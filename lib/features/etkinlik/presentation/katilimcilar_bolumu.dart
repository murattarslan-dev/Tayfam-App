import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
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
///
/// [duzeltme] açıksa (yönetebilen kullanıcı, bitişten sonraki yedi gün;
/// ADR-0015 §6) her satırda organizatör düzeltmesi menüsü vardır: katılımı
/// ekle ya da kaldır. Kendi satırında menü yoktur (sunucu: kimse kendi
/// katılımını düzeltemez).
class KatilimcilarBolumu extends ConsumerStatefulWidget {
  const KatilimcilarBolumu({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
    this.duzeltme = false,
  });

  final String tayfaId;
  final String etkinlikId;
  final bool duzeltme;

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
        if (widget.duzeltme) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.etkinlik_duzeltme_bilgi,
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
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
              _KatilimciSatiri(
                anahtar: (
                  tayfaId: widget.tayfaId,
                  etkinlikId: widget.etkinlikId,
                ),
                katilimci: katilimci,
                duzeltme: widget.duzeltme,
              ),
            if (sayfali.dahaHatasi case final hata?) HataSatiri.hatadan(hata),
            if (sayfali.dahaYukleniyor)
              const Center(child: TayfamYukleniyor())
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
          loading: () => [
            const Center(child: TayfamYukleniyor(gecikmeli: true)),
          ],
        ),
      ],
    );
  }
}

enum _Duzeltme { ekle, kaldir }

class _KatilimciSatiri extends ConsumerWidget {
  const _KatilimciSatiri({
    required this.anahtar,
    required this.katilimci,
    required this.duzeltme,
  });

  final EtkinlikAnahtari anahtar;
  final Attendee katilimci;
  final bool duzeltme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final katildi = katilimci.attendance == AttendanceStatus.attended;
    final menu = duzeltme && !ref.watch(kendisiMiProvider(katilimci.userId));
    final mesgul = ref.watch(aracEylemProvider(anahtar));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(
            child: KullaniciAdiMetni(
              kullaniciId: katilimci.userId,
              style: context.yazi.bodyLarge,
            ),
          ),
          if (katildi) Etiket(metin: m.etkinlik_katildi),
          if (menu)
            PopupMenuButton<_Duzeltme>(
              tooltip: m.etkinlik_duzeltme,
              enabled: !mesgul,
              onSelected: (secim) => unawaited(
                _duzelt(context, ref, ekle: secim == _Duzeltme.ekle),
              ),
              itemBuilder: (context) => [
                if (katildi)
                  PopupMenuItem(
                    value: _Duzeltme.kaldir,
                    child: Text(m.etkinlik_duzeltme_kaldir),
                  )
                else
                  PopupMenuItem(
                    value: _Duzeltme.ekle,
                    child: Text(m.etkinlik_duzeltme_ekle),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _duzelt(
    BuildContext context,
    WidgetRef ref, {
    required bool ekle,
  }) async {
    final m = AppLocalizations.of(context);
    if (!ekle) {
      final onay = await cikarmaOnayi(
        context,
        baslik: m.etkinlik_duzeltme_kaldir_onay,
        metin: m.etkinlik_duzeltme_kaldir_metni,
        eylem: m.etkinlik_duzeltme_kaldir,
      );
      if (!onay || !context.mounted) return;
    }
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .katilimDuzelt(katilimci.userId, ekle: ekle);
    if (!context.mounted) return;
    if (hata != null) {
      hataBildir(context, hata);
    } else {
      aracBildir(context, m.etkinlik_duzeltme_tamam);
    }
  }
}
