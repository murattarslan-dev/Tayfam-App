import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/realtime/realtime_olaylari.dart';
import 'package:tayfam/core/realtime/realtime_soketi.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

/// Bağlantının durumu.
enum RealtimeDurumu {
  /// Bağlantı yok (oturum kapalı, arka plan, web ya da yeniden deneme
  /// bekleniyor).
  kapali,

  /// El sıkışması sürüyor ya da `ready` bekleniyor.
  baglaniyor,

  /// `ready` geldi; çerçeve gönderilebilir.
  acik,
}

/// Bağlantı açık değilken çerçeve gönderilmek istendi ya da cevap
/// gelmeden bağlantı koptu. Gönderen aynı `client_request_id` ile REST'e
/// düşer (ADR-0007).
final class RealtimeKapali implements Exception {
  const RealtimeKapali();

  @override
  String toString() => 'RealtimeKapali';
}

/// Tek satırlık günlük. Satırda yalnızca çerçeve türü, hata kodu ya da
/// kapanma kodu bulunur; içerik ve token bulunmaz (CLAUDE.md kesin kural 3).
typedef RealtimeGunlugu = void Function(String satir);

void _varsayilanGunluk(String satir) =>
    developer.log(satir, name: 'tayfam.realtime');

/// Uygulamanın tek WebSocket bağlantısı (ADR-0007; Tayfam-Api ADR-0014).
///
/// - Bağlantı erişim token'ıyla açılır (`Authorization: Bearer`); token
///   `SessionStore`'dan gelir ve bellekte yalnızca bu bağlantının ömrü kadar
///   tutulur, hiçbir yere yazılmaz.
/// - `4003 token_expired`: token `SessionStore.reddedildi` ile (tek uçuşta)
///   yenilenir ve hemen, sessizce yeniden bağlanılır.
/// - `4001 session_ended`: oturum kapatılır; girişe dönülür.
/// - Diğer kopmalar: 1, 2, 4 … en fazla 30 saniye, ±%20 sapmayla yeniden
///   denenir. `ready` gelince sayaç sıfırlanır.
/// - Arka plana geçtikten 30 saniye sonra kapanır, ön plana dönünce yeniden
///   bağlanır.
/// - Her bağlantıda istenen kanallara yeniden abone olunur (en fazla 100;
///   açık ekrandaki kanal önce) ve [Baglandi] yayılır: açık ekranlar
///   kaçırdıklarını REST'ten çeker.
/// - Çerçeve içeriği loglanmaz.
final class RealtimeIstemcisi {
  RealtimeIstemcisi({
    required this.adres,
    required this._baglayici,
    required this._tokenAl,
    required this._reddedildi,
    required this._oturumuKapat,
    required this._zamanlayici,
    Map<String, String> basliklar = const {},
    Random? rastgele,
    this._gunluk = _varsayilanGunluk,
  }) : _basliklar = basliklar,
       _rastgele = rastgele ?? Random.secure();

  /// En fazla abonelik (sözleşme: bağlantı başına 100).
  static const int enFazlaAbonelik = 100;

  /// Çerçeveye cevap bu sürede gelmezse REST'e düşülür.
  static const Duration cevapSuresi = Duration(seconds: 10);

  /// Arka plana geçtikten bu kadar sonra bağlantı kapanır.
  static const Duration arkaPlanSuresi = Duration(seconds: 30);

  /// `recheck_failed` sonrası yeniden abonelikten önce beklenen süre.
  static const Duration yenidenDenetimBeklemesi = Duration(seconds: 5);

  /// En uzun yeniden bağlanma beklemesi.
  static const Duration enUzunBekleme = Duration(seconds: 30);

  /// `wss://…/v1/realtime`.
  final Uri adres;

  final RealtimeBaglayici _baglayici;
  final Future<String> Function() _tokenAl;
  final Future<String> Function(String reddedilen) _reddedildi;
  final Future<void> Function() _oturumuKapat;
  final ZamanlayiciKurucu _zamanlayici;
  final Map<String, String> _basliklar;
  final Random _rastgele;
  final RealtimeGunlugu _gunluk;

  final StreamController<RealtimeOlayi> _olaylar =
      StreamController<RealtimeOlayi>.broadcast();
  final StreamController<RealtimeDurumu> _durumlar =
      StreamController<RealtimeDurumu>.broadcast();

  RealtimeDurumu _durum = RealtimeDurumu.kapali;
  bool _calismali = false;
  bool _onPlanda = true;
  bool _kapandi = false;
  int _nesil = 0;
  int _deneme = 0;
  int _sayac = 0;

  RealtimeSoketi? _soket;
  StreamSubscription<String>? _dinleyici;
  String? _token;
  Timer? _yenidenBaglanma;
  Timer? _arkaPlan;

