import 'dart:async';

import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';

/// Testlerde kullanılan sahte FCM token'ı (gerçek değil).
const String sahteToken = 'sahte-fcm-token:0001';

/// Firebase'siz sahte push platformu; çağrıları kaydeder.
final class SahtePushPlatformu implements PushPlatformu {
  SahtePushPlatformu({
    this.izinDurumu = BildirimIzni.verildi,
    this.istekSonucu = BildirimIzni.verildi,
    this.mevcutToken = sahteToken,
    this.baslar = true,
    this.ilk,
  });

  BildirimIzni izinDurumu;

  /// [izinIste]'nin döndüreceği sonuç; izin durumu da buna geçer.
  BildirimIzni istekSonucu;

  String? mevcutToken;
  final bool baslar;
  final PushVerisi? ilk;

  int baslatma = 0;
  int izinIstegi = 0;
  int tokenSilme = 0;
  int ayarAcma = 0;
  final List<List<BildirimKanali>> kurulanKanallar = [];

  final StreamController<String> yenileme = StreamController.broadcast();
  final StreamController<PushVerisi> dokunma = StreamController.broadcast();
  final StreamController<PushVerisi> onPlan = StreamController.broadcast();

  @override
  bool get etkin => true;

  @override
  Future<bool> baslat() async {
    baslatma++;
    return baslar;
  }

  @override
  Future<BildirimIzni> izin() async => izinDurumu;

  @override
  Future<BildirimIzni> izinIste() async {
    izinIstegi++;
    izinDurumu = istekSonucu;
    return istekSonucu;
  }

  @override
  Future<String?> token() async => mevcutToken;

  @override
  Future<void> tokenSil() async {
    tokenSilme++;
  }

  @override
  Stream<String> get tokenYenilendi => yenileme.stream;

  @override
  Future<PushVerisi?> ilkDokunulan() async => ilk;

  @override
  Stream<PushVerisi> get dokunulanlar => dokunma.stream;

  @override
  Stream<PushVerisi> get onPlandaGelenler => onPlan.stream;

  @override
  Future<void> kanallariKur(List<BildirimKanali> kanallar) async {
    kurulanKanallar.add(kanallar);
  }

  @override
  Future<bool> ayarlariAc() async {
    ayarAcma++;
    return true;
  }
}

/// Sahte push token uçları; gerçek ağ yok.
final class SahtePushTokenDeposu implements PushTokenDeposu {
  SahtePushTokenDeposu({this.hata});

  /// Verilirse her çağrı bunu fırlatır.
  Exception? hata;

  final List<String> kaydedilen = [];
  int silme = 0;

  @override
  Future<void> kaydet(String token) async {
    final h = hata;
    if (h != null) throw h;
    kaydedilen.add(token);
  }

  @override
  Future<void> sil() async {
    silme++;
    final h = hata;
    if (h != null) throw h;
  }
}
