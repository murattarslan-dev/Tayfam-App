import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/auth_api.dart';
import 'package:tayfam/core/api/gen/apis/status_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/butunluk/butunluk_kaniti.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';

/// Oturumun neden kapandığı. Yalnızca yönlendirme ve günlük içindir.
enum OturumKapanisNedeni {
  /// Kullanıcı çıkış yaptı.
  cikis,

  /// Hesap silindi.
  hesapSilindi,

  /// Sunucu oturumu sonlandırdı (WebSocket `4001 session_ended`).
  sunucuSonlandirdi,

  /// Yenilenmiş token'la tekrarlanan istek yine `unauthenticated` aldı.
  yetkisiz,

  /// Yenileme token'ı reddedildi (`invalid-refresh`), süresi geçti ya da
  /// zaten gönderilmişti ve yerine yenisi alınamadı.
  yenilemeReddedildi,

  /// Yenileme isteği gönderildi ama yeni token alınamadı (bağlantı koptu,
  /// sunucu hatası). Gönderilmiş token bir daha gönderilmez.
  yenilemeBasarisiz,
}

/// `SessionStore`'un dışarı verdiği oturum durumu. Token taşımaz.
sealed class OturumOlayi {
  const OturumOlayi();
}

/// Oturum açık. Bayraklar son giriş ya da yenileme yanıtından gelir.
final class OturumAcik extends OturumOlayi {
  const OturumAcik({required this.kayitBekliyor, required this.onayGerekli});

  /// `registration_pending`: kayıt ekranına gidilir.
  final bool kayitBekliyor;

  /// `consent_required`: yeniden onay ekranına gidilir.
  final bool onayGerekli;

  @override
  bool operator ==(Object other) =>
      other is OturumAcik &&
      other.kayitBekliyor == kayitBekliyor &&
      other.onayGerekli == onayGerekli;

  @override
  int get hashCode => Object.hash(kayitBekliyor, onayGerekli);
}

/// Oturum yok. [neden] uygulama açılışında oturum hiç yoksa `null`'dır.
final class OturumKapali extends OturumOlayi {
  const OturumKapali([this.neden]);

  final OturumKapanisNedeni? neden;

  @override
  bool operator ==(Object other) =>
      other is OturumKapali && other.neden == neden;

  @override
  int get hashCode => neden.hashCode;
}

/// Oturum yokken ya da istek sürerken oturum kapandığında fırlatılır.
/// Arayüz giriş ekranına döner; kullanıcıya ayrı hata gösterilmez.
final class OturumYok implements Exception {
  const OturumYok();

  @override
  String toString() => 'OturumYok';
}

/// `POST /v1/auth/refresh` çağrısı. [butunlukTokeni] varsa istekte
/// `integrity_token` olarak gider (istemci ADR-0023).
typedef TokenYenileyici =
    Future<Session> Function(String yenilemeTokeni, {String? butunlukTokeni});

/// Yenileme token'ının özetine bağlı bütünlük kanıtı (istemci ADR-0023).
/// Alınamazsa `null`; hata fırlatmaz ve süresi sınırlıdır.
typedef YenilemeKaniti = Future<String?> Function(String yenilemeTokeni);

/// Yenilemeden önce sunucuya ulaşılabildiğini doğrulayan kimliksiz istek
/// (`GET /v1/status`).
typedef BaglantiYoklayici = Future<void> Function();

