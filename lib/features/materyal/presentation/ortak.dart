import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/api/gen/models.dart' as api show Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/hesap.dart' show disBaglantiyiAc;
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/application/materyal_formu.dart';
import 'package:tayfam/features/materyal/presentation/materyal_formu_ekrani.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart'
    show bildirimGoster;
import 'package:tayfam/l10n/app_localizations.dart';

/// Materyal türünün ikonu.
IconData materyalTurIkonu(MaterialKind tur) => switch (tur) {
  MaterialKind.link => Icons.link,
  MaterialKind.notePhoto => Icons.photo_library_outlined,
  MaterialKind.unknown => Icons.description_outlined,
};

/// Materyal türünün adı.
String materyalTurAdi(AppLocalizations m, MaterialKind tur) => switch (tur) {
  MaterialKind.link => m.materyal_tur_baglanti,
  MaterialKind.notePhoto => m.materyal_tur_not,
  MaterialKind.unknown => m.materyal_tur_bilinmiyor,
};

/// Ekleme ya da düzenleme formunu kabuğun üstünde tam ekran açar. Başarıda
/// kısa bildirim gösterilir ve materyal döner; vazgeçilirse `null`.
Future<api.Material?> materyalFormunuAc(
  BuildContext context, {
  required String tayfaId,
  api.Material? duzenlenen,
}) async {
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<api.Material>(
      fullscreenDialog: true,
      builder: (_) =>
          MateryalFormuEkrani(tayfaId: tayfaId, duzenlenen: duzenlenen),
    ),
  );
  if (sonuc != null) {
    bildirimGoster(
      bildirim,
      duzenlenen == null ? m.materyal_eklendi : m.materyal_kaydedildi,
    );
  }
  return sonuc;
}

/// Materyalin bağlantısını "Tayfam dışına çıkıyorsun" uyarısıyla açar
/// (App ADR-0033 §2): önce alttan sayfa açılır, alan adı büyük yazılır;
/// kullanıcı "Aç" demeden hiçbir şey açılmaz ve hiçbir istek gitmez.
/// Açma sistem tarayıcısındadır (uygulama içi web görünümü, önizleme
/// yok). Adres yeniden doğrulanır: `https` dışı, IP adresli ya da kullanıcı
/// bilgili adres açılmaz. Adres log'a yazılmaz.
Future<void> materyalBaglantisiniAc(
  BuildContext context,
  WidgetRef ref,
  api.Material materyal,
) async {
  final m = AppLocalizations.of(context);
  final adres = acilabilirBaglanti(materyal.url);
  if (adres == null) {
    bildirimGoster(ScaffoldMessenger.of(context), m.materyal_baglanti_acilamaz);
    return;
  }
  final alanAdi = materyal.domain ?? adres.host;
  final ac = await altSayfaAc<bool>(
    context,
    builder: (_) => BaglantiUyarisi(alanAdi: alanAdi, adres: adres.toString()),
  );
  if (ac != true || !context.mounted) return;
  await disBaglantiyiAc(context, ref, adres);
}

/// "Tayfam dışına çıkıyorsun" alt sayfası: alan adı büyük, tam adres
/// küçük, açıklama, "Vazgeç" ve "Aç". "Aç" `true` ile kapanır.
class BaglantiUyarisi extends StatelessWidget {
  const BaglantiUyarisi({
    super.key,
    required this.alanAdi,
    required this.adres,
  });

  /// Sunucunun ayrıştırdığı alan adı (punycode olabilir).
  final String alanAdi;

