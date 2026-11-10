import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';

/// Aktif tayfanın kimliğini tutan notifier (ADR-0001 kural 3, ADR-0003,
/// ADR-0014 §1).
///
/// Aktif tayfa seçimi tayfaya bağlı bir durum değil, hangi tayfanın
/// gösterileceğini belirleyen uygulama geneli bir seçimdir: Tayfa sekmesi,
/// WebSocket abonelikleri (ADR-0007) ve tayfa değiştirme paneli aynı değeri
/// okur. Bu yüzden `family` değildir ve kalıcıdır (`autoDispose` değil).
///
/// - Seçilen kimlik kullanıcı ayarı olarak güvenli depoya yazılır
///   ([SonTayfaDeposu]); yalnızca kimlik, içerik değil (ADR-0006 istisnası).
/// - Oturum durumu her değiştiğinde bellekteki seçim sıfırlanır (ADR-0001,
///   kural 8). Oturum kapanınca ([OturumDurumu.girisYok]) kayıt da silinir.
/// - Tayfa listesi gelince [uzlastir] kayıtlı kimliği etkin üyeliklerle
///   karşılaştırır; yoksa sunucunun sırasındaki ilk etkin tayfa seçilir,
///   etkin tayfa yoksa seçim kalkar (karşılama ekranı).
///
/// Değer `null` ise kullanıcının (bilinen) etkin bir tayfası yoktur ve Tayfa
/// sekmesi karşılama ekranını gösterir.
class AktifTayfaIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final oturum = ref.watch(oturumDurumuProvider);
    if (oturum == OturumDurumu.girisYok) {
      unawaited(_silSessiz());
    }
    return null;
  }

  SonTayfaDeposu get _depo => ref.read(sonTayfaDeposuProvider);

  /// [tayfaId]'yi aktif tayfa yapar ve son tayfa olarak hatırlar. Kimlik
  /// UUID biçiminde değilse [ArgumentError] fırlatır; kimliğin kendisi hata
  /// metnine yazılmaz.
  void sec(String tayfaId) {
    if (!uuidBicimindeMi(tayfaId)) {
      throw ArgumentError('Tayfa kimliği UUID biçiminde değil.');
    }
    state = tayfaId;
    unawaited(_yazSessiz(tayfaId));
  }

  /// Aktif tayfa seçimini ve hatırlanan kimliği kaldırır.
  void temizle() {
    state = null;
    unawaited(_silSessiz());
  }

  /// Tayfa listesi (sunucunun sırasıyla [etkinIdler]) gelince seçimi
  /// uzlaştırır (ADR-0014 §1):
  ///
  /// 1. Bellekteki seçim, yoksa güvenli depodaki son tayfa, etkin
  ///    üyeliklerdeyse o kalır.
  /// 2. Değilse (çıkarılma, ayrılma, tayfa silinmesi) ilk etkin tayfa
  ///    seçilir.
  /// 3. Etkin tayfa yoksa seçim ve kayıt kalkar.
  Future<void> uzlastir(List<String> etkinIdler) async {
    final gecerli = [
      for (final id in etkinIdler)
        if (uuidBicimindeMi(id)) id,
    ];
    var aday = state;
    if (aday == null) {
      final kayitli = await _okuSessiz();
      if (!ref.mounted) return;
      // Beklerken bir seçim yapıldıysa o daha yenidir.
      aday = state ?? kayitli;
    }
    if (aday != null && gecerli.contains(aday)) {
      if (state != aday) sec(aday);
      return;
    }
    if (gecerli.isNotEmpty) {
      sec(gecerli.first);
    } else {
      temizle();
    }
  }

  /// Tayfa listesi alınamadığında (ör. çevrimdışı açılış) seçim yoksa
  /// güvenli depodaki son tayfayı doğrulamadan geri yükler. Kimlik yalnızca
  /// adres içindir; tayfaya erişimi sunucu söyler (kesin kural 5).
  Future<void> kayittanYukle() async {
    if (state != null) return;
    final kayitli = await _okuSessiz();
    if (!ref.mounted || state != null) return;
    if (kayitli != null && uuidBicimindeMi(kayitli)) state = kayitli;
  }

  Future<String?> _okuSessiz() async {
    try {
      return await _depo.oku();
    } on Exception {
      return null;
    }
  }

  Future<void> _yazSessiz(String tayfaId) async {
    try {
      await _depo.yaz(tayfaId);
    } on Exception {
      // Hatırlanamasa da seçim bu çalışmada geçerlidir.
    }
  }

  Future<void> _silSessiz() async {
    try {
      await _depo.sil();
    } on Exception {
      // Depoya ulaşılamadı; bir sonraki uzlaştırmada etkin üyelik yoksa
      // kayıt yine kullanılmaz.
    }
  }
}

/// Aktif tayfanın kimliği; tayfa yoksa `null`.
final aktifTayfaIdProvider = NotifierProvider<AktifTayfaIdNotifier, String?>(
  AktifTayfaIdNotifier.new,
  name: 'aktifTayfaIdProvider',
);
