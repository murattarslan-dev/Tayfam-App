import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_listesi.dart';
import 'package:tayfam/features/soru_havuzu/presentation/ortak.dart';
import 'package:tayfam/features/soru_havuzu/presentation/soru_satiri.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın soru havuzu (`/t/<tayfaId>/soru-havuzu`; App ADR-0033 §2,
/// Tayfam-Api ADR-0040 §2): başlıkta tayfanın adı ve "Soru sor", ders/konu
/// süzgeci ve satırları tek kartta sayfalı liste (yeniden eskiye). Aşağı
/// çekince yenilenir. Süzgeç sunucuda uygulanır; seçilen ders ve konu
/// yalnızca istekte gider.
///
/// Her üye soru sorabilir; yetkiyi sunucu verir (kesin kural 5). Modül
/// kapalıysa sunucunun `module-disabled` hatası gösterilir.
class HavuzEkrani extends ConsumerWidget {
  const HavuzEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final suzgec = ref.watch(havuzSuzgeciProvider(tayfaId));
    final saglayici = havuzListesiProvider((tayfaId: tayfaId, suzgec: suzgec));
    final durum = ref.watch(saglayici);
    final tayfaAdi = ref.watch(tayfaOzetiProvider(tayfaId)).ad;
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(
        title: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.soru_havuzu_ad),
              if (tayfaAdi != null)
                Text(
                  tayfaAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.yazi.bodySmall,
                ),
            ],
          ),
        ),
        actions: [
          Center(
            child: CerceveliHapEylem(
              etiket: m.soru_sor,
              ikon: Icons.add,
              onPressed: () =>
                  unawaited(havuzSoruFormunuAc(context, tayfaId: tayfaId)),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
        ],
      ),
      body: TayfamYenile(
        onRefresh: () => _yenile(context, ref, suzgec),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s40,
              ),
              children: [
                _Suzgec(tayfaId: tayfaId, secim: suzgec),
                const SizedBox(height: TayfamSpacing.s12),
                if (liste == null && hata != null)
                  YuklemeHatasi(
                    hata: hata,
                    onTekrarDene: () => ref.invalidate(saglayici),
                  )
                else if (liste == null)
                  Center(
                    child: TayfamYukleniyor(
                      boyut: TayfamSizes.yukleniyorTamEkran,
                      etiket: m.soru_havuzu_yukleniyor,
                      gecikmeli: true,
                    ),
                  )
                else if (liste.ogeler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s4,
                    ),
                    child: Text(
                      suzgec == null
                          ? m.soru_havuzu_bos
                          : m.soru_havuzu_suzgec_bos,
                      style: context.yazi.bodyLarge?.copyWith(
                        color: context.renkler.metinGovde,
                      ),
                    ),
                  )
                else ...[
                  ListeKarti(
                    children: [
                      for (final soru in liste.ogeler)
                        HavuzSoruSatiri(
                          key: ValueKey(soru.id),
                          ders: soru.subjectKey,
                          konu: soru.topicKey,
                          metin: soru.body,
                          fotografSayisi: soru.photoUploadIds.length,
                          cevapSayisi: soru.answerCount,
                          onTap: () => context.go(
                            Adresler.havuzSorusu(tayfaId, soru.id),
                          ),
                        ),
                    ],
                  ),
                  if (liste.dahaHatasi case final dahaHatasi?) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri.hatadan(dahaHatasi),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_tekrar_dene,
                        onPressed: () => _dahaFazla(ref, suzgec),
                      ),
                    ),
                  ] else if (liste.dahaYukleniyor) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    Center(
                      child: TayfamYukleniyor(etiket: m.soru_havuzu_yukleniyor),
                    ),
                  ] else if (liste.dahaVar) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    Center(
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_daha_fazla,
                        onPressed: () => _dahaFazla(ref, suzgec),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref, DersKonuSecimi? suzgec) => unawaited(
    ref
        .read(havuzListesiProvider((tayfaId: tayfaId, suzgec: suzgec)).notifier)
        .dahaFazla(),
  );

  /// Listeyi yeniler; yenileme başarısız olursa eldeki liste kalır ve hata
  /// kısa bildirimle gösterilir.
  Future<void> _yenile(
    BuildContext context,
    WidgetRef ref,
    DersKonuSecimi? suzgec,
  ) async {
    final saglayici = havuzListesiProvider((tayfaId: tayfaId, suzgec: suzgec));
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) {
      yenilemeHatasiBildir(
        context,
        hata,
        tekrarDene: () => unawaited(_yenile(context, ref, suzgec)),
      );
    }
  }
}

/// Ders/konu süzgeci: "Tümü" ve seçili ders/konu (ya da "Ders seç") çipi.
/// Çipe dokununca ortak ders/konu seçicisi alttan açılır. Çipler dar
/// ekranda ve büyük yazıda alt satıra iner.
class _Suzgec extends ConsumerWidget {
  const _Suzgec({required this.tayfaId, required this.secim});

  final String tayfaId;
  final DersKonuSecimi? secim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final secim = this.secim;
    final adlar = secim == null
        ? null
        : dersKonuAdlari(
            ref.watch(katalogProvider).value,
            katalogDili(context),
            ders: secim.ders,
            konu: secim.konu,
          );
    final secimMetni = adlar == null
        ? m.soru_havuzu_ders_sec
        : [adlar.ders, adlar.konu].nonNulls.join(' · ');
    return Semantics(
      container: true,
      label: m.soru_havuzu_suzgec,
      child: Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          SuzgecCipi(
            metin: m.soru_etiket_tumu,
            secili: secim == null,
            onSecildi: () =>
                ref.read(havuzSuzgeciProvider(tayfaId).notifier).ayarla(null),
          ),
          SuzgecCipi(
            metin: secimMetni.isEmpty ? m.soru_havuzu_ders_sec : secimMetni,
            secili: secim != null,
            onSecildi: () => unawaited(_sec(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _sec(BuildContext context, WidgetRef ref) async {
    final sonuc = await altSayfaAc<_SuzgecSonucu>(
      context,
      builder: (_) => _SuzgecSayfasi(ilk: secim),
    );
    if (sonuc == null) return;
    ref.read(havuzSuzgeciProvider(tayfaId).notifier).ayarla(sonuc.secim);
  }
}

/// Süzgeç sayfasının sonucu (`secim` `null`: süzgeç kaldırıldı).
typedef _SuzgecSonucu = ({DersKonuSecimi? secim});

/// Süzgeç seçimi: ortak ders/konu seçicisi, "Temizle" ve "Uygula".
class _SuzgecSayfasi extends StatefulWidget {
  const _SuzgecSayfasi({required this.ilk});

  final DersKonuSecimi? ilk;

  @override
  State<_SuzgecSayfasi> createState() => _SuzgecSayfasiState();
}

class _SuzgecSayfasiState extends State<_SuzgecSayfasi> {
  late DersKonuSecimi? _secim = widget.ilk;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return AltSayfaIcerigi(
      baslik: m.soru_havuzu_suzgec,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DersKonuSecici(
              secim: _secim,
              onDegisti: (yeni) => setState(() => _secim = yeni),
            ),
            const SizedBox(height: TayfamSpacing.s24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                IkincilEylem(
                  etiket: m.soru_havuzu_suzgec_temizle,
                  onPressed: () =>
                      Navigator.of(context).pop<_SuzgecSonucu>((secim: null)),
                ),
                BirincilEylem(
                  etiket: m.soru_havuzu_suzgec_uygula,
                  onPressed: () =>
                      Navigator.of(context).pop<_SuzgecSonucu>((secim: _secim)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
