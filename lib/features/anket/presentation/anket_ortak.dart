import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/presentation/anket_formu_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anket formunu kabuğun üstünde tam ekran açar (ADR-0018 §5).
/// [etkinlikId] verilirse anket o etkinliğe bağlanır. Anket açılınca kısa
/// bir bildirim gösterilir ve anketin ekranına gidilir.
Future<void> anketFormunuAc(
  BuildContext context, {
  required String tayfaId,
  String? etkinlikId,
}) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final yonlendirici = GoRouter.maybeOf(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Poll>(
      fullscreenDialog: true,
      builder: (_) =>
          AnketFormuEkrani(tayfaId: tayfaId, etkinlikId: etkinlikId),
    ),
  );
  if (sonuc == null) return;
  anketBildirimi(bildirim, metinler.anket_acildi);
  yonlendirici?.go(Adresler.anket(tayfaId, sonuc.id));
}

/// Ekranın altında kısa süreli bildirim gösterir; öncekinin yerini alır.
void anketBildirimi(ScaffoldMessengerState bildirim, String metin) {
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Bir işlemin hatasını gösterir ([hataBildir]). Oturum kapandıysa
/// ([OturumYok]) giriş ekranına dönülür; ayrı hata gösterilmez.
void anketHatasiniBildir(BuildContext context, Object hata) {
  if (hata is OturumYok) return;
  hataBildir(context, hata);
}

/// "Tekrar dene" bağlantısı.
class AnketTekrarDene extends StatelessWidget {
  const AnketTekrarDene({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(AppLocalizations.of(context).tayfa_ana_tekrar_dene),
      ),
    );
  }
}

/// Anketin durum çipi (tasarım: Anketler, Anket-Oy): açıkta teal "Açık",
/// kapanınca nötr "Kapandı". Renk tek başına bilgi taşımaz; çipin metni
/// her zaman görünür.
class AnketDurumCipi extends StatelessWidget {
  const AnketDurumCipi({super.key, required this.kapali});

  final bool kapali;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return kapali
        ? Etiket(metin: m.anket_kapandi, ton: EtiketTonu.notr)
        : Etiket(metin: m.anket_acik, ton: EtiketTonu.teal);
  }
}

/// Kullanıcının kendi oyunu işaretleyen "Senin oyun" çipi. Yalnızca
/// `own_option_ids`'ten gelir; başkalarının oyu hiçbir yerde işaretlenmez.
class SeninOyunEtiketi extends StatelessWidget {
  const SeninOyunEtiketi({super.key});

  @override
  Widget build(BuildContext context) {
    return Etiket(metin: AppLocalizations.of(context).anket_senin_oyun);
  }
}

/// Anket ekranındaki kapanış satırı (tasarım: Anket-Oy, Anket-Gizli):
/// açıksa planlanan kapanma ya da "Elle kapatılana kadar açık", kapandıysa
/// kapanma zamanı (biliniyorsa), cihazın saatine göre.
class AnketKapanisMetni extends StatelessWidget {
  const AnketKapanisMetni({
    super.key,
    required this.anket,
    required this.kapali,
  });

  final Poll anket;
  final bool kapali;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final zaman = kapali ? (anket.closedAt ?? anket.closesAt) : anket.closesAt;
    final String metin;
    if (zaman == null) {
      if (kapali) return const SizedBox.shrink();
      metin = m.anket_elle_kapanana_kadar;
    } else {
      final yerel = zaman.toLocal();
      metin = kapali
          ? m.anket_kapandi_zaman(yerel, yerel)
          : m.anket_kapanis(yerel, yerel);
    }
    return Text(
      metin,
      style: context.yazi.labelSmall?.copyWith(
        color: context.renkler.metinIkincil,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