  final Map<String, _Bekleyen> _bekleyenler = {};

  String? _sahip;
  List<KanalRef> _istenen = const [];
  final Set<KanalRef> _abone = {};
  final Set<KanalRef> _yenidenDenetlenen = {};

  /// Sunucu olayları (yalnızca bellekteki durumu güncellemek için).
  Stream<RealtimeOlayi> get olaylar => _olaylar.stream;

  /// Durum değişiklikleri.
  Stream<RealtimeDurumu> get durumlar => _durumlar.stream;

  /// Şu anki durum.
  RealtimeDurumu get durum => _durum;

  /// Bu bağlantıda abone olunan (ya da abonelik isteği giden) kanallar.
  @visibleForTesting
  Set<KanalRef> get aboneler => Set.unmodifiable(_abone);

  /// Oturum açık ve kayıt tamam: bağlantıyı kurar (ön plandaysa).
  void baslat() {
    if (_kapandi || _calismali) return;
    _calismali = true;
    if (_onPlanda) _hemenBaglan();
  }

  /// Oturum kapandı: bağlantıyı kapatır, abonelikleri ve bekleyen
  /// istekleri bırakır.
  void durdur() {
    _calismali = false;
    _arkaPlan?.cancel();
    _arkaPlan = null;
    _sahip = null;
    _istenen = const [];
    _yenidenDenetlenen.clear();
    _soketiKapat();
  }

  /// Uygulama arka plana geçti: [arkaPlanSuresi] sonra bağlantı kapanır.
  void arkaPlana() {
    if (!_onPlanda) return;
    _onPlanda = false;
    _arkaPlan?.cancel();
    _arkaPlan = _zamanlayici(arkaPlanSuresi, () {
      _arkaPlan = null;
      if (!_onPlanda) _soketiKapat();
    });
  }

  /// Uygulama ön plana döndü: bağlantı yoksa hemen yeniden bağlanır.
  void onPlana() {
    if (_onPlanda) return;
    _onPlanda = true;
    _arkaPlan?.cancel();
    _arkaPlan = null;
    if (_calismali && _soket == null) _hemenBaglan();
  }

  /// [sahip]'in (aktif tayfanın kanal listesi) istediği abonelikler.
  /// [oncelikli] (açık ekrandaki kanal) 100 sınırında önce gelir. Eksik
  /// abonelikler kurulur, fazlası bırakılır (ADR-0007 "Abonelikler").
  void abonelikleriAyarla(
    String sahip,
    List<KanalRef> kanallar, {
    KanalRef? oncelikli,
  }) {
    _sahip = sahip;
    final sirali = <KanalRef>[?oncelikli, ...kanallar];
    final tekil = <KanalRef>{};
    for (final k in sirali) {
      if (tekil.length >= enFazlaAbonelik) break;
      tekil.add(k);
    }
    _istenen = List.unmodifiable(tekil);
    _abonelikleriEsitle();
  }

  /// [sahip]'in abonelikleri (başka bir sahip devralmadıysa) bırakılır.
  void abonelikleriBirak(String sahip) {
    if (_sahip != sahip) return;
    _sahip = null;
    _istenen = const [];
    _abonelikleriEsitle();
  }

  /// Kanal mesajını `send` çerçevesiyle gönderir; sunucunun yazdığı
  /// mesajı döndürür. Bağlantı açık değilse ya da kopunca [RealtimeKapali],
  /// [cevapSuresi]'nde cevap gelmezse [TimeoutException], hata çerçevesinde
  /// [ApiProblem] fırlatır.
  Future<ChannelMessage> kanalaGonder({
    required String tayfaId,
    required String kanalId,
    required String metin,
    required String istekKimligi,
  }) async {
    final veri = await _istek('send', {
      'tayfa_id': tayfaId,
      'channel_id': kanalId,
      'body': metin,
      'client_request_id': istekKimligi,
    });
    return gonderilenKanalMesaji(veri);
  }

