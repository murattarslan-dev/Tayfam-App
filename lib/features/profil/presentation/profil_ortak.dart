import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/application/hesap_silme_notifier.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [hata]'nın profil ekranlarındaki metni. Başka hesap seçildiyse kendi
/// metni; Google girişi, API ve bağlantı hataları hesap özelliğinin ve
/// ortak eşlemenin metinleriyle gösterilir (`title` / `detail` gösterilmez).
String profilHatasiMetni(AppLocalizations m, Object hata) => switch (hata) {
  FarkliHesapHatasi() => m.profil_sil_farkli_hesap,
  _ => hesapHatasiMetni(m, hata),
};

/// Referans kodunun paylaşım linki: `https://tayfam.app/r/<kod>` (kesin
/// kural 9). Kod yol parçası olarak kodlanır.
Uri referansLinki(String kod) =>
    Uri(scheme: 'https', host: 'tayfam.app', pathSegments: ['r', kod]);

/// Ekranın altında kısa süreli bildirim gösterir; öncekinin yerini alır.
void profilBildirimi(ScaffoldMessengerState bildirim, String metin) {
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Referans linkini sistem paylaşım menüsüyle paylaşır. [dugme], iPad'de
/// menünün bağlanacağı düğmenin bağlamıdır. Paylaşılan metin loglanmaz.
Future<void> referansiPaylas(BuildContext dugme, WidgetRef ref, String kod) {
  final metin = AppLocalizations.of(dugme)
      .profil_referans_paylasim_metni(referansLinki(kod).toString());
  final kutu = dugme.findRenderObject();
  final konum = kutu is RenderBox && kutu.hasSize
      ? kutu.localToGlobal(Offset.zero) & kutu.size
      : null;
  return ref.read(paylasiciProvider).paylas(metin, konum: konum);
}

/// Referans kodunu panoya kopyalar ve kısa bir bildirim gösterir.
Future<void> referansiKopyala(
  BuildContext context,
  WidgetRef ref,
  String kod,
) async {
  final bildirim = ScaffoldMessenger.of(context);
  final metin = AppLocalizations.of(context).profil_referans_kopyalandi;
  await ref.read(paylasiciProvider).kopyala(kod);
  profilBildirimi(bildirim, metin);
}

/// Evet / hayır onay penceresi; onaylanırsa `true`.
Future<bool> profilOnayi(
  BuildContext context, {
  required String baslik,
  required String aciklama,
  required String onay,
}) async {
  final metinler = AppLocalizations.of(context);
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(baslik),
      content: Text(aciklama),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          child: Text(metinler.profil_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          child: Text(onay),
        ),
      ],
    ),
  );
  return sonuc ?? false;
}
