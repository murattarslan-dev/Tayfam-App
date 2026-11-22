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

/// Soru havuzuna soru sorma ve düzenleme formu (Tayfam-Api ADR-0040 §2):
/// ders (zorunlu) ve konu (isteğe bağlı) ortak seçiciyle, düz metin (en
/// çok 10000 karakter) ve en çok iki fotoğraf; metin ya da fotoğraftan
/// biri gerekir. Başlık ve etiket yoktur.
///
/// Gönder düğmesi sağ üsttedir. Kabuğun üstünde tam ekran açılır;
/// başarıda kapanır ve soruyu döndürür. Bağlantı yoksa form açık kalır,
/// girilenler korunur. Altta topluluk kuralı notu durur (ücretli özel ders
/// teklifi ve iletişim bilgisi paylaşımı yasak; genç kullanıcı güvenliği).
class HavuzSoruFormuEkrani extends ConsumerStatefulWidget {
  const HavuzSoruFormuEkrani({
    super.key,
    required this.tayfaId,
    this.duzenlenen,
  });

  final String tayfaId;

  /// Düzenlenen soru; yeni soruda `null`.
  final Question? duzenlenen;

  @override
  ConsumerState<HavuzSoruFormuEkrani> createState() =>
      _HavuzSoruFormuEkraniState();
}

class _HavuzSoruFormuEkraniState extends ConsumerState<HavuzSoruFormuEkrani> {
  late final TextEditingController _metin;

  HavuzSoruFormuAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, duzenlenen: widget.duzenlenen);

  HavuzSoruFormuNotifier get _notifier =>
      ref.read(havuzSoruFormuProvider(_anahtar).notifier);

  @override
  void initState() {
    super.initState();
    _metin = TextEditingController(
      text: ref.read(havuzSoruFormuProvider(_anahtar)).metin,
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
    final saglayici = havuzSoruFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      if (sonraki.tamamlandi) {
        Navigator.of(context).pop(sonraki.soru ?? widget.duzenlenen);
      }
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          yeni ? m.soru_havuzu_form_yeni : m.soru_havuzu_form_duzenle,
        ),
        actions: [
          FormUstEylemi(
            etiket: yeni ? m.soru_form_gonder : m.soru_form_kaydet,
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
                TayfamSpacing.s20,
                TayfamSpacing.s8,
                TayfamSpacing.s20,
                TayfamSpacing.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DersKonuSecici(
                    secim: durum.secim,
                    onDegisti: kilitli ? null : _notifier.secimAyarla,
                    dersHatasi: durum.hatalar.contains(HavuzFormHatasi.ders)
                        ? m.soru_havuzu_ders_hatasi
                        : null,
                  ),
                  const SizedBox(height: TayfamSpacing.s24),
                  TextField(
                    controller: _metin,
                    enabled: !kilitli,
                    maxLength: soruCevapGovdesiEnCok,
                    minLines: 5,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _notifier.metinAyarla,
                    decoration: soruAlanGorunumu(context).copyWith(
                      labelText: m.soru_havuzu_metin_etiketi,
                      helperText: m.soru_havuzu_metin_ipucu,
                      helperMaxLines: 3,
                      alignLabelWithHint: true,
                      errorMaxLines: 3,
                      errorText: havuzIcerikHatasi(m, durum.hatalar),
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  BolumEtiketi(baslik: m.soru_havuzu_fotograflar),
                  HavuzFotografAlanlari(
                    tayfaId: widget.tayfaId,
                    yerler: durum.fotograflar,
                    etkin: !kilitli,
                    onDegisti: _notifier.fotografAyarla,
                  ),
                  const SizedBox(height: TayfamSpacing.s24),
                  _KuralNotu(metin: m.soru_havuzu_kural_notu),
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

/// Formun altındaki topluluk kuralı notu: ikon ve metin.
class _KuralNotu extends StatelessWidget {
  const _KuralNotu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.info_outline,
            size: TayfamSizes.ikon,
            color: r.metinIkincil,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s8),
        Expanded(
          child: Text(
            metin,
            style: context.yazi.bodySmall?.copyWith(color: r.metinGovde),
          ),
        ),
      ],
    );
  }
}