/// Token'ların tek sahibi ve tek yenileme noktası (ADR-0005 §3).
///
/// - Token'lar bellekte yalnızca burada, kalıcı olarak yalnızca
///   [TokenDeposu]'nda (mobilde güvenli depo, web'de bellek) tutulur.
/// - Yenileme tek uçuştadır: aynı anda gelen istekler süren yenilemeyi
///   bekler, ikinci yenileme isteği gönderilmez.
/// - Gönderilmiş bir yenileme token'ı hiçbir koşulda ikinci kez
///   gönderilmez (sunucu tolerans dışında oturumu iptal eder). Göndermeden
///   önce kayıt depodan silinir; uygulama yanıt gelmeden kapanırsa açılışta
///   yeniden giriş istenir. Yeni çift alınamazsa oturum kapanır.
/// - Göndermeden önce `GET /v1/status` ile bağlantı yoklanır; bağlantı
///   yoksa token harcanmaz, hata isteğe döner ve oturum açık kalır.
/// - Oturum kapanınca token'lar silinir ve [olaylar]'a [OturumKapali]
///   yayılır; kullanıcıya bağlı durum bunu dinleyerek sıfırlanır
///   (ADR-0001 kural 8).
/// - Bütünlük (istemci ADR-0023): sunucunun bildirdiği
///   `integrity_check_after` geçtiyse yenileme isteğine, bağlantı
///   yoklandıktan sonra ve token harcanmadan önce, [YenilemeKaniti]'nin
///   verdiği kanıt eklenir. Kanıt alınamazsa yenileme kanıtsız gider.
final class SessionStore {
  SessionStore({
    required this._depo,
    required this._yenileyici,
    required this._yoklayici,
    this._kanit,
    DateTime Function()? saat,
    Future<void> Function(Duration sure)? bekle,
    this._gunluk = varsayilanApiGunlugu,
  }) : _saat = saat ?? DateTime.now,
       _bekle = bekle ?? Future<void>.delayed;

  /// Erişim token'ının bitmesine bu kadar kala istekten önce yenilenir.
  static const Duration erkenYenileme = Duration(seconds: 60);

  /// `refresh-conflict` sonrası depoya bakmadan önce beklenen süre.
  static const Duration catismaBeklemesi = Duration(seconds: 1);

  final TokenDeposu _depo;
  final TokenYenileyici _yenileyici;
  final BaglantiYoklayici _yoklayici;
  final YenilemeKaniti? _kanit;
  final DateTime Function() _saat;
  final Future<void> Function(Duration sure) _bekle;
  final ApiGunlugu _gunluk;

  final StreamController<OturumOlayi> _olaylar =
      StreamController<OturumOlayi>.broadcast();

  KayitliOturum? _oturum;

  /// Sunucuya gönderilmiş son yenileme token'ı; bir daha gönderilmez.
  String? _harcanan;

  /// Her açılış ve kapanışta artar; eski oturuma ait bir yenilemenin sonucu
  /// yeni oturumun üstüne yazılmaz.
  int _nesil = 0;

  /// Sonraki yenileme, zamanı gelmemiş olsa da bütünlük kanıtı taşır
  /// (`integrity-required` alındı).
  bool _kanitZorla = false;

  /// `integrity-required` yüzünden kanıtla yenilenmiş son erişim token'ı;
  /// bu token da reddedilirse bir daha yenilenmez.
  String? _butunlukIcinYenilenen;

  Future<void>? _yukleme;
  Future<void>? _ucus;

  /// Oturum açılışı, bayrak değişikliği ve kapanış olayları.
  Stream<OturumOlayi> get olaylar => _olaylar.stream;

  /// Depodaki kaydı (bir kez) okuyup güncel durumu döndürür.
  Future<OturumOlayi> durum() async {
    await _yukle();
    return _durum();
  }

  /// Giriş (`POST /v1/auth/sign-in`) yanıtıyla oturumu açar.
  Future<void> oturumAc(Session oturum) async {
    await _yukle();
    _nesil++;
    _harcanan = null;
    _ucus = null;
    _kanitZorla = false;
    _butunlukIcinYenilenen = null;
    final kayit = _kayit(oturum);
    await _depo.yaz(kayit.kodla());
    _oturum = kayit;
    _yay(_durum());
  }

