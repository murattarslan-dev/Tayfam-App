import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/soru_cevap/application/cevap_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/cevap_karti.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_karti.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru işlemleri menüsünün seçenekleri.
enum SoruIslemi { duzenle, sil, sikayet }

/// Tek bir soru ve cevapları (`/t/<tayfaId>/sorular/<soruId>`; ADR-0018
/// §4). Cevaplar "faydalı" oyuna göre sıralıdır ve sayfalıdır.
///
/// Adresteki [soruId] girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez, "bulunamadı" gösterilir. Düzenleme ve (onaylı) silme
/// yazar ile yönetime gösterilir; kararı sunucu verir (kesin kural 5).
class SoruEkrani extends ConsumerWidget {
  const SoruEkrani({super.key, required this.tayfaId, required this.soruId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  /// Adresteki soru kimliği; biçimi burada doğrulanır.
  final String soruId;

  SoruAnahtari get _anahtar => (tayfaId: tayfaId, soruId: soruId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    if (!uuidBicimindeMi(soruId)) {
      return Scaffold(
        appBar: AppBar(title: Text(metinler.soru_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: metinler.hata_question_not_found),
        ),
      );
    }
    final saglayici = soruProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
    final soru = durum.value;
    final hata = durum.error;
    final yazarId = soru?.authorUserId;
    final kendisi = yazarId != null && ref.watch(kendisiMiProvider(yazarId));
    return Scaffold(
      appBar: AppBar(
        title: Text(metinler.soru_baslik),
        actions: [
          if (soru != null)
            PopupMenuButton<SoruIslemi>(
              tooltip: metinler.soru_islemler,
              icon: const Icon(Icons.more_vert),
              onSelected: (islem) =>
                  unawaited(_soruIslemi(context, ref, soru, islem, kendisi)),
              itemBuilder: (_) => [
                if (kendisi || yonetimde) ...[
                  PopupMenuItem(
                    value: SoruIslemi.duzenle,
                    child: Text(metinler.soru_duzenle),
                  ),
                  PopupMenuItem(
                    value: SoruIslemi.sil,
                    child: Text(metinler.soru_sil),
                  ),
                ],
                // Başkasının sorusu şikâyet edilebilir (ADR-0018 §8).
                if (!kendisi)
                  PopupMenuItem(
                    value: SoruIslemi.sikayet,
                    child: Text(metinler.sikayet_et),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: RefreshIndicator(
              onRefresh: () => _yenile(context, ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                children: [
                  if (soru != null) ...[
                    _SoruIcerigi(soru: soru),
                    const SizedBox(height: TayfamSpacing.s24),
                    _Cevaplar(
                      anahtar: _anahtar,
                      soru: soru,
                      yonetimde: yonetimde,
                    ),
                  ] else if (hata != null) ...[
                    HataSatiri.hatadan(hata),
                    _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
                  ] else
                    Center(
                      child: TayfamYukleniyor(
                        boyut: TayfamSizes.yukleniyorTamEkran,
                        etiket: metinler.soru_yukleniyor,
                        gecikmeli: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Soruyu ve cevapları yeniden okur.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final soru = soruProvider(_anahtar);
    if (!ref.read(soru).hasValue) {
      ref.invalidate(soru);
      return;
    }
    final hatalar = await Future.wait([
      ref.read(soru.notifier).yenile(),
      ref.read(cevapListesiProvider(_anahtar).notifier).yenile(),
    ]);
    final hata = hatalar.nonNulls.firstOrNull;
    if (hata == null || !context.mounted) return;
    islemHatasiniBildir(context, hata);
  }

  Future<void> _soruIslemi(
    BuildContext context,
    WidgetRef ref,
    Question soru,
    SoruIslemi islem,
    bool kendisi,
  ) async {
    final metinler = AppLocalizations.of(context);
    switch (islem) {
      case SoruIslemi.duzenle:
        await soruFormunuAc(context, tayfaId: tayfaId, duzenlenen: soru);
      case SoruIslemi.sil:
        final onay = await silmeyiOnayla(
          context,
          baslik: metinler.soru_sil_onay_baslik,
          aciklama: kendisi
              ? metinler.soru_sil_onay_kendi
              : metinler.soru_sil_onay_yonetim,
        );
        if (!onay || !context.mounted) return;
        final bildirim = ScaffoldMessenger.of(context);
        final hata = await ref.read(soruProvider(_anahtar).notifier).sil();
        if (!context.mounted) return;
        if (hata != null) {
          islemHatasiniBildir(context, hata);
          return;
        }
        bildirimGoster(bildirim, metinler.soru_silindi);
        await Navigator.of(context).maybePop();
      case SoruIslemi.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: tayfaId,
            tur: ReportTargetType.question,
            id: soru.id,
          ),
        );
    }
  }
}

class _SoruIcerigi extends StatelessWidget {
  const _SoruIcerigi({required this.soru});

  final Question soru;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    final govde = soru.body.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (soru.tags.isNotEmpty) ...[
          SoruEtiketleri(etiketler: soru.tags),
          const SizedBox(height: TayfamSpacing.s12),
        ],
        Semantics(
          header: true,
          child: Text(soru.title, style: yazi.headlineSmall),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        YazarSatiri(yazarId: soru.authorUserId, zaman: soru.createdAt),
        if (govde.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s16),
          // Düz metin: biçim ve bağlantı yorumlanmaz (ADR-0018 §4).
          SelectableText(
            govde,
            style: yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde),
          ),
        ],
      ],
    );
  }
}

class _Cevaplar extends ConsumerWidget {
  const _Cevaplar({
    required this.anahtar,
    required this.soru,
    required this.yonetimde,
  });

  final SoruAnahtari anahtar;
  final Question soru;
  final bool yonetimde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = cevapListesiProvider(anahtar);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(baslik: metinler.soru_cevaplar_baslik),
        const SizedBox(height: TayfamSpacing.s4),
        CevapSayisi(sayi: soru.answerCount),
        const SizedBox(height: TayfamSpacing.s12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BirincilEylem(
            etiket: metinler.soru_cevap_yaz,
            ikon: Icons.edit_outlined,
            onPressed: () => unawaited(
              cevapFormunuAc(
                context,
                tayfaId: anahtar.tayfaId,
                soruId: anahtar.soruId,
              ),
            ),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
        ] else if (liste == null)
          Center(
            child: TayfamYukleniyor(
              boyut: TayfamSizes.yukleniyorTamEkran,
              etiket: metinler.soru_cevap_yukleniyor,
              gecikmeli: true,
            ),
          )
        else if (liste.ogeler.isEmpty)
          Text(
            metinler.soru_cevap_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          )
        else ...[
          for (final (sira, cevap) in liste.ogeler.indexed) ...[
            if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
            CevapKarti(
              cevap: cevap,
              yonetimde: yonetimde,
              onOyla: (oy) => unawaited(_oyla(context, ref, cevap, oy)),
              onIslem: (islem) =>
                  unawaited(_cevapIslemi(context, ref, cevap, islem)),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s16),
          if (liste.dahaHatasi case final dahaHatasi?) ...[
            HataSatiri.hatadan(dahaHatasi),
            _TekrarDene(onPressed: () => _dahaFazla(ref)),
          ] else if (liste.dahaYukleniyor)
            Center(
              child: TayfamYukleniyor(etiket: metinler.soru_cevap_yukleniyor),
            )
          else if (liste.dahaVar)
            Center(
              child: TextButton(
                onPressed: () => _dahaFazla(ref),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(metinler.tayfa_ana_daha_fazla),
              ),
            ),
        ],
      ],
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(cevapListesiProvider(anahtar).notifier).dahaFazla());

  Future<void> _oyla(
    BuildContext context,
    WidgetRef ref,
    Answer cevap,
    bool oy,
  ) async {
    final notifier = ref.read(cevapListesiProvider(anahtar).notifier);
    final hata = await notifier.oyla(cevap.id, oy: oy);
    if (hata != null && context.mounted) islemHatasiniBildir(context, hata);
  }

  Future<void> _cevapIslemi(
    BuildContext context,
    WidgetRef ref,
    Answer cevap,
    CevapIslemi islem,
  ) async {
    final metinler = AppLocalizations.of(context);
    switch (islem) {
      case CevapIslemi.duzenle:
        await cevapFormunuAc(
          context,
          tayfaId: anahtar.tayfaId,
          soruId: anahtar.soruId,
          duzenlenen: cevap,
        );
      case CevapIslemi.sil:
        final yazarId = cevap.authorUserId;
        final kendisi = yazarId != null && ref.read(kendisiMiProvider(yazarId));
        final onay = await silmeyiOnayla(
          context,
          baslik: metinler.soru_cevap_sil_onay_baslik,
          aciklama: kendisi
              ? metinler.soru_cevap_sil_onay_kendi
              : metinler.soru_cevap_sil_onay_yonetim,
        );
        if (!onay || !context.mounted) return;
        final bildirim = ScaffoldMessenger.of(context);
        final notifier = ref.read(cevapListesiProvider(anahtar).notifier);
        final hata = await notifier.sil(cevap.id);
        if (!context.mounted) return;
        if (hata != null) {
          islemHatasiniBildir(context, hata);
          return;
        }
        bildirimGoster(bildirim, metinler.soru_cevap_silindi);
      case CevapIslemi.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: anahtar.tayfaId,
            tur: ReportTargetType.answer,
            id: cevap.id,
          ),
        );
    }
  }
}

class _TekrarDene extends StatelessWidget {
  const _TekrarDene({required this.onPressed});

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
