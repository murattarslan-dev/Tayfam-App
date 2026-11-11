import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/duyuru/application/duyuru_formu_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Duyuru yazma ve düzenleme formu (ADR-0015 §2): başlık (1–120
/// karakter, tek satır) ve metin (en çok 5000 karakter).
///
/// Kabuğun üstünde tam ekran açılır. `client_request_id` form açılınca bir
/// kez üretilir; gönderim tekrar denenirse aynı id gider. Bağlantı yoksa
/// form açık kalır ve girilenler korunur (ADR-0006). Başarıda form
/// kapanır ve duyuruyu döndürür.
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
    final saglayici = duyuruFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      final duyuru = sonraki.tamamlanan;
      if (duyuru != null) Navigator.of(context).pop(duyuru);
    });
    final durum = ref.watch(saglayici);
    final kilitli = durum.gonderiliyor;
    final yeni = widget.duzenlenen == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          yeni ? metinler.duyuru_form_yeni : metinler.duyuru_form_duzenle,
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
                    minLines: 5,
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
                  if (durum.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: BirincilEylem(
                      etiket: yeni
                          ? metinler.duyuru_form_yayinla
                          : metinler.duyuru_form_kaydet,
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
