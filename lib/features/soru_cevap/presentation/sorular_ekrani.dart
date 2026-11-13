import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/soru_cevap/application/etiketler_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_bolumu.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın soruları (`/t/<tayfaId>/sorular`; ADR-0018 §4; tasarım:
/// Sorular): başlıkta tayfanın adı ve "Soru sor", arama, etiket çipleriyle
/// süzme ve satırları tek kartta sayfalı liste (soru, etiketler, cevap
/// sayısı ve zaman). Aşağı çekince yenilenir.
///
/// Arama sunucuda yapılır (Türkçe büyük-küçük harf duyarsız); yazmayı
/// bırakınca ya da klavyede "Ara"ya basınca başlar. Arama metni yalnızca
/// istekte gider; saklanmaz, loglanmaz. Her üye soru sorabilir.
class SorularEkrani extends ConsumerStatefulWidget {
  const SorularEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<SorularEkrani> createState() => _SorularEkraniState();
}

class _SorularEkraniState extends ConsumerState<SorularEkrani> {
  final TextEditingController _arama = TextEditingController();
  Timer? _gecikme;

  String get _tayfaId => widget.tayfaId;

  SoruSuzgeciNotifier get _suzgec =>
      ref.read(soruSuzgeciProvider(_tayfaId).notifier);

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  void _aramaDegisti(String metin) {
    setState(() {});
    _gecikme?.cancel();
    _gecikme = Timer(soruAramasiGecikmesi, () => _suzgec.aramaAyarla(metin));
  }

  void _aramaGonder(String metin) {
    _gecikme?.cancel();
    _suzgec.aramaAyarla(metin);
  }

  void _aramayiTemizle() {
    _gecikme?.cancel();
    _arama.clear();
    setState(() {});
    _suzgec.aramaAyarla('');
  }

  /// "Tümü" çipi: seçili etiket varsa kaldırır.
  void _tumunuGoster(String? seciliId) {
    if (seciliId != null) _suzgec.etiketSec(seciliId);
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final suzgec = ref.watch(soruSuzgeciProvider(_tayfaId));
    final saglayici = soruListesiProvider(suzgec.anahtar(_tayfaId));
    final durum = ref.watch(saglayici);
    final etiketler = ref.watch(etiketlerProvider(_tayfaId)).value;
    final tayfaAdi = ref.watch(tayfaOzetiProvider(_tayfaId)).ad;
    final simdi = ref.watch(simdiProvider)();
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(
        title: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(metinler.soru_liste_baslik),
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
            child: _SoruSorDugmesi(
              onPressed: () =>
                  unawaited(soruFormunuAc(context, tayfaId: _tayfaId)),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _yenile(suzgec),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s4,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            TextField(
              controller: _arama,
              maxLength: soruAramasiEnCok,
              textInputAction: TextInputAction.search,
              onChanged: _aramaDegisti,
              onSubmitted: _aramaGonder,
              decoration:
                  soruAlanGorunumu(
                    context,
                    koseler: TayfamRadii.hapKoseleri,
                  ).copyWith(
                    hintText: metinler.soru_arama_etiketi,
                    counterText: '',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _arama.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: metinler.soru_arama_temizle,
                            icon: const Icon(Icons.close),
                            onPressed: _aramayiTemizle,
                          ),
                  ),
            ),
            if (etiketler != null && etiketler.isNotEmpty) ...[
              const SizedBox(height: TayfamSpacing.s12),
              _EtiketSuzgeci(
                etiketler: etiketler,
                seciliId: suzgec.etiketId,
                onSecildi: _suzgec.etiketSec,
                onTumu: () => _tumunuGoster(suzgec.etiketId),
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
                  etiket: metinler.soru_yukleniyor,
                  gecikmeli: true,
                ),
              )
            else if (liste.ogeler.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s4,
                ),
                child: Text(
                  suzgec.etkin ? metinler.soru_arama_bos : metinler.soru_bos,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              )
            else ...[
              ListeKarti(
                children: [
                  for (final soru in liste.ogeler)
                    SoruSatiri(
                      soru: soru,
                      simdi: simdi,
                      etiketli: true,
                      onTap: () => context.go(Adresler.soru(_tayfaId, soru.id)),
                    ),
                ],
              ),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                const SizedBox(height: TayfamSpacing.s8),
                HataSatiri.hatadan(dahaHatasi),
                _TekrarDene(onPressed: () => _dahaFazla(suzgec)),
              ] else if (liste.dahaYukleniyor) ...[
                const SizedBox(height: TayfamSpacing.s16),
                Center(
                  child: TayfamYukleniyor(etiket: metinler.soru_yukleniyor),
                ),
              ] else if (liste.dahaVar) ...[
                const SizedBox(height: TayfamSpacing.s8),
                Center(
                  child: BaglantiEylemi(
                    etiket: metinler.tayfa_ana_daha_fazla,
                    onPressed: () => _dahaFazla(suzgec),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(SoruSuzgeci suzgec) => unawaited(
    ref
        .read(soruListesiProvider(suzgec.anahtar(_tayfaId)).notifier)
        .dahaFazla(),
  );

  /// Listeyi ve etiketleri yeniler. Yenileme başarısız olursa eldeki liste
  /// kalır ve hata kısa bildirimle gösterilir.
  Future<void> _yenile(SoruSuzgeci suzgec) async {
    ref.invalidate(etiketlerProvider(_tayfaId));
    final saglayici = soruListesiProvider(suzgec.anahtar(_tayfaId));
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !mounted) return;
    if (ref.read(saglayici).hasValue) islemHatasiniBildir(context, hata);
  }
}

/// Başlıktaki "Soru sor" (tasarım: Sorular): tint-brand zeminli hap
/// düğme, ikonlu; en az 48 px.
class _SoruSorDugmesi extends StatelessWidget {
  const _SoruSorDugmesi({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: r.tintMarka,
          foregroundColor: r.tintMarkaUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
          shape: const StadiumBorder(),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(
          etiket: AppLocalizations.of(context).soru_sor,
          ikon: Icons.add,
        ),
      ),
    );
  }
}

/// Etiket süzgeci (tasarım: Sorular): yatay kaydırılan çipler; başta
/// "Tümü", en çok bir etiket seçili. Seçili çip marka zeminlidir; seçim
/// ekran okuyucuya da bildirilir.
class _EtiketSuzgeci extends StatelessWidget {
  const _EtiketSuzgeci({
    required this.etiketler,
    required this.seciliId,
    required this.onSecildi,
    required this.onTumu,
  });

  final List<Tag> etiketler;
  final String? seciliId;
  final ValueChanged<String> onSecildi;
  final VoidCallback onTumu;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: m.soru_etiket_suzgeci,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SuzgecCipi(
              metin: m.soru_etiket_tumu,
              secili: seciliId == null,
              onSecildi: onTumu,
            ),
            for (final etiket in etiketler) ...[
              const SizedBox(width: TayfamSpacing.s8),
              SuzgecCipi(
                metin: etiket.name,
                secili: etiket.id == seciliId,
                onSecildi: () => onSecildi(etiket.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Süzgeç çipi (tasarım: Sorular, Soru-Form "Tayfadaki etiketler"):
/// seçiliyken marka zemin, değilken kart zemin ve çerçeve; 13 px 700.
class SuzgecCipi extends StatelessWidget {
  const SuzgecCipi({
    super.key,
    required this.metin,
    required this.secili,
    required this.onSecildi,
  });

  final String metin;
  final bool secili;
  final VoidCallback? onSecildi;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onSecildi = this.onSecildi;
    return ChoiceChip(
      label: Text(metin),
      selected: secili,
      showCheckmark: false,
      onSelected: onSecildi == null ? null : (_) => onSecildi(),
      selectedColor: r.marka,
      backgroundColor: r.kart,
      shape: const StadiumBorder(),
      side: BorderSide(
        color: secili ? r.marka : r.cizgi,
        width: TayfamSizes.vurguKenari,
      ),
      labelStyle: context.yazi.labelMedium?.copyWith(
        color: secili ? r.markaUstu : r.metin,
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
