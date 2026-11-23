import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/gunun_icerigi/application/gunun_icerigi.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ana sayfadaki "Günün içeriği" kartı (`daily`; App ADR-0024 §6,
/// Tayfam-Api ADR-0027 §5).
///
/// Yalnızca sunucunun bugün seçtiği içeriği gösterir; istemci seçim
/// yapmaz. "Tümü" havuzu açar (her üye okur; yönetimi sunucunun
/// `caller_can_manage`'ı açar). Havuz boşsa sakin bir boş durum; yönetimdeki
/// üyeye "İçerik ekle" yönlendirmesi. Modül kapalıysa (`module-disabled`)
/// kart yer kaplamaz.
class GununIcerigiKarti extends ConsumerWidget {
  const GununIcerigiKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = bugunkuIcerikProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final veri = durum.value;
    final hata = durum.error;
    if (veri == null &&
        hata is ApiProblem &&
        hata.type == ProblemType.moduleDisabled) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: m.gunun_icerigi_ad,
          tumuEtiketi: m.gunun_icerigi_tumu,
          onTumu: () => context.go(gununIcerigiAdresi(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (veri != null)
          switch (veri.item) {
            final icerik? => _IcerikKarti(
              tayfaId: tayfaId,
              icerik: icerik,
              sabit: veri.pinned,
            ),
            null => _BosKart(tayfaId: tayfaId),
          }
        else if (hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else
          Center(
            child: TayfamYukleniyor(
              etiket: m.gunun_icerigi_yukleniyor,
              gecikmeli: true,
            ),
          ),
      ],
    );
  }
}

enum _KartIslemi { sikayet }

class _IcerikKarti extends StatelessWidget {
  const _IcerikKarti({
    required this.tayfaId,
    required this.icerik,
    required this.sabit,
  });

  final String tayfaId;
  final DailyItem icerik;

  /// İçerik bugüne sabitlenmiş.
  final bool sabit;

  Future<void> _islem(BuildContext context, _KartIslemi islem) async {
    switch (islem) {
      case _KartIslemi.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: tayfaId,
            tur: ReportTargetType.dailyItem,
            id: icerik.id,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.format_quote, color: r.marka)),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: sabit
                      ? Etiket(
                          metin: m.gunun_icerigi_bugune_ozel,
                          ton: EtiketTonu.mango,
                          ikon: Icons.push_pin_outlined,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              PopupMenuButton<_KartIslemi>(
                tooltip: m.gunun_icerigi_secenekler,
                icon: const Icon(Icons.more_vert),
                onSelected: (islem) => unawaited(_islem(context, islem)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _KartIslemi.sikayet,
                    child: Text(m.gunun_icerigi_sikayet_et),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          IcerikMetni(icerik: icerik, buyuk: true),
        ],
      ),
    );
  }
}

/// Havuz boşken: kısa bir açıklama; yönetimdeki üyeye "İçerik ekle".
/// Rol yalnızca arayüzü sadeleştirir, yetkiyi sunucu verir.
class _BosKart extends ConsumerWidget {
  const _BosKart({required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            yonetimde ? m.gunun_icerigi_bos_yonetici : m.gunun_icerigi_bos_uye,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
          if (yonetimde) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => context.go(gununIcerigiAdresi(tayfaId)),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                icon: const Icon(Icons.add),
                label: Text(m.gunun_icerigi_ekle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
