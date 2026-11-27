import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/push/push_platformu.dart';

/// Yerel taraftaki küçük platform kanalı: Android'de (`MainActivity.kt`)
/// bildirim kanallarını kurar ve uygulamanın bildirim ayarlarını açar;
/// iOS'ta (`AppDelegate.swift`) yalnızca ayarları açar. Ek paket gerekmez
/// (istemci ADR-0019 §4, iOS notu).
const MethodChannel bildirimKanali = MethodChannel('tayfam/bildirim');

/// FCM ile push (istemci ADR-0019). Firebase'e dokunan tek sınıftır.
///
/// - Firebase yapılandırması `android/app/google-services.json`'dan ve
///   `ios/Runner/GoogleService-Info.plist`'ten gelir (değerler public; kesin
///   kural 6). Otomatik FCM kaydı manifestte ve `Info.plist`'te kapalıdır:
///   FCM (iOS'ta APNs) kaydı yalnızca [kaydol] çağrılınca, yani oturum açık
///   ve izin verilmişken yapılır.
/// - firebase_messaging 17'nin FID API'si (`register` / `unregister` /
///   `onRegistered`) kullanılır; kullanımdan kalkan kayıt token'ı API'si
///   (`getToken` / `deleteToken` / `onTokenRefresh`) Firebase'in uyarısına
///   uygun olarak hiç çağrılmaz (Tayfam-Api ADR-0036).
/// - Başlatma başarısız olursa push o çalışmada kapalıdır; hiçbir çağrı
///   hata fırlatmaz.
/// - Kimlik (FID), mesaj verisi ve bildirim içeriği loglanmaz.
final class FirebasePushPlatformu implements PushPlatformu {
  FirebasePushPlatformu({this._kanal = bildirimKanali});

  final MethodChannel _kanal;
  Future<bool>? _baslatma;
  FirebaseMessaging? _fcm;

  @override
  bool get etkin => true;

  @override
  Future<bool> baslat() => _baslatma ??= _baslat();

  Future<bool> _baslat() async {
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;
      return true;
    } on Exception {
      return false;
    }
  }

  Future<FirebaseMessaging?> _hazir() async => await baslat() ? _fcm : null;

  @override
  Future<BildirimIzni> izin() async {
    final fcm = await _hazir();
    if (fcm == null) return BildirimIzni.reddedildi;
    try {
      final ayar = await fcm.getNotificationSettings();
      return _izneCevir(ayar.authorizationStatus);
    } on Exception {
      return BildirimIzni.reddedildi;
    }
  }

  @override
  Future<BildirimIzni> izinIste() async {
    final fcm = await _hazir();
    if (fcm == null) return BildirimIzni.reddedildi;
    try {
      final ayar = await fcm.requestPermission();
      return _izneCevir(ayar.authorizationStatus);
    } on Exception {
      return BildirimIzni.reddedildi;
    }
  }

  @override
  Future<void> kaydol() async {
    final fcm = await _hazir();
    if (fcm == null) return;
    try {
      // Manifestte kapalı olan otomatik kayıt, kayıt istenince açılır;
      // çıkışta yeniden kapanır ([kaydiSil]). Kimlik [kimlikKaydedildi]
      // akışından gelir (firebase_messaging 17; Tayfam-Api ADR-0036).
      await fcm.setAutoInitEnabled(true);
      await fcm.register();
    } on Exception {
      // Kayıt olmadı; bir sonraki açılışta ya da izin verilince yeniden.
    }
  }

  @override
  Future<void> kaydiSil() async {
    final fcm = await _hazir();
    if (fcm == null) return;
    try {
      await fcm.setAutoInitEnabled(false);
      await fcm.unregister();
    } on Exception {
      // Kayıt zaten yok ya da ağ yok; sunucu oturum bitince kendisi siler.
    }
  }

  @override
  Stream<String> get kimlikKaydedildi {
    final fcm = _fcm;
    return fcm == null ? const Stream.empty() : fcm.onRegistered;
  }

  @override
  Future<PushVerisi?> ilkDokunulan() async {
    final fcm = await _hazir();
    if (fcm == null) return null;
    try {
      final mesaj = await fcm.getInitialMessage();
      return mesaj == null ? null : _veri(mesaj);
    } on Exception {
      return null;
    }
  }

  @override
  Stream<PushVerisi> get dokunulanlar => _fcm == null
      ? const Stream.empty()
      : FirebaseMessaging.onMessageOpenedApp.map(_veri);

  @override
  Stream<PushVerisi> get onPlandaGelenler => _fcm == null
      ? const Stream.empty()
      : FirebaseMessaging.onMessage.map(_veri);

  @override
  Future<void> kanallariKur(List<BildirimKanali> kanallar) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _kanal.invokeMethod<void>('kanallariKur', [
        for (final k in kanallar) k.kanalVerisi,
      ]);
    } on PlatformException {
      // Kanal kurulamazsa FCM varsayılan kanalı kullanır.
    } on MissingPluginException {
      // Yerel taraf yok (test, başka platform).
    }
  }

  @override
  Future<bool> ayarlariAc() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      return await _kanal.invokeMethod<bool>('ayarlariAc') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

BildirimIzni _izneCevir(AuthorizationStatus durum) => switch (durum) {
  AuthorizationStatus.authorized ||
  AuthorizationStatus.provisional => BildirimIzni.verildi,
  AuthorizationStatus.notDetermined => BildirimIzni.sorulmadi,
  _ => BildirimIzni.reddedildi,
};

/// Mesajın `data`'sından yalnızca metin değerler; geri kalanı atılır.
PushVerisi _veri(RemoteMessage mesaj) => {
  for (final MapEntry(:key, :value) in mesaj.data.entries)
    if (value is String) key: value,
};
