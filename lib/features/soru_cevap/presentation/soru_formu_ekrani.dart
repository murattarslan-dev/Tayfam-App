import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/application/etiketler_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru sorma ve düzenleme formu (ADR-0018 §4; tasarım: Soru-Form): başlık
/// (10–150 karakter, tek satır), isteğe bağlı ayrıntı (en çok 10000
/// karakter, düz metin) ve en çok beş etiket (her biri en çok 30 karakter).
///
/// Gönder düğmesi sağ üsttedir. Etiket yazılıp "Ekle" ile ya da altta
/// "Tayfadaki etiketler" önerilerinden eklenir; yazılırken öneriler
/// süzülür. Kabuğun üstünde tam ekran açılır; başarıda kapanır ve soruyu
/// döndürür. Bağlantı yoksa form açık kalır, girilenler korunur.
class SoruFormuEkrani extends ConsumerStatefulWidget {
  const SoruFormuEkrani({super.key, required this.tayfaId, this.duzenlenen});

  final String tayfaId;

  /// Düzenlenen soru; yeni soruda `null`.
  final Question? duzenlenen;

  @override
  ConsumerState<SoruFormuEkrani> createState() => _SoruFormuEkraniState();
}

class _SoruFormuEkraniState extends ConsumerState<SoruFormuEkrani> {
  late final TextEditingController _baslik;
  late final TextEditingController _govde;
  final TextEditingController _etiket = TextEditingController();

  SoruFormuAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, duzenlenen: widget.duzenlenen);

  SoruFormuNotifier get _notifier =>
      ref.read(soruFormuProvider(_anahtar).notifier);

  @override
  void initState() {
    super.initState();
    final durum = ref.read(soruFormuProvider(_anahtar));
    _baslik = TextEditingController(text: durum.baslik);
    _govde = TextEditingController(text: durum.govde);
  }

  @override
  void dispose() {
    _baslik.dispose();
    _govde.dispose();
    _etiket.dispose();
    super.dispose();
  }

  void _etiketEkle(String ad) {
    if (_notifier.etiketEkle(ad)) _etiket.clear();
    setState(() {});
  }

  /// Gönderir; etiket kutusunda eklenmemiş bir ad kaldıysa önce onu ekler,
  /// eklenemezse (hata gösterilir) göndermez.
  void _gonder() {
    if (_etiket.text.trim().isNotEmpty) {
      final eklendi = _notifier.etiketEkle(_etiket.text);
      setState(() {});
      if (!eklendi) return;
      _etiket.clear();
    }
    unawaited(_notifier.gonder());
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final saglayici = soruFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      final soru = sonraki.tamamlanan;
      if (soru != null) Navigator.of(context).pop(soru);
    });
    final durum = ref.watch(saglayici);
    final tumEtiketler = ref.watch(etiketlerProvider(widget.tayfaId)).value;
    final oneriler = tumEtiketler == null || !durum.etiketEklenebilir
        ? const <String>[]
        : etiketOnerileri(tumEtiketler, _etiket.text, durum.etiketler);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          yeni ? metinler.soru_form_yeni : metinler.soru_form_duzenle,
        ),
        actions: [
          FormUstEylemi(
            etiket: yeni ? metinler.soru_form_gonder : metinler.soru_form_kaydet,
            onPressed: kilitli ? null : _gonder,
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
                TayfamSpacing.s20,
                TayfamSpacing.s8,
                TayfamSpacing.s20,
                TayfamSpacing.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _baslik,
                    autofocus: yeni,
                    enabled: !kilitli,
                    maxLength: soruBasligiEnCok,
                    style: yazi.titleMedium,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: _notifier.baslikAyarla,
                    decoration: soruAlanGorunumu(context).copyWith(
                      labelText: metinler.soru_form_baslik_etiketi,
                      errorMaxLines: 3,
                      errorText: durum.baslikHatali
                          ? metinler.soru_form_baslik_hatasi
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  TextField(
                    controller: _govde,
                    enabled: !kilitli,
                    maxLength: soruCevapGovdesiEnCok,
                    minLines: 5,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _notifier.govdeAyarla,
                    decoration: soruAlanGorunumu(context).copyWith(
                      labelText: metinler.soru_form_govde_etiketi,
                      alignLabelWithHint: true,
                      errorMaxLines: 3,
                      errorText: durum.govdeHatali
                          ? metinler.soru_form_govde_hatasi
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  Semantics(
                    header: true,
                    child: Wrap(
                      spacing: TayfamSpacing.s4,
                      children: [
                        Text(metinler.soru_form_etiketler, style: yazi.titleSmall),
                        Text(
                          metinler.soru_form_etiketler_siniri,
                          style: yazi.titleSmall?.copyWith(
                            color: r.metinIkincil,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  if (durum.etiketler.isNotEmpty) ...[
                    Wrap(
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s8,
                      children: [
                        for (final ad in durum.etiketler)
                          InputChip(
                            label: Text(ad),
                            isEnabled: !kilitli,
                            backgroundColor: r.tintMarka,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            labelStyle: yazi.labelLarge?.copyWith(
                              color: r.tintMarkaUstu,
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: TayfamSizes.ikonKucuk,
                            ),
                            deleteIconColor: r.tintMarkaUstu,
                            deleteButtonTooltipMessage: metinler
                                .soru_form_etiket_cikar(ad),
                            onDeleted: () {
                              _notifier.etiketCikar(ad);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: TayfamSpacing.s8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _etiket,
                          enabled: !kilitli && durum.etiketEklenebilir,
                          maxLength: etiketEnCok,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _etiketEkle,
                          decoration: soruAlanGorunumu(context).copyWith(
                            labelText: metinler.soru_form_etiket_etiketi,
                            counterText: '',
                            errorMaxLines: 3,
                            errorText: switch (durum.etiketHatasi) {
                              EtiketHatasi.cokUzun =>
                                metinler.soru_form_etiket_cok_uzun,
                              EtiketHatasi.cokFazla =>
                                metinler.soru_form_etiket_cok_fazla,
                              null => null,
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: TayfamSpacing.s8),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: TayfamSpacing.s4,
                        ),
                        child: CerceveliHapEylem(
                          etiket: metinler.soru_form_etiket_ekle,
                          onPressed: kilitli || !durum.etiketEklenebilir
                              ? null
                              : () => _etiketEkle(_etiket.text),
                        ),
                      ),
                    ],
                  ),
                  if (oneriler.isNotEmpty && !kilitli) ...[
                    const SizedBox(height: TayfamSpacing.s12),
                    Text(
                      metinler.soru_form_etiket_oneriler,
                      style: yazi.labelMedium?.copyWith(color: r.metinIkincil),
                    ),
                    const SizedBox(height: TayfamSpacing.s8),
                    Wrap(
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s8,
                      children: [
                        for (final ad in oneriler)
                          ActionChip(
                            label: Text(ad),
                            backgroundColor: r.kart,
                            side: BorderSide(
                              color: r.cizgi,
                              width: TayfamSizes.vurguKenari,
                            ),
                            shape: const StadiumBorder(),
                            labelStyle: yazi.labelMedium?.copyWith(
                              color: r.metin,
                            ),
                            onPressed: () => _etiketEkle(ad),
                          ),
                      ],
                    ),
                  ],
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
