import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_uyarici.dart';

/// Kronometrenin modu (Tayfam-Api ADR-0037 §3: `mode`).
enum KronometreModu {
  geriSayim('countdown'),
  ileriSayim('stopwatch'),
  satrancSaati('chess_clock');

  const KronometreModu(this.wire);

  /// Tanımdaki değer.
  final String wire;

  /// Tanımdaki [deger]; tanınmayan değerde `null`.
  static KronometreModu? oku(String? deger) {
    for (final mod in values) {
      if (mod.wire == deger) return mod;
    }
    return null;
  }
}

/// Ön ayar ve elle girilen sürenin en çok saniyesi (Tayfam-Api
/// `definition.go`'daki `presets` sınırı).
const int kronometreSureEnCok = 86400;

/// Tanımda ön ayar yokken başlangıç süresi.
const Duration kronometreVarsayilanSure = Duration(minutes: 5);

/// Tanımdaki ön ayarların en çok sayısı (Tayfam-Api `MaxTimerPresets`).
const int kronometreOnAyarEnCok = 6;

/// Bileşenin tanımından okunan ayar: mod ve ön ayarlar (saniye). Mod
/// yoksa ya da tanınmıyorsa geri sayımdır; sınır dışındaki ön ayar atlanır
/// (ADR-0024 §3: parametreler girdi kabul edilir).
@immutable
final class KronometreTanimi {
  const KronometreTanimi({required this.mod, this.onAyarlar = const []});

  factory KronometreTanimi.oku(BilesenParametreleri p) {
    final mod =
        KronometreModu.oku(
          p.metin('mode', izinli: {
            for (final m in KronometreModu.values) m.wire,
          }),
        ) ??
        KronometreModu.geriSayim;
    final onAyarlar = <int>[];
    for (final s in p.tamSayilar('presets')) {
      if (s < 1 || s > kronometreSureEnCok || onAyarlar.contains(s)) continue;
      if (onAyarlar.length == kronometreOnAyarEnCok) break;
      onAyarlar.add(s);
    }
    return KronometreTanimi(mod: mod, onAyarlar: onAyarlar);
  }

  final KronometreModu mod;

  /// Ön ayar süreleri (saniye), tanımdaki sırayla.
  final List<int> onAyarlar;

  /// Kronometre açılınca seçili süre: ilk ön ayar ya da 5 dakika.
  Duration get ilkSure => onAyarlar.isEmpty
      ? kronometreVarsayilanSure
      : Duration(seconds: onAyarlar.first);
}

/// Tek bir saat: biriken süre ve çalışıyorsa başladığı an. Geçen süre her
/// okunuşta başlangıç anından hesaplanır; zamanlayıcının tıklamalarına
/// güvenilmez (uygulama arka plandayken ya da ekran kapalıyken de doğru
/// kalır).
@immutable
final class Sayac {
  const Sayac({this.birikmis = Duration.zero, this.basladi});

  final Duration birikmis;

  /// Çalışıyorsa son başladığı an; duruyorsa `null`.
  final DateTime? basladi;

  bool get calisiyor => basladi != null;

  /// [simdi] itibarıyla geçen süre. Saat geri alınırsa eksi fark yok
  /// sayılır.
  Duration gecen(DateTime simdi) {
    final basladi = this.basladi;
    if (basladi == null) return birikmis;
    final fark = simdi.difference(basladi);
    return fark.isNegative ? birikmis : birikmis + fark;
  }

  Sayac baslat(DateTime simdi) =>
      calisiyor ? this : Sayac(birikmis: birikmis, basladi: simdi);

  Sayac durdur(DateTime simdi) =>
      calisiyor ? Sayac(birikmis: gecen(simdi)) : this;
}

/// Kronometrenin durumu (ADR-0031 §3). Yalnızca bellektedir (ADR-0006):
/// diske yazılmaz, sunucuya gitmez; ekran kapanınca sıfırlanır.
///
/// Satranç saatinde iki saat vardır; 0 üstteki (ekranda ters dönen), 1
/// alttaki oyuncunundur. [sira] saati işleyen (ya da duraklatılmışsa
/// işleyecek) oyuncudur.
@immutable
final class KronometreDurumu {
  const KronometreDurumu({
    required this.mod,
    required this.sure,
    required this.sayaclar,
    required this.simdi,
    this.sira,
    this.bitti = false,
  });