  /// İstekte kullanılacak erişim token'ı. Bitmesine [erkenYenileme]'den az
  /// kaldıysa önce (tek uçuşta) yeniler.
  ///
  /// Oturum yoksa ya da yenilemede kapandıysa [OturumYok]; bağlantı yoksa
  /// [ApiOffline] / [ApiTimeout] fırlatır.
  Future<String> erisimTokeni() async {
    await _yukle();
    final suren = _ucus;
    if (suren != null) await suren;
    final oturum = _oturum;
    if (oturum == null) throw const OturumYok();
    if (oturum.erisimBitis.difference(_saat()) > erkenYenileme) {
      return oturum.erisimTokeni;
    }
    await _tekUcus();
    return _gecerliToken();
  }

  /// [reddedilen] token `unauthenticated` (ya da WebSocket `4003`) aldı:
  /// başka bir istek zaten yenilemediyse tek uçuşta yeniler ve yeni token'ı
  /// döndürür.
  Future<String> reddedildi(String reddedilen) async {
    await _yukle();
    final oturum = _oturum;
    if (oturum == null) throw const OturumYok();
    if (oturum.erisimTokeni != reddedilen) return oturum.erisimTokeni;
    await _tekUcus();
    return _gecerliToken();
  }

  /// [reddedilen] token `integrity-required` aldı (sunucu `enforce`
  /// modunda; istemci ADR-0023 §5): bir sonraki yenileme zamanından
  /// bağımsız olarak kanıt taşır ve tek uçuşta yapılır. Yeni token'ı
  /// döndürür; bu token için zaten kanıtla yenilendiyse `null` (istek
  /// tekrarlanmaz, hata kullanıcıya gider). Başka bir istek token'ı zaten
  /// değiştirdiyse güncel token döner.
  Future<String?> butunlukGerekti(String reddedilen) async {
    await _yukle();
    final oturum = _oturum;
    if (oturum == null) throw const OturumYok();
    if (reddedilen == _butunlukIcinYenilenen) return null;
    if (oturum.erisimTokeni != reddedilen) return oturum.erisimTokeni;
    _kanitZorla = true;
    await _tekUcus();
    final yeni = _gecerliToken();
    _butunlukIcinYenilenen = yeni;
    return yeni;
  }

  /// Süreden bağımsız yeniler (tek uçuşta). Kayıt tamamlanınca ya da
  /// onay verilince güncel bayrakları almak için çağrılır.
  Future<void> yenile() async {
    await _yukle();
    if (_oturum == null) throw const OturumYok();
    await _tekUcus();
  }

  /// Oturumun kullanıcı kimliği (`Session.user_id`). Kayıt bu alan
  /// eklenmeden önce yazıldıysa bir kez (tek uçuşta) yenilenir. Oturum
  /// yoksa [OturumYok]; bağlantı yoksa [ApiOffline] / [ApiTimeout].
  Future<String> kullaniciKimligi() async {
    await _yukle();
    final oturum = _oturum;
    if (oturum == null) throw const OturumYok();
    final id = oturum.kullaniciId;
    if (id != null) return id;
    await _tekUcus();
    final yeni = _oturum?.kullaniciId;
    if (yeni == null) throw const OturumYok();
    return yeni;
  }

  /// Oturumu kapatır: token'ları bellekten ve depodan siler, [olaylar]'a
  /// [OturumKapali] yayar. Oturum zaten kapalıysa bir şey yaymaz.
  Future<void> kapat(OturumKapanisNedeni neden) async {
    await _yukle();
    await _kapat(neden, _nesil);
  }

  /// Olay akışını kapatır (provider bırakılınca).
  Future<void> dispose() => _olaylar.close();

  // ------------------------------------------------------------------ iç

  String _gecerliToken() {
    final oturum = _oturum;
    if (oturum == null) throw const OturumYok();
    return oturum.erisimTokeni;
  }

  OturumOlayi _durum() {
    final oturum = _oturum;
    if (oturum == null) return const OturumKapali();
    return OturumAcik(
      kayitBekliyor: oturum.kayitBekliyor,
      onayGerekli: oturum.onayGerekli,
    );
  }

