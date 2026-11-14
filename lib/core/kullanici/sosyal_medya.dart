import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil tamamlama formundaki sosyal medya platformları, gösterim sırasıyla
/// (sözleşme: `SocialAccount.platform`; issue #186).
const List<SocialAccountPlatform> sosyalPlatformlar = [
  SocialAccountPlatform.instagram,
  SocialAccountPlatform.x,
  SocialAccountPlatform.tiktok,
  SocialAccountPlatform.youtube,
];

/// Sözleşmedeki kullanıcı adı kuralları (`SocialAccount` açıklaması; baştaki
/// `@` atıldıktan sonra). Tanınmayan platformun kuralı yoktur.
RegExp? _kural(SocialAccountPlatform platform) => switch (platform) {
  SocialAccountPlatform.instagram => RegExp(r'^[A-Za-z0-9._]{1,30}$'),
  SocialAccountPlatform.x => RegExp(r'^[A-Za-z0-9_]{1,15}$'),
  SocialAccountPlatform.tiktok => RegExp(r'^[A-Za-z0-9._]{2,24}$'),
  SocialAccountPlatform.youtube => RegExp(r'^[A-Za-z0-9._-]{3,30}$'),
  SocialAccountPlatform.unknown => null,
};

/// Kullanıcının yazdığı değerden kullanıcı adı: boşluklar ve baştaki `@`
/// atılır (sunucu da atar).
String sosyalKullaniciAdi(String girilen) {
  final kirpik = girilen.trim();
  return kirpik.startsWith('@') ? kirpik.substring(1).trim() : kirpik;
}

/// [ad] (baştaki `@` atılmış) [platform]'un kuralına uyuyor mu. URL ve
/// boşluk kabul edilmez; tanınmayan platform için `false`.
bool sosyalKullaniciAdiGecerli(SocialAccountPlatform platform, String ad) =>
    _kural(platform)?.hasMatch(ad) ?? false;

/// Hesabın platformdaki bilinen adresi (bağlantıyı istemci kurar; kişi
/// URL yazmaz). Kullanıcı adı kurala uymuyorsa ya da platform tanınmıyorsa
/// `null`: sunucudan gelen değer de girdi kabul edilir ve doğrulanır.
Uri? sosyalMedyaAdresi(SocialAccount hesap) {
  final ad = hesap.username;
  if (!sosyalKullaniciAdiGecerli(hesap.platform, ad)) return null;
  return switch (hesap.platform) {
    SocialAccountPlatform.instagram => Uri(
      scheme: 'https',
      host: 'www.instagram.com',
      pathSegments: [ad, ''],
    ),
    SocialAccountPlatform.x => Uri(
      scheme: 'https',
      host: 'x.com',
      pathSegments: [ad],
    ),
    SocialAccountPlatform.tiktok => Uri(
      scheme: 'https',
      host: 'www.tiktok.com',
      pathSegments: ['@$ad'],
    ),
    SocialAccountPlatform.youtube => Uri(
      scheme: 'https',
      host: 'www.youtube.com',
      pathSegments: ['@$ad'],
    ),
    SocialAccountPlatform.unknown => null,
  };
}

/// Platformun adı ("Instagram"); tanınmayan platform için `null`.
String? sosyalPlatformAdi(AppLocalizations m, SocialAccountPlatform p) =>
    switch (p) {
      SocialAccountPlatform.instagram => m.profil_sosyal_instagram,
      SocialAccountPlatform.x => m.profil_sosyal_x,
      SocialAccountPlatform.tiktok => m.profil_sosyal_tiktok,
      SocialAccountPlatform.youtube => m.profil_sosyal_youtube,
      SocialAccountPlatform.unknown => null,
    };
