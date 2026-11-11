import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

/// Çevrimdışı kuyruğa giren bir iş (ADR-0006): kanal mesajı, birebir
/// mesaj (düz sürüm), soru, cevap, katılım bildirimi.
///
/// İşi oluşturan özellik bu sınıftan türetir ve kendi alanlarını (ör.
/// mesaj metni) ekler. Kuyruk işin içeriğine bakmaz, hiçbir yere yazmaz
/// ve loglamaz (CLAUDE.md kesin kural 3).
abstract class KuyrukIsi {
  const KuyrukIsi();

  /// İş oluşturulurken bir kez üretilen `client_request_id`
  /// (`yeniIstekKimligi()`); her denemede aynısı gönderilir. Kuyrukta
  /// işin kimliği de budur.
  String get istekKimligi;

  /// İşin ait olduğu sıra (ör. `kanal:<kanalId>`). Aynı gruptaki işler
  /// eklendikleri sırayla, birer birer gönderilir; gruplar birbirini
  /// beklemez. Arayüz bekleyen öğeleri bu grupla süzer.
  String get grup;

  /// İşi bir kez gönderir ve sunucunun cevabını döndürür. Her çağrıda
  /// aynı [istekKimligi] kullanılmalıdır; sunucu aynı id'yi ikinci kayıt
  /// açmadan karşılar. Hata [ApiHatasi] (ya da [OturumYok]) olarak
  /// fırlatılır.
  Future<Object?> gonder();
}

/// Kuyruktaki bir öğenin durumu.
enum KuyrukDurumu {
  /// Gönderilmeyi bekliyor (ilk deneme ya da geri çekilme süresi).
  bekliyor,

  /// Şu an gönderiliyor.
  gonderiliyor,

  /// Kalıcı hata aldı; "Tekrar dene" ya da "Sil" beklenir.
  gonderilemedi,
}

/// Kuyruktaki bir iş ve gönderim durumu. Yalnızca bellektedir.
@immutable
final class KuyrukOgesi {
  const KuyrukOgesi({
    required this.isi,
    required this.durum,
    this.deneme = 0,
    this.sonrakiDeneme,
    this.hata,
  });

  final KuyrukIsi isi;
  final KuyrukDurumu durum;

  /// Başarısız deneme sayısı.
  final int deneme;

  /// [KuyrukDurumu.bekliyor] iken en erken deneme anı; `null` ise hemen.
  final DateTime? sonrakiDeneme;

  /// Son denemenin hatası (metni ortak eşlemeden gelir).
  final Object? hata;

  String get istekKimligi => isi.istekKimligi;
  String get grup => isi.grup;

  KuyrukOgesi _ile({
    KuyrukDurumu? durum,
    int? deneme,
    DateTime? sonrakiDeneme,
    Object? hata,
  }) => KuyrukOgesi(
    isi: isi,
    durum: durum ?? this.durum,
    deneme: deneme ?? this.deneme,
    sonrakiDeneme: sonrakiDeneme,
    hata: hata,
  );
}

/// Kuyruğun bir işi bitirdiğinde yaydığı olay.
sealed class KuyrukOlayi {
  const KuyrukOlayi(this.isi);

  final KuyrukIsi isi;
}

/// İş gönderildi; [sonuc] [KuyrukIsi.gonder]'in döndürdüğü değerdir (ör.
/// sunucunun yazdığı mesaj). İşi ekleyen bekleyen kaydı bununla değiştirir.
final class KuyrukGonderildi extends KuyrukOlayi {
  const KuyrukGonderildi(super.isi, this.sonuc);

  final Object? sonuc;
}

/// İş kalıcı hata aldı ve "gönderilemedi" oldu.
final class KuyrukGonderilemedi extends KuyrukOlayi {
  const KuyrukGonderilemedi(super.isi, this.hata);

  final Object hata;
}

/// Bir hatanın geçici olup olmadığı (ADR-0006): bağlantı yok, zaman aşımı,
/// sunucu hatası, `unavailable`, `rate-limited` ve `slow-mode` yeniden
/// denenir; diğer problemler (`invalid-request`, `permission-denied`,
/// `not-found`, `muted`, `channel-archived` …) kalıcıdır.
bool geciciHataMi(Object hata) => switch (hata) {
  ApiOffline() || ApiTimeout() => true,
  ApiProblem(:final type, :final status) =>
    type == ProblemType.rateLimited ||
        type == ProblemType.slowMode ||
        type == ProblemType.unavailable ||
        type == ProblemType.internal ||
        status >= 500,
  TimeoutException() => true,
  _ => false,
};

