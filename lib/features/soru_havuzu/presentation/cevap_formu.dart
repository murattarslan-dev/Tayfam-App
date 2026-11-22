import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_formu.dart';
import 'package:tayfam/features/soru_havuzu/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Havuz sorusuna cevap yazma ve düzenleme formu (Tayfam-Api ADR-0040 §2):
/// üstte sorunun kısa alıntısı, düz metin ve en çok iki fotoğraf; metin ya
/// da fotoğraftan biri gerekir. Düzenlemede kalan fotoğraflar yeniden
/// gönderilir (verilmeyen fotoğrafı sunucu kaldırır).
///
/// Kabuğun üstünde tam ekran açılır; başarıda `true` ile kapanır.
/// Bağlantı yoksa form açık kalır, girilenler korunur.
class HavuzCevapFormuEkrani extends ConsumerStatefulWidget {
  const HavuzCevapFormuEkrani({super.key, required this.soru, this.duzenlenen});

  /// Cevaplanan havuz sorusu.
  final Question soru;

  /// Düzenlenen cevap; yeni cevapta `null`.
  final Answer? duzenlenen;

  @override
  ConsumerState<HavuzCevapFormuEkrani> createState() =>
      _HavuzCevapFormuEkraniState();
}

class _HavuzCevapFormuEkraniState extends ConsumerState<HavuzCevapFormuEkrani> {
  late final TextEditingController _metin;

  HavuzCevapFormuAnahtari get _anahtar => (
    tayfaId: widget.soru.tayfaId,
    soruId: widget.soru.id,
    duzenlenen: widget.duzenlenen,
  );

  HavuzCevapFormuNotifier get _notifier =>
      ref.read(havuzCevapFormuProvider(_anahtar).notifier);

  @override
  void initState() {
    super.initState();
    _metin = TextEditingController(
      text: ref.read(havuzCevapFormuProvider(_anahtar)).metin,
    );
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = havuzCevapFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      if (sonraki.tamamlandi) Navigator.of(context).pop(true);
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(yeni ? m.soru_cevap_form_yeni : m.soru_cevap_form_duzenle),
        actions: [
          FormUstEylemi(
            etiket: yeni ? m.soru_cevap_form_gonder : m.soru_form_kaydet,
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
                  _SoruAlintisi(soru: widget.soru),
                  const SizedBox(height: TayfamSpacing.s16),
                  TextField(
                    controller: _metin,
                    autofocus: yeni,
                    enabled: !kilitli,
                    maxLength: soruCevapGovdesiEnCok,
                    minLines: 6,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _notifier.metinAyarla,
                    decoration: soruAlanGorunumu(context).copyWith(
                      labelText: m.soru_cevap_form_govde_etiketi,
                      alignLabelWithHint: true,
                      errorMaxLines: 3,
                      errorText: havuzIcerikHatasi(m, durum.hatalar),
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  BolumEtiketi(baslik: m.soru_havuzu_fotograflar),
                  HavuzFotografAlanlari(
                    tayfaId: widget.soru.tayfaId,
                    yerler: durum.fotograflar,
                    etkin: !kilitli,
                    onDegisti: _notifier.fotografAyarla,
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

/// Cevaplanan sorunun alıntısı: tint-brand kutu, küçük "Soru" etiketi ve
/// metnin ilk satırları (metinsiz soruda "Fotoğraflı soru").
class _SoruAlintisi extends StatelessWidget {
  const _SoruAlintisi({required this.soru});

  final Question soru;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final metin = soru.body.trim();
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
                m.soru_baslik,
                style: yazi.labelSmall?.copyWith(color: r.metinIkincil),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                metin.isEmpty ? m.soru_havuzu_fotografli_soru : metin,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: yazi.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
