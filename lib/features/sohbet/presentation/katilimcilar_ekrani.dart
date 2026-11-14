import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanal_kisileri.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ortak.dart';
import 'package:tayfam/features/sohbet/presentation/kisi_secici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kanalın katılımcılar ekranını açar.
Future<void> katilimcilariAc(BuildContext context, KanalRef kanal) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => KatilimcilarEkrani(kanal: kanal)),
    );

/// Etkinlik ya da seçili kişi kanalının katılımcıları (2026-11-13 tasarım:
/// Kanal-Katilimcilar, Kanal-Katilimcilar-Etkinlik; Tayfam-Api #183).
///
/// - Liste `GET …/channels/{id}/members`'tan (yalnızca kimlik); adlar
///   profil önbelleğinden.
/// - Seçili kişi kanalında "Kişi ekle" ve satırlardaki "Çıkar" yalnızca
///   kanalı açana görünür; yönetim de değiştiremez. Bu kolaylıktır,
///   kararı sunucu verir (kesin kural 5).
/// - Etkinlik kanalının listesi salt okunurdur: kitle katılım cevabından
///   gelir.
/// - Kanala erişim kalmazsa (çıkarıldın) ekran kapanır.
class KatilimcilarEkrani extends ConsumerStatefulWidget {
  const KatilimcilarEkrani({super.key, required this.kanal});

  final KanalRef kanal;

  @override
  ConsumerState<KatilimcilarEkrani> createState() => _KatilimcilarEkraniState();
}

class _KatilimcilarEkraniState extends ConsumerState<KatilimcilarEkrani> {
  final Set<String> _isleniyor = {};

  Channel? _bul(List<Channel>? liste) {
    for (final k in liste ?? const <Channel>[]) {
      if (k.id == widget.kanal.kanalId) return k;
    }
    return null;
  }

  Future<void> _ekle(Channel kanal, List<String> mevcut) async {
    final secilen = await kisiSeciciyiAc(
      context,
      tayfaId: widget.kanal.tayfaId,
      kanalAdi: kanal.name,
      kanalda: mevcut.toSet(),
      ekleme: true,
    );
    if (secilen == null || secilen.isEmpty || !mounted) return;
    try {
      await ref
          .read(kanallarProvider(widget.kanal.tayfaId).notifier)
          .katilimciEkle(kanal.id, secilen);
      if (!mounted) return;
      await ref.read(katilimcilarProvider(widget.kanal).notifier).yenile();
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    }
  }

  Future<void> _cikar(String kisi) async {
    setState(() => _isleniyor.add(kisi));
    try {
      await ref
          .read(kanallarProvider(widget.kanal.tayfaId).notifier)
          .katilimciCikar(widget.kanal.kanalId, kisi);
      if (mounted) {
        ref.read(katilimcilarProvider(widget.kanal).notifier).dus(kisi);
      }
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _isleniyor.remove(kisi));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = katilimcilarProvider(widget.kanal);
    final durum = ref.watch(saglayici);
    final kanal = _bul(ref.watch(kanallarProvider(widget.kanal.tayfaId)).value);

    ref.listen(kanallarProvider(widget.kanal.tayfaId), (onceki, simdiki) {
      final vardi = _bul(onceki?.value) != null;
      if (vardi && simdiki.hasValue && _bul(simdiki.value) == null) {
        unawaited(Navigator.of(context).maybePop());
      }
    });

    final kitle = kanal == null ? null : KanalKitlesi.kanaldan(kanal);
    final acan = kanal?.creatorUserId;
    final acanBenim = acan != null && ref.watch(kendisiMiProvider(acan));
    final duzenlenebilir =
        kitle == KanalKitlesi.secili && acanBenim && kanal?.archivedAt == null;
    final liste = durum.value;
    final kisiler = [
      // Kanalı açan listenin başında.
      if (acan != null && (liste?.ogeler.contains(acan) ?? false)) acan,
      for (final k in liste?.ogeler ?? const <String>[])
        if (k != acan) k,
    ];
    final sayi = kanal?.memberCount ?? kisiler.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.sohbet_katilimcilar_baslik),
            if (kanal != null)
              Text(
                kitle == KanalKitlesi.etkinlik
                    ? m.sohbet_katilimcilar_alt_etkinlik(kanal.name)
                    : m.sohbet_katilimcilar_alt_secili(kanal.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final hata = await ref.read(saglayici.notifier).yenile();
          if (hata != null && context.mounted) hataBildir(context, hata);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            if (kitle == KanalKitlesi.etkinlik)
              Text(
                m.sohbet_katilimcilar_etkinlik_bilgi,
                style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
            if (duzenlenebilir && kanal != null)
              BirincilEylem(
                etiket: m.sohbet_kisi_ekle,
                ikon: Icons.person_add_alt,
                onPressed: liste == null
                    ? null
                    : () => unawaited(_ekle(kanal, kisiler)),
              ),
            if (liste == null && durum.error != null) ...[
              const SizedBox(height: TayfamSpacing.s16),
              HataSatiri.hatadan(durum.error!),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: BaglantiEylemi(
                  etiket: m.sohbet_tekrar_dene,
                  onPressed: () => ref.invalidate(saglayici),
                ),
              ),
            ] else if (liste == null)
              Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s24),
                child: Center(
                  child: TayfamYukleniyor(
                    etiket: m.sohbet_katilimcilar_yukleniyor,
                    gecikmeli: true,
                  ),
                ),
              )
            else ...[
              BolumEtiketi(
                baslik: m.sohbet_kanal_kisi_sayisi(sayi),
                sag: kitle == KanalKitlesi.secili
                    ? Text(
                        m.sohbet_katilimcilar_acan_icerde,
                        style: context.yazi.bodySmall?.copyWith(
                          color: r.metinIkincil,
                        ),
                      )
                    : null,
              ),
              ListeKarti(
                children: [
                  for (final kisi in kisiler)
                    ListeKartiSatiri(
                      child: _KatilimciSatiri(
                        kisi: kisi,
                        acan: kisi == acan,
                        cikar: duzenlenebilir && kisi != acan
                            ? (_isleniyor.contains(kisi)
                                  ? null
                                  : () => unawaited(_cikar(kisi)))
                            : null,
                        cikarGoster: duzenlenebilir && kisi != acan,
                      ),
                    ),
                ],
              ),
              if (liste.dahaHatasi case final hata?) HataSatiri.hatadan(hata),
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
              if (duzenlenebilir) ...[
                const SizedBox(height: TayfamSpacing.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s4,
                  ),
                  child: Text(
                    m.sohbet_katilimcilar_not,
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinIkincil,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Katılımcı satırı: kişi, kanalı açansa "Kanalı açan"; kanalı açana
/// diğer satırlarda "Çıkar".
class _KatilimciSatiri extends ConsumerWidget {
  const _KatilimciSatiri({
    required this.kisi,
    required this.acan,
    required this.cikar,
    required this.cikarGoster,
  });

  final String kisi;
  final bool acan;
  final VoidCallback? cikar;
  final bool cikarGoster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    return KisiSatiriIcerigi(
      kisi: kisi,
      altMetin: acan ? m.sohbet_katilimci_acan : null,
      sag: cikarGoster
          ? YikiciEylem(
              etiket: m.sohbet_katilimci_cikar,
              semantikEtiketi: m.sohbet_katilimci_cikar_etiket(
                kisiAdi(m, ref, kisi),
              ),
              onPressed: cikar,
            )
          : null,
    );
  }
}
