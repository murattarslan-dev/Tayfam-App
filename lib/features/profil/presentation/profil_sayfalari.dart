import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil fotoğrafı alttan sayfasında seçilen işlem.
enum FotografIslemi { galeri, kamera, kaldir }

/// Profil fotoğrafı alttan sayfası (tasarım: Profil-Foto): Galeriden seç,
/// Fotoğraf çek ve yalnızca fotoğraf varken Fotoğrafı kaldır; altta
/// fotoğrafın kimlere göründüğü notu. Vazgeçilirse `null`.
Future<FotografIslemi?> fotografSayfasiniAc(
  BuildContext context, {
  required bool fotografVar,
}) {
  final m = AppLocalizations.of(context);
  return altSayfaAc<FotografIslemi>(
    context,
    builder: (sayfa) => AltSayfaIcerigi(
      baslik: m.profil_avatar_baslik,
      children: [
        MenuSatiri(
          ikon: Icons.photo_library_outlined,
          baslik: m.medya_kaynak_galeri,
          onTap: () => Navigator.of(sayfa).pop(FotografIslemi.galeri),
        ),
        MenuSatiri(
          ikon: Icons.photo_camera_outlined,
          baslik: m.medya_kaynak_kamera,
          onTap: () => Navigator.of(sayfa).pop(FotografIslemi.kamera),
        ),
        if (fotografVar) ...[
          Divider(
            height: TayfamSpacing.s12,
            thickness: TayfamSizes.kenar,
            color: sayfa.renkler.cizgi,
          ),
          MenuSatiri(
            ikon: Icons.delete_outline,
            tur: MenuSatiriTuru.yikici,
            baslik: m.medya_fotograf_kaldir,
            aciklama: m.profil_avatar_kaldir_aciklama,
            onTap: () => Navigator.of(sayfa).pop(FotografIslemi.kaldir),
          ),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            TayfamSpacing.s8,
            TayfamSpacing.s8,
            0,
          ),
          child: Text(m.profil_avatar_aciklama, style: sayfa.yazi.bodySmall),
        ),
      ],
    ),
  );
}

/// Görünürlük seçeneklerinin gösterim sırası.
const List<ActivityVisibility> gorunurlukSecenekleri = [
  ActivityVisibility.private,
  ActivityVisibility.tayfa,
  ActivityVisibility.public,
];

/// Görünürlüğün adı ("Yalnızca ben"); tanınmayan değer "Herkes" sayılmaz,
/// en geniş seçenek gibi gösterilir (sunucu karar verir).
String gorunurlukAdi(AppLocalizations m, ActivityVisibility g) => switch (g) {
  ActivityVisibility.private => m.profil_gorunurluk_ozel,
  ActivityVisibility.tayfa => m.profil_gorunurluk_tayfa,
  ActivityVisibility.public ||
  ActivityVisibility.unknown => m.profil_gorunurluk_herkes,
};

String _gorunurlukAciklamasi(AppLocalizations m, ActivityVisibility g) =>
    switch (g) {
      ActivityVisibility.private => m.profil_gorunurluk_ozel_aciklama,
      ActivityVisibility.tayfa => m.profil_gorunurluk_tayfa_aciklama,
      ActivityVisibility.public ||
      ActivityVisibility.unknown => m.profil_gorunurluk_herkes_aciklama,
    };

/// "Katılım geçmişin kime görünsün?" alttan sayfası (tasarım:
/// Profil-Gorunurluk): üç seçenek kartı. Seçilen değer döner (kaydı
/// çağıran yapar; seçince hemen kaydedilir). Vazgeçilirse `null`.
Future<ActivityVisibility?> gorunurlukSayfasiniAc(
  BuildContext context, {
  required ActivityVisibility secili,
}) {
  final m = AppLocalizations.of(context);
  return altSayfaAc<ActivityVisibility>(
    context,
    builder: (sayfa) => AltSayfaIcerigi(
      baslik: m.profil_gorunurluk_soru,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            0,
            TayfamSpacing.s8,
            TayfamSpacing.s12,
          ),
          child: Text(
            m.profil_gorunurluk_aciklama,
            style: sayfa.yazi.bodyMedium?.copyWith(
              color: sayfa.renkler.metinGovde,
            ),
          ),
        ),
        RadioGroup<ActivityVisibility>(
          groupValue: secili,
          onChanged: (secim) => Navigator.of(sayfa).pop(secim),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, g) in gorunurlukSecenekleri.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                SecimKarti(
                  secili: g == secili,
                  child: RadioListTile<ActivityVisibility>(
                    value: g,
                    title: Text(gorunurlukAdi(m, g)),
                    subtitle: Text(
                      _gorunurlukAciklamasi(m, g),
                      style: sayfa.yazi.bodySmall?.copyWith(
                        color: sayfa.renkler.metinGovde,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Seçenek kartı: seçiliyse tint-brand zemin ve 2 px brand kenar, değilse
/// kart zemin ve çizgi kenar (tasarım: Profil-Gorunurluk, Profil-Dogum-Gunu,
/// Profil-Tamamla-Gorunurluk).
class SecimKarti extends StatelessWidget {
  const SecimKarti({super.key, required this.secili, required this.child});

  final bool secili;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Material(
      color: secili ? r.tintMarka : r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.secimKoseleri,
        side: BorderSide(
          color: secili ? r.marka : r.cizgi,
          width: secili ? TayfamSizes.alanOdakKenari : TayfamSizes.vurguKenari,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Satır içi üç parçalı tema seçici (tasarım: Profil-Ana "Tema"): cihaz
/// ayarı, açık, koyu. Seçili parça brand zemin + brand üstü metin. Ekran
/// okuyucu parçaları birbirini dışlayan seçenekler olarak okur.
class TemaSecici extends StatelessWidget {
  const TemaSecici({super.key, required this.secili, required this.onSec});

  final TemaTercihi secili;
  final ValueChanged<TemaTercihi> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        borderRadius: TayfamRadii.onizlemeKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, t) in TemaTercihi.values.indexed) ...[
                if (sira > 0) const SizedBox(width: TayfamSpacing.s4),
                Expanded(
                  child: _TemaParcasi(
                    etiket: switch (t) {
                      TemaTercihi.sistem => m.profil_tema_sistem,
                      TemaTercihi.acik => m.profil_tema_acik,
                      TemaTercihi.koyu => m.profil_tema_koyu,
                    },
                    secili: t == secili,
                    onTap: () => onSec(t),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TemaParcasi extends StatelessWidget {
  const _TemaParcasi({
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: Material(
        color: secili ? r.marka : r.zemin,
        borderRadius: TayfamRadii.dugmeKoseleri,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          checked: secili,
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s4,
                  vertical: TayfamSpacing.s8,
                ),
                child: Center(
                  child: Text(
                    etiket,
                    textAlign: TextAlign.center,
                    style: context.yazi.labelLarge?.copyWith(
                      color: secili ? r.markaUstu : r.metin,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
