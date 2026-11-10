import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Aktif tayfanın kimliğini tutan notifier (ADR-0001 kural 3, ADR-0003).
///
/// Aktif tayfa seçimi tayfaya bağlı bir durum değil, hangi tayfanın
/// gösterileceğini belirleyen uygulama geneli bir seçimdir: Tayfa sekmesi,
/// WebSocket abonelikleri (ADR-0007) ve tayfa değiştirme paneli aynı değeri
/// okur. Bu yüzden `family` değildir ve kalıcıdır (`autoDispose` değil);
/// ekranlar arasında gezinirken seçim kaybolmamalıdır. Tayfaya bağlı
/// durumlar ise `tayfaId` ile `family` + `autoDispose` tanımlanır ve tayfa
/// değişince bırakılır.
///
/// Oturum durumu her değiştiğinde (çıkış, `session_ended`, hesap silme,
/// yeniden onay) seçim sıfırlanır; önceki kullanıcının seçimi bellekte
/// kalmaz (ADR-0001, kural 8).
///
/// Değer `null` ise kullanıcının (bilinen) bir tayfası yoktur ve Tayfa
/// sekmesi karşılama ekranını gösterir. Gerçek tayfa listesi ApiClient
/// (#7) sonrasında bağlanır; o zamana kadar uygulamada hiçbir şey bu değeri
/// doldurmaz (sahte veri yok).
class AktifTayfaIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(oturumDurumuProvider);
    return null;
  }

  /// [tayfaId]'yi aktif tayfa yapar. Kimlik UUID biçiminde değilse
  /// [ArgumentError] fırlatır; kimliğin kendisi hata metnine yazılmaz.
  void sec(String tayfaId) {
    if (!uuidBicimindeMi(tayfaId)) {
      throw ArgumentError('Tayfa kimliği UUID biçiminde değil.');
    }
    state = tayfaId;
  }

  /// Aktif tayfa seçimini kaldırır (ör. tayfadan ayrılınca).
  void temizle() => state = null;
}

/// Aktif tayfanın kimliği; tayfa yoksa `null`.
final aktifTayfaIdProvider = NotifierProvider<AktifTayfaIdNotifier, String?>(
  AktifTayfaIdNotifier.new,
  name: 'aktifTayfaIdProvider',
);

/// Bir tayfanın gösterilecek adı; bilinmiyorsa `null`.
///
/// Tayfaya bağlı durum olduğu için `family(tayfaId)` + `autoDispose`
/// (ADR-0001, kural 3). GEÇİCİ: Ad sunucudan gelir; ApiClient (#7)
/// bağlanana kadar her zaman `null` döner ve arayüz genel bir başlık
/// gösterir.
final tayfaAdiProvider = Provider.autoDispose.family<String?, String>(
  (ref, tayfaId) => null,
  name: 'tayfaAdiProvider',
);