/// Çevrimdışı yazma kuyruğu (ADR-0006).
///
/// - Yalnızca bellektedir; uygulama kapanınca bekleyenler kaybolur
///   (bilinçli kabul edilen bedel).
/// - Oturum durumu değişince (çıkış, kullanıcı değişimi, hesap silme)
///   temizlenir (ADR-0001 kural 8).
/// - Aynı [KuyrukIsi.grup]'taki işler sırayla gider; grubun başındaki iş
///   gönderilmeden arkasındaki gitmez. "Gönderilemedi" olan iş sırayı
///   tutmaz.
/// - Geçici hatada ([geciciHataMi]) 2, 4, 8 … en fazla 60 saniye sonra
///   yeniden denenir; `rate-limited` ve `slow-mode` sunucunun bildirdiği
///   süre kadar bekler. [simdiDene] (bağlantı gelince) bekleyenleri hemen
///   dener.
/// - İçerik hiçbir yere yazılmaz ve loglanmaz.
class CevrimdisiKuyruk extends Notifier<List<KuyrukOgesi>> {
  /// İlk geri çekilme süresi.
  static const Duration ilkBekleme = Duration(seconds: 2);

  /// En uzun geri çekilme süresi.
  static const Duration enUzunBekleme = Duration(seconds: 60);

  final StreamController<KuyrukOlayi> _olaylar =
      StreamController<KuyrukOlayi>.broadcast();
  final Set<String> _ucustakiGruplar = {};
  Timer? _zamanlayici;
  int _nesil = 0;

  /// Biten işlerin olayları. İşi ekleyen özellik dinler.
  Stream<KuyrukOlayi> get olaylar => _olaylar.stream;

  @override
  List<KuyrukOgesi> build() {
    ref.watch(oturumDurumuProvider);
    _nesil++;
    _ucustakiGruplar.clear();
    ref.onDispose(() {
      _zamanlayici?.cancel();
      _zamanlayici = null;
    });
    return const [];
  }

  /// [isi]'ni kuyruğa ekler ve (sırası geldiyse) hemen gönderir. Aynı
  /// istek kimliğiyle kuyrukta bir iş varsa bir şey yapmaz.
  void ekle(KuyrukIsi isi) {
    if (_bul(isi.istekKimligi) != null) return;
    state = List.unmodifiable([
      ...state,
      KuyrukOgesi(isi: isi, durum: KuyrukDurumu.bekliyor),
    ]);
    _isle();
  }

  /// "Gönderilemedi" olan işi yeniden sıraya koyar ve dener.
  void tekrarDene(String istekKimligi) {
    final oge = _bul(istekKimligi);
    if (oge == null || oge.durum != KuyrukDurumu.gonderilemedi) return;
    _degistir(
      istekKimligi,
      (o) => o._ile(durum: KuyrukDurumu.bekliyor, deneme: 0),
    );
    _isle();
  }

  /// İşi kuyruktan çıkarır ("Sil"). Gönderilirken çıkarılan işin sonucu
  /// yok sayılmaz: sunucu yazdıysa [KuyrukGonderildi] yine yayılır.
  void sil(String istekKimligi) {
    state = List.unmodifiable([
      for (final o in state)
        if (o.istekKimligi != istekKimligi) o,
    ]);
    _isle();
  }

  /// Bekleyen bütün işleri, geri çekilme süresini beklemeden dener
  /// (bağlantı geldi, uygulama ön plana döndü).
  void simdiDene() {
    if (state.any(_bekliyorZamanli)) {
      state = List.unmodifiable([
        for (final o in state)
          // `_ile` sonraki deneme anını verilmezse temizler.
          if (_bekliyorZamanli(o)) o._ile(deneme: o.deneme) else o,
      ]);
    }
    _isle();
  }

  static bool _bekliyorZamanli(KuyrukOgesi o) =>
      o.durum == KuyrukDurumu.bekliyor && o.sonrakiDeneme != null;

  /// [grup]'taki öğeler, eklenme sırasıyla.
  List<KuyrukOgesi> grubunOgeleri(String grup) => [
    for (final o in state)
      if (o.grup == grup) o,
  ];

  /// Gönderilmeyi bekleyen (gönderilemedi olmayan) öğe var mı.
  bool get bekleyenVar =>
      state.any((o) => o.durum != KuyrukDurumu.gonderilemedi);

  // ------------------------------------------------------------------ iç

  DateTime _simdi() => ref.read(simdiProvider)();

  KuyrukOgesi? _bul(String istekKimligi) {
    for (final o in state) {
      if (o.istekKimligi == istekKimligi) return o;
    }
    return null;
  }

