import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Ödünçlerim" ekranının kütüphane altındaki yolu.
const String odunclerimYolu = 'odunclerim';

/// Kalem detayının yol parametresi.
const String kalemIdParametresi = 'kalemId';

/// [tayfaId] tayfasının ortak kütüphanesi.
String kutuphaneAdresi(String tayfaId) => Adresler.kutuphane(tayfaId);

/// [tayfaId] tayfasında çağıranın ödünçleri.
String odunclerimAdresi(String tayfaId) =>
    '${kutuphaneAdresi(tayfaId)}/$odunclerimYolu';

/// Bir kalemin detayı.
String kalemAdresi(String tayfaId, String kalemId) =>
    '${kutuphaneAdresi(tayfaId)}/$kalemId';

/// Sözleşmedeki üst sınırlar (Tayfam-Api ADR-0040 §1). Kalem ve sıra
/// sınırlarını (üye başına 100, sırada 20) sunucu uygular.
const int adEnCok = 80;
const int kitapAdiEnCok = 60;
const int notEnCok = 300;

/// İade tarihi en çok bu kadar gün sonrası olabilir (sözleşme: 90 gün).
const int iadeEnCokGun = 89;

/// Formda seçilebilen türler, sözleşmedeki sırayla.
const List<LibraryItemKind> secilebilirTurler = [
  LibraryItemKind.book,
  LibraryItemKind.campingGear,
  LibraryItemKind.boardGame,
  LibraryItemKind.tool,
  LibraryItemKind.other,
];

/// Türün adı.
String turAdi(AppLocalizations m, LibraryItemKind tur) => switch (tur) {
  LibraryItemKind.book => m.kutuphane_tur_kitap,
  LibraryItemKind.campingGear => m.kutuphane_tur_kamp,
  LibraryItemKind.boardGame => m.kutuphane_tur_masa_oyunu,
  LibraryItemKind.tool => m.kutuphane_tur_alet,
  LibraryItemKind.other || LibraryItemKind.unknown => m.kutuphane_tur_diger,
};

/// Türün ikonu (süs; ad her zaman yanındadır).
IconData turIkonu(LibraryItemKind tur) => switch (tur) {
  LibraryItemKind.book => Icons.menu_book_outlined,
  LibraryItemKind.campingGear => Icons.backpack_outlined,
  LibraryItemKind.boardGame => Icons.casino_outlined,
  LibraryItemKind.tool => Icons.handyman_outlined,
  LibraryItemKind.other ||
  LibraryItemKind.unknown => Icons.inventory_2_outlined,
};

/// Ödüncün durum metni.
String oduncDurumu(AppLocalizations m, LibraryLoanState durum) =>
    switch (durum) {
      LibraryLoanState.requested => m.kutuphane_odunc_istendi,
      LibraryLoanState.approved => m.kutuphane_odunc_onaylandi,
      LibraryLoanState.handedOver => m.kutuphane_odunc_teslim_edildi,
      LibraryLoanState.returned => m.kutuphane_odunc_iade_alindi,
      LibraryLoanState.declined => m.kutuphane_odunc_reddedildi,
      LibraryLoanState.cancelled => m.kutuphane_odunc_iptal,
      LibraryLoanState.closed => m.kutuphane_odunc_kapandi,
      LibraryLoanState.unknown => m.kutuphane_odunc_bilinmiyor,
    };

/// Ödünç durumunun etiket tonu.
EtiketTonu oduncTonu(LibraryLoanState durum) => switch (durum) {
  LibraryLoanState.requested || LibraryLoanState.approved => EtiketTonu.marka,
  LibraryLoanState.handedOver => EtiketTonu.mango,
  LibraryLoanState.returned => EtiketTonu.teal,
  LibraryLoanState.declined ||
  LibraryLoanState.cancelled ||
  LibraryLoanState.closed ||
  LibraryLoanState.unknown => EtiketTonu.notr,
};

/// Tarihin kısa metni ("5 Aralık 2026").
String tarihMetni(AppLocalizations m, DateTime tarih) =>
    DateFormat.yMMMMd(m.localeName).format(tarih.toLocal());

/// Kalemin türü: ikon ve ad.
class TurEtiketi extends StatelessWidget {
  const TurEtiketi({super.key, required this.tur});

  final LibraryItemKind tur;

  @override
  Widget build(BuildContext context) => Etiket(
    metin: turAdi(AppLocalizations.of(context), tur),
    ton: EtiketTonu.notr,
    ikon: turIkonu(tur),
  );
}

/// Kalemin herkese görünen durumu: müsait ya da ödünçte. Kimde olduğu
/// yazılmaz (yalnızca iki taraf görür).
class DurumEtiketi extends StatelessWidget {
  const DurumEtiketi({super.key, required this.durum});

  final LibraryItemStatus durum;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return switch (durum) {
      LibraryItemStatus.available => Etiket(
        metin: m.kutuphane_durum_musait,
        ton: EtiketTonu.teal,
      ),
      LibraryItemStatus.onLoan => Etiket(
        metin: m.kutuphane_durum_oduncte,
        ton: EtiketTonu.mango,
      ),
      LibraryItemStatus.withdrawn => Etiket(
        metin: m.kutuphane_durum_geri_cekildi,
        ton: EtiketTonu.notr,
      ),
      LibraryItemStatus.unknown => const SizedBox.shrink(),
    };
  }
}

/// Fotoğraf yokken türün ikonu: kare, nötr yüzey.
class TurKutusu extends StatelessWidget {
  const TurKutusu({super.key, required this.tur, required this.boyut});

  final LibraryItemKind tur;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ExcludeSemantics(
      child: Container(
        width: boyut,
        height: boyut,
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: Icon(turIkonu(tur), color: r.tintMarkaUstu),
      ),
    );
  }
}

/// Onay penceresi: son adım dolu yıkıcı düğmedir (ADR-0004 Notlar).
Future<bool> yikiciOnay(
  BuildContext context, {
  required String baslik,
  required String metin,
  required String eylem,
}) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final m = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(baslik),
        scrollable: true,
        content: Text(metin),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.kutuphane_vazgec),
          ),
          YikiciEylem(
            etiket: eylem,
            dolu: true,
            onPressed: () => Navigator.of(pencere).pop(true),
          ),
        ],
      );
    },
  );
  return onay ?? false;
}
