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

/// Anketin durum etiketleri: "Açık" ya da "Kapandı" ve gizliyse "Gizli
/// anket". Renk tek başına bilgi taşımaz; etiket metni her zaman görünür.
class AnketEtiketleri extends StatelessWidget {
  const AnketEtiketleri({super.key, required this.anket, required this.kapali});

  final Poll anket;
  final bool kapali;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [
        Etiket(metin: kapali ? m.anket_kapandi : m.anket_acik),
        if (anket.anonymous) Etiket(metin: m.anket_gizli),
      ],
    );
  }
}

/// Kullanıcının kendi oyunu işaretleyen "Senin oyun" etiketi. Yalnızca
/// `own_option_ids`'ten gelir; başkalarının oyu hiçbir yerde işaretlenmez.
class SeninOyunEtiketi extends StatelessWidget {
  const SeninOyunEtiketi({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.check_circle_outline,
            size: TayfamSizes.ikonKucuk,
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s4),
        Flexible(
          child: Etiket(metin: AppLocalizations.of(context).anket_senin_oyun),
        ),
      ],
    );
  }
}

/// Anketin kapanış satırı: açıksa planlanan kapanma, kapandıysa kapanma
/// zamanı (biliniyorsa), cihazın saatine göre.
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
    if (zaman == null) return const SizedBox.shrink();
    final yerel = zaman.toLocal();
    return Text(
      kapali
          ? m.anket_kapandi_zaman(yerel, yerel)
          : m.anket_kapanis(yerel, yerel),
      style: context.yazi.bodySmall?.copyWith(
        color: context.renkler.metinIkincil,
      ),
    );
  }
}
