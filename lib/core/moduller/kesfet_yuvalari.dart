import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Keşfet ve güvenlik ağı paketinin başka paketlere eklediği parçaların
/// yuvaları (istemci ADR-0027 §1). Tayfa, tayfa yönetimi ve etkinlik
/// paketleri Keşfet'i import etmez (Keşfet onları kullanır; döngü olurdu,
/// ADR-0002). `shell/kayitlar.dart` bu provider'ları override eder;
/// varsayılanlarda parça gösterilmez.

/// Keşfet girişleri (tayfa değiştirme panelindeki satır, karşılama
/// ekranındaki kart) görünür mü. Keşfet paketi akışın okunup okunmadığına
/// göre verir; sunucu `feature-disabled` dönerse `false` (ADR-0027 §2).
/// Varsayılanı `false`'tur.
final kesfetGorunurProvider = Provider<bool>(
  (ref) => false,
  name: 'kesfetGorunurProvider',
);

/// Tayfa ayarlarında yalnızca yöneticiye gösterilen ek bölüm (Keşfet'te
/// göster). Okunamazsa yer kaplamaz; yetki sunucudadır.
typedef TayfaAyarEkBolumu = Widget Function(
  BuildContext context,
  String tayfaId,
);

/// Uygulamaya kayıtlı tayfa ayarı ek bölümü; varsayılanı `null`.
final tayfaAyarEkBolumuProvider = Provider<TayfaAyarEkBolumu?>(
  (ref) => null,
  name: 'tayfaAyarEkBolumuProvider',
);

/// Etkinlik detayında varış bildiriminin altındaki güvenlik kartları
/// (güvenlik kişisi, "Her şey yolunda mıydı?"). [simdi] uygulamanın
/// saatidir. Gösterilecek bir şey yoksa yer kaplamaz.
typedef EtkinlikGuvenlikYuvasi = Widget Function(
  BuildContext context,
  Event etkinlik,
  DateTime simdi,
);

/// Uygulamaya kayıtlı etkinlik güvenlik kartları; varsayılanı `null`.
final etkinlikGuvenlikYuvasiProvider = Provider<EtkinlikGuvenlikYuvasi?>(
  (ref) => null,
  name: 'etkinlikGuvenlikYuvasiProvider',
);
