import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Çözülmüş birebir mesajın geldiği yol.
enum CozulmusMesajKaynagi {
  /// Bu cihazdan gönderildi.
  gonderildi,

  /// Bir zarftan çözüldü (karşı taraf ya da kendi diğer cihazımız).
  zarf,

  /// Geçmiş arşivinden çözüldü (yeniden arşive yazılmaz).
  arsiv,
}

/// Uçtan uca şifreli bir birebir mesajın çözülmüş içeriği (ADR-0020).
///
/// Yalnızca bellekte yaşar (ADR-0006); hiçbir yere yazılmaz, loglanmaz.
/// `toString` metni içermez.
@immutable
final class CozulmusBirebirMesaj {
  const CozulmusBirebirMesaj({
    required this.mesajId,
    required this.konusmaId,
    required this.gonderenKullaniciId,
    required this.metin,
    required this.olusturma,
    required this.kaynak,
  });

  final String mesajId;
  final String konusmaId;
  final String gonderenKullaniciId;
  final String metin;
  final DateTime olusturma;
  final CozulmusMesajKaynagi kaynak;

  @override
  String toString() => 'CozulmusBirebirMesaj($mesajId)';
}

/// Konuşmada gösterilen E2E sistem satırının türü.
enum E2eSatirTuru {
  /// Karşı tarafın bir cihazı eklendi ya da çıkarıldı ya da kimlik
  /// anahtarı değişti: "Güvenlik kodu değişti".
  guvenlikKoduDegisti,

  /// Bir zarf çözülemedi: "Bir mesaj çözülemedi".
  mesajCozulemedi,

  /// Kendi hesabına yeni bir cihaz eklendi (bütün konuşmalarda).
  yeniKendiCihazi,
}

/// Konuşmanın akışına zamanıyla giren E2E sistem satırı.
@immutable
final class E2eSistemSatiri {
  const E2eSistemSatiri({
    required this.kimlik,
    required this.tur,
    required this.zaman,
  });

  /// Tekilleştirme anahtarı (ör. anahtar olayının ya da zarfın kimliği).
  final String kimlik;
  final E2eSatirTuru tur;
  final DateTime zaman;
}

/// Bellekteki çözülmüş içerik ve E2E sistem satırları.
@immutable
final class BirebirIcerikDurumu {
  const BirebirIcerikDurumu({
    this.mesajlar = const {},
    this.konusmaSatirlari = const {},
    this.kullaniciSatirlari = const {},
    this.genelSatirlar = const [],
  });

  /// Mesaj kimliği → çözülmüş içerik.
  final Map<String, CozulmusBirebirMesaj> mesajlar;

  /// Konuşma kimliği → o konuşmaya ait satırlar ("bir mesaj çözülemedi").
  final Map<String, List<E2eSistemSatiri>> konusmaSatirlari;

  /// Karşı kullanıcı kimliği → o kişiyle bütün konuşmalarda gösterilen
  /// satırlar ("güvenlik kodu değişti").
  final Map<String, List<E2eSistemSatiri>> kullaniciSatirlari;

  /// Bütün konuşmalarda gösterilen satırlar (kendi hesabına yeni cihaz).
  final List<E2eSistemSatiri> genelSatirlar;

  /// [konusmaId] (karşı taraf [karsiId]) konuşmasının satırları, eskiden
  /// yeniye.
  List<E2eSistemSatiri> satirlar(String konusmaId, String? karsiId) {
    final hepsi = <E2eSistemSatiri>[
      ...?konusmaSatirlari[konusmaId],
      if (karsiId != null) ...?kullaniciSatirlari[karsiId],
      ...genelSatirlar,
    ]..sort((a, b) => a.zaman.compareTo(b.zaman));
    return hepsi;
  }
}

/// Uçtan uca şifreli birebir mesajların bellekteki içeriği (ADR-0020).
///
/// Gönderilen ve zarftan çözülen mesajlar [ekle] ile girer; geçmiş arşivi
/// (E3) çözdüğü mesajları da buraya ekler. Konuşma ekranı mesajın
/// metnini buradan alır. Oturum değişince (çıkış dahil) sıfırlanır
/// (ADR-0001 kural 8). Diske hiçbir şey yazılmaz.
class BirebirIcerikNotifier extends Notifier<BirebirIcerikDurumu> {
  @override
  BirebirIcerikDurumu build() {
    ref.watch(oturumDurumuProvider);
    return const BirebirIcerikDurumu();
  }