  /// Başlamamış kronometre.
  factory KronometreDurumu.ilk(
    KronometreModu mod,
    Duration sure,
    DateTime simdi,
  ) => KronometreDurumu(
    mod: mod,
    sure: sure,
    sayaclar: mod == KronometreModu.satrancSaati
        ? const [Sayac(), Sayac()]
        : const [Sayac()],
    simdi: simdi,
  );

  final KronometreModu mod;

  /// Geri sayımda toplam süre; satranç saatinde oyuncu başına süre.
  final Duration sure;

  final List<Sayac> sayaclar;

  /// Durumun hesaplandığı an (ekrandaki değerler buna göre çizilir).
  final DateTime simdi;

  /// Satranç saatinde sıradaki oyuncu; başlamadıysa `null`.
  final int? sira;

  /// Geri sayımda ya da satranç saatinde süre doldu.
  final bool bitti;

  bool get calisiyor => sayaclar.any((s) => s.calisiyor);

  /// Bir kez başlatıldı mı (süre artık değiştirilemez; "Sıfırla" gerekir).
  bool get baslatildi =>
      bitti ||
      sira != null ||
      sayaclar.any((s) => s.calisiyor || s.birikmis > Duration.zero);

  /// Duraklatıldı mı (başlatıldı, bitmedi, işlemiyor).
  bool get duraklatildi => baslatildi && !bitti && !calisiyor;

  /// Saati işleyen ya da işleyecek sayacın sırası.
  int get etkinSayac => mod == KronometreModu.satrancSaati ? sira ?? 0 : 0;

  Duration gecen([int i = 0]) => sayaclar[i].gecen(simdi);

  Duration kalan([int i = 0]) {
    final k = sure - gecen(i);
    return k.isNegative ? Duration.zero : k;
  }

  /// Ekranda gösterilen saniye: ileri sayımda geçen (aşağı yuvarlanır),
  /// diğerlerinde kalan (yukarı yuvarlanır; 0 yalnızca süre dolunca).
  int gosterilenSaniye([int i = 0]) {
    if (mod == KronometreModu.ileriSayim) return gecen(i).inSeconds;
    final ms = kalan(i).inMilliseconds;
    return (ms + Duration.millisecondsPerSecond - 1) ~/
        Duration.millisecondsPerSecond;
  }

  /// Süresi dolan satranç oyuncusu; yoksa `null`.
  int? get bitenTaraf {
    if (!bitti || mod != KronometreModu.satrancSaati) return null;
    for (var i = 0; i < sayaclar.length; i++) {
      if (kalan(i) == Duration.zero) return i;
    }
    return null;
  }

  /// Ekrandaki saniyenin değişeceği ana kadar süre; işlemiyorsa `null`.
  Duration? get sonrakiDegisim {
    if (!calisiyor || bitti) return null;
    const saniye = Duration.millisecondsPerSecond;
    final int ms;
    if (mod == KronometreModu.ileriSayim) {
      ms = saniye - gecen().inMilliseconds % saniye;
    } else {
      final kalanMs = kalan(etkinSayac).inMilliseconds;
      final artik = kalanMs % saniye;
      ms = artik == 0 ? (kalanMs == 0 ? 0 : saniye) : artik;
    }
    return Duration(milliseconds: ms);
  }

  KronometreDurumu kopya({
    List<Sayac>? sayaclar,
    DateTime? simdi,
    int? sira,
    bool? bitti,
  }) => KronometreDurumu(
    mod: mod,
    sure: sure,
    sayaclar: sayaclar ?? this.sayaclar,
    simdi: simdi ?? this.simdi,
    sira: sira ?? this.sira,
    bitti: bitti ?? this.bitti,
  );

  /// Bütün saatleri [simdi]'de durdurur.
  KronometreDurumu durdur(DateTime simdi) => kopya(
    sayaclar: [for (final s in sayaclar) s.durdur(simdi)],
    simdi: simdi,
  );

  /// [i]'nci saati [simdi]'de başlatır (diğerleri durur).
  KronometreDurumu baslat(int i, DateTime simdi) => kopya(
    sayaclar: [
      for (var j = 0; j < sayaclar.length; j++)
        j == i ? sayaclar[j].baslat(simdi) : sayaclar[j].durdur(simdi),
    ],
    simdi: simdi,
    sira: mod == KronometreModu.satrancSaati ? i : null,
  );
}