  void _yay(OturumOlayi olay) {
    if (!_olaylar.isClosed) _olaylar.add(olay);
  }

  KayitliOturum _kayit(Session oturum) => KayitliOturum(
    erisimTokeni: oturum.accessToken,
    erisimBitis: oturum.accessExpiresAt.toUtc(),
    yenilemeTokeni: oturum.refreshToken,
    yenilemeBitis: oturum.refreshExpiresAt.toUtc(),
    kayitBekliyor: oturum.registrationPending,
    onayGerekli: oturum.consentRequired ?? false,
    kullaniciId: oturum.userId,
    butunlukSonrasi: oturum.integrityCheckAfter?.toUtc(),
  );

  Future<void> _yukle() => _yukleme ??= _depodanOku();

  Future<void> _depodanOku() async {
    final String? metin;
    try {
      metin = await _depo.oku();
    } on Exception {
      // Çözülemeyen kayıt (ör. başka cihazdan taşınmış; #12): silinir,
      // oturum yok sayılır ve giriş istenir.
      _gunluk('oturum: depo okunamadı');
      await _depodanSilSessiz();
      return;
    }
    if (metin == null) return;
    final kayit = KayitliOturum.coz(metin);
    if (kayit == null || !kayit.yenilemeBitis.isAfter(_saat())) {
      await _depodanSilSessiz();
      return;
    }
    _oturum = kayit;
  }

  Future<String?> _depodanOkuSessiz() async {
    try {
      return await _depo.oku();
    } on Exception {
      _gunluk('oturum: depo okunamadı');
      return null;
    }
  }

  Future<void> _depodanSilSessiz() async {
    try {
      await _depo.sil();
    } on Exception {
      _gunluk('oturum: depo silinemedi');
    }
  }

  /// Yalnızca [nesil] hâlâ geçerliyse kapatır.
  Future<void> _kapat(OturumKapanisNedeni neden, int nesil) async {
    if (nesil != _nesil) return;
    final acikti = _oturum != null;
    _nesil++;
    _oturum = null;
    _harcanan = null;
    _ucus = null;
    _kanitZorla = false;
    _butunlukIcinYenilenen = null;
    await _depodanSilSessiz();
    if (acikti) {
      _gunluk('oturum: kapandı (${neden.name})');
      _yay(OturumKapali(neden));
    }
  }

  Future<void> _tekUcus() {
    final suren = _ucus;
    if (suren != null) return suren;
    late final Future<void> ucus;
    ucus = _yenileUcus().whenComplete(() {
      if (identical(_ucus, ucus)) _ucus = null;
    });
    _ucus = ucus;
    return ucus;
  }

  Future<void> _yenileUcus() async {
    final nesil = _nesil;
    final oturum = _oturum;
    if (oturum == null) throw const OturumYok();
    if (oturum.yenilemeTokeni == _harcanan ||
        !oturum.yenilemeBitis.isAfter(_saat())) {
      await _kapat(OturumKapanisNedeni.yenilemeReddedildi, nesil);
      throw const OturumYok();
    }

    // Bağlantı yoksa burada hata döner ve token harcanmaz.
    await _yoklayici();
    if (nesil != _nesil) throw const OturumYok();

    // Kanıt token harcanmadan önce alınır: süresi sınırlıdır ve bu sırada
    // yenileme token'ı henüz gönderilmemiştir (10 sn tolerans etkilenmez).
    final butunlukTokeni = await _butunlukKaniti(oturum);
    if (nesil != _nesil) throw const OturumYok();

    _harcanan = oturum.yenilemeTokeni;
    await _depodanSilSessiz();
    final Session yeni;
    try {
      yeni = await _yenileyici(
        oturum.yenilemeTokeni,
        butunlukTokeni: butunlukTokeni,
      );
    } on Exception catch (hata) {
      if (hata is ApiProblem && hata.type == ProblemType.refreshConflict) {
        await _catismadanSonra(oturum, nesil);
        return;
      }
      final reddedildi =
          hata is ApiProblem && hata.type == ProblemType.invalidRefresh;
      await _kapat(
        reddedildi
            ? OturumKapanisNedeni.yenilemeReddedildi
            : OturumKapanisNedeni.yenilemeBasarisiz,
        nesil,
      );
      throw const OturumYok();
    }
    if (nesil != _nesil) throw const OturumYok();
    await _guncelle(_kayit(yeni), yaz: true);
  }