  /// Açılacak tam adres.
  final String adres;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return AltSayfaIcerigi(
      baslik: m.materyal_disari_baslik,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.public, color: r.metinIkincil),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Semantics(
                      label: m.materyal_alan_adi_etiketi(alanAdi),
                      excludeSemantics: true,
                      child: Text(
                        alanAdi,
                        style: yazi.titleLarge?.copyWith(color: r.metin),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TayfamSpacing.s8),
              Text(
                adres,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
              const SizedBox(height: TayfamSpacing.s16),
              Text(
                m.materyal_disari_aciklama,
                style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
              const SizedBox(height: TayfamSpacing.s24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  IkincilEylem(
                    etiket: m.materyal_vazgec,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  BirincilEylem(
                    etiket: m.materyal_ac,
                    ikon: Icons.open_in_new,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Türün kare ikon kutusu (liste satırının başında).
class MateryalTurKutusu extends StatelessWidget {
  const MateryalTurKutusu({super.key, required this.tur});

  final MaterialKind tur;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ExcludeSemantics(
      child: Container(
        width: TayfamSizes.dokunmaMin,
        height: TayfamSizes.dokunmaMin,
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: Icon(materyalTurIkonu(tur), color: r.tintMarkaUstu),
      ),
    );
  }
}

/// Bir materyalin liste satırı (liste ve ana sayfa kartı): tür ikonu,
/// başlık, bağlantıda alan adı (her zaman görünür), not fotoğrafında
/// fotoğraf sayısı ve ders/konu etiketleri. Bütün satır tek dokunma
/// alanıdır ve ekran okuyucuya tek öğe olarak okunur; dokununca detay
/// açılır (bağlantı doğrudan açılmaz).
class MateryalSatiri extends StatelessWidget {
  const MateryalSatiri({
    super.key,
    required this.materyal,
    required this.onTap,
    this.etiketler = true,
  });

  final api.Material materyal;
  final VoidCallback onTap;

  /// Ders/konu etiketleri gösterilsin mi (ana sayfa kartında yer kazanmak
  /// için kapatılabilir).
  final bool etiketler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final ikincil = yazi.bodySmall?.copyWith(color: r.metinIkincil);
    final fotografSayisi = materyal.photoUploadIds?.length ?? 0;
    final alanAdi = materyal.domain;
    final bilgi = switch (materyal.kind) {
      MaterialKind.link => alanAdi ?? m.materyal_tur_baglanti,
      MaterialKind.notePhoto => m.materyal_fotograf_sayisi(fotografSayisi),
      MaterialKind.unknown => m.materyal_tur_bilinmiyor,
    };
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MateryalTurKutusu(tur: materyal.kind),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        materyal.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: yazi.titleMedium?.copyWith(color: r.metin),
                      ),
                      const SizedBox(height: TayfamSpacing.s4),
                      Text(
                        bilgi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ikincil,
                      ),
                      if (etiketler) ...[
                        const SizedBox(height: TayfamSpacing.s8),
                        DersKonuEtiketleri(
                          ders: materyal.subjectKey,
                          konu: materyal.topicKey,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Not fotoğrafları (en çok üç): yan yana kare küçük resimler. Dokununca
/// tam ekran açılır (iki parmakla yakınlaştırma; kaydet/paylaş yok,
/// ADR-0006). Her küçük resim en az 48 px dokunma alanıdır ve ekran
/// okuyucuya "Fotoğraf 1 / 3" diye okunur.
class MateryalFotograflari extends StatelessWidget {
  const MateryalFotograflari({super.key, required this.kimlikler});

  /// `material_note` yüklemelerinin kimlikleri, sırasıyla.
  final List<String> kimlikler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    if (kimlikler.isEmpty) return const SizedBox.shrink();
    final sayi = kimlikler.length;
    return LayoutBuilder(
      builder: (context, kisit) {
        final kenar =
            ((kisit.maxWidth -
                        TayfamSpacing.s8 * (materyalFotografEnCok - 1)) /
                    materyalFotografEnCok)
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
                    label: m.materyal_fotograf_etiketi(i + 1, sayi),
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
                          etiket: m.materyal_fotograf_etiketi(i + 1, sayi),
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
                  Text(m.materyal_fotograf_sayaci(sira + 1, sayi)),
        etiket: (sira) => m.materyal_fotograf_etiketi(sira + 1, sayi),
        gorsel: (context, sira) => MedyaGorseli(
          key: ValueKey(kimlikler[sira]),
          uploadId: kimlikler[sira],
          varyant: MedyaVaryanti.tam,
          fit: BoxFit.contain,
          etiket: m.materyal_fotograf_etiketi(sira + 1, sayi),
          yerTutucu: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Formdaki fotoğraf yerleri (en çok üç, `material_note` yüklemesi): her
/// yer ayrı bir fotoğraf alanıdır; sonraki yer öncekisi doluyken (ya da
/// kendisi doluyken) görünür. "Kaldır" `null` verir.
class MateryalFotografAlanlari extends StatelessWidget {
  const MateryalFotografAlanlari({
    super.key,
    required this.tayfaId,
    required this.yerler,
    required this.onDegisti,
    this.etkin = true,
  });

  final String tayfaId;

  /// [materyalFotografEnCok] yer; boş yer `null`.
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
            key: ValueKey('materyal_foto_$i'),
            amac: UploadPurpose.materialNote,
            tayfaId: tayfaId,
            deger: yerler[i],
            bicim: FotografAlaniBicimi.kare,
            etkin: etkin,
            etiket: m.materyal_fotograf_etiketi(i + 1, materyalFotografEnCok),
            onDegisti: (yeni) => onDegisti(i, yeni),
          ),
        ],
      ],
    );
  }
}
