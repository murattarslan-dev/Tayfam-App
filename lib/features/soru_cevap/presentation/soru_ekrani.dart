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
import 'package:tayfam/features/soru_cevap/application/en_faydali.dart';
import 'package:tayfam/features/soru_cevap/application/soru_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/cevap_karti.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tek bir soru ve cevapları (`/t/<tayfaId>/sorular/<soruId>`; ADR-0018
/// §4; tasarım: Soru-Detay): etiketler, büyük başlık, soran ve tarih, düz
/// metin ayrıntı; "N cevap" başlığı ve cevaplar tek kartta, sunucunun
/// sırasıyla (faydalı oyu çoktan aza) ve sayfalı. İlk cevap en az bir oy
/// almışsa "En faydalı" etiketi taşır. Altta sabit "Cevap yaz".
///
/// Adresteki [soruId] girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez, "bulunamadı" gösterilir. ⋯ menüsünde yazar ile yönetime
/// Düzenle ve (onaylı) Sil, diğerlerine Şikâyet et; kararı sunucu verir
/// (kesin kural 5).
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
        actions: [
          if (soru != null)
            IconButton(
              tooltip: metinler.soru_islemler,
              icon: const Icon(Icons.more_horiz),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              onPressed: () => unawaited(
                _menuyuAc(
                  context,
                  ref,
                  soru,
                  kendisi: kendisi,
                  yonetimde: yonetimde,
                ),
              ),
            ),
          const SizedBox(width: TayfamSpacing.s4),
        ],
      ),
      bottomNavigationBar: soru == null
          ? null
          : _CevapYazCubugu(
              onPressed: () => unawaited(
                cevapFormunuAc(
                  context,
                  tayfaId: tayfaId,
                  soruId: soruId,
                  soruBasligi: soru.title,
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
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
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s4,
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s24,
                ),
                children: [
                  if (soru != null) ...[
                    _SoruIcerigi(soru: soru),
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

  Future<void> _menuyuAc(
    BuildContext context,
    WidgetRef ref,
    Question soru, {
    required bool kendisi,
    required bool yonetimde,
  }) async {
    final metinler = AppLocalizations.of(context);
    final islem = await icerikIslemiSec(
      context,
      baslik: metinler.soru_islemler,
      yonetebilir: kendisi || yonetimde,
    );
    if (islem == null || !context.mounted) return;
    switch (islem) {
      case IcerikIslemi.duzenle:
        await soruFormunuAc(context, tayfaId: tayfaId, duzenlenen: soru);
      case IcerikIslemi.sil:
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
      case IcerikIslemi.sikayet:
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

/// Sorunun kendisi (tasarım: Soru-Detay): etiketler, büyük başlık, soran
/// ve tarih, düz metin ayrıntı.
class _SoruIcerigi extends StatelessWidget {
  const _SoruIcerigi({required this.soru});

  final Question soru;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    final govde = soru.body.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (soru.tags.isNotEmpty) ...[
            SoruEtiketleri(etiketler: soru.tags),
            const SizedBox(height: TayfamSpacing.s12),
          ],
          Semantics(
            header: true,
            child: Text(soru.title, style: yazi.headlineMedium),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          YazarSatiri(yazarId: soru.authorUserId, zaman: soru.createdAt),
          if (govde.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s12),
            // Düz metin: biçim ve bağlantı yorumlanmaz (ADR-0018 §4).
            SelectableText(
              govde,
              style: yazi.bodyLarge?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "N cevap" başlığı, sıralama notu ve cevaplar kartı.
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
    final yazi = context.yazi;
    final saglayici = cevapListesiProvider(anahtar);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    final cevaplar = liste?.ogeler ?? const <Answer>[];
    final enFaydali = enFaydaliCevapKimligi(cevaplar);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TayfamSpacing.s24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
          child: Semantics(
            header: true,
            child: Text(
              soru.answerCount > 0
                  ? metinler.soru_cevap_sayisi(soru.answerCount)
                  : metinler.soru_cevaplar_baslik,
              style: yazi.headlineSmall,
            ),
          ),
        ),
        if (cevaplar.length > 1) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
            child: Text(metinler.soru_cevap_siralama, style: yazi.bodySmall),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s12),
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
        else if (cevaplar.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
            child: Text(
              metinler.soru_cevap_bos,
              style: yazi.bodyLarge?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          )
        else ...[
          ListeKarti(
            children: [
              for (final cevap in cevaplar)
                CevapKarti(
                  cevap: cevap,
                  yonetimde: yonetimde,
                  enFaydali: cevap.id == enFaydali,
                  onOyla: (oy) => unawaited(_oyla(context, ref, cevap, oy)),
                  onIslem: (islem) =>
                      unawaited(_cevapIslemi(context, ref, cevap, islem)),
                ),
            ],
          ),
          if (liste.dahaHatasi case final dahaHatasi?) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri.hatadan(dahaHatasi),
            _TekrarDene(onPressed: () => _dahaFazla(ref)),
          ] else if (liste.dahaYukleniyor) ...[
            const SizedBox(height: TayfamSpacing.s16),
            Center(
              child: TayfamYukleniyor(etiket: metinler.soru_cevap_yukleniyor),
            ),
          ] else if (liste.dahaVar) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Center(
              child: BaglantiEylemi(
                etiket: metinler.tayfa_ana_daha_fazla,
                onPressed: () => _dahaFazla(ref),
              ),
            ),
          ],
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
    IcerikIslemi islem,
  ) async {
    final metinler = AppLocalizations.of(context);
    switch (islem) {
      case IcerikIslemi.duzenle:
        await cevapFormunuAc(
          context,
          tayfaId: anahtar.tayfaId,
          soruId: anahtar.soruId,
          soruBasligi: soru.title,
          duzenlenen: cevap,
        );
      case IcerikIslemi.sil:
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
      case IcerikIslemi.sikayet:
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

/// Altta sabit "Cevap yaz" çubuğu (tasarım: Soru-Detay): zemin rengi,
/// üstte ince çizgi, tam genişlikte birincil eylem.
class _CevapYazCubugu extends StatelessWidget {
  const _CevapYazCubugu({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
            vertical: TayfamSpacing.s12,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: SizedBox(
                width: double.infinity,
                child: BirincilEylem(
                  etiket: AppLocalizations.of(context).soru_cevap_yaz,
                  ikon: Icons.chat_bubble_outline,
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TekrarDene extends StatelessWidget {
  const _TekrarDene({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: BaglantiEylemi(
        etiket: AppLocalizations.of(context).tayfa_ana_tekrar_dene,
        onPressed: onPressed,
      ),
    );
  }
}
