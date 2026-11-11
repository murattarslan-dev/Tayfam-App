import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/cihaz/e2e_cihaz_yoneticisi.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

export 'package:tayfam/core/e2e/cihaz/e2e_cihaz_yoneticisi.dart'
    show E2eCihazBilgisi, E2eCihazDurumu;

/// Bu derlemede uçtan uca şifreleme var mı: mobilde evet, web geliştirme
/// derlemesinde hayır (ADR-0011). Testler override eder.
final e2eEtkinProvider = Provider<bool>(
  (ref) => !kIsWeb,
  name: 'e2eEtkinProvider',
);

/// Uygulamanın Signal motoru (ADR-0010). Platform kanalı uygulaması Signal
/// köprüsü işiyle (`lib/core/e2e/signal/`) gelir ve bu provider'a
/// bağlanır; bağlanana kadar her çağrı desteklenmiyor hatası verir ve
/// cihaz kaydı [E2eCihazDurumu.hata]'da kalır. Testler sahte motor verir.
final e2eMotoruProvider = Provider<SignalMotoru>(
  (ref) => const _BaglanmamisMotor(),
  name: 'e2eMotoruProvider',
);

/// Köprü bağlanana kadar her çağrıda [SignalHatasi] veren motor.
final class _BaglanmamisMotor implements SignalMotoru {
  const _BaglanmamisMotor();

  @override
  Object? noSuchMethod(Invocation invocation) =>
      Future<Never>.error(const SignalHatasi(SignalHatasiTuru.bilinmeyen));
}

/// Cihaz kaydı ve ön anahtar bakımı.
final e2eCihazYoneticisiProvider = Provider<E2eCihazYoneticisi>(
  (ref) => E2eCihazYoneticisi(
    motor: ref.watch(e2eMotoruProvider),
    depo: ref.watch(e2eDeposuProvider),
    api: ref.watch(apiClientProvider),
  ),
  name: 'e2eCihazYoneticisiProvider',
);

/// Bu cihazın E2E durumu (ADR-0020 "Cihaz").
///
/// - Oturum açılınca (yalnızca mobilde) cihaz kaydedilir ya da durumu
///   okunur, ön anahtar bakımı yapılır.
/// - Oturum kapanınca (çıkış, hesap silme, sunucunun kapatması) ve
///   açılışta oturum yoksa bütün E2E anahtarları güvenli depodan silinir
///   (ADR-0010). Sunucu cihazı oturumla birlikte siler (Tayfam-Api
///   ADR-0018 §1).
///
/// Geçmiş arşivi ve eşleştirme (E3) bu durumu dinler ve geçmiş anahtarı
/// talebinden sonra [yenile]'yi çağırır.
class E2eCihazNotifier extends Notifier<E2eCihazBilgisi> {
  int _nesil = 0;
  Future<void>? _suren;

  @override
  E2eCihazBilgisi build() {
    final oturum = ref.watch(oturumDurumuProvider);
    final etkin = ref.watch(e2eEtkinProvider);
    final nesil = ++_nesil;
    _suren = null;
    if (!etkin) {
      return const E2eCihazBilgisi(durum: E2eCihazDurumu.desteklenmiyor);
    }
    switch (oturum) {
      case OturumDurumu.acik:
        _baslat(nesil);
        return const E2eCihazBilgisi(durum: E2eCihazDurumu.hazirlaniyor);
      case OturumDurumu.girisYok:
        unawaited(ref.read(e2eDeposuProvider).temizle());
        return const E2eCihazBilgisi.kapali();
      case OturumDurumu.yukleniyor ||
          OturumDurumu.kayitBekliyor ||
          OturumDurumu.onayGerekli:
        return const E2eCihazBilgisi.kapali();
    }
  }

  void _baslat(int nesil) {
    final suren = _hazirla(nesil);
    _suren = suren;
    unawaited(
      suren.whenComplete(() {
        if (identical(_suren, suren)) _suren = null;
      }),
    );
  }

  Future<void> _hazirla(int nesil) async {
    // build bitmeden state yazılmaz.
    await Future<void>.value();
    E2eCihazBilgisi sonuc;
    try {
      sonuc = await ref.read(e2eCihazYoneticisiProvider).hazirla();
    } on ApiProblem catch (hata) {
      sonuc = hata.type == ProblemType.e2eDeviceLimit
          ? const E2eCihazBilgisi(durum: E2eCihazDurumu.sinirDolu)
          : E2eCihazBilgisi(durum: E2eCihazDurumu.hata, hata: hata);
    } on Exception catch (hata) {
      sonuc = E2eCihazBilgisi(durum: E2eCihazDurumu.hata, hata: hata);
    }
    if (!ref.mounted || nesil != _nesil) return;
    state = sonuc;
  }

  /// Hazırlık başarısızsa (ya da cihaz sınırı doluysa) yeniden dener.
  Future<void> yenidenDene() {
    if (state.durum == E2eCihazDurumu.hazir ||
        state.durum == E2eCihazDurumu.desteklenmiyor ||
        state.durum == E2eCihazDurumu.kapali) {
      return Future.value();
    }
    final suren = _suren;
    if (suren != null) return suren;
    state = const E2eCihazBilgisi(durum: E2eCihazDurumu.hazirlaniyor);
    _baslat(_nesil);
    return _suren ?? Future.value();
  }

  /// Cihaz hazır olana kadar bekler. Hazır değilse cihaz sınırında
  /// `e2e-device-limit`, diğer durumlarda `e2e-device-not-registered`
  /// problemi fırlatır (metni ortak hata eşlemesinden).
  Future<void> hazirOl() async {
    if (state.durum == E2eCihazDurumu.hata) await yenidenDene();
    final suren = _suren;
    if (suren != null) await suren;
    if (!ref.mounted) throw _hazirDegil;
    switch (state.durum) {
      case E2eCihazDurumu.hazir:
        return;
      case E2eCihazDurumu.sinirDolu:
        throw const ApiProblem(type: ProblemType.e2eDeviceLimit, status: 409);
      default:
        throw _hazirDegil;
    }
  }

  /// Sunucudaki durumu yeniden okur (geçmiş anahtarı talebi, eşleştirme ya
  /// da yenilemeden sonra). Okunamazsa durum değişmez.
  Future<void> yenile() async {
    if (!state.hazir) return;
    final nesil = _nesil;
    try {
      final yeni = await ref.read(e2eCihazYoneticisiProvider).durumOku();
      if (ref.mounted && nesil == _nesil) state = yeni;
    } on Exception {
      // Bir sonraki açılışta yeniden okunur.
    }
  }

  /// `e2e.prekeys_low`: ön anahtarlar tamamlanır.
  Future<void> onAnahtarlarAzaldi() async {
    if (!state.hazir) return;
    try {
      await ref.read(e2eCihazYoneticisiProvider).onAnahtarlarAzaldi();
    } on Exception {
      // Bir sonraki açılışta ya da sinyalde yeniden denenir.
    }
  }
}

/// Cihaz hazır değilken gönderim: `e2e-device-not-registered` problemi
/// (kullanıcıya "şifreli mesajlaşma henüz hazır değil" metni).
const ApiProblem _hazirDegil = ApiProblem(
  type: ProblemType.e2eDeviceNotRegistered,
  status: 409,
);

/// Bu cihazın E2E durumu (kalıcı; oturum değişince yeniden kurulur).
final e2eCihazProvider = NotifierProvider<E2eCihazNotifier, E2eCihazBilgisi>(
  E2eCihazNotifier.new,
  name: 'e2eCihazProvider',
);
