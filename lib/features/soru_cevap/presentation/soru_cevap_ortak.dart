import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/presentation/cevap_formu_ekrani.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_formu_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru formunu kabuğun üstünde tam ekran açar (ADR-0018 §4). Yeni soru
/// için [duzenlenen] `null`'dır; soru sorulunca sorunun ekranına gidilir.
/// Sonuç liste ve detaya form içinde yansır.
Future<void> soruFormunuAc(
  BuildContext context, {
  required String tayfaId,
  Question? duzenlenen,
}) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Question>(
      fullscreenDialog: true,
      builder: (_) => SoruFormuEkrani(tayfaId: tayfaId, duzenlenen: duzenlenen),
    ),
  );
  if (sonuc == null) return;
  if (duzenlenen == null) {
    bildirimGoster(bildirim, metinler.soru_soruldu);
    if (!context.mounted) return;
    GoRouter.maybeOf(context)?.go(Adresler.soru(tayfaId, sonuc.id));
  } else {
    bildirimGoster(bildirim, metinler.soru_kaydedildi);
  }
}

/// Cevap formunu kabuğun üstünde tam ekran açar. Yeni cevap için
/// [duzenlenen] `null`'dır. Sonuç cevap listesine form içinde yansır.
Future<void> cevapFormunuAc(
  BuildContext context, {
  required String tayfaId,
  required String soruId,
  Answer? duzenlenen,
}) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Answer>(
      fullscreenDialog: true,
      builder: (_) => CevapFormuEkrani(
        tayfaId: tayfaId,
        soruId: soruId,
        duzenlenen: duzenlenen,
      ),
    ),
  );
  if (sonuc == null) return;
  bildirimGoster(
    bildirim,
    duzenlenen == null
        ? metinler.soru_cevap_gonderildi
        : metinler.soru_kaydedildi,
  );
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

/// Silme onayı; onaylanırsa `true`.
Future<bool> silmeyiOnayla(
  BuildContext context, {
  required String baslik,
  required String aciklama,
}) async {
  final metinler = AppLocalizations.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(baslik),
      content: Text(aciklama),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          child: Text(metinler.soru_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          child: Text(metinler.soru_sil),
        ),
      ],
    ),
  );
  return onay ?? false;
}

/// İçeriğin yazarı ve yazıldığı gün ve saat (cihazın saatine göre).
/// Yazarın hesabı silindiyse "Silinmiş kullanıcı" yazar.
class YazarSatiri extends StatelessWidget {
  const YazarSatiri({super.key, required this.yazarId, required this.zaman});

  /// Yazarın kimliği; hesap silindiyse `null`.
  final String? yazarId;

  /// Sunucudan gelen zaman (UTC).
  final DateTime zaman;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final stil = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metinIkincil,
    );
    final yazarId = this.yazarId;
    final yerel = zaman.toLocal();
    return Wrap(
      spacing: TayfamSpacing.s8,
      children: [
        if (yazarId == null)
          Text(metinler.kullanici_silinmis, style: stil)
        else
          KullaniciAdiMetni(kullaniciId: yazarId, style: stil),
        Text(metinler.soru_tarih(yerel, yerel), style: stil),
      ],
    );
  }
}

/// Sorunun etiketleri (ADR-0004 etiket bileşeni).
class SoruEtiketleri extends StatelessWidget {
  const SoruEtiketleri({super.key, required this.etiketler});

  final List<Tag> etiketler;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [for (final e in etiketler) Etiket(metin: e.name)],
    );
  }
}