  void _degistir(String istekKimligi, KuyrukOgesi Function(KuyrukOgesi) f) {
    state = List.unmodifiable([
      for (final o in state)
        if (o.istekKimligi == istekKimligi) f(o) else o,
    ]);
  }

  /// Her grubun başındaki işi (sırası geldiyse) gönderir ve en yakın
  /// bekleme için zamanlayıcıyı kurar.
  void _isle() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
    final simdi = _simdi();
    final basliklar = <String, KuyrukOgesi>{};
    for (final o in state) {
      if (o.durum == KuyrukDurumu.gonderilemedi) continue;
      basliklar.putIfAbsent(o.grup, () => o);
    }
    DateTime? enYakin;
    for (final oge in basliklar.values) {
      if (oge.durum != KuyrukDurumu.bekliyor) continue;
      if (_ucustakiGruplar.contains(oge.grup)) continue;
      final zaman = oge.sonrakiDeneme;
      if (zaman == null || !zaman.isAfter(simdi)) {
        unawaited(_gonder(oge));
      } else if (enYakin == null || zaman.isBefore(enYakin)) {
        enYakin = zaman;
      }
    }
    if (enYakin != null) {
      _zamanlayici = ref.read(zamanlayiciProvider)(
        enYakin.difference(simdi),
        _isle,
      );
    }
  }

  Future<void> _gonder(KuyrukOgesi oge) async {
    final nesil = _nesil;
    _ucustakiGruplar.add(oge.grup);
    _degistir(
      oge.istekKimligi,
      (o) => o._ile(durum: KuyrukDurumu.gonderiliyor, deneme: o.deneme),
    );
    Object? sonuc;
    Exception? hata;
    try {
      sonuc = await oge.isi.gonder();
    } on Exception catch (h) {
      hata = h;
    }
    if (!ref.mounted || nesil != _nesil) return;
    _ucustakiGruplar.remove(oge.grup);

    if (hata case final h?) {
      _hatayiIsle(oge, h);
      return;
    }
    sil(oge.istekKimligi);
    _yay(KuyrukGonderildi(oge.isi, sonuc));
  }

  void _hatayiIsle(KuyrukOgesi oge, Exception hata) {
    if (hata is OturumYok) {
      // Oturum kapandı; kuyruk oturum durumu değişince temizlenir.
      return;
    }
    final mevcut = _bul(oge.istekKimligi);
    if (geciciHataMi(hata)) {
      if (mevcut != null) {
        final deneme = mevcut.deneme + 1;
        _degistir(
          oge.istekKimligi,
          (o) => o._ile(
            durum: KuyrukDurumu.bekliyor,
            deneme: deneme,
            sonrakiDeneme: _simdi().add(beklemeSuresi(deneme, hata)),
            hata: hata,
          ),
        );
      }
    } else {
      if (mevcut != null) {
        _degistir(
          oge.istekKimligi,
          (o) => o._ile(
            durum: KuyrukDurumu.gonderilemedi,
            deneme: o.deneme + 1,
            hata: hata,
          ),
        );
      }
      _yay(KuyrukGonderilemedi(oge.isi, hata));
    }
    _isle();
  }

  void _yay(KuyrukOlayi olay) {
    if (!_olaylar.isClosed) _olaylar.add(olay);
  }
}

/// [deneme]'inci başarısız denemeden sonra beklenecek süre: sunucu bir süre
/// bildirdiyse o, değilse 2, 4, 8 … en fazla 60 saniye (ADR-0006).
@visibleForTesting
Duration beklemeSuresi(int deneme, Object hata) {
  if (hata is ApiProblem) {
    final sunucu = hata.retryAfter;
    if (sunucu != null && sunucu > Duration.zero) return sunucu;
  }
  final ust = deneme.clamp(1, 6);
  final saniye = CevrimdisiKuyruk.ilkBekleme.inSeconds << (ust - 1);
  final sure = Duration(seconds: saniye);
  return sure > CevrimdisiKuyruk.enUzunBekleme
      ? CevrimdisiKuyruk.enUzunBekleme
      : sure;
}

/// Uygulama boyunca tek çevrimdışı kuyruk (ADR-0006: `core/` altında,
/// kalıcı provider; ADR-0001 kural 4).
final cevrimdisiKuyrukProvider =
    NotifierProvider<CevrimdisiKuyruk, List<KuyrukOgesi>>(
      CevrimdisiKuyruk.new,
      name: 'cevrimdisiKuyrukProvider',
    );
