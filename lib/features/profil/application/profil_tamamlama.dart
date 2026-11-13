import 'package:tayfam/core/api/gen/models.dart';

/// Profil tamamlama formunun adımları (issue #186; tasarım: Profil-Tamamla,
/// Profil-Tamamla-Hakkimda, -Diller, -Sosyal, -Gorunurluk), gösterim
/// sırasıyla. Her alan adımının sözleşmedeki karşılığı [alan]'dır; "Kim
/// görsün" ([gorunurluk]) bir alan değildir ve her zaman son adımdır.
enum TamamlamaAdimi {
  ilgiler(ProfileField.interests),
  hakkimda(ProfileField.about),
  meslek(ProfileField.occupation),
  takim(ProfileField.team),
  diller(ProfileField.languages),
  sosyal(ProfileField.socialAccounts),
  gorunurluk(null);

  const TamamlamaAdimi(this.alan);

  /// Adımın sözleşmedeki alanı; "Kim görsün" için `null`.
  final ProfileField? alan;

  /// Adımın tek başına açıldığı adresteki sabit parça
  /// (`/profil/tanitim/<yol>`).
  String get yol => name;
}

/// Hakkımda metninin en çok uzunluğu (sözleşme: `about` `maxLength: 160`).
const int hakkimdaEnCok = 160;

/// Meslek ve takımın en çok uzunluğu (sözleşme: `maxLength: 60`).
const int tekSatirEnCok = 60;

/// En çok dil sayısı (sözleşme: `languages` `maxItems: 5`).
const int dilEnCok = 5;

/// [hesap]'ta [alan]'ın değeri var mı (boş metin ve boş liste yok sayılır).
bool alanDolu(Account hesap, ProfileField alan) => switch (alan) {
  ProfileField.interests => hesap.interests.any((t) => t != EventType.unknown),
  ProfileField.about => (hesap.about ?? '').trim().isNotEmpty,
  ProfileField.occupation => (hesap.occupation ?? '').trim().isNotEmpty,
  ProfileField.team => (hesap.team ?? '').trim().isNotEmpty,
  ProfileField.languages => hesap.languages.isNotEmpty,
  ProfileField.socialAccounts => hesap.socialAccounts.isNotEmpty,
  // Tanımadığımız alan sorulamaz; cevaplanmış sayılır.
  ProfileField.unknown => true,
};

/// [alan] cevaplanmış mı: değeri var ya da "Paylaşmak istemiyorum"
/// denmiş (sözleşme: `declined_profile_fields`).
bool alanCevaplandi(Account hesap, ProfileField alan) =>
    alanDolu(hesap, alan) || hesap.declinedProfileFields.contains(alan);

/// [alan] için "Paylaşmak istemiyorum" denmiş mi.
bool alanReddedildi(Account hesap, ProfileField alan) =>
    hesap.declinedProfileFields.contains(alan);

/// Girişten sonra açılan formun adımları: yalnızca cevaplanmamış alanlar,
/// sonunda her zaman "Kim görsün" (README kararı). Adımlar form açılırken
/// bir kez hesaplanır; form sürerken kaydedilen alanlar listeden düşmez.
List<TamamlamaAdimi> tamamlamaAdimlari(Account hesap) => [
  for (final adim in TamamlamaAdimi.values)
    if (adim.alan == null || !alanCevaplandi(hesap, adim.alan!)) adim,
];
