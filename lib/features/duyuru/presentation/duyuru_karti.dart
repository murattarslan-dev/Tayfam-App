import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir duyurunun listedeki kartı (ADR-0015 §2; tasarım: Duyurular): üstte
/// sabitlendiyse "Sabitlendi" etiketi ve kısa tarih ("Bugün 11:05",
/// "8 Kas"), başlık ve gövdenin ilk iki satırı. Sabitlenmiş kartın kenarı
/// mango ve kalındır; renk tek başına bilgi taşımaz, etiket metni her zaman
/// görünür. Yazar adı listede gösterilmez (yalnızca detayda).
///
/// Gövde düz metindir; markdown ya da HTML yorumlanmaz, bağlantılar
/// dokunulabilir değildir. Kartın tamamı tek bir düğmedir ve duyurunun
/// ekranını açar.
class DuyuruKarti extends StatelessWidget {
  const DuyuruKarti({
    super.key,
    required this.duyuru,
    required this.simdi,
    this.onTap,
  });

  final Announcement duyuru;

  /// "Bugün"ün hesaplandığı an.
  final DateTime simdi;

  /// Dokununca; `null` ise kart dokunulmaz.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final govde = duyuru.body.trim();
    final sabit = duyuru.pinned;
    final icerik = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (sabit) const SabitEtiketi(),
              Text(
                duyuruKisaZamani(m, duyuru.createdAt, simdi),
                style: yazi.labelSmall?.copyWith(
                  color: r.metinIkincil,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            duyuru.title,
            style: yazi.titleMedium?.copyWith(
              fontWeight: TayfamTypography.buyukBaslikAgirligi,
            ),
          ),
          if (govde.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              govde,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: yazi.bodySmall?.copyWith(color: r.metinGovde),
            ),
          ],
        ],
      ),
    );
    final onTap = this.onTap;
    final kart = Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(
          color: sabit ? r.mango : r.cizgi,
          width: sabit ? TayfamSizes.vurguKenari : TayfamSizes.kenar,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Semantics(container: true, child: icerik)
          : Semantics(
              container: true,
              button: true,
              child: InkWell(onTap: onTap, child: icerik),
            ),
    );
    if (onTap == null) return kart;
    return OdakCercevesi(koseler: TayfamRadii.kartKoseleri, child: kart);
  }
}

/// Sabitlenmiş duyurunun mango "Sabitlendi" etiketi (raptiye ikonlu). Renk
/// tek başına bilgi taşımaz; etiket metni her zaman görünür.
class SabitEtiketi extends StatelessWidget {
  const SabitEtiketi({super.key});

  @override
  Widget build(BuildContext context) {
    return Etiket(
      metin: AppLocalizations.of(context).duyuru_sabit,
      ton: EtiketTonu.mango,
      ikon: Icons.push_pin_outlined,
    );
  }
}

/// Duyuru kartındaki kısa zaman: bugünse "Bugün 11:05", bu yılsa gün ve
/// ay ("8 Kas"), daha eskiyse yılla. Cihazın saat diliminde, takvim gününe
/// göredir (ADR-0008).
String duyuruKisaZamani(AppLocalizations m, DateTime an, DateTime simdi) {
  final yerel = an.toLocal();
  final suan = simdi.toLocal();
  if (yerel.year == suan.year &&
      yerel.month == suan.month &&
      yerel.day == suan.day) {
    return m.duyuru_bugun_saat(saatMetni(m, yerel));
  }
  if (yerel.year == suan.year) {
    return DateFormat.MMMd(m.localeName).format(yerel);
  }
  return DateFormat.yMMMd(m.localeName).format(yerel);
}

/// Duyurunun yayın günü ve saati, cihazın saatine göre (ADR-0008).
/// [duzenlendi] ise sonuna "· düzenlendi" eklenir.
class DuyuruTarihi extends StatelessWidget {
  const DuyuruTarihi({super.key, required this.zaman, this.duzenlendi = false});

  /// Sunucudan gelen zaman (UTC).
  final DateTime zaman;

  /// Duyuru yayından sonra değişti (`updated_at` > `created_at`).
  final bool duzenlendi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yerel = zaman.toLocal();
    final tarih = m.duyuru_tarih(yerel, yerel);
    return Text(
      duzenlendi ? m.duyuru_tarih_duzenlendi(tarih) : tarih,
      style: context.yazi.labelSmall?.copyWith(
        color: context.renkler.metinIkincil,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
