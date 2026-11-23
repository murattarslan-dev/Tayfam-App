import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/garaj/application/arac_formu.dart';
import 'package:tayfam/features/garaj/presentation/ortak.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart' show FormUstEylemi;
import 'package:tayfam/l10n/app_localizations.dart';

/// Garaj aracı ekleme ve düzenleme formu (Tayfam-Api ADR-0040 §4): marka
/// (zorunlu), model, yıl, renk, kısa not ve en çok üç fotoğraf. Plaka
/// garajda tutulmaz; yalnızca etkinliğin araç formunda yazılır.
///
/// Kaydet düğmesi sağ üsttedir. Kabuğun üstünde tam ekran açılır; başarıda
/// kapanır ve aracı döndürür. Hata formun altında gösterilir, girilenler
/// kaybolmaz.
class GarajFormuEkrani extends ConsumerStatefulWidget {
  const GarajFormuEkrani({super.key, this.duzenlenen});

  /// Düzenlenen araç; yenide `null`.
  final GarageVehicle? duzenlenen;

  @override
  ConsumerState<GarajFormuEkrani> createState() => _GarajFormuEkraniState();
}

class _GarajFormuEkraniState extends ConsumerState<GarajFormuEkrani> {
  late final TextEditingController _marka = TextEditingController(
    text: widget.duzenlenen?.make,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.duzenlenen?.model,
  );
  late final TextEditingController _yil = TextEditingController(
    text: switch (widget.duzenlenen?.modelYear) {
      final yil? when yil > 0 => '$yil',
      _ => '',
    },
  );
  late final TextEditingController _renk = TextEditingController(
    text: widget.duzenlenen?.color,
  );
  late final TextEditingController _not = TextEditingController(
    text: widget.duzenlenen?.note,
  );

  GarajFormuNotifier get _notifier =>
      ref.read(garajFormuProvider(widget.duzenlenen).notifier);

  @override
  void dispose() {
    _marka.dispose();
    _model.dispose();
    _yil.dispose();
    _renk.dispose();
    _not.dispose();
    super.dispose();
  }

  void _gonder() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      _notifier.gonder((
        marka: _marka.text,
        model: _model.text,
        yil: _yil.text,
        renk: _renk.text,
        not: _not.text,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final saglayici = garajFormuProvider(widget.duzenlenen);
    ref.listen(saglayici, (_, sonraki) {
      if (sonraki.tamamlandi) Navigator.of(context).pop(sonraki.arac);
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final h = durum.hatalar;
    final gelecekYil = ref.read(simdiProvider)().toLocal().year + 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.duzenlenen == null ? m.garaj_form_yeni : m.garaj_form_duzenle,
        ),
        actions: [
          if (kilitli)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s16,
              ),
              child: TayfamYukleniyor(etiket: m.garaj_kaydediliyor),
            )
          else
            FormUstEylemi(etiket: m.garaj_kaydet, onPressed: _gonder),
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
                TayfamSpacing.s20,
                TayfamSpacing.s8,
                TayfamSpacing.s20,
                TayfamSpacing.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _marka,
                    enabled: !kilitli,
                    maxLength: garajMarkaEnCok,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: m.garaj_marka_alani,
                      errorMaxLines: 3,
                      errorText: h.contains(GarajFormHatasi.marka)
                          ? m.garaj_marka_hata(garajMarkaEnCok)
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  TextField(
                    controller: _model,
                    enabled: !kilitli,
                    maxLength: garajModelEnCok,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: m.garaj_model_alani,
                      errorMaxLines: 3,
                      errorText: h.contains(GarajFormHatasi.model)
                          ? m.garaj_uzunluk_hata(garajModelEnCok)
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  TextField(
                    controller: _yil,
                    enabled: !kilitli,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: m.garaj_yil_alani,
                      errorMaxLines: 3,
                      errorText: h.contains(GarajFormHatasi.yil)
                          ? m.garaj_yil_hata(garajYiliEnAz, gelecekYil)
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  TextField(
                    controller: _renk,
                    enabled: !kilitli,
                    maxLength: garajRenkEnCok,
                    decoration: InputDecoration(
                      labelText: m.garaj_renk_alani,
                      errorMaxLines: 3,
                      errorText: h.contains(GarajFormHatasi.renk)
                          ? m.garaj_uzunluk_hata(garajRenkEnCok)
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  TextField(
                    controller: _not,
                    enabled: !kilitli,
                    maxLength: garajNotEnCok,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: m.garaj_not_alani,
                      helperText: m.garaj_not_ipucu,
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      errorText: h.contains(GarajFormHatasi.not)
                          ? m.garaj_uzunluk_hata(garajNotEnCok)
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  BolumEtiketi(baslik: m.garaj_fotograflar),
                  GarajFotografAlanlari(
                    yerler: durum.fotograflar,
                    etkin: !kilitli,
                    onDegisti: _notifier.fotografAyarla,
                  ),
                  const SizedBox(height: TayfamSpacing.s24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.lock_outline,
                          size: TayfamSizes.ikon,
                          color: r.metinIkincil,
                        ),
                      ),
                      const SizedBox(width: TayfamSpacing.s8),
                      Expanded(
                        child: Text(
                          m.garaj_plaka_notu,
                          style: yazi.bodySmall?.copyWith(color: r.metinGovde),
                        ),
                      ),
                    ],
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
