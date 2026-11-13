import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/application/cevap_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Cevap yazma ve düzenleme formu (ADR-0018 §4; tasarım: Cevap-Form):
/// üstte sorunun alıntısı, sayaçlı düz metin (1–10000 karakter); gönder
/// düğmesi sağ üstte. Kabuğun üstünde tam ekran açılır; başarıda kapanır
/// ve cevabı döndürür. Bağlantı yoksa form açık kalır, girilenler korunur.
class CevapFormuEkrani extends ConsumerStatefulWidget {
  const CevapFormuEkrani({
    super.key,
    required this.tayfaId,
    required this.soruId,
    required this.soruBasligi,
    this.duzenlenen,
  });

  final String tayfaId;

  final String soruId;

  /// Formun üstünde alıntılanan sorunun başlığı.
  final String soruBasligi;

  /// Düzenlenen cevap; yeni cevapta `null`.
  final Answer? duzenlenen;

  @override
  ConsumerState<CevapFormuEkrani> createState() => _CevapFormuEkraniState();
}

class _CevapFormuEkraniState extends ConsumerState<CevapFormuEkrani> {
  late final TextEditingController _govde;

  CevapFormuAnahtari get _anahtar => (
    tayfaId: widget.tayfaId,
    soruId: widget.soruId,
    duzenlenen: widget.duzenlenen,
  );

  CevapFormuNotifier get _notifier =>
      ref.read(cevapFormuProvider(_anahtar).notifier);

  @override
  void initState() {
    super.initState();
    _govde = TextEditingController(
      text: ref.read(cevapFormuProvider(_anahtar)).govde,
    );
  }

  @override
  void dispose() {
    _govde.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final saglayici = cevapFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      final cevap = sonraki.tamamlanan;
      if (cevap != null) Navigator.of(context).pop(cevap);
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          yeni
              ? metinler.soru_cevap_form_yeni
              : metinler.soru_cevap_form_duzenle,
        ),
        actions: [
          FormUstEylemi(
            etiket: yeni
                ? metinler.soru_cevap_form_gonder
                : metinler.soru_form_kaydet,
            onPressed: kilitli ? null : () => unawaited(_notifier.gonder()),
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
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s4,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SoruAlintisi(baslik: widget.soruBasligi),
                  const SizedBox(height: TayfamSpacing.s16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s4,
                    ),
                    child: TextField(
                      controller: _govde,
                      autofocus: yeni,
                      enabled: !kilitli,
                      maxLength: soruCevapGovdesiEnCok,
                      minLines: 8,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _notifier.govdeAyarla,
                      decoration: soruAlanGorunumu(context).copyWith(
                        labelText: metinler.soru_cevap_form_govde_etiketi,
                        alignLabelWithHint: true,
                        errorMaxLines: 3,
                        errorText: durum.govdeHatali
                            ? metinler.soru_cevap_form_govde_hatasi
                            : null,
                      ),
                    ),
                  ),
                  if (durum.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cevaplanan sorunun alıntısı (tasarım: Cevap-Form): tint-brand kutu,
/// küçük "Soru" etiketi ve başlık.
class _SoruAlintisi extends StatelessWidget {
  const _SoruAlintisi({required this.baslik});

  final String baslik;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.secimKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s16,
            vertical: TayfamSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).soru_baslik,
                style: yazi.labelSmall?.copyWith(color: r.metinIkincil),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(baslik, style: yazi.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
