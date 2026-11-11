import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/application/cevap_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_formu_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Cevap yazma ve düzenleme formu (ADR-0018 §4): düz metin, 1–10000
/// karakter. Kabuğun üstünde tam ekran açılır; başarıda kapanır ve cevabı
/// döndürür. Bağlantı yoksa form açık kalır, girilenler korunur.
class CevapFormuEkrani extends ConsumerStatefulWidget {
  const CevapFormuEkrani({
    super.key,
    required this.tayfaId,
    required this.soruId,
    this.duzenlenen,
  });

  final String tayfaId;

  final String soruId;

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
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _govde,
                    autofocus: yeni,
                    enabled: !kilitli,
                    maxLength: soruCevapGovdesiEnCok,
                    minLines: 5,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _notifier.govdeAyarla,
                    decoration: InputDecoration(
                      labelText: metinler.soru_cevap_form_govde_etiketi,
                      alignLabelWithHint: true,
                      errorText: durum.govdeHatali
                          ? metinler.soru_cevap_form_govde_hatasi
                          : null,
                    ),
                  ),
                  if (durum.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: BirincilEylem(
                      etiket: yeni
                          ? metinler.soru_cevap_form_gonder
                          : metinler.soru_form_kaydet,
                      onPressed: kilitli
                          ? null
                          : () => unawaited(_notifier.gonder()),
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
}
