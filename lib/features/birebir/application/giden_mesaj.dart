import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Gönderilmekte olan bir birebir mesajın durumu (ADR-0006: bekleyen öğe
/// saat ikonuyla, başarısız olan uyarı ikonuyla gösterilir).
enum GidenDurumu {
  /// İstek sürüyor.
  gonderiliyor,

  /// Gönderilemedi; "Tekrar dene" ve "Sil" sunulur.
  basarisiz,
}

/// Sunucu kabul edene kadar yalnızca bellekte duran giden mesaj.
///
/// [istekKimligi] mesaj yazıldığı anda bir kez üretilir ve her denemede
/// aynı değer gönderilir (`client_request_id`); sunucu ikinci mesaj açmaz.
/// Metin hiçbir yere yazılmaz ve loglanmaz (kesin kural 3).
@immutable
final class GidenMesaj {
  const GidenMesaj({
    required this.istekKimligi,
    required this.metin,
    this.durum = GidenDurumu.gonderiliyor,
    this.hata,
  });

  final String istekKimligi;

  final String metin;

  final GidenDurumu durum;

  /// Son denemenin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Yeniden deneniyor.
  GidenMesaj gonderiliyor() =>
      GidenMesaj(istekKimligi: istekKimligi, metin: metin);

  /// Gönderilemedi.
  GidenMesaj basarisiz(Object hata) => GidenMesaj(
    istekKimligi: istekKimligi,
    metin: metin,
    durum: GidenDurumu.basarisiz,
    hata: hata,
  );
}

/// Mesajların gösterim sırası: en yeni önce (sunucunun ilk sayfasıyla
/// aynı).
int mesajSirasi(DirectMessage a, DirectMessage b) {
  final zaman = b.createdAt.compareTo(a.createdAt);
  return zaman != 0 ? zaman : b.id.compareTo(a.id);
}

/// [mevcut] ile [gelen]'i kimliğe göre birleştirir (aynı kimlikte gelen
/// kazanır) ve en yeni önce sıralar.
List<DirectMessage> mesajlariBirlestir(
  Iterable<DirectMessage> mevcut,
  Iterable<DirectMessage> gelen,
) {
  final hepsi = {for (final m in mevcut) m.id: m};
  for (final m in gelen) {
    hepsi[m.id] = m;
  }
  return List.unmodifiable(hepsi.values.toList()..sort(mesajSirasi));
}

/// [mesaj]'ın silinmiş hali: metin yok, `deleted: true`.
DirectMessage silinmisOlarak(DirectMessage mesaj) => DirectMessage(
  id: mesaj.id,
  conversationId: mesaj.conversationId,
  senderUserId: mesaj.senderUserId,
  deleted: true,
  createdAt: mesaj.createdAt,
);