  /// Birebir mesajı `dm.send` çerçevesiyle gönderir (abonelik gerekmez).
  /// Hatalar [kanalaGonder] ile aynıdır.
  Future<DmGonderimi> dmGonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) async {
    final veri = await _istek('dm.send', {
      'recipient_user_id': aliciId,
      'body': metin,
      'client_request_id': istekKimligi,
    });
    return gonderilenDm(veri);
  }

  /// Bağlantıyı ve akışları kapatır (provider bırakılınca).
  Future<void> dispose() async {
    _kapandi = true;
    durdur();
    await _olaylar.close();
    await _durumlar.close();
  }

  // ------------------------------------------------------------------ iç

  void _durumuAyarla(RealtimeDurumu yeni) {
    if (_durum == yeni) return;
    _durum = yeni;
    if (!_durumlar.isClosed) _durumlar.add(yeni);
  }

  void _yay(RealtimeOlayi olay) {
    if (!_olaylar.isClosed) _olaylar.add(olay);
  }

  void _hemenBaglan() {
    _yenidenBaglanma?.cancel();
    _yenidenBaglanma = null;
    _deneme = 0;
    unawaited(_baglan());
  }

  Future<void> _baglan() async {
    if (!_calismali || !_onPlanda || _soket != null) return;
    final nesil = ++_nesil;
    _durumuAyarla(RealtimeDurumu.baglaniyor);
    final String token;
    try {
      token = await _tokenAl();
    } on OturumYok {
      _durumuAyarla(RealtimeDurumu.kapali);
      return;
    } on Exception {
      if (nesil != _nesil) return;
      _durumuAyarla(RealtimeDurumu.kapali);
      _yenidenPlanla();
      return;
    }
    if (nesil != _nesil || !_calismali || !_onPlanda || _soket != null) {
      return;
    }

    final RealtimeSoketi soket;
    try {
      soket = _baglayici(adres, {
        ..._basliklar,
        'Authorization': 'Bearer $token',
      });
    } on Exception {
      _gunluk('realtime: bağlantı açılamadı');
      _durumuAyarla(RealtimeDurumu.kapali);
      _yenidenPlanla();
      return;
    }
    _soket = soket;
    _token = token;
    _dinleyici = soket.gelen.listen(
      _gelen,
      onError: (Object _) {},
      onDone: () => _kopunca(soket),
      cancelOnError: false,
    );
    try {
      await soket.hazir;
    } on Exception {
      _kopunca(soket);
    }
  }

  void _yenidenPlanla() {
    if (!_calismali || !_onPlanda || _kapandi) return;
    _yenidenBaglanma?.cancel();
    final sure = yenidenBaglanmaBeklemesi(_deneme++, _rastgele);
    _yenidenBaglanma = _zamanlayici(sure, () {
      _yenidenBaglanma = null;
      unawaited(_baglan());
    });
  }

  /// Bizim kapattığımız bağlantı: yeniden bağlanılmaz.
  void _soketiKapat() {
    _yenidenBaglanma?.cancel();
    _yenidenBaglanma = null;
    _nesil++;
    final soket = _soket;
    _baglantiyiBirak();
    _durumuAyarla(RealtimeDurumu.kapali);
    if (soket != null) unawaited(_sessizKapat(soket));
  }

  Future<void> _sessizKapat(RealtimeSoketi soket) async {
    try {
      await soket.kapat(1000);
    } on Exception {
      // Zaten kapalı.
    }
  }

  void _baglantiyiBirak() {
    _soket = null;
    _token = null;
    unawaited(_dinleyici?.cancel());
    _dinleyici = null;
    _abone.clear();
    final bekleyenler = _bekleyenler.values.toList();
    _bekleyenler.clear();
    for (final b in bekleyenler) {
      b.bitir(hata: const RealtimeKapali());
    }
  }

  /// Sunucu ya da ağ bağlantıyı kapattı.
  void _kopunca(RealtimeSoketi soket) {
    if (!identical(_soket, soket)) return;
    final token = _token;
    _baglantiyiBirak();
    _durumuAyarla(RealtimeDurumu.kapali);
    final kod = soket.kapanmaKodu;
    _gunluk('realtime: kapandı (${kod ?? 'kod yok'})');
    switch (kod) {
      case 4001:
        _calismali = false;
        unawaited(_oturumuKapat());
      case 4003:
        unawaited(_tokenYenileVeBaglan(token));
      default:
        _yenidenPlanla();
    }
  }

  Future<void> _tokenYenileVeBaglan(String? eski) async {
    try {
      if (eski != null) await _reddedildi(eski);
    } on OturumYok {
      return;
    } on Exception {
      _yenidenPlanla();
      return;
    }
    if (_calismali && _onPlanda) _hemenBaglan();
  }

  void _gelen(String metin) {
    final c = cerceveyiCoz(metin);
    if (c == null) {
      _gunluk('realtime: çözülemeyen çerçeve');
      return;
    }
    final kimlik = c.kimlik;
    if (kimlik != null) {
      final bekleyen = _bekleyenler.remove(kimlik);
      if (bekleyen != null) {
        if (c.tur == 'error') {
          bekleyen.bitir(hata: cerceveHatasi(c.veri));
        } else {
          bekleyen.bitir(veri: c.veri);
        }
        return;
      }
    }
    if (c.tur == 'error') {
      final kod = c.veri['code'];
      _gunluk('realtime: hata ${kod is String ? kod : '?'}');
      return;
    }
    final olay = olayaCevir(c);
    if (olay == null) return;
    switch (olay) {
      case Baglandi():
        _deneme = 0;
        _durumuAyarla(RealtimeDurumu.acik);
        _abonelikleriEsitle();
      case AbonelikBitti(:final kanal, :final neden):
        _abone.remove(kanal);
        if (neden == AbonelikBitisNedeni.erisimKalmadi) {
          _istenen = List.unmodifiable(_istenen.where((k) => k != kanal));
        } else if (neden == AbonelikBitisNedeni.denetlenemedi) {
          _yenidenDenetle(kanal);
        }
      default:
        break;
    }
    _yay(olay);
  }

  /// `recheck_failed`: 5 saniye sonra bir kez yeniden abone olunur.
  void _yenidenDenetle(KanalRef kanal) {
    if (!_yenidenDenetlenen.add(kanal)) return;
    _zamanlayici(yenidenDenetimBeklemesi, () {
      if (_istenen.contains(kanal) &&
          !_abone.contains(kanal) &&
          _durum == RealtimeDurumu.acik) {
        _aboneOl(kanal);
      }
    });
  }

  void _abonelikleriEsitle() {
    if (_durum != RealtimeDurumu.acik) return;
    final istenen = _istenen.toSet();
    for (final k in _abone.difference(istenen).toList()) {
      _abone.remove(k);
      unawaited(
        _istek('unsubscribe', {
          'tayfa_id': k.tayfaId,
          'channel_id': k.kanalId,
        }).then((_) {}, onError: (Object _) {}),
      );
    }
    for (final k in _istenen) {
      if (!_abone.contains(k)) _aboneOl(k);
    }
  }

  void _aboneOl(KanalRef kanal) {
    _abone.add(kanal);
    unawaited(
      _istek('subscribe', {
        'tayfa_id': kanal.tayfaId,
        'channel_id': kanal.kanalId,
      }).then((_) {}, onError: (Object hata) => _abonelikHatasi(kanal, hata)),
    );
  }

  void _abonelikHatasi(KanalRef kanal, Object hata) {
    if (hata is RealtimeKapali) return;
    _abone.remove(kanal);
    if (hata is ApiProblem) {
      _gunluk('realtime: abonelik hatası ${hata.type.name}');
      if (hata.type == ProblemType.tayfaNotFound ||
          hata.type == ProblemType.channelNotFound) {
        _istenen = List.unmodifiable(_istenen.where((k) => k != kanal));
        _yay(
          AbonelikBitti(kanal: kanal, neden: AbonelikBitisNedeni.bulunamadi),
        );
      }
    }
  }

  Future<Map<String, Object?>> _istek(String tur, Map<String, Object?> veri) {
    final soket = _soket;
    if (soket == null || _durum != RealtimeDurumu.acik) {
      return Future.error(const RealtimeKapali());
    }
    final kimlik = 'c${++_sayac}';
    final bekleyen = _Bekleyen();
    _bekleyenler[kimlik] = bekleyen;
    bekleyen.zamanAsimi = _zamanlayici(cevapSuresi, () {
      if (_bekleyenler.remove(kimlik) != null) {
        _gunluk('realtime: $tur cevapsız');
        bekleyen.bitir(hata: TimeoutException(null, cevapSuresi));
      }
    });
    try {
      soket.gonder(cerceveYaz(tur, kimlik, veri));
    } on Exception {
      _bekleyenler.remove(kimlik);
      bekleyen.bitir(hata: const RealtimeKapali());
    }
    return bekleyen.tamamlayici.future;
  }
}

final class _Bekleyen {
  final Completer<Map<String, Object?>> tamamlayici = Completer();
  Timer? zamanAsimi;

  void bitir({Map<String, Object?>? veri, Object? hata}) {
    zamanAsimi?.cancel();
    if (tamamlayici.isCompleted) return;
    if (hata != null) {
      tamamlayici.completeError(hata);
    } else {
      tamamlayici.complete(veri ?? const {});
    }
  }
}

/// [deneme]'inci (0'dan) yeniden bağlanma öncesi bekleme: 1, 2, 4 … en
/// fazla 30 saniye, ±%20 rastgele sapma (ADR-0007).
@visibleForTesting
Duration yenidenBaglanmaBeklemesi(int deneme, Random rastgele) {
  final us = deneme.clamp(0, 5);
  final taban = min(1 << us, RealtimeIstemcisi.enUzunBekleme.inSeconds);
  final carpan = 0.8 + 0.4 * rastgele.nextDouble();
  return Duration(milliseconds: (taban * 1000 * carpan).round());
}
