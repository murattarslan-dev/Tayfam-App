import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/sosyal_medya.dart';
import 'package:tayfam/core/metin/diller.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/application/profil_tamamlama.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/profil/presentation/profil_sayfalari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Doğum günü görünürlüğü seçeneklerinin gösterim sırası (README kararı:
/// "Yalnızca doğum günüm" varsayılan ve ilk, sonra "Doğum tarihim ve
/// yaşım", en son "Kimse").
const List<BirthdayVisibility> dogumGunuSecenekleri = [
  BirthdayVisibility.birthday,
  BirthdayVisibility.full,
  BirthdayVisibility.hidden,
];

/// Seçeneğin adı. Tanınmayan değer varsayılan gibi gösterilir.
String dogumGunuAdi(AppLocalizations m, BirthdayVisibility g) => switch (g) {
  BirthdayVisibility.birthday ||
  BirthdayVisibility.unknown => m.profil_dogum_gunu_gun_ay,
  BirthdayVisibility.full => m.profil_dogum_gunu_tam,
  BirthdayVisibility.hidden => m.profil_dogum_gunu_gizli,
};

/// Seçeneğin açıklaması; satırlarda şu anki ayarın özeti olarak da
/// görünür ("Arkadaşların gün ve ayı görür").
String dogumGunuAciklamasi(AppLocalizations m, BirthdayVisibility g) =>
    switch (g) {
      BirthdayVisibility.birthday ||
      BirthdayVisibility.unknown => m.profil_dogum_gunu_gun_ay_aciklama,
      BirthdayVisibility.full => m.profil_dogum_gunu_tam_aciklama,
      BirthdayVisibility.hidden => m.profil_dogum_gunu_gizli_aciklama,
    };

/// "Doğum günün kime görünsün?" alttan sayfası (tasarım: Profil-Dogum-Gunu):
/// üç seçenek kartı. Seçilen değer döner (kaydı çağıran yapar; seçince
/// hemen kaydedilir). Vazgeçilirse `null`.
Future<BirthdayVisibility?> dogumGunuSayfasiniAc(
  BuildContext context, {
  required BirthdayVisibility secili,
}) {
  final m = AppLocalizations.of(context);
  return altSayfaAc<BirthdayVisibility>(
    context,
    builder: (sayfa) => AltSayfaIcerigi(
      baslik: m.profil_dogum_gunu_soru,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            0,
            TayfamSpacing.s8,
            TayfamSpacing.s12,
          ),
          child: Text(
            m.profil_dogum_gunu_aciklama,
            style: sayfa.yazi.bodyMedium?.copyWith(
              color: sayfa.renkler.metinGovde,
            ),
          ),
        ),
        RadioGroup<BirthdayVisibility>(
          groupValue: secili,
          onChanged: (secim) => Navigator.of(sayfa).pop(secim),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, g) in dogumGunuSecenekleri.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                SecimKarti(
                  secili: g == secili,
                  child: RadioListTile<BirthdayVisibility>(
                    value: g,
                    title: Text(dogumGunuAdi(m, g)),
                    subtitle: Text(
                      dogumGunuAciklamasi(m, g),
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

/// Doğum günü satırına dokununca (Profil → Gizlilik ve Tanıtım
/// bilgilerin): seçim sayfası açılır, seçilince hemen kaydedilir
/// (`PATCH /v1/me/account` `birthday_visibility`; issue #185). Hata olursa
/// kısa bildirim gösterilir, eski ayar kalır.
Future<void> dogumGunuSec(
  BuildContext context,
  WidgetRef ref,
  Account hesap,
) async {
  final secim = await dogumGunuSayfasiniAc(
    context,
    secili: hesap.birthdayVisibility,
  );
  if (secim == null || secim == hesap.birthdayVisibility || !context.mounted) {
    return;
  }
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final hata = await ref
      .read(hesapAyarlariProvider.notifier)
      .guncelle(AccountUpdate(birthdayVisibility: secim));
  if (hata != null) profilBildirimi(bildirim, profilHatasiMetni(m, hata));
}

/// "Kim görsün" seçeneklerinin gösterim sırası (tasarım:
/// Profil-Tamamla-Gorunurluk; varsayılan `friends_and_mutual`).
const List<AboutVisibility> tanitimGorunurlukSecenekleri = [
  AboutVisibility.friendsAndMutual,
  AboutVisibility.friends,
  AboutVisibility.none,
];

/// "Kim görsün" seçeneğinin adı. Tanınmayan değer varsayılan gibi
/// gösterilir.
String tanitimGorunurlukAdi(AppLocalizations m, AboutVisibility g) =>
    switch (g) {
      AboutVisibility.friendsAndMutual ||
      AboutVisibility.unknown => m.profil_tanitim_gorunurluk_ortak,
      AboutVisibility.friends => m.profil_tanitim_gorunurluk_arkadaslar,
      AboutVisibility.none => m.profil_tanitim_gorunurluk_kimse,
    };

/// "Kim görsün" seçeneğinin açıklaması.
String tanitimGorunurlukAciklamasi(AppLocalizations m, AboutVisibility g) =>
    switch (g) {
      AboutVisibility.friendsAndMutual ||
      AboutVisibility.unknown => m.profil_tanitim_gorunurluk_ortak_aciklama,
      AboutVisibility.friends =>
        m.profil_tanitim_gorunurluk_arkadaslar_aciklama,
      AboutVisibility.none => m.profil_tanitim_gorunurluk_kimse_aciklama,
    };

/// Adımın Tanıtım bilgilerin ekranındaki satır adı ("İlgi alanların").
String adimAdi(AppLocalizations m, TamamlamaAdimi adim) => switch (adim) {
  TamamlamaAdimi.ilgiler => m.profil_alan_ilgiler,
  TamamlamaAdimi.hakkimda => m.profil_alan_hakkimda,
  TamamlamaAdimi.meslek => m.profil_alan_meslek,
  TamamlamaAdimi.takim => m.profil_alan_takim,
  TamamlamaAdimi.diller => m.profil_alan_diller,
  TamamlamaAdimi.sosyal => m.profil_alan_sosyal,
  TamamlamaAdimi.gorunurluk => m.profil_tanitim_kim_gorur,
};

/// Alanın şu anki değerinin kısa özeti (tasarım: Profil-Tanitim): değer,
/// "Paylaşmak istemiyorum" ya da "Eklenmedi".
String alanOzeti(AppLocalizations m, Account hesap, ProfileField alan) {
  if (!alanDolu(hesap, alan)) {
    return alanReddedildi(hesap, alan)
        ? m.profil_tamamla_paylasmak_istemiyorum
        : m.profil_tanitim_eklenmedi;
  }
  return switch (alan) {
    ProfileField.interests => [
      for (final t in hesap.interests)
        if (t != EventType.unknown) etkinlikTuruGirdisi(t).ad(m),
    ].join(m.profil_liste_ayirici),
    ProfileField.about => hesap.about?.trim() ?? '',
    ProfileField.occupation => hesap.occupation?.trim() ?? '',
    ProfileField.team => hesap.team?.trim() ?? '',
    ProfileField.languages => dilListesi(m, hesap.languages),
    ProfileField.socialAccounts => [
      for (final s in hesap.socialAccounts) ?sosyalPlatformAdi(m, s.platform),
    ].join(m.profil_liste_ayirici),
    ProfileField.unknown => '',
  };
}
