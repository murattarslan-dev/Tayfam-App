import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Katılımcılar sekmelerinin sırası (tasarım: Etkinlik-Katilimcilar).
const List<ListEventAttendeesStatus> katilimciSekmeleri = [
  ListEventAttendeesStatus.going,
  ListEventAttendeesStatus.maybe,
  ListEventAttendeesStatus.waitlist,
  ListEventAttendeesStatus.notGoing,
];

/// Katılımcılar ekranı (`/t/<tayfaId>/etkinlikler/<etkinlikId>/katilimcilar`;
/// 2026-11-13 yeniden tasarım, ADR-0015 Notlar): cevaba göre durum çipleri
/// (sayılar etkinlikten; "Gelmiyor"un sayısı sözleşmede yok) ve seçili
/// listenin satırları, sayfalı. Varışı doğrulanan kişide "Katıldı" etiketi.
///
/// Organizatör düzeltmesi (yönetebilen kullanıcı, bitişten sonraki yedi
/// gün; ADR-0015 §6) açıksa üstte bilgi kutusu ve her satırda ⋯ düğmesi
/// vardır: alttan sayfada katılımı ekle ya da kaldır. Kendi satırında
/// düğme yoktur (sunucu: kimse kendi katılımını düzeltemez).
///
/// Adresteki kimlikler girdi kabul edilir: biçimi bozuk etkinlik kimliği
/// için istek gönderilmez.
class KatilimcilarEkrani extends ConsumerStatefulWidget {
  const KatilimcilarEkrani({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
  });

  final String tayfaId;
  final String etkinlikId;

  @override
  ConsumerState<KatilimcilarEkrani> createState() => _KatilimcilarEkraniState();
}

