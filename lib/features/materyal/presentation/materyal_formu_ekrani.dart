import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/api/gen/models.dart' as api show Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/materyal/application/materyal_formu.dart';
import 'package:tayfam/features/materyal/presentation/ortak.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart' show FormUstEylemi;
import 'package:tayfam/l10n/app_localizations.dart';

/// Materyal ekleme ve düzenleme formu (Tayfam-Api ADR-0040 §3): tür
/// (bağlantı ya da not fotoğrafı; yalnızca eklerken, sonra değişmez),
/// başlık (en çok 80 karakter), `https` bağlantı ya da 1–3 not fotoğrafı,
/// ders (zorunlu) ve konu (isteğe bağlı). Dosya/PDF yüklenmez.
///
/// Kaydet düğmesi sağ üsttedir. Kabuğun üstünde tam ekran açılır; başarıda
/// kapanır ve materyali döndürür. Hata formun altında gösterilir,
/// girilenler kaybolmaz.
class MateryalFormuEkrani extends ConsumerStatefulWidget {
  const MateryalFormuEkrani({
    super.key,
    required this.tayfaId,
    this.duzenlenen,
  });

  final String tayfaId;

  /// Düzenlenen materyal; yenide `null`.
  final api.Material? duzenlenen;

  @override
  ConsumerState<MateryalFormuEkrani> createState() =>
      _MateryalFormuEkraniState();
}

class _MateryalFormuEkraniState extends ConsumerState<MateryalFormuEkrani> {
  late final TextEditingController _baslik;
  late final TextEditingController _baglanti;

  MateryalFormuAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, duzenlenen: widget.duzenlenen);

  MateryalFormuNotifier get _notifier =>
      ref.read(materyalFormuProvider(_anahtar).notifier);

  @override
  void initState() {
    super.initState();
    final durum = ref.read(materyalFormuProvider(_anahtar));
    _baslik = TextEditingController(text: durum.baslik);
    _baglanti = TextEditingController(text: durum.baglanti);
  }

  @override
  void dispose() {
    _baslik.dispose();
    _baglanti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final saglayici = materyalFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      if (sonraki.tamamlandi) Navigator.of(context).pop(sonraki.materyal);
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    final hatalar = durum.hatalar;
    final dersHatali = hatalar.contains(MateryalFormHatasi.ders);
    return Scaffold(
      appBar: AppBar(
        title: Text(yeni ? m.materyal_form_yeni : m.materyal_form_duzenle),
        actions: [
          if (kilitli)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s16,
              ),
              child: TayfamYukleniyor(etiket: m.materyal_kaydediliyor),
            )
          else
            FormUstEylemi(
              etiket: m.materyal_kaydet,
              onPressed: () => unawaited(_notifier.gonder()),
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
                  BolumEtiketi(baslik: m.materyal_tur_alani),
                  if (yeni)
                    Wrap(
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s8,
                      children: [
                        for (final tur in const [
                          MaterialKind.link,
                          MaterialKind.notePhoto,
                        ])
                          ChoiceChip(
                            avatar: Icon(materyalTurIkonu(tur)),
                            label: Text(materyalTurAdi(m, tur)),
                            selected: durum.tur == tur,
                            onSelected: kilitli
                                ? null
                                : (_) => _notifier.turAyarla(tur),
                          ),
                      ],
                    )
                  else ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Etiket(
                        metin: materyalTurAdi(m, durum.tur),
                        ton: EtiketTonu.notr,
                        ikon: materyalTurIkonu(durum.tur),
                      ),
                    ),
                    const SizedBox(height: TayfamSpacing.s4),
                    Text(
                      m.materyal_tur_degismez,
                      style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                    ),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  TextField(
                    controller: _baslik,
                    enabled: !kilitli,
                    maxLength: materyalBaslikEnCok,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _notifier.baslikAyarla,
                    decoration: InputDecoration(
                      labelText: m.materyal_baslik_alani,
                      errorMaxLines: 3,
                      errorText: _baslikHatasi(m, hatalar),
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  if (durum.tur == MaterialKind.link)
                    TextField(
                      controller: _baglanti,
                      enabled: !kilitli,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: _notifier.baglantiAyarla,
                      decoration: InputDecoration(
                        labelText: m.materyal_baglanti_alani,
                        helperText: m.materyal_baglanti_ipucu,
                        helperMaxLines: 3,
                        errorMaxLines: 3,
                        errorText: _baglantiHatasi(m, hatalar),
                      ),
                    )
                  else ...[
                    BolumEtiketi(baslik: m.materyal_fotograflar),
                    MateryalFotografAlanlari(
                      tayfaId: widget.tayfaId,
                      yerler: durum.fotograflar,
                      etkin: !kilitli,
                      onDegisti: _notifier.fotografAyarla,
                    ),
                    if (hatalar.contains(MateryalFormHatasi.fotografYok)) ...[
                      const SizedBox(height: TayfamSpacing.s8),
                      HataSatiri(metin: m.materyal_fotograf_yok),
                    ],
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  DersKonuSecici(
                    secim: durum.secim,
                    onDegisti: kilitli ? null : _notifier.secimAyarla,
                    dersHatasi: dersHatali && durum.secim != null
                        ? m.materyal_ders_hatasi
                        : null,
                  ),
                  // Ders alanı düzey seçilene kadar görünmez; hata o zaman
                  // seçicinin altında durur.
                  if (dersHatali && durum.secim == null) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri(metin: m.materyal_ders_hatasi),
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  Row(
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
                          m.materyal_kural_notu,
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

String? _baslikHatasi(AppLocalizations m, Set<MateryalFormHatasi> hatalar) {
  if (hatalar.contains(MateryalFormHatasi.baslikBos)) {
    return m.materyal_baslik_bos;
  }
  if (hatalar.contains(MateryalFormHatasi.baslikUzun)) {
    return m.materyal_baslik_uzun(materyalBaslikEnCok);
  }
  return null;
}

String? _baglantiHatasi(AppLocalizations m, Set<MateryalFormHatasi> hatalar) {
  if (hatalar.contains(MateryalFormHatasi.baglantiBos)) {
    return m.materyal_baglanti_bos;
  }
  if (hatalar.contains(MateryalFormHatasi.baglantiGecersiz)) {
    return m.materyal_baglanti_gecersiz;
  }
  return null;
}
