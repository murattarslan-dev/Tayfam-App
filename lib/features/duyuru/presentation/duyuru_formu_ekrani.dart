import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/duyuru/application/duyuru_formu_notifier.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Duyuru formunun sonucu: yayınlanan ya da kaydedilen duyuru ve istenen
/// sabitlemenin başarısız olup olmadığı.
typedef DuyuruFormuSonucu = ({Announcement duyuru, bool sabitlenemedi});

/// Bu yazı ölçeğinden büyükte üst çubuktaki eylem ("Duyuru yaz",
/// "Yayınla") çubuğa sığmaz; içeriğin içine (listenin başına, formun
/// sonuna) iner.
const double ustCubukEylemiEnBuyukOlcek = 1.5;

/// Üst çubuktaki eylem içeriğe mi inmeli (büyük yazı).
bool eylemIcerigeIner(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > ustCubukEylemiEnBuyukOlcek;

/// Duyuru yazma ve düzenleme formu (ADR-0015 §2; tasarım: Duyuru-Form):
/// üstte kapat (X), başlık ve sağda "Yayınla" / "Kaydet"; sayaçlı başlık
/// (1–120 karakter, tek satır) ve metin (en çok 5000 karakter). Yeni
/// duyuruda moderatör ve yöneticiye "Yayınlayınca sabitle" anahtarı
/// gösterilir: oluşturmadan sonra ayrı bir sabitleme çağrısı yapılır.
///
/// Kabuğun üstünde tam ekran açılır. `client_request_id` form açılınca bir
/// kez üretilir; gönderim tekrar denenirse aynı id gider. Bağlantı yoksa
/// form açık kalır ve girilenler korunur (ADR-0006). Başarıda form
/// kapanır ve [DuyuruFormuSonucu] döndürür.
class DuyuruFormuEkrani extends ConsumerStatefulWidget {
  const DuyuruFormuEkrani({super.key, required this.tayfaId, this.duzenlenen});

  final String tayfaId;

  /// Düzenlenen duyuru; yeni duyuruda `null`.
  final Announcement? duzenlenen;

  @override
  ConsumerState<DuyuruFormuEkrani> createState() => _DuyuruFormuEkraniState();
}

class _DuyuruFormuEkraniState extends ConsumerState<DuyuruFormuEkrani> {
  late final TextEditingController _baslik;
  late final TextEditingController _govde;

  DuyuruFormuAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, duzenlenen: widget.duzenlenen);

  DuyuruFormuNotifier get _notifier =>
      ref.read(duyuruFormuProvider(_anahtar).notifier);

  @override
  void initState() {
    super.initState();
    final durum = ref.read(duyuruFormuProvider(_anahtar));
    _baslik = TextEditingController(text: durum.baslik);
    _govde = TextEditingController(text: durum.govde);
  }

  @override
  void dispose() {
    _baslik.dispose();
    _govde.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final saglayici = duyuruFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      final duyuru = sonraki.tamamlanan;
      if (duyuru != null) {
        Navigator.of(context).pop<DuyuruFormuSonucu>((
          duyuru: duyuru,
          sabitlenemedi: sonraki.sabitlenemedi,
        ));
      }
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    final sabitlemeGorunur =
        yeni && ref.watch(tayfaOzetiProvider(widget.tayfaId)).yonetimde;
    final ikincil = yazi.bodySmall?.copyWith(color: r.metinIkincil);
    // Büyük yazıda "Yayınla" / "Kaydet" üst çubuğa sığmaz; formun sonuna
    // iner.
    final icerikte = eylemIcerigeIner(context);
    final gonder = BirincilEylem(
      etiket: yeni ? metinler.duyuru_form_yayinla : metinler.duyuru_form_kaydet,
      onPressed: kilitli ? null : () => unawaited(_notifier.gonder()),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          yeni ? metinler.duyuru_form_yeni : metinler.duyuru_form_duzenle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!icerikte)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s12),
              child: gonder,
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
                    maxLength: duyuruBasligiEnCok,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: _notifier.baslikAyarla,
                    decoration: InputDecoration(
                      labelText: metinler.duyuru_form_baslik_etiketi,
                      errorText: durum.baslikHatali
                          ? metinler.duyuru_form_baslik_hatasi
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  TextField(
                    controller: _govde,
                    enabled: !kilitli,
                    maxLength: duyuruGovdesiEnCok,
                    minLines: 8,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _notifier.govdeAyarla,
                    decoration: InputDecoration(
                      labelText: metinler.duyuru_form_govde_etiketi,
                      alignLabelWithHint: true,
                      errorText: durum.govdeHatali
                          ? metinler.duyuru_form_govde_hatasi
                          : null,
                    ),
                  ),
                  if (sabitlemeGorunur) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    MergeSemantics(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: TayfamSizes.menuSatiri,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metinler.duyuru_form_sabitle,
                                    style: yazi.titleSmall,
                                  ),
                                  Text(
                                    metinler.duyuru_form_sabitle_aciklama,
                                    style: ikincil,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: TayfamSpacing.s12),
                            Switch(
                              value: durum.sabitle,
                              activeTrackColor: r.marka,
                              onChanged: kilitli
                                  ? null
                                  : (deger) => _notifier.sabitlemeyiAyarla(
                                      sabitle: deger,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(metinler.duyuru_form_duz_metin_notu, style: ikincil),
                  if (durum.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                  ],
                  if (icerikte) ...[
                    const SizedBox(height: TayfamSpacing.s24),
                    gonder,
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
