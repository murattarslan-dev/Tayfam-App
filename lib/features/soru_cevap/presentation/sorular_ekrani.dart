import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/application/etiketler_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın soruları (`/t/<tayfaId>/sorular`; ADR-0018 §4): arama, etiket
/// süzgeci ve sayfalı liste. Aşağı çekince yenilenir.
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

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final suzgec = ref.watch(soruSuzgeciProvider(_tayfaId));
    final saglayici = soruListesiProvider(suzgec.anahtar(_tayfaId));
    final durum = ref.watch(saglayici);
    final etiketler = ref.watch(etiketlerProvider(_tayfaId)).value;
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(metinler.soru_liste_baslik)),
      body: RefreshIndicator(
        onRefresh: () => _yenile(suzgec),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: metinler.soru_sor,
                ikon: Icons.help_outline,
                onPressed: () =>
                    unawaited(soruFormunuAc(context, tayfaId: _tayfaId)),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            TextField(
              controller: _arama,
              maxLength: soruAramasiEnCok,
              textInputAction: TextInputAction.search,
              onChanged: _aramaDegisti,
              onSubmitted: _aramaGonder,
              decoration: InputDecoration(
                labelText: metinler.soru_arama_etiketi,
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
              const SizedBox(height: TayfamSpacing.s8),
              _EtiketSuzgeci(
                etiketler: etiketler,
                seciliId: suzgec.etiketId,
                onSecildi: _suzgec.etiketSec,
              ),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ] else if (liste == null)
              Center(
                child: CircularProgressIndicator(
                  semanticsLabel: metinler.soru_yukleniyor,
                ),
              )
            else if (liste.ogeler.isEmpty)
              Text(
                suzgec.etkin ? metinler.soru_arama_bos : metinler.soru_bos,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              )
            else ...[
              for (final (sira, soru) in liste.ogeler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                SoruKarti(
                  soru: soru,
                  onTap: () => context.go(Adresler.soru(_tayfaId, soru.id)),
                ),
              ],
              const SizedBox(height: TayfamSpacing.s16),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                _TekrarDene(onPressed: () => _dahaFazla(suzgec)),
              ] else if (liste.dahaYukleniyor)
                Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: metinler.soru_yukleniyor,
                  ),
                )
              else if (liste.dahaVar)
                Center(
                  child: TextButton(
                    onPressed: () => _dahaFazla(suzgec),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(metinler.tayfa_ana_daha_fazla),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(SoruSuzgeci suzgec) => unawaited(
    ref.read(soruListesiProvider(suzgec.anahtar(_tayfaId)).notifier).dahaFazla(),
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

/// Etiket süzgeci: yatay kaydırılan seçim çipleri; en çok bir etiket seçili.
class _EtiketSuzgeci extends StatelessWidget {
  const _EtiketSuzgeci({
    required this.etiketler,
    required this.seciliId,
    required this.onSecildi,
  });

  final List<Tag> etiketler;
  final String? seciliId;
  final ValueChanged<String> onSecildi;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).soru_etiket_suzgeci,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (sira, etiket) in etiketler.indexed) ...[
              if (sira > 0) const SizedBox(width: TayfamSpacing.s8),
              FilterChip(
                label: Text(etiket.name),
                selected: etiket.id == seciliId,
                onSelected: (_) => onSecildi(etiket.id),
              ),
            ],
          ],
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
