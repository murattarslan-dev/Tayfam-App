import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_formu_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Duyuru formunu kabuğun üstünde tam ekran açar (ADR-0015 §2). Yeni
/// duyuru için [duzenlenen] `null`'dır. Yayınlanınca ya da kaydedilince
/// kısa bir bildirim gösterilir; sonuç liste ve detaya form içinde yansır.
Future<void> duyuruFormunuAc(
  BuildContext context, {
  required String tayfaId,
  Announcement? duzenlenen,
}) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Announcement>(
      fullscreenDialog: true,
      builder: (_) =>
          DuyuruFormuEkrani(tayfaId: tayfaId, duzenlenen: duzenlenen),
    ),
  );
  if (sonuc == null) return;
  final metin = duzenlenen == null
      ? metinler.duyuru_yayinlandi
      : metinler.duyuru_kaydedildi;
  bildirimGoster(bildirim, metin);
}

/// Ekranın altında kısa süreli bildirim gösterir; öncekinin yerini alır.
void bildirimGoster(ScaffoldMessengerState bildirim, String metin) {
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Bir işlemin hatasını gösterir ([hataBildir]). Oturum kapandıysa
/// ([OturumYok]) giriş ekranına dönülür; ayrı hata gösterilmez.
void islemHatasiniBildir(BuildContext context, Object hata) {
  if (hata is OturumYok) return;
  hataBildir(context, hata);
}