/// Elle girilen süreyi okur: `90` (saniye), `1:30` (dakika:saniye) ya da
/// `1:02:03` (saat:dakika:saniye). İlk parçadan sonrakiler 60'tan
/// küçüktür; süre 1 saniye ile [kronometreSureEnCok] arasındadır. Okunamazsa
/// `null`.
Duration? kronometreSuresiniOku(String metin) {
  final parcalar = metin.trim().split(':');
  if (parcalar.length > 3) return null;
  var toplam = 0;
  for (var i = 0; i < parcalar.length; i++) {
    final parca = parcalar[i];
    if (parca.isEmpty ||
        parca.length > 5 ||
        !RegExp(r'^\d+$').hasMatch(parca)) {
      return null;
    }
    final sayi = int.parse(parca);
    if (i > 0 && sayi >= 60) return null;
    toplam = toplam * 60 + sayi;
  }
  if (toplam < 1 || toplam > kronometreSureEnCok) return null;
  return Duration(seconds: toplam);
}

/// Kronometrenin bellekteki kimliği: mod ve açılıştaki süre.
typedef KronometreAyari = ({KronometreModu mod, Duration ilkSure});

/// Kronometrenin işleyişi (ADR-0031 §3). Sunucuyla konuşmaz. Ekrandaki
/// saniye değişeceği an tek seferlik bir zamanlayıcı kurulur; her
/// tıklamada değerler saatten yeniden hesaplanır. Süre dolunca bir kez
/// uyarı (kısa titreşim ve ses) verilir.
class KronometreNotifier extends Notifier<KronometreDurumu> {
  KronometreNotifier(this.ayar);

  final KronometreAyari ayar;

  Timer? _zamanlayici;

  DateTime _simdi() => ref.read(simdiProvider)();

  @override
  KronometreDurumu build() {
    ref.onDispose(() {
      _zamanlayici?.cancel();
      _zamanlayici = null;
    });
    return KronometreDurumu.ilk(ayar.mod, ayar.ilkSure, _simdi());
  }

  /// Süreyi değiştirir; yalnızca başlamamış kronometrede.
  void sureSec(Duration sure) {
    if (state.baslatildi || state.mod == KronometreModu.ileriSayim) return;
    if (sure <= Duration.zero ||
        sure > const Duration(seconds: kronometreSureEnCok)) {
      return;
    }
    _yaz(KronometreDurumu.ilk(state.mod, sure, _simdi()));
  }

  /// Başlatır ya da duraklatılmışsa sürdürür. Satranç saatinde başlamamış
  /// saat üstteki oyuncudan başlar.
  void baslat() {
    if (state.bitti || state.calisiyor) return;
    _yaz(state.baslat(state.etkinSayac, _simdi()));
  }

  void duraklat() {
    if (!state.calisiyor) return;
    _yaz(state.durdur(_simdi()));
  }

  /// Başa döner; süre korunur.
  void sifirla() => _yaz(KronometreDurumu.ilk(state.mod, state.sure, _simdi()));

  /// Satranç saatinde [taraf] oyuncusu hamlesini bitirdi: saati durur,
  /// rakibinki başlar. Başlamamış saatte iki taraf da dokunabilir (dokunan
  /// beyazın karşısındaki oyuncudur); sonra yalnızca sıradaki oyuncu.
  void hamle(int taraf) {
    final d = state;
    if (d.mod != KronometreModu.satrancSaati || d.bitti) return;
    if (taraf < 0 || taraf > 1) return;
    final sira = d.sira;
    if (sira != null && (sira != taraf || !d.calisiyor)) return;
    _yaz(d.baslat(1 - taraf, _simdi()));
  }

  /// Değerleri saatten yeniden hesaplar (zamanlayıcı ve uygulama öne
  /// geldiğinde).
  void yenile() => _yaz(state.kopya(simdi: _simdi()));

  void _yaz(KronometreDurumu yeni) {
    _zamanlayici?.cancel();
    _zamanlayici = null;
    var d = yeni;
    if (!d.bitti &&
        d.calisiyor &&
        d.mod != KronometreModu.ileriSayim &&
        d.kalan(d.etkinSayac) == Duration.zero) {
      d = d.durdur(d.simdi).kopya(bitti: true);
      unawaited(ref.read(kronometreUyariciProvider).uyar());
    }
    state = d;
    final sonraki = d.sonrakiDegisim;
    if (sonraki != null) {
      _zamanlayici = ref.read(zamanlayiciProvider)(sonraki, yenile);
    }
  }
}

/// Kronometre ekranının durumu. Ekran kapanınca bırakılır ve sıfırlanır
/// (ADR-0031 §3).
final kronometreProvider = NotifierProvider.autoDispose
    .family<KronometreNotifier, KronometreDurumu, KronometreAyari>(
      KronometreNotifier.new,
      name: 'kronometreProvider',
    );
