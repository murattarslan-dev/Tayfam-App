import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cihazdaki bildirim izninin durumu (istemci ADR-0019 §3).
enum BildirimIzni {
  /// Bildirim gösterilebilir.
  verildi,

  /// Kullanıcı reddetti ya da sistem ayarından kapattı.
  reddedildi,

  /// Sistem penceresi henüz hiç gösterilmedi (Android 13+).
  sorulmadi,
}

/// Android bildirim kanalı (Tayfam-Api ADR-0019 §4). Ad ve açıklama
/// çeviri dosyasından gelir.
@immutable
final class BildirimKanali {
  const BildirimKanali({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.yuksekOncelik,
  });

  /// Sunucunun gönderdiği kanal kimliği (`tayfam_messages` …).
  final String id;

  /// Sistem ayarlarında görünen ad.
  final String ad;

  /// Sistem ayarlarında görünen açıklama.
  final String aciklama;

  /// Yüksek önem (sesli, üstten görünen); yoksa varsayılan önem.
  final bool yuksekOncelik;

  /// Platform kanalına giden biçim.
  Map<String, Object> get kanalVerisi => {
    'id': id,
    'ad': ad,
    'aciklama': aciklama,
    'yuksek': yuksekOncelik,
  };

  @override
  bool operator ==(Object other) =>
      other is BildirimKanali &&
      other.id == id &&
      other.ad == ad &&
      other.aciklama == aciklama &&
      other.yuksekOncelik == yuksekOncelik;

  @override
  int get hashCode => Object.hash(id, ad, aciklama, yuksekOncelik);
}

/// Push mesajının `data` alanı: yalnızca metin değerler. Sunucudan gelen
/// girdidir; kullanan doğrular (CLAUDE.md, "Doğrula").
typedef PushVerisi = Map<String, String>;

/// Push altyapısının (FCM) uygulamaya bakan yüzü. Firebase'e yalnızca
/// `FirebasePushPlatformu` dokunur; testler ve web derlemesi
/// [KapaliPushPlatformu] ya da sahte bir uygulama kullanır.
///
/// Token hiçbir zaman loglanmaz ve diske yazılmaz (kesin kural 3).
abstract interface class PushPlatformu {
  /// Bu derlemede push var mı. `false` ise hiçbir çağrı bir şey yapmaz.
  bool get etkin;

  /// Altyapıyı (bir kez) başlatır. Başlatılamazsa `false`; push o
  /// çalışmada kapalı kalır, uygulama etkilenmez.
  Future<bool> baslat();

  /// Bildirim izninin güncel durumu.
  Future<BildirimIzni> izin();

  /// Sistem izin penceresini gösterir (gerekiyorsa) ve sonucu döndürür.
  Future<BildirimIzni> izinIste();

  /// Bu cihazın FCM kayıt token'ı; alınamazsa `null`.
  Future<String?> token();

  /// FCM token'ını cihazda geçersiz kılar; sonraki [token] yenisini verir.
  Future<void> tokenSil();

  /// FCM token'ı yenilenince yeni değer.
  Stream<String> get tokenYenilendi;

  /// Uygulama kapalıyken dokunulup açılan bildirimin verisi (bir kez).
  Future<PushVerisi?> ilkDokunulan();

  /// Uygulama arka plandayken dokunulan bildirimlerin verisi.
  Stream<PushVerisi> get dokunulanlar;

  /// Uygulama ön plandayken gelen mesajların verisi; sistem bildirimi
  /// gösterilmez.
  Stream<PushVerisi> get onPlandaGelenler;

  /// Android bildirim kanallarını kurar (varsa ad ve açıklamayı günceller).
  Future<void> kanallariKur(List<BildirimKanali> kanallar);

  /// Uygulamanın sistemdeki bildirim ayarlarını açar; açılamazsa `false`.
  Future<bool> ayarlariAc();
}

/// Push'un olmadığı derleme: web geliştirme derlemesi (ADR-0011) ve
/// testlerin varsayılanı. Hiçbir şey yapmaz.
final class KapaliPushPlatformu implements PushPlatformu {
  const KapaliPushPlatformu();

  @override
  bool get etkin => false;

  @override
  Future<bool> baslat() async => false;

  @override
  Future<BildirimIzni> izin() async => BildirimIzni.reddedildi;

  @override
  Future<BildirimIzni> izinIste() async => BildirimIzni.reddedildi;

  @override
  Future<String?> token() async => null;

  @override
  Future<void> tokenSil() async {}

  @override
  Stream<String> get tokenYenilendi => const Stream.empty();

  @override
  Future<PushVerisi?> ilkDokunulan() async => null;

  @override
  Stream<PushVerisi> get dokunulanlar => const Stream.empty();

  @override
  Stream<PushVerisi> get onPlandaGelenler => const Stream.empty();

  @override
  Future<void> kanallariKur(List<BildirimKanali> kanallar) async {}

  @override
  Future<bool> ayarlariAc() async => false;
}

/// Uygulamanın push platformu. Varsayılanı [KapaliPushPlatformu]'dur;
/// `main.dart` mobilde Firebase uygulamasıyla değiştirir (web derlemesinde
/// push yüklenmez).
final pushPlatformuProvider = Provider<PushPlatformu>(
  (ref) => const KapaliPushPlatformu(),
  name: 'pushPlatformuProvider',
);
