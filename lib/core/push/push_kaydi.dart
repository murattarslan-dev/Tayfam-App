import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sunucuya push token'ı kaydeden ve silen uçlar (Tayfam-Api ADR-0019 §1).
abstract interface class PushTokenDeposu {
  /// `PUT /v1/me/push-token`: bu oturumun token'ını kaydeder ya da yeniler.
  Future<void> kaydet(String token);

  /// `DELETE /v1/me/push-token`: bu oturumun token'ını siler.
  Future<void> sil();
}

/// Üretilmiş uç sınıfıyla, tek `ApiClient` üzerinden (ADR-0005).
final class ApiPushTokenDeposu implements PushTokenDeposu {
  ApiPushTokenDeposu(ApiClient istemci, {required this.platform})
    : _me = MeApi(istemci);

  final MeApi _me;

  /// Sözleşmedeki platform (yalnızca mobil; ADR-0011).
  final PushTokenRegistrationPlatform platform;

  @override
  Future<void> kaydet(String token) => _me.putPushToken(
    body: PushTokenRegistration(token: token, platform: platform),
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

/// Push token'ının sunucudaki kaydını oturumla eşit tutar (istemci
/// ADR-0019 §2).
///
/// - Uygulama açılınca altyapı başlatılır ve kanallar kurulur.
/// - Oturum açık olunca (giriş, her açılış) ve izin verilmişse token alınır
///   ve `PUT` edilir; FCM token'ı yenilenince yenisi `PUT` edilir.
/// - Çıkışta [cikisOncesi] sunucudaki kaydı siler (`DELETE`) ve cihazdaki
///   FCM token'ını geçersiz kılar. Oturum başka bir yoldan kapanırsa
///   (sunucu kapattı, yenileme reddedildi, hesap silindi) cihazdaki token
///   yine silinir; sunucu kendi kaydını oturumla birlikte siler.
/// - İşler sırayla yürür; hata fırlatmaz. Token loglanmaz ve diske
///   yazılmaz; yalnızca platformun kendi deposunda durur.
final class PushKaydi {
  PushKaydi({
    required PushPlatformu platform,
    required PushTokenDeposu depo,
    required bool Function() oturumAcik,
    required AppLocalizations metinler,
    ApiGunlugu gunluk = varsayilanApiGunlugu,
  }) : _platform = platform,
       _depo = depo,
       _oturumAcik = oturumAcik,
       _metinler = metinler,
       _gunluk = gunluk;

  final PushPlatformu _platform;
  final PushTokenDeposu _depo;
  final bool Function() _oturumAcik;
  final AppLocalizations _metinler;
  final ApiGunlugu _gunluk;

  Future<void> _sira = Future<void>.value();
  StreamSubscription<String>? _yenileme;
  bool _kapandi = false;

  /// Altyapıyı başlatır, kanalları kurar ve token yenilemesini dinler.
  Future<void> baslat() => _sirala(() async {
    if (!_platform.etkin || !await _platform.baslat()) return;
    await _platform.kanallariKur(bildirimKanallari(_metinler));
    if (_kapandi) return;
    _yenileme = _platform.tokenYenilendi.listen(_tokenYenilendi);
  });

  /// Oturum açıksa ve izin verilmişse token'ı sunucuya kaydeder.
  Future<void> esitle() => _sirala(() async {
    if (!_platform.etkin || !_oturumAcik()) return;
    if (await _platform.izin() != BildirimIzni.verildi) return;
    final token = await _platform.token();
    if (token == null || !_oturumAcik()) return;
    await _kaydet(token);
  });

  /// Çıkıştan hemen önce: sunucudaki kaydı ve cihazdaki token'ı siler.
  /// Sunucuya ulaşılamazsa da devam eder (oturum kapanınca sunucu siler).
  Future<void> cikisOncesi() => _sirala(() async {
    if (!_platform.etkin) return;
    try {
      await _depo.sil();
    } on Exception {
      _gunluk('push: token sunucudan silinemedi');
    }
    await _platform.tokenSil();
  });

  /// Oturum kapandı: cihazdaki token geçersiz kılınır; bir sonraki
  /// oturum yeni token alır.
  Future<void> oturumKapandi() => _sirala(() async {
    if (!_platform.etkin) return;
    await _platform.tokenSil();
  });

  /// Dinlemeyi bırakır.
  void dispose() {
    _kapandi = true;
    unawaited(_yenileme?.cancel());
  }

  void _tokenYenilendi(String token) {
    unawaited(
      _sirala(() async {
        if (!_oturumAcik()) return;
        if (await _platform.izin() != BildirimIzni.verildi) return;
        await _kaydet(token);
      }),
    );
  }

  Future<void> _kaydet(String token) async {
    try {
      await _depo.kaydet(token);
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
/// durumunu izler: açılınca eşitler, kapanınca cihazdaki token'ı siler.
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
