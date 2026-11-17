import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sunucuya push kimliğini kaydeden ve silen uçlar (Tayfam-Api ADR-0019
/// §1, ADR-0036).
abstract interface class PushTokenDeposu {
  /// `PUT /v1/me/push-token`: bu oturumun push kimliğini (FID) kaydeder ya
  /// da yeniler.
  Future<void> kaydet(String kimlik);

  /// `DELETE /v1/me/push-token`: bu oturumun push kaydını siler.
  Future<void> sil();
}

/// Üretilmiş uç sınıfıyla, tek `ApiClient` üzerinden (ADR-0005).
final class ApiPushTokenDeposu implements PushTokenDeposu {
  ApiPushTokenDeposu(ApiTransport istemci, {required this.platform})
    : _me = MeApi(istemci);

  final MeApi _me;

  /// Sözleşmedeki platform (yalnızca mobil; ADR-0011).
  final PushTokenRegistrationPlatform platform;

  /// firebase_messaging 17+ `onRegistered` FID verir; sunucu onu
  /// `message.fid` ile hedefler (Tayfam-Api ADR-0036). Kayıt token'ı
  /// (varsayılan tür) bu istemciden artık gönderilmez.
  @override
  Future<void> kaydet(String kimlik) => _me.putPushToken(
    body: PushTokenRegistration(
      token: kimlik,
      platform: platform,
      tokenType: PushTokenRegistrationTokenType.fid,
    ),
  );

  @override
  Future<void> sil() => _me.deletePushToken();
}

/// Uygulamanın push token deposu. Bugün yalnızca Android hedefidir
/// (ADR-0011); iOS derlemesinde push açılınca platform `ios` olur.
final pushTokenDeposuProvider = Provider<PushTokenDeposu>(
  (ref) => ApiPushTokenDeposu(
    ref.watch(apiClientProvider),
    platform: PushTokenRegistrationPlatform.android,
  ),
  name: 'pushTokenDeposuProvider',
);

/// Üç Android bildirim kanalı (Tayfam-Api ADR-0019 §4). Ad ve açıklama
/// çeviri dosyasındadır; kimlikler sunucunun gönderdikleridir.
List<BildirimKanali> bildirimKanallari(AppLocalizations m) => [
  BildirimKanali(
    id: 'tayfam_messages',
    ad: m.push_kanal_mesajlar,
    aciklama: m.push_kanal_mesajlar_aciklama,
    yuksekOncelik: true,
  ),
  BildirimKanali(
    id: 'tayfam_alerts',
    ad: m.push_kanal_uyarilar,
    aciklama: m.push_kanal_uyarilar_aciklama,
    yuksekOncelik: true,
  ),
  BildirimKanali(
    id: 'tayfam_general',
    ad: m.push_kanal_genel,
    aciklama: m.push_kanal_genel_aciklama,
    yuksekOncelik: false,
  ),
];

/// Push kimliğinin (FID) sunucudaki kaydını oturumla eşit tutar (istemci
/// ADR-0019 §2).
///
/// - Uygulama açılınca altyapı başlatılır, kanallar kurulur ve
///   `onRegistered` dinlenmeye başlar (Firebase: `register()`'dan önce).
/// - Oturum açık olunca (giriş, her açılış) ve izin verilmişse FCM'e
///   kaydolunur; gelen FID `PUT` edilir. FID değişince (ya da her
///   `register()`'da yeniden yayınlanınca) yine `PUT` edilir; aynı oturumda
///   zaten gönderilmiş kimlik tekrar gönderilmez.
/// - Çıkışta [cikisOncesi] sunucudaki kaydı siler (`DELETE`) ve cihazın
///   FCM kaydını kaldırır (`unregister`). Oturum başka bir yoldan kapanırsa
///   (sunucu kapattı, yenileme reddedildi, hesap silindi) cihazın kaydı
///   yine kaldırılır; sunucu kendi kaydını oturumla birlikte siler.
/// - İşler sırayla yürür; hata fırlatmaz. Kimlik loglanmaz ve diske
///   yazılmaz; yalnızca platformun kendi deposunda durur.
final class PushKaydi {
  PushKaydi({
    required this._platform,
    required this._depo,
    required this._oturumAcik,
    required this._metinler,
    this._gunluk = varsayilanApiGunlugu,
  });

  final PushPlatformu _platform;
  final PushTokenDeposu _depo;
  final bool Function() _oturumAcik;
  final AppLocalizations _metinler;
  final ApiGunlugu _gunluk;

  Future<void> _sira = Future<void>.value();
  StreamSubscription<String>? _kayitlar;
  bool _kapandi = false;

  /// Bu oturumda sunucuya kaydedilmiş son kimlik (yalnızca bellekte).
  String? _gonderilen;

  /// Altyapıyı başlatır, kanalları kurar ve kimlik kaydını dinler.
  Future<void> baslat() => _sirala(() async {
    if (!_platform.etkin || !await _platform.baslat()) return;
    await _platform.kanallariKur(bildirimKanallari(_metinler));
    if (_kapandi) return;
    _kayitlar = _platform.kimlikKaydedildi.listen(_kimlikKaydedildi);
  });

  /// Oturum açıksa ve izin verilmişse FCM'e kaydolur; kimlik
  /// [PushPlatformu.kimlikKaydedildi]'den gelince sunucuya kaydedilir.
  Future<void> esitle() => _sirala(() async {
    if (!_platform.etkin || !_oturumAcik()) return;
    if (await _platform.izin() != BildirimIzni.verildi) return;
    await _platform.kaydol();
  });

  /// Çıkıştan hemen önce: sunucudaki kaydı siler ve cihazın FCM kaydını
  /// kaldırır.
  /// Sunucuya ulaşılamazsa da devam eder (oturum kapanınca sunucu siler).
  Future<void> cikisOncesi() => _sirala(() async {
    if (!_platform.etkin) return;
    try {
      await _depo.sil();
    } on Exception {
      _gunluk('push: token sunucudan silinemedi');
    }
    _gonderilen = null;
    await _platform.kaydiSil();
  });

  /// Oturum kapandı: cihazın FCM kaydı kaldırılır; bir sonraki oturum
  /// yeniden kaydolur.
  Future<void> oturumKapandi() => _sirala(() async {
    if (!_platform.etkin) return;
    _gonderilen = null;
    await _platform.kaydiSil();
  });

  /// Dinlemeyi bırakır.
  void dispose() {
    _kapandi = true;
    unawaited(_kayitlar?.cancel());
  }

  void _kimlikKaydedildi(String kimlik) {
    unawaited(
      _sirala(() async {
        if (!_oturumAcik() || kimlik == _gonderilen) return;
        if (await _platform.izin() != BildirimIzni.verildi) return;
        await _kaydet(kimlik);
      }),
    );
  }

  Future<void> _kaydet(String kimlik) async {
    try {
      await _depo.kaydet(kimlik);
      _gonderilen = kimlik;
    } on Exception {
      // Bir sonraki açılışta ya da yenilemede yeniden denenir.
      _gunluk('push: token kaydedilemedi');
    }
  }

  Future<void> _sirala(Future<void> Function() islem) {
    final sonraki = _sira.then((_) async {
      try {
        await islem();
      } on Exception {
        _gunluk('push: işlem tamamlanamadı');
      }
    });
    _sira = sonraki;
    return sonraki;
  }
}

/// Uygulama boyunca tek [PushKaydi] (kalıcı; ADR-0001 kural 4). Oturum
/// durumunu izler: açılınca eşitler, kapanınca cihazın FCM kaydını kaldırır.
final pushKaydiProvider = Provider<PushKaydi>((ref) {
  final kayit = PushKaydi(
    platform: ref.watch(pushPlatformuProvider),
    depo: ref.watch(pushTokenDeposuProvider),
    oturumAcik: () => ref.read(oturumDurumuProvider) == OturumDurumu.acik,
    metinler: lookupAppLocalizations(const Locale('tr', 'TR')),
  );
  ref.onDispose(kayit.dispose);
  unawaited(kayit.baslat());
  ref.listen<OturumDurumu>(oturumDurumuProvider, (onceki, simdiki) {
    if (simdiki == OturumDurumu.acik) {
      unawaited(kayit.esitle());
    } else if (simdiki == OturumDurumu.girisYok &&
        onceki != null &&
        onceki != OturumDurumu.yukleniyor &&
        onceki != OturumDurumu.girisYok) {
      unawaited(kayit.oturumKapandi());
    }
  }, fireImmediately: true);
  return kayit;
}, name: 'pushKaydiProvider');
