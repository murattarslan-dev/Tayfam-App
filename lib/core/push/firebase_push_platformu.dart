import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/push/push_platformu.dart';

/// Android tarafındaki küçük platform kanalı (`MainActivity.kt`): bildirim
/// kanallarını kurar ve uygulamanın bildirim ayarlarını açar. Ek paket
/// gerekmez (istemci ADR-0019 §4).
const MethodChannel bildirimKanali = MethodChannel('tayfam/bildirim');

/// FCM ile push (istemci ADR-0019). Firebase'e dokunan tek sınıftır.
///
/// - Firebase yapılandırması `android/app/google-services.json`'dan gelir
///   (değerler public; kesin kural 6). Analitik ve otomatik token üretimi
///   manifestte kapalıdır: token yalnızca [token] çağrılınca, yani oturum
///   açık ve izin verilmişken üretilir.
/// - Başlatma başarısız olursa (ör. iOS'ta yapılandırma yok) push o
///   çalışmada kapalıdır; hiçbir çağrı hata fırlatmaz.
/// - Token, mesaj verisi ve bildirim içeriği loglanmaz.
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
  Future<String?> token() async {
    final fcm = await _hazir();
    if (fcm == null) return null;
    try {
      // Manifestte kapalı olan otomatik yenileme, token istenince açılır;
      // çıkışta yeniden kapanır ([tokenSil]).
      await fcm.setAutoInitEnabled(true);
      return await fcm.getToken();
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> tokenSil() async {
    final fcm = await _hazir();
    if (fcm == null) return;
    try {
      await fcm.setAutoInitEnabled(false);
      await fcm.deleteToken();
    } on Exception {
      // Token zaten yok ya da ağ yok; sunucu oturum bitince kendisi siler.
    }
  }

  @override
  Stream<String> get tokenYenilendi {
    final fcm = _fcm;
    return fcm == null ? const Stream.empty() : fcm.onTokenRefresh;
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
    if (defaultTargetPlatform != TargetPlatform.android) return false;
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
