import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/tayfa/data/paylasim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [tur] etkinlik türünün çeviri dosyasındaki adı.
String turEtiketi(AppLocalizations m, EventType tur) => switch (tur) {
  EventType.convoy => m.tayfa_tur_convoy,
  EventType.camp => m.tayfa_tur_camp,
  EventType.hike => m.tayfa_tur_hike,
  EventType.fishing => m.tayfa_tur_fishing,
  EventType.gaming => m.tayfa_tur_gaming,
  EventType.sports => m.tayfa_tur_sports,
  EventType.general || EventType.unknown => m.tayfa_tur_general,
};

/// [tur]'ün çip vurgusu. Türlere sabit renk kararı verilmediği için
/// (etkinlik türü kaydı henüz boş) çip vurguları sözleşmenin tür sırasıyla
/// sırayla teal, mango, nar olarak dağıtılır; tür değişmedikçe rengi
/// değişmez.
CipVurgusu turVurgusu(EventType tur) {
  const vurgular = CipVurgusu.values;
  final sira = EventType.values.indexOf(tur);
  return vurgular[sira % vurgular.length];
}

/// Tayfa kodunu sistem paylaşım menüsüyle paylaşır (ADR-0014 §5). Metin:
/// tayfa adı, kod ve tayfam.app bağlantısı. [dugme], iPad'de menünün
/// bağlanacağı düğmenin bağlamıdır.
Future<void> koduPaylas(
  BuildContext dugme,
  WidgetRef ref, {
  required String ad,
  required String kod,
}) {
  final metin = AppLocalizations.of(dugme).tayfa_paylasim_metni(ad, kod);
  final kutu = dugme.findRenderObject();
  final konum = kutu is RenderBox && kutu.hasSize
      ? kutu.localToGlobal(Offset.zero) & kutu.size
      : null;
  return ref.read(paylasiciProvider).paylas(metin, konum: konum);
}

/// Tayfa kodunu panoya kopyalar ve kısa bir bildirim gösterir.
Future<void> koduKopyala(
  BuildContext context,
  WidgetRef ref, {
  required String kod,
}) async {
  final bildirim = ScaffoldMessenger.of(context);
  final metin = AppLocalizations.of(context).tayfa_kod_kopyalandi;
  await ref.read(paylasiciProvider).kopyala(kod);
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}
