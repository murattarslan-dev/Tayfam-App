import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Katılımcılar sekmelerinin sırası.
const List<ListEventAttendeesStatus> katilimciSekmeleri = [
  ListEventAttendeesStatus.going,
  ListEventAttendeesStatus.maybe,
  ListEventAttendeesStatus.notGoing,
  ListEventAttendeesStatus.waitlist,
];

/// Katılımcılar (ADR-0015 §3): cevaba göre sekmeler, sayfalı. Sekmeler dar
/// ekranda ve büyük yazıda alt satıra geçen seçim çipleridir.
class KatilimcilarBolumu extends ConsumerStatefulWidget {
  const KatilimcilarBolumu({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
  });

  final String tayfaId;
  final String etkinlikId;

  @override
  ConsumerState<KatilimcilarBolumu> createState() => _KatilimcilarBolumuState();
}

class _KatilimcilarBolumuState extends ConsumerState<KatilimcilarBolumu> {
  ListEventAttendeesStatus _sekme = ListEventAttendeesStatus.going;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final anahtar = (
      tayfaId: widget.tayfaId,
      etkinlikId: widget.etkinlikId,
      durum: _sekme,
    );
    final liste = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            m.etkinlik_katilimcilar_baslik,
            style: context.yazi.titleMedium,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final durum in katilimciSekmeleri)
              ChoiceChip(
                label: Text(katilimciSekmesi(m, durum)),
                selected: _sekme == durum,
                onSelected: (_) => setState(() => _sekme = durum),
              ),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s8),
        ...liste.when<List<Widget>>(
          data: (sayfali) => [
            if (sayfali.ogeler.isEmpty)
              Text(
                m.etkinlik_katilimci_yok,
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
            for (final katilimci in sayfali.ogeler)
              _KatilimciSatiri(katilimci: katilimci),
            if (sayfali.hata case final hata?) HataSatiri.hatadan(hata),
            if (sayfali.yukleniyor)
              const Center(child: CircularProgressIndicator())
            else if (sayfali.dahaVar)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => unawaited(notifier.dahaFazla()),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.etkinlik_daha_fazla),
                ),
              ),
          ],
          error: (hata, _) => [
            HataSatiri.hatadan(hata),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => unawaited(notifier.yenile()),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.etkinlik_tekrar_dene),
              ),
            ),
          ],
          loading: () => [const Center(child: CircularProgressIndicator())],
        ),
      ],
    );
  }
}

class _KatilimciSatiri extends ConsumerWidget {
  const _KatilimciSatiri({required this.katilimci});

  final Attendee katilimci;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ad =
        ref.watch(kullaniciAdiProvider(katilimci.userId)).value ??
        m.etkinlik_uye;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(child: Text(ad, style: context.yazi.bodyLarge)),
          if (katilimci.attendance == AttendanceStatus.attended)
            Etiket(metin: m.etkinlik_katildi),
        ],
      ),
    );
  }
}