  /// Mesajları ekler (aynı kimlikte var olan korunur).
  void ekle(Iterable<CozulmusBirebirMesaj> mesajlar) {
    final yeni = {...state.mesajlar};
    var degisti = false;
    for (final m in mesajlar) {
      if (yeni.containsKey(m.mesajId)) continue;
      yeni[m.mesajId] = m;
      degisti = true;
    }
    if (!degisti) return;
    state = BirebirIcerikDurumu(
      mesajlar: Map.unmodifiable(yeni),
      konusmaSatirlari: state.konusmaSatirlari,
      kullaniciSatirlari: state.kullaniciSatirlari,
      genelSatirlar: state.genelSatirlar,
    );
  }

  /// [konusmaId]'ye satır ekler (aynı kimlikli satır tekrar eklenmez).
  void konusmaSatiri(String konusmaId, E2eSistemSatiri satir) {
    final mevcut = state.konusmaSatirlari[konusmaId] ?? const [];
    if (mevcut.any((s) => s.kimlik == satir.kimlik)) return;
    state = BirebirIcerikDurumu(
      mesajlar: state.mesajlar,
      konusmaSatirlari: {
        ...state.konusmaSatirlari,
        konusmaId: List.unmodifiable([...mevcut, satir]),
      },
      kullaniciSatirlari: state.kullaniciSatirlari,
      genelSatirlar: state.genelSatirlar,
    );
  }

  /// [kullaniciId] ile konuşmalara satır ekler.
  void kullaniciSatiri(String kullaniciId, E2eSistemSatiri satir) {
    final mevcut = state.kullaniciSatirlari[kullaniciId] ?? const [];
    if (mevcut.any((s) => s.kimlik == satir.kimlik)) return;
    state = BirebirIcerikDurumu(
      mesajlar: state.mesajlar,
      konusmaSatirlari: state.konusmaSatirlari,
      kullaniciSatirlari: {
        ...state.kullaniciSatirlari,
        kullaniciId: List.unmodifiable([...mevcut, satir]),
      },
      genelSatirlar: state.genelSatirlar,
    );
  }

  /// Bütün konuşmalara satır ekler.
  void genelSatir(E2eSistemSatiri satir) {
    if (state.genelSatirlar.any((s) => s.kimlik == satir.kimlik)) return;
    state = BirebirIcerikDurumu(
      mesajlar: state.mesajlar,
      konusmaSatirlari: state.konusmaSatirlari,
      kullaniciSatirlari: state.kullaniciSatirlari,
      genelSatirlar: List.unmodifiable([...state.genelSatirlar, satir]),
    );
  }
}

/// Bellekteki E2E içerik (kalıcı; oturum değişince sıfırlanır).
final birebirIcerikProvider =
    NotifierProvider<BirebirIcerikNotifier, BirebirIcerikDurumu>(
      BirebirIcerikNotifier.new,
      name: 'birebirIcerikProvider',
    );

/// Bu cihazın gönderdiği ve zarftan çözdüğü her mesajı yayan kanca.
///
/// Geçmiş arşivi (E3) buna abone olup eşleştirilmiş cihazda mesajları
/// arşive yazar. Arşivden gelen mesajlar ([CozulmusMesajKaynagi.arsiv])
/// burada yayılmaz.
final class E2eMesajYayini {
  final StreamController<CozulmusBirebirMesaj> _akis =
      StreamController<CozulmusBirebirMesaj>.broadcast();

  /// Yeni çözülmüş (ya da gönderilmiş) mesajlar.
  Stream<CozulmusBirebirMesaj> get akis => _akis.stream;

  /// [mesaj]'ı yayar.
  void yay(CozulmusBirebirMesaj mesaj) {
    if (!_akis.isClosed) _akis.add(mesaj);
  }

  Future<void> kapat() => _akis.close();
}

/// Uygulamanın E2E mesaj yayını (kalıcı).
final e2eMesajYayiniProvider = Provider<E2eMesajYayini>((ref) {
  final yayin = E2eMesajYayini();
  ref.onDispose(() => unawaited(yayin.kapat()));
  return yayin;
}, name: 'e2eMesajYayiniProvider');
