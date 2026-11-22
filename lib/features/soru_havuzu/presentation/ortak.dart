import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_formu.dart';
import 'package:tayfam/features/soru_havuzu/presentation/cevap_formu.dart';
import 'package:tayfam/features/soru_havuzu/presentation/soru_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru havuzuna soru sorma ya da soruyu düzenleme formunu kabuğun
/// üstünde tam ekran açar. Yeni soru sorulunca sorunun ekranına gidilir;
/// sonuç listelere ve detaya form içinde yansır.
Future<void> havuzSoruFormunuAc(
  BuildContext context, {
  required String tayfaId,
  Question? duzenlenen,
}) async {
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Question>(
      fullscreenDialog: true,
      builder: (_) =>
          HavuzSoruFormuEkrani(tayfaId: tayfaId, duzenlenen: duzenlenen),
    ),
  );
  if (sonuc == null) return;
  if (duzenlenen != null) {
    bildirimGoster(bildirim, m.soru_kaydedildi);
    return;
  }
  bildirimGoster(bildirim, m.soru_havuzu_soruldu);
  if (!context.mounted) return;
  GoRouter.maybeOf(context)?.go(Adresler.havuzSorusu(tayfaId, sonuc.id));
}

/// Havuz sorusuna cevap formunu kabuğun üstünde tam ekran açar; yeni cevap
/// için [duzenlenen] `null`'dır. Sonuç cevap listesine form içinde yansır.
Future<void> havuzCevapFormunuAc(
  BuildContext context, {
  required Question soru,
  Answer? duzenlenen,
}) async {
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final tamam = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => HavuzCevapFormuEkrani(soru: soru, duzenlenen: duzenlenen),
    ),
  );
  if (tamam != true) return;
  bildirimGoster(
    bildirim,
    duzenlenen == null ? m.soru_cevap_gonderildi : m.soru_kaydedildi,
  );
}

/// Sorunun ya da cevabın fotoğrafları (en çok iki): yan yana kare küçük
/// resimler. Dokununca fotoğraflar tam ekran açılır (iki parmakla
/// yakınlaştırma; kaydet/paylaş yok, ADR-0006). Her küçük resim en az 48 px
/// dokunma alanıdır ve ekran okuyucuya "Fotoğraf 1 / 2" diye okunur.
class HavuzFotograflari extends StatelessWidget {
  const HavuzFotograflari({super.key, required this.kimlikler});

  /// `question_pool` yüklemelerinin kimlikleri, sırasıyla.
  final List<String> kimlikler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    if (kimlikler.isEmpty) return const SizedBox.shrink();
    final sayi = kimlikler.length;
    return LayoutBuilder(
      builder: (context, kisit) {
        // İki fotoğraf yan yana sığar; dar ekranda da kare kalır.
        final kenar =
            ((kisit.maxWidth - TayfamSpacing.s8 * (havuzFotografEnCok - 1)) /
                    havuzFotografEnCok)
                .clamp(TayfamSizes.dokunmaMin, TayfamSizes.okumaGenisligi / 2)
                .toDouble();
        return Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (var i = 0; i < sayi; i++)
              SizedBox.square(
                dimension: kenar,
                child: OdakCercevesi(
                  koseler: TayfamRadii.onizlemeKoseleri,
                  child: Semantics(
                    button: true,
                    label: m.soru_havuzu_fotograf_etiketi(i + 1, sayi),
                    excludeSemantics: true,
                    child: Material(
                      color: context.renkler.kart,
                      borderRadius: TayfamRadii.onizlemeKoseleri,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => unawaited(_tamEkranAc(context, i)),
                        child: MedyaGorseli(
                          key: ValueKey(kimlikler[i]),
                          uploadId: kimlikler[i],
                          etiket: m.soru_havuzu_fotograf_etiketi(i + 1, sayi),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _tamEkranAc(BuildContext context, int ilk) {
    final m = AppLocalizations.of(context);
    final sayi = kimlikler.length;
    return tamEkranFotografAc(
      context,
      kokNavigator: true,
      builder: (_) => TamEkranFotograf(
        sayi: sayi,
        ilkSira: ilk,
        baslikOrtada: true,
        baslik: sayi < 2
            ? null
            : (context, sira) =>
                  Text(m.soru_havuzu_fotograf_sayaci(sira + 1, sayi)),
        etiket: (sira) => m.soru_havuzu_fotograf_etiketi(sira + 1, sayi),
        gorsel: (context, sira) => MedyaGorseli(
          key: ValueKey(kimlikler[sira]),
          uploadId: kimlikler[sira],
          varyant: MedyaVaryanti.tam,
          fit: BoxFit.contain,
          etiket: m.soru_havuzu_fotograf_etiketi(sira + 1, sayi),
          yerTutucu: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Formdaki fotoğraf yerleri (en çok iki, `question_pool` yüklemesi):
/// her yer ayrı bir fotoğraf alanıdır; ikinci yer ilki doluyken (ya da
/// kendisi doluyken) görünür. Yükleme hazır olunca [onDegisti] yerin
/// sırası ve kimliğiyle çağrılır; "Kaldır" `null` verir.
class HavuzFotografAlanlari extends StatelessWidget {
  const HavuzFotografAlanlari({
    super.key,
    required this.tayfaId,
    required this.yerler,
    required this.onDegisti,
    this.etkin = true,
  });

  final String tayfaId;

  /// [havuzFotografEnCok] yer; boş yer `null`.
  final List<String?> yerler;

  final void Function(int sira, String? uploadId) onDegisti;

  final bool etkin;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final gorunen = [
      for (var i = 0; i < yerler.length; i++)
        if (i == 0 || yerler[i] != null || yerler[i - 1] != null) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in gorunen) ...[
          if (i != gorunen.first) const SizedBox(height: TayfamSpacing.s16),
          FotografAlani(
            key: ValueKey('soru_havuzu_foto_$i'),
            amac: UploadPurpose.questionPool,
            tayfaId: tayfaId,
            deger: yerler[i],
            bicim: FotografAlaniBicimi.kare,
            etkin: etkin,
            etiket: m.soru_havuzu_fotograf_etiketi(i + 1, havuzFotografEnCok),
            onDegisti: (yeni) => onDegisti(i, yeni),
          ),
        ],
      ],
    );
  }
}

/// Formdaki hata metinleri (alanların altında gösterilir).
String? havuzIcerikHatasi(AppLocalizations m, Set<HavuzFormHatasi> hatalar) {
  if (hatalar.contains(HavuzFormHatasi.metinUzun)) {
    return m.soru_havuzu_metin_uzun;
  }
  if (hatalar.contains(HavuzFormHatasi.icerikYok)) {
    return m.soru_havuzu_icerik_yok;
  }
  return null;
}
