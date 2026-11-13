import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ortak.dart';
import 'package:tayfam/features/sohbet/presentation/kisi_secici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik kanalı için etkinlik seçiciyi açar (2026-11-13 tasarım:
/// Kanal-Etkinlik-Sec). Seçilen etkinlik döner; vazgeçilirse `null`.
///
/// Liste tayfanın yaklaşan (bitmemiş) etkinlikleridir
/// (`GET /v1/tayfas/{tayfa_id}/events`). Görebildiğin açık bir kanalı
/// olan etkinlik pasif görünür; görmediğin kanalı sunucu söyler
/// (`event-channel-exists`).
Future<Event?> etkinlikSeciciyiAc(
  BuildContext context, {
  required String tayfaId,
  Event? secili,
}) => Navigator.of(context).push(
  MaterialPageRoute<Event>(
    builder: (_) => EtkinlikSecici(tayfaId: tayfaId, secili: secili),
  ),
);

/// Etkinlik seçici ekranı.
class EtkinlikSecici extends ConsumerStatefulWidget {
  const EtkinlikSecici({super.key, required this.tayfaId, this.secili});

  final String tayfaId;
  final Event? secili;

  @override
  ConsumerState<EtkinlikSecici> createState() => _EtkinlikSeciciState();
}

class _EtkinlikSeciciState extends ConsumerState<EtkinlikSecici> {
  late Event? _secili = widget.secili;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = etkinlikListesiProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final kanallar =
        ref.watch(kanallarProvider(widget.tayfaId)).value ?? const [];
    final kanaliOlanlar = {
      for (final k in kanallar)
        if (k.visibility == ChannelVisibility.event && k.archivedAt == null)
          ?k.eventId,
    };
    final liste = durum.value;
    final simdi = ref.read(simdiProvider)();
    final secili = _secili;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.sohbet_kitle_etkinlik_sec),
            Text(
              m.sohbet_kitle_etkinlik,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s24,
              ),
              children: [
                BolumEtiketi(baslik: m.sohbet_etkinlik_yaklasan),
                if (liste == null && durum.error != null) ...[
                  HataSatiri.hatadan(durum.error!),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BaglantiEylemi(
                      etiket: m.sohbet_tekrar_dene,
                      onPressed: () => ref.invalidate(saglayici),
                    ),
                  ),
                ] else if (liste == null)
                  const Center(child: TayfamYukleniyor(gecikmeli: true))
                else if (liste.ogeler.isEmpty)
                  Text(
                    m.sohbet_etkinlik_bos,
                    style: context.yazi.bodyLarge?.copyWith(
                      color: r.metinGovde,
                    ),
                  )
                else
                  RadioGroup<String>(
                    groupValue: secili?.id,
                    onChanged: (id) => setState(() {
                      for (final e in liste.ogeler) {
                        if (e.id == id) _secili = e;
                      }
                    }),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (sira, e) in liste.ogeler.indexed) ...[
                          if (sira > 0)
                            const SizedBox(height: TayfamSpacing.s8),
                          _EtkinlikSecenegi(
                            etkinlik: e,
                            simdi: simdi,
                            secili: e.id == secili?.id,
                            kanaliVar: kanaliOlanlar.contains(e.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (liste != null) ...[
                  if (liste.dahaHatasi case final hata?)
                    HataSatiri.hatadan(hata),
                  if (liste.dahaYukleniyor)
                    const Center(child: TayfamYukleniyor())
                  else if (liste.dahaVar)
                    Center(
                      child: BaglantiEylemi(
                        etiket: m.sohbet_daha_fazla,
                        onPressed: () =>
                            unawaited(ref.read(saglayici.notifier).dahaFazla()),
                      ),
                    ),
                ],
                const SizedBox(height: TayfamSpacing.s16),
                const _NasilCalisir(),
              ],
            ),
          ),
          SeciciAltEylemi(
            child: BirincilEylem(
              etiket: m.sohbet_etkinlik_devam,
              onPressed: secili == null
                  ? null
                  : () => Navigator.of(context).pop(secili),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seçicideki etkinlik zamanı: bir hafta içindeyse gün adı ve saat
/// ("Cumartesi 08:30"), sonra gün ve ay ("6 Ara"); cihazın saat diliminde.
String seciciZamani(AppLocalizations m, DateTime baslangic, DateTime simdi) {
  final yerel = baslangic.toLocal();
  final fark = yerel.difference(simdi.toLocal());
  if (fark.inDays < 7) {
    return DateFormat.EEEE(m.localeName).add_Hm().format(yerel);
  }
  return DateFormat.MMMd(m.localeName).format(yerel);
}

/// Bir etkinlik seçeneği: tür çipi, başlık, zaman ve gelen sayısı.
/// Görebildiğin açık kanalı varsa pasiftir.
class _EtkinlikSecenegi extends StatelessWidget {
  const _EtkinlikSecenegi({
    required this.etkinlik,
    required this.simdi,
    required this.secili,
    required this.kanaliVar,
  });

  final Event etkinlik;
  final DateTime simdi;
  final bool secili;
  final bool kanaliVar;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final baslik = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (etkinlik.type != EventType.unknown) ...[
          EtkinlikTuruCipi(tur: etkinlik.type),
          const SizedBox(height: TayfamSpacing.s4),
        ],
        Text(etkinlik.title),
      ],
    );
    final alt = Text(
      kanaliVar
          ? m.sohbet_etkinlik_kanali_var
          : m.sohbet_etkinlik_satiri(
              etkinlik.goingCount,
              seciciZamani(m, etkinlik.startsAt, simdi),
            ),
      style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
    );
    if (kanaliVar) {
      return SecimKarti(
        secili: false,
        child: ListTile(enabled: false, title: baslik, subtitle: alt),
      );
    }
    return SecimKarti(
      secili: secili,
      child: RadioListTile<String>(
        value: etkinlik.id,
        controlAffinity: ListTileControlAffinity.trailing,
        title: baslik,
        subtitle: alt,
      ),
    );
  }
}

/// "Etkinlik kanalı nasıl çalışır?" bilgi kartı.
class _NasilCalisir extends StatelessWidget {
  const _NasilCalisir();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final maddeler = [
      m.sohbet_etkinlik_nasil_1,
      m.sohbet_etkinlik_nasil_2,
      m.sohbet_etkinlik_nasil_3,
      m.sohbet_etkinlik_nasil_4,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.kartKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                m.sohbet_etkinlik_nasil,
                style: context.yazi.titleSmall,
              ),
            ),
            for (final madde in maddeler) ...[
              const SizedBox(height: TayfamSpacing.s8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.check,
                      size: TayfamSizes.ikonKucuk,
                      color: r.tintMarkaUstu,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Text(
                      madde,
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