  /// Zamanı geldiyse (ya da `integrity-required` alındıysa) yenileme
  /// token'ının özetine bağlı kanıt; gerekmiyorsa ya da alınamazsa `null`.
  Future<String?> _butunlukKaniti(KayitliOturum oturum) async {
    final kanit = _kanit;
    if (kanit == null) return null;
    final sonrasi = oturum.butunlukSonrasi;
    final zamani = sonrasi != null && !_saat().isBefore(sonrasi);
    if (!zamani && !_kanitZorla) return null;
    _kanitZorla = false;
    try {
      return await kanit(oturum.yenilemeTokeni);
    } on Exception {
      return null;
    }
  }

  /// `refresh-conflict`: aynı token'la başka bir yenileme (başka bir
  /// süreç) sürüyor. Bir süre bekleyip depodaki daha yeni kaydı alır; yoksa
  /// elde gönderilmemiş token kalmadığı için oturum kapanır.
  Future<void> _catismadanSonra(KayitliOturum eski, int nesil) async {
    await _bekle(catismaBeklemesi);
    if (nesil != _nesil) throw const OturumYok();
    final metin = await _depodanOkuSessiz();
    final depodaki = metin == null ? null : KayitliOturum.coz(metin);
    if (nesil != _nesil) throw const OturumYok();
    if (depodaki != null &&
        depodaki.yenilemeTokeni != eski.yenilemeTokeni &&
        depodaki.yenilemeTokeni != _harcanan) {
      await _guncelle(depodaki, yaz: false);
      return;
    }
    await _kapat(OturumKapanisNedeni.yenilemeReddedildi, nesil);
    throw const OturumYok();
  }

  Future<void> _guncelle(KayitliOturum kayit, {required bool yaz}) async {
    final onceki = _durum();
    _oturum = kayit;
    if (yaz) {
      try {
        await _depo.yaz(kayit.kodla());
      } on Exception {
        // Depoda kayıt yok (gönderimden önce silindi); bu çalışmada bellek
        // yeter, açılışta yeniden giriş istenir. Eski token geri gelmez.
        _gunluk('oturum: depoya yazılamadı');
      }
    }
    final simdiki = _durum();
    if (simdiki != onceki) _yay(simdiki);
  }
}

/// Uygulama boyunca tek `SessionStore` (ADR-0001 kural 4: kalıcı;
/// Riverpod 3'te `autoDispose` olmayan provider kalıcıdır).
final sessionStoreProvider = Provider<SessionStore>(
  _sessionStoreOlustur,
  name: 'sessionStoreProvider',
);

SessionStore _sessionStoreOlustur(Ref ref) {
  final tasima = ref.watch(httpTasimaProvider);
  final auth = AuthApi(tasima);
  final status = StatusApi(tasima);
  final butunluk = ref.watch(butunlukKanitiProvider);
  final oturum = SessionStore(
    depo: ref.watch(tokenDeposuProvider),
    yenileyici: (token, {butunlukTokeni}) => auth.refresh(
      body: RefreshRequest(refreshToken: token, integrityToken: butunlukTokeni),
    ),
    yoklayici: () async {
      await status.getStatus();
    },
    kanit: butunluk.yenileme,
  );
  ref.onDispose(oturum.dispose);
  return oturum;
}