class _KatilimcilarEkraniState extends ConsumerState<KatilimcilarEkrani> {
  ListEventAttendeesStatus _sekme = ListEventAttendeesStatus.going;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    if (!uuidBicimindeMi(widget.etkinlikId)) {
      return Scaffold(
        appBar: AppBar(title: Text(m.etkinlik_katilimcilar_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: m.hata_event_not_found),
        ),
      );
    }
    final etkinlikAnahtari = (
      tayfaId: widget.tayfaId,
      etkinlikId: widget.etkinlikId,
    );
    final etkinlik = ref.watch(etkinlikDetayProvider(etkinlikAnahtari)).value;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final duzeltme =
        etkinlik != null && katilimDuzeltmeAcik(etkinlik, simdi);
    final anahtar = (
      tayfaId: widget.tayfaId,
      etkinlikId: widget.etkinlikId,
      durum: _sekme,
    );
    final liste = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    final govde = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return Scaffold(
      appBar: AppBar(
        title: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.etkinlik_katilimcilar_baslik),
              if (etkinlik != null)
                Text(
                  etkinlik.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.yazi.bodySmall,
                ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.yenile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                for (final durum in katilimciSekmeleri)
                  ChoiceChip(
                    label: Text(_sekmeEtiketi(m, durum, etkinlik)),
                    selected: _sekme == durum,
                    onSelected: (_) => setState(() => _sekme = durum),
                  ),
              ],
            ),
            if (duzeltme) ...[
              const SizedBox(height: TayfamSpacing.s16),
              _BilgiKutusu(metin: m.etkinlik_duzeltme_bilgi),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            ...liste.when<List<Widget>>(
              data: (sayfali) => [
                if (sayfali.ogeler.isEmpty)
                  Text(m.etkinlik_katilimci_yok, style: govde)
                else
                  ListeKarti(
                    children: [
                      for (final katilimci in sayfali.ogeler)
                        _KatilimciSatiri(
                          anahtar: etkinlikAnahtari,
                          katilimci: katilimci,
                          duzeltme: duzeltme,
                        ),
                    ],
                  ),
                if (sayfali.dahaHatasi case final hata?) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  HataSatiri.hatadan(hata),
                ],
                if (sayfali.dahaYukleniyor)
                  const Center(child: TayfamYukleniyor())
                else if (sayfali.dahaVar)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BaglantiEylemi(
                      etiket: m.etkinlik_daha_fazla,
                      onPressed: () => unawaited(notifier.dahaFazla()),
                    ),
                  ),
              ],
              error: (hata, _) => [
                HataSatiri.hatadan(hata),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BaglantiEylemi(
                    etiket: m.etkinlik_tekrar_dene,
                    onPressed: () => unawaited(notifier.yenile()),
                  ),
                ),
              ],
              loading: () => [
                const Center(child: TayfamYukleniyor(gecikmeli: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Çipin metni: sayısı bilinen durumlarda ad ve sayı ("Geliyor 24").
String _sekmeEtiketi(
  AppLocalizations m,
  ListEventAttendeesStatus durum,
  Event? etkinlik,
) {
  final ad = katilimciSekmesi(m, durum);
  if (etkinlik == null) return ad;
  final sayi = switch (durum) {
    ListEventAttendeesStatus.going => etkinlik.goingCount,
    ListEventAttendeesStatus.maybe => etkinlik.maybeCount,
    ListEventAttendeesStatus.waitlist => etkinlik.waitlistCount,
    ListEventAttendeesStatus.notGoing ||
    ListEventAttendeesStatus.unknown => null,
  };
  if (sayi == null) return ad;
  return m.etkinlik_katilimci_sekme_sayisi(ad, etkinlikSayi(m, sayi));
}

/// Tint-brand bilgi kutusu (tasarım: Etkinlik-Katilimcilar).
class _BilgiKutusu extends StatelessWidget {
  const _BilgiKutusu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                size: TayfamSizes.ikon,
                color: r.tintMarkaUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: Text(
                metin,
                style: context.yazi.bodyMedium?.copyWith(
                  color: r.tintMarkaUstu,
                ),
              ),
            ),
          ],
        ),
      ),
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
      constraints: const BoxConstraints(minHeight: TayfamSizes.menuSatiri),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s16,
          TayfamSpacing.s8,
          TayfamSpacing.s4,
          TayfamSpacing.s8,
        ),
        child: Row(
          children: [
            KimlikAvatari(kullaniciId: katilimci.userId),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: MergeSemantics(
                child: Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    KullaniciAdiMetni(
                      kullaniciId: katilimci.userId,
                      style: context.yazi.titleSmall,
                    ),
                    if (katildi)
                      Etiket(
                        metin: m.etkinlik_katildi,
                        ton: EtiketTonu.teal,
                        ikon: Icons.check,
                      )
                    else if (duzeltme)
                      Text(
                        m.etkinlik_varis_yok,
                        style: context.yazi.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            if (menu)
              AracIkonDugmesi(
                ipucu: m.etkinlik_duzeltme,
                ikon: Icons.more_horiz,
                onPressed: mesgul
                    ? null
                    : () => unawaited(_menuyuAc(context, ref, katildi)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _menuyuAc(
    BuildContext context,
    WidgetRef ref,
    bool katildi,
  ) async {
    final m = AppLocalizations.of(context);
    final secim = await altSayfaAc<_Duzeltme>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.etkinlik_duzeltme,
        children: [
          if (katildi)
            MenuSatiri(
              baslik: m.etkinlik_duzeltme_kaldir,
              ikon: Icons.remove_circle_outline,
              tur: MenuSatiriTuru.yikici,
              onTap: () => Navigator.of(sayfa).pop(_Duzeltme.kaldir),
            )
          else
            MenuSatiri(
              baslik: m.etkinlik_duzeltme_ekle,
              ikon: Icons.how_to_reg_outlined,
              onTap: () => Navigator.of(sayfa).pop(_Duzeltme.ekle),
            ),
        ],
      ),
    );
    if (secim == null || !context.mounted) return;
    await _duzelt(context, ref, ekle: secim == _Duzeltme.ekle);
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
