import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/kalem_formu.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ortak kütüphane (`/t/<tayfaId>/kutuphane`; App ADR-0033 §2, Tayfam-Api
/// ADR-0040 §1).
///
/// Geri çekilmemiş kalemler, en yeni önce; tür ve "Benim eşyalarım"
/// süzgeci sunucuya sorgu olarak gider. Her üye kalemin yalnızca
/// durumunu (müsait, ödünçte) ve sıradaki kişi sayısını görür; ödüncün
/// kimde olduğu yazılmaz. "Eşya ekle" sunucu `caller_can_add` derse
/// görünür (kesin kural 5). Üstteki düğme "Ödünçlerim"i açar.
class KutuphaneListeEkrani extends ConsumerStatefulWidget {
  const KutuphaneListeEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<KutuphaneListeEkrani> createState() =>
      _KutuphaneListeEkraniState();
}

class _KutuphaneListeEkraniState extends ConsumerState<KutuphaneListeEkrani> {
  LibraryItemKind? _tur;
  bool _benim = false;

  KalemSorgusu get _sorgu =>
      (tayfaId: widget.tayfaId, tur: _tur, benim: _benim);

  Future<void> _ekle() async {
    final m = AppLocalizations.of(context);
    final kalem = await kalemFormunuAc(context, widget.tayfaId);
    if (kalem == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m.kutuphane_eklendi)));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = kalemlerProvider(_sorgu);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(
        title: Text(m.kutuphane_ad),
        actions: [
          IconButton(
            onPressed: () =>
                unawaited(context.push(odunclerimAdresi(widget.tayfaId))),
            tooltip: m.kutuphane_odunclerim,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      floatingActionButton: liste?.callerCanAdd ?? false
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(_ekle()),
              icon: const Icon(Icons.add),
              label: Text(m.kutuphane_ekle),
            )
          : null,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s12,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s12,
              ),
              sliver: SliverToBoxAdapter(
                child: _Suzgec(
                  tur: _tur,
                  benim: _benim,
                  onTur: (tur) => setState(() => _tur = tur),
                  onBenim: (benim) => setState(() => _benim = benim),
                ),
              ),
            ),
            ...switch ((liste, hata)) {
              (final liste?, _) when liste.items.isEmpty => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.kenarMobil,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: TayfamKart(
                      child: Text(
                        _tur == null && !_benim
                            ? m.kutuphane_bos
                            : m.kutuphane_bos_suzgec,
                        style: context.yazi.bodyMedium?.copyWith(
                          color: context.renkler.metinGovde,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              (final liste?, _) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    TayfamSpacing.kenarMobil,
                    0,
                    TayfamSpacing.kenarMobil,
                    // Alttaki "Eşya ekle" düğmesi son satırı örtmesin.
                    TayfamSpacing.s64 + TayfamSpacing.s40,
                  ),
                  sliver: SliverList.builder(
                    itemCount: liste.items.length,
                    itemBuilder: (context, i) {
                      final kalem = liste.items[i];
                      return Padding(
                        key: ValueKey(kalem.id),
                        padding: const EdgeInsets.only(
                          bottom: TayfamSpacing.s12,
                        ),
                        child: KalemSatiri(
                          kalem: kalem,
                          onTap: () => unawaited(
                            context.push(kalemAdresi(widget.tayfaId, kalem.id)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              (null, final hata?) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: YuklemeHatasi(
                    hata: hata,
                    onTekrarDene: () => ref.invalidate(saglayici),
                  ),
                ),
              ],
              (null, null) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: TayfamYukleniyor(etiket: m.kutuphane_yukleniyor),
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

/// Tür süzgeci ve "Benim eşyalarım".
class _Suzgec extends StatelessWidget {
  const _Suzgec({
    required this.tur,
    required this.benim,
    required this.onTur,
    required this.onBenim,
  });

  final LibraryItemKind? tur;
  final bool benim;
  final ValueChanged<LibraryItemKind?> onTur;
  final ValueChanged<bool> onBenim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [
        ChoiceChip(
          label: Text(m.kutuphane_tumu),
          selected: tur == null,
          onSelected: (_) => onTur(null),
        ),
        for (final t in secilebilirTurler)
          ChoiceChip(
            label: Text(turAdi(m, t)),
            selected: tur == t,
            onSelected: (_) => onTur(t),
          ),
        FilterChip(
          label: Text(m.kutuphane_benim),
          selected: benim,
          onSelected: onBenim,
        ),
      ],
    );
  }
}

/// Listedeki bir kalem: fotoğraf (yoksa tür ikonu), ad, tür, durum ve
/// sırada bekleyen sayısı; çağıran sıradaysa yeri. Dokununca detay açılır.
class KalemSatiri extends StatelessWidget {
  const KalemSatiri({super.key, required this.kalem, required this.onTap});

  final LibraryItem kalem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final foto = kalem.photoUploadId;
    final sira = kalem.callerQueueRank;
    return TayfamKart(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (foto != null)
            ClipRRect(
              borderRadius: TayfamRadii.onizlemeKoseleri,
              child: SizedBox.square(
                dimension: TayfamSizes.fotografKucukResim,
                child: MedyaGorseli(
                  uploadId: foto,
                  etiket: m.kutuphane_fotograf_alani,
                ),
              ),
            )
          else
            TurKutusu(tur: kalem.kind, boyut: TayfamSizes.fotografKucukResim),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kalem.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: yazi.titleMedium?.copyWith(color: r.metin),
                ),
                const SizedBox(height: TayfamSpacing.s8),
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    TurEtiketi(tur: kalem.kind),
                    DurumEtiketi(durum: kalem.status),
                  ],
                ),
                if (sira != null || kalem.queueLength > 0) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(
                    sira != null
                        ? m.kutuphane_siradaki_yerin(sira)
                        : m.kutuphane_sira_uzunlugu(kalem.queueLength),
                    style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
