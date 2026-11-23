// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

/// Sözleşmedeki şemalar ve satır içi tipleri (ADR-0005).
///
/// Modeller değişmezdir. Okurken tanınmayan JSON alanları yok
/// sayılır; yazarken `null` alanlar yazılmaz. Zamanlar UTC.
/// `toString` bilerek üretilmez: alan değerleri log'a
/// düşmesin (CLAUDE.md kesin kural 3).
library;

/// Profil tamamlama formundaki alanları kimin göreceği (issue #186).
/// `friends_and_mutual` (varsayılan): arkadaşlar ve ortak tayfa
/// üyeleri. `friends`: yalnızca arkadaşlar. `none`: kimse. Sosyal
/// medya hesapları her durumda en fazla arkadaşlara görünür.
enum AboutVisibility {
  friendsAndMutual('friends_and_mutual'),
  friends('friends'),
  none('none'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const AboutVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('AboutVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static AboutVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Account {
  const Account({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
    required this.referralCode,
    required this.activityVisibility,
    required this.birthdayVisibility,
    required this.interests,
    this.about,
    this.occupation,
    this.team,
    required this.languages,
    required this.socialAccounts,
    required this.declinedProfileFields,
    required this.aboutVisibility,
    required this.profileCompletionPending,
    required this.statsVisibility,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Account.fromJson(Map<String, Object?> json) => Account(
    userId: _readString(json['user_id'], 'Account.user_id'),
    displayName: _readString(json['display_name'], 'Account.display_name'),
    avatarUploadId: switch (json['avatar_upload_id']) {
      null => null,
      final Object v => _readString(v, 'Account.avatar_upload_id'),
    },
    referralCode: _readString(json['referral_code'], 'Account.referral_code'),
    activityVisibility: ActivityVisibility.fromWire(
      _readString(json['activity_visibility'], 'Account.activity_visibility'),
    ),
    birthdayVisibility: BirthdayVisibility.fromWire(
      _readString(json['birthday_visibility'], 'Account.birthday_visibility'),
    ),
    interests: List<String>.unmodifiable(
      _readList(
        json['interests'],
        'Account.interests',
      ).map((Object? e0) => _readString(e0, 'Account.interests')),
    ),
    about: switch (json['about']) {
      null => null,
      final Object v => _readString(v, 'Account.about'),
    },
    occupation: switch (json['occupation']) {
      null => null,
      final Object v => _readString(v, 'Account.occupation'),
    },
    team: switch (json['team']) {
      null => null,
      final Object v => _readString(v, 'Account.team'),
    },
    languages: List<String>.unmodifiable(
      _readList(
        json['languages'],
        'Account.languages',
      ).map((Object? e0) => _readString(e0, 'Account.languages')),
    ),
    socialAccounts: List<SocialAccount>.unmodifiable(
      _readList(json['social_accounts'], 'Account.social_accounts').map(
        (Object? e0) =>
            SocialAccount.fromJson(_readObject(e0, 'Account.social_accounts')),
      ),
    ),
    declinedProfileFields: List<ProfileField>.unmodifiable(
      _readList(
        json['declined_profile_fields'],
        'Account.declined_profile_fields',
      ).map(
        (Object? e0) => ProfileField.fromWire(
          _readString(e0, 'Account.declined_profile_fields'),
        ),
      ),
    ),
    aboutVisibility: AboutVisibility.fromWire(
      _readString(json['about_visibility'], 'Account.about_visibility'),
    ),
    profileCompletionPending: _readBool(
      json['profile_completion_pending'],
      'Account.profile_completion_pending',
    ),
    statsVisibility: StatsVisibility.fromWire(
      _readString(json['stats_visibility'], 'Account.stats_visibility'),
    ),
  );

  /// Kendi kullanıcı kimliğiniz.
  final String userId;

  /// Kendi görünen adınız.
  final String displayName;

  /// Avatar; linkleri `POST /v1/media/urls`.
  final String? avatarUploadId;

  /// Örn. `TYF-8K2M4Q`; paylaşım linki `tayfam.app/r/<kod>`.
  final String referralCode;

  final ActivityVisibility activityVisibility;

  final BirthdayVisibility birthdayVisibility;

  final List<String> interests;

  /// Boşsa alan yoktur.
  final String? about;

  /// Boşsa alan yoktur.
  final String? occupation;

  /// Boşsa alan yoktur.
  final String? team;

  final List<String> languages;

  final List<SocialAccount> socialAccounts;

  /// "Paylaşmak istemiyorum" denen alanlar; cevaplanmış sayılır.
  final List<ProfileField> declinedProfileFields;

  final AboutVisibility aboutVisibility;

  /// Profil tamamlama formu gösterilmeli: cevaplanmamış (boş ve
  /// reddedilmemiş) bir alan var ve geçerli bir erteleme yok.
  final bool profileCompletionPending;

  final StatsVisibility statsVisibility;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
    'referral_code': referralCode,
    'activity_visibility': activityVisibility.wire,
    'birthday_visibility': birthdayVisibility.wire,
    'interests': <Object?>[for (final e0 in interests) e0],
    if (about case final value?) 'about': value,
    if (occupation case final value?) 'occupation': value,
    if (team case final value?) 'team': value,
    'languages': <Object?>[for (final e0 in languages) e0],
    'social_accounts': <Object?>[for (final e0 in socialAccounts) e0.toJson()],
    'declined_profile_fields': <Object?>[
      for (final e0 in declinedProfileFields) e0.wire,
    ],
    'about_visibility': aboutVisibility.wire,
    'profile_completion_pending': profileCompletionPending,
    'stats_visibility': statsVisibility.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId &&
          referralCode == other.referralCode &&
          activityVisibility == other.activityVisibility &&
          birthdayVisibility == other.birthdayVisibility &&
          _deepEquals(interests, other.interests) &&
          about == other.about &&
          occupation == other.occupation &&
          team == other.team &&
          _deepEquals(languages, other.languages) &&
          _deepEquals(socialAccounts, other.socialAccounts) &&
          _deepEquals(declinedProfileFields, other.declinedProfileFields) &&
          aboutVisibility == other.aboutVisibility &&
          profileCompletionPending == other.profileCompletionPending &&
          statsVisibility == other.statsVisibility;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    displayName,
    avatarUploadId,
    referralCode,
    activityVisibility,
    birthdayVisibility,
    _deepHash(interests),
    about,
    occupation,
    team,
    _deepHash(languages),
    _deepHash(socialAccounts),
    _deepHash(declinedProfileFields),
    aboutVisibility,
    profileCompletionPending,
    statsVisibility,
  ]);
}

/// En az bir alan bulunur; olmayan alan değişmez.
///
/// Kısıtlar: minProperties: 1.
final class AccountUpdate {
  const AccountUpdate({
    this.displayName,
    this.activityVisibility,
    this.birthdayVisibility,
    this.interests,
    this.about,
    this.occupation,
    this.team,
    this.languages,
    this.socialAccounts,
    this.declinedProfileFields,
    this.aboutVisibility,
    this.statsVisibility,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AccountUpdate.fromJson(Map<String, Object?> json) => AccountUpdate(
    displayName: switch (json['display_name']) {
      null => null,
      final Object v => _readString(v, 'AccountUpdate.display_name'),
    },
    activityVisibility: switch (json['activity_visibility']) {
      null => null,
      final Object v => ActivityVisibility.fromWire(
        _readString(v, 'AccountUpdate.activity_visibility'),
      ),
    },
    birthdayVisibility: switch (json['birthday_visibility']) {
      null => null,
      final Object v => BirthdayVisibility.fromWire(
        _readString(v, 'AccountUpdate.birthday_visibility'),
      ),
    },
    interests: switch (json['interests']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(
          v,
          'AccountUpdate.interests',
        ).map((Object? e0) => _readString(e0, 'AccountUpdate.interests')),
      ),
    },
    about: switch (json['about']) {
      null => null,
      final Object v => _readString(v, 'AccountUpdate.about'),
    },
    occupation: switch (json['occupation']) {
      null => null,
      final Object v => _readString(v, 'AccountUpdate.occupation'),
    },
    team: switch (json['team']) {
      null => null,
      final Object v => _readString(v, 'AccountUpdate.team'),
    },
    languages: switch (json['languages']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(
          v,
          'AccountUpdate.languages',
        ).map((Object? e0) => _readString(e0, 'AccountUpdate.languages')),
      ),
    },
    socialAccounts: switch (json['social_accounts']) {
      null => null,
      final Object v => List<SocialAccount>.unmodifiable(
        _readList(v, 'AccountUpdate.social_accounts').map(
          (Object? e0) => SocialAccount.fromJson(
            _readObject(e0, 'AccountUpdate.social_accounts'),
          ),
        ),
      ),
    },
    declinedProfileFields: switch (json['declined_profile_fields']) {
      null => null,
      final Object v => List<ProfileField>.unmodifiable(
        _readList(v, 'AccountUpdate.declined_profile_fields').map(
          (Object? e0) => ProfileField.fromWire(
            _readString(e0, 'AccountUpdate.declined_profile_fields'),
          ),
        ),
      ),
    },
    aboutVisibility: switch (json['about_visibility']) {
      null => null,
      final Object v => AboutVisibility.fromWire(
        _readString(v, 'AccountUpdate.about_visibility'),
      ),
    },
    statsVisibility: switch (json['stats_visibility']) {
      null => null,
      final Object v => StatsVisibility.fromWire(
        _readString(v, 'AccountUpdate.stats_visibility'),
      ),
    },
  );

  /// Yeni görünen ad; boşluklar tekleştirilip kırpıldıktan sonra 1–40
  /// karakter. 24 saatte en fazla 3 değişiklik.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String? displayName;

  final ActivityVisibility? activityVisibility;

  final BirthdayVisibility? birthdayVisibility;

  /// Katalogdaki ilgi alanlarından tekrarsız çoklu seçim.
  ///
  /// Kısıtlar: maxItems: 20; uniqueItems: true.
  final List<String>? interests;

  /// Hakkımda; kırpıldıktan sonra en fazla 160 karakter, satır sonu olabilir. `""` temizler.
  ///
  /// Kısıtlar: maxLength: 160.
  final String? about;

  /// Meslek / uğraş; tek satır, en fazla 60 karakter. `""` temizler.
  ///
  /// Kısıtlar: maxLength: 60.
  final String? occupation;

  /// Tutulan takım; tek satır, en fazla 60 karakter. `""` temizler.
  ///
  /// Kısıtlar: maxLength: 60.
  final String? team;

  /// ISO 639-1 kodları (`tr`, `en`), en fazla 5, tekrarsız.
  ///
  /// Kısıtlar: maxItems: 5.
  final List<String>? languages;

  /// Tamamı değişir; platform başına bir hesap.
  ///
  /// Kısıtlar: maxItems: 4.
  final List<SocialAccount>? socialAccounts;

  /// Gönderilirse "Paylaşmak istemiyorum" listesinin tamamı olur.
  ///
  /// Kısıtlar: uniqueItems: true.
  final List<ProfileField>? declinedProfileFields;

  final AboutVisibility? aboutVisibility;

  final StatsVisibility? statsVisibility;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (displayName case final value?) 'display_name': value,
    if (activityVisibility case final value?) 'activity_visibility': value.wire,
    if (birthdayVisibility case final value?) 'birthday_visibility': value.wire,
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0],
    if (about case final value?) 'about': value,
    if (occupation case final value?) 'occupation': value,
    if (team case final value?) 'team': value,
    if (languages case final value?)
      'languages': <Object?>[for (final e0 in value) e0],
    if (socialAccounts case final value?)
      'social_accounts': <Object?>[for (final e0 in value) e0.toJson()],
    if (declinedProfileFields case final value?)
      'declined_profile_fields': <Object?>[for (final e0 in value) e0.wire],
    if (aboutVisibility case final value?) 'about_visibility': value.wire,
    if (statsVisibility case final value?) 'stats_visibility': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountUpdate &&
          displayName == other.displayName &&
          activityVisibility == other.activityVisibility &&
          birthdayVisibility == other.birthdayVisibility &&
          _deepEquals(interests, other.interests) &&
          about == other.about &&
          occupation == other.occupation &&
          team == other.team &&
          _deepEquals(languages, other.languages) &&
          _deepEquals(socialAccounts, other.socialAccounts) &&
          _deepEquals(declinedProfileFields, other.declinedProfileFields) &&
          aboutVisibility == other.aboutVisibility &&
          statsVisibility == other.statsVisibility;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    displayName,
    activityVisibility,
    birthdayVisibility,
    _deepHash(interests),
    about,
    occupation,
    team,
    _deepHash(languages),
    _deepHash(socialAccounts),
    _deepHash(declinedProfileFields),
    aboutVisibility,
    statsVisibility,
  ]);
}

final class ActivityList {
  const ActivityList({required this.records, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ActivityList.fromJson(Map<String, Object?> json) => ActivityList(
    records: List<ActivityRecord>.unmodifiable(
      _readList(json['records'], 'ActivityList.records').map(
        (Object? e0) =>
            ActivityRecord.fromJson(_readObject(e0, 'ActivityList.records')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'ActivityList.next_page_token'),
    },
  );

  final List<ActivityRecord> records;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'records': <Object?>[for (final e0 in records) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityList &&
          _deepEquals(records, other.records) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(records), nextPageToken]);
}

final class ActivityRecord {
  const ActivityRecord({
    required this.eventType,
    required this.mode,
    this.city,
    this.district,
    required this.startedAt,
    required this.tayfaMember,
    this.tayfaId,
    this.tayfaName,
    this.eventId,
    this.eventTitle,
    this.durationMinutes,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ActivityRecord.fromJson(Map<String, Object?> json) => ActivityRecord(
    eventType: _readString(json['event_type'], 'ActivityRecord.event_type'),
    mode: ActivityRecordMode.fromWire(
      _readString(json['mode'], 'ActivityRecord.mode'),
    ),
    city: switch (json['city']) {
      null => null,
      final Object v => _readString(v, 'ActivityRecord.city'),
    },
    district: switch (json['district']) {
      null => null,
      final Object v => _readString(v, 'ActivityRecord.district'),
    },
    startedAt: _readDateTime(json['started_at'], 'ActivityRecord.started_at'),
    tayfaMember: _readBool(json['tayfa_member'], 'ActivityRecord.tayfa_member'),
    tayfaId: switch (json['tayfa_id']) {
      null => null,
      final Object v => _readString(v, 'ActivityRecord.tayfa_id'),
    },
    tayfaName: switch (json['tayfa_name']) {
      null => null,
      final Object v => _readString(v, 'ActivityRecord.tayfa_name'),
    },
    eventId: switch (json['event_id']) {
      null => null,
      final Object v => _readString(v, 'ActivityRecord.event_id'),
    },
    eventTitle: switch (json['event_title']) {
      null => null,
      final Object v => _readString(v, 'ActivityRecord.event_title'),
    },
    durationMinutes: switch (json['duration_minutes']) {
      null => null,
      final Object v => _readInt(v, 'ActivityRecord.duration_minutes'),
    },
  );

  final String eventType;

  final ActivityRecordMode mode;

  final String? city;

  final String? district;

  final DateTime startedAt;

  /// Kaydın tayfasının etkin üyesisiniz; aşağıdaki alanlar yalnızca o zaman doludur.
  final bool tayfaMember;

  final String? tayfaId;

  final String? tayfaName;

  /// Etkinlik silinmişse yoktur.
  final String? eventId;

  final String? eventTitle;

  final int? durationMinutes;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'event_type': eventType,
    'mode': mode.wire,
    if (city case final value?) 'city': value,
    if (district case final value?) 'district': value,
    'started_at': startedAt.toUtc().toIso8601String(),
    'tayfa_member': tayfaMember,
    if (tayfaId case final value?) 'tayfa_id': value,
    if (tayfaName case final value?) 'tayfa_name': value,
    if (eventId case final value?) 'event_id': value,
    if (eventTitle case final value?) 'event_title': value,
    if (durationMinutes case final value?) 'duration_minutes': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityRecord &&
          eventType == other.eventType &&
          mode == other.mode &&
          city == other.city &&
          district == other.district &&
          startedAt == other.startedAt &&
          tayfaMember == other.tayfaMember &&
          tayfaId == other.tayfaId &&
          tayfaName == other.tayfaName &&
          eventId == other.eventId &&
          eventTitle == other.eventTitle &&
          durationMinutes == other.durationMinutes;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    eventType,
    mode,
    city,
    district,
    startedAt,
    tayfaMember,
    tayfaId,
    tayfaName,
    eventId,
    eventTitle,
    durationMinutes,
  ]);
}

enum ActivityRecordMode {
  inPerson('in_person'),
  online('online'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ActivityRecordMode(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ActivityRecordMode.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ActivityRecordMode fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Katılım geçmişinin kime görüneceği.
enum ActivityVisibility {
  private('private'),
  tayfa('tayfa'),
  public('public'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ActivityVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ActivityVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ActivityVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Announcement {
  const Announcement({
    required this.id,
    required this.tayfaId,
    this.authorUserId,
    required this.title,
    required this.body,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
    this.editedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Announcement.fromJson(Map<String, Object?> json) => Announcement(
    id: _readString(json['id'], 'Announcement.id'),
    tayfaId: _readString(json['tayfa_id'], 'Announcement.tayfa_id'),
    authorUserId: switch (json['author_user_id']) {
      null => null,
      final Object v => _readString(v, 'Announcement.author_user_id'),
    },
    title: _readString(json['title'], 'Announcement.title'),
    body: _readString(json['body'], 'Announcement.body'),
    pinned: _readBool(json['pinned'], 'Announcement.pinned'),
    createdAt: _readDateTime(json['created_at'], 'Announcement.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Announcement.updated_at'),
    editedAt: switch (json['edited_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Announcement.edited_at'),
    },
  );

  final String id;

  final String tayfaId;

  /// Yazarın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? authorUserId;

  final String title;

  final String body;

  final bool pinned;

  final DateTime createdAt;

  /// Her düzenleme, sabitleme ve geri almada değişir.
  final DateTime updatedAt;

  /// Başlık ya da gövdenin son değiştiği zaman (issue #191).
  /// Sabitleme, sabitlemeyi kaldırma ve geri alma onu değiştirmez.
  /// Hiç düzenlenmemiş duyuruda yoktur; istemci "düzenlendi"
  /// etiketini bu alana göre gösterir.
  final DateTime? editedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    if (authorUserId case final value?) 'author_user_id': value,
    'title': title,
    'body': body,
    'pinned': pinned,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (editedAt case final value?)
      'edited_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Announcement &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          authorUserId == other.authorUserId &&
          title == other.title &&
          body == other.body &&
          pinned == other.pinned &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          editedAt == other.editedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    authorUserId,
    title,
    body,
    pinned,
    createdAt,
    updatedAt,
    editedAt,
  ]);
}

final class AnnouncementCreateRequest {
  const AnnouncementCreateRequest({
    required this.title,
    this.body,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnnouncementCreateRequest.fromJson(Map<String, Object?> json) =>
      AnnouncementCreateRequest(
        title: _readString(json['title'], 'AnnouncementCreateRequest.title'),
        body: switch (json['body']) {
          null => null,
          final Object v => _readString(v, 'AnnouncementCreateRequest.body'),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'AnnouncementCreateRequest.client_request_id',
        ),
      );

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 1–120 karakter, tek satır.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String title;

  /// En fazla 5000 karakter; satır sonu olabilir.
  ///
  /// Kısıtlar: maxLength: 5000.
  final String? body;

  /// İstemcinin her yayınlama denemesi için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    if (body case final value?) 'body': value,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementCreateRequest &&
          title == other.title &&
          body == other.body &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[title, body, clientRequestId]);
}

final class AnnouncementList {
  const AnnouncementList({required this.announcements, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnnouncementList.fromJson(Map<String, Object?> json) =>
      AnnouncementList(
        announcements: List<Announcement>.unmodifiable(
          _readList(
            json['announcements'],
            'AnnouncementList.announcements',
          ).map(
            (Object? e0) => Announcement.fromJson(
              _readObject(e0, 'AnnouncementList.announcements'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'AnnouncementList.next_page_token'),
        },
      );

  final List<Announcement> announcements;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'announcements': <Object?>[for (final e0 in announcements) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementList &&
          _deepEquals(announcements, other.announcements) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(announcements), nextPageToken]);
}

/// Kısıtlar: minProperties: 1.
final class AnnouncementUpdateRequest {
  const AnnouncementUpdateRequest({this.title, this.body});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnnouncementUpdateRequest.fromJson(Map<String, Object?> json) =>
      AnnouncementUpdateRequest(
        title: switch (json['title']) {
          null => null,
          final Object v => _readString(v, 'AnnouncementUpdateRequest.title'),
        },
        body: switch (json['body']) {
          null => null,
          final Object v => _readString(v, 'AnnouncementUpdateRequest.body'),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String? title;

  /// Kısıtlar: maxLength: 5000.
  final String? body;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (title case final value?) 'title': value,
    if (body case final value?) 'body': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementUpdateRequest &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => Object.hashAll(<Object?>[title, body]);
}

final class Answer {
  const Answer({
    required this.id,
    required this.questionId,
    required this.tayfaId,
    this.authorUserId,
    required this.body,
    required this.voteCount,
    required this.voted,
    required this.createdAt,
    required this.updatedAt,
    required this.photoUploadIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Answer.fromJson(Map<String, Object?> json) => Answer(
    id: _readString(json['id'], 'Answer.id'),
    questionId: _readString(json['question_id'], 'Answer.question_id'),
    tayfaId: _readString(json['tayfa_id'], 'Answer.tayfa_id'),
    authorUserId: switch (json['author_user_id']) {
      null => null,
      final Object v => _readString(v, 'Answer.author_user_id'),
    },
    body: _readString(json['body'], 'Answer.body'),
    voteCount: _readInt(json['vote_count'], 'Answer.vote_count'),
    voted: _readBool(json['voted'], 'Answer.voted'),
    createdAt: _readDateTime(json['created_at'], 'Answer.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Answer.updated_at'),
    photoUploadIds: List<String>.unmodifiable(
      _readList(
        json['photo_upload_ids'],
        'Answer.photo_upload_ids',
      ).map((Object? e0) => _readString(e0, 'Answer.photo_upload_ids')),
    ),
  );

  final String id;

  final String questionId;

  final String tayfaId;

  /// Yazarın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? authorUserId;

  final String body;

  /// Faydalı oyu sayısı.
  final int voteCount;

  /// Çağıran bu cevaba oy verdi mi.
  final bool voted;

  final DateTime createdAt;

  /// Her düzenleme ve geri almada değişir; oylar değiştirmez.
  final DateTime updatedAt;

  /// Soru havuzunda 0–2 fotoğraf (`question_pool` yüklemesi), sırasıyla. Soru-Cevap'ta boştur.
  ///
  /// Kısıtlar: maxItems: 2.
  final List<String> photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'question_id': questionId,
    'tayfa_id': tayfaId,
    if (authorUserId case final value?) 'author_user_id': value,
    'body': body,
    'vote_count': voteCount,
    'voted': voted,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'photo_upload_ids': <Object?>[for (final e0 in photoUploadIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Answer &&
          id == other.id &&
          questionId == other.questionId &&
          tayfaId == other.tayfaId &&
          authorUserId == other.authorUserId &&
          body == other.body &&
          voteCount == other.voteCount &&
          voted == other.voted &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    questionId,
    tayfaId,
    authorUserId,
    body,
    voteCount,
    voted,
    createdAt,
    updatedAt,
    _deepHash(photoUploadIds),
  ]);
}

final class AnswerCreateRequest {
  const AnswerCreateRequest({
    required this.body,
    required this.clientRequestId,
    this.photoUploadIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnswerCreateRequest.fromJson(Map<String, Object?> json) =>
      AnswerCreateRequest(
        body: _readString(json['body'], 'AnswerCreateRequest.body'),
        clientRequestId: _readString(
          json['client_request_id'],
          'AnswerCreateRequest.client_request_id',
        ),
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'AnswerCreateRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'AnswerCreateRequest.photo_upload_ids'),
            ),
          ),
        },
      );

  /// Boşluklar atıldıktan sonra 1–10000 karakter; satır sonu olabilir. Soru havuzunda fotoğraf varsa boş olabilir.
  ///
  /// Kısıtlar: maxLength: 10000.
  final String body;

  final String clientRequestId;

  /// Yalnızca soru havuzunda; 0–2 fotoğraf (`question_pool` yüklemesi).
  ///
  /// Kısıtlar: maxItems: 2.
  final List<String>? photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    'client_request_id': clientRequestId,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerCreateRequest &&
          body == other.body &&
          clientRequestId == other.clientRequestId &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    body,
    clientRequestId,
    _deepHash(photoUploadIds),
  ]);
}

final class AnswerList {
  const AnswerList({required this.answers, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnswerList.fromJson(Map<String, Object?> json) => AnswerList(
    answers: List<Answer>.unmodifiable(
      _readList(json['answers'], 'AnswerList.answers').map(
        (Object? e0) => Answer.fromJson(_readObject(e0, 'AnswerList.answers')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'AnswerList.next_page_token'),
    },
  );

  final List<Answer> answers;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'answers': <Object?>[for (final e0 in answers) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerList &&
          _deepEquals(answers, other.answers) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(answers), nextPageToken]);
}

/// Cevabın içeriğinin yeni hali; soru havuzunda `photo_upload_ids` yoksa ya da `[]` ise fotoğraflar kalkar (dosyaları silinir).
final class AnswerUpdateRequest {
  const AnswerUpdateRequest({required this.body, this.photoUploadIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnswerUpdateRequest.fromJson(Map<String, Object?> json) =>
      AnswerUpdateRequest(
        body: _readString(json['body'], 'AnswerUpdateRequest.body'),
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'AnswerUpdateRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'AnswerUpdateRequest.photo_upload_ids'),
            ),
          ),
        },
      );

  /// Boşluklar atıldıktan sonra 1–10000 karakter; soru havuzunda fotoğraf varsa boş olabilir.
  ///
  /// Kısıtlar: maxLength: 10000.
  final String body;

  /// Kısıtlar: maxItems: 2.
  final List<String>? photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerUpdateRequest &&
          body == other.body &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[body, _deepHash(photoUploadIds)]);
}

/// `location`: buluşma noktasına 300 m içinde check-in. `online`:
/// çevrimiçi etkinlikte "Katıldım". `hike_start`: yoklamada çıkış (`roll_call`).
/// `organizer`: organizatör düzeltmesi. `qr`: üye organizatörün
/// QR'ını okuttu (ADR-0038 §3).
enum AttendanceMethod {
  location('location'),
  online('online'),
  hikeStart('hike_start'),
  organizer('organizer'),
  qr('qr'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const AttendanceMethod(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('AttendanceMethod.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static AttendanceMethod fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `attended`: doğrulandı. `no_show`: organizatör düzeltmesiyle kaldırıldı.
enum AttendanceStatus {
  attended('attended'),
  noShow('no_show'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const AttendanceStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('AttendanceStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static AttendanceStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Attendee {
  const Attendee({
    required this.userId,
    required this.status,
    required this.updatedAt,
    this.attendance,
    this.attendanceMethod,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Attendee.fromJson(Map<String, Object?> json) => Attendee(
    userId: _readString(json['user_id'], 'Attendee.user_id'),
    status: RsvpStatus.fromWire(_readString(json['status'], 'Attendee.status')),
    updatedAt: _readDateTime(json['updated_at'], 'Attendee.updated_at'),
    attendance: switch (json['attendance']) {
      null => null,
      final Object v => AttendanceStatus.fromWire(
        _readString(v, 'Attendee.attendance'),
      ),
    },
    attendanceMethod: switch (json['attendance_method']) {
      null => null,
      final Object v => AttendanceMethod.fromWire(
        _readString(v, 'Attendee.attendance_method'),
      ),
    },
  );

  final String userId;

  final RsvpStatus status;

  /// Cevabın ya da katılımın son değiştiği zaman.
  final DateTime updatedAt;

  /// Doğrulanmamışsa yoktur.
  final AttendanceStatus? attendance;

  final AttendanceMethod? attendanceMethod;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'status': status.wire,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (attendance case final value?) 'attendance': value.wire,
    if (attendanceMethod case final value?) 'attendance_method': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attendee &&
          userId == other.userId &&
          status == other.status &&
          updatedAt == other.updatedAt &&
          attendance == other.attendance &&
          attendanceMethod == other.attendanceMethod;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    status,
    updatedAt,
    attendance,
    attendanceMethod,
  ]);
}

final class AttendeeList {
  const AttendeeList({required this.attendees, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AttendeeList.fromJson(Map<String, Object?> json) => AttendeeList(
    attendees: List<Attendee>.unmodifiable(
      _readList(json['attendees'], 'AttendeeList.attendees').map(
        (Object? e0) =>
            Attendee.fromJson(_readObject(e0, 'AttendeeList.attendees')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'AttendeeList.next_page_token'),
    },
  );

  final List<Attendee> attendees;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'attendees': <Object?>[for (final e0 in attendees) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendeeList &&
          _deepEquals(attendees, other.attendees) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(attendees), nextPageToken]);
}

final class AvailabilityDay {
  const AvailabilityDay({
    required this.date,
    required this.slots,
    this.note,
    required this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AvailabilityDay.fromJson(Map<String, Object?> json) =>
      AvailabilityDay(
        date: _readString(json['date'], 'AvailabilityDay.date'),
        slots: List<DaySlot>.unmodifiable(
          _readList(json['slots'], 'AvailabilityDay.slots').map(
            (Object? e0) =>
                DaySlot.fromWire(_readString(e0, 'AvailabilityDay.slots')),
          ),
        ),
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'AvailabilityDay.note'),
        },
        updatedAt: _readDateTime(
          json['updated_at'],
          'AvailabilityDay.updated_at',
        ),
      );

  /// Takvim günü (Europe/Istanbul).
  ///
  /// Kısıtlar: biçim: `YYYY-AA-GG` (saat dilimsiz tarih).
  final String date;

  /// Sabah, öğleden sonra, akşam sırasıyla; ya da yalnızca `all_day`.
  ///
  /// Kısıtlar: minItems: 1; maxItems: 3.
  final List<DaySlot> slots;

  /// Not yoksa alan yoktur.
  ///
  /// Kısıtlar: maxLength: 60.
  final String? note;

  final DateTime updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'date': date,
    'slots': <Object?>[for (final e0 in slots) e0.wire],
    if (note case final value?) 'note': value,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilityDay &&
          date == other.date &&
          _deepEquals(slots, other.slots) &&
          note == other.note &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[date, _deepHash(slots), note, updatedAt]);
}

final class AvailabilityDayList {
  const AvailabilityDayList({required this.days});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AvailabilityDayList.fromJson(Map<String, Object?> json) =>
      AvailabilityDayList(
        days: List<AvailabilityDay>.unmodifiable(
          _readList(json['days'], 'AvailabilityDayList.days').map(
            (Object? e0) => AvailabilityDay.fromJson(
              _readObject(e0, 'AvailabilityDayList.days'),
            ),
          ),
        ),
      );

  /// Kısıtlar: maxItems: 31.
  final List<AvailabilityDay> days;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'days': <Object?>[for (final e0 in days) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilityDayList && _deepEquals(days, other.days);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(days)]);
}

final class AvailabilityInput {
  const AvailabilityInput({required this.slots, this.note});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AvailabilityInput.fromJson(Map<String, Object?> json) =>
      AvailabilityInput(
        slots: List<DaySlot>.unmodifiable(
          _readList(json['slots'], 'AvailabilityInput.slots').map(
            (Object? e0) =>
                DaySlot.fromWire(_readString(e0, 'AvailabilityInput.slots')),
          ),
        ),
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'AvailabilityInput.note'),
        },
      );

  /// Tekrar eden dilim yok sayılır. `all_day` tek başına.
  ///
  /// Kısıtlar: minItems: 1; maxItems: 4.
  final List<DaySlot> slots;

  /// İsteğe bağlı, en fazla 60 karakter. Kontrol karakteri (satır sonu
  /// dahil), satır/paragraf ayırıcı (U+2028, U+2029), yön kontrolü
  /// (U+202A–U+202E, U+2066–U+2069) ve görünmez karakter (U+200B
  /// gibi) içeremez; emoji dizileri (U+200D) serbesttir. Baştaki ve
  /// sondaki boşluk kırpılır.
  ///
  /// Kısıtlar: maxLength: 60.
  final String? note;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'slots': <Object?>[for (final e0 in slots) e0.wire],
    if (note case final value?) 'note': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilityInput &&
          _deepEquals(slots, other.slots) &&
          note == other.note;

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(slots), note]);
}

final class AvailabilitySummary {
  const AvailabilitySummary({required this.date, required this.slots});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AvailabilitySummary.fromJson(Map<String, Object?> json) =>
      AvailabilitySummary(
        date: _readString(json['date'], 'AvailabilitySummary.date'),
        slots: List<DaySlot>.unmodifiable(
          _readList(json['slots'], 'AvailabilitySummary.slots').map(
            (Object? e0) =>
                DaySlot.fromWire(_readString(e0, 'AvailabilitySummary.slots')),
          ),
        ),
      );

  /// Kısıtlar: biçim: `YYYY-AA-GG` (saat dilimsiz tarih).
  final String date;

  /// Kısıtlar: minItems: 1; maxItems: 3.
  final List<DaySlot> slots;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'date': date,
    'slots': <Object?>[for (final e0 in slots) e0.wire],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilitySummary &&
          date == other.date &&
          _deepEquals(slots, other.slots);

  @override
  int get hashCode => Object.hashAll(<Object?>[date, _deepHash(slots)]);
}

final class AvatarRequest {
  const AvatarRequest({required this.uploadId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AvatarRequest.fromJson(Map<String, Object?> json) => AvatarRequest(
    uploadId: _readString(json['upload_id'], 'AvatarRequest.upload_id'),
  );

  final String uploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'upload_id': uploadId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarRequest && uploadId == other.uploadId;

  @override
  int get hashCode => Object.hashAll(<Object?>[uploadId]);
}

final class AvatarView {
  const AvatarView({required this.avatarUploadId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AvatarView.fromJson(Map<String, Object?> json) => AvatarView(
    avatarUploadId: _readString(
      json['avatar_upload_id'],
      'AvatarView.avatar_upload_id',
    ),
  );

  final String avatarUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'avatar_upload_id': avatarUploadId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarView && avatarUploadId == other.avatarUploadId;

  @override
  int get hashCode => Object.hashAll(<Object?>[avatarUploadId]);
}

final class BanRequest {
  const BanRequest({this.reason});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory BanRequest.fromJson(Map<String, Object?> json) => BanRequest(
    reason: switch (json['reason']) {
      null => null,
      final Object v => ReportReason.fromWire(
        _readString(v, 'BanRequest.reason'),
      ),
    },
  );

  /// İsteğe bağlı. Şikâyet nedenleriyle aynı liste; `staff_conduct`
  /// kabul edilmez (`validation`, alan `reason`).
  final ReportReason? reason;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (reason case final value?) 'reason': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BanRequest && reason == other.reason;

  @override
  int get hashCode => Object.hashAll(<Object?>[reason]);
}

/// Doğum gününün gösterilen kısmı. Yalnızca arkadaşlara ve ayar izin
/// verdiğinde (kendi profilinizde her zaman) döner; yoksa alan da
/// yoktur.
final class Birthday {
  const Birthday({required this.month, required this.day, this.year, this.age});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Birthday.fromJson(Map<String, Object?> json) => Birthday(
    month: _readInt(json['month'], 'Birthday.month'),
    day: _readInt(json['day'], 'Birthday.day'),
    year: switch (json['year']) {
      null => null,
      final Object v => _readInt(v, 'Birthday.year'),
    },
    age: switch (json['age']) {
      null => null,
      final Object v => _readInt(v, 'Birthday.age'),
    },
  );

  /// Kısıtlar: minimum: 1; maximum: 12.
  final int month;

  /// Kısıtlar: minimum: 1; maximum: 31.
  final int day;

  /// Yalnızca `full` ayarında ve kendi profilinizde.
  final int? year;

  /// Bugünkü yaş (Türkiye saatiyle); `year` ile birlikte.
  final int? age;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'month': month,
    'day': day,
    if (year case final value?) 'year': value,
    if (age case final value?) 'age': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Birthday &&
          month == other.month &&
          day == other.day &&
          year == other.year &&
          age == other.age;

  @override
  int get hashCode => Object.hashAll(<Object?>[month, day, year, age]);
}

/// Doğum gününüzün arkadaşlarınıza ne kadarının görüneceği (issue #185).
/// Arkadaşınız olmayan hiç kimse görmez. `hidden`: kimse. `birthday`
/// (varsayılan): gün ve ay. `full`: tarih ve yaş.
enum BirthdayVisibility {
  hidden('hidden'),
  birthday('birthday'),
  full('full'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const BirthdayVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('BirthdayVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static BirthdayVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class BlockedUser {
  const BlockedUser({
    required this.userId,
    this.displayName,
    this.avatarUploadId,
    required this.blockedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory BlockedUser.fromJson(Map<String, Object?> json) => BlockedUser(
    userId: _readString(json['user_id'], 'BlockedUser.user_id'),
    displayName: switch (json['display_name']) {
      null => null,
      final Object v => _readString(v, 'BlockedUser.display_name'),
    },
    avatarUploadId: switch (json['avatar_upload_id']) {
      null => null,
      final Object v => _readString(v, 'BlockedUser.avatar_upload_id'),
    },
    blockedAt: _readDateTime(json['blocked_at'], 'BlockedUser.blocked_at'),
  );

  final String userId;

  /// Hesap silinmişse yoktur.
  final String? displayName;

  final String? avatarUploadId;

  final DateTime blockedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    if (displayName case final value?) 'display_name': value,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
    'blocked_at': blockedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedUser &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId &&
          blockedAt == other.blockedAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[userId, displayName, avatarUploadId, blockedAt]);
}

final class BlockedUserList {
  const BlockedUserList({required this.users, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory BlockedUserList.fromJson(Map<String, Object?> json) =>
      BlockedUserList(
        users: List<BlockedUser>.unmodifiable(
          _readList(json['users'], 'BlockedUserList.users').map(
            (Object? e0) =>
                BlockedUser.fromJson(_readObject(e0, 'BlockedUserList.users')),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'BlockedUserList.next_page_token'),
        },
      );

  final List<BlockedUser> users;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'users': <Object?>[for (final e0 in users) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedUserList &&
          _deepEquals(users, other.users) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(users), nextPageToken]);
}

final class Catalog {
  const Catalog({
    required this.catalogVersion,
    required this.interests,
    required this.eventTypes,
    required this.studyTags,
    required this.badges,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Catalog.fromJson(Map<String, Object?> json) => Catalog(
    catalogVersion: _readInt(
      json['catalog_version'],
      'Catalog.catalog_version',
    ),
    interests: List<CatalogInterest>.unmodifiable(
      _readList(json['interests'], 'Catalog.interests').map(
        (Object? e0) =>
            CatalogInterest.fromJson(_readObject(e0, 'Catalog.interests')),
      ),
    ),
    eventTypes: List<CatalogEventType>.unmodifiable(
      _readList(json['event_types'], 'Catalog.event_types').map(
        (Object? e0) =>
            CatalogEventType.fromJson(_readObject(e0, 'Catalog.event_types')),
      ),
    ),
    studyTags: List<CatalogStudyTag>.unmodifiable(
      _readList(json['study_tags'], 'Catalog.study_tags').map(
        (Object? e0) =>
            CatalogStudyTag.fromJson(_readObject(e0, 'Catalog.study_tags')),
      ),
    ),
    badges: List<CatalogBadge>.unmodifiable(
      _readList(json['badges'], 'Catalog.badges').map(
        (Object? e0) =>
            CatalogBadge.fromJson(_readObject(e0, 'Catalog.badges')),
      ),
    ),
  );

  /// Kataloğun bütününün sürümü; her değişiklikte artar. `ETag` ile aynıdır.
  final int catalogVersion;

  /// Bütün ilgi alanları (emekliler dahil), `position` sırasıyla.
  final List<CatalogInterest> interests;

  /// Aktif türlerin güncel sürümleri, listeleme sırasıyla.
  final List<CatalogEventType> eventTypes;

  /// Ders ve konu etiketleri (emekliler dahil), `position` sırasıyla; istemci `parent_key` ile gruplar.
  final List<CatalogStudyTag> studyTags;

  /// Rozet tanımları (emekliler dahil), `position` sırasıyla.
  final List<CatalogBadge> badges;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'catalog_version': catalogVersion,
    'interests': <Object?>[for (final e0 in interests) e0.toJson()],
    'event_types': <Object?>[for (final e0 in eventTypes) e0.toJson()],
    'study_tags': <Object?>[for (final e0 in studyTags) e0.toJson()],
    'badges': <Object?>[for (final e0 in badges) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Catalog &&
          catalogVersion == other.catalogVersion &&
          _deepEquals(interests, other.interests) &&
          _deepEquals(eventTypes, other.eventTypes) &&
          _deepEquals(studyTags, other.studyTags) &&
          _deepEquals(badges, other.badges);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    catalogVersion,
    _deepHash(interests),
    _deepHash(eventTypes),
    _deepHash(studyTags),
    _deepHash(badges),
  ]);
}

/// Bir rozet tanımı (#258, ADR-0039 §1). Rozet katalog gibi veridir;
/// adlar platform sahibinin içeriğidir ve düz metin gösterilir. `retired`
/// rozet artık kazanılmaz, kazanılmışlar göstermeye devam eder. Hassas
/// ölçümlerden ve katılımı hassas türlerden rozet çıkmaz. Sıralama ya da
/// "en çok rozet" listesi yoktur.
final class CatalogBadge {
  const CatalogBadge({
    required this.key,
    required this.scope,
    required this.position,
    required this.labels,
    required this.icon,
    required this.status,
    required this.rule,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogBadge.fromJson(Map<String, Object?> json) => CatalogBadge(
    key: _readString(json['key'], 'CatalogBadge.key'),
    scope: CatalogBadgeScope.fromWire(
      _readString(json['scope'], 'CatalogBadge.scope'),
    ),
    position: _readInt(json['position'], 'CatalogBadge.position'),
    labels: Map<String, String>.unmodifiable(
      _readObject(json['labels'], 'CatalogBadge.labels').map(
        (String k0, Object? e0) =>
            MapEntry(k0, _readString(e0, 'CatalogBadge.labels')),
      ),
    ),
    icon: _readString(json['icon'], 'CatalogBadge.icon'),
    status: CatalogStatus.fromWire(
      _readString(json['status'], 'CatalogBadge.status'),
    ),
    rule: CatalogBadgeRule.fromJson(
      _readObject(json['rule'], 'CatalogBadge.rule'),
    ),
  );

  /// Değişmez anahtar: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// `user` kişisel rozet (kilometre taşı ya da şampiyonluk), `tayfa`
  /// tayfa rozeti. Tanınmayan değer `unknown`.
  final CatalogBadgeScope scope;

  /// Listeleme sırası (küçükten büyüğe).
  final int position;

  final Map<String, String> labels;

  /// İstemcinin sabit ikon setinden bir anahtar.
  final String icon;

  final CatalogStatus status;

  final CatalogBadgeRule rule;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'scope': scope.wire,
    'position': position,
    'labels': <String, Object?>{
      for (final e0 in labels.entries) e0.key: e0.value,
    },
    'icon': icon,
    'status': status.wire,
    'rule': rule.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogBadge &&
          key == other.key &&
          scope == other.scope &&
          position == other.position &&
          _deepEquals(labels, other.labels) &&
          icon == other.icon &&
          status == other.status &&
          rule == other.rule;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    scope,
    position,
    _deepHash(labels),
    icon,
    status,
    rule,
  ]);
}

/// Rozetin kazanılma kuralı; istemci rozeti açıklamak için kullanır.
/// `threshold` bir metriğin toplamı `value` değerine ulaştı (`metric`,
/// `value`, `period` yalnızca bunda vardır); `first` bir türde
/// (`event_type`) ya da genel ilk katılım; `champion` bir etkinliğin
/// kutlamasında kişi ya da takımı kazanan ilan edildi (`event_type`
/// varsa yalnızca o türde). `first` ve `champion` yalnızca kişiseldir.
/// Tanınmayan `kind` için istemci rozeti açıklamasız gösterir.
final class CatalogBadgeRule {
  const CatalogBadgeRule({
    required this.kind,
    this.metric,
    this.value,
    this.period,
    this.eventType,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogBadgeRule.fromJson(Map<String, Object?> json) =>
      CatalogBadgeRule(
        kind: CatalogBadgeRuleKind.fromWire(
          _readString(json['kind'], 'CatalogBadgeRule.kind'),
        ),
        metric: switch (json['metric']) {
          null => null,
          final Object v => _readString(v, 'CatalogBadgeRule.metric'),
        },
        value: switch (json['value']) {
          null => null,
          final Object v => _readDouble(v, 'CatalogBadgeRule.value'),
        },
        period: switch (json['period']) {
          null => null,
          final Object v => CatalogBadgeRulePeriod.fromWire(
            _readString(v, 'CatalogBadgeRule.period'),
          ),
        },
        eventType: switch (json['event_type']) {
          null => null,
          final Object v => _readString(v, 'CatalogBadgeRule.event_type'),
        },
      );

  final CatalogBadgeRuleKind kind;

  /// Ortak metrik (`events`, `attended`, `participants`, `duration`)
  /// ya da `<tür anahtarı>.<anahtar>` (türün ortak metriği ya da bir
  /// ölçüm veya günlük bileşeni).
  final String? metric;

  /// Eşik, metriğin biriminde (süre dakika).
  final double? value;

  /// `year` rozet her takvim yılı ayrı kazanılır.
  final CatalogBadgeRulePeriod? period;

  /// Kuralın türü; yoksa her tür.
  final String? eventType;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    if (metric case final value?) 'metric': value,
    if (value case final value?) 'value': value,
    if (period case final value?) 'period': value.wire,
    if (eventType case final value?) 'event_type': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogBadgeRule &&
          kind == other.kind &&
          metric == other.metric &&
          value == other.value &&
          period == other.period &&
          eventType == other.eventType;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[kind, metric, value, period, eventType]);
}

enum CatalogBadgeRuleKind {
  threshold('threshold'),
  first('first'),
  champion('champion'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const CatalogBadgeRuleKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('CatalogBadgeRuleKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static CatalogBadgeRuleKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `year` rozet her takvim yılı ayrı kazanılır.
enum CatalogBadgeRulePeriod {
  allTime('all_time'),
  year('year'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const CatalogBadgeRulePeriod(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('CatalogBadgeRulePeriod.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static CatalogBadgeRulePeriod fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `user` kişisel rozet (kilometre taşı ya da şampiyonluk), `tayfa`
/// tayfa rozeti. Tanınmayan değer `unknown`.
enum CatalogBadgeScope {
  user('user'),
  tayfa('tayfa'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const CatalogBadgeScope(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('CatalogBadgeScope.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static CatalogBadgeScope fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Bir bileşen (ADR-0025 §4, ADR-0037 §3). `kind` kapalı listedir ve
/// kodla büyür; istemci tanımadığı bir `kind` görürse o bölümde
/// "uygulamayı güncelle" gösterir, etkinliğin geri kalanı çalışır
/// (ADR-0025 §9). Katılım, kontenjan, check-in ve albüm her etkinliğin
/// temelidir; bileşen değildir.
///
/// `params` bileşene göre değişir; bilinmeyen parametre yok sayılır.
/// "seçimli" işaretli parametre, değer yerine organizatöre bırakılan bir
/// liste olabilir: `{"organizer_choice": ["elimination", "league",
/// "swiss"], "default": "swiss"}` (ADR-0037 §2).
///
/// | `kind` | `params` |
/// |--------|----------|
/// | `route` | — |
/// | `meeting_point` | — |
/// | `schedule` | `max_items` (1–100) |
/// | `checklist` | `label` (`gear`, `task`, `section`, `duty`, `item`), `assignment`, `quantity` (boolean) |
/// | `roll_call` | `alarm` (boolean), `return_grace_minutes` (1–1440) |
/// | `vehicles` | `plate`, `seats` (boolean) |
/// | `teams` | `mode` (`random`, `balanced`, `manual`; seçimli), `team_size` (1–50), `team_count` (2–50) |
/// | `draw` | — |
/// | `bracket` | `format` (`elimination`, `league`, `swiss`; seçimli), `best_of` (1, 3, 5; seçimli) |
/// | `scoreboard` | `side` (`player`, `team`), `tables` (boolean), `presets` (ön ayar anahtarları), `rounds` (`round`, `single`, `first_to`; seçimli), `target` (1–100000), `winner` (`high`, `low`, `first`; seçimli), `result` (`points`, `wdl`), `best_of` (1, 3, 5; seçimli), `guests` (boolean) |
/// | `ranking` | `source` (kişisel bir ölçümün `key`'i) ya da `metric` (`duration`, `rank`); biri zorunlu, ikisi birlikte olmaz; `direction` (`asc`, `desc`) |
/// | `vote` | `source` (`free`, `participants`, `vehicles`, `album`, `route_stops`; zorunlu) |
/// | `celebration` | `source` (bir `scoreboard`, `bracket`, `ranking` ya da `vote` bileşeninin `key`'i) |
/// | `measure` | `unit`, `scope` (`personal`, `total`), `entered_by` (`self`, `organizer`) zorunlu; `min`, `max`, `decimals` (0–3), `showcase`, `sensitive` (boolean), `prefill_from` (bir alanın `key`'i) |
/// | `goal` | `measure` (bir ölçümün `key`'i; zorunlu), `default_target` |
/// | `log` | `fields` (`CatalogField` listesi, 1–8; zorunlu), `location` (boolean), `location_default` (`self`, `participants`, `tayfa`), `stat` (en fazla 3: `count`, `distinct:<alan>`, `sum:<alan>`), `max_entries` (1–500) |
/// | `questions` | `anonymous` (boolean) |
/// | `timer` | `mode` (`countdown`, `stopwatch`, `chess_clock`; seçimli), `presets` (saniye, en fazla 6) |
/// | `pool_link` | `max_links` (1–50) |
///
/// Birimler (`unit`, kapalı liste; adları çeviri dosyasında): `kg`,
/// `piece`, `bag`, `km`, `m`, `altitude_m`, `page`, `minute`, `hour`,
/// `unit`, `goal`, `point`, `night`, `nm`, `box`, `section`, `net`.
/// Para birimi yoktur; hiçbir bileşende para, bahis ya da ödül
/// parametresi yoktur.
final class CatalogComponent {
  const CatalogComponent({
    required this.kind,
    this.key,
    this.labels,
    this.optional,
    this.params,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogComponent.fromJson(Map<String, Object?> json) =>
      CatalogComponent(
        kind: _readString(json['kind'], 'CatalogComponent.kind'),
        key: switch (json['key']) {
          null => null,
          final Object v => _readString(v, 'CatalogComponent.key'),
        },
        labels: switch (json['labels']) {
          null => null,
          final Object v => Map<String, String>.unmodifiable(
            _readObject(v, 'CatalogComponent.labels').map(
              (String k0, Object? e0) =>
                  MapEntry(k0, _readString(e0, 'CatalogComponent.labels')),
            ),
          ),
        },
        optional: switch (json['optional']) {
          null => null,
          final Object v => CatalogComponentOptional.fromJson(
            _readObject(v, 'CatalogComponent.optional'),
          ),
        },
        params: switch (json['params']) {
          null => null,
          final Object v => _readJsonObject(v, 'CatalogComponent.params'),
        },
      );

  /// Bileşen türü (yukarıdaki tablo).
  final String kind;

  /// Bileşenin tür içindeki anahtarı; yoksa `kind` ile aynıdır. Aynı
  /// `kind` bir türde birden fazla kez kullanılıyorsa (iki ölçüm) her
  /// biri kendi anahtarını taşır. `measure` ve `log` için zorunludur.
  final String? key;

  final Map<String, String>? labels;

  final CatalogComponentOptional? optional;

  /// Bileşenin parametreleri (yukarıdaki tablo); bileşene göre değişen serbest nesne.
  final Map<String, Object?>? params;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    if (key case final value?) 'key': value,
    if (labels case final value?)
      'labels': <String, Object?>{
        for (final e0 in value.entries) e0.key: e0.value,
      },
    if (optional case final value?) 'optional': value.toJson(),
    if (params case final value?) 'params': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogComponent &&
          kind == other.kind &&
          key == other.key &&
          _deepEquals(labels, other.labels) &&
          optional == other.optional &&
          _deepEquals(params, other.params);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    kind,
    key,
    _deepHash(labels),
    optional,
    _deepHash(params),
  ]);
}

/// Bileşen isteğe bağlıdır; organizatör etkinliği kurarken açıp kapatır (ADR-0037 §2).
final class CatalogComponentOptional {
  const CatalogComponentOptional({required this.default_});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogComponentOptional.fromJson(Map<String, Object?> json) =>
      CatalogComponentOptional(
        default_: _readBool(
          json['default'],
          'CatalogComponentOptional.default',
        ),
      );

  /// Varsayılan olarak açık mı.
  final bool default_;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'default': default_};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogComponentOptional && default_ == other.default_;

  @override
  int get hashCode => Object.hashAll(<Object?>[default_]);
}

/// Tür tanımı (ADR-0025 §3, ADR-0037 §2). Tamamen bildirimseldir:
/// çalıştırılabilir kural, ifade, şablon, HTML ya da URL içermez. Sunucu
/// tanımı kapalı bir şemaya karşı doğrular (bilinmeyen anahtar
/// reddedilir, en fazla 16 KiB); istemci de yalnızca bildiği anahtarları
/// yorumlar. Üç anahtar da isteğe bağlıdır: boş nesne, alanı ve
/// bileşeni olmayan türdür ("Genel").
final class CatalogDefinition {
  const CatalogDefinition({this.fields, this.components, this.flags});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogDefinition.fromJson(Map<String, Object?> json) =>
      CatalogDefinition(
        fields: switch (json['fields']) {
          null => null,
          final Object v => List<CatalogField>.unmodifiable(
            _readList(v, 'CatalogDefinition.fields').map(
              (Object? e0) => CatalogField.fromJson(
                _readObject(e0, 'CatalogDefinition.fields'),
              ),
            ),
          ),
        },
        components: switch (json['components']) {
          null => null,
          final Object v => List<CatalogComponent>.unmodifiable(
            _readList(v, 'CatalogDefinition.components').map(
              (Object? e0) => CatalogComponent.fromJson(
                _readObject(e0, 'CatalogDefinition.components'),
              ),
            ),
          ),
        },
        flags: switch (json['flags']) {
          null => null,
          final Object v => CatalogTypeFlags.fromJson(
            _readObject(v, 'CatalogDefinition.flags'),
          ),
        },
      );

  /// Etkinliğin türe özel alanları (en fazla 20). Değerleri etkinliğin `fields` nesnesindedir.
  ///
  /// Kısıtlar: maxItems: 20.
  final List<CatalogField>? fields;

  /// Etkinliğin bileşenleri, gösterim sırasıyla (en fazla 20).
  ///
  /// Kısıtlar: maxItems: 20.
  final List<CatalogComponent>? components;

  final CatalogTypeFlags? flags;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (fields case final value?)
      'fields': <Object?>[for (final e0 in value) e0.toJson()],
    if (components case final value?)
      'components': <Object?>[for (final e0 in value) e0.toJson()],
    if (flags case final value?) 'flags': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogDefinition &&
          _deepEquals(fields, other.fields) &&
          _deepEquals(components, other.components) &&
          flags == other.flags;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(fields),
    _deepHash(components),
    flags,
  ]);
}

/// Bir etkinlik türünün bir sürümü.
final class CatalogEventType {
  const CatalogEventType({
    required this.key,
    required this.interestKeys,
    required this.labels,
    required this.icon,
    required this.modes,
    required this.status,
    required this.version,
    required this.definition,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogEventType.fromJson(Map<String, Object?> json) =>
      CatalogEventType(
        key: _readString(json['key'], 'CatalogEventType.key'),
        interestKeys: List<String>.unmodifiable(
          _readList(
            json['interest_keys'],
            'CatalogEventType.interest_keys',
          ).map(
            (Object? e0) => _readString(e0, 'CatalogEventType.interest_keys'),
          ),
        ),
        labels: Map<String, String>.unmodifiable(
          _readObject(json['labels'], 'CatalogEventType.labels').map(
            (String k0, Object? e0) =>
                MapEntry(k0, _readString(e0, 'CatalogEventType.labels')),
          ),
        ),
        icon: _readString(json['icon'], 'CatalogEventType.icon'),
        modes: List<EventMode>.unmodifiable(
          _readList(json['modes'], 'CatalogEventType.modes').map(
            (Object? e0) =>
                EventMode.fromWire(_readString(e0, 'CatalogEventType.modes')),
          ),
        ),
        status: CatalogStatus.fromWire(
          _readString(json['status'], 'CatalogEventType.status'),
        ),
        version: _readInt(json['version'], 'CatalogEventType.version'),
        definition: CatalogDefinition.fromJson(
          _readObject(json['definition'], 'CatalogEventType.definition'),
        ),
      );

  /// Değişmez anahtar: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// 1–3 ilgi alanı; ilki ana ilgi alanıdır. Tür hepsinde listelenir.
  ///
  /// Kısıtlar: minItems: 1; maxItems: 3.
  final List<String> interestKeys;

  final Map<String, String> labels;

  /// İstemcinin sabit ikon setinden bir anahtar.
  final String icon;

  /// Bu türde etkinliğin alabileceği modlar.
  ///
  /// Kısıtlar: minItems: 1; maxItems: 2.
  final List<EventMode> modes;

  final CatalogStatus status;

  /// Türün her değişikliğinde artar.
  ///
  /// Kısıtlar: minimum: 1.
  final int version;

  final CatalogDefinition definition;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'interest_keys': <Object?>[for (final e0 in interestKeys) e0],
    'labels': <String, Object?>{
      for (final e0 in labels.entries) e0.key: e0.value,
    },
    'icon': icon,
    'modes': <Object?>[for (final e0 in modes) e0.wire],
    'status': status.wire,
    'version': version,
    'definition': definition.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogEventType &&
          key == other.key &&
          _deepEquals(interestKeys, other.interestKeys) &&
          _deepEquals(labels, other.labels) &&
          icon == other.icon &&
          _deepEquals(modes, other.modes) &&
          status == other.status &&
          version == other.version &&
          definition == other.definition;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    _deepHash(interestKeys),
    _deepHash(labels),
    icon,
    _deepHash(modes),
    status,
    version,
    definition,
  ]);
}

/// Bir alan: türün alanı ya da `log` bileşeninin kayıt alanı. `kind`
/// kapalı listedir; para, URL, dosya, konum ve kişi alanı yoktur.
/// İstemci tanımadığı bir `kind` görürse alanı göstermez ve o türde
/// etkinlik oluşturmayı kapatır (ADR-0025 §9).
///
/// | `kind` | Değer (JSON) | Ek anahtarlar |
/// |--------|--------------|---------------|
/// | `text` | metin, tek satır | `max_length` (≤ 120), `vocabulary` |
/// | `long_text` | metin, çok satırlı | `max_length` (≤ 1000) |
/// | `integer` | tam sayı | `min`, `max`, `unit` |
/// | `decimal` | sayı | `min`, `max`, `decimals` (1–3), `unit` |
/// | `choice` | `options`'tan biri | `options`, `option_labels` |
/// | `multi_choice` | `options`'tan liste | `options`, `option_labels`, `max_selected` |
/// | `boolean` | `true` / `false` | — |
/// | `date` | `YYYY-MM-DD` | — |
/// | `duration` | dakika, tam sayı | `min`, `max` |
final class CatalogField {
  const CatalogField({
    required this.key,
    required this.kind,
    this.required_,
    required this.labels,
    this.maxLength,
    this.min,
    this.max,
    this.decimals,
    this.unit,
    this.options,
    this.optionLabels,
    this.maxSelected,
    this.vocabulary,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogField.fromJson(Map<String, Object?> json) => CatalogField(
    key: _readString(json['key'], 'CatalogField.key'),
    kind: _readString(json['kind'], 'CatalogField.kind'),
    required_: switch (json['required']) {
      null => null,
      final Object v => _readBool(v, 'CatalogField.required'),
    },
    labels: Map<String, String>.unmodifiable(
      _readObject(json['labels'], 'CatalogField.labels').map(
        (String k0, Object? e0) =>
            MapEntry(k0, _readString(e0, 'CatalogField.labels')),
      ),
    ),
    maxLength: switch (json['max_length']) {
      null => null,
      final Object v => _readInt(v, 'CatalogField.max_length'),
    },
    min: switch (json['min']) {
      null => null,
      final Object v => _readDouble(v, 'CatalogField.min'),
    },
    max: switch (json['max']) {
      null => null,
      final Object v => _readDouble(v, 'CatalogField.max'),
    },
    decimals: switch (json['decimals']) {
      null => null,
      final Object v => _readInt(v, 'CatalogField.decimals'),
    },
    unit: switch (json['unit']) {
      null => null,
      final Object v => _readString(v, 'CatalogField.unit'),
    },
    options: switch (json['options']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(
          v,
          'CatalogField.options',
        ).map((Object? e0) => _readString(e0, 'CatalogField.options')),
      ),
    },
    optionLabels: switch (json['option_labels']) {
      null => null,
      final Object v => Map<String, Map<String, String>>.unmodifiable(
        _readObject(v, 'CatalogField.option_labels').map(
          (String k0, Object? e0) => MapEntry(
            k0,
            Map<String, String>.unmodifiable(
              _readObject(e0, 'CatalogField.option_labels').map(
                (String k1, Object? e1) =>
                    MapEntry(k1, _readString(e1, 'CatalogField.option_labels')),
              ),
            ),
          ),
        ),
      ),
    },
    maxSelected: switch (json['max_selected']) {
      null => null,
      final Object v => _readInt(v, 'CatalogField.max_selected'),
    },
    vocabulary: switch (json['vocabulary']) {
      null => null,
      final Object v => CatalogVocabulary.fromJson(
        _readObject(v, 'CatalogField.vocabulary'),
      ),
    },
  );

  /// Tür içinde tekil: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// `text`, `long_text`, `integer`, `decimal`, `choice`, `multi_choice`, `boolean`, `date`, `duration`.
  final String kind;

  /// Etkinlik oluştururken zorunlu mu; yoksa `false`.
  final bool? required_;

  final Map<String, String> labels;

  /// `text`, `long_text`: en fazla karakter.
  final int? maxLength;

  /// `integer`, `decimal`, `duration`: en küçük değer; yoksa 0 (`duration`: 1).
  final double? min;

  /// `integer`, `decimal`, `duration`: en büyük değer.
  final double? max;

  /// `decimal`: ondalık basamak sayısı; yoksa 2.
  final int? decimals;

  /// `integer`, `decimal`: isteğe bağlı birim (birim listesi `CatalogComponent`'te); adı çeviri dosyasındadır.
  final String? unit;

  /// `choice`, `multi_choice`: seçenek anahtarları (`^[a-z0-9][a-z0-9_]{0,39}$`), en fazla 50.
  ///
  /// Kısıtlar: maxItems: 50.
  final List<String>? options;

  /// Seçenek anahtarı → adlar (dil → metin). Adı olmayan seçenek olduğu gibi gösterilir (`"1"` … `"5"`).
  final Map<String, Map<String, String>>? optionLabels;

  /// `multi_choice`: en fazla seçim; yoksa seçenek sayısı.
  final int? maxSelected;

  final CatalogVocabulary? vocabulary;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'kind': kind,
    if (required_ case final value?) 'required': value,
    'labels': <String, Object?>{
      for (final e0 in labels.entries) e0.key: e0.value,
    },
    if (maxLength case final value?) 'max_length': value,
    if (min case final value?) 'min': value,
    if (max case final value?) 'max': value,
    if (decimals case final value?) 'decimals': value,
    if (unit case final value?) 'unit': value,
    if (options case final value?)
      'options': <Object?>[for (final e0 in value) e0],
    if (optionLabels case final value?)
      'option_labels': <String, Object?>{
        for (final e0 in value.entries)
          e0.key: <String, Object?>{
            for (final e1 in e0.value.entries) e1.key: e1.value,
          },
      },
    if (maxSelected case final value?) 'max_selected': value,
    if (vocabulary case final value?) 'vocabulary': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogField &&
          key == other.key &&
          kind == other.kind &&
          required_ == other.required_ &&
          _deepEquals(labels, other.labels) &&
          maxLength == other.maxLength &&
          min == other.min &&
          max == other.max &&
          decimals == other.decimals &&
          unit == other.unit &&
          _deepEquals(options, other.options) &&
          _deepEquals(optionLabels, other.optionLabels) &&
          maxSelected == other.maxSelected &&
          vocabulary == other.vocabulary;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    kind,
    required_,
    _deepHash(labels),
    maxLength,
    min,
    max,
    decimals,
    unit,
    _deepHash(options),
    _deepHash(optionLabels),
    maxSelected,
    vocabulary,
  ]);
}

final class CatalogInterest {
  const CatalogInterest({
    required this.key,
    required this.position,
    required this.labels,
    required this.icon,
    required this.status,
    required this.defaultWidgets,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogInterest.fromJson(Map<String, Object?> json) =>
      CatalogInterest(
        key: _readString(json['key'], 'CatalogInterest.key'),
        position: _readInt(json['position'], 'CatalogInterest.position'),
        labels: Map<String, String>.unmodifiable(
          _readObject(json['labels'], 'CatalogInterest.labels').map(
            (String k0, Object? e0) =>
                MapEntry(k0, _readString(e0, 'CatalogInterest.labels')),
          ),
        ),
        icon: _readString(json['icon'], 'CatalogInterest.icon'),
        status: CatalogStatus.fromWire(
          _readString(json['status'], 'CatalogInterest.status'),
        ),
        defaultWidgets: List<String>.unmodifiable(
          _readList(
            json['default_widgets'],
            'CatalogInterest.default_widgets',
          ).map(
            (Object? e0) => _readString(e0, 'CatalogInterest.default_widgets'),
          ),
        ),
      );

  /// Değişmez anahtar: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// Listeleme sırası (küçükten büyüğe).
  final int position;

  final Map<String, String> labels;

  /// İstemcinin sabit ikon setinden bir anahtar.
  final String icon;

  final CatalogStatus status;

  /// Bu ilgi alanını seçen tayfada varsayılan açık gelen ana sayfa bileşenleri (ADR-0027).
  final List<String> defaultWidgets;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'position': position,
    'labels': <String, Object?>{
      for (final e0 in labels.entries) e0.key: e0.value,
    },
    'icon': icon,
    'status': status.wire,
    'default_widgets': <Object?>[for (final e0 in defaultWidgets) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogInterest &&
          key == other.key &&
          position == other.position &&
          _deepEquals(labels, other.labels) &&
          icon == other.icon &&
          status == other.status &&
          _deepEquals(defaultWidgets, other.defaultWidgets);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    position,
    _deepHash(labels),
    icon,
    status,
    _deepHash(defaultWidgets),
  ]);
}

/// `retired`: yeni etkinlikte, tayfada ya da profilde seçilemez; eski
/// kayıtlar göstermeye devam eder. Katalog kaydı hiç silinmez.
enum CatalogStatus {
  active('active'),
  retired('retired'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const CatalogStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('CatalogStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static CatalogStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Eğitim modüllerinin (materyal kütüphanesi, soru havuzu) içeriği
/// etiketlediği ders ve konu listesinin bir kaydı (#259, ADR-0040 §5):
/// sınav/düzey → ders → konu, en fazla üç seviye. Böyle içerikte ders
/// (ikinci seviye) zorunlu, konu (üçüncü seviye, o dersin altında)
/// isteğe bağlıdır. Her düzeyin ve dersin altında anahtarı
/// `<üst anahtar>_other` olan bir "Diğer" kaydı vardır. `retired` kayıt
/// (ya da emekli bir kaydın altındaki kayıt) yeni içerikte seçilemez,
/// eski içerik göstermeye devam eder. Adlar platform sahibinin
/// içeriğidir ve düz metin gösterilir.
final class CatalogStudyTag {
  const CatalogStudyTag({
    required this.key,
    this.parentKey,
    required this.position,
    required this.labels,
    required this.status,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogStudyTag.fromJson(Map<String, Object?> json) =>
      CatalogStudyTag(
        key: _readString(json['key'], 'CatalogStudyTag.key'),
        parentKey: switch (json['parent_key']) {
          null => null,
          final Object v => _readString(v, 'CatalogStudyTag.parent_key'),
        },
        position: _readInt(json['position'], 'CatalogStudyTag.position'),
        labels: Map<String, String>.unmodifiable(
          _readObject(json['labels'], 'CatalogStudyTag.labels').map(
            (String k0, Object? e0) =>
                MapEntry(k0, _readString(e0, 'CatalogStudyTag.labels')),
          ),
        ),
        status: CatalogStatus.fromWire(
          _readString(json['status'], 'CatalogStudyTag.status'),
        ),
      );

  /// Değişmez, bütün listede tekil anahtar: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// Üst kaydın anahtarı; düzeyde yoktur. Değişmez.
  final String? parentKey;

  /// Aynı üst kaydın altındaki sıra (küçükten büyüğe).
  final int position;

  final Map<String, String> labels;

  final CatalogStatus status;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    if (parentKey case final value?) 'parent_key': value,
    'position': position,
    'labels': <String, Object?>{
      for (final e0 in labels.entries) e0.key: e0.value,
    },
    'status': status.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogStudyTag &&
          key == other.key &&
          parentKey == other.parentKey &&
          position == other.position &&
          _deepEquals(labels, other.labels) &&
          status == other.status;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    parentKey,
    position,
    _deepHash(labels),
    status,
  ]);
}

/// Tür bayrakları (ADR-0037 §1). Olmayan bayrak `false`tur.
final class CatalogTypeFlags {
  const CatalogTypeFlags({
    this.sensitiveAttendance,
    this.albumNotice,
    this.personalScopeForbidden,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogTypeFlags.fromJson(Map<String, Object?> json) =>
      CatalogTypeFlags(
        sensitiveAttendance: switch (json['sensitive_attendance']) {
          null => null,
          final Object v => _readBool(
            v,
            'CatalogTypeFlags.sensitive_attendance',
          ),
        },
        albumNotice: switch (json['album_notice']) {
          null => null,
          final Object v => _readBool(v, 'CatalogTypeFlags.album_notice'),
        },
        personalScopeForbidden: switch (json['personal_scope_forbidden']) {
          null => null,
          final Object v => _readBool(
            v,
            'CatalogTypeFlags.personal_scope_forbidden',
          ),
        },
      );

  /// Katılım kişisel geçmişe, istatistiğe ve arkadaşlık puanına girmez; katılımcı listesini yalnızca organizatör, moderatör ve yönetici görür (diğerleri `attendees-hidden`).
  final bool? sensitiveAttendance;

  /// Albüme yüklemeden önce izin onayı istenir; onaysız istek `album-consent-required` alır (`consent_ack`).
  final bool? albumNotice;

  /// Bu türde kişi bazında değer tutulmaz (kişisel ölçüm ve günlük tanımlanamaz).
  final bool? personalScopeForbidden;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (sensitiveAttendance case final value?) 'sensitive_attendance': value,
    if (albumNotice case final value?) 'album_notice': value,
    if (personalScopeForbidden case final value?)
      'personal_scope_forbidden': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogTypeFlags &&
          sensitiveAttendance == other.sensitiveAttendance &&
          albumNotice == other.albumNotice &&
          personalScopeForbidden == other.personalScopeForbidden;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    sensitiveAttendance,
    albumNotice,
    personalScopeForbidden,
  ]);
}

/// `text` alanı tayfa sözlüğüne bağlıdır (ADR-0037 §4): serbest metin +
/// tayfanın önceki değerlerinden otomatik tamamlama.
final class CatalogVocabulary {
  const CatalogVocabulary({required this.namespace});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CatalogVocabulary.fromJson(Map<String, Object?> json) =>
      CatalogVocabulary(
        namespace: _readString(
          json['namespace'],
          'CatalogVocabulary.namespace',
        ),
      );

  /// Sözlüğün ad alanı; türler paylaşabilir.
  final String namespace;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'namespace': namespace};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogVocabulary && namespace == other.namespace;

  @override
  int get hashCode => Object.hashAll(<Object?>[namespace]);
}

/// Bir kazanan; tam biri bulunur. Kişi (`user_id`), takım (`team_id`;
/// `team_name` adsız takımda yoktur, `team_position` 1'den) ya da
/// misafir oyuncu (`guest_id`; `guest_nickname` silinmişse yoktur).
final class ChampionWinner {
  const ChampionWinner({
    this.userId,
    this.teamId,
    this.teamName,
    this.teamPosition,
    this.guestId,
    this.guestNickname,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChampionWinner.fromJson(Map<String, Object?> json) => ChampionWinner(
    userId: switch (json['user_id']) {
      null => null,
      final Object v => _readString(v, 'ChampionWinner.user_id'),
    },
    teamId: switch (json['team_id']) {
      null => null,
      final Object v => _readString(v, 'ChampionWinner.team_id'),
    },
    teamName: switch (json['team_name']) {
      null => null,
      final Object v => _readString(v, 'ChampionWinner.team_name'),
    },
    teamPosition: switch (json['team_position']) {
      null => null,
      final Object v => _readInt(v, 'ChampionWinner.team_position'),
    },
    guestId: switch (json['guest_id']) {
      null => null,
      final Object v => _readString(v, 'ChampionWinner.guest_id'),
    },
    guestNickname: switch (json['guest_nickname']) {
      null => null,
      final Object v => _readString(v, 'ChampionWinner.guest_nickname'),
    },
  );

  final String? userId;

  final String? teamId;

  final String? teamName;

  final int? teamPosition;

  final String? guestId;

  final String? guestNickname;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (userId case final value?) 'user_id': value,
    if (teamId case final value?) 'team_id': value,
    if (teamName case final value?) 'team_name': value,
    if (teamPosition case final value?) 'team_position': value,
    if (guestId case final value?) 'guest_id': value,
    if (guestNickname case final value?) 'guest_nickname': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChampionWinner &&
          userId == other.userId &&
          teamId == other.teamId &&
          teamName == other.teamName &&
          teamPosition == other.teamPosition &&
          guestId == other.guestId &&
          guestNickname == other.guestNickname;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    teamId,
    teamName,
    teamPosition,
    guestId,
    guestNickname,
  ]);
}

/// Şampiyonlar: bu türlerdeki etkinliklerin ilan edilmiş kazananları
/// (boş liste her tür) ve dönem (`last_30_days` ya da `this_year`).
/// Ayarsız kart bu yılın bütün türlerini gösterir.
final class ChampionsWidgetConfig {
  const ChampionsWidgetConfig({required this.eventTypes, required this.period});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChampionsWidgetConfig.fromJson(Map<String, Object?> json) =>
      ChampionsWidgetConfig(
        eventTypes: List<String>.unmodifiable(
          _readList(
            json['event_types'],
            'ChampionsWidgetConfig.event_types',
          ).map(
            (Object? e0) =>
                _readString(e0, 'ChampionsWidgetConfig.event_types'),
          ),
        ),
        period: HomeWidgetPeriod.fromWire(
          _readString(json['period'], 'ChampionsWidgetConfig.period'),
        ),
      );

  /// Kısıtlar: maxItems: 10.
  final List<String> eventTypes;

  final HomeWidgetPeriod period;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'event_types': <Object?>[for (final e0 in eventTypes) e0],
    'period': period.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChampionsWidgetConfig &&
          _deepEquals(eventTypes, other.eventTypes) &&
          period == other.period;

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(eventTypes), period]);
}

final class ChampionsWidgetData {
  const ChampionsWidgetData({required this.period, required this.champions});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChampionsWidgetData.fromJson(Map<String, Object?> json) =>
      ChampionsWidgetData(
        period: HomeWidgetPeriod.fromWire(
          _readString(json['period'], 'ChampionsWidgetData.period'),
        ),
        champions: List<HomeChampion>.unmodifiable(
          _readList(json['champions'], 'ChampionsWidgetData.champions').map(
            (Object? e0) => HomeChampion.fromJson(
              _readObject(e0, 'ChampionsWidgetData.champions'),
            ),
          ),
        ),
      );

  final HomeWidgetPeriod period;

  /// Kısıtlar: maxItems: 10.
  final List<HomeChampion> champions;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'period': period.wire,
    'champions': <Object?>[for (final e0 in champions) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChampionsWidgetData &&
          period == other.period &&
          _deepEquals(champions, other.champions);

  @override
  int get hashCode => Object.hashAll(<Object?>[period, _deepHash(champions)]);
}

final class Channel {
  const Channel({
    required this.id,
    required this.tayfaId,
    required this.name,
    required this.visibility,
    required this.slowModeSeconds,
    this.creatorUserId,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount,
    this.lastReadMessageId,
    this.eventId,
    this.eventTitle,
    this.memberCount,
    this.archiveAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Channel.fromJson(Map<String, Object?> json) => Channel(
    id: _readString(json['id'], 'Channel.id'),
    tayfaId: _readString(json['tayfa_id'], 'Channel.tayfa_id'),
    name: _readString(json['name'], 'Channel.name'),
    visibility: ChannelVisibility.fromWire(
      _readString(json['visibility'], 'Channel.visibility'),
    ),
    slowModeSeconds: _readInt(
      json['slow_mode_seconds'],
      'Channel.slow_mode_seconds',
    ),
    creatorUserId: switch (json['creator_user_id']) {
      null => null,
      final Object v => _readString(v, 'Channel.creator_user_id'),
    },
    archivedAt: switch (json['archived_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Channel.archived_at'),
    },
    createdAt: _readDateTime(json['created_at'], 'Channel.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Channel.updated_at'),
    unreadCount: switch (json['unread_count']) {
      null => null,
      final Object v => _readInt(v, 'Channel.unread_count'),
    },
    lastReadMessageId: switch (json['last_read_message_id']) {
      null => null,
      final Object v => _readString(v, 'Channel.last_read_message_id'),
    },
    eventId: switch (json['event_id']) {
      null => null,
      final Object v => _readString(v, 'Channel.event_id'),
    },
    eventTitle: switch (json['event_title']) {
      null => null,
      final Object v => _readString(v, 'Channel.event_title'),
    },
    memberCount: switch (json['member_count']) {
      null => null,
      final Object v => _readInt(v, 'Channel.member_count'),
    },
    archiveAt: switch (json['archive_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Channel.archive_at'),
    },
  );

  final String id;

  final String tayfaId;

  final String name;

  final ChannelVisibility visibility;

  /// 0 kapalı. Yönetici ve moderatörler muaftır.
  ///
  /// Kısıtlar: minimum: 0; maximum: 3600.
  final int slowModeSeconds;

  /// Açanın hesabı silindiyse yoktur.
  final String? creatorUserId;

  /// Arşivliyse dolu (salt okunur).
  final DateTime? archivedAt;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// Yalnızca listede. 100, "99+" demektir.
  ///
  /// Kısıtlar: minimum: 0; maximum: 100.
  final int? unreadCount;

  /// Yalnızca listede; okundu işaretiniz yoksa yoktur.
  final String? lastReadMessageId;

  /// Yalnızca `event` kanalında.
  final String? eventId;

  /// Yalnızca `event` kanalında: etkinliğin başlığı, iptal edilmiş olsa
  /// da (issue #193). Etkinlik size görünmüyorsa yoktur.
  final String? eventTitle;

  /// Yalnızca `event` ve `selected` kanalında; kitlenin büyüklüğü.
  ///
  /// Kısıtlar: minimum: 0.
  final int? memberCount;

  /// Yalnızca `event` kanalında: planlanan arşiv zamanı (etkinliğin
  /// bitişi ya da iptal anı + 7 gün). İstemci kalan süreyi bundan
  /// hesaplar. Bu zaman gelince `archived_at` dolar.
  final DateTime? archiveAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    'name': name,
    'visibility': visibility.wire,
    'slow_mode_seconds': slowModeSeconds,
    if (creatorUserId case final value?) 'creator_user_id': value,
    if (archivedAt case final value?)
      'archived_at': value.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (unreadCount case final value?) 'unread_count': value,
    if (lastReadMessageId case final value?) 'last_read_message_id': value,
    if (eventId case final value?) 'event_id': value,
    if (eventTitle case final value?) 'event_title': value,
    if (memberCount case final value?) 'member_count': value,
    if (archiveAt case final value?)
      'archive_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          name == other.name &&
          visibility == other.visibility &&
          slowModeSeconds == other.slowModeSeconds &&
          creatorUserId == other.creatorUserId &&
          archivedAt == other.archivedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          unreadCount == other.unreadCount &&
          lastReadMessageId == other.lastReadMessageId &&
          eventId == other.eventId &&
          eventTitle == other.eventTitle &&
          memberCount == other.memberCount &&
          archiveAt == other.archiveAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    name,
    visibility,
    slowModeSeconds,
    creatorUserId,
    archivedAt,
    createdAt,
    updatedAt,
    unreadCount,
    lastReadMessageId,
    eventId,
    eventTitle,
    memberCount,
    archiveAt,
  ]);
}

final class ChannelCreateRequest {
  const ChannelCreateRequest({
    required this.name,
    this.visibility,
    this.slowModeSeconds,
    this.eventId,
    this.memberUserIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelCreateRequest.fromJson(Map<String, Object?> json) =>
      ChannelCreateRequest(
        name: _readString(json['name'], 'ChannelCreateRequest.name'),
        visibility: switch (json['visibility']) {
          null => null,
          final Object v => ChannelCreateRequestVisibility.fromWire(
            _readString(v, 'ChannelCreateRequest.visibility'),
          ),
        },
        slowModeSeconds: switch (json['slow_mode_seconds']) {
          null => null,
          final Object v => _readInt(
            v,
            'ChannelCreateRequest.slow_mode_seconds',
          ),
        },
        eventId: switch (json['event_id']) {
          null => null,
          final Object v => _readString(v, 'ChannelCreateRequest.event_id'),
        },
        memberUserIds: switch (json['member_user_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'ChannelCreateRequest.member_user_ids').map(
              (Object? e0) =>
                  _readString(e0, 'ChannelCreateRequest.member_user_ids'),
            ),
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String name;

  /// Kısıtlar: varsayılan (sunucu): `members`.
  final ChannelCreateRequestVisibility? visibility;

  /// Kısıtlar: minimum: 0; maximum: 3600; varsayılan (sunucu): 0.
  final int? slowModeSeconds;

  /// Yalnızca ve zorunlu olarak `event` kanalında.
  final String? eventId;

  /// Yalnızca `selected` kanalında; açan dışındaki ilk üyeler.
  ///
  /// Kısıtlar: maxItems: 100.
  final List<String>? memberUserIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (visibility case final value?) 'visibility': value.wire,
    if (slowModeSeconds case final value?) 'slow_mode_seconds': value,
    if (eventId case final value?) 'event_id': value,
    if (memberUserIds case final value?)
      'member_user_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelCreateRequest &&
          name == other.name &&
          visibility == other.visibility &&
          slowModeSeconds == other.slowModeSeconds &&
          eventId == other.eventId &&
          _deepEquals(memberUserIds, other.memberUserIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    name,
    visibility,
    slowModeSeconds,
    eventId,
    _deepHash(memberUserIds),
  ]);
}

/// Kısıtlar: varsayılan (sunucu): `members`.
enum ChannelCreateRequestVisibility {
  members('members'),
  staff('staff'),
  event('event'),
  selected('selected'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ChannelCreateRequestVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ChannelCreateRequestVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChannelCreateRequestVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class ChannelList {
  const ChannelList({required this.channels});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelList.fromJson(Map<String, Object?> json) => ChannelList(
    channels: List<Channel>.unmodifiable(
      _readList(json['channels'], 'ChannelList.channels').map(
        (Object? e0) =>
            Channel.fromJson(_readObject(e0, 'ChannelList.channels')),
      ),
    ),
  );

  final List<Channel> channels;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'channels': <Object?>[for (final e0 in channels) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelList && _deepEquals(channels, other.channels);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(channels)]);
}

final class ChannelMember {
  const ChannelMember({required this.userId, required this.roles});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMember.fromJson(Map<String, Object?> json) => ChannelMember(
    userId: _readString(json['user_id'], 'ChannelMember.user_id'),
    roles: List<ChannelMemberRolesItem>.unmodifiable(
      _readList(json['roles'], 'ChannelMember.roles').map(
        (Object? e0) => ChannelMemberRolesItem.fromWire(
          _readString(e0, 'ChannelMember.roles'),
        ),
      ),
    ),
  );

  final String userId;

  /// `organizer`: etkinliğin organizatörü (yalnızca `event`); `creator`: kanalı açan. Boş olabilir.
  final List<ChannelMemberRolesItem> roles;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'roles': <Object?>[for (final e0 in roles) e0.wire],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMember &&
          userId == other.userId &&
          _deepEquals(roles, other.roles);

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, _deepHash(roles)]);
}

final class ChannelMemberList {
  const ChannelMemberList({
    required this.userIds,
    required this.members,
    this.nextPageToken,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMemberList.fromJson(Map<String, Object?> json) =>
      ChannelMemberList(
        userIds: List<String>.unmodifiable(
          _readList(
            json['user_ids'],
            'ChannelMemberList.user_ids',
          ).map((Object? e0) => _readString(e0, 'ChannelMemberList.user_ids')),
        ),
        members: List<ChannelMember>.unmodifiable(
          _readList(json['members'], 'ChannelMemberList.members').map(
            (Object? e0) => ChannelMember.fromJson(
              _readObject(e0, 'ChannelMemberList.members'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'ChannelMemberList.next_page_token'),
        },
      );

  final List<String> userIds;

  /// `user_ids` ile aynı kişiler aynı sırada, kanaldaki rolleriyle
  /// (issue #193). Tayfa rolü burada yoktur; ad ve avatar profil
  /// ucundan gelir.
  final List<ChannelMember> members;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_ids': <Object?>[for (final e0 in userIds) e0],
    'members': <Object?>[for (final e0 in members) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMemberList &&
          _deepEquals(userIds, other.userIds) &&
          _deepEquals(members, other.members) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(userIds),
    _deepHash(members),
    nextPageToken,
  ]);
}

enum ChannelMemberRolesItem {
  organizer('organizer'),
  creator('creator'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ChannelMemberRolesItem(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ChannelMemberRolesItem.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChannelMemberRolesItem fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class ChannelMembersAddRequest {
  const ChannelMembersAddRequest({required this.userIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMembersAddRequest.fromJson(Map<String, Object?> json) =>
      ChannelMembersAddRequest(
        userIds: List<String>.unmodifiable(
          _readList(json['user_ids'], 'ChannelMembersAddRequest.user_ids').map(
            (Object? e0) =>
                _readString(e0, 'ChannelMembersAddRequest.user_ids'),
          ),
        ),
      );

  /// Kısıtlar: minItems: 1; maxItems: 100.
  final List<String> userIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_ids': <Object?>[for (final e0 in userIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMembersAddRequest && _deepEquals(userIds, other.userIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(userIds)]);
}

final class ChannelMessage {
  const ChannelMessage({
    required this.id,
    required this.channelId,
    this.authorUserId,
    required this.kind,
    this.body,
    this.photoUploadId,
    this.place,
    required this.deleted,
    this.restorable,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMessage.fromJson(Map<String, Object?> json) => ChannelMessage(
    id: _readString(json['id'], 'ChannelMessage.id'),
    channelId: _readString(json['channel_id'], 'ChannelMessage.channel_id'),
    authorUserId: switch (json['author_user_id']) {
      null => null,
      final Object v => _readString(v, 'ChannelMessage.author_user_id'),
    },
    kind: ChannelMessageKind.fromWire(
      _readString(json['kind'], 'ChannelMessage.kind'),
    ),
    body: switch (json['body']) {
      null => null,
      final Object v => _readString(v, 'ChannelMessage.body'),
    },
    photoUploadId: switch (json['photo_upload_id']) {
      null => null,
      final Object v => _readString(v, 'ChannelMessage.photo_upload_id'),
    },
    place: switch (json['place']) {
      null => null,
      final Object v => Place.fromJson(_readObject(v, 'ChannelMessage.place')),
    },
    deleted: _readBool(json['deleted'], 'ChannelMessage.deleted'),
    restorable: switch (json['restorable']) {
      null => null,
      final Object v => _readBool(v, 'ChannelMessage.restorable'),
    },
    createdAt: _readDateTime(json['created_at'], 'ChannelMessage.created_at'),
  );

  final String id;

  final String channelId;

  /// Yazarın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? authorUserId;

  final ChannelMessageKind kind;

  /// Yalnızca `text`; silinmiş mesajda yoktur.
  final String? body;

  /// Yalnızca `photo`; silinmiş mesajda yoktur. Linkler
  /// `POST /v1/media/urls` ile (yalnızca kanalın kitlesine).
  final String? photoUploadId;

  /// Yalnızca `place`; silinmiş mesajda yoktur.
  final Place? place;

  final bool deleted;

  /// Yalnızca yöneticilere; moderasyonla gizlenmiş ve hâlâ geri alınabilir.
  final bool? restorable;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'channel_id': channelId,
    if (authorUserId case final value?) 'author_user_id': value,
    'kind': kind.wire,
    if (body case final value?) 'body': value,
    if (photoUploadId case final value?) 'photo_upload_id': value,
    if (place case final value?) 'place': value.toJson(),
    'deleted': deleted,
    if (restorable case final value?) 'restorable': value,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMessage &&
          id == other.id &&
          channelId == other.channelId &&
          authorUserId == other.authorUserId &&
          kind == other.kind &&
          body == other.body &&
          photoUploadId == other.photoUploadId &&
          place == other.place &&
          deleted == other.deleted &&
          restorable == other.restorable &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    channelId,
    authorUserId,
    kind,
    body,
    photoUploadId,
    place,
    deleted,
    restorable,
    createdAt,
  ]);
}

final class ChannelMessageCreateRequest {
  const ChannelMessageCreateRequest({
    this.kind,
    this.body,
    this.photoUploadId,
    this.place,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMessageCreateRequest.fromJson(Map<String, Object?> json) =>
      ChannelMessageCreateRequest(
        kind: switch (json['kind']) {
          null => null,
          final Object v => ChannelMessageCreateRequestKind.fromWire(
            _readString(v, 'ChannelMessageCreateRequest.kind'),
          ),
        },
        body: switch (json['body']) {
          null => null,
          final Object v => _readString(v, 'ChannelMessageCreateRequest.body'),
        },
        photoUploadId: switch (json['photo_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'ChannelMessageCreateRequest.photo_upload_id',
          ),
        },
        place: switch (json['place']) {
          null => null,
          final Object v => Place.fromJson(
            _readObject(v, 'ChannelMessageCreateRequest.place'),
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'ChannelMessageCreateRequest.client_request_id',
        ),
      );

  /// Verilmezse `text`.
  final ChannelMessageCreateRequestKind? kind;

  /// Yalnızca ve zorunlu olarak `text`.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 4000.
  final String? body;

  /// Yalnızca ve zorunlu olarak `photo`; kendi hazır `chat_photo` yüklemeniz.
  final String? photoUploadId;

  /// Yalnızca ve zorunlu olarak `place`.
  final Place? place;

  /// İstemcinin ürettiği tekrar gönderim anahtarı; mesaj kimliği sunucudadır.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (kind case final value?) 'kind': value.wire,
    if (body case final value?) 'body': value,
    if (photoUploadId case final value?) 'photo_upload_id': value,
    if (place case final value?) 'place': value.toJson(),
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMessageCreateRequest &&
          kind == other.kind &&
          body == other.body &&
          photoUploadId == other.photoUploadId &&
          place == other.place &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    kind,
    body,
    photoUploadId,
    place,
    clientRequestId,
  ]);
}

/// Verilmezse `text`.
enum ChannelMessageCreateRequestKind {
  text('text'),
  photo('photo'),
  place('place'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ChannelMessageCreateRequestKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'ChannelMessageCreateRequestKind.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChannelMessageCreateRequestKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `unknown`: istemciden yeni bir sunucu değeri (#205).
enum ChannelMessageKind {
  text('text'),
  photo('photo'),
  place('place'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const ChannelMessageKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ChannelMessageKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChannelMessageKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class ChannelMessageList {
  const ChannelMessageList({required this.messages, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMessageList.fromJson(Map<String, Object?> json) =>
      ChannelMessageList(
        messages: List<ChannelMessage>.unmodifiable(
          _readList(json['messages'], 'ChannelMessageList.messages').map(
            (Object? e0) => ChannelMessage.fromJson(
              _readObject(e0, 'ChannelMessageList.messages'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(
            v,
            'ChannelMessageList.next_page_token',
          ),
        },
      );

  final List<ChannelMessage> messages;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'messages': <Object?>[for (final e0 in messages) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMessageList &&
          _deepEquals(messages, other.messages) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(messages), nextPageToken]);
}

final class ChannelReadRequest {
  const ChannelReadRequest({required this.messageId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelReadRequest.fromJson(Map<String, Object?> json) =>
      ChannelReadRequest(
        messageId: _readString(
          json['message_id'],
          'ChannelReadRequest.message_id',
        ),
      );

  final String messageId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'message_id': messageId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelReadRequest && messageId == other.messageId;

  @override
  int get hashCode => Object.hashAll(<Object?>[messageId]);
}

/// Kısıtlar: minProperties: 1.
final class ChannelUpdateRequest {
  const ChannelUpdateRequest({
    this.name,
    this.visibility,
    this.slowModeSeconds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelUpdateRequest.fromJson(Map<String, Object?> json) =>
      ChannelUpdateRequest(
        name: switch (json['name']) {
          null => null,
          final Object v => _readString(v, 'ChannelUpdateRequest.name'),
        },
        visibility: switch (json['visibility']) {
          null => null,
          final Object v => ChannelUpdateRequestVisibility.fromWire(
            _readString(v, 'ChannelUpdateRequest.visibility'),
          ),
        },
        slowModeSeconds: switch (json['slow_mode_seconds']) {
          null => null,
          final Object v => _readInt(
            v,
            'ChannelUpdateRequest.slow_mode_seconds',
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String? name;

  /// `event` ve `selected` kanalının türü değişmez (`invalid-request`).
  final ChannelUpdateRequestVisibility? visibility;

  /// Kısıtlar: minimum: 0; maximum: 3600.
  final int? slowModeSeconds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (name case final value?) 'name': value,
    if (visibility case final value?) 'visibility': value.wire,
    if (slowModeSeconds case final value?) 'slow_mode_seconds': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelUpdateRequest &&
          name == other.name &&
          visibility == other.visibility &&
          slowModeSeconds == other.slowModeSeconds;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[name, visibility, slowModeSeconds]);
}

/// `event` ve `selected` kanalının türü değişmez (`invalid-request`).
enum ChannelUpdateRequestVisibility {
  members('members'),
  staff('staff'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ChannelUpdateRequestVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ChannelUpdateRequestVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChannelUpdateRequestVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `members`: tüm etkin üyeler; `staff`: yalnızca yönetici ve
/// moderatörler; `event`: kanalı açan, etkinliğin organizatörü ve
/// etkinliğe gelenler; `selected`: kanalı açan ve seçtikleri (issue
/// #183). `event` ve `selected` sonradan başka türe, başka tür de
/// bunlara çevrilemez.
enum ChannelVisibility {
  members('members'),
  staff('staff'),
  event('event'),
  selected('selected'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const ChannelVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ChannelVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChannelVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class CheckIn {
  const CheckIn({required this.attendance, required this.method});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CheckIn.fromJson(Map<String, Object?> json) => CheckIn(
    attendance: AttendanceStatus.fromWire(
      _readString(json['attendance'], 'CheckIn.attendance'),
    ),
    method: AttendanceMethod.fromWire(
      _readString(json['method'], 'CheckIn.method'),
    ),
  );

  final AttendanceStatus attendance;

  final AttendanceMethod method;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'attendance': attendance.wire,
    'method': method.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckIn &&
          attendance == other.attendance &&
          method == other.method;

  @override
  int get hashCode => Object.hashAll(<Object?>[attendance, method]);
}

final class CheckInRequest {
  const CheckInRequest({this.location});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CheckInRequest.fromJson(Map<String, Object?> json) => CheckInRequest(
    location: switch (json['location']) {
      null => null,
      final Object v => LatLng.fromJson(
        _readObject(v, 'CheckInRequest.location'),
      ),
    },
  );

  /// Yüz yüze etkinlikte zorunlu, şu anki konumunuz; çevrimiçide gönderilmez. Saklanmaz, log'a yazılmaz.
  final LatLng? location;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (location case final value?) 'location': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInRequest && location == other.location;

  @override
  int get hashCode => Object.hashAll(<Object?>[location]);
}

/// Bir etkinliğin bir liste bileşeni, isteği yapanın gördüğü haliyle (#241).
final class Checklist {
  const Checklist({
    required this.items,
    required this.label,
    required this.assignmentEnabled,
    required this.quantityEnabled,
    required this.callerCanManage,
    required this.callerCanTake,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Checklist.fromJson(Map<String, Object?> json) => Checklist(
    items: List<ChecklistItem>.unmodifiable(
      _readList(json['items'], 'Checklist.items').map(
        (Object? e0) =>
            ChecklistItem.fromJson(_readObject(e0, 'Checklist.items')),
      ),
    ),
    label: ChecklistLabel.fromWire(
      _readString(json['label'], 'Checklist.label'),
    ),
    assignmentEnabled: _readBool(
      json['assignment_enabled'],
      'Checklist.assignment_enabled',
    ),
    quantityEnabled: _readBool(
      json['quantity_enabled'],
      'Checklist.quantity_enabled',
    ),
    callerCanManage: _readBool(
      json['caller_can_manage'],
      'Checklist.caller_can_manage',
    ),
    callerCanTake: _readBool(
      json['caller_can_take'],
      'Checklist.caller_can_take',
    ),
  );

  /// Eklenme sırasıyla.
  final List<ChecklistItem> items;

  /// Bileşenin `label` parametresi (malzeme, görev, bölüm, nöbet, madde); tanım vermezse `item`. Metni istemci çevirir.
  final ChecklistLabel label;

  /// Bileşenin `assignment` parametresi; kapalıysa madde üstlenilmez.
  final bool assignmentEnabled;

  /// Bileşenin `quantity` parametresi; kapalıysa adet hep 1.
  final bool quantityEnabled;

  /// Şu an madde ekleyebilir, çıkarabilir ve atayabilirsiniz (organizatör yetkisi, susturulmamış; etkinlik bitmemiş, iptal değil, tayfa salt okunur değil).
  final bool callerCanManage;

  /// Şu an boştaki maddeyi kendinize atayabilir ve kendi atamanızı kaldırabilirsiniz (`going`, susturulmamış, `assignment_enabled`; aynı pencereler).
  final bool callerCanTake;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final e0 in items) e0.toJson()],
    'label': label.wire,
    'assignment_enabled': assignmentEnabled,
    'quantity_enabled': quantityEnabled,
    'caller_can_manage': callerCanManage,
    'caller_can_take': callerCanTake,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Checklist &&
          _deepEquals(items, other.items) &&
          label == other.label &&
          assignmentEnabled == other.assignmentEnabled &&
          quantityEnabled == other.quantityEnabled &&
          callerCanManage == other.callerCanManage &&
          callerCanTake == other.callerCanTake;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(items),
    label,
    assignmentEnabled,
    quantityEnabled,
    callerCanManage,
    callerCanTake,
  ]);
}

final class ChecklistAssignRequest {
  const ChecklistAssignRequest({this.assignedUserId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChecklistAssignRequest.fromJson(Map<String, Object?> json) =>
      ChecklistAssignRequest(
        assignedUserId: switch (json['assigned_user_id']) {
          null => null,
          final Object v => _readString(
            v,
            'ChecklistAssignRequest.assigned_user_id',
          ),
        },
      );

  /// Üstlenecek kişi. Yoksa (ya da `null`) atama kaldırılır.
  final String? assignedUserId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (assignedUserId case final value?) 'assigned_user_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistAssignRequest && assignedUserId == other.assignedUserId;

  @override
  int get hashCode => Object.hashAll(<Object?>[assignedUserId]);
}

final class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.assignedUserId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChecklistItem.fromJson(Map<String, Object?> json) => ChecklistItem(
    id: _readString(json['id'], 'ChecklistItem.id'),
    name: _readString(json['name'], 'ChecklistItem.name'),
    quantity: _readInt(json['quantity'], 'ChecklistItem.quantity'),
    assignedUserId: switch (json['assigned_user_id']) {
      null => null,
      final Object v => _readString(v, 'ChecklistItem.assigned_user_id'),
    },
  );

  final String id;

  final String name;

  /// 1–999; bileşenin `quantity` parametresi kapalıysa hep 1.
  final int quantity;

  /// Maddeyi üstlenen kişi; kimse üstlenmediyse yoktur.
  final String? assignedUserId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'quantity': quantity,
    if (assignedUserId case final value?) 'assigned_user_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          id == other.id &&
          name == other.name &&
          quantity == other.quantity &&
          assignedUserId == other.assignedUserId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, name, quantity, assignedUserId]);
}

final class ChecklistItemRequest {
  const ChecklistItemRequest({
    required this.name,
    this.quantity,
    this.assignedUserId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChecklistItemRequest.fromJson(Map<String, Object?> json) =>
      ChecklistItemRequest(
        name: _readString(json['name'], 'ChecklistItemRequest.name'),
        quantity: switch (json['quantity']) {
          null => null,
          final Object v => _readInt(v, 'ChecklistItemRequest.quantity'),
        },
        assignedUserId: switch (json['assigned_user_id']) {
          null => null,
          final Object v => _readString(
            v,
            'ChecklistItemRequest.assigned_user_id',
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 60.
  final String name;

  /// 0 ya da yok: 1. Birden büyük değer yalnızca `quantity_enabled` ise.
  ///
  /// Kısıtlar: minimum: 0; maximum: 999.
  final int? quantity;

  /// İsteğe bağlı; yalnızca `assignment_enabled` ise. Tayfanın `going` cevabı vermiş etkin bir üyesi (`event-not-going`).
  final String? assignedUserId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (quantity case final value?) 'quantity': value,
    if (assignedUserId case final value?) 'assigned_user_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItemRequest &&
          name == other.name &&
          quantity == other.quantity &&
          assignedUserId == other.assignedUserId;

  @override
  int get hashCode => Object.hashAll(<Object?>[name, quantity, assignedUserId]);
}

/// Bileşenin `label` parametresi (malzeme, görev, bölüm, nöbet, madde); tanım vermezse `item`. Metni istemci çevirir.
enum ChecklistLabel {
  gear('gear'),
  task('task'),
  section('section'),
  duty('duty'),
  item('item'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ChecklistLabel(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ChecklistLabel.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ChecklistLabel fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class ClientConfig {
  const ClientConfig({required this.platforms});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ClientConfig.fromJson(Map<String, Object?> json) => ClientConfig(
    platforms: ClientConfigPlatforms.fromJson(
      _readObject(json['platforms'], 'ClientConfig.platforms'),
    ),
  );

  final ClientConfigPlatforms platforms;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'platforms': platforms.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientConfig && platforms == other.platforms;

  @override
  int get hashCode => Object.hashAll(<Object?>[platforms]);
}

final class ClientConfigPlatforms {
  const ClientConfigPlatforms({
    required this.android,
    required this.ios,
    this.web,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ClientConfigPlatforms.fromJson(Map<String, Object?> json) =>
      ClientConfigPlatforms(
        android: PlatformVersions.fromJson(
          _readObject(json['android'], 'ClientConfigPlatforms.android'),
        ),
        ios: PlatformVersions.fromJson(
          _readObject(json['ios'], 'ClientConfigPlatforms.ios'),
        ),
        web: switch (json['web']) {
          null => null,
          final Object v => PlatformVersions.fromJson(
            _readObject(v, 'ClientConfigPlatforms.web'),
          ),
        },
      );

  final PlatformVersions android;

  final PlatformVersions ios;

  /// Yalnızca prod dışında; web geliştirme derlemesi (ADR-0017).
  final PlatformVersions? web;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'android': android.toJson(),
    'ios': ios.toJson(),
    if (web case final value?) 'web': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientConfigPlatforms &&
          android == other.android &&
          ios == other.ios &&
          web == other.web;

  @override
  int get hashCode => Object.hashAll(<Object?>[android, ios, web]);
}

/// Organizatöre bırakılan bir parametre için seçim (ADR-0037 §2).
/// `value` seçeneğin metin halidir: seçeneğin kendisi ya da tam sayı
/// seçeneğin rakamları (`"swiss"`, `"3"`).
final class ComponentChoice {
  const ComponentChoice({required this.param, required this.value});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ComponentChoice.fromJson(Map<String, Object?> json) =>
      ComponentChoice(
        param: _readString(json['param'], 'ComponentChoice.param'),
        value: _readString(json['value'], 'ComponentChoice.value'),
      );

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String param;

  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String value;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'param': param,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComponentChoice && param == other.param && value == other.value;

  @override
  int get hashCode => Object.hashAll(<Object?>[param, value]);
}

final class ConsentRequest {
  const ConsentRequest({
    required this.privacyNoticeVersion,
    required this.termsVersion,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConsentRequest.fromJson(Map<String, Object?> json) => ConsentRequest(
    privacyNoticeVersion: _readString(
      json['privacy_notice_version'],
      'ConsentRequest.privacy_notice_version',
    ),
    termsVersion: _readString(
      json['terms_version'],
      'ConsentRequest.terms_version',
    ),
  );

  /// Kısıtlar: maxLength: 32.
  final String privacyNoticeVersion;

  /// Kısıtlar: maxLength: 32.
  final String termsVersion;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'privacy_notice_version': privacyNoticeVersion,
    'terms_version': termsVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentRequest &&
          privacyNoticeVersion == other.privacyNoticeVersion &&
          termsVersion == other.termsVersion;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[privacyNoticeVersion, termsVersion]);
}

final class ConsentStatus {
  const ConsentStatus({
    required this.privacyNoticeVersion,
    required this.termsVersion,
    required this.consentRequired,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConsentStatus.fromJson(Map<String, Object?> json) => ConsentStatus(
    privacyNoticeVersion: _readString(
      json['privacy_notice_version'],
      'ConsentStatus.privacy_notice_version',
    ),
    termsVersion: _readString(
      json['terms_version'],
      'ConsentStatus.terms_version',
    ),
    consentRequired: _readBool(
      json['consent_required'],
      'ConsentStatus.consent_required',
    ),
  );

  final String privacyNoticeVersion;

  final String termsVersion;

  final bool consentRequired;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'privacy_notice_version': privacyNoticeVersion,
    'terms_version': termsVersion,
    'consent_required': consentRequired,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentStatus &&
          privacyNoticeVersion == other.privacyNoticeVersion &&
          termsVersion == other.termsVersion &&
          consentRequired == other.consentRequired;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    privacyNoticeVersion,
    termsVersion,
    consentRequired,
  ]);
}

final class Conversation {
  const Conversation({
    required this.id,
    this.otherUserId,
    required this.status,
    required this.unreadCount,
    this.lastReadMessageId,
    this.peerLastReadMessageId,
    required this.lastMessageAt,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Conversation.fromJson(Map<String, Object?> json) => Conversation(
    id: _readString(json['id'], 'Conversation.id'),
    otherUserId: switch (json['other_user_id']) {
      null => null,
      final Object v => _readString(v, 'Conversation.other_user_id'),
    },
    status: ConversationStatus.fromWire(
      _readString(json['status'], 'Conversation.status'),
    ),
    unreadCount: _readInt(json['unread_count'], 'Conversation.unread_count'),
    lastReadMessageId: switch (json['last_read_message_id']) {
      null => null,
      final Object v => _readString(v, 'Conversation.last_read_message_id'),
    },
    peerLastReadMessageId: switch (json['peer_last_read_message_id']) {
      null => null,
      final Object v => _readString(
        v,
        'Conversation.peer_last_read_message_id',
      ),
    },
    lastMessageAt: _readDateTime(
      json['last_message_at'],
      'Conversation.last_message_at',
    ),
    createdAt: _readDateTime(json['created_at'], 'Conversation.created_at'),
  );

  final String id;

  /// Karşı tarafın hesabı silindiyse yoktur ("Silinmiş kullanıcı"; yazılamaz).
  final String? otherUserId;

  /// `active` (serbest yazışma), `request_sent` (isteğiniz cevap
  /// bekliyor; reddedilse de böyle görünür), `request_received`
  /// (size gelen istek: cevap yazın, kabul edin ya da reddedin).
  /// Tanınmayan değer `unknown`.
  final ConversationStatus status;

  /// Kısıtlar: minimum: 0; maximum: 100.
  final int unreadCount;

  final String? lastReadMessageId;

  /// Karşı tarafın okundu işareti; yalnızca aktif konuşmada.
  final String? peerLastReadMessageId;

  final DateTime lastMessageAt;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (otherUserId case final value?) 'other_user_id': value,
    'status': status.wire,
    'unread_count': unreadCount,
    if (lastReadMessageId case final value?) 'last_read_message_id': value,
    if (peerLastReadMessageId case final value?)
      'peer_last_read_message_id': value,
    'last_message_at': lastMessageAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          id == other.id &&
          otherUserId == other.otherUserId &&
          status == other.status &&
          unreadCount == other.unreadCount &&
          lastReadMessageId == other.lastReadMessageId &&
          peerLastReadMessageId == other.peerLastReadMessageId &&
          lastMessageAt == other.lastMessageAt &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    otherUserId,
    status,
    unreadCount,
    lastReadMessageId,
    peerLastReadMessageId,
    lastMessageAt,
    createdAt,
  ]);
}

final class ConversationList {
  const ConversationList({required this.conversations, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConversationList.fromJson(Map<String, Object?> json) =>
      ConversationList(
        conversations: List<Conversation>.unmodifiable(
          _readList(
            json['conversations'],
            'ConversationList.conversations',
          ).map(
            (Object? e0) => Conversation.fromJson(
              _readObject(e0, 'ConversationList.conversations'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'ConversationList.next_page_token'),
        },
      );

  final List<Conversation> conversations;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'conversations': <Object?>[for (final e0 in conversations) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationList &&
          _deepEquals(conversations, other.conversations) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(conversations), nextPageToken]);
}

/// Birebir konuşma tercihi; `mentions` yoktur.
final class ConversationNotificationPreferenceRequest {
  const ConversationNotificationPreferenceRequest({
    required this.level,
    this.muteUntil,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConversationNotificationPreferenceRequest.fromJson(
    Map<String, Object?> json,
  ) => ConversationNotificationPreferenceRequest(
    level: ConversationNotificationPreferenceRequestLevel.fromWire(
      _readString(
        json['level'],
        'ConversationNotificationPreferenceRequest.level',
      ),
    ),
    muteUntil: switch (json['mute_until']) {
      null => null,
      final Object v => _readDateTime(
        v,
        'ConversationNotificationPreferenceRequest.mute_until',
      ),
    },
  );

  final ConversationNotificationPreferenceRequestLevel level;

  /// Yalnızca `none` ile; en fazla bir yıl sonrası.
  final DateTime? muteUntil;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'level': level.wire,
    if (muteUntil case final value?)
      'mute_until': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationNotificationPreferenceRequest &&
          level == other.level &&
          muteUntil == other.muteUntil;

  @override
  int get hashCode => Object.hashAll(<Object?>[level, muteUntil]);
}

enum ConversationNotificationPreferenceRequestLevel {
  all('all'),
  none('none'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ConversationNotificationPreferenceRequestLevel(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'ConversationNotificationPreferenceRequestLevel.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ConversationNotificationPreferenceRequestLevel fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `active` (serbest yazışma), `request_sent` (isteğiniz cevap
/// bekliyor; reddedilse de böyle görünür), `request_received`
/// (size gelen istek: cevap yazın, kabul edin ya da reddedin).
/// Tanınmayan değer `unknown`.
enum ConversationStatus {
  active('active'),
  requestSent('request_sent'),
  requestReceived('request_received'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const ConversationStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ConversationStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ConversationStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Geri sayım. Başlık kötüye kullanım filtresinden geçer; an geçince
/// bileşen gösterilmez.
final class CountdownWidgetConfig {
  const CountdownWidgetConfig({required this.title, required this.at});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CountdownWidgetConfig.fromJson(Map<String, Object?> json) =>
      CountdownWidgetConfig(
        title: _readString(json['title'], 'CountdownWidgetConfig.title'),
        at: _readDateTime(json['at'], 'CountdownWidgetConfig.at'),
      );

  /// Kısıtlar: minLength: 1; maxLength: 60.
  final String title;

  /// Saniyeye yuvarlanır.
  final DateTime at;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'at': at.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountdownWidgetConfig && title == other.title && at == other.at;

  @override
  int get hashCode => Object.hashAll(<Object?>[title, at]);
}

final class CountdownWidgetData {
  const CountdownWidgetData({required this.title, this.at});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CountdownWidgetData.fromJson(Map<String, Object?> json) =>
      CountdownWidgetData(
        title: _readString(json['title'], 'CountdownWidgetData.title'),
        at: switch (json['at']) {
          null => null,
          final Object v => _readDateTime(v, 'CountdownWidgetData.at'),
        },
      );

  final String title;

  final DateTime? at;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    if (at case final value?) 'at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountdownWidgetData && title == other.title && at == other.at;

  @override
  int get hashCode => Object.hashAll(<Object?>[title, at]);
}

final class CreatedInvite {
  const CreatedInvite({required this.invite, required this.token});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CreatedInvite.fromJson(Map<String, Object?> json) => CreatedInvite(
    invite: Invite.fromJson(
      _readObject(json['invite'], 'CreatedInvite.invite'),
    ),
    token: _readString(json['token'], 'CreatedInvite.token'),
  );

  final Invite invite;

  /// Linkin gizli kısmı (43 karakter base64url). Yalnızca burada, bir kez döner.
  final String token;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'invite': invite.toJson(),
    'token': token,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatedInvite && invite == other.invite && token == other.token;

  @override
  int get hashCode => Object.hashAll(<Object?>[invite, token]);
}

final class DailyItem {
  const DailyItem({
    required this.id,
    required this.body,
    this.attribution,
    required this.position,
    this.pin,
    this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyItem.fromJson(Map<String, Object?> json) => DailyItem(
    id: _readString(json['id'], 'DailyItem.id'),
    body: _readString(json['body'], 'DailyItem.body'),
    attribution: switch (json['attribution']) {
      null => null,
      final Object v => _readString(v, 'DailyItem.attribution'),
    },
    position: _readInt(json['position'], 'DailyItem.position'),
    pin: switch (json['pin']) {
      null => null,
      final Object v => DailyPin.fromJson(_readObject(v, 'DailyItem.pin')),
    },
    createdByUserId: switch (json['created_by_user_id']) {
      null => null,
      final Object v => _readString(v, 'DailyItem.created_by_user_id'),
    },
    createdAt: _readDateTime(json['created_at'], 'DailyItem.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'DailyItem.updated_at'),
    deletedAt: switch (json['deleted_at']) {
      null => null,
      final Object v => _readDateTime(v, 'DailyItem.deleted_at'),
    },
  );

  final String id;

  /// 1–500 karakter. Satırlar `\n` ile ayrılır (dizeler için; art
  /// arda en fazla bir boş satır); başka denetim karakteri yoktur.
  final String body;

  /// Söyleyen ya da kaynak; tek satır, en fazla 120. Yoksa alan yoktur.
  final String? attribution;

  /// Havuzdaki yeri, küçükten büyüğe (boşluk olabilir).
  final int position;

  final DailyPin? pin;

  /// Ekleyen; hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? createdByUserId;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// Yalnızca silinenler listesinde (`deleted=true`).
  final DateTime? deletedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'body': body,
    if (attribution case final value?) 'attribution': value,
    'position': position,
    if (pin case final value?) 'pin': value.toJson(),
    if (createdByUserId case final value?) 'created_by_user_id': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (deletedAt case final value?)
      'deleted_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyItem &&
          id == other.id &&
          body == other.body &&
          attribution == other.attribution &&
          position == other.position &&
          pin == other.pin &&
          createdByUserId == other.createdByUserId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    body,
    attribution,
    position,
    pin,
    createdByUserId,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
}

final class DailyItemCreateRequest {
  const DailyItemCreateRequest({
    required this.body,
    this.attribution,
    this.pin,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyItemCreateRequest.fromJson(Map<String, Object?> json) =>
      DailyItemCreateRequest(
        body: _readString(json['body'], 'DailyItemCreateRequest.body'),
        attribution: switch (json['attribution']) {
          null => null,
          final Object v => _readString(
            v,
            'DailyItemCreateRequest.attribution',
          ),
        },
        pin: switch (json['pin']) {
          null => null,
          final Object v => DailyPin.fromJson(
            _readObject(v, 'DailyItemCreateRequest.pin'),
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'DailyItemCreateRequest.client_request_id',
        ),
      );

  /// Kısıtlar: minLength: 1; maxLength: 4096.
  final String body;

  /// Boş: yok.
  ///
  /// Kısıtlar: maxLength: 4096.
  final String? attribution;

  final DailyPin? pin;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    if (attribution case final value?) 'attribution': value,
    if (pin case final value?) 'pin': value.toJson(),
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyItemCreateRequest &&
          body == other.body &&
          attribution == other.attribution &&
          pin == other.pin &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[body, attribution, pin, clientRequestId]);
}

final class DailyItemInput {
  const DailyItemInput({required this.body, this.attribution, this.pin});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyItemInput.fromJson(Map<String, Object?> json) => DailyItemInput(
    body: _readString(json['body'], 'DailyItemInput.body'),
    attribution: switch (json['attribution']) {
      null => null,
      final Object v => _readString(v, 'DailyItemInput.attribution'),
    },
    pin: switch (json['pin']) {
      null => null,
      final Object v => DailyPin.fromJson(_readObject(v, 'DailyItemInput.pin')),
    },
  );

  /// Kısıtlar: minLength: 1; maxLength: 4096.
  final String body;

  /// Boş: yok.
  ///
  /// Kısıtlar: maxLength: 4096.
  final String? attribution;

  final DailyPin? pin;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    if (attribution case final value?) 'attribution': value,
    if (pin case final value?) 'pin': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyItemInput &&
          body == other.body &&
          attribution == other.attribution &&
          pin == other.pin;

  @override
  int get hashCode => Object.hashAll(<Object?>[body, attribution, pin]);
}

final class DailyItemList {
  const DailyItemList({required this.items, required this.callerCanManage});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyItemList.fromJson(Map<String, Object?> json) => DailyItemList(
    items: List<DailyItem>.unmodifiable(
      _readList(json['items'], 'DailyItemList.items').map(
        (Object? e0) =>
            DailyItem.fromJson(_readObject(e0, 'DailyItemList.items')),
      ),
    ),
    callerCanManage: _readBool(
      json['caller_can_manage'],
      'DailyItemList.caller_can_manage',
    ),
  );

  final List<DailyItem> items;

  /// Çağıran havuzu şimdi yönetebilir mi.
  final bool callerCanManage;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final e0 in items) e0.toJson()],
    'caller_can_manage': callerCanManage,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyItemList &&
          _deepEquals(items, other.items) &&
          callerCanManage == other.callerCanManage;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(items), callerCanManage]);
}

final class DailyItemSaved {
  const DailyItemSaved({required this.item, required this.pinConflict});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyItemSaved.fromJson(Map<String, Object?> json) => DailyItemSaved(
    item: DailyItem.fromJson(_readObject(json['item'], 'DailyItemSaved.item')),
    pinConflict: _readBool(json['pin_conflict'], 'DailyItemSaved.pin_conflict'),
  );

  final DailyItem item;

  /// Aynı güne sabitlenmiş başka içerik var; istemci uyarır.
  final bool pinConflict;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'item': item.toJson(),
    'pin_conflict': pinConflict,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyItemSaved &&
          item == other.item &&
          pinConflict == other.pinConflict;

  @override
  int get hashCode => Object.hashAll(<Object?>[item, pinConflict]);
}

final class DailyOrder {
  const DailyOrder({required this.items});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyOrder.fromJson(Map<String, Object?> json) => DailyOrder(
    items: List<DailyItem>.unmodifiable(
      _readList(json['items'], 'DailyOrder.items').map(
        (Object? e0) => DailyItem.fromJson(_readObject(e0, 'DailyOrder.items')),
      ),
    ),
  );

  final List<DailyItem> items;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final e0 in items) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyOrder && _deepEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(items)]);
}

final class DailyOrderRequest {
  const DailyOrderRequest({required this.itemIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyOrderRequest.fromJson(Map<String, Object?> json) =>
      DailyOrderRequest(
        itemIds: List<String>.unmodifiable(
          _readList(
            json['item_ids'],
            'DailyOrderRequest.item_ids',
          ).map((Object? e0) => _readString(e0, 'DailyOrderRequest.item_ids')),
        ),
      );

  /// Kısıtlar: maxItems: 1000.
  final List<String> itemIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'item_ids': <Object?>[for (final e0 in itemIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyOrderRequest && _deepEquals(itemIds, other.itemIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(itemIds)]);
}

/// Yılın bir gününe sabitleme. `year` yoksa her yıl tekrarlanır.
/// Yılsız 29 Şubat yalnızca artık yıllarda gösterilir; yıllı 29 Şubat
/// artık yıl ister.
final class DailyPin {
  const DailyPin({required this.month, required this.day, this.year});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyPin.fromJson(Map<String, Object?> json) => DailyPin(
    month: _readInt(json['month'], 'DailyPin.month'),
    day: _readInt(json['day'], 'DailyPin.day'),
    year: switch (json['year']) {
      null => null,
      final Object v => _readInt(v, 'DailyPin.year'),
    },
  );

  /// Kısıtlar: minimum: 1; maximum: 12.
  final int month;

  /// Kısıtlar: minimum: 1; maximum: 31.
  final int day;

  /// Kısıtlar: minimum: 2000; maximum: 2100.
  final int? year;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'month': month,
    'day': day,
    if (year case final value?) 'year': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyPin &&
          month == other.month &&
          day == other.day &&
          year == other.year;

  @override
  int get hashCode => Object.hashAll(<Object?>[month, day, year]);
}

final class DailyToday {
  const DailyToday({this.item, required this.pinned, required this.date});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DailyToday.fromJson(Map<String, Object?> json) => DailyToday(
    item: switch (json['item']) {
      null => null,
      final Object v => DailyItem.fromJson(_readObject(v, 'DailyToday.item')),
    },
    pinned: _readBool(json['pinned'], 'DailyToday.pinned'),
    date: _readString(json['date'], 'DailyToday.date'),
  );

  final DailyItem? item;

  /// İçerik bugüne sabitlenmiş.
  final bool pinned;

  /// Bugün, Europe/Istanbul.
  ///
  /// Kısıtlar: biçim: `YYYY-AA-GG` (saat dilimsiz tarih).
  final String date;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (item case final value?) 'item': value.toJson(),
    'pinned': pinned,
    'date': date,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyToday &&
          item == other.item &&
          pinned == other.pinned &&
          date == other.date;

  @override
  int get hashCode => Object.hashAll(<Object?>[item, pinned, date]);
}

final class DataExport {
  const DataExport({
    required this.id,
    required this.status,
    this.failureReason,
    required this.requestedAt,
    this.readyAt,
    this.expiresAt,
    this.downloadedAt,
    this.sizeBytes,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DataExport.fromJson(Map<String, Object?> json) => DataExport(
    id: _readString(json['id'], 'DataExport.id'),
    status: DataExportStatus.fromWire(
      _readString(json['status'], 'DataExport.status'),
    ),
    failureReason: switch (json['failure_reason']) {
      null => null,
      final Object v => DataExportFailureReason.fromWire(
        _readString(v, 'DataExport.failure_reason'),
      ),
    },
    requestedAt: _readDateTime(json['requested_at'], 'DataExport.requested_at'),
    readyAt: switch (json['ready_at']) {
      null => null,
      final Object v => _readDateTime(v, 'DataExport.ready_at'),
    },
    expiresAt: switch (json['expires_at']) {
      null => null,
      final Object v => _readDateTime(v, 'DataExport.expires_at'),
    },
    downloadedAt: switch (json['downloaded_at']) {
      null => null,
      final Object v => _readDateTime(v, 'DataExport.downloaded_at'),
    },
    sizeBytes: switch (json['size_bytes']) {
      null => null,
      final Object v => _readInt(v, 'DataExport.size_bytes'),
    },
  );

  final String id;

  /// `pending` (sırada), `processing` (toplanıyor), `ready` (7 gün
  /// indirilebilir), `expired` (dosya ve anahtar silindi), `failed`
  /// (30 günlük sınıra sayılmaz; tekrar talep açılabilir).
  final DataExportStatus status;

  /// Yalnızca `failed`: `unavailable` (bir servise ya da depolamaya
  /// ulaşılamadı), `too_large` (arşiv 16 MiB'ı geçti; talebiniz elle
  /// yanıtlanır), `timeout` (zamanında bitmedi), `failed`.
  final DataExportFailureReason? failureReason;

  final DateTime requestedAt;

  final DateTime? readyAt;

  final DateTime? expiresAt;

  final DateTime? downloadedAt;

  /// Şifreli dosyanın boyutu, `ready` iken.
  final int? sizeBytes;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'status': status.wire,
    if (failureReason case final value?) 'failure_reason': value.wire,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    if (readyAt case final value?) 'ready_at': value.toUtc().toIso8601String(),
    if (expiresAt case final value?)
      'expires_at': value.toUtc().toIso8601String(),
    if (downloadedAt case final value?)
      'downloaded_at': value.toUtc().toIso8601String(),
    if (sizeBytes case final value?) 'size_bytes': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataExport &&
          id == other.id &&
          status == other.status &&
          failureReason == other.failureReason &&
          requestedAt == other.requestedAt &&
          readyAt == other.readyAt &&
          expiresAt == other.expiresAt &&
          downloadedAt == other.downloadedAt &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    status,
    failureReason,
    requestedAt,
    readyAt,
    expiresAt,
    downloadedAt,
    sizeBytes,
  ]);
}

final class DataExportDownload {
  const DataExportDownload({
    required this.url,
    required this.expiresAt,
    required this.key,
    required this.sizeBytes,
    required this.format,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DataExportDownload.fromJson(Map<String, Object?> json) =>
      DataExportDownload(
        url: _readString(json['url'], 'DataExportDownload.url'),
        expiresAt: _readDateTime(
          json['expires_at'],
          'DataExportDownload.expires_at',
        ),
        key: _readString(json['key'], 'DataExportDownload.key'),
        sizeBytes: _readInt(
          json['size_bytes'],
          'DataExportDownload.size_bytes',
        ),
        format: DataExportDownloadFormat.fromWire(
          _readString(json['format'], 'DataExportDownload.format'),
        ),
      );

  /// Şifreli dosyanın imzalı GET linki; `expires_at`'e kadar (5 dakika) taşıyan herkes indirebilir.
  final String url;

  final DateTime expiresAt;

  /// 32 baytlık AES-256 anahtarı (base64).
  ///
  /// Kısıtlar: biçim: standart base64.
  final String key;

  final int sizeBytes;

  final DataExportDownloadFormat format;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'key': key,
    'size_bytes': sizeBytes,
    'format': format.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataExportDownload &&
          url == other.url &&
          expiresAt == other.expiresAt &&
          key == other.key &&
          sizeBytes == other.sizeBytes &&
          format == other.format;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[url, expiresAt, key, sizeBytes, format]);
}

enum DataExportDownloadFormat {
  aes256GcmV1('aes-256-gcm-v1'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const DataExportDownloadFormat(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('DataExportDownloadFormat.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static DataExportDownloadFormat fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Yalnızca `failed`: `unavailable` (bir servise ya da depolamaya
/// ulaşılamadı), `too_large` (arşiv 16 MiB'ı geçti; talebiniz elle
/// yanıtlanır), `timeout` (zamanında bitmedi), `failed`.
enum DataExportFailureReason {
  unavailable('unavailable'),
  tooLarge('too_large'),
  timeout('timeout'),
  failed('failed'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const DataExportFailureReason(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('DataExportFailureReason.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static DataExportFailureReason fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class DataExportList {
  const DataExportList({required this.dataExports, this.nextRequestAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DataExportList.fromJson(Map<String, Object?> json) => DataExportList(
    dataExports: List<DataExport>.unmodifiable(
      _readList(json['data_exports'], 'DataExportList.data_exports').map(
        (Object? e0) =>
            DataExport.fromJson(_readObject(e0, 'DataExportList.data_exports')),
      ),
    ),
    nextRequestAt: switch (json['next_request_at']) {
      null => null,
      final Object v => _readDateTime(v, 'DataExportList.next_request_at'),
    },
  );

  final List<DataExport> dataExports;

  /// Bir sonraki talebin açılabileceği an; yoksa şimdi açılabilir (süren talep yine engeller).
  final DateTime? nextRequestAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'data_exports': <Object?>[for (final e0 in dataExports) e0.toJson()],
    if (nextRequestAt case final value?)
      'next_request_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataExportList &&
          _deepEquals(dataExports, other.dataExports) &&
          nextRequestAt == other.nextRequestAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(dataExports), nextRequestAt]);
}

final class DataExportRequest {
  const DataExportRequest({required this.clientRequestId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DataExportRequest.fromJson(Map<String, Object?> json) =>
      DataExportRequest(
        clientRequestId: _readString(
          json['client_request_id'],
          'DataExportRequest.client_request_id',
        ),
      );

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataExportRequest && clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[clientRequestId]);
}

/// `pending` (sırada), `processing` (toplanıyor), `ready` (7 gün
/// indirilebilir), `expired` (dosya ve anahtar silindi), `failed`
/// (30 günlük sınıra sayılmaz; tekrar talep açılabilir).
enum DataExportStatus {
  pending('pending'),
  processing('processing'),
  ready('ready'),
  expired('expired'),
  failed('failed'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const DataExportStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('DataExportStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static DataExportStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Günün kaba bir bölümü; saat değil. `all_day` başka dilimle birlikte olmaz.
enum DaySlot {
  morning('morning'),
  afternoon('afternoon'),
  evening('evening'),
  allDay('all_day'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const DaySlot(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('DaySlot.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static DaySlot fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class DeclinedRequest {
  const DeclinedRequest({
    required this.conversationId,
    required this.senderUserId,
    required this.declinedAt,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DeclinedRequest.fromJson(Map<String, Object?> json) =>
      DeclinedRequest(
        conversationId: _readString(
          json['conversation_id'],
          'DeclinedRequest.conversation_id',
        ),
        senderUserId: _readString(
          json['sender_user_id'],
          'DeclinedRequest.sender_user_id',
        ),
        declinedAt: _readDateTime(
          json['declined_at'],
          'DeclinedRequest.declined_at',
        ),
        createdAt: _readDateTime(
          json['created_at'],
          'DeclinedRequest.created_at',
        ),
      );

  final String conversationId;

  /// İsteği gönderen.
  final String senderUserId;

  final DateTime declinedAt;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'conversation_id': conversationId,
    'sender_user_id': senderUserId,
    'declined_at': declinedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeclinedRequest &&
          conversationId == other.conversationId &&
          senderUserId == other.senderUserId &&
          declinedAt == other.declinedAt &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    conversationId,
    senderUserId,
    declinedAt,
    createdAt,
  ]);
}

final class DeclinedRequestList {
  const DeclinedRequestList({
    required this.declinedRequests,
    this.nextPageToken,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DeclinedRequestList.fromJson(Map<String, Object?> json) =>
      DeclinedRequestList(
        declinedRequests: List<DeclinedRequest>.unmodifiable(
          _readList(
            json['declined_requests'],
            'DeclinedRequestList.declined_requests',
          ).map(
            (Object? e0) => DeclinedRequest.fromJson(
              _readObject(e0, 'DeclinedRequestList.declined_requests'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(
            v,
            'DeclinedRequestList.next_page_token',
          ),
        },
      );

  final List<DeclinedRequest> declinedRequests;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'declined_requests': <Object?>[
      for (final e0 in declinedRequests) e0.toJson(),
    ],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeclinedRequestList &&
          _deepEquals(declinedRequests, other.declinedRequests) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(declinedRequests), nextPageToken]);
}

final class Deletion {
  const Deletion({required this.deletionAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Deletion.fromJson(Map<String, Object?> json) => Deletion(
    deletionAt: _readDateTime(json['deletion_at'], 'Deletion.deletion_at'),
  );

  final DateTime deletionAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'deletion_at': deletionAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Deletion && deletionAt == other.deletionAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[deletionAt]);
}

final class DeviceSession {
  const DeviceSession({
    required this.sessionId,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    required this.current,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DeviceSession.fromJson(Map<String, Object?> json) => DeviceSession(
    sessionId: _readString(json['session_id'], 'DeviceSession.session_id'),
    platform: DeviceSessionPlatform.fromWire(
      _readString(json['platform'], 'DeviceSession.platform'),
    ),
    createdAt: _readDateTime(json['created_at'], 'DeviceSession.created_at'),
    lastSeenAt: _readDateTime(
      json['last_seen_at'],
      'DeviceSession.last_seen_at',
    ),
    current: _readBool(json['current'], 'DeviceSession.current'),
  );

  final String sessionId;

  final DeviceSessionPlatform platform;

  final DateTime createdAt;

  /// Oturumun son token yenilemesi.
  final DateTime lastSeenAt;

  /// Bu isteğin oturumu.
  final bool current;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'session_id': sessionId,
    'platform': platform.wire,
    'created_at': createdAt.toUtc().toIso8601String(),
    'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
    'current': current,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceSession &&
          sessionId == other.sessionId &&
          platform == other.platform &&
          createdAt == other.createdAt &&
          lastSeenAt == other.lastSeenAt &&
          current == other.current;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    sessionId,
    platform,
    createdAt,
    lastSeenAt,
    current,
  ]);
}

final class DeviceSessionList {
  const DeviceSessionList({required this.sessions});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DeviceSessionList.fromJson(Map<String, Object?> json) =>
      DeviceSessionList(
        sessions: List<DeviceSession>.unmodifiable(
          _readList(json['sessions'], 'DeviceSessionList.sessions').map(
            (Object? e0) => DeviceSession.fromJson(
              _readObject(e0, 'DeviceSessionList.sessions'),
            ),
          ),
        ),
      );

  final List<DeviceSession> sessions;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'sessions': <Object?>[for (final e0 in sessions) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceSessionList && _deepEquals(sessions, other.sessions);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(sessions)]);
}

enum DeviceSessionPlatform {
  android('android'),
  ios('ios'),
  web('web'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const DeviceSessionPlatform(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('DeviceSessionPlatform.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static DeviceSessionPlatform fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    this.senderUserId,
    required this.deleted,
    this.encryption,
    required this.createdAt,
    this.attachmentUploadId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DirectMessage.fromJson(Map<String, Object?> json) => DirectMessage(
    id: _readString(json['id'], 'DirectMessage.id'),
    conversationId: _readString(
      json['conversation_id'],
      'DirectMessage.conversation_id',
    ),
    senderUserId: switch (json['sender_user_id']) {
      null => null,
      final Object v => _readString(v, 'DirectMessage.sender_user_id'),
    },
    deleted: _readBool(json['deleted'], 'DirectMessage.deleted'),
    encryption: switch (json['encryption']) {
      null => null,
      final Object v => DirectMessageEncryption.fromWire(
        _readString(v, 'DirectMessage.encryption'),
      ),
    },
    createdAt: _readDateTime(json['created_at'], 'DirectMessage.created_at'),
    attachmentUploadId: switch (json['attachment_upload_id']) {
      null => null,
      final Object v => _readString(v, 'DirectMessage.attachment_upload_id'),
    },
  );

  final String id;

  final String conversationId;

  /// Gönderenin hesabı silindiyse yoktur.
  final String? senderUserId;

  final bool deleted;

  /// Her mesaj uçtan uca şifrelidir; içerik yalnızca zarflarda ve
  /// arşivdedir (`server` değeri #151 ile kalktı).
  final DirectMessageEncryption? encryption;

  final DateTime createdAt;

  /// Şifreli ekin yüklemesi (#205); yoksa ya da mesaj silindiyse
  /// yoktur. Ne olduğu ve anahtarı zarfın içindedir.
  final String? attachmentUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'conversation_id': conversationId,
    if (senderUserId case final value?) 'sender_user_id': value,
    'deleted': deleted,
    if (encryption case final value?) 'encryption': value.wire,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (attachmentUploadId case final value?) 'attachment_upload_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectMessage &&
          id == other.id &&
          conversationId == other.conversationId &&
          senderUserId == other.senderUserId &&
          deleted == other.deleted &&
          encryption == other.encryption &&
          createdAt == other.createdAt &&
          attachmentUploadId == other.attachmentUploadId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    conversationId,
    senderUserId,
    deleted,
    encryption,
    createdAt,
    attachmentUploadId,
  ]);
}

/// Düz metin (`body`) kabul edilmez (#151).
final class DirectMessageCreateRequest {
  const DirectMessageCreateRequest({
    required this.recipientUserId,
    required this.envelopes,
    required this.clientRequestId,
    this.attachmentUploadId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DirectMessageCreateRequest.fromJson(Map<String, Object?> json) =>
      DirectMessageCreateRequest(
        recipientUserId: _readString(
          json['recipient_user_id'],
          'DirectMessageCreateRequest.recipient_user_id',
        ),
        envelopes: List<OutgoingEnvelope>.unmodifiable(
          _readList(
            json['envelopes'],
            'DirectMessageCreateRequest.envelopes',
          ).map(
            (Object? e0) => OutgoingEnvelope.fromJson(
              _readObject(e0, 'DirectMessageCreateRequest.envelopes'),
            ),
          ),
        ),
        clientRequestId: _readString(
          json['client_request_id'],
          'DirectMessageCreateRequest.client_request_id',
        ),
        attachmentUploadId: switch (json['attachment_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'DirectMessageCreateRequest.attachment_upload_id',
          ),
        },
      );

  final String recipientUserId;

  /// Kısıtlar: minItems: 1; maxItems: 16.
  final List<OutgoingEnvelope> envelopes;

  /// İstemcinin ürettiği tekrar gönderim anahtarı.
  final String clientRequestId;

  /// İsteğe bağlı şifreli ek; kendi hazır `dm_attachment` yüklemeniz (#205).
  final String? attachmentUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'recipient_user_id': recipientUserId,
    'envelopes': <Object?>[for (final e0 in envelopes) e0.toJson()],
    'client_request_id': clientRequestId,
    if (attachmentUploadId case final value?) 'attachment_upload_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectMessageCreateRequest &&
          recipientUserId == other.recipientUserId &&
          _deepEquals(envelopes, other.envelopes) &&
          clientRequestId == other.clientRequestId &&
          attachmentUploadId == other.attachmentUploadId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    recipientUserId,
    _deepHash(envelopes),
    clientRequestId,
    attachmentUploadId,
  ]);
}

/// Her mesaj uçtan uca şifrelidir; içerik yalnızca zarflarda ve
/// arşivdedir (`server` değeri #151 ile kalktı).
enum DirectMessageEncryption {
  e2e('e2e'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const DirectMessageEncryption(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('DirectMessageEncryption.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static DirectMessageEncryption fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class DirectMessageList {
  const DirectMessageList({required this.messages, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DirectMessageList.fromJson(Map<String, Object?> json) =>
      DirectMessageList(
        messages: List<DirectMessage>.unmodifiable(
          _readList(json['messages'], 'DirectMessageList.messages').map(
            (Object? e0) => DirectMessage.fromJson(
              _readObject(e0, 'DirectMessageList.messages'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'DirectMessageList.next_page_token'),
        },
      );

  final List<DirectMessage> messages;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'messages': <Object?>[for (final e0 in messages) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectMessageList &&
          _deepEquals(messages, other.messages) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(messages), nextPageToken]);
}

final class DirectMessageSent {
  const DirectMessageSent({required this.message, required this.conversation});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DirectMessageSent.fromJson(Map<String, Object?> json) =>
      DirectMessageSent(
        message: DirectMessage.fromJson(
          _readObject(json['message'], 'DirectMessageSent.message'),
        ),
        conversation: Conversation.fromJson(
          _readObject(json['conversation'], 'DirectMessageSent.conversation'),
        ),
      );

  final DirectMessage message;

  final Conversation conversation;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'message': message.toJson(),
    'conversation': conversation.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectMessageSent &&
          message == other.message &&
          conversation == other.conversation;

  @override
  int get hashCode => Object.hashAll(<Object?>[message, conversation]);
}

final class DiscoverFeed {
  const DiscoverFeed({required this.items});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DiscoverFeed.fromJson(Map<String, Object?> json) => DiscoverFeed(
    items: List<DiscoverItem>.unmodifiable(
      _readList(json['items'], 'DiscoverFeed.items').map(
        (Object? e0) =>
            DiscoverItem.fromJson(_readObject(e0, 'DiscoverFeed.items')),
      ),
    ),
  );

  /// Kısıtlar: maxItems: 50.
  final List<DiscoverItem> items;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final e0 in items) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverFeed && _deepEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(items)]);
}

final class DiscoverItem {
  const DiscoverItem({
    required this.event,
    required this.tayfa,
    required this.friends,
    required this.friendCount,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DiscoverItem.fromJson(Map<String, Object?> json) => DiscoverItem(
    event: DiscoverItemEvent.fromJson(
      _readObject(json['event'], 'DiscoverItem.event'),
    ),
    tayfa: DiscoverItemTayfa.fromJson(
      _readObject(json['tayfa'], 'DiscoverItem.tayfa'),
    ),
    friends: List<DiscoverPerson>.unmodifiable(
      _readList(json['friends'], 'DiscoverItem.friends').map(
        (Object? e0) =>
            DiscoverPerson.fromJson(_readObject(e0, 'DiscoverItem.friends')),
      ),
    ),
    friendCount: _readInt(json['friend_count'], 'DiscoverItem.friend_count'),
  );

  /// Açıklama, buluşma noktası ve koordinat yoktur.
  final DiscoverItemEvent event;

  /// Yalnızca olgular. `event_count` bitişinden 7 gün geçmiş, iptal
  /// edilmemiş etkinlikler; `attendance_count` bu etkinliklerdeki
  /// doğrulanmış katılımlar.
  final DiscoverItemTayfa tayfa;

  /// En çok 3 görünür arkadaş; yoksa boş dizi.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<DiscoverPerson> friends;

  /// Görünür arkadaşların tamamı (`friends` dahil); yoksa 0
  /// (ADR-0035; önceden en az 1'di).
  ///
  /// Kısıtlar: minimum: 0.
  final int friendCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'event': event.toJson(),
    'tayfa': tayfa.toJson(),
    'friends': <Object?>[for (final e0 in friends) e0.toJson()],
    'friend_count': friendCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItem &&
          event == other.event &&
          tayfa == other.tayfa &&
          _deepEquals(friends, other.friends) &&
          friendCount == other.friendCount;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[event, tayfa, _deepHash(friends), friendCount]);
}

/// Açıklama, buluşma noktası ve koordinat yoktur.
final class DiscoverItemEvent {
  const DiscoverItemEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.city,
    this.district,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DiscoverItemEvent.fromJson(Map<String, Object?> json) =>
      DiscoverItemEvent(
        id: _readString(json['id'], 'DiscoverItemEvent.id'),
        type: _readString(json['type'], 'DiscoverItemEvent.type'),
        title: _readString(json['title'], 'DiscoverItemEvent.title'),
        startsAt: _readDateTime(
          json['starts_at'],
          'DiscoverItemEvent.starts_at',
        ),
        endsAt: _readDateTime(json['ends_at'], 'DiscoverItemEvent.ends_at'),
        city: switch (json['city']) {
          null => null,
          final Object v => _readString(v, 'DiscoverItemEvent.city'),
        },
        district: switch (json['district']) {
          null => null,
          final Object v => _readString(v, 'DiscoverItemEvent.district'),
        },
      );

  final String id;

  final String type;

  final String title;

  final DateTime startsAt;

  final DateTime endsAt;

  final String? city;

  final String? district;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type,
    'title': title,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    if (city case final value?) 'city': value,
    if (district case final value?) 'district': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItemEvent &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          city == other.city &&
          district == other.district;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    type,
    title,
    startsAt,
    endsAt,
    city,
    district,
  ]);
}

/// Yalnızca olgular. `event_count` bitişinden 7 gün geçmiş, iptal
/// edilmemiş etkinlikler; `attendance_count` bu etkinliklerdeki
/// doğrulanmış katılımlar.
final class DiscoverItemTayfa {
  const DiscoverItemTayfa({
    required this.id,
    required this.name,
    this.description,
    this.city,
    required this.createdAt,
    required this.eventCount,
    required this.attendanceCount,
    this.showcase,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DiscoverItemTayfa.fromJson(Map<String, Object?> json) =>
      DiscoverItemTayfa(
        id: _readString(json['id'], 'DiscoverItemTayfa.id'),
        name: _readString(json['name'], 'DiscoverItemTayfa.name'),
        description: switch (json['description']) {
          null => null,
          final Object v => _readString(v, 'DiscoverItemTayfa.description'),
        },
        city: switch (json['city']) {
          null => null,
          final Object v => _readString(v, 'DiscoverItemTayfa.city'),
        },
        createdAt: _readDateTime(
          json['created_at'],
          'DiscoverItemTayfa.created_at',
        ),
        eventCount: _readInt(
          json['event_count'],
          'DiscoverItemTayfa.event_count',
        ),
        attendanceCount: _readInt(
          json['attendance_count'],
          'DiscoverItemTayfa.attendance_count',
        ),
        showcase: switch (json['showcase']) {
          null => null,
          final Object v => TayfaShowcase.fromJson(
            _readObject(v, 'DiscoverItemTayfa.showcase'),
          ),
        },
      );

  final String id;

  final String name;

  final String? description;

  final String? city;

  final DateTime createdAt;

  /// Kısıtlar: minimum: 0.
  final int eventCount;

  /// Kısıtlar: minimum: 0.
  final int attendanceCount;

  final TayfaShowcase? showcase;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    if (description case final value?) 'description': value,
    if (city case final value?) 'city': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'event_count': eventCount,
    'attendance_count': attendanceCount,
    if (showcase case final value?) 'showcase': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItemTayfa &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          city == other.city &&
          createdAt == other.createdAt &&
          eventCount == other.eventCount &&
          attendanceCount == other.attendanceCount &&
          showcase == other.showcase;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    name,
    description,
    city,
    createdAt,
    eventCount,
    attendanceCount,
    showcase,
  ]);
}

final class DiscoverPerson {
  const DiscoverPerson({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory DiscoverPerson.fromJson(Map<String, Object?> json) => DiscoverPerson(
    userId: _readString(json['user_id'], 'DiscoverPerson.user_id'),
    displayName: _readString(
      json['display_name'],
      'DiscoverPerson.display_name',
    ),
    avatarUploadId: switch (json['avatar_upload_id']) {
      null => null,
      final Object v => _readString(v, 'DiscoverPerson.avatar_upload_id'),
    },
  );

  final String userId;

  final String displayName;

  final String? avatarUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverPerson &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[userId, displayName, avatarUploadId]);
}

final class E2EArchiveEntry {
  const E2EArchiveEntry({
    required this.messageId,
    required this.conversationId,
    required this.keyVersion,
    required this.content,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EArchiveEntry.fromJson(
    Map<String, Object?> json,
  ) => E2EArchiveEntry(
    messageId: _readString(json['message_id'], 'E2EArchiveEntry.message_id'),
    conversationId: _readString(
      json['conversation_id'],
      'E2EArchiveEntry.conversation_id',
    ),
    keyVersion: _readInt(json['key_version'], 'E2EArchiveEntry.key_version'),
    content: _readString(json['content'], 'E2EArchiveEntry.content'),
    createdAt: _readDateTime(json['created_at'], 'E2EArchiveEntry.created_at'),
  );

  final String messageId;

  final String conversationId;

  final int keyVersion;

  /// Kısıtlar: biçim: standart base64.
  final String content;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'message_id': messageId,
    'conversation_id': conversationId,
    'key_version': keyVersion,
    'content': content,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EArchiveEntry &&
          messageId == other.messageId &&
          conversationId == other.conversationId &&
          keyVersion == other.keyVersion &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    messageId,
    conversationId,
    keyVersion,
    content,
    createdAt,
  ]);
}

final class E2EArchiveEntryList {
  const E2EArchiveEntryList({required this.entries, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EArchiveEntryList.fromJson(Map<String, Object?> json) =>
      E2EArchiveEntryList(
        entries: List<E2EArchiveEntry>.unmodifiable(
          _readList(json['entries'], 'E2EArchiveEntryList.entries').map(
            (Object? e0) => E2EArchiveEntry.fromJson(
              _readObject(e0, 'E2EArchiveEntryList.entries'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(
            v,
            'E2EArchiveEntryList.next_page_token',
          ),
        },
      );

  final List<E2EArchiveEntry> entries;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EArchiveEntryList &&
          _deepEquals(entries, other.entries) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(entries), nextPageToken]);
}

final class E2EArchiveWrite {
  const E2EArchiveWrite({
    required this.historyKeyVersion,
    required this.entries,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EArchiveWrite.fromJson(Map<String, Object?> json) =>
      E2EArchiveWrite(
        historyKeyVersion: _readInt(
          json['history_key_version'],
          'E2EArchiveWrite.history_key_version',
        ),
        entries: List<E2EArchiveWriteEntriesItem>.unmodifiable(
          _readList(json['entries'], 'E2EArchiveWrite.entries').map(
            (Object? e0) => E2EArchiveWriteEntriesItem.fromJson(
              _readObject(e0, 'E2EArchiveWrite.entries'),
            ),
          ),
        ),
      );

  /// Kısıtlar: minimum: 1; maximum: 32767.
  final int historyKeyVersion;

  /// Kısıtlar: minItems: 1; maxItems: 50.
  final List<E2EArchiveWriteEntriesItem> entries;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'history_key_version': historyKeyVersion,
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EArchiveWrite &&
          historyKeyVersion == other.historyKeyVersion &&
          _deepEquals(entries, other.entries);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[historyKeyVersion, _deepHash(entries)]);
}

final class E2EArchiveWriteEntriesItem {
  const E2EArchiveWriteEntriesItem({
    required this.messageId,
    required this.content,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EArchiveWriteEntriesItem.fromJson(Map<String, Object?> json) =>
      E2EArchiveWriteEntriesItem(
        messageId: _readString(
          json['message_id'],
          'E2EArchiveWriteEntriesItem.message_id',
        ),
        content: _readString(
          json['content'],
          'E2EArchiveWriteEntriesItem.content',
        ),
      );

  final String messageId;

  /// 1 B – 32 KiB.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String content;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'message_id': messageId,
    'content': content,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EArchiveWriteEntriesItem &&
          messageId == other.messageId &&
          content == other.content;

  @override
  int get hashCode => Object.hashAll(<Object?>[messageId, content]);
}

final class E2EArchiveWritten {
  const E2EArchiveWritten({required this.acceptedMessageIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EArchiveWritten.fromJson(Map<String, Object?> json) =>
      E2EArchiveWritten(
        acceptedMessageIds: List<String>.unmodifiable(
          _readList(
            json['accepted_message_ids'],
            'E2EArchiveWritten.accepted_message_ids',
          ).map(
            (Object? e0) =>
                _readString(e0, 'E2EArchiveWritten.accepted_message_ids'),
          ),
        ),
      );

  final List<String> acceptedMessageIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'accepted_message_ids': <Object?>[for (final e0 in acceptedMessageIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EArchiveWritten &&
          _deepEquals(acceptedMessageIds, other.acceptedMessageIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(acceptedMessageIds)]);
}

final class E2EBundleRequest {
  const E2EBundleRequest({this.deviceIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EBundleRequest.fromJson(Map<String, Object?> json) =>
      E2EBundleRequest(
        deviceIds: switch (json['device_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'E2EBundleRequest.device_ids').map(
              (Object? e0) => _readString(e0, 'E2EBundleRequest.device_ids'),
            ),
          ),
        },
      );

  /// Yalnızca bu cihazlar; boşsa tüm cihazlar.
  ///
  /// Kısıtlar: maxItems: 5.
  final List<String>? deviceIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (deviceIds case final value?)
      'device_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EBundleRequest && _deepEquals(deviceIds, other.deviceIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(deviceIds)]);
}

final class E2EDevice {
  const E2EDevice({
    required this.id,
    required this.deviceNumber,
    required this.registrationId,
    required this.identityKey,
    required this.paired,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EDevice.fromJson(Map<String, Object?> json) => E2EDevice(
    id: _readString(json['id'], 'E2EDevice.id'),
    deviceNumber: _readInt(json['device_number'], 'E2EDevice.device_number'),
    registrationId: _readInt(
      json['registration_id'],
      'E2EDevice.registration_id',
    ),
    identityKey: _readString(json['identity_key'], 'E2EDevice.identity_key'),
    paired: _readBool(json['paired'], 'E2EDevice.paired'),
    createdAt: _readDateTime(json['created_at'], 'E2EDevice.created_at'),
  );

  final String id;

  /// Signal adresindeki cihaz numarası.
  ///
  /// Kısıtlar: minimum: 1; maximum: 127.
  final int deviceNumber;

  final int registrationId;

  /// Kısıtlar: biçim: standart base64.
  final String identityKey;

  /// Cihaz geçmiş anahtarını biliyor (arşive yazar ve okur).
  final bool paired;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'device_number': deviceNumber,
    'registration_id': registrationId,
    'identity_key': identityKey,
    'paired': paired,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EDevice &&
          id == other.id &&
          deviceNumber == other.deviceNumber &&
          registrationId == other.registrationId &&
          identityKey == other.identityKey &&
          paired == other.paired &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    deviceNumber,
    registrationId,
    identityKey,
    paired,
    createdAt,
  ]);
}

final class E2EDeviceRegistered {
  const E2EDeviceRegistered({required this.device, required this.prekeyCounts});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EDeviceRegistered.fromJson(Map<String, Object?> json) =>
      E2EDeviceRegistered(
        device: E2EDevice.fromJson(
          _readObject(json['device'], 'E2EDeviceRegistered.device'),
        ),
        prekeyCounts: E2EPreKeyCounts.fromJson(
          _readObject(
            json['prekey_counts'],
            'E2EDeviceRegistered.prekey_counts',
          ),
        ),
      );

  final E2EDevice device;

  final E2EPreKeyCounts prekeyCounts;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'device': device.toJson(),
    'prekey_counts': prekeyCounts.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EDeviceRegistered &&
          device == other.device &&
          prekeyCounts == other.prekeyCounts;

  @override
  int get hashCode => Object.hashAll(<Object?>[device, prekeyCounts]);
}

final class E2EDeviceRegistration {
  const E2EDeviceRegistration({
    required this.registrationId,
    required this.identityKey,
    required this.signedPrekey,
    required this.kyberLastResortPrekey,
    this.oneTimePrekeys,
    this.kyberPrekeys,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EDeviceRegistration.fromJson(Map<String, Object?> json) =>
      E2EDeviceRegistration(
        registrationId: _readInt(
          json['registration_id'],
          'E2EDeviceRegistration.registration_id',
        ),
        identityKey: _readString(
          json['identity_key'],
          'E2EDeviceRegistration.identity_key',
        ),
        signedPrekey: E2ESignedPreKey.fromJson(
          _readObject(
            json['signed_prekey'],
            'E2EDeviceRegistration.signed_prekey',
          ),
        ),
        kyberLastResortPrekey: E2ESignedPreKey.fromJson(
          _readObject(
            json['kyber_last_resort_prekey'],
            'E2EDeviceRegistration.kyber_last_resort_prekey',
          ),
        ),
        oneTimePrekeys: switch (json['one_time_prekeys']) {
          null => null,
          final Object v => List<E2EPreKey>.unmodifiable(
            _readList(v, 'E2EDeviceRegistration.one_time_prekeys').map(
              (Object? e0) => E2EPreKey.fromJson(
                _readObject(e0, 'E2EDeviceRegistration.one_time_prekeys'),
              ),
            ),
          ),
        },
        kyberPrekeys: switch (json['kyber_prekeys']) {
          null => null,
          final Object v => List<E2ESignedPreKey>.unmodifiable(
            _readList(v, 'E2EDeviceRegistration.kyber_prekeys').map(
              (Object? e0) => E2ESignedPreKey.fromJson(
                _readObject(e0, 'E2EDeviceRegistration.kyber_prekeys'),
              ),
            ),
          ),
        },
      );

  /// Kısıtlar: minimum: 1; maximum: 16380.
  final int registrationId;

  /// 33 bayt, 0x05 ile başlar.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String identityKey;

  final E2ESignedPreKey signedPrekey;

  final E2ESignedPreKey kyberLastResortPrekey;

  /// Kısıtlar: maxItems: 100.
  final List<E2EPreKey>? oneTimePrekeys;

  /// Kısıtlar: maxItems: 100.
  final List<E2ESignedPreKey>? kyberPrekeys;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'registration_id': registrationId,
    'identity_key': identityKey,
    'signed_prekey': signedPrekey.toJson(),
    'kyber_last_resort_prekey': kyberLastResortPrekey.toJson(),
    if (oneTimePrekeys case final value?)
      'one_time_prekeys': <Object?>[for (final e0 in value) e0.toJson()],
    if (kyberPrekeys case final value?)
      'kyber_prekeys': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EDeviceRegistration &&
          registrationId == other.registrationId &&
          identityKey == other.identityKey &&
          signedPrekey == other.signedPrekey &&
          kyberLastResortPrekey == other.kyberLastResortPrekey &&
          _deepEquals(oneTimePrekeys, other.oneTimePrekeys) &&
          _deepEquals(kyberPrekeys, other.kyberPrekeys);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    registrationId,
    identityKey,
    signedPrekey,
    kyberLastResortPrekey,
    _deepHash(oneTimePrekeys),
    _deepHash(kyberPrekeys),
  ]);
}

final class E2EDeviceState {
  const E2EDeviceState({
    required this.device,
    required this.prekeyCounts,
    required this.historyKeyVersion,
    required this.rotationNeeded,
    required this.otherPairedDevice,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EDeviceState.fromJson(Map<String, Object?> json) => E2EDeviceState(
    device: E2EDevice.fromJson(
      _readObject(json['device'], 'E2EDeviceState.device'),
    ),
    prekeyCounts: E2EPreKeyCounts.fromJson(
      _readObject(json['prekey_counts'], 'E2EDeviceState.prekey_counts'),
    ),
    historyKeyVersion: _readInt(
      json['history_key_version'],
      'E2EDeviceState.history_key_version',
    ),
    rotationNeeded: _readBool(
      json['rotation_needed'],
      'E2EDeviceState.rotation_needed',
    ),
    otherPairedDevice: _readBool(
      json['other_paired_device'],
      'E2EDeviceState.other_paired_device',
    ),
  );

  final E2EDevice device;

  final E2EPreKeyCounts prekeyCounts;

  /// Hesabın geçmiş anahtarı sürümü; ilk cihaz anahtar alana kadar 0.
  final int historyKeyVersion;

  /// Eşleştirilmiş bir cihaz kaldırıldı; eşleştirilmiş bir cihaz anahtarı yenilemeli.
  final bool rotationNeeded;

  /// Hesabın eşleştirilmiş başka cihazı var (QR eşleştirme önerin).
  final bool otherPairedDevice;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'device': device.toJson(),
    'prekey_counts': prekeyCounts.toJson(),
    'history_key_version': historyKeyVersion,
    'rotation_needed': rotationNeeded,
    'other_paired_device': otherPairedDevice,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EDeviceState &&
          device == other.device &&
          prekeyCounts == other.prekeyCounts &&
          historyKeyVersion == other.historyKeyVersion &&
          rotationNeeded == other.rotationNeeded &&
          otherPairedDevice == other.otherPairedDevice;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    device,
    prekeyCounts,
    historyKeyVersion,
    rotationNeeded,
    otherPairedDevice,
  ]);
}

/// `e2e-devices-changed` (409) cevabının ek alanları; cihaz listelerini
/// tazeleyip tekrar deneyin.
final class E2EDevicesChangedProblem {
  const E2EDevicesChangedProblem({
    required this.type,
    required this.title,
    required this.status,
    this.detail,
    this.instance,
    this.requestId,
    required this.missingDeviceIds,
    required this.staleDeviceIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EDevicesChangedProblem.fromJson(Map<String, Object?> json) =>
      E2EDevicesChangedProblem(
        type: _readString(json['type'], 'E2EDevicesChangedProblem.type'),
        title: _readString(json['title'], 'E2EDevicesChangedProblem.title'),
        status: _readInt(json['status'], 'E2EDevicesChangedProblem.status'),
        detail: switch (json['detail']) {
          null => null,
          final Object v => _readString(v, 'E2EDevicesChangedProblem.detail'),
        },
        instance: switch (json['instance']) {
          null => null,
          final Object v => _readString(v, 'E2EDevicesChangedProblem.instance'),
        },
        requestId: switch (json['request_id']) {
          null => null,
          final Object v => _readString(
            v,
            'E2EDevicesChangedProblem.request_id',
          ),
        },
        missingDeviceIds: List<String>.unmodifiable(
          _readList(
            json['missing_device_ids'],
            'E2EDevicesChangedProblem.missing_device_ids',
          ).map(
            (Object? e0) =>
                _readString(e0, 'E2EDevicesChangedProblem.missing_device_ids'),
          ),
        ),
        staleDeviceIds: List<String>.unmodifiable(
          _readList(
            json['stale_device_ids'],
            'E2EDevicesChangedProblem.stale_device_ids',
          ).map(
            (Object? e0) =>
                _readString(e0, 'E2EDevicesChangedProblem.stale_device_ids'),
          ),
        ),
      );

  final String type;

  final String title;

  final int status;

  final String? detail;

  final String? instance;

  final String? requestId;

  /// Zarf (ya da paylaşım) eksik cihazlar.
  final List<String> missingDeviceIds;

  /// Artık olmayan, değişmiş ya da iki kez verilen cihazlar.
  final List<String> staleDeviceIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'title': title,
    'status': status,
    if (detail case final value?) 'detail': value,
    if (instance case final value?) 'instance': value,
    if (requestId case final value?) 'request_id': value,
    'missing_device_ids': <Object?>[for (final e0 in missingDeviceIds) e0],
    'stale_device_ids': <Object?>[for (final e0 in staleDeviceIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EDevicesChangedProblem &&
          type == other.type &&
          title == other.title &&
          status == other.status &&
          detail == other.detail &&
          instance == other.instance &&
          requestId == other.requestId &&
          _deepEquals(missingDeviceIds, other.missingDeviceIds) &&
          _deepEquals(staleDeviceIds, other.staleDeviceIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    type,
    title,
    status,
    detail,
    instance,
    requestId,
    _deepHash(missingDeviceIds),
    _deepHash(staleDeviceIds),
  ]);
}

final class E2EEnvelope {
  const E2EEnvelope({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDeviceId,
    required this.senderDeviceNumber,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EEnvelope.fromJson(Map<String, Object?> json) => E2EEnvelope(
    id: _readString(json['id'], 'E2EEnvelope.id'),
    messageId: _readString(json['message_id'], 'E2EEnvelope.message_id'),
    conversationId: _readString(
      json['conversation_id'],
      'E2EEnvelope.conversation_id',
    ),
    senderUserId: _readString(
      json['sender_user_id'],
      'E2EEnvelope.sender_user_id',
    ),
    senderDeviceId: _readString(
      json['sender_device_id'],
      'E2EEnvelope.sender_device_id',
    ),
    senderDeviceNumber: _readInt(
      json['sender_device_number'],
      'E2EEnvelope.sender_device_number',
    ),
    type: E2EEnvelopeType.fromWire(
      _readString(json['type'], 'E2EEnvelope.type'),
    ),
    content: _readString(json['content'], 'E2EEnvelope.content'),
    createdAt: _readDateTime(json['created_at'], 'E2EEnvelope.created_at'),
  );

  final String id;

  final String messageId;

  final String conversationId;

  final String senderUserId;

  final String senderDeviceId;

  final int senderDeviceNumber;

  final E2EEnvelopeType type;

  /// Kısıtlar: biçim: standart base64.
  final String content;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'message_id': messageId,
    'conversation_id': conversationId,
    'sender_user_id': senderUserId,
    'sender_device_id': senderDeviceId,
    'sender_device_number': senderDeviceNumber,
    'type': type.wire,
    'content': content,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EEnvelope &&
          id == other.id &&
          messageId == other.messageId &&
          conversationId == other.conversationId &&
          senderUserId == other.senderUserId &&
          senderDeviceId == other.senderDeviceId &&
          senderDeviceNumber == other.senderDeviceNumber &&
          type == other.type &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    messageId,
    conversationId,
    senderUserId,
    senderDeviceId,
    senderDeviceNumber,
    type,
    content,
    createdAt,
  ]);
}

final class E2EEnvelopeAck {
  const E2EEnvelopeAck({required this.envelopeIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EEnvelopeAck.fromJson(Map<String, Object?> json) => E2EEnvelopeAck(
    envelopeIds: List<String>.unmodifiable(
      _readList(
        json['envelope_ids'],
        'E2EEnvelopeAck.envelope_ids',
      ).map((Object? e0) => _readString(e0, 'E2EEnvelopeAck.envelope_ids')),
    ),
  );

  /// Kısıtlar: minItems: 1; maxItems: 100.
  final List<String> envelopeIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'envelope_ids': <Object?>[for (final e0 in envelopeIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EEnvelopeAck && _deepEquals(envelopeIds, other.envelopeIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(envelopeIds)]);
}

final class E2EEnvelopeList {
  const E2EEnvelopeList({required this.envelopes, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EEnvelopeList.fromJson(Map<String, Object?> json) =>
      E2EEnvelopeList(
        envelopes: List<E2EEnvelope>.unmodifiable(
          _readList(json['envelopes'], 'E2EEnvelopeList.envelopes').map(
            (Object? e0) => E2EEnvelope.fromJson(
              _readObject(e0, 'E2EEnvelopeList.envelopes'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'E2EEnvelopeList.next_page_token'),
        },
      );

  final List<E2EEnvelope> envelopes;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'envelopes': <Object?>[for (final e0 in envelopes) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EEnvelopeList &&
          _deepEquals(envelopes, other.envelopes) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(envelopes), nextPageToken]);
}

enum E2EEnvelopeType {
  whisper('whisper'),
  prekey('prekey'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const E2EEnvelopeType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('E2EEnvelopeType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static E2EEnvelopeType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class E2EHistoryKeyRotation {
  const E2EHistoryKeyRotation({
    required this.historyKeyVersion,
    required this.shares,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EHistoryKeyRotation.fromJson(Map<String, Object?> json) =>
      E2EHistoryKeyRotation(
        historyKeyVersion: _readInt(
          json['history_key_version'],
          'E2EHistoryKeyRotation.history_key_version',
        ),
        shares: List<E2EHistoryKeyRotationSharesItem>.unmodifiable(
          _readList(json['shares'], 'E2EHistoryKeyRotation.shares').map(
            (Object? e0) => E2EHistoryKeyRotationSharesItem.fromJson(
              _readObject(e0, 'E2EHistoryKeyRotation.shares'),
            ),
          ),
        ),
      );

  /// Kısıtlar: minimum: 1; maximum: 32767.
  final int historyKeyVersion;

  /// Kısıtlar: maxItems: 5.
  final List<E2EHistoryKeyRotationSharesItem> shares;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'history_key_version': historyKeyVersion,
    'shares': <Object?>[for (final e0 in shares) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EHistoryKeyRotation &&
          historyKeyVersion == other.historyKeyVersion &&
          _deepEquals(shares, other.shares);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[historyKeyVersion, _deepHash(shares)]);
}

final class E2EHistoryKeyRotationSharesItem {
  const E2EHistoryKeyRotationSharesItem({
    required this.deviceId,
    required this.bundle,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EHistoryKeyRotationSharesItem.fromJson(Map<String, Object?> json) =>
      E2EHistoryKeyRotationSharesItem(
        deviceId: _readString(
          json['device_id'],
          'E2EHistoryKeyRotationSharesItem.device_id',
        ),
        bundle: _readString(
          json['bundle'],
          'E2EHistoryKeyRotationSharesItem.bundle',
        ),
      );

  final String deviceId;

  /// 1 B – 16 KiB.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String bundle;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'device_id': deviceId,
    'bundle': bundle,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EHistoryKeyRotationSharesItem &&
          deviceId == other.deviceId &&
          bundle == other.bundle;

  @override
  int get hashCode => Object.hashAll(<Object?>[deviceId, bundle]);
}

final class E2EHistoryKeyShare {
  const E2EHistoryKeyShare({
    required this.id,
    required this.senderDeviceId,
    required this.historyKeyVersion,
    required this.bundle,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EHistoryKeyShare.fromJson(Map<String, Object?> json) =>
      E2EHistoryKeyShare(
        id: _readString(json['id'], 'E2EHistoryKeyShare.id'),
        senderDeviceId: _readString(
          json['sender_device_id'],
          'E2EHistoryKeyShare.sender_device_id',
        ),
        historyKeyVersion: _readInt(
          json['history_key_version'],
          'E2EHistoryKeyShare.history_key_version',
        ),
        bundle: _readString(json['bundle'], 'E2EHistoryKeyShare.bundle'),
        createdAt: _readDateTime(
          json['created_at'],
          'E2EHistoryKeyShare.created_at',
        ),
      );

  final String id;

  final String senderDeviceId;

  final int historyKeyVersion;

  /// Kısıtlar: biçim: standart base64.
  final String bundle;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sender_device_id': senderDeviceId,
    'history_key_version': historyKeyVersion,
    'bundle': bundle,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EHistoryKeyShare &&
          id == other.id &&
          senderDeviceId == other.senderDeviceId &&
          historyKeyVersion == other.historyKeyVersion &&
          bundle == other.bundle &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    senderDeviceId,
    historyKeyVersion,
    bundle,
    createdAt,
  ]);
}

final class E2EHistoryKeyShareList {
  const E2EHistoryKeyShareList({required this.shares});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EHistoryKeyShareList.fromJson(Map<String, Object?> json) =>
      E2EHistoryKeyShareList(
        shares: List<E2EHistoryKeyShare>.unmodifiable(
          _readList(json['shares'], 'E2EHistoryKeyShareList.shares').map(
            (Object? e0) => E2EHistoryKeyShare.fromJson(
              _readObject(e0, 'E2EHistoryKeyShareList.shares'),
            ),
          ),
        ),
      );

  final List<E2EHistoryKeyShare> shares;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'shares': <Object?>[for (final e0 in shares) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EHistoryKeyShareList && _deepEquals(shares, other.shares);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(shares)]);
}

final class E2EHistoryKeyVersion {
  const E2EHistoryKeyVersion({required this.historyKeyVersion});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EHistoryKeyVersion.fromJson(Map<String, Object?> json) =>
      E2EHistoryKeyVersion(
        historyKeyVersion: _readInt(
          json['history_key_version'],
          'E2EHistoryKeyVersion.history_key_version',
        ),
      );

  final int historyKeyVersion;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'history_key_version': historyKeyVersion,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EHistoryKeyVersion &&
          historyKeyVersion == other.historyKeyVersion;

  @override
  int get hashCode => Object.hashAll(<Object?>[historyKeyVersion]);
}

final class E2EKeyEvent {
  const E2EKeyEvent({
    required this.id,
    required this.deviceId,
    required this.deviceNumber,
    required this.type,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EKeyEvent.fromJson(Map<String, Object?> json) => E2EKeyEvent(
    id: _readString(json['id'], 'E2EKeyEvent.id'),
    deviceId: _readString(json['device_id'], 'E2EKeyEvent.device_id'),
    deviceNumber: _readInt(json['device_number'], 'E2EKeyEvent.device_number'),
    type: E2EKeyEventType.fromWire(
      _readString(json['type'], 'E2EKeyEvent.type'),
    ),
    createdAt: _readDateTime(json['created_at'], 'E2EKeyEvent.created_at'),
  );

  final String id;

  final String deviceId;

  final int deviceNumber;

  /// `identity_changed` yazılmaz (yeni kimlik anahtarı yeni cihazdır); ileriye dönük.
  final E2EKeyEventType type;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'device_id': deviceId,
    'device_number': deviceNumber,
    'type': type.wire,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EKeyEvent &&
          id == other.id &&
          deviceId == other.deviceId &&
          deviceNumber == other.deviceNumber &&
          type == other.type &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, deviceId, deviceNumber, type, createdAt]);
}

final class E2EKeyEventList {
  const E2EKeyEventList({required this.events, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EKeyEventList.fromJson(Map<String, Object?> json) =>
      E2EKeyEventList(
        events: List<E2EKeyEvent>.unmodifiable(
          _readList(json['events'], 'E2EKeyEventList.events').map(
            (Object? e0) =>
                E2EKeyEvent.fromJson(_readObject(e0, 'E2EKeyEventList.events')),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'E2EKeyEventList.next_page_token'),
        },
      );

  final List<E2EKeyEvent> events;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'events': <Object?>[for (final e0 in events) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EKeyEventList &&
          _deepEquals(events, other.events) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(events), nextPageToken]);
}

/// `identity_changed` yazılmaz (yeni kimlik anahtarı yeni cihazdır); ileriye dönük.
enum E2EKeyEventType {
  deviceAdded('device_added'),
  deviceRemoved('device_removed'),
  identityChanged('identity_changed'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const E2EKeyEventType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('E2EKeyEventType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static E2EKeyEventType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class E2ELinkAnswer {
  const E2ELinkAnswer({required this.historyKeyVersion, required this.answer});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2ELinkAnswer.fromJson(Map<String, Object?> json) => E2ELinkAnswer(
    historyKeyVersion: _readInt(
      json['history_key_version'],
      'E2ELinkAnswer.history_key_version',
    ),
    answer: _readString(json['answer'], 'E2ELinkAnswer.answer'),
  );

  /// Kısıtlar: minimum: 1; maximum: 32767.
  final int historyKeyVersion;

  /// 1 B – 16 KiB.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String answer;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'history_key_version': historyKeyVersion,
    'answer': answer,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2ELinkAnswer &&
          historyKeyVersion == other.historyKeyVersion &&
          answer == other.answer;

  @override
  int get hashCode => Object.hashAll(<Object?>[historyKeyVersion, answer]);
}

final class E2ELinkRequest {
  const E2ELinkRequest({
    required this.linkRequestId,
    required this.expiresAt,
    required this.answered,
    this.answer,
    this.historyKeyVersion,
    this.answeredByDeviceId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2ELinkRequest.fromJson(Map<String, Object?> json) => E2ELinkRequest(
    linkRequestId: _readString(
      json['link_request_id'],
      'E2ELinkRequest.link_request_id',
    ),
    expiresAt: _readDateTime(json['expires_at'], 'E2ELinkRequest.expires_at'),
    answered: _readBool(json['answered'], 'E2ELinkRequest.answered'),
    answer: switch (json['answer']) {
      null => null,
      final Object v => _readString(v, 'E2ELinkRequest.answer'),
    },
    historyKeyVersion: switch (json['history_key_version']) {
      null => null,
      final Object v => _readInt(v, 'E2ELinkRequest.history_key_version'),
    },
    answeredByDeviceId: switch (json['answered_by_device_id']) {
      null => null,
      final Object v => _readString(v, 'E2ELinkRequest.answered_by_device_id'),
    },
  );

  final String linkRequestId;

  final DateTime expiresAt;

  final bool answered;

  /// Cevaplanınca.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String? answer;

  /// Cevaplanınca.
  final int? historyKeyVersion;

  /// Cevaplanınca.
  final String? answeredByDeviceId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'link_request_id': linkRequestId,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'answered': answered,
    if (answer case final value?) 'answer': value,
    if (historyKeyVersion case final value?) 'history_key_version': value,
    if (answeredByDeviceId case final value?) 'answered_by_device_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2ELinkRequest &&
          linkRequestId == other.linkRequestId &&
          expiresAt == other.expiresAt &&
          answered == other.answered &&
          answer == other.answer &&
          historyKeyVersion == other.historyKeyVersion &&
          answeredByDeviceId == other.answeredByDeviceId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    linkRequestId,
    expiresAt,
    answered,
    answer,
    historyKeyVersion,
    answeredByDeviceId,
  ]);
}

final class E2ELinkRequestCreated {
  const E2ELinkRequestCreated({
    required this.linkRequestId,
    required this.expiresAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2ELinkRequestCreated.fromJson(Map<String, Object?> json) =>
      E2ELinkRequestCreated(
        linkRequestId: _readString(
          json['link_request_id'],
          'E2ELinkRequestCreated.link_request_id',
        ),
        expiresAt: _readDateTime(
          json['expires_at'],
          'E2ELinkRequestCreated.expires_at',
        ),
      );

  final String linkRequestId;

  final DateTime expiresAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'link_request_id': linkRequestId,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2ELinkRequestCreated &&
          linkRequestId == other.linkRequestId &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[linkRequestId, expiresAt]);
}

final class E2EPreKey {
  const E2EPreKey({required this.keyId, required this.publicKey});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPreKey.fromJson(Map<String, Object?> json) => E2EPreKey(
    keyId: _readInt(json['key_id'], 'E2EPreKey.key_id'),
    publicKey: _readString(json['public_key'], 'E2EPreKey.public_key'),
  );

  /// Kısıtlar: minimum: 0; maximum: 16777215.
  final int keyId;

  /// 33 bayt, 0x05 ile başlar.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String publicKey;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key_id': keyId,
    'public_key': publicKey,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPreKey &&
          keyId == other.keyId &&
          publicKey == other.publicKey;

  @override
  int get hashCode => Object.hashAll(<Object?>[keyId, publicKey]);
}

final class E2EPreKeyBundle {
  const E2EPreKeyBundle({
    required this.deviceId,
    required this.deviceNumber,
    required this.registrationId,
    required this.identityKey,
    required this.signedPrekey,
    this.oneTimePrekey,
    required this.kyberPrekey,
    required this.kyberLastResort,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPreKeyBundle.fromJson(Map<String, Object?> json) =>
      E2EPreKeyBundle(
        deviceId: _readString(json['device_id'], 'E2EPreKeyBundle.device_id'),
        deviceNumber: _readInt(
          json['device_number'],
          'E2EPreKeyBundle.device_number',
        ),
        registrationId: _readInt(
          json['registration_id'],
          'E2EPreKeyBundle.registration_id',
        ),
        identityKey: _readString(
          json['identity_key'],
          'E2EPreKeyBundle.identity_key',
        ),
        signedPrekey: E2ESignedPreKey.fromJson(
          _readObject(json['signed_prekey'], 'E2EPreKeyBundle.signed_prekey'),
        ),
        oneTimePrekey: switch (json['one_time_prekey']) {
          null => null,
          final Object v => E2EPreKey.fromJson(
            _readObject(v, 'E2EPreKeyBundle.one_time_prekey'),
          ),
        },
        kyberPrekey: E2ESignedPreKey.fromJson(
          _readObject(json['kyber_prekey'], 'E2EPreKeyBundle.kyber_prekey'),
        ),
        kyberLastResort: _readBool(
          json['kyber_last_resort'],
          'E2EPreKeyBundle.kyber_last_resort',
        ),
      );

  final String deviceId;

  final int deviceNumber;

  final int registrationId;

  /// Kısıtlar: biçim: standart base64.
  final String identityKey;

  final E2ESignedPreKey signedPrekey;

  final E2EPreKey? oneTimePrekey;

  final E2ESignedPreKey kyberPrekey;

  final bool kyberLastResort;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'device_id': deviceId,
    'device_number': deviceNumber,
    'registration_id': registrationId,
    'identity_key': identityKey,
    'signed_prekey': signedPrekey.toJson(),
    if (oneTimePrekey case final value?) 'one_time_prekey': value.toJson(),
    'kyber_prekey': kyberPrekey.toJson(),
    'kyber_last_resort': kyberLastResort,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPreKeyBundle &&
          deviceId == other.deviceId &&
          deviceNumber == other.deviceNumber &&
          registrationId == other.registrationId &&
          identityKey == other.identityKey &&
          signedPrekey == other.signedPrekey &&
          oneTimePrekey == other.oneTimePrekey &&
          kyberPrekey == other.kyberPrekey &&
          kyberLastResort == other.kyberLastResort;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    deviceId,
    deviceNumber,
    registrationId,
    identityKey,
    signedPrekey,
    oneTimePrekey,
    kyberPrekey,
    kyberLastResort,
  ]);
}

final class E2EPreKeyBundleList {
  const E2EPreKeyBundleList({required this.bundles});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPreKeyBundleList.fromJson(Map<String, Object?> json) =>
      E2EPreKeyBundleList(
        bundles: List<E2EPreKeyBundle>.unmodifiable(
          _readList(json['bundles'], 'E2EPreKeyBundleList.bundles').map(
            (Object? e0) => E2EPreKeyBundle.fromJson(
              _readObject(e0, 'E2EPreKeyBundleList.bundles'),
            ),
          ),
        ),
      );

  final List<E2EPreKeyBundle> bundles;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'bundles': <Object?>[for (final e0 in bundles) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPreKeyBundleList && _deepEquals(bundles, other.bundles);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(bundles)]);
}

final class E2EPreKeyCounts {
  const E2EPreKeyCounts({
    required this.ec,
    required this.kyber,
    required this.low,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPreKeyCounts.fromJson(Map<String, Object?> json) =>
      E2EPreKeyCounts(
        ec: _readInt(json['ec'], 'E2EPreKeyCounts.ec'),
        kyber: _readInt(json['kyber'], 'E2EPreKeyCounts.kyber'),
        low: _readBool(json['low'], 'E2EPreKeyCounts.low'),
      );

  final int ec;

  final int kyber;

  /// Bir türden 10'dan az kaldı; yükleyin.
  final bool low;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'ec': ec,
    'kyber': kyber,
    'low': low,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPreKeyCounts &&
          ec == other.ec &&
          kyber == other.kyber &&
          low == other.low;

  @override
  int get hashCode => Object.hashAll(<Object?>[ec, kyber, low]);
}

final class E2EPreKeyUpload {
  const E2EPreKeyUpload({
    this.signedPrekey,
    this.kyberLastResortPrekey,
    this.oneTimePrekeys,
    this.kyberPrekeys,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPreKeyUpload.fromJson(Map<String, Object?> json) =>
      E2EPreKeyUpload(
        signedPrekey: switch (json['signed_prekey']) {
          null => null,
          final Object v => E2ESignedPreKey.fromJson(
            _readObject(v, 'E2EPreKeyUpload.signed_prekey'),
          ),
        },
        kyberLastResortPrekey: switch (json['kyber_last_resort_prekey']) {
          null => null,
          final Object v => E2ESignedPreKey.fromJson(
            _readObject(v, 'E2EPreKeyUpload.kyber_last_resort_prekey'),
          ),
        },
        oneTimePrekeys: switch (json['one_time_prekeys']) {
          null => null,
          final Object v => List<E2EPreKey>.unmodifiable(
            _readList(v, 'E2EPreKeyUpload.one_time_prekeys').map(
              (Object? e0) => E2EPreKey.fromJson(
                _readObject(e0, 'E2EPreKeyUpload.one_time_prekeys'),
              ),
            ),
          ),
        },
        kyberPrekeys: switch (json['kyber_prekeys']) {
          null => null,
          final Object v => List<E2ESignedPreKey>.unmodifiable(
            _readList(v, 'E2EPreKeyUpload.kyber_prekeys').map(
              (Object? e0) => E2ESignedPreKey.fromJson(
                _readObject(e0, 'E2EPreKeyUpload.kyber_prekeys'),
              ),
            ),
          ),
        },
      );

  final E2ESignedPreKey? signedPrekey;

  final E2ESignedPreKey? kyberLastResortPrekey;

  /// Kısıtlar: maxItems: 100.
  final List<E2EPreKey>? oneTimePrekeys;

  /// Kısıtlar: maxItems: 100.
  final List<E2ESignedPreKey>? kyberPrekeys;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (signedPrekey case final value?) 'signed_prekey': value.toJson(),
    if (kyberLastResortPrekey case final value?)
      'kyber_last_resort_prekey': value.toJson(),
    if (oneTimePrekeys case final value?)
      'one_time_prekeys': <Object?>[for (final e0 in value) e0.toJson()],
    if (kyberPrekeys case final value?)
      'kyber_prekeys': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPreKeyUpload &&
          signedPrekey == other.signedPrekey &&
          kyberLastResortPrekey == other.kyberLastResortPrekey &&
          _deepEquals(oneTimePrekeys, other.oneTimePrekeys) &&
          _deepEquals(kyberPrekeys, other.kyberPrekeys);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    signedPrekey,
    kyberLastResortPrekey,
    _deepHash(oneTimePrekeys),
    _deepHash(kyberPrekeys),
  ]);
}

final class E2EPublicDevice {
  const E2EPublicDevice({
    required this.id,
    required this.deviceNumber,
    required this.registrationId,
    required this.identityKey,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPublicDevice.fromJson(Map<String, Object?> json) =>
      E2EPublicDevice(
        id: _readString(json['id'], 'E2EPublicDevice.id'),
        deviceNumber: _readInt(
          json['device_number'],
          'E2EPublicDevice.device_number',
        ),
        registrationId: _readInt(
          json['registration_id'],
          'E2EPublicDevice.registration_id',
        ),
        identityKey: _readString(
          json['identity_key'],
          'E2EPublicDevice.identity_key',
        ),
        createdAt: _readDateTime(
          json['created_at'],
          'E2EPublicDevice.created_at',
        ),
      );

  final String id;

  final int deviceNumber;

  final int registrationId;

  /// Kısıtlar: biçim: standart base64.
  final String identityKey;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'device_number': deviceNumber,
    'registration_id': registrationId,
    'identity_key': identityKey,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPublicDevice &&
          id == other.id &&
          deviceNumber == other.deviceNumber &&
          registrationId == other.registrationId &&
          identityKey == other.identityKey &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    deviceNumber,
    registrationId,
    identityKey,
    createdAt,
  ]);
}

final class E2EPublicDeviceList {
  const E2EPublicDeviceList({required this.devices});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EPublicDeviceList.fromJson(Map<String, Object?> json) =>
      E2EPublicDeviceList(
        devices: List<E2EPublicDevice>.unmodifiable(
          _readList(json['devices'], 'E2EPublicDeviceList.devices').map(
            (Object? e0) => E2EPublicDevice.fromJson(
              _readObject(e0, 'E2EPublicDeviceList.devices'),
            ),
          ),
        ),
      );

  final List<E2EPublicDevice> devices;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'devices': <Object?>[for (final e0 in devices) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EPublicDeviceList && _deepEquals(devices, other.devices);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(devices)]);
}

final class E2EShareAck {
  const E2EShareAck({required this.shareIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2EShareAck.fromJson(Map<String, Object?> json) => E2EShareAck(
    shareIds: List<String>.unmodifiable(
      _readList(
        json['share_ids'],
        'E2EShareAck.share_ids',
      ).map((Object? e0) => _readString(e0, 'E2EShareAck.share_ids')),
    ),
  );

  /// Kısıtlar: minItems: 1; maxItems: 100.
  final List<String> shareIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'share_ids': <Object?>[for (final e0 in shareIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2EShareAck && _deepEquals(shareIds, other.shareIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(shareIds)]);
}

final class E2ESignedPreKey {
  const E2ESignedPreKey({
    required this.keyId,
    required this.publicKey,
    required this.signature,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory E2ESignedPreKey.fromJson(Map<String, Object?> json) =>
      E2ESignedPreKey(
        keyId: _readInt(json['key_id'], 'E2ESignedPreKey.key_id'),
        publicKey: _readString(
          json['public_key'],
          'E2ESignedPreKey.public_key',
        ),
        signature: _readString(json['signature'], 'E2ESignedPreKey.signature'),
      );

  /// Kısıtlar: minimum: 0; maximum: 16777215.
  final int keyId;

  /// EC imzalı ön anahtarda 33 bayt (0x05 ile), Kyber'de 1569 bayt.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String publicKey;

  /// 64 bayt.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String signature;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key_id': keyId,
    'public_key': publicKey,
    'signature': signature,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is E2ESignedPreKey &&
          keyId == other.keyId &&
          publicKey == other.publicKey &&
          signature == other.signature;

  @override
  int get hashCode => Object.hashAll(<Object?>[keyId, publicKey, signature]);
}

/// Kazanılmış bir rozet (#258, ADR-0039 §2). Adı ve ikonu katalogdaki
/// aynı anahtarlı `CatalogBadge`'dedir. Rozet geri alınmaz: etkinlik ya
/// da tayfa sonradan silinse de kalır.
final class EarnedBadge {
  const EarnedBadge({
    required this.badgeKey,
    this.year,
    this.tayfaId,
    this.eventId,
    required this.earnedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EarnedBadge.fromJson(Map<String, Object?> json) => EarnedBadge(
    badgeKey: _readString(json['badge_key'], 'EarnedBadge.badge_key'),
    year: switch (json['year']) {
      null => null,
      final Object v => _readInt(v, 'EarnedBadge.year'),
    },
    tayfaId: switch (json['tayfa_id']) {
      null => null,
      final Object v => _readString(v, 'EarnedBadge.tayfa_id'),
    },
    eventId: switch (json['event_id']) {
      null => null,
      final Object v => _readString(v, 'EarnedBadge.event_id'),
    },
    earnedAt: _readDateTime(json['earned_at'], 'EarnedBadge.earned_at'),
  );

  final String badgeKey;

  /// Yalnızca yıllık rozette, kazanıldığı takvim yılı.
  final int? year;

  /// Yalnızca şampiyonluk rozetinde, etkinliğin tayfası (silinmiş olabilir).
  final String? tayfaId;

  /// Yalnızca şampiyonluk rozetinde, etkinlik (silinmiş olabilir).
  final String? eventId;

  final DateTime earnedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'badge_key': badgeKey,
    if (year case final value?) 'year': value,
    if (tayfaId case final value?) 'tayfa_id': value,
    if (eventId case final value?) 'event_id': value,
    'earned_at': earnedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarnedBadge &&
          badgeKey == other.badgeKey &&
          year == other.year &&
          tayfaId == other.tayfaId &&
          eventId == other.eventId &&
          earnedAt == other.earnedAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[badgeKey, year, tayfaId, eventId, earnedAt]);
}

/// Bir etkin üyenin gördüğü etkinlik. `type` katalog anahtarıdır;
/// etkinlik oluşturulduğu tür sürümüne (`type_version`) bağlıdır ve o
/// sürümün tanımıyla gösterilir (güncel katalogda yoksa
/// `GET /v1/catalog/event-types/{key}/versions/{version}`). `fields`
/// yalnızca tek etkinlik yanıtında gelir. Konvoyun rotası ve
/// araçları bileşenlerindedir (`route`, `vehicles`); kampın listesi
/// `checklist` bileşenindedir, kamp yeri, su, tuvalet ve notlar
/// `fields`'tadır (`site_name`, `has_water`, `has_toilet`, `notes`;
/// #241). Yürüyüşün yoklaması ve beklenen dönüşü `roll_call`
/// bileşenindedir; zorluk, planlanan mesafe ve irtifa `fields`'tadır
/// (`difficulty`, `planned_distance`, `planned_elevation`; #242).
/// Balık etkinliğinin av günlüğü `log` bileşenindedir (`catches`; #243).
final class Event {
  const Event({
    this.coverUploadId,
    required this.id,
    required this.tayfaId,
    required this.type,
    required this.typeVersion,
    this.fields,
    required this.mode,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.openEnded,
    this.meetingPointName,
    this.meetingPoint,
    this.city,
    this.district,
    this.onlineUrl,
    required this.capacity,
    required this.status,
    this.cancelledAt,
    this.cancelReason,
    required this.discoverable,
    this.createdByUserId,
    required this.goingCount,
    required this.maybeCount,
    required this.waitlistCount,
    this.callerRsvp,
    required this.callerCanManage,
    this.callerAttendance,
    this.seriesId,
    required this.seriesOverride,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Event.fromJson(Map<String, Object?> json) => Event(
    coverUploadId: switch (json['cover_upload_id']) {
      null => null,
      final Object v => _readString(v, 'Event.cover_upload_id'),
    },
    id: _readString(json['id'], 'Event.id'),
    tayfaId: _readString(json['tayfa_id'], 'Event.tayfa_id'),
    type: _readString(json['type'], 'Event.type'),
    typeVersion: _readInt(json['type_version'], 'Event.type_version'),
    fields: switch (json['fields']) {
      null => null,
      final Object v => _readJsonObject(v, 'Event.fields'),
    },
    mode: EventMode.fromWire(_readString(json['mode'], 'Event.mode')),
    title: _readString(json['title'], 'Event.title'),
    description: _readString(json['description'], 'Event.description'),
    startsAt: _readDateTime(json['starts_at'], 'Event.starts_at'),
    endsAt: _readDateTime(json['ends_at'], 'Event.ends_at'),
    openEnded: _readBool(json['open_ended'], 'Event.open_ended'),
    meetingPointName: switch (json['meeting_point_name']) {
      null => null,
      final Object v => _readString(v, 'Event.meeting_point_name'),
    },
    meetingPoint: switch (json['meeting_point']) {
      null => null,
      final Object v => LatLng.fromJson(_readObject(v, 'Event.meeting_point')),
    },
    city: switch (json['city']) {
      null => null,
      final Object v => _readString(v, 'Event.city'),
    },
    district: switch (json['district']) {
      null => null,
      final Object v => _readString(v, 'Event.district'),
    },
    onlineUrl: switch (json['online_url']) {
      null => null,
      final Object v => _readString(v, 'Event.online_url'),
    },
    capacity: _readInt(json['capacity'], 'Event.capacity'),
    status: EventStatus.fromWire(_readString(json['status'], 'Event.status')),
    cancelledAt: switch (json['cancelled_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Event.cancelled_at'),
    },
    cancelReason: switch (json['cancel_reason']) {
      null => null,
      final Object v => _readString(v, 'Event.cancel_reason'),
    },
    discoverable: _readBool(json['discoverable'], 'Event.discoverable'),
    createdByUserId: switch (json['created_by_user_id']) {
      null => null,
      final Object v => _readString(v, 'Event.created_by_user_id'),
    },
    goingCount: _readInt(json['going_count'], 'Event.going_count'),
    maybeCount: _readInt(json['maybe_count'], 'Event.maybe_count'),
    waitlistCount: _readInt(json['waitlist_count'], 'Event.waitlist_count'),
    callerRsvp: switch (json['caller_rsvp']) {
      null => null,
      final Object v => RsvpStatus.fromWire(
        _readString(v, 'Event.caller_rsvp'),
      ),
    },
    callerCanManage: _readBool(
      json['caller_can_manage'],
      'Event.caller_can_manage',
    ),
    callerAttendance: switch (json['caller_attendance']) {
      null => null,
      final Object v => AttendanceStatus.fromWire(
        _readString(v, 'Event.caller_attendance'),
      ),
    },
    seriesId: switch (json['series_id']) {
      null => null,
      final Object v => _readString(v, 'Event.series_id'),
    },
    seriesOverride: _readBool(json['series_override'], 'Event.series_override'),
    createdAt: _readDateTime(json['created_at'], 'Event.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Event.updated_at'),
  );

  /// Kapak; linkleri `POST /v1/media/urls`. Serinin ürettiği etkinliklerde yoktur.
  final String? coverUploadId;

  final String id;

  final String tayfaId;

  final String type;

  /// Etkinliğin oluşturulduğu tür sürümü; etkinlik boyunca değişmez.
  ///
  /// Kısıtlar: minimum: 1.
  final int typeVersion;

  final Map<String, Object?>? fields;

  final EventMode mode;

  final String title;

  final String description;

  final DateTime startsAt;

  final DateTime endsAt;

  /// `starts_now` ile açılmış ve organizatörün henüz bitirmediği
  /// etkinlik (ADR-0038 §1): `ends_at` planlanmış bitiş değil, en geç
  /// bitiştir (başlangıçtan 12 saat sonra); etkinlik o anda
  /// kendiliğinden biter. Kendiliğinden bittikten sonra da `true`
  /// kalır; etkinliğin sürüp sürmediği `ends_at` ile şimdiye bakılarak
  /// anlaşılır. Organizatör `POST …/finish` ile bitirir.
  final bool openEnded;

  final String? meetingPointName;

  final LatLng? meetingPoint;

  final String? city;

  final String? district;

  /// Çevrimiçi etkinlikte.
  final String? onlineUrl;

  /// 0: sınırsız.
  final int capacity;

  final EventStatus status;

  final DateTime? cancelledAt;

  final String? cancelReason;

  /// Organizatörün işareti: etkinlik halka açık bir yerde buluşur ve
  /// Keşfet'te görünebilir (ADR-0033). Yalnızca yüz yüze etkinlikte
  /// etkilidir; özel adreste buluşan etkinlik işaretlenmez.
  final bool discoverable;

  /// Organizatör; hesabı silindiyse yoktur.
  final String? createdByUserId;

  final int goingCount;

  final int maybeCount;

  final int waitlistCount;

  /// Sizin cevabınız; cevap vermediyseniz yoktur.
  final RsvpStatus? callerRsvp;

  /// Düzenleyip iptal edebilir misiniz (istemcinin doğru işlemleri göstermesi için; sunucu her istekte yeniden kontrol eder).
  final bool callerCanManage;

  /// Doğrulanmış katılımınız; yoksa yoktur.
  final AttendanceStatus? callerAttendance;

  /// Tekrarlayan serinin etkinliğiyse.
  final String? seriesId;

  /// Seriden ayrı düzenlendi; seri değişiklikleri ona dokunmaz.
  final bool seriesOverride;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (coverUploadId case final value?) 'cover_upload_id': value,
    'id': id,
    'tayfa_id': tayfaId,
    'type': type,
    'type_version': typeVersion,
    if (fields case final value?) 'fields': value,
    'mode': mode.wire,
    'title': title,
    'description': description,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'open_ended': openEnded,
    if (meetingPointName case final value?) 'meeting_point_name': value,
    if (meetingPoint case final value?) 'meeting_point': value.toJson(),
    if (city case final value?) 'city': value,
    if (district case final value?) 'district': value,
    if (onlineUrl case final value?) 'online_url': value,
    'capacity': capacity,
    'status': status.wire,
    if (cancelledAt case final value?)
      'cancelled_at': value.toUtc().toIso8601String(),
    if (cancelReason case final value?) 'cancel_reason': value,
    'discoverable': discoverable,
    if (createdByUserId case final value?) 'created_by_user_id': value,
    'going_count': goingCount,
    'maybe_count': maybeCount,
    'waitlist_count': waitlistCount,
    if (callerRsvp case final value?) 'caller_rsvp': value.wire,
    'caller_can_manage': callerCanManage,
    if (callerAttendance case final value?) 'caller_attendance': value.wire,
    if (seriesId case final value?) 'series_id': value,
    'series_override': seriesOverride,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          coverUploadId == other.coverUploadId &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          type == other.type &&
          typeVersion == other.typeVersion &&
          _deepEquals(fields, other.fields) &&
          mode == other.mode &&
          title == other.title &&
          description == other.description &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          openEnded == other.openEnded &&
          meetingPointName == other.meetingPointName &&
          meetingPoint == other.meetingPoint &&
          city == other.city &&
          district == other.district &&
          onlineUrl == other.onlineUrl &&
          capacity == other.capacity &&
          status == other.status &&
          cancelledAt == other.cancelledAt &&
          cancelReason == other.cancelReason &&
          discoverable == other.discoverable &&
          createdByUserId == other.createdByUserId &&
          goingCount == other.goingCount &&
          maybeCount == other.maybeCount &&
          waitlistCount == other.waitlistCount &&
          callerRsvp == other.callerRsvp &&
          callerCanManage == other.callerCanManage &&
          callerAttendance == other.callerAttendance &&
          seriesId == other.seriesId &&
          seriesOverride == other.seriesOverride &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    coverUploadId,
    id,
    tayfaId,
    type,
    typeVersion,
    _deepHash(fields),
    mode,
    title,
    description,
    startsAt,
    endsAt,
    openEnded,
    meetingPointName,
    meetingPoint,
    city,
    district,
    onlineUrl,
    capacity,
    status,
    cancelledAt,
    cancelReason,
    discoverable,
    createdByUserId,
    goingCount,
    maybeCount,
    waitlistCount,
    callerRsvp,
    callerCanManage,
    callerAttendance,
    seriesId,
    seriesOverride,
    createdAt,
    updatedAt,
  ]);
}

/// Bir etkinliğin bir eşleşme ağacı bileşeni, isteği yapanın gördüğü haliyle (#251).
final class EventBracket {
  const EventBracket({
    required this.started,
    required this.format,
    required this.bestOf,
    required this.result,
    required this.winner,
    this.drawKey,
    required this.drawn,
    this.subject,
    this.teamsKey,
    required this.rounds,
    required this.currentRound,
    this.startedAt,
    required this.entrants,
    required this.matches,
    required this.standings,
    required this.finished,
    required this.winnerPositions,
    required this.callerCanManage,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventBracket.fromJson(Map<String, Object?> json) => EventBracket(
    started: _readBool(json['started'], 'EventBracket.started'),
    format: EventBracketFormat.fromWire(
      _readString(json['format'], 'EventBracket.format'),
    ),
    bestOf: _readInt(json['best_of'], 'EventBracket.best_of'),
    result: EventBracketResult.fromWire(
      _readString(json['result'], 'EventBracket.result'),
    ),
    winner: EventBracketWinner.fromWire(
      _readString(json['winner'], 'EventBracket.winner'),
    ),
    drawKey: switch (json['draw_key']) {
      null => null,
      final Object v => _readString(v, 'EventBracket.draw_key'),
    },
    drawn: _readBool(json['drawn'], 'EventBracket.drawn'),
    subject: switch (json['subject']) {
      null => null,
      final Object v => EventBracketSubject.fromWire(
        _readString(v, 'EventBracket.subject'),
      ),
    },
    teamsKey: switch (json['teams_key']) {
      null => null,
      final Object v => _readString(v, 'EventBracket.teams_key'),
    },
    rounds: _readInt(json['rounds'], 'EventBracket.rounds'),
    currentRound: _readInt(json['current_round'], 'EventBracket.current_round'),
    startedAt: switch (json['started_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventBracket.started_at'),
    },
    entrants: List<EventBracketEntrant>.unmodifiable(
      _readList(json['entrants'], 'EventBracket.entrants').map(
        (Object? e0) => EventBracketEntrant.fromJson(
          _readObject(e0, 'EventBracket.entrants'),
        ),
      ),
    ),
    matches: List<EventBracketMatch>.unmodifiable(
      _readList(json['matches'], 'EventBracket.matches').map(
        (Object? e0) =>
            EventBracketMatch.fromJson(_readObject(e0, 'EventBracket.matches')),
      ),
    ),
    standings: List<EventBracketStanding>.unmodifiable(
      _readList(json['standings'], 'EventBracket.standings').map(
        (Object? e0) => EventBracketStanding.fromJson(
          _readObject(e0, 'EventBracket.standings'),
        ),
      ),
    ),
    finished: _readBool(json['finished'], 'EventBracket.finished'),
    winnerPositions: List<int>.unmodifiable(
      _readList(
        json['winner_positions'],
        'EventBracket.winner_positions',
      ).map((Object? e0) => _readInt(e0, 'EventBracket.winner_positions')),
    ),
    callerCanManage: _readBool(
      json['caller_can_manage'],
      'EventBracket.caller_can_manage',
    ),
  );

  /// Eşleşme ağacı başlatıldı.
  final bool started;

  /// Eleme, lig ya da İsviçre; başlamamışsa başlatılırsa alınacak olan.
  final EventBracketFormat format;

  /// Maç başına oyun (BO1/BO3/BO5).
  final int bestOf;

  /// Oyun puanla mı galibiyet/beraberlik/mağlubiyetle mi skorlanır.
  final EventBracketResult result;

  /// `points` kuralında yüksek ya da düşük puan kazanır.
  final EventBracketWinner winner;

  /// Tohumların geldiği kura bileşeninin anahtarı; türde kura yoksa alan yok.
  final String? drawKey;

  /// Kura çekildi; `subject`, `teams_key` ve `entrants` onundur.
  final bool drawn;

  final EventBracketSubject? subject;

  /// Yalnızca takım kurasında, takım bileşeninin anahtarı.
  final String? teamsKey;

  /// Planlanan tur: ligin turları, İsviçre'de oynanacak tur, elemede en çok tur.
  final int rounds;

  /// Eşlenmiş son tur; başlamamışsa 0.
  final int currentRound;

  /// Yalnızca başlamış eşleşme ağacında.
  final DateTime? startedAt;

  /// Kuradaki yerler, sıraya göre.
  final List<EventBracketEntrant> entrants;

  /// Tura ve sıraya göre.
  final List<EventBracketMatch> matches;

  /// Lig ya da İsviçre sıralaması (puan → aralarındaki maç → Buchholz); elemede boş.
  final List<EventBracketStanding> standings;

  /// Eşleşme ağacı sonuçlandı.
  final bool finished;

  /// Sonuçlandıysa kazananların kuradaki yerleri (elemede son kazanan, lig ve İsviçre'de birinci; tam eşitlikte birden çok); öncesinde boş.
  final List<int> winnerPositions;

  /// Şu an başlatabilir, sonraki turu eşleyebilir, düzeltebilir ve sıfırlayabilirsiniz (organizatör, moderatör, yönetici; susturulmamış; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanManage;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'started': started,
    'format': format.wire,
    'best_of': bestOf,
    'result': result.wire,
    'winner': winner.wire,
    if (drawKey case final value?) 'draw_key': value,
    'drawn': drawn,
    if (subject case final value?) 'subject': value.wire,
    if (teamsKey case final value?) 'teams_key': value,
    'rounds': rounds,
    'current_round': currentRound,
    if (startedAt case final value?)
      'started_at': value.toUtc().toIso8601String(),
    'entrants': <Object?>[for (final e0 in entrants) e0.toJson()],
    'matches': <Object?>[for (final e0 in matches) e0.toJson()],
    'standings': <Object?>[for (final e0 in standings) e0.toJson()],
    'finished': finished,
    'winner_positions': <Object?>[for (final e0 in winnerPositions) e0],
    'caller_can_manage': callerCanManage,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventBracket &&
          started == other.started &&
          format == other.format &&
          bestOf == other.bestOf &&
          result == other.result &&
          winner == other.winner &&
          drawKey == other.drawKey &&
          drawn == other.drawn &&
          subject == other.subject &&
          teamsKey == other.teamsKey &&
          rounds == other.rounds &&
          currentRound == other.currentRound &&
          startedAt == other.startedAt &&
          _deepEquals(entrants, other.entrants) &&
          _deepEquals(matches, other.matches) &&
          _deepEquals(standings, other.standings) &&
          finished == other.finished &&
          _deepEquals(winnerPositions, other.winnerPositions) &&
          callerCanManage == other.callerCanManage;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    started,
    format,
    bestOf,
    result,
    winner,
    drawKey,
    drawn,
    subject,
    teamsKey,
    rounds,
    currentRound,
    startedAt,
    _deepHash(entrants),
    _deepHash(matches),
    _deepHash(standings),
    finished,
    _deepHash(winnerPositions),
    callerCanManage,
  ]);
}

/// Eşleşme ağacının tohumlandığı kuradaki bir yer. Boş yerde (kişi ya da takım geri çekildi) ne `user_id` ne `team_id` vardır.
final class EventBracketEntrant {
  const EventBracketEntrant({
    required this.position,
    this.userId,
    this.teamId,
    this.guestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventBracketEntrant.fromJson(Map<String, Object?> json) =>
      EventBracketEntrant(
        position: _readInt(json['position'], 'EventBracketEntrant.position'),
        userId: switch (json['user_id']) {
          null => null,
          final Object v => _readString(v, 'EventBracketEntrant.user_id'),
        },
        teamId: switch (json['team_id']) {
          null => null,
          final Object v => _readString(v, 'EventBracketEntrant.team_id'),
        },
        guestId: switch (json['guest_id']) {
          null => null,
          final Object v => _readString(v, 'EventBracketEntrant.guest_id'),
        },
      );

  /// Kısıtlar: minimum: 1; maximum: 500.
  final int position;

  /// Katılımcı kurasında kişinin kullanıcı kimliği.
  final String? userId;

  /// Takım kurasında takımın kimliği.
  final String? teamId;

  /// Katılımcı kurasında misafir oyuncunun kimliği (`EventGuestPlayer.id`).
  final String? guestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'position': position,
    if (userId case final value?) 'user_id': value,
    if (teamId case final value?) 'team_id': value,
    if (guestId case final value?) 'guest_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventBracketEntrant &&
          position == other.position &&
          userId == other.userId &&
          teamId == other.teamId &&
          guestId == other.guestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[position, userId, teamId, guestId]);
}

/// Eleme, lig ya da İsviçre; başlamamışsa başlatılırsa alınacak olan.
enum EventBracketFormat {
  elimination('elimination'),
  league('league'),
  swiss('swiss'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventBracketFormat(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventBracketFormat.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventBracketFormat fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Maçın bir oyunu.
final class EventBracketGame {
  const EventBracketGame({
    required this.number,
    this.aPoints,
    this.bPoints,
    this.aOutcome,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventBracketGame.fromJson(Map<String, Object?> json) =>
      EventBracketGame(
        number: _readInt(json['number'], 'EventBracketGame.number'),
        aPoints: switch (json['a_points']) {
          null => null,
          final Object v => _readInt(v, 'EventBracketGame.a_points'),
        },
        bPoints: switch (json['b_points']) {
          null => null,
          final Object v => _readInt(v, 'EventBracketGame.b_points'),
        },
        aOutcome: switch (json['a_outcome']) {
          null => null,
          final Object v => EventBracketGameAOutcome.fromWire(
            _readString(v, 'EventBracketGame.a_outcome'),
          ),
        },
      );

  /// Kısıtlar: minimum: 1; maximum: 9.
  final int number;

  /// Yalnızca `points` kuralında.
  final int? aPoints;

  /// Yalnızca `points` kuralında.
  final int? bPoints;

  /// Yalnızca `wdl` kuralında; B tarafınınki tersidir.
  final EventBracketGameAOutcome? aOutcome;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    if (aPoints case final value?) 'a_points': value,
    if (bPoints case final value?) 'b_points': value,
    if (aOutcome case final value?) 'a_outcome': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventBracketGame &&
          number == other.number &&
          aPoints == other.aPoints &&
          bPoints == other.bPoints &&
          aOutcome == other.aOutcome;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[number, aPoints, bPoints, aOutcome]);
}

/// Yalnızca `wdl` kuralında; B tarafınınki tersidir.
enum EventBracketGameAOutcome {
  win('win'),
  draw('draw'),
  loss('loss'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventBracketGameAOutcome(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('EventBracketGameAOutcome.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventBracketGameAOutcome fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `points` kuralında `a_points` ve `b_points` birlikte, `wdl` kuralında yalnızca `a_outcome`.
final class EventBracketGameRequest {
  const EventBracketGameRequest({this.aPoints, this.bPoints, this.aOutcome});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventBracketGameRequest.fromJson(Map<String, Object?> json) =>
      EventBracketGameRequest(
        aPoints: switch (json['a_points']) {
          null => null,
          final Object v => _readInt(v, 'EventBracketGameRequest.a_points'),
        },
        bPoints: switch (json['b_points']) {
          null => null,
          final Object v => _readInt(v, 'EventBracketGameRequest.b_points'),
        },
        aOutcome: switch (json['a_outcome']) {
          null => null,
          final Object v => EventBracketGameRequestAOutcome.fromWire(
            _readString(v, 'EventBracketGameRequest.a_outcome'),
          ),
        },
      );

  /// Kısıtlar: minimum: -1000000; maximum: 1000000.
  final int? aPoints;

  /// Kısıtlar: minimum: -1000000; maximum: 1000000.
  final int? bPoints;

  final EventBracketGameRequestAOutcome? aOutcome;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (aPoints case final value?) 'a_points': value,
    if (bPoints case final value?) 'b_points': value,
    if (aOutcome case final value?) 'a_outcome': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventBracketGameRequest &&
          aPoints == other.aPoints &&
          bPoints == other.bPoints &&
          aOutcome == other.aOutcome;

  @override
  int get hashCode => Object.hashAll(<Object?>[aPoints, bPoints, aOutcome]);
}

enum EventBracketGameRequestAOutcome {
  win('win'),
  draw('draw'),
  loss('loss'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventBracketGameRequestAOutcome(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'EventBracketGameRequestAOutcome.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventBracketGameRequestAOutcome fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Eşleşme ağacının bir maçı (#251). Taraflar kuradaki yerlerdir.
final class EventBracketMatch {
  const EventBracketMatch({
    required this.id,
    required this.round,
    required this.slot,
    this.aPosition,
    this.bPosition,
    required this.games,
    required this.decided,
    required this.bye,
    this.winnerPosition,
    required this.aTotal,
    required this.bTotal,
    required this.aGamesWon,
    required this.bGamesWon,
    required this.callerCanScore,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventBracketMatch.fromJson(
    Map<String, Object?> json,
  ) => EventBracketMatch(
    id: _readString(json['id'], 'EventBracketMatch.id'),
    round: _readInt(json['round'], 'EventBracketMatch.round'),
    slot: _readInt(json['slot'], 'EventBracketMatch.slot'),
    aPosition: switch (json['a_position']) {
      null => null,
      final Object v => _readInt(v, 'EventBracketMatch.a_position'),
    },
    bPosition: switch (json['b_position']) {
      null => null,
      final Object v => _readInt(v, 'EventBracketMatch.b_position'),
    },
    games: List<EventBracketGame>.unmodifiable(
      _readList(json['games'], 'EventBracketMatch.games').map(
        (Object? e0) => EventBracketGame.fromJson(
          _readObject(e0, 'EventBracketMatch.games'),
        ),
      ),
    ),
    decided: _readBool(json['decided'], 'EventBracketMatch.decided'),
    bye: _readBool(json['bye'], 'EventBracketMatch.bye'),
    winnerPosition: switch (json['winner_position']) {
      null => null,
      final Object v => _readInt(v, 'EventBracketMatch.winner_position'),
    },
    aTotal: _readDouble(json['a_total'], 'EventBracketMatch.a_total'),
    bTotal: _readDouble(json['b_total'], 'EventBracketMatch.b_total'),
    aGamesWon: _readInt(json['a_games_won'], 'EventBracketMatch.a_games_won'),
    bGamesWon: _readInt(json['b_games_won'], 'EventBracketMatch.b_games_won'),
    callerCanScore: _readBool(
      json['caller_can_score'],
      'EventBracketMatch.caller_can_score',
    ),
  );

  final String id;

  /// Kısıtlar: minimum: 1.
  final int round;

  /// Maçın turdaki sırası.
  ///
  /// Kısıtlar: minimum: 1.
  final int slot;

  /// A tarafının kuradaki yeri; yoksa (bay) alan yok.
  final int? aPosition;

  /// B tarafının kuradaki yeri; yoksa (bay) alan yok.
  final int? bPosition;

  final List<EventBracketGame> games;

  /// Maç sonuçlandı: kazanan, beraberlik (elemede yok) ya da bay.
  final bool decided;

  /// En fazla bir taraflı maç.
  final bool bye;

  /// Kazananın yeri; beraberlikte, sonuçlanmamış maçta ya da tarafsız maçta alan yok.
  final int? winnerPosition;

  /// Tarafın toplamı; `wdl` kuralında galibiyet 1, beraberlik 0.5.
  final double aTotal;

  final double bTotal;

  /// Tarafın tek başına kazandığı oyun sayısı.
  final int aGamesWon;

  final int bGamesWon;

  /// Şu an bu maça oyun girebilirsiniz (organizatör, moderatör, yönetici ya da maçın hakemi; mevcut turun sonuçlanmamış maçı; etkinlik başlamış, iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanScore;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'round': round,
    'slot': slot,
    if (aPosition case final value?) 'a_position': value,
    if (bPosition case final value?) 'b_position': value,
    'games': <Object?>[for (final e0 in games) e0.toJson()],
    'decided': decided,
    'bye': bye,
    if (winnerPosition case final value?) 'winner_position': value,
    'a_total': aTotal,
    'b_total': bTotal,
    'a_games_won': aGamesWon,
    'b_games_won': bGamesWon,
    'caller_can_score': callerCanScore,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventBracketMatch &&
          id == other.id &&
          round == other.round &&
          slot == other.slot &&
          aPosition == other.aPosition &&
          bPosition == other.bPosition &&
          _deepEquals(games, other.games) &&
          decided == other.decided &&
          bye == other.bye &&
          winnerPosition == other.winnerPosition &&
          aTotal == other.aTotal &&
          bTotal == other.bTotal &&
          aGamesWon == other.aGamesWon &&
          bGamesWon == other.bGamesWon &&
          callerCanScore == other.callerCanScore;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    round,
    slot,
    aPosition,
    bPosition,
    _deepHash(games),
    decided,
    bye,
    winnerPosition,
    aTotal,
    bTotal,
    aGamesWon,
    bGamesWon,
    callerCanScore,
  ]);
}

/// Oyun puanla mı galibiyet/beraberlik/mağlubiyetle mi skorlanır.
enum EventBracketResult {
  points('points'),
  wdl('wdl'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventBracketResult(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventBracketResult.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventBracketResult fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Lig ya da İsviçre sıralamasında bir katılımcı.
final class EventBracketStanding {
  const EventBracketStanding({
    required this.position,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.points,
    required this.headToHead,
    required this.buchholz,
    required this.rank,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventBracketStanding.fromJson(Map<String, Object?> json) =>
      EventBracketStanding(
        position: _readInt(json['position'], 'EventBracketStanding.position'),
        played: _readInt(json['played'], 'EventBracketStanding.played'),
        won: _readInt(json['won'], 'EventBracketStanding.won'),
        drawn: _readInt(json['drawn'], 'EventBracketStanding.drawn'),
        lost: _readInt(json['lost'], 'EventBracketStanding.lost'),
        points: _readDouble(json['points'], 'EventBracketStanding.points'),
        headToHead: _readDouble(
          json['head_to_head'],
          'EventBracketStanding.head_to_head',
        ),
        buchholz: _readDouble(
          json['buchholz'],
          'EventBracketStanding.buchholz',
        ),
        rank: _readInt(json['rank'], 'EventBracketStanding.rank'),
      );

  /// Kuradaki yeri.
  final int position;

  final int played;

  final int won;

  final int drawn;

  final int lost;

  /// Galibiyet 1, beraberlik 0.5, bay 1.
  final double points;

  /// Puanca eşit olanlara karşı alınan puan.
  final double headToHead;

  /// Rakiplerin puanları toplamı.
  final double buchholz;

  /// 1'den başlar; üçünde de eşit olanlar aynı sırayı paylaşır.
  final int rank;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'position': position,
    'played': played,
    'won': won,
    'drawn': drawn,
    'lost': lost,
    'points': points,
    'head_to_head': headToHead,
    'buchholz': buchholz,
    'rank': rank,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventBracketStanding &&
          position == other.position &&
          played == other.played &&
          won == other.won &&
          drawn == other.drawn &&
          lost == other.lost &&
          points == other.points &&
          headToHead == other.headToHead &&
          buchholz == other.buchholz &&
          rank == other.rank;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    position,
    played,
    won,
    drawn,
    lost,
    points,
    headToHead,
    buchholz,
    rank,
  ]);
}

enum EventBracketSubject {
  participants('participants'),
  teams('teams'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventBracketSubject(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventBracketSubject.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventBracketSubject fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `points` kuralında yüksek ya da düşük puan kazanır.
enum EventBracketWinner {
  high('high'),
  low('low'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventBracketWinner(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventBracketWinner.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventBracketWinner fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventCancelRequest {
  const EventCancelRequest({this.reason});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventCancelRequest.fromJson(Map<String, Object?> json) =>
      EventCancelRequest(
        reason: switch (json['reason']) {
          null => null,
          final Object v => _readString(v, 'EventCancelRequest.reason'),
        },
      );

  /// Kısıtlar: maxLength: 500.
  final String? reason;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (reason case final value?) 'reason': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCancelRequest && reason == other.reason;

  @override
  int get hashCode => Object.hashAll(<Object?>[reason]);
}

/// Bir etkinliğin bir kutlama bileşeni, isteği yapanın gördüğü haliyle (#255).
final class EventCelebration {
  const EventCelebration({
    this.source,
    this.sourceKind,
    required this.winners,
    required this.hidden,
    required this.announced,
    this.announcedAt,
    required this.callerCanAnnounce,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventCelebration.fromJson(Map<String, Object?> json) =>
      EventCelebration(
        source: switch (json['source']) {
          null => null,
          final Object v => _readString(v, 'EventCelebration.source'),
        },
        sourceKind: switch (json['source_kind']) {
          null => null,
          final Object v => EventCelebrationSourceKind.fromWire(
            _readString(v, 'EventCelebration.source_kind'),
          ),
        },
        winners: List<EventCelebrationWinner>.unmodifiable(
          _readList(json['winners'], 'EventCelebration.winners').map(
            (Object? e0) => EventCelebrationWinner.fromJson(
              _readObject(e0, 'EventCelebration.winners'),
            ),
          ),
        ),
        hidden: _readBool(json['hidden'], 'EventCelebration.hidden'),
        announced: _readBool(json['announced'], 'EventCelebration.announced'),
        announcedAt: switch (json['announced_at']) {
          null => null,
          final Object v => _readDateTime(v, 'EventCelebration.announced_at'),
        },
        callerCanAnnounce: _readBool(
          json['caller_can_announce'],
          'EventCelebration.caller_can_announce',
        ),
      );

  /// Kazananların okunduğu bileşenin anahtarı; elle seçilen kazananlarda yoktur.
  final String? source;

  /// Kaynak bileşenin türü; elle seçilen kazananlarda yoktur.
  final EventCelebrationSourceKind? sourceKind;

  /// Kazananlar; kaynağın sırasıyla (masalar sırayla, eşitlikte yer sırası) ya da elle verilen sırayla. Kaynak sonuçlanmadıysa, elle seçilmediyse ve gizliyken boş.
  final List<EventCelebrationWinner> winners;

  /// Kaynak sonucunu herkesten gizliyor (hassas ölçüm) ya da türün katılımı hassas.
  final bool hidden;

  /// Organizatör kazananı ilan etti.
  final bool announced;

  /// Yalnızca ilan edildiyse; ilk ilan zamanı.
  final DateTime? announcedAt;

  /// Şu an ilan edebilirsiniz (organizatör, moderatör, yönetici; etkinlik başlamış, iptal değil, donmamış, tayfa salt okunur değil). Kazanan olup olmadığı `winners`'tadır.
  final bool callerCanAnnounce;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (source case final value?) 'source': value,
    if (sourceKind case final value?) 'source_kind': value.wire,
    'winners': <Object?>[for (final e0 in winners) e0.toJson()],
    'hidden': hidden,
    'announced': announced,
    if (announcedAt case final value?)
      'announced_at': value.toUtc().toIso8601String(),
    'caller_can_announce': callerCanAnnounce,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCelebration &&
          source == other.source &&
          sourceKind == other.sourceKind &&
          _deepEquals(winners, other.winners) &&
          hidden == other.hidden &&
          announced == other.announced &&
          announcedAt == other.announcedAt &&
          callerCanAnnounce == other.callerCanAnnounce;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    source,
    sourceKind,
    _deepHash(winners),
    hidden,
    announced,
    announcedAt,
    callerCanAnnounce,
  ]);
}

final class EventCelebrationRequest {
  const EventCelebrationRequest({this.winnerIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventCelebrationRequest.fromJson(Map<String, Object?> json) =>
      EventCelebrationRequest(
        winnerIds: switch (json['winner_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'EventCelebrationRequest.winner_ids').map(
              (Object? e0) =>
                  _readString(e0, 'EventCelebrationRequest.winner_ids'),
            ),
          ),
        },
      );

  /// Yalnızca kaynaksız kutlamada, elle seçilen kazananlar (etkinliğin katılımcıları, 1–10 farklı kişi).
  ///
  /// Kısıtlar: maxItems: 10.
  final List<String>? winnerIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (winnerIds case final value?)
      'winner_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCelebrationRequest &&
          _deepEquals(winnerIds, other.winnerIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(winnerIds)]);
}

/// Kaynak bileşenin türü; elle seçilen kazananlarda yoktur.
enum EventCelebrationSourceKind {
  scoreboard('scoreboard'),
  bracket('bracket'),
  ranking('ranking'),
  vote('vote'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventCelebrationSourceKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('EventCelebrationSourceKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventCelebrationSourceKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Bir kazanan: `user_id`, `team_id` ve `guest_id`'den tam olarak biri vardır.
final class EventCelebrationWinner {
  const EventCelebrationWinner({
    this.userId,
    this.teamId,
    this.guestId,
    this.tableId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventCelebrationWinner.fromJson(Map<String, Object?> json) =>
      EventCelebrationWinner(
        userId: switch (json['user_id']) {
          null => null,
          final Object v => _readString(v, 'EventCelebrationWinner.user_id'),
        },
        teamId: switch (json['team_id']) {
          null => null,
          final Object v => _readString(v, 'EventCelebrationWinner.team_id'),
        },
        guestId: switch (json['guest_id']) {
          null => null,
          final Object v => _readString(v, 'EventCelebrationWinner.guest_id'),
        },
        tableId: switch (json['table_id']) {
          null => null,
          final Object v => _readString(v, 'EventCelebrationWinner.table_id'),
        },
      );

  final String? userId;

  /// Kaynağın oturttuğu takım bileşenindeki takım.
  final String? teamId;

  /// Etkinliğin misafir oyuncusu; takma adı etkinliğin misafirlerinden okunur.
  final String? guestId;

  /// Yalnızca yazboz kaynağında; kazanılan masa.
  final String? tableId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (userId case final value?) 'user_id': value,
    if (teamId case final value?) 'team_id': value,
    if (guestId case final value?) 'guest_id': value,
    if (tableId case final value?) 'table_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCelebrationWinner &&
          userId == other.userId &&
          teamId == other.teamId &&
          guestId == other.guestId &&
          tableId == other.tableId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[userId, teamId, guestId, tableId]);
}

final class EventComponentChoiceState {
  const EventComponentChoiceState({
    required this.param,
    required this.value,
    required this.options,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventComponentChoiceState.fromJson(Map<String, Object?> json) =>
      EventComponentChoiceState(
        param: _readString(json['param'], 'EventComponentChoiceState.param'),
        value: _readString(json['value'], 'EventComponentChoiceState.value'),
        options: List<String>.unmodifiable(
          _readList(json['options'], 'EventComponentChoiceState.options').map(
            (Object? e0) =>
                _readString(e0, 'EventComponentChoiceState.options'),
          ),
        ),
      );

  final String param;

  /// Geçerli seçenek: organizatörün seçimi ya da tanımdaki varsayılan.
  final String value;

  /// Tanımdaki seçenekler, tanımdaki sırayla.
  final List<String> options;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'param': param,
    'value': value,
    'options': <Object?>[for (final e0 in options) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventComponentChoiceState &&
          param == other.param &&
          value == other.value &&
          _deepEquals(options, other.options);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[param, value, _deepHash(options)]);
}

final class EventComponentList {
  const EventComponentList({
    required this.components,
    required this.locked,
    required this.callerCanManage,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventComponentList.fromJson(Map<String, Object?> json) =>
      EventComponentList(
        components: List<EventComponentState>.unmodifiable(
          _readList(json['components'], 'EventComponentList.components').map(
            (Object? e0) => EventComponentState.fromJson(
              _readObject(e0, 'EventComponentList.components'),
            ),
          ),
        ),
        locked: _readBool(json['locked'], 'EventComponentList.locked'),
        callerCanManage: _readBool(
          json['caller_can_manage'],
          'EventComponentList.caller_can_manage',
        ),
      );

  final List<EventComponentState> components;

  /// Seçimler artık değişmez: etkinlik başladı ya da iptal edildi, ya da tayfa salt okunur.
  final bool locked;

  /// Çağıran organizatör, moderatör ya da yöneticidir ve susturulmamıştır.
  final bool callerCanManage;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'components': <Object?>[for (final e0 in components) e0.toJson()],
    'locked': locked,
    'caller_can_manage': callerCanManage,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventComponentList &&
          _deepEquals(components, other.components) &&
          locked == other.locked &&
          callerCanManage == other.callerCanManage;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(components), locked, callerCanManage]);
}

/// Yeni etkinlikte bir bileşen için organizatörün seçimi.
final class EventComponentSelection {
  const EventComponentSelection({
    required this.key,
    this.enabled,
    this.choices,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventComponentSelection.fromJson(Map<String, Object?> json) =>
      EventComponentSelection(
        key: _readString(json['key'], 'EventComponentSelection.key'),
        enabled: switch (json['enabled']) {
          null => null,
          final Object v => _readBool(v, 'EventComponentSelection.enabled'),
        },
        choices: switch (json['choices']) {
          null => null,
          final Object v => List<ComponentChoice>.unmodifiable(
            _readList(v, 'EventComponentSelection.choices').map(
              (Object? e0) => ComponentChoice.fromJson(
                _readObject(e0, 'EventComponentSelection.choices'),
              ),
            ),
          ),
        },
      );

  /// Bileşenin anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// `optional` bileşeni açar ya da kapatır; gönderilmezse tanımdaki varsayılan.
  final bool? enabled;

  /// Kısıtlar: maxItems: 20.
  final List<ComponentChoice>? choices;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    if (enabled case final value?) 'enabled': value,
    if (choices case final value?)
      'choices': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventComponentSelection &&
          key == other.key &&
          enabled == other.enabled &&
          _deepEquals(choices, other.choices);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[key, enabled, _deepHash(choices)]);
}

/// En az biri bulunur.
final class EventComponentSelectionRequest {
  const EventComponentSelectionRequest({this.enabled, this.choices});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventComponentSelectionRequest.fromJson(Map<String, Object?> json) =>
      EventComponentSelectionRequest(
        enabled: switch (json['enabled']) {
          null => null,
          final Object v => _readBool(
            v,
            'EventComponentSelectionRequest.enabled',
          ),
        },
        choices: switch (json['choices']) {
          null => null,
          final Object v => List<ComponentChoice>.unmodifiable(
            _readList(v, 'EventComponentSelectionRequest.choices').map(
              (Object? e0) => ComponentChoice.fromJson(
                _readObject(e0, 'EventComponentSelectionRequest.choices'),
              ),
            ),
          ),
        },
      );

  /// `optional` bileşeni açar ya da kapatır.
  final bool? enabled;

  /// Kısıtlar: maxItems: 20.
  final List<ComponentChoice>? choices;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (enabled case final value?) 'enabled': value,
    if (choices case final value?)
      'choices': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventComponentSelectionRequest &&
          enabled == other.enabled &&
          _deepEquals(choices, other.choices);

  @override
  int get hashCode => Object.hashAll(<Object?>[enabled, _deepHash(choices)]);
}

final class EventComponentState {
  const EventComponentState({
    required this.key,
    required this.kind,
    required this.optional,
    required this.enabled,
    required this.choices,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventComponentState.fromJson(Map<String, Object?> json) =>
      EventComponentState(
        key: _readString(json['key'], 'EventComponentState.key'),
        kind: _readString(json['kind'], 'EventComponentState.kind'),
        optional: _readBool(json['optional'], 'EventComponentState.optional'),
        enabled: _readBool(json['enabled'], 'EventComponentState.enabled'),
        choices: List<EventComponentChoiceState>.unmodifiable(
          _readList(json['choices'], 'EventComponentState.choices').map(
            (Object? e0) => EventComponentChoiceState.fromJson(
              _readObject(e0, 'EventComponentState.choices'),
            ),
          ),
        ),
      );

  final String key;

  /// Bileşen türü (`CatalogComponent.kind`).
  final String kind;

  /// Organizatör bileşeni açıp kapatabilir.
  final bool optional;

  /// Yalnızca kapatılmış `optional` bileşende `false`.
  final bool enabled;

  /// Organizatöre bırakılan her parametre, ada göre.
  final List<EventComponentChoiceState> choices;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'kind': kind,
    'optional': optional,
    'enabled': enabled,
    'choices': <Object?>[for (final e0 in choices) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventComponentState &&
          key == other.key &&
          kind == other.kind &&
          optional == other.optional &&
          enabled == other.enabled &&
          _deepEquals(choices, other.choices);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    kind,
    optional,
    enabled,
    _deepHash(choices),
  ]);
}

/// `starts_at` ve `ends_at` zorunludur; `starts_now` `true` ise ikisi
/// de gönderilmez.
/// Yüz yüze: `meeting_point`, `city`, `district` zorunlu; `online_url`
/// boş. Çevrimiçi: `online_url` (https) zorunlu; yer alanları boş.
/// `type` katalogdaki aktif bir türün anahtarıdır; etkinlik türün
/// güncel sürümüyle oluşturulur ve `mode` türün izin verdiği modlardan
/// biri olmalıdır. `fields` türün tanımına göre doğrulanır: zorunlu
/// alanlar verilir, tanımda olmayan alan gönderilmez (ör. `gaming`:
/// `game`, `platform`; `sports`: `sport`, `venue_name`; `camp`:
/// `site_name`, `has_water`, `has_toilet`, `notes`; `hike`:
/// `difficulty`, `planned_distance`, `planned_elevation`). Türe özel
/// ayrıntı nesnesi yoktur (#243). Rota ve
/// yürüyüşün beklenen dönüşü etkinlik oluşturulduktan sonra
/// bileşenlerinden (`route`, `roll_call`) yazılır.
final class EventCreateRequest {
  const EventCreateRequest({
    this.coverUploadId,
    this.components,
    required this.type,
    this.fields,
    required this.mode,
    required this.title,
    this.description,
    this.startsAt,
    this.endsAt,
    this.startsNow,
    this.meetingPointName,
    this.meetingPoint,
    this.city,
    this.district,
    this.onlineUrl,
    this.capacity,
    this.discoverable,
    this.recurrence,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventCreateRequest.fromJson(
    Map<String, Object?> json,
  ) => EventCreateRequest(
    coverUploadId: switch (json['cover_upload_id']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.cover_upload_id'),
    },
    components: switch (json['components']) {
      null => null,
      final Object v => List<EventComponentSelection>.unmodifiable(
        _readList(v, 'EventCreateRequest.components').map(
          (Object? e0) => EventComponentSelection.fromJson(
            _readObject(e0, 'EventCreateRequest.components'),
          ),
        ),
      ),
    },
    type: _readString(json['type'], 'EventCreateRequest.type'),
    fields: switch (json['fields']) {
      null => null,
      final Object v => _readJsonObject(v, 'EventCreateRequest.fields'),
    },
    mode: EventMode.fromWire(
      _readString(json['mode'], 'EventCreateRequest.mode'),
    ),
    title: _readString(json['title'], 'EventCreateRequest.title'),
    description: switch (json['description']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.description'),
    },
    startsAt: switch (json['starts_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventCreateRequest.starts_at'),
    },
    endsAt: switch (json['ends_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventCreateRequest.ends_at'),
    },
    startsNow: switch (json['starts_now']) {
      null => null,
      final Object v => _readBool(v, 'EventCreateRequest.starts_now'),
    },
    meetingPointName: switch (json['meeting_point_name']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.meeting_point_name'),
    },
    meetingPoint: switch (json['meeting_point']) {
      null => null,
      final Object v => LatLng.fromJson(
        _readObject(v, 'EventCreateRequest.meeting_point'),
      ),
    },
    city: switch (json['city']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.city'),
    },
    district: switch (json['district']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.district'),
    },
    onlineUrl: switch (json['online_url']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.online_url'),
    },
    capacity: switch (json['capacity']) {
      null => null,
      final Object v => _readInt(v, 'EventCreateRequest.capacity'),
    },
    discoverable: switch (json['discoverable']) {
      null => null,
      final Object v => _readBool(v, 'EventCreateRequest.discoverable'),
    },
    recurrence: switch (json['recurrence']) {
      null => null,
      final Object v => Recurrence.fromJson(
        _readObject(v, 'EventCreateRequest.recurrence'),
      ),
    },
    clientRequestId: _readString(
      json['client_request_id'],
      'EventCreateRequest.client_request_id',
    ),
  );

  /// İsteğe bağlı: kendi hazır `cover` yüklemeniz (bu tayfa için açılmış). Yalnızca bu etkinliğe bağlanır.
  final String? coverUploadId;

  /// Organizatörün bileşen seçimleri (ADR-0037 §2): `optional`
  /// bileşenlerin açık/kapalı hali ve organizatöre bırakılan
  /// parametreler. Gönderilmeyen bileşen tanımdaki varsayılanla
  /// başlar. Türde olmayan ya da tekrar eden bileşen, `optional`
  /// olmayan bileşeni kapatmak ve geçersiz seçim `invalid-request`.
  /// Sonradan `PUT …/components/{component_key}` ile, etkinlik
  /// başlayana kadar değişir.
  ///
  /// Kısıtlar: maxItems: 20.
  final List<EventComponentSelection>? components;

  final String type;

  final Map<String, Object?>? fields;

  final EventMode mode;

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 1–120 karakter.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String title;

  /// Kısıtlar: maxLength: 5000.
  final String? description;

  /// Gelecekte, en fazla iki yıl ileri. `starts_now` ile gönderilmez.
  final DateTime? startsAt;

  /// Başlangıçtan sonra, en fazla 30 gün. `starts_now` ile gönderilmez.
  final DateTime? endsAt;

  /// Şimdi başlat (ADR-0038 §1): etkinlik sunucu saatiyle şimdi başlar
  /// (istemci saati kullanılmaz) ve açık uçludur (`open_ended`):
  /// `ends_at` 12 saat sonrasına yazılır, organizatör
  /// `POST …/finish` ile bitirir. `starts_at`, `ends_at` ve
  /// `recurrence` gönderilmez, `discoverable` `true` olamaz
  /// (`invalid-request`). Tayfada etkinlik açma izni yerine tayfanın
  /// `now_create_min_role` ayarı geçerlidir. Kişi başına aynı anda en
  /// fazla bir açık şimdi etkinliği (tayfa içi ve anlık toplam):
  /// aşılırsa `now-limit-reached`. Yüz yüzede buluşma noktası yine
  /// zorunludur; istemcinin cihaz konumuyla önerip kullanıcının
  /// onayladığı noktadır, cihaz konumu ayrıca gönderilmez.
  final bool? startsNow;

  /// Kısıtlar: maxLength: 120.
  final String? meetingPointName;

  final LatLng? meetingPoint;

  /// Kısıtlar: maxLength: 50.
  final String? city;

  /// Kısıtlar: maxLength: 50.
  final String? district;

  /// Kısıtlar: maxLength: 2048.
  final String? onlineUrl;

  /// 0: sınırsız.
  ///
  /// Kısıtlar: minimum: 0; maximum: 10000.
  final int? capacity;

  /// Organizatörün işareti: etkinlik halka açık bir yerde buluşur ve
  /// Keşfet'te görünebilir (ADR-0033). Yalnızca yüz yüze etkinlikte
  /// etkilidir; özel adreste buluşan etkinlik işaretlenmez.
  final bool? discoverable;

  final Recurrence? recurrence;

  /// İstemcinin her açma denemesi için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (coverUploadId case final value?) 'cover_upload_id': value,
    if (components case final value?)
      'components': <Object?>[for (final e0 in value) e0.toJson()],
    'type': type,
    if (fields case final value?) 'fields': value,
    'mode': mode.wire,
    'title': title,
    if (description case final value?) 'description': value,
    if (startsAt case final value?)
      'starts_at': value.toUtc().toIso8601String(),
    if (endsAt case final value?) 'ends_at': value.toUtc().toIso8601String(),
    if (startsNow case final value?) 'starts_now': value,
    if (meetingPointName case final value?) 'meeting_point_name': value,
    if (meetingPoint case final value?) 'meeting_point': value.toJson(),
    if (city case final value?) 'city': value,
    if (district case final value?) 'district': value,
    if (onlineUrl case final value?) 'online_url': value,
    if (capacity case final value?) 'capacity': value,
    if (discoverable case final value?) 'discoverable': value,
    if (recurrence case final value?) 'recurrence': value.toJson(),
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCreateRequest &&
          coverUploadId == other.coverUploadId &&
          _deepEquals(components, other.components) &&
          type == other.type &&
          _deepEquals(fields, other.fields) &&
          mode == other.mode &&
          title == other.title &&
          description == other.description &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          startsNow == other.startsNow &&
          meetingPointName == other.meetingPointName &&
          meetingPoint == other.meetingPoint &&
          city == other.city &&
          district == other.district &&
          onlineUrl == other.onlineUrl &&
          capacity == other.capacity &&
          discoverable == other.discoverable &&
          recurrence == other.recurrence &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    coverUploadId,
    _deepHash(components),
    type,
    _deepHash(fields),
    mode,
    title,
    description,
    startsAt,
    endsAt,
    startsNow,
    meetingPointName,
    meetingPoint,
    city,
    district,
    onlineUrl,
    capacity,
    discoverable,
    recurrence,
    clientRequestId,
  ]);
}

/// Bir etkinliğin bir kura bileşeni, isteği yapanın gördüğü haliyle (#249).
final class EventDraw {
  const EventDraw({
    required this.drawn,
    required this.subject,
    this.teamsKey,
    this.drawnAt,
    required this.entries,
    required this.callerCanDraw,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventDraw.fromJson(Map<String, Object?> json) => EventDraw(
    drawn: _readBool(json['drawn'], 'EventDraw.drawn'),
    subject: EventDrawSubject.fromWire(
      _readString(json['subject'], 'EventDraw.subject'),
    ),
    teamsKey: switch (json['teams_key']) {
      null => null,
      final Object v => _readString(v, 'EventDraw.teams_key'),
    },
    drawnAt: switch (json['drawn_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventDraw.drawn_at'),
    },
    entries: List<EventDrawEntry>.unmodifiable(
      _readList(json['entries'], 'EventDraw.entries').map(
        (Object? e0) =>
            EventDrawEntry.fromJson(_readObject(e0, 'EventDraw.entries')),
      ),
    ),
    callerCanDraw: _readBool(
      json['caller_can_draw'],
      'EventDraw.caller_can_draw',
    ),
  );

  /// Kura çekildi.
  final bool drawn;

  /// Kuranın sıraladığı (çekilmemişse şu an çekilse sıralayacağı) giriş türü.
  final EventDrawSubject subject;

  /// Yalnızca `teams` kurasında, takım bileşeninin anahtarı.
  final String? teamsKey;

  /// Yalnızca çekilmiş kurada.
  final DateTime? drawnAt;

  /// Sıraya göre; kura çekilmemişse boş. Ardışık iki yer bir eşleşmedir.
  final List<EventDrawEntry> entries;

  /// Şu an kurayı çekebilirsiniz (kura çekilmemiş; organizatör, moderatör, yönetici; susturulmamış; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanDraw;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'drawn': drawn,
    'subject': subject.wire,
    if (teamsKey case final value?) 'teams_key': value,
    if (drawnAt case final value?) 'drawn_at': value.toUtc().toIso8601String(),
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
    'caller_can_draw': callerCanDraw,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventDraw &&
          drawn == other.drawn &&
          subject == other.subject &&
          teamsKey == other.teamsKey &&
          drawnAt == other.drawnAt &&
          _deepEquals(entries, other.entries) &&
          callerCanDraw == other.callerCanDraw;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    drawn,
    subject,
    teamsKey,
    drawnAt,
    _deepHash(entries),
    callerCanDraw,
  ]);
}

/// Kurada bir yer. Boş yerde (kişi ya da takım geri çekildi) ne `user_id` ne `team_id` vardır.
final class EventDrawEntry {
  const EventDrawEntry({
    required this.position,
    this.userId,
    this.teamId,
    this.guestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventDrawEntry.fromJson(Map<String, Object?> json) => EventDrawEntry(
    position: _readInt(json['position'], 'EventDrawEntry.position'),
    userId: switch (json['user_id']) {
      null => null,
      final Object v => _readString(v, 'EventDrawEntry.user_id'),
    },
    teamId: switch (json['team_id']) {
      null => null,
      final Object v => _readString(v, 'EventDrawEntry.team_id'),
    },
    guestId: switch (json['guest_id']) {
      null => null,
      final Object v => _readString(v, 'EventDrawEntry.guest_id'),
    },
  );

  /// Kısıtlar: minimum: 1; maximum: 500.
  final int position;

  /// Katılımcı kurasında kişinin kullanıcı kimliği.
  final String? userId;

  /// Takım kurasında `teams_key` bileşenindeki takımın kimliği.
  final String? teamId;

  /// Katılımcı kurasında misafir oyuncunun kimliği (`EventGuestPlayer.id`); misafirin yeri boşalmaz.
  final String? guestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'position': position,
    if (userId case final value?) 'user_id': value,
    if (teamId case final value?) 'team_id': value,
    if (guestId case final value?) 'guest_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventDrawEntry &&
          position == other.position &&
          userId == other.userId &&
          teamId == other.teamId &&
          guestId == other.guestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[position, userId, teamId, guestId]);
}

/// Kuranın sıraladığı (çekilmemişse şu an çekilse sıralayacağı) giriş türü.
enum EventDrawSubject {
  participants('participants'),
  teams('teams'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventDrawSubject(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventDrawSubject.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventDrawSubject fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventFeedback {
  const EventFeedback({this.answer, this.updatedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventFeedback.fromJson(Map<String, Object?> json) => EventFeedback(
    answer: switch (json['answer']) {
      null => null,
      final Object v => EventFeedbackAnswer.fromWire(
        _readString(v, 'EventFeedback.answer'),
      ),
    },
    updatedAt: switch (json['updated_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventFeedback.updated_at'),
    },
  );

  final EventFeedbackAnswer? answer;

  final DateTime? updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (answer case final value?) 'answer': value.wire,
    if (updatedAt case final value?)
      'updated_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventFeedback &&
          answer == other.answer &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[answer, updatedAt]);
}

enum EventFeedbackAnswer {
  ok('ok'),
  notOk('not_ok'),
  serious('serious'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const EventFeedbackAnswer(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventFeedbackAnswer.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventFeedbackAnswer fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventFeedbackInput {
  const EventFeedbackInput({required this.answer});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventFeedbackInput.fromJson(Map<String, Object?> json) =>
      EventFeedbackInput(
        answer: EventFeedbackInputAnswer.fromWire(
          _readString(json['answer'], 'EventFeedbackInput.answer'),
        ),
      );

  final EventFeedbackInputAnswer answer;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'answer': answer.wire};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventFeedbackInput && answer == other.answer;

  @override
  int get hashCode => Object.hashAll(<Object?>[answer]);
}

enum EventFeedbackInputAnswer {
  ok('ok'),
  notOk('not_ok'),
  serious('serious'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventFeedbackInputAnswer(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('EventFeedbackInputAnswer.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventFeedbackInputAnswer fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Bir etkinliğin bir hedef bileşeni, isteği yapanın gördüğü haliyle (#246).
final class EventGoal {
  const EventGoal({
    required this.measureKey,
    required this.unit,
    required this.decimals,
    this.target,
    required this.targetSet,
    this.targetUpdatedAt,
    this.defaultTarget,
    this.current,
    required this.progressHidden,
    required this.measureEnabled,
    required this.reached,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventGoal.fromJson(Map<String, Object?> json) => EventGoal(
    measureKey: _readString(json['measure_key'], 'EventGoal.measure_key'),
    unit: _readString(json['unit'], 'EventGoal.unit'),
    decimals: _readInt(json['decimals'], 'EventGoal.decimals'),
    target: switch (json['target']) {
      null => null,
      final Object v => _readDouble(v, 'EventGoal.target'),
    },
    targetSet: _readBool(json['target_set'], 'EventGoal.target_set'),
    targetUpdatedAt: switch (json['target_updated_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventGoal.target_updated_at'),
    },
    defaultTarget: switch (json['default_target']) {
      null => null,
      final Object v => _readDouble(v, 'EventGoal.default_target'),
    },
    current: switch (json['current']) {
      null => null,
      final Object v => _readDouble(v, 'EventGoal.current'),
    },
    progressHidden: _readBool(
      json['progress_hidden'],
      'EventGoal.progress_hidden',
    ),
    measureEnabled: _readBool(
      json['measure_enabled'],
      'EventGoal.measure_enabled',
    ),
    reached: _readBool(json['reached'], 'EventGoal.reached'),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventGoal.caller_can_edit',
    ),
  );

  /// Hedefin bağlı olduğu ölçümün anahtarı (`EventMeasure`).
  final String measureKey;

  /// Bağlı ölçümün birimi (kapalı liste, `CatalogComponent`); adı istemcinin çeviri dosyasında.
  final String unit;

  /// Bağlı ölçümün ondalık basamağı.
  ///
  /// Kısıtlar: minimum: 0; maximum: 3.
  final int decimals;

  /// Etkinliğin hedefi: organizatörün koyduğu, yoksa tanımdaki varsayılan; ikisi de yoksa yoktur.
  final double? target;

  /// Hedefi organizatör koydu (`false` ise varsayılan ya da hedef yok).
  final bool targetSet;

  /// Organizatörün hedefi son yazdığı an; yoksa yoktur.
  final DateTime? targetUpdatedAt;

  /// Tanımdaki varsayılan hedef; yoksa yoktur.
  final double? defaultTarget;

  /// Bağlı ölçümün kaydedilmiş değeri (toplam ölçüm) ya da değerlerinin
  /// toplamı (kişisel ölçüm); değer yoksa 0. Önerilen değer sayılmaz.
  /// `progress_hidden` ya da ölçüm kapalıysa yoktur.
  final double? current;

  /// İlerlemeyi göremezsiniz (hassas kişisel ölçüm).
  final bool progressHidden;

  /// Bağlı ölçüm bu etkinlikte açık (isteğe bağlı ölçüm kapalıysa ilerleme yoktur).
  final bool measureEnabled;

  /// `current` hedefe ulaştı.
  final bool reached;

  /// Şu an hedefi koyabilirsiniz (organizatör, moderatör, yönetici; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'measure_key': measureKey,
    'unit': unit,
    'decimals': decimals,
    if (target case final value?) 'target': value,
    'target_set': targetSet,
    if (targetUpdatedAt case final value?)
      'target_updated_at': value.toUtc().toIso8601String(),
    if (defaultTarget case final value?) 'default_target': value,
    if (current case final value?) 'current': value,
    'progress_hidden': progressHidden,
    'measure_enabled': measureEnabled,
    'reached': reached,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventGoal &&
          measureKey == other.measureKey &&
          unit == other.unit &&
          decimals == other.decimals &&
          target == other.target &&
          targetSet == other.targetSet &&
          targetUpdatedAt == other.targetUpdatedAt &&
          defaultTarget == other.defaultTarget &&
          current == other.current &&
          progressHidden == other.progressHidden &&
          measureEnabled == other.measureEnabled &&
          reached == other.reached &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    measureKey,
    unit,
    decimals,
    target,
    targetSet,
    targetUpdatedAt,
    defaultTarget,
    current,
    progressHidden,
    measureEnabled,
    reached,
    callerCanEdit,
  ]);
}

final class EventGoalTargetRequest {
  const EventGoalTargetRequest({required this.target});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventGoalTargetRequest.fromJson(Map<String, Object?> json) =>
      EventGoalTargetRequest(
        target: _readDouble(json['target'], 'EventGoalTargetRequest.target'),
      );

  /// Bağlı ölçümün biriminde; ondalık basamağına yuvarlanır.
  ///
  /// Kısıtlar: maximum: 1000000000; exclusiveMinimum: 0.
  final double target;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'target': target};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventGoalTargetRequest && target == other.target;

  @override
  int get hashCode => Object.hashAll(<Object?>[target]);
}

/// Misafir oyuncu: uygulamada hesabı olmayan, yalnızca takma adla
/// oynayan kişi. Profili, kişisel kaydı ve iletişim alanı yoktur;
/// istatistiğe girmez.
final class EventGuestPlayer {
  const EventGuestPlayer({
    required this.id,
    this.nickname,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventGuestPlayer.fromJson(Map<String, Object?> json) =>
      EventGuestPlayer(
        id: _readString(json['id'], 'EventGuestPlayer.id'),
        nickname: switch (json['nickname']) {
          null => null,
          final Object v => _readString(v, 'EventGuestPlayer.nickname'),
        },
        createdAt: _readDateTime(
          json['created_at'],
          'EventGuestPlayer.created_at',
        ),
      );

  final String id;

  /// Takma ad. Etkinliğin bitiminden 30 gün sonra (ya da ekleyen hesabını silince) silinir ve alan yer almaz; istemci adsız misafir gösterir.
  ///
  /// Kısıtlar: maxLength: 24.
  final String? nickname;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (nickname case final value?) 'nickname': value,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventGuestPlayer &&
          id == other.id &&
          nickname == other.nickname &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[id, nickname, createdAt]);
}

final class EventGuestPlayerRequest {
  const EventGuestPlayerRequest({required this.nickname, this.tableId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventGuestPlayerRequest.fromJson(Map<String, Object?> json) =>
      EventGuestPlayerRequest(
        nickname: _readString(
          json['nickname'],
          'EventGuestPlayerRequest.nickname',
        ),
        tableId: switch (json['table_id']) {
          null => null,
          final Object v => _readString(v, 'EventGuestPlayerRequest.table_id'),
        },
      );

  /// Baştaki ve sondaki boşluk atılır; denetim ve biçim karakterleri reddedilir.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 24.
  final String nickname;

  /// Ekleyen masanın hakemiyse o masa (`EventScoreTable.id`); organizatör ve etkinliğin ya da bileşenin hakemi vermez.
  final String? tableId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'nickname': nickname,
    if (tableId case final value?) 'table_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventGuestPlayerRequest &&
          nickname == other.nickname &&
          tableId == other.tableId;

  @override
  int get hashCode => Object.hashAll(<Object?>[nickname, tableId]);
}

final class EventGuestPlayers {
  const EventGuestPlayers({
    required this.guests,
    required this.maxGuests,
    required this.callerCanAdd,
    required this.callerCanRemove,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventGuestPlayers.fromJson(Map<String, Object?> json) =>
      EventGuestPlayers(
        guests: List<EventGuestPlayer>.unmodifiable(
          _readList(json['guests'], 'EventGuestPlayers.guests').map(
            (Object? e0) => EventGuestPlayer.fromJson(
              _readObject(e0, 'EventGuestPlayers.guests'),
            ),
          ),
        ),
        maxGuests: _readInt(json['max_guests'], 'EventGuestPlayers.max_guests'),
        callerCanAdd: _readBool(
          json['caller_can_add'],
          'EventGuestPlayers.caller_can_add',
        ),
        callerCanRemove: _readBool(
          json['caller_can_remove'],
          'EventGuestPlayers.caller_can_remove',
        ),
      );

  /// Eklenme sırasıyla.
  final List<EventGuestPlayer> guests;

  /// Etkinlik başına en fazla misafir (30).
  final int maxGuests;

  /// Çağıran şimdi masa vermeden misafir ekleyebilir (organizatör, moderatör, yönetici ya da etkinliğin veya bileşenin hakemi). Masanın hakemi `table_id` ile ekler.
  final bool callerCanAdd;

  /// Çağıran şimdi misafir silebilir (organizatör, moderatör, yönetici).
  final bool callerCanRemove;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'guests': <Object?>[for (final e0 in guests) e0.toJson()],
    'max_guests': maxGuests,
    'caller_can_add': callerCanAdd,
    'caller_can_remove': callerCanRemove,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventGuestPlayers &&
          _deepEquals(guests, other.guests) &&
          maxGuests == other.maxGuests &&
          callerCanAdd == other.callerCanAdd &&
          callerCanRemove == other.callerCanRemove;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(guests),
    maxGuests,
    callerCanAdd,
    callerCanRemove,
  ]);
}

final class EventList {
  const EventList({required this.events, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventList.fromJson(Map<String, Object?> json) => EventList(
    events: List<Event>.unmodifiable(
      _readList(json['events'], 'EventList.events').map(
        (Object? e0) => Event.fromJson(_readObject(e0, 'EventList.events')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'EventList.next_page_token'),
    },
  );

  final List<Event> events;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'events': <Object?>[for (final e0 in events) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventList &&
          _deepEquals(events, other.events) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(events), nextPageToken]);
}

/// Bir günlük kaydı, isteği yapanın gördüğü haliyle (#243).
final class EventLogEntry {
  const EventLogEntry({
    required this.id,
    required this.userId,
    required this.values,
    this.location,
    this.locationVisibility,
    this.photoUploadId,
    required this.createdAt,
    required this.callerCanRemove,
    this.vocabularyIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventLogEntry.fromJson(Map<String, Object?> json) => EventLogEntry(
    id: _readString(json['id'], 'EventLogEntry.id'),
    userId: _readString(json['user_id'], 'EventLogEntry.user_id'),
    values: _readJsonObject(json['values'], 'EventLogEntry.values'),
    location: switch (json['location']) {
      null => null,
      final Object v => LatLng.fromJson(
        _readObject(v, 'EventLogEntry.location'),
      ),
    },
    locationVisibility: switch (json['location_visibility']) {
      null => null,
      final Object v => LogLocationVisibility.fromWire(
        _readString(v, 'EventLogEntry.location_visibility'),
      ),
    },
    photoUploadId: switch (json['photo_upload_id']) {
      null => null,
      final Object v => _readString(v, 'EventLogEntry.photo_upload_id'),
    },
    createdAt: _readDateTime(json['created_at'], 'EventLogEntry.created_at'),
    callerCanRemove: _readBool(
      json['caller_can_remove'],
      'EventLogEntry.caller_can_remove',
    ),
    vocabularyIds: switch (json['vocabulary_ids']) {
      null => null,
      final Object v => Map<String, String>.unmodifiable(
        _readObject(v, 'EventLogEntry.vocabulary_ids').map(
          (String k0, Object? e0) =>
              MapEntry(k0, _readString(e0, 'EventLogEntry.vocabulary_ids')),
        ),
      ),
    },
  );

  final String id;

  /// Kaydı giren.
  final String userId;

  /// Kaydın alan değerleri; alanlar bileşenin `fields` parametresindedir.
  final Map<String, Object?> values;

  /// Kaydın konumu; yoksa ya da görmeniz gerekmiyorsa yoktur.
  final LatLng? location;

  /// Yalnızca kendi konumlu kayıtlarınızda.
  final LogLocationVisibility? locationVisibility;

  /// Fotoğraf; linkleri `POST /v1/media/urls`. Kaydı gören her üye görür.
  final String? photoUploadId;

  final DateTime createdAt;

  /// Kaydı şu an çıkarabilirsiniz.
  final bool callerCanRemove;

  /// Tayfa sözlüğüne bağlı alanların değerleri (birleştirme hedefine
  /// çözülmüş); metinleri `values`'ta. Böyle alan yoksa yoktur.
  final Map<String, String>? vocabularyIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'values': values,
    if (location case final value?) 'location': value.toJson(),
    if (locationVisibility case final value?) 'location_visibility': value.wire,
    if (photoUploadId case final value?) 'photo_upload_id': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'caller_can_remove': callerCanRemove,
    if (vocabularyIds case final value?)
      'vocabulary_ids': <String, Object?>{
        for (final e0 in value.entries) e0.key: e0.value,
      },
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventLogEntry &&
          id == other.id &&
          userId == other.userId &&
          _deepEquals(values, other.values) &&
          location == other.location &&
          locationVisibility == other.locationVisibility &&
          photoUploadId == other.photoUploadId &&
          createdAt == other.createdAt &&
          callerCanRemove == other.callerCanRemove &&
          _deepEquals(vocabularyIds, other.vocabularyIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    userId,
    _deepHash(values),
    location,
    locationVisibility,
    photoUploadId,
    createdAt,
    callerCanRemove,
    _deepHash(vocabularyIds),
  ]);
}

final class EventLogEntryCreateRequest {
  const EventLogEntryCreateRequest({
    required this.values,
    this.location,
    this.locationVisibility,
    this.photoUploadId,
    required this.clientRequestId,
    this.vocabularyIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventLogEntryCreateRequest.fromJson(Map<String, Object?> json) =>
      EventLogEntryCreateRequest(
        values: _readJsonObject(
          json['values'],
          'EventLogEntryCreateRequest.values',
        ),
        location: switch (json['location']) {
          null => null,
          final Object v => LatLng.fromJson(
            _readObject(v, 'EventLogEntryCreateRequest.location'),
          ),
        },
        locationVisibility: switch (json['location_visibility']) {
          null => null,
          final Object v => LogLocationVisibility.fromWire(
            _readString(v, 'EventLogEntryCreateRequest.location_visibility'),
          ),
        },
        photoUploadId: switch (json['photo_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'EventLogEntryCreateRequest.photo_upload_id',
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'EventLogEntryCreateRequest.client_request_id',
        ),
        vocabularyIds: switch (json['vocabulary_ids']) {
          null => null,
          final Object v => Map<String, String>.unmodifiable(
            _readObject(v, 'EventLogEntryCreateRequest.vocabulary_ids').map(
              (String k0, Object? e0) => MapEntry(
                k0,
                _readString(e0, 'EventLogEntryCreateRequest.vocabulary_ids'),
              ),
            ),
          ),
        },
      );

  /// Kaydın alan değerleri (en fazla 8); zorunlu alanlar verilir.
  final Map<String, Object?> values;

  /// İsteğe bağlı; yalnızca `location_enabled` günlükte. Kişinin seçtiği nokta.
  final LatLng? location;

  /// Yalnızca konumla; yoksa günlüğün varsayılanı.
  final LogLocationVisibility? locationVisibility;

  /// İsteğe bağlı: kendi hazır `log_photo` yüklemeniz (bu tayfa için).
  /// Fotoğrafın konum bilgisi (EXIF/GPS) işlemede silinmiştir; kaydın
  /// konumu yalnızca `location` ile paylaşılır.
  final String? photoUploadId;

  final String clientRequestId;

  /// Tayfa sözlüğüne bağlı alanlar için var olan değerler (en fazla
  /// 8); aynı alan `values`'ta da verilmez.
  final Map<String, String>? vocabularyIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'values': values,
    if (location case final value?) 'location': value.toJson(),
    if (locationVisibility case final value?) 'location_visibility': value.wire,
    if (photoUploadId case final value?) 'photo_upload_id': value,
    'client_request_id': clientRequestId,
    if (vocabularyIds case final value?)
      'vocabulary_ids': <String, Object?>{
        for (final e0 in value.entries) e0.key: e0.value,
      },
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventLogEntryCreateRequest &&
          _deepEquals(values, other.values) &&
          location == other.location &&
          locationVisibility == other.locationVisibility &&
          photoUploadId == other.photoUploadId &&
          clientRequestId == other.clientRequestId &&
          _deepEquals(vocabularyIds, other.vocabularyIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(values),
    location,
    locationVisibility,
    photoUploadId,
    clientRequestId,
    _deepHash(vocabularyIds),
  ]);
}

/// Bir etkinliğin bir günlük bileşeninin kayıtları, eskiden yeniye (#243).
final class EventLogEntryList {
  const EventLogEntryList({
    required this.entries,
    this.nextPageToken,
    required this.locationEnabled,
    this.locationDefault,
    required this.maxEntries,
    required this.callerCanAdd,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventLogEntryList.fromJson(Map<String, Object?> json) =>
      EventLogEntryList(
        entries: List<EventLogEntry>.unmodifiable(
          _readList(json['entries'], 'EventLogEntryList.entries').map(
            (Object? e0) => EventLogEntry.fromJson(
              _readObject(e0, 'EventLogEntryList.entries'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'EventLogEntryList.next_page_token'),
        },
        locationEnabled: _readBool(
          json['location_enabled'],
          'EventLogEntryList.location_enabled',
        ),
        locationDefault: switch (json['location_default']) {
          null => null,
          final Object v => LogLocationVisibility.fromWire(
            _readString(v, 'EventLogEntryList.location_default'),
          ),
        },
        maxEntries: _readInt(
          json['max_entries'],
          'EventLogEntryList.max_entries',
        ),
        callerCanAdd: _readBool(
          json['caller_can_add'],
          'EventLogEntryList.caller_can_add',
        ),
      );

  /// Kısıtlar: maxItems: 100.
  final List<EventLogEntry> entries;

  final String? nextPageToken;

  /// Bileşenin `location` parametresi; kapalıysa kayda konum verilmez.
  final bool locationEnabled;

  /// Yeni kaydın konum görünürlüğünün varsayılanı; konum kapalıysa yoktur.
  final LogLocationVisibility? locationDefault;

  /// Kişi başına en fazla kayıt.
  ///
  /// Kısıtlar: minimum: 1; maximum: 500.
  final int maxEntries;

  /// Şu an kayıt ekleyebilirsiniz (katılımınız doğrulanmış, susturulmamış; etkinlik iptal değil, donmamış, tayfa salt okunur değil). Sayı sınırı ayrıca denetlenir.
  final bool callerCanAdd;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
    'location_enabled': locationEnabled,
    if (locationDefault case final value?) 'location_default': value.wire,
    'max_entries': maxEntries,
    'caller_can_add': callerCanAdd,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventLogEntryList &&
          _deepEquals(entries, other.entries) &&
          nextPageToken == other.nextPageToken &&
          locationEnabled == other.locationEnabled &&
          locationDefault == other.locationDefault &&
          maxEntries == other.maxEntries &&
          callerCanAdd == other.callerCanAdd;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(entries),
    nextPageToken,
    locationEnabled,
    locationDefault,
    maxEntries,
    callerCanAdd,
  ]);
}

/// Bir etkinliğin bir ölçüm bileşeni, isteği yapanın gördüğü haliyle (#245).
final class EventMeasure {
  const EventMeasure({
    required this.unit,
    required this.scope,
    required this.enteredBy,
    required this.min,
    required this.max,
    required this.decimals,
    this.total,
    this.totalUpdatedAt,
    required this.entries,
    this.suggested,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventMeasure.fromJson(Map<String, Object?> json) => EventMeasure(
    unit: _readString(json['unit'], 'EventMeasure.unit'),
    scope: EventMeasureScope.fromWire(
      _readString(json['scope'], 'EventMeasure.scope'),
    ),
    enteredBy: EventMeasureEnteredBy.fromWire(
      _readString(json['entered_by'], 'EventMeasure.entered_by'),
    ),
    min: _readDouble(json['min'], 'EventMeasure.min'),
    max: _readDouble(json['max'], 'EventMeasure.max'),
    decimals: _readInt(json['decimals'], 'EventMeasure.decimals'),
    total: switch (json['total']) {
      null => null,
      final Object v => _readDouble(v, 'EventMeasure.total'),
    },
    totalUpdatedAt: switch (json['total_updated_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventMeasure.total_updated_at'),
    },
    entries: List<EventMeasureEntry>.unmodifiable(
      _readList(json['entries'], 'EventMeasure.entries').map(
        (Object? e0) =>
            EventMeasureEntry.fromJson(_readObject(e0, 'EventMeasure.entries')),
      ),
    ),
    suggested: switch (json['suggested']) {
      null => null,
      final Object v => _readDouble(v, 'EventMeasure.suggested'),
    },
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventMeasure.caller_can_edit',
    ),
  );

  /// Tanımdaki birim (kapalı liste, `CatalogComponent`); adı istemcinin çeviri dosyasında.
  final String unit;

  /// `total` etkinlik başına tek değer, `personal` katılımcı başına.
  final EventMeasureScope scope;

  /// `self` katılımcı kendi adına girer; `organizer` organizatör ve atanmış hakem girer.
  final EventMeasureEnteredBy enteredBy;

  /// Değerin alt sınırı (tanımda yoksa 0).
  final double min;

  /// Değerin üst sınırı (tanımda yoksa 1000000000).
  final double max;

  /// Değerin yuvarlandığı ondalık basamak.
  ///
  /// Kısıtlar: minimum: 0; maximum: 3.
  final int decimals;

  /// Toplam ölçümün değeri; yoksa ya da kişisel ölçümde yoktur.
  final double? total;

  /// Toplamın son yazıldığı an; değer yoksa yoktur.
  final DateTime? totalUpdatedAt;

  /// Kişisel ölçümün görebildiğiniz değerleri, en eski değişiklik önce; toplam ölçümde boş.
  final List<EventMeasureEntry> entries;

  /// Önerilen değer (`prefill_from`): etkinlik bittikten sonra, toplam
  /// ölçümün değeri yokken etkinliğin ilgili alanının değeri. Biri
  /// yazana kadar ölçüm sayılmaz.
  final double? suggested;

  /// Şu an yazabilirsiniz (toplamı, kendi değerinizi ya da herkesinkini; ölçümün kuralına göre). Etkinlik başlamış, iptal değil, donmamış, tayfa salt okunur değil.
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'unit': unit,
    'scope': scope.wire,
    'entered_by': enteredBy.wire,
    'min': min,
    'max': max,
    'decimals': decimals,
    if (total case final value?) 'total': value,
    if (totalUpdatedAt case final value?)
      'total_updated_at': value.toUtc().toIso8601String(),
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
    if (suggested case final value?) 'suggested': value,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventMeasure &&
          unit == other.unit &&
          scope == other.scope &&
          enteredBy == other.enteredBy &&
          min == other.min &&
          max == other.max &&
          decimals == other.decimals &&
          total == other.total &&
          totalUpdatedAt == other.totalUpdatedAt &&
          _deepEquals(entries, other.entries) &&
          suggested == other.suggested &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    unit,
    scope,
    enteredBy,
    min,
    max,
    decimals,
    total,
    totalUpdatedAt,
    _deepHash(entries),
    suggested,
    callerCanEdit,
  ]);
}

/// `self` katılımcı kendi adına girer; `organizer` organizatör ve atanmış hakem girer.
enum EventMeasureEnteredBy {
  self('self'),
  organizer('organizer'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventMeasureEnteredBy(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventMeasureEnteredBy.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventMeasureEnteredBy fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventMeasureEntry {
  const EventMeasureEntry({
    required this.userId,
    required this.value,
    this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventMeasureEntry.fromJson(Map<String, Object?> json) =>
      EventMeasureEntry(
        userId: _readString(json['user_id'], 'EventMeasureEntry.user_id'),
        value: _readDouble(json['value'], 'EventMeasureEntry.value'),
        updatedAt: switch (json['updated_at']) {
          null => null,
          final Object v => _readDateTime(v, 'EventMeasureEntry.updated_at'),
        },
      );

  /// Değerin ait olduğu katılımcı.
  final String userId;

  final double value;

  final DateTime? updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'value': value,
    if (updatedAt case final value?)
      'updated_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventMeasureEntry &&
          userId == other.userId &&
          value == other.value &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, value, updatedAt]);
}

/// `total` etkinlik başına tek değer, `personal` katılımcı başına.
enum EventMeasureScope {
  total('total'),
  personal('personal'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventMeasureScope(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventMeasureScope.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventMeasureScope fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventMeasureValueRequest {
  const EventMeasureValueRequest({required this.value});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventMeasureValueRequest.fromJson(Map<String, Object?> json) =>
      EventMeasureValueRequest(
        value: _readDouble(json['value'], 'EventMeasureValueRequest.value'),
      );

  /// Tanımdaki sınırlar içinde; ondalık basamağa yuvarlanır.
  ///
  /// Kısıtlar: minimum: -1000000000; maximum: 1000000000.
  final double value;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventMeasureValueRequest && value == other.value;

  @override
  int get hashCode => Object.hashAll(<Object?>[value]);
}

enum EventMode {
  inPerson('in_person'),
  online('online'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventMode(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventMode.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventMode fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventPhoto {
  const EventPhoto({
    required this.id,
    required this.eventId,
    required this.uploaderId,
    required this.uploadId,
    this.caption,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventPhoto.fromJson(Map<String, Object?> json) => EventPhoto(
    id: _readString(json['id'], 'EventPhoto.id'),
    eventId: _readString(json['event_id'], 'EventPhoto.event_id'),
    uploaderId: _readString(json['uploader_id'], 'EventPhoto.uploader_id'),
    uploadId: _readString(json['upload_id'], 'EventPhoto.upload_id'),
    caption: switch (json['caption']) {
      null => null,
      final Object v => _readString(v, 'EventPhoto.caption'),
    },
    createdAt: _readDateTime(json['created_at'], 'EventPhoto.created_at'),
  );

  final String id;

  final String eventId;

  final String uploaderId;

  /// Linkleri `POST /v1/media/urls`.
  final String uploadId;

  /// Açıklama yoksa alan yoktur.
  final String? caption;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'event_id': eventId,
    'uploader_id': uploaderId,
    'upload_id': uploadId,
    if (caption case final value?) 'caption': value,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventPhoto &&
          id == other.id &&
          eventId == other.eventId &&
          uploaderId == other.uploaderId &&
          uploadId == other.uploadId &&
          caption == other.caption &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    eventId,
    uploaderId,
    uploadId,
    caption,
    createdAt,
  ]);
}

final class EventPhotoCreateRequest {
  const EventPhotoCreateRequest({
    required this.uploadId,
    this.caption,
    required this.clientRequestId,
    this.consentAck,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventPhotoCreateRequest.fromJson(Map<String, Object?> json) =>
      EventPhotoCreateRequest(
        uploadId: _readString(
          json['upload_id'],
          'EventPhotoCreateRequest.upload_id',
        ),
        caption: switch (json['caption']) {
          null => null,
          final Object v => _readString(v, 'EventPhotoCreateRequest.caption'),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'EventPhotoCreateRequest.client_request_id',
        ),
        consentAck: switch (json['consent_ack']) {
          null => null,
          final Object v => _readBool(v, 'EventPhotoCreateRequest.consent_ack'),
        },
      );

  /// Kendi hazır `event_photo` yüklemeniz (bu tayfa için, başka içeriğe
  /// bağlanmamış). Konum bilgisi (EXIF/GPS) işlemede silinmiştir.
  final String uploadId;

  /// İsteğe bağlı; boşluklar kırpılır, boş ise yok sayılır.
  ///
  /// Kısıtlar: maxLength: 200.
  final String? caption;

  final String clientRequestId;

  /// Yüzü görünenlerden (çocuklarda velisinden) izin alındığının
  /// onayı. Türü `album_notice` bayraklı etkinlikte `true` olmalıdır
  /// (`album-consent-required`); diğerlerinde yok sayılır. Saklanmaz.
  ///
  /// Kısıtlar: varsayılan (sunucu): false.
  final bool? consentAck;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'upload_id': uploadId,
    if (caption case final value?) 'caption': value,
    'client_request_id': clientRequestId,
    if (consentAck case final value?) 'consent_ack': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventPhotoCreateRequest &&
          uploadId == other.uploadId &&
          caption == other.caption &&
          clientRequestId == other.clientRequestId &&
          consentAck == other.consentAck;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[uploadId, caption, clientRequestId, consentAck]);
}

final class EventPhotoList {
  const EventPhotoList({required this.photos, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventPhotoList.fromJson(Map<String, Object?> json) => EventPhotoList(
    photos: List<EventPhoto>.unmodifiable(
      _readList(json['photos'], 'EventPhotoList.photos').map(
        (Object? e0) =>
            EventPhoto.fromJson(_readObject(e0, 'EventPhotoList.photos')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'EventPhotoList.next_page_token'),
    },
  );

  final List<EventPhoto> photos;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'photos': <Object?>[for (final e0 in photos) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventPhotoList &&
          _deepEquals(photos, other.photos) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(photos), nextPageToken]);
}

/// Bir etkinliğin soru havuzu bağlantısı bileşeni (#271).
final class EventPoolLinks {
  const EventPoolLinks({
    required this.questions,
    required this.maxLinks,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventPoolLinks.fromJson(Map<String, Object?> json) => EventPoolLinks(
    questions: List<PoolLinkedQuestion>.unmodifiable(
      _readList(json['questions'], 'EventPoolLinks.questions').map(
        (Object? e0) => PoolLinkedQuestion.fromJson(
          _readObject(e0, 'EventPoolLinks.questions'),
        ),
      ),
    ),
    maxLinks: _readInt(json['max_links'], 'EventPoolLinks.max_links'),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventPoolLinks.caller_can_edit',
    ),
  );

  /// Kısıtlar: maxItems: 50.
  final List<PoolLinkedQuestion> questions;

  /// Bileşenin bağlayabileceği en fazla soru.
  ///
  /// Kısıtlar: minimum: 1; maximum: 50.
  final int maxLinks;

  /// Listeyi şu an değiştirebilirsiniz (organizatör yetkisi; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'questions': <Object?>[for (final e0 in questions) e0.toJson()],
    'max_links': maxLinks,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventPoolLinks &&
          _deepEquals(questions, other.questions) &&
          maxLinks == other.maxLinks &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(questions), maxLinks, callerCanEdit]);
}

final class EventPoolLinksRequest {
  const EventPoolLinksRequest({required this.questionIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventPoolLinksRequest.fromJson(Map<String, Object?> json) =>
      EventPoolLinksRequest(
        questionIds: List<String>.unmodifiable(
          _readList(
            json['question_ids'],
            'EventPoolLinksRequest.question_ids',
          ).map(
            (Object? e0) =>
                _readString(e0, 'EventPoolLinksRequest.question_ids'),
          ),
        ),
      );

  /// Bağlı soruların yeni hali, sırasıyla; boş dizi bütün bağları kaldırır.
  ///
  /// Kısıtlar: maxItems: 50; uniqueItems: true.
  final List<String> questionIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'question_ids': <Object?>[for (final e0 in questionIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventPoolLinksRequest &&
          _deepEquals(questionIds, other.questionIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(questionIds)]);
}

/// Bir etkinlik sorusu, isteği yapanın gördüğü haliyle (#256).
final class EventQuestion {
  const EventQuestion({
    required this.id,
    required this.body,
    required this.anonymous,
    this.authorId,
    required this.callerIsAuthor,
    required this.voteCount,
    required this.callerVoted,
    this.answeredAt,
    required this.createdAt,
    required this.callerCanRemove,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventQuestion.fromJson(Map<String, Object?> json) => EventQuestion(
    id: _readString(json['id'], 'EventQuestion.id'),
    body: _readString(json['body'], 'EventQuestion.body'),
    anonymous: _readBool(json['anonymous'], 'EventQuestion.anonymous'),
    authorId: switch (json['author_id']) {
      null => null,
      final Object v => _readString(v, 'EventQuestion.author_id'),
    },
    callerIsAuthor: _readBool(
      json['caller_is_author'],
      'EventQuestion.caller_is_author',
    ),
    voteCount: _readInt(json['vote_count'], 'EventQuestion.vote_count'),
    callerVoted: _readBool(json['caller_voted'], 'EventQuestion.caller_voted'),
    answeredAt: switch (json['answered_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventQuestion.answered_at'),
    },
    createdAt: _readDateTime(json['created_at'], 'EventQuestion.created_at'),
    callerCanRemove: _readBool(
      json['caller_can_remove'],
      'EventQuestion.caller_can_remove',
    ),
  );

  final String id;

  /// Kısıtlar: minLength: 1; maxLength: 500.
  final String body;

  /// Anonim soru; `author_id` hiçbir zaman verilmez.
  final bool anonymous;

  /// Soran; anonim soruda yoktur (yazara ve yönetime de).
  final String? authorId;

  /// Soruyu siz sordunuz.
  final bool callerIsAuthor;

  /// Kısıtlar: minimum: 0.
  final int voteCount;

  /// Bu soruya oy verdiniz.
  final bool callerVoted;

  /// Yalnızca cevaplandı işaretliyse.
  final DateTime? answeredAt;

  final DateTime createdAt;

  /// Soruyu şu an kaldırabilirsiniz.
  final bool callerCanRemove;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'body': body,
    'anonymous': anonymous,
    if (authorId case final value?) 'author_id': value,
    'caller_is_author': callerIsAuthor,
    'vote_count': voteCount,
    'caller_voted': callerVoted,
    if (answeredAt case final value?)
      'answered_at': value.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'caller_can_remove': callerCanRemove,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventQuestion &&
          id == other.id &&
          body == other.body &&
          anonymous == other.anonymous &&
          authorId == other.authorId &&
          callerIsAuthor == other.callerIsAuthor &&
          voteCount == other.voteCount &&
          callerVoted == other.callerVoted &&
          answeredAt == other.answeredAt &&
          createdAt == other.createdAt &&
          callerCanRemove == other.callerCanRemove;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    body,
    anonymous,
    authorId,
    callerIsAuthor,
    voteCount,
    callerVoted,
    answeredAt,
    createdAt,
    callerCanRemove,
  ]);
}

final class EventQuestionCreateRequest {
  const EventQuestionCreateRequest({
    required this.body,
    this.anonymous,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventQuestionCreateRequest.fromJson(Map<String, Object?> json) =>
      EventQuestionCreateRequest(
        body: _readString(json['body'], 'EventQuestionCreateRequest.body'),
        anonymous: switch (json['anonymous']) {
          null => null,
          final Object v => _readBool(
            v,
            'EventQuestionCreateRequest.anonymous',
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'EventQuestionCreateRequest.client_request_id',
        ),
      );

  /// Soru; kırpıldıktan ve iç boşluklar teke indirildikten sonra 1–500 karakter.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 2256.
  final String body;

  /// Yalnızca `anonymous_allowed` bileşende.
  ///
  /// Kısıtlar: varsayılan (sunucu): false.
  final bool? anonymous;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    if (anonymous case final value?) 'anonymous': value,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventQuestionCreateRequest &&
          body == other.body &&
          anonymous == other.anonymous &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[body, anonymous, clientRequestId]);
}

/// Bir etkinliğin bir soru toplama bileşeninin soruları (#256).
final class EventQuestionList {
  const EventQuestionList({
    required this.questions,
    required this.anonymousAllowed,
    required this.callerCanAsk,
    required this.callerCanMarkAnswered,
    required this.maxQuestionsPerPerson,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventQuestionList.fromJson(Map<String, Object?> json) =>
      EventQuestionList(
        questions: List<EventQuestion>.unmodifiable(
          _readList(json['questions'], 'EventQuestionList.questions').map(
            (Object? e0) => EventQuestion.fromJson(
              _readObject(e0, 'EventQuestionList.questions'),
            ),
          ),
        ),
        anonymousAllowed: _readBool(
          json['anonymous_allowed'],
          'EventQuestionList.anonymous_allowed',
        ),
        callerCanAsk: _readBool(
          json['caller_can_ask'],
          'EventQuestionList.caller_can_ask',
        ),
        callerCanMarkAnswered: _readBool(
          json['caller_can_mark_answered'],
          'EventQuestionList.caller_can_mark_answered',
        ),
        maxQuestionsPerPerson: _readInt(
          json['max_questions_per_person'],
          'EventQuestionList.max_questions_per_person',
        ),
      );

  /// Cevaplanmamışlar önce, sonra çok oy alan, sonra eski.
  ///
  /// Kısıtlar: maxItems: 500.
  final List<EventQuestion> questions;

  /// Bileşenin `anonymous` parametresi; açıksa soru anonim sorulabilir.
  final bool anonymousAllowed;

  /// Şu an soru sorabilir ve oy verebilirsiniz (`going` ya da katılımı doğrulanmış, susturulmamış; etkinlik iptal değil, donmamış, tayfa salt okunur değil). Sayı sınırları ayrıca denetlenir.
  final bool callerCanAsk;

  /// Şu an soruları cevaplandı işaretleyebilirsiniz.
  final bool callerCanMarkAnswered;

  /// Kişi başına en fazla soru.
  ///
  /// Kısıtlar: minimum: 1.
  final int maxQuestionsPerPerson;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'questions': <Object?>[for (final e0 in questions) e0.toJson()],
    'anonymous_allowed': anonymousAllowed,
    'caller_can_ask': callerCanAsk,
    'caller_can_mark_answered': callerCanMarkAnswered,
    'max_questions_per_person': maxQuestionsPerPerson,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventQuestionList &&
          _deepEquals(questions, other.questions) &&
          anonymousAllowed == other.anonymousAllowed &&
          callerCanAsk == other.callerCanAsk &&
          callerCanMarkAnswered == other.callerCanMarkAnswered &&
          maxQuestionsPerPerson == other.maxQuestionsPerPerson;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(questions),
    anonymousAllowed,
    callerCanAsk,
    callerCanMarkAnswered,
    maxQuestionsPerPerson,
  ]);
}

/// Bir etkinliğin bir derece bileşeni, isteği yapanın gördüğü haliyle (#253).
final class EventRanking {
  const EventRanking({
    this.source,
    this.metric,
    required this.direction,
    this.unit,
    required this.decimals,
    required this.entries,
    required this.hidden,
    required this.measureEnabled,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRanking.fromJson(Map<String, Object?> json) => EventRanking(
    source: switch (json['source']) {
      null => null,
      final Object v => _readString(v, 'EventRanking.source'),
    },
    metric: switch (json['metric']) {
      null => null,
      final Object v => EventRankingMetric.fromWire(
        _readString(v, 'EventRanking.metric'),
      ),
    },
    direction: EventRankingDirection.fromWire(
      _readString(json['direction'], 'EventRanking.direction'),
    ),
    unit: switch (json['unit']) {
      null => null,
      final Object v => _readString(v, 'EventRanking.unit'),
    },
    decimals: _readInt(json['decimals'], 'EventRanking.decimals'),
    entries: List<EventRankingEntry>.unmodifiable(
      _readList(json['entries'], 'EventRanking.entries').map(
        (Object? e0) =>
            EventRankingEntry.fromJson(_readObject(e0, 'EventRanking.entries')),
      ),
    ),
    hidden: _readBool(json['hidden'], 'EventRanking.hidden'),
    measureEnabled: _readBool(
      json['measure_enabled'],
      'EventRanking.measure_enabled',
    ),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventRanking.caller_can_edit',
    ),
  );

  /// Derecenin hesaplandığı kişisel ölçümün anahtarı (`EventMeasure`); elle girilen derecede yoktur.
  final String? source;

  /// Elle girilen derecenin ölçütü: `duration` süre (saniye), `rank` sıra. Ölçümden hesaplanan derecede yoktur.
  final EventRankingMetric? metric;

  /// `asc` en küçük değer önde (süre, sıra), `desc` en büyük değer önde.
  final EventRankingDirection direction;

  /// Ölçümden hesaplanan derecede ölçümün birimi (kapalı liste); elle girilen derecede yoktur.
  final String? unit;

  /// Değerin ondalık basamağı: ölçümünki ya da ölçütünkü (`duration` 2, `rank` 0).
  ///
  /// Kısıtlar: minimum: 0; maximum: 3.
  final int decimals;

  /// Katılımcılar sırayla, en iyi önde; gizliyken ya da kaynak ölçüm kapalıyken boş.
  final List<EventRankingEntry> entries;

  /// Derece hassas bir ölçümden hesaplanıyor ve ölçümün bütün değerlerini göremiyorsunuz.
  final bool hidden;

  /// Ölçümden hesaplanan derecede kaynak ölçüm bu etkinlikte açık; elle girilen derecede her zaman `true`.
  final bool measureEnabled;

  /// Şu an değer girebilirsiniz (yalnızca elle girilen derecede; organizatör, moderatör, yönetici ya da atanmış hakem). Etkinlik başlamış, iptal değil, donmamış, tayfa salt okunur değil.
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (source case final value?) 'source': value,
    if (metric case final value?) 'metric': value.wire,
    'direction': direction.wire,
    if (unit case final value?) 'unit': value,
    'decimals': decimals,
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
    'hidden': hidden,
    'measure_enabled': measureEnabled,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRanking &&
          source == other.source &&
          metric == other.metric &&
          direction == other.direction &&
          unit == other.unit &&
          decimals == other.decimals &&
          _deepEquals(entries, other.entries) &&
          hidden == other.hidden &&
          measureEnabled == other.measureEnabled &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    source,
    metric,
    direction,
    unit,
    decimals,
    _deepHash(entries),
    hidden,
    measureEnabled,
    callerCanEdit,
  ]);
}

/// `asc` en küçük değer önde (süre, sıra), `desc` en büyük değer önde.
enum EventRankingDirection {
  asc('asc'),
  desc('desc'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventRankingDirection(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventRankingDirection.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventRankingDirection fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventRankingEntry {
  const EventRankingEntry({
    required this.userId,
    required this.value,
    required this.rank,
    this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRankingEntry.fromJson(Map<String, Object?> json) =>
      EventRankingEntry(
        userId: _readString(json['user_id'], 'EventRankingEntry.user_id'),
        value: _readDouble(json['value'], 'EventRankingEntry.value'),
        rank: _readInt(json['rank'], 'EventRankingEntry.rank'),
        updatedAt: switch (json['updated_at']) {
          null => null,
          final Object v => _readDateTime(v, 'EventRankingEntry.updated_at'),
        },
      );

  /// Derecenin ait olduğu katılımcı.
  final String userId;

  /// Süre (saniye), sıra ya da ölçümün değeri.
  final double value;

  /// Sıra; eşit değerler aynı sırayı paylaşır (1, 1, 3).
  ///
  /// Kısıtlar: minimum: 1.
  final int rank;

  final DateTime? updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'value': value,
    'rank': rank,
    if (updatedAt case final value?)
      'updated_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRankingEntry &&
          userId == other.userId &&
          value == other.value &&
          rank == other.rank &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, value, rank, updatedAt]);
}

/// Elle girilen derecenin ölçütü: `duration` süre (saniye), `rank` sıra. Ölçümden hesaplanan derecede yoktur.
enum EventRankingMetric {
  duration('duration'),
  rank('rank'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventRankingMetric(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventRankingMetric.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventRankingMetric fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventRankingValueRequest {
  const EventRankingValueRequest({required this.value});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRankingValueRequest.fromJson(Map<String, Object?> json) =>
      EventRankingValueRequest(
        value: _readDouble(json['value'], 'EventRankingValueRequest.value'),
      );

  /// `duration` ölçütünde saniye (iki basamağa yuvarlanır, en çok 1000000), `rank` ölçütünde 1–10000 arası tam sayı.
  ///
  /// Kısıtlar: maximum: 1000000; exclusiveMinimum: 0.
  final double value;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRankingValueRequest && value == other.value;

  @override
  int get hashCode => Object.hashAll(<Object?>[value]);
}

final class EventReferee {
  const EventReferee({
    required this.id,
    required this.userId,
    this.componentKey,
    this.scopeId,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventReferee.fromJson(Map<String, Object?> json) => EventReferee(
    id: _readString(json['id'], 'EventReferee.id'),
    userId: _readString(json['user_id'], 'EventReferee.user_id'),
    componentKey: switch (json['component_key']) {
      null => null,
      final Object v => _readString(v, 'EventReferee.component_key'),
    },
    scopeId: switch (json['scope_id']) {
      null => null,
      final Object v => _readString(v, 'EventReferee.scope_id'),
    },
    createdAt: _readDateTime(json['created_at'], 'EventReferee.created_at'),
  );

  final String id;

  final String userId;

  /// Yoksa atama etkinliğin bütün bileşenleri içindir.
  final String? componentKey;

  /// Bileşenin bir kapsamı (masa, maç); yoksa bileşenin tamamı.
  final String? scopeId;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    if (componentKey case final value?) 'component_key': value,
    if (scopeId case final value?) 'scope_id': value,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventReferee &&
          id == other.id &&
          userId == other.userId &&
          componentKey == other.componentKey &&
          scopeId == other.scopeId &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, userId, componentKey, scopeId, createdAt]);
}

final class EventRefereeAssignRequest {
  const EventRefereeAssignRequest({
    required this.userId,
    this.componentKey,
    this.scopeId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRefereeAssignRequest.fromJson(
    Map<String, Object?> json,
  ) => EventRefereeAssignRequest(
    userId: _readString(json['user_id'], 'EventRefereeAssignRequest.user_id'),
    componentKey: switch (json['component_key']) {
      null => null,
      final Object v => _readString(
        v,
        'EventRefereeAssignRequest.component_key',
      ),
    },
    scopeId: switch (json['scope_id']) {
      null => null,
      final Object v => _readString(v, 'EventRefereeAssignRequest.scope_id'),
    },
  );

  /// Tayfanın etkin bir üyesi.
  final String userId;

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? componentKey;

  /// `component_key` ile birlikte verilir.
  final String? scopeId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    if (componentKey case final value?) 'component_key': value,
    if (scopeId case final value?) 'scope_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRefereeAssignRequest &&
          userId == other.userId &&
          componentKey == other.componentKey &&
          scopeId == other.scopeId;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, componentKey, scopeId]);
}

final class EventRefereeList {
  const EventRefereeList({required this.referees});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRefereeList.fromJson(Map<String, Object?> json) =>
      EventRefereeList(
        referees: List<EventReferee>.unmodifiable(
          _readList(json['referees'], 'EventRefereeList.referees').map(
            (Object? e0) => EventReferee.fromJson(
              _readObject(e0, 'EventRefereeList.referees'),
            ),
          ),
        ),
      );

  final List<EventReferee> referees;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'referees': <Object?>[for (final e0 in referees) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRefereeList && _deepEquals(referees, other.referees);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(referees)]);
}

/// Bir etkinliğin bir yoklama bileşeni, isteği yapanın gördüğü haliyle (#242).
final class EventRollCall {
  const EventRollCall({
    required this.alarm,
    required this.returnGraceMinutes,
    this.expectedReturnAt,
    this.mine,
    required this.entries,
    required this.callerCanManage,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRollCall.fromJson(Map<String, Object?> json) => EventRollCall(
    alarm: _readBool(json['alarm'], 'EventRollCall.alarm'),
    returnGraceMinutes: _readInt(
      json['return_grace_minutes'],
      'EventRollCall.return_grace_minutes',
    ),
    expectedReturnAt: switch (json['expected_return_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventRollCall.expected_return_at'),
    },
    mine: switch (json['mine']) {
      null => null,
      final Object v => RollCallEntry.fromJson(
        _readObject(v, 'EventRollCall.mine'),
      ),
    },
    entries: List<RollCallEntry>.unmodifiable(
      _readList(json['entries'], 'EventRollCall.entries').map(
        (Object? e0) =>
            RollCallEntry.fromJson(_readObject(e0, 'EventRollCall.entries')),
      ),
    ),
    callerCanManage: _readBool(
      json['caller_can_manage'],
      'EventRollCall.caller_can_manage',
    ),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventRollCall.caller_can_edit',
    ),
  );

  /// Bileşenin `alarm` parametresi; kapalıysa dönmeme alarmı kurulmaz.
  final bool alarm;

  /// Beklenen dönüşten sonraki tolerans (dakika); tanım vermezse 30.
  ///
  /// Kısıtlar: minimum: 0; maximum: 1440.
  final int returnGraceMinutes;

  /// Beklenen dönüş; plan yoksa yoktur (alarm kurulmaz).
  final DateTime? expectedReturnAt;

  /// Kendi kaydınız; çıkmadıysanız yoktur.
  final RollCallEntry? mine;

  /// Herkesin kaydı, önce dışarıdakiler; yalnızca `caller_can_manage` ise dolu, değilse boş.
  ///
  /// Kısıtlar: maxItems: 1000.
  final List<RollCallEntry> entries;

  /// Etkinliğin bileşenlerini yönetirsiniz (organizatör yetkisi, susturulmamış).
  final bool callerCanManage;

  /// Beklenen dönüşü şu an değiştirebilirsiniz (organizatör yetkisi; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'alarm': alarm,
    'return_grace_minutes': returnGraceMinutes,
    if (expectedReturnAt case final value?)
      'expected_return_at': value.toUtc().toIso8601String(),
    if (mine case final value?) 'mine': value.toJson(),
    'entries': <Object?>[for (final e0 in entries) e0.toJson()],
    'caller_can_manage': callerCanManage,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRollCall &&
          alarm == other.alarm &&
          returnGraceMinutes == other.returnGraceMinutes &&
          expectedReturnAt == other.expectedReturnAt &&
          mine == other.mine &&
          _deepEquals(entries, other.entries) &&
          callerCanManage == other.callerCanManage &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    alarm,
    returnGraceMinutes,
    expectedReturnAt,
    mine,
    _deepHash(entries),
    callerCanManage,
    callerCanEdit,
  ]);
}

/// Bir etkinliğin rota bileşeninin güzergâhı (#239).
final class EventRoute {
  const EventRoute({
    required this.points,
    this.updatedAt,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRoute.fromJson(Map<String, Object?> json) => EventRoute(
    points: List<LatLng>.unmodifiable(
      _readList(json['points'], 'EventRoute.points').map(
        (Object? e0) => LatLng.fromJson(_readObject(e0, 'EventRoute.points')),
      ),
    ),
    updatedAt: switch (json['updated_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventRoute.updated_at'),
    },
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventRoute.caller_can_edit',
    ),
  );

  /// Sırayla; rota yoksa boş, varsa 2–500 nokta.
  ///
  /// Kısıtlar: maxItems: 500.
  final List<LatLng> points;

  /// Rotanın son yazıldığı an; rota yoksa yoktur.
  final DateTime? updatedAt;

  /// Rotayı şu an değiştirebilirsiniz (organizatör yetkisi; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'points': <Object?>[for (final e0 in points) e0.toJson()],
    if (updatedAt case final value?)
      'updated_at': value.toUtc().toIso8601String(),
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRoute &&
          _deepEquals(points, other.points) &&
          updatedAt == other.updatedAt &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(points), updatedAt, callerCanEdit]);
}

final class EventRouteRequest {
  const EventRouteRequest({required this.points});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventRouteRequest.fromJson(Map<String, Object?> json) =>
      EventRouteRequest(
        points: List<LatLng>.unmodifiable(
          _readList(json['points'], 'EventRouteRequest.points').map(
            (Object? e0) =>
                LatLng.fromJson(_readObject(e0, 'EventRouteRequest.points')),
          ),
        ),
      );

  /// Boş (rotayı kaldırır) ya da 2–500 nokta.
  ///
  /// Kısıtlar: maxItems: 500.
  final List<LatLng> points;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'points': <Object?>[for (final e0 in points) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRouteRequest && _deepEquals(points, other.points);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(points)]);
}

/// Bir etkinliğin bir program bileşeni, isteği yapanın gördüğü haliyle (#247).
final class EventSchedule {
  const EventSchedule({
    required this.items,
    required this.maxItems,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventSchedule.fromJson(Map<String, Object?> json) => EventSchedule(
    items: List<EventScheduleItem>.unmodifiable(
      _readList(json['items'], 'EventSchedule.items').map(
        (Object? e0) =>
            EventScheduleItem.fromJson(_readObject(e0, 'EventSchedule.items')),
      ),
    ),
    maxItems: _readInt(json['max_items'], 'EventSchedule.max_items'),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventSchedule.caller_can_edit',
    ),
  );

  /// Başlangıç saatine göre; aynı saattekiler eklenme sırasıyla.
  final List<EventScheduleItem> items;

  /// Programın alabileceği madde sayısı (bileşenin `max_items` parametresi; tanım vermezse 100).
  ///
  /// Kısıtlar: minimum: 1; maximum: 100.
  final int maxItems;

  /// Şu an madde ekleyebilir, düzenleyebilir ve çıkarabilirsiniz (organizatör, moderatör, yönetici; susturulmamış; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final e0 in items) e0.toJson()],
    'max_items': maxItems,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventSchedule &&
          _deepEquals(items, other.items) &&
          maxItems == other.maxItems &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(items), maxItems, callerCanEdit]);
}

final class EventScheduleItem {
  const EventScheduleItem({
    required this.id,
    required this.startsAt,
    this.endsAt,
    required this.title,
    this.note,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScheduleItem.fromJson(Map<String, Object?> json) =>
      EventScheduleItem(
        id: _readString(json['id'], 'EventScheduleItem.id'),
        startsAt: _readDateTime(
          json['starts_at'],
          'EventScheduleItem.starts_at',
        ),
        endsAt: switch (json['ends_at']) {
          null => null,
          final Object v => _readDateTime(v, 'EventScheduleItem.ends_at'),
        },
        title: _readString(json['title'], 'EventScheduleItem.title'),
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'EventScheduleItem.note'),
        },
      );

  final String id;

  final DateTime startsAt;

  /// Bitiş saati; yoksa yoktur.
  final DateTime? endsAt;

  /// 1–120 karakter.
  final String title;

  /// En fazla 500 karakter; yoksa yoktur.
  final String? note;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'starts_at': startsAt.toUtc().toIso8601String(),
    if (endsAt case final value?) 'ends_at': value.toUtc().toIso8601String(),
    'title': title,
    if (note case final value?) 'note': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScheduleItem &&
          id == other.id &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          title == other.title &&
          note == other.note;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, startsAt, endsAt, title, note]);
}

final class EventScheduleItemRequest {
  const EventScheduleItemRequest({
    required this.startsAt,
    this.endsAt,
    required this.title,
    this.note,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScheduleItemRequest.fromJson(Map<String, Object?> json) =>
      EventScheduleItemRequest(
        startsAt: _readDateTime(
          json['starts_at'],
          'EventScheduleItemRequest.starts_at',
        ),
        endsAt: switch (json['ends_at']) {
          null => null,
          final Object v => _readDateTime(
            v,
            'EventScheduleItemRequest.ends_at',
          ),
        },
        title: _readString(json['title'], 'EventScheduleItemRequest.title'),
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'EventScheduleItemRequest.note'),
        },
      );

  /// Etkinliğin başlangıcından en çok bir gün önce, bitişinden en çok bir gün sonra.
  final DateTime startsAt;

  /// İsteğe bağlı; başlangıçtan sonra, etkinliğin bitişinden en çok bir gün sonra.
  final DateTime? endsAt;

  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String title;

  /// İsteğe bağlı; boş metin notu kaldırır.
  ///
  /// Kısıtlar: maxLength: 500.
  final String? note;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'starts_at': startsAt.toUtc().toIso8601String(),
    if (endsAt case final value?) 'ends_at': value.toUtc().toIso8601String(),
    'title': title,
    if (note case final value?) 'note': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScheduleItemRequest &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          title == other.title &&
          note == other.note;

  @override
  int get hashCode => Object.hashAll(<Object?>[startsAt, endsAt, title, note]);
}

/// Bir yerin bir eldeki skoru.
final class EventScoreEntry {
  const EventScoreEntry({required this.playerId, this.points, this.outcome});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreEntry.fromJson(Map<String, Object?> json) =>
      EventScoreEntry(
        playerId: _readString(json['player_id'], 'EventScoreEntry.player_id'),
        points: switch (json['points']) {
          null => null,
          final Object v => _readInt(v, 'EventScoreEntry.points'),
        },
        outcome: switch (json['outcome']) {
          null => null,
          final Object v => EventScoreEntryOutcome.fromWire(
            _readString(v, 'EventScoreEntry.outcome'),
          ),
        },
      );

  /// Yer (`EventScorePlayer.id`).
  final String playerId;

  /// Yalnızca `points` modunda.
  final int? points;

  /// Yalnızca `wdl` modunda.
  final EventScoreEntryOutcome? outcome;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'player_id': playerId,
    if (points case final value?) 'points': value,
    if (outcome case final value?) 'outcome': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreEntry &&
          playerId == other.playerId &&
          points == other.points &&
          outcome == other.outcome;

  @override
  int get hashCode => Object.hashAll(<Object?>[playerId, points, outcome]);
}

/// Yalnızca `wdl` modunda.
enum EventScoreEntryOutcome {
  win('win'),
  draw('draw'),
  loss('loss'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreEntryOutcome(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('EventScoreEntryOutcome.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreEntryOutcome fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Masadaki bir yer. Kişi ya da takım; ikisi de yoksa kişi hesabını
/// silmiştir ("Silinmiş kullanıcı") ya da takım kaldırılmıştır.
final class EventScorePlayer {
  const EventScorePlayer({
    required this.id,
    required this.position,
    this.userId,
    this.teamId,
    this.guestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScorePlayer.fromJson(Map<String, Object?> json) =>
      EventScorePlayer(
        id: _readString(json['id'], 'EventScorePlayer.id'),
        position: _readInt(json['position'], 'EventScorePlayer.position'),
        userId: switch (json['user_id']) {
          null => null,
          final Object v => _readString(v, 'EventScorePlayer.user_id'),
        },
        teamId: switch (json['team_id']) {
          null => null,
          final Object v => _readString(v, 'EventScorePlayer.team_id'),
        },
        guestId: switch (json['guest_id']) {
          null => null,
          final Object v => _readString(v, 'EventScorePlayer.guest_id'),
        },
      );

  final String id;

  /// Kısıtlar: minimum: 1; maximum: 50.
  final int position;

  final String? userId;

  /// Takım masasında takım bileşeninin takımı.
  final String? teamId;

  /// Misafir oyuncunun kimliği (`EventGuestPlayer.id`).
  final String? guestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'position': position,
    if (userId case final value?) 'user_id': value,
    if (teamId case final value?) 'team_id': value,
    if (guestId case final value?) 'guest_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScorePlayer &&
          id == other.id &&
          position == other.position &&
          userId == other.userId &&
          teamId == other.teamId &&
          guestId == other.guestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, position, userId, teamId, guestId]);
}

/// Bir yer; `user_id`, `team_id` ve `guest_id`'den tam olarak biri.
/// Misafir yalnızca kişi masasına ve misafir alan (`guests`) bileşene
/// oturur (`guest-players-disabled`); etkinliğin misafiri değilse
/// `guest-player-not-found`.
final class EventScorePlayerInput {
  const EventScorePlayerInput({this.userId, this.teamId, this.guestId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScorePlayerInput.fromJson(Map<String, Object?> json) =>
      EventScorePlayerInput(
        userId: switch (json['user_id']) {
          null => null,
          final Object v => _readString(v, 'EventScorePlayerInput.user_id'),
        },
        teamId: switch (json['team_id']) {
          null => null,
          final Object v => _readString(v, 'EventScorePlayerInput.team_id'),
        },
        guestId: switch (json['guest_id']) {
          null => null,
          final Object v => _readString(v, 'EventScorePlayerInput.guest_id'),
        },
      );

  final String? userId;

  final String? teamId;

  final String? guestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (userId case final value?) 'user_id': value,
    if (teamId case final value?) 'team_id': value,
    if (guestId case final value?) 'guest_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScorePlayerInput &&
          userId == other.userId &&
          teamId == other.teamId &&
          guestId == other.guestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, teamId, guestId]);
}

final class EventScorePlayersRequest {
  const EventScorePlayersRequest({required this.players});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScorePlayersRequest.fromJson(Map<String, Object?> json) =>
      EventScorePlayersRequest(
        players: List<EventScorePlayerInput>.unmodifiable(
          _readList(json['players'], 'EventScorePlayersRequest.players').map(
            (Object? e0) => EventScorePlayerInput.fromJson(
              _readObject(e0, 'EventScorePlayersRequest.players'),
            ),
          ),
        ),
      );

  /// Kısıtlar: maxItems: 50.
  final List<EventScorePlayerInput> players;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'players': <Object?>[for (final e0 in players) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScorePlayersRequest && _deepEquals(players, other.players);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(players)]);
}

/// Katalogdaki bir yazboz ön ayarı (Batak, 101 Okey …;
final class EventScorePreset {
  const EventScorePreset({
    required this.key,
    required this.labels,
    this.playersMin,
    this.playersMax,
    required this.rules,
    required this.retired,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScorePreset.fromJson(Map<String, Object?> json) =>
      EventScorePreset(
        key: _readString(json['key'], 'EventScorePreset.key'),
        labels: Map<String, String>.unmodifiable(
          _readObject(json['labels'], 'EventScorePreset.labels').map(
            (String k0, Object? e0) =>
                MapEntry(k0, _readString(e0, 'EventScorePreset.labels')),
          ),
        ),
        playersMin: switch (json['players_min']) {
          null => null,
          final Object v => _readInt(v, 'EventScorePreset.players_min'),
        },
        playersMax: switch (json['players_max']) {
          null => null,
          final Object v => _readInt(v, 'EventScorePreset.players_max'),
        },
        rules: EventScoreRules.fromJson(
          _readObject(json['rules'], 'EventScorePreset.rules'),
        ),
        retired: _readBool(json['retired'], 'EventScorePreset.retired'),
      );

  /// Değişmez anahtar: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  final Map<String, String> labels;

  /// Masanın en az yer sayısı; yoksa alan yok.
  final int? playersMin;

  /// Masanın en çok yer sayısı; yoksa alan yok.
  final int? playersMax;

  final EventScoreRules rules;

  /// Emekli ön ayar eski masalarda görünür; yeni masa kullanamaz.
  final bool retired;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'labels': <String, Object?>{
      for (final e0 in labels.entries) e0.key: e0.value,
    },
    if (playersMin case final value?) 'players_min': value,
    if (playersMax case final value?) 'players_max': value,
    'rules': rules.toJson(),
    'retired': retired,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScorePreset &&
          key == other.key &&
          _deepEquals(labels, other.labels) &&
          playersMin == other.playersMin &&
          playersMax == other.playersMax &&
          rules == other.rules &&
          retired == other.retired;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    _deepHash(labels),
    playersMin,
    playersMax,
    rules,
    retired,
  ]);
}

final class EventScoreRound {
  const EventScoreRound({required this.number, required this.scores});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreRound.fromJson(Map<String, Object?> json) =>
      EventScoreRound(
        number: _readInt(json['number'], 'EventScoreRound.number'),
        scores: List<EventScoreEntry>.unmodifiable(
          _readList(json['scores'], 'EventScoreRound.scores').map(
            (Object? e0) => EventScoreEntry.fromJson(
              _readObject(e0, 'EventScoreRound.scores'),
            ),
          ),
        ),
      );

  /// Kısıtlar: minimum: 1; maximum: 200.
  final int number;

  final List<EventScoreEntry> scores;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    'scores': <Object?>[for (final e0 in scores) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreRound &&
          number == other.number &&
          _deepEquals(scores, other.scores);

  @override
  int get hashCode => Object.hashAll(<Object?>[number, _deepHash(scores)]);
}

final class EventScoreRoundRequest {
  const EventScoreRoundRequest({required this.scores});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreRoundRequest.fromJson(Map<String, Object?> json) =>
      EventScoreRoundRequest(
        scores: List<EventScoreEntry>.unmodifiable(
          _readList(json['scores'], 'EventScoreRoundRequest.scores').map(
            (Object? e0) => EventScoreEntry.fromJson(
              _readObject(e0, 'EventScoreRoundRequest.scores'),
            ),
          ),
        ),
      );

  /// Kısıtlar: minItems: 1; maxItems: 50.
  final List<EventScoreEntry> scores;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'scores': <Object?>[for (final e0 in scores) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreRoundRequest && _deepEquals(scores, other.scores);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(scores)]);
}

/// Yazboz kuralları (#250). Ön ayarda verilmeyen kural boştur ve
/// bileşenden gelir; masada ve bileşende hepsi doludur.
final class EventScoreRules {
  const EventScoreRules({
    this.side,
    this.rounds,
    this.winner,
    this.result,
    this.target,
    this.bestOf,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreRules.fromJson(Map<String, Object?> json) =>
      EventScoreRules(
        side: switch (json['side']) {
          null => null,
          final Object v => EventScoreRulesSide.fromWire(
            _readString(v, 'EventScoreRules.side'),
          ),
        },
        rounds: switch (json['rounds']) {
          null => null,
          final Object v => EventScoreRulesRounds.fromWire(
            _readString(v, 'EventScoreRules.rounds'),
          ),
        },
        winner: switch (json['winner']) {
          null => null,
          final Object v => EventScoreRulesWinner.fromWire(
            _readString(v, 'EventScoreRules.winner'),
          ),
        },
        result: switch (json['result']) {
          null => null,
          final Object v => EventScoreRulesResult.fromWire(
            _readString(v, 'EventScoreRules.result'),
          ),
        },
        target: switch (json['target']) {
          null => null,
          final Object v => _readInt(v, 'EventScoreRules.target'),
        },
        bestOf: switch (json['best_of']) {
          null => null,
          final Object v => _readInt(v, 'EventScoreRules.best_of'),
        },
      );

  /// Oyuncular kişiler (`player`) ya da takımlar (`team`).
  final EventScoreRulesSide? side;

  /// El el, tek maç ya da hedefe ilk ulaşana kadar.
  final EventScoreRulesRounds? rounds;

  /// Yüksek, düşük toplam ya da hedefe ilk ulaşan kazanır.
  final EventScoreRulesWinner? winner;

  /// Puan ya da galibiyet (1) / beraberlik (½) / mağlubiyet (0).
  final EventScoreRulesResult? result;

  /// Hedef puan; yoksa alan yok.
  ///
  /// Kısıtlar: minimum: 1; maximum: 100000.
  final int? target;

  /// BO maçı; yarıdan fazlasını kazanan kazanır. Yoksa alan yok.
  final int? bestOf;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (side case final value?) 'side': value.wire,
    if (rounds case final value?) 'rounds': value.wire,
    if (winner case final value?) 'winner': value.wire,
    if (result case final value?) 'result': value.wire,
    if (target case final value?) 'target': value,
    if (bestOf case final value?) 'best_of': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreRules &&
          side == other.side &&
          rounds == other.rounds &&
          winner == other.winner &&
          result == other.result &&
          target == other.target &&
          bestOf == other.bestOf;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[side, rounds, winner, result, target, bestOf]);
}

/// Puan ya da galibiyet (1) / beraberlik (½) / mağlubiyet (0).
enum EventScoreRulesResult {
  points('points'),
  wdl('wdl'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreRulesResult(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventScoreRulesResult.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreRulesResult fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// El el, tek maç ya da hedefe ilk ulaşana kadar.
enum EventScoreRulesRounds {
  round('round'),
  single('single'),
  firstTo('first_to'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreRulesRounds(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventScoreRulesRounds.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreRulesRounds fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Oyuncular kişiler (`player`) ya da takımlar (`team`).
enum EventScoreRulesSide {
  player('player'),
  team('team'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreRulesSide(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventScoreRulesSide.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreRulesSide fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Yüksek, düşük toplam ya da hedefe ilk ulaşan kazanır.
enum EventScoreRulesWinner {
  high('high'),
  low('low'),
  first('first'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreRulesWinner(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventScoreRulesWinner.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreRulesWinner fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventScoreStanding {
  const EventScoreStanding({
    required this.playerId,
    required this.total,
    required this.roundsWon,
    required this.rank,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreStanding.fromJson(
    Map<String, Object?> json,
  ) => EventScoreStanding(
    playerId: _readString(json['player_id'], 'EventScoreStanding.player_id'),
    total: _readDouble(json['total'], 'EventScoreStanding.total'),
    roundsWon: _readInt(json['rounds_won'], 'EventScoreStanding.rounds_won'),
    rank: _readInt(json['rank'], 'EventScoreStanding.rank'),
  );

  final String playerId;

  /// Puan toplamı; `wdl` modunda galibiyet 1, beraberlik 0.5.
  final double total;

  /// Tek başına kazanılan el sayısı; BO maçında kazananı belirler.
  final int roundsWon;

  /// 1'den başlar; eşitler aynı sırayı paylaşır.
  final int rank;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'player_id': playerId,
    'total': total,
    'rounds_won': roundsWon,
    'rank': rank,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreStanding &&
          playerId == other.playerId &&
          total == other.total &&
          roundsWon == other.roundsWon &&
          rank == other.rank;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[playerId, total, roundsWon, rank]);
}

/// Yazbozun bir masası (#250).
final class EventScoreTable {
  const EventScoreTable({
    required this.id,
    required this.label,
    this.presetKey,
    required this.rules,
    this.teamsKey,
    required this.status,
    this.finishedAt,
    required this.createdAt,
    required this.players,
    required this.rounds,
    required this.standings,
    required this.winnerIds,
    required this.callerCanScore,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreTable.fromJson(
    Map<String, Object?> json,
  ) => EventScoreTable(
    id: _readString(json['id'], 'EventScoreTable.id'),
    label: _readString(json['label'], 'EventScoreTable.label'),
    presetKey: switch (json['preset_key']) {
      null => null,
      final Object v => _readString(v, 'EventScoreTable.preset_key'),
    },
    rules: EventScoreRules.fromJson(
      _readObject(json['rules'], 'EventScoreTable.rules'),
    ),
    teamsKey: switch (json['teams_key']) {
      null => null,
      final Object v => _readString(v, 'EventScoreTable.teams_key'),
    },
    status: EventScoreTableStatus.fromWire(
      _readString(json['status'], 'EventScoreTable.status'),
    ),
    finishedAt: switch (json['finished_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventScoreTable.finished_at'),
    },
    createdAt: _readDateTime(json['created_at'], 'EventScoreTable.created_at'),
    players: List<EventScorePlayer>.unmodifiable(
      _readList(json['players'], 'EventScoreTable.players').map(
        (Object? e0) => EventScorePlayer.fromJson(
          _readObject(e0, 'EventScoreTable.players'),
        ),
      ),
    ),
    rounds: List<EventScoreRound>.unmodifiable(
      _readList(json['rounds'], 'EventScoreTable.rounds').map(
        (Object? e0) =>
            EventScoreRound.fromJson(_readObject(e0, 'EventScoreTable.rounds')),
      ),
    ),
    standings: List<EventScoreStanding>.unmodifiable(
      _readList(json['standings'], 'EventScoreTable.standings').map(
        (Object? e0) => EventScoreStanding.fromJson(
          _readObject(e0, 'EventScoreTable.standings'),
        ),
      ),
    ),
    winnerIds: List<String>.unmodifiable(
      _readList(
        json['winner_ids'],
        'EventScoreTable.winner_ids',
      ).map((Object? e0) => _readString(e0, 'EventScoreTable.winner_ids')),
    ),
    callerCanScore: _readBool(
      json['caller_can_score'],
      'EventScoreTable.caller_can_score',
    ),
  );

  final String id;

  /// Kısıtlar: minLength: 1; maxLength: 30.
  final String label;

  /// Masanın ön ayarı; yoksa alan yok.
  final String? presetKey;

  final EventScoreRules rules;

  /// Yalnızca takım masasında, takım bileşeninin anahtarı.
  final String? teamsKey;

  final EventScoreTableStatus status;

  /// Yalnızca biten masada.
  final DateTime? finishedAt;

  final DateTime createdAt;

  /// Sıraya göre.
  ///
  /// Kısıtlar: maxItems: 50.
  final List<EventScorePlayer> players;

  /// El numarasına göre.
  ///
  /// Kısıtlar: maxItems: 200.
  final List<EventScoreRound> rounds;

  /// Sıralamaya, sonra yer sırasına göre.
  final List<EventScoreStanding> standings;

  /// Biten masada birinci sıradaki yerler (beraberlikte birden çok); açık masada boş.
  final List<String> winnerIds;

  /// Şu an el girebilir ve masayı bitirebilirsiniz (organizatör, moderatör, yönetici ya da masanın hakemi; susturulmamış; masa açık; etkinlik başlamış, iptal değil, donmamış; tayfa salt okunur değil).
  final bool callerCanScore;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    if (presetKey case final value?) 'preset_key': value,
    'rules': rules.toJson(),
    if (teamsKey case final value?) 'teams_key': value,
    'status': status.wire,
    if (finishedAt case final value?)
      'finished_at': value.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'players': <Object?>[for (final e0 in players) e0.toJson()],
    'rounds': <Object?>[for (final e0 in rounds) e0.toJson()],
    'standings': <Object?>[for (final e0 in standings) e0.toJson()],
    'winner_ids': <Object?>[for (final e0 in winnerIds) e0],
    'caller_can_score': callerCanScore,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreTable &&
          id == other.id &&
          label == other.label &&
          presetKey == other.presetKey &&
          rules == other.rules &&
          teamsKey == other.teamsKey &&
          status == other.status &&
          finishedAt == other.finishedAt &&
          createdAt == other.createdAt &&
          _deepEquals(players, other.players) &&
          _deepEquals(rounds, other.rounds) &&
          _deepEquals(standings, other.standings) &&
          _deepEquals(winnerIds, other.winnerIds) &&
          callerCanScore == other.callerCanScore;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    label,
    presetKey,
    rules,
    teamsKey,
    status,
    finishedAt,
    createdAt,
    _deepHash(players),
    _deepHash(rounds),
    _deepHash(standings),
    _deepHash(winnerIds),
    callerCanScore,
  ]);
}

final class EventScoreTableRequest {
  const EventScoreTableRequest({
    required this.label,
    this.presetKey,
    this.target,
    this.teamsKey,
    this.players,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreTableRequest.fromJson(Map<String, Object?> json) =>
      EventScoreTableRequest(
        label: _readString(json['label'], 'EventScoreTableRequest.label'),
        presetKey: switch (json['preset_key']) {
          null => null,
          final Object v => _readString(v, 'EventScoreTableRequest.preset_key'),
        },
        target: switch (json['target']) {
          null => null,
          final Object v => _readInt(v, 'EventScoreTableRequest.target'),
        },
        teamsKey: switch (json['teams_key']) {
          null => null,
          final Object v => _readString(v, 'EventScoreTableRequest.teams_key'),
        },
        players: switch (json['players']) {
          null => null,
          final Object v => List<EventScorePlayerInput>.unmodifiable(
            _readList(v, 'EventScoreTableRequest.players').map(
              (Object? e0) => EventScorePlayerInput.fromJson(
                _readObject(e0, 'EventScoreTableRequest.players'),
              ),
            ),
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 30.
  final String label;

  /// Bileşen ön ayar sunuyorsa zorunlu; sunmuyorsa verilmez.
  final String? presetKey;

  /// Hedef puanı değiştirir; 0 ya da yok kuraldakini korur.
  ///
  /// Kısıtlar: minimum: 0; maximum: 100000.
  final int? target;

  /// Takım masasında zorunlu: etkinliğin türündeki `teams` bileşeninin anahtarı.
  final String? teamsKey;

  /// Sırasıyla; boş ya da yoksa yerler sonra verilir.
  ///
  /// Kısıtlar: maxItems: 50.
  final List<EventScorePlayerInput>? players;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    if (presetKey case final value?) 'preset_key': value,
    if (target case final value?) 'target': value,
    if (teamsKey case final value?) 'teams_key': value,
    if (players case final value?)
      'players': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreTableRequest &&
          label == other.label &&
          presetKey == other.presetKey &&
          target == other.target &&
          teamsKey == other.teamsKey &&
          _deepEquals(players, other.players);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    label,
    presetKey,
    target,
    teamsKey,
    _deepHash(players),
  ]);
}

enum EventScoreTableStatus {
  open('open'),
  finished('finished'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreTableStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventScoreTableStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreTableStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// En az bir alan.
final class EventScoreTableUpdate {
  const EventScoreTableUpdate({this.label, this.status});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreTableUpdate.fromJson(Map<String, Object?> json) =>
      EventScoreTableUpdate(
        label: switch (json['label']) {
          null => null,
          final Object v => _readString(v, 'EventScoreTableUpdate.label'),
        },
        status: switch (json['status']) {
          null => null,
          final Object v => EventScoreTableUpdateStatus.fromWire(
            _readString(v, 'EventScoreTableUpdate.status'),
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 30.
  final String? label;

  final EventScoreTableUpdateStatus? status;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (label case final value?) 'label': value,
    if (status case final value?) 'status': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreTableUpdate &&
          label == other.label &&
          status == other.status;

  @override
  int get hashCode => Object.hashAll(<Object?>[label, status]);
}

enum EventScoreTableUpdateStatus {
  open('open'),
  finished('finished'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventScoreTableUpdateStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('EventScoreTableUpdateStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventScoreTableUpdateStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Bir etkinliğin bir yazboz bileşeni, isteği yapanın gördüğü haliyle (#250).
final class EventScoreboard {
  const EventScoreboard({
    required this.tables,
    required this.presets,
    required this.rules,
    required this.maxTables,
    required this.callerCanManage,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventScoreboard.fromJson(Map<String, Object?> json) =>
      EventScoreboard(
        tables: List<EventScoreTable>.unmodifiable(
          _readList(json['tables'], 'EventScoreboard.tables').map(
            (Object? e0) => EventScoreTable.fromJson(
              _readObject(e0, 'EventScoreboard.tables'),
            ),
          ),
        ),
        presets: List<EventScorePreset>.unmodifiable(
          _readList(json['presets'], 'EventScoreboard.presets').map(
            (Object? e0) => EventScorePreset.fromJson(
              _readObject(e0, 'EventScoreboard.presets'),
            ),
          ),
        ),
        rules: EventScoreRules.fromJson(
          _readObject(json['rules'], 'EventScoreboard.rules'),
        ),
        maxTables: _readInt(json['max_tables'], 'EventScoreboard.max_tables'),
        callerCanManage: _readBool(
          json['caller_can_manage'],
          'EventScoreboard.caller_can_manage',
        ),
      );

  /// Kuruluş sırasıyla.
  ///
  /// Kısıtlar: maxItems: 20.
  final List<EventScoreTable> tables;

  /// Bileşenin sunduğu ve masaların kullandığı ön ayarlar, katalog sırasıyla.
  final List<EventScorePreset> presets;

  final EventScoreRules rules;

  /// 20; bileşenin `tables` parametresi kapalıysa 1.
  final int maxTables;

  /// Şu an masaları yönetebilir ve skor düzeltebilirsiniz (organizatör, moderatör, yönetici; susturulmamış; etkinlik iptal değil, donmamış; tayfa salt okunur değil).
  final bool callerCanManage;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tables': <Object?>[for (final e0 in tables) e0.toJson()],
    'presets': <Object?>[for (final e0 in presets) e0.toJson()],
    'rules': rules.toJson(),
    'max_tables': maxTables,
    'caller_can_manage': callerCanManage,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventScoreboard &&
          _deepEquals(tables, other.tables) &&
          _deepEquals(presets, other.presets) &&
          rules == other.rules &&
          maxTables == other.maxTables &&
          callerCanManage == other.callerCanManage;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(tables),
    _deepHash(presets),
    rules,
    maxTables,
    callerCanManage,
  ]);
}

final class EventSeries {
  const EventSeries({
    required this.id,
    required this.tayfaId,
    this.templateEventId,
    required this.rrule,
    required this.timeZone,
    required this.startsAt,
    this.endedAt,
    this.createdByUserId,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventSeries.fromJson(Map<String, Object?> json) => EventSeries(
    id: _readString(json['id'], 'EventSeries.id'),
    tayfaId: _readString(json['tayfa_id'], 'EventSeries.tayfa_id'),
    templateEventId: switch (json['template_event_id']) {
      null => null,
      final Object v => _readString(v, 'EventSeries.template_event_id'),
    },
    rrule: _readString(json['rrule'], 'EventSeries.rrule'),
    timeZone: _readString(json['time_zone'], 'EventSeries.time_zone'),
    startsAt: _readDateTime(json['starts_at'], 'EventSeries.starts_at'),
    endedAt: switch (json['ended_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventSeries.ended_at'),
    },
    createdByUserId: switch (json['created_by_user_id']) {
      null => null,
      final Object v => _readString(v, 'EventSeries.created_by_user_id'),
    },
    createdAt: _readDateTime(json['created_at'], 'EventSeries.created_at'),
  );

  final String id;

  final String tayfaId;

  /// Yeni tekrarların kopyalandığı etkinlik.
  final String? templateEventId;

  /// Kanonik biçim.
  final String rrule;

  final String timeZone;

  /// İlk tekrar.
  final DateTime startsAt;

  /// Seri bitirildiyse.
  final DateTime? endedAt;

  /// Hesabı silindiyse yoktur.
  final String? createdByUserId;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    if (templateEventId case final value?) 'template_event_id': value,
    'rrule': rrule,
    'time_zone': timeZone,
    'starts_at': startsAt.toUtc().toIso8601String(),
    if (endedAt case final value?) 'ended_at': value.toUtc().toIso8601String(),
    if (createdByUserId case final value?) 'created_by_user_id': value,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventSeries &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          templateEventId == other.templateEventId &&
          rrule == other.rrule &&
          timeZone == other.timeZone &&
          startsAt == other.startsAt &&
          endedAt == other.endedAt &&
          createdByUserId == other.createdByUserId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    templateEventId,
    rrule,
    timeZone,
    startsAt,
    endedAt,
    createdByUserId,
    createdAt,
  ]);
}

final class EventSeriesEnding {
  const EventSeriesEnding({required this.series, required this.cancelledCount});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventSeriesEnding.fromJson(Map<String, Object?> json) =>
      EventSeriesEnding(
        series: EventSeries.fromJson(
          _readObject(json['series'], 'EventSeriesEnding.series'),
        ),
        cancelledCount: _readInt(
          json['cancelled_count'],
          'EventSeriesEnding.cancelled_count',
        ),
      );

  final EventSeries series;

  /// İptal edilen yaklaşan etkinlik sayısı.
  final int cancelledCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'series': series.toJson(),
    'cancelled_count': cancelledCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventSeriesEnding &&
          series == other.series &&
          cancelledCount == other.cancelledCount;

  @override
  int get hashCode => Object.hashAll(<Object?>[series, cancelledCount]);
}

enum EventStatus {
  scheduled('scheduled'),
  cancelled('cancelled'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventTeam {
  const EventTeam({
    required this.id,
    required this.position,
    this.name,
    required this.memberIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventTeam.fromJson(Map<String, Object?> json) => EventTeam(
    id: _readString(json['id'], 'EventTeam.id'),
    position: _readInt(json['position'], 'EventTeam.position'),
    name: switch (json['name']) {
      null => null,
      final Object v => _readString(v, 'EventTeam.name'),
    },
    memberIds: List<String>.unmodifiable(
      _readList(
        json['member_ids'],
        'EventTeam.member_ids',
      ).map((Object? e0) => _readString(e0, 'EventTeam.member_ids')),
    ),
  );

  final String id;

  /// Takımın sırası; adsız takımı istemci sırasıyla adlandırır.
  ///
  /// Kısıtlar: minimum: 1; maximum: 50.
  final int position;

  /// 1–40 karakter; adsız takımda yoktur.
  final String? name;

  /// Takımdaki ve hâlâ katılımcı olan kişilerin kullanıcı kimlikleri.
  final List<String> memberIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'position': position,
    if (name case final value?) 'name': value,
    'member_ids': <Object?>[for (final e0 in memberIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTeam &&
          id == other.id &&
          position == other.position &&
          name == other.name &&
          _deepEquals(memberIds, other.memberIds);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, position, name, _deepHash(memberIds)]);
}

/// Bir etkinliğin bir takım bileşeni, isteği yapanın gördüğü haliyle (#248).
final class EventTeams {
  const EventTeams({
    required this.teams,
    required this.mode,
    this.teamCount,
    this.teamSize,
    required this.callerCanEdit,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventTeams.fromJson(Map<String, Object?> json) => EventTeams(
    teams: List<EventTeam>.unmodifiable(
      _readList(json['teams'], 'EventTeams.teams').map(
        (Object? e0) => EventTeam.fromJson(_readObject(e0, 'EventTeams.teams')),
      ),
    ),
    mode: EventTeamsMode.fromWire(_readString(json['mode'], 'EventTeams.mode')),
    teamCount: switch (json['team_count']) {
      null => null,
      final Object v => _readInt(v, 'EventTeams.team_count'),
    },
    teamSize: switch (json['team_size']) {
      null => null,
      final Object v => _readInt(v, 'EventTeams.team_size'),
    },
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'EventTeams.caller_can_edit',
    ),
  );

  /// Sıraya göre; takım kurulmamışsa boş.
  final List<EventTeam> teams;

  /// Bu etkinlikte geçerli mod (organizatörün seçimi ya da tanımdaki değer; tanım vermezse random).
  final EventTeamsMode mode;

  /// Bileşenin `team_count` parametresi; tanım vermezse yoktur.
  ///
  /// Kısıtlar: minimum: 1; maximum: 50.
  final int? teamCount;

  /// Bileşenin `team_size` parametresi; tanım vermezse yoktur.
  ///
  /// Kısıtlar: minimum: 1; maximum: 50.
  final int? teamSize;

  /// Şu an takımları kurabilirsiniz (organizatör, moderatör, yönetici; susturulmamış; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanEdit;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'teams': <Object?>[for (final e0 in teams) e0.toJson()],
    'mode': mode.wire,
    if (teamCount case final value?) 'team_count': value,
    if (teamSize case final value?) 'team_size': value,
    'caller_can_edit': callerCanEdit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTeams &&
          _deepEquals(teams, other.teams) &&
          mode == other.mode &&
          teamCount == other.teamCount &&
          teamSize == other.teamSize &&
          callerCanEdit == other.callerCanEdit;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(teams),
    mode,
    teamCount,
    teamSize,
    callerCanEdit,
  ]);
}

final class EventTeamsGenerateRequest {
  const EventTeamsGenerateRequest({this.levels});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventTeamsGenerateRequest.fromJson(Map<String, Object?> json) =>
      EventTeamsGenerateRequest(
        levels: switch (json['levels']) {
          null => null,
          final Object v =>
            List<EventTeamsGenerateRequestLevelsItem>.unmodifiable(
              _readList(v, 'EventTeamsGenerateRequest.levels').map(
                (Object? e0) => EventTeamsGenerateRequestLevelsItem.fromJson(
                  _readObject(e0, 'EventTeamsGenerateRequest.levels'),
                ),
              ),
            ),
        },
      );

  /// Yalnızca `balanced` modda kullanılır; kişi başına en fazla bir. Saklanmaz.
  ///
  /// Kısıtlar: maxItems: 500.
  final List<EventTeamsGenerateRequestLevelsItem>? levels;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (levels case final value?)
      'levels': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTeamsGenerateRequest && _deepEquals(levels, other.levels);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(levels)]);
}

final class EventTeamsGenerateRequestLevelsItem {
  const EventTeamsGenerateRequestLevelsItem({
    required this.userId,
    required this.level,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventTeamsGenerateRequestLevelsItem.fromJson(
    Map<String, Object?> json,
  ) => EventTeamsGenerateRequestLevelsItem(
    userId: _readString(
      json['user_id'],
      'EventTeamsGenerateRequestLevelsItem.user_id',
    ),
    level: _readInt(json['level'], 'EventTeamsGenerateRequestLevelsItem.level'),
  );

  final String userId;

  /// 1 (başlangıç) – 5 (en güçlü).
  ///
  /// Kısıtlar: minimum: 1; maximum: 5.
  final int level;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'level': level,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTeamsGenerateRequestLevelsItem &&
          userId == other.userId &&
          level == other.level;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, level]);
}

/// Bu etkinlikte geçerli mod (organizatörün seçimi ya da tanımdaki değer; tanım vermezse random).
enum EventTeamsMode {
  random('random'),
  balanced('balanced'),
  manual('manual'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventTeamsMode(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventTeamsMode.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventTeamsMode fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class EventTeamsRequest {
  const EventTeamsRequest({required this.teams});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventTeamsRequest.fromJson(Map<String, Object?> json) =>
      EventTeamsRequest(
        teams: List<EventTeamsRequestTeamsItem>.unmodifiable(
          _readList(json['teams'], 'EventTeamsRequest.teams').map(
            (Object? e0) => EventTeamsRequestTeamsItem.fromJson(
              _readObject(e0, 'EventTeamsRequest.teams'),
            ),
          ),
        ),
      );

  /// Sırasıyla; boş liste takımları kaldırır.
  ///
  /// Kısıtlar: maxItems: 50.
  final List<EventTeamsRequestTeamsItem> teams;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'teams': <Object?>[for (final e0 in teams) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTeamsRequest && _deepEquals(teams, other.teams);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(teams)]);
}

final class EventTeamsRequestTeamsItem {
  const EventTeamsRequestTeamsItem({this.name, this.memberIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventTeamsRequestTeamsItem.fromJson(Map<String, Object?> json) =>
      EventTeamsRequestTeamsItem(
        name: switch (json['name']) {
          null => null,
          final Object v => _readString(v, 'EventTeamsRequestTeamsItem.name'),
        },
        memberIds: switch (json['member_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'EventTeamsRequestTeamsItem.member_ids').map(
              (Object? e0) =>
                  _readString(e0, 'EventTeamsRequestTeamsItem.member_ids'),
            ),
          ),
        },
      );

  /// İsteğe bağlı; boş metin adsız takım.
  ///
  /// Kısıtlar: maxLength: 40.
  final String? name;

  /// Katılımcıların kullanıcı kimlikleri; bir kişi en fazla bir takımda.
  final List<String>? memberIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (name case final value?) 'name': value,
    if (memberIds case final value?)
      'member_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTeamsRequestTeamsItem &&
          name == other.name &&
          _deepEquals(memberIds, other.memberIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[name, _deepHash(memberIds)]);
}

/// Kurallar açmadakiyle aynıdır; tür ve tür sürümü değişmez. `fields`
/// verilirse alan değerlerinin TAMAMI yerine geçer (etkinliğin kendi tür
/// sürümüne göre doğrulanır); `{}` bütün değerleri kaldırır.
///
/// Kısıtlar: minProperties: 1.
final class EventUpdateRequest {
  const EventUpdateRequest({
    this.fields,
    this.coverUploadId,
    this.title,
    this.description,
    this.startsAt,
    this.endsAt,
    this.mode,
    this.meetingPointName,
    this.meetingPoint,
    this.city,
    this.district,
    this.onlineUrl,
    this.capacity,
    this.discoverable,
    this.applyToSeries,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventUpdateRequest.fromJson(
    Map<String, Object?> json,
  ) => EventUpdateRequest(
    fields: switch (json['fields']) {
      null => null,
      final Object v => _readJsonObject(v, 'EventUpdateRequest.fields'),
    },
    coverUploadId: switch (json['cover_upload_id']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.cover_upload_id'),
    },
    title: switch (json['title']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.title'),
    },
    description: switch (json['description']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.description'),
    },
    startsAt: switch (json['starts_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventUpdateRequest.starts_at'),
    },
    endsAt: switch (json['ends_at']) {
      null => null,
      final Object v => _readDateTime(v, 'EventUpdateRequest.ends_at'),
    },
    mode: switch (json['mode']) {
      null => null,
      final Object v => EventMode.fromWire(
        _readString(v, 'EventUpdateRequest.mode'),
      ),
    },
    meetingPointName: switch (json['meeting_point_name']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.meeting_point_name'),
    },
    meetingPoint: switch (json['meeting_point']) {
      null => null,
      final Object v => LatLng.fromJson(
        _readObject(v, 'EventUpdateRequest.meeting_point'),
      ),
    },
    city: switch (json['city']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.city'),
    },
    district: switch (json['district']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.district'),
    },
    onlineUrl: switch (json['online_url']) {
      null => null,
      final Object v => _readString(v, 'EventUpdateRequest.online_url'),
    },
    capacity: switch (json['capacity']) {
      null => null,
      final Object v => _readInt(v, 'EventUpdateRequest.capacity'),
    },
    discoverable: switch (json['discoverable']) {
      null => null,
      final Object v => _readBool(v, 'EventUpdateRequest.discoverable'),
    },
    applyToSeries: switch (json['apply_to_series']) {
      null => null,
      final Object v => _readBool(v, 'EventUpdateRequest.apply_to_series'),
    },
  );

  final Map<String, Object?>? fields;

  /// Kendi hazır `cover` yüklemeniz; `""` kapağı kaldırır, eski kapak
  /// silinir. `apply_to_series: true` ile verilemez.
  final String? coverUploadId;

  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String? title;

  /// Kısıtlar: maxLength: 5000.
  final String? description;

  final DateTime? startsAt;

  final DateTime? endsAt;

  final EventMode? mode;

  /// Kısıtlar: maxLength: 120.
  final String? meetingPointName;

  final LatLng? meetingPoint;

  /// Kısıtlar: maxLength: 50.
  final String? city;

  /// Kısıtlar: maxLength: 50.
  final String? district;

  /// Kısıtlar: maxLength: 2048.
  final String? onlineUrl;

  /// Kısıtlar: minimum: 0; maximum: 10000.
  final int? capacity;

  /// Organizatörün işareti: etkinlik halka açık bir yerde buluşur ve
  /// Keşfet'te görünebilir (ADR-0033). Yalnızca yüz yüze etkinlikte
  /// etkilidir; özel adreste buluşan etkinlik işaretlenmez.
  final bool? discoverable;

  /// `true` yalnızca seriye ait etkinlikte geçerlidir; yoksa `false`.
  final bool? applyToSeries;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (fields case final value?) 'fields': value,
    if (coverUploadId case final value?) 'cover_upload_id': value,
    if (title case final value?) 'title': value,
    if (description case final value?) 'description': value,
    if (startsAt case final value?)
      'starts_at': value.toUtc().toIso8601String(),
    if (endsAt case final value?) 'ends_at': value.toUtc().toIso8601String(),
    if (mode case final value?) 'mode': value.wire,
    if (meetingPointName case final value?) 'meeting_point_name': value,
    if (meetingPoint case final value?) 'meeting_point': value.toJson(),
    if (city case final value?) 'city': value,
    if (district case final value?) 'district': value,
    if (onlineUrl case final value?) 'online_url': value,
    if (capacity case final value?) 'capacity': value,
    if (discoverable case final value?) 'discoverable': value,
    if (applyToSeries case final value?) 'apply_to_series': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventUpdateRequest &&
          _deepEquals(fields, other.fields) &&
          coverUploadId == other.coverUploadId &&
          title == other.title &&
          description == other.description &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          mode == other.mode &&
          meetingPointName == other.meetingPointName &&
          meetingPoint == other.meetingPoint &&
          city == other.city &&
          district == other.district &&
          onlineUrl == other.onlineUrl &&
          capacity == other.capacity &&
          discoverable == other.discoverable &&
          applyToSeries == other.applyToSeries;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(fields),
    coverUploadId,
    title,
    description,
    startsAt,
    endsAt,
    mode,
    meetingPointName,
    meetingPoint,
    city,
    district,
    onlineUrl,
    capacity,
    discoverable,
    applyToSeries,
  ]);
}

/// Bir katılımcının etkinliğe yazdığı araç (#240).
final class EventVehicle {
  const EventVehicle({
    required this.id,
    required this.userId,
    required this.make,
    this.model,
    this.modelYear,
    this.color,
    this.plate,
    required this.seats,
    required this.riderUserIds,
    required this.pendingUserIds,
    this.garageVehicleId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventVehicle.fromJson(Map<String, Object?> json) => EventVehicle(
    id: _readString(json['id'], 'EventVehicle.id'),
    userId: _readString(json['user_id'], 'EventVehicle.user_id'),
    make: _readString(json['make'], 'EventVehicle.make'),
    model: switch (json['model']) {
      null => null,
      final Object v => _readString(v, 'EventVehicle.model'),
    },
    modelYear: switch (json['model_year']) {
      null => null,
      final Object v => _readInt(v, 'EventVehicle.model_year'),
    },
    color: switch (json['color']) {
      null => null,
      final Object v => _readString(v, 'EventVehicle.color'),
    },
    plate: switch (json['plate']) {
      null => null,
      final Object v => _readString(v, 'EventVehicle.plate'),
    },
    seats: _readInt(json['seats'], 'EventVehicle.seats'),
    riderUserIds: List<String>.unmodifiable(
      _readList(
        json['rider_user_ids'],
        'EventVehicle.rider_user_ids',
      ).map((Object? e0) => _readString(e0, 'EventVehicle.rider_user_ids')),
    ),
    pendingUserIds: List<String>.unmodifiable(
      _readList(
        json['pending_user_ids'],
        'EventVehicle.pending_user_ids',
      ).map((Object? e0) => _readString(e0, 'EventVehicle.pending_user_ids')),
    ),
    garageVehicleId: switch (json['garage_vehicle_id']) {
      null => null,
      final Object v => _readString(v, 'EventVehicle.garage_vehicle_id'),
    },
  );

  final String id;

  /// Aracın sahibi.
  final String userId;

  final String make;

  final String? model;

  /// Verilmemişse yoktur.
  final int? modelYear;

  final String? color;

  /// Kişisel veri. Yalnızca katılımcılara (`going`), organizatöre ve aracın sahibine döner.
  final String? plate;

  /// Araç sahibinin yazdığı boş koltuk sayısı; bileşenin `seats` parametresi kapalıysa hep 0.
  ///
  /// Kısıtlar: minimum: 0; maximum: 8.
  final int seats;

  /// Koltuk isteği onaylanan kişiler, istek sırasıyla.
  final List<String> riderUserIds;

  /// Onay bekleyen kişiler. Aracın sahibi hepsini, başkası yalnızca kendisini görür.
  final List<String> pendingUserIds;

  /// Aracın kopyalandığı üye garajı aracı (#272); elle yazıldıysa ya da garajdaki araç kalıcı silindiyse yoktur.
  final String? garageVehicleId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'make': make,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (plate case final value?) 'plate': value,
    'seats': seats,
    'rider_user_ids': <Object?>[for (final e0 in riderUserIds) e0],
    'pending_user_ids': <Object?>[for (final e0 in pendingUserIds) e0],
    if (garageVehicleId case final value?) 'garage_vehicle_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventVehicle &&
          id == other.id &&
          userId == other.userId &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          plate == other.plate &&
          seats == other.seats &&
          _deepEquals(riderUserIds, other.riderUserIds) &&
          _deepEquals(pendingUserIds, other.pendingUserIds) &&
          garageVehicleId == other.garageVehicleId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    userId,
    make,
    model,
    modelYear,
    color,
    plate,
    seats,
    _deepHash(riderUserIds),
    _deepHash(pendingUserIds),
    garageVehicleId,
  ]);
}

/// Araç ya elle yazılır (`make` zorunlu) ya da çağıranın garajından
/// seçilir (`garage_vehicle_id`; #272): o zaman `make`, `model`,
/// `model_year` ve `color` verilmez, garajdaki araçtan kopyalanır.
/// Plaka garajda yoktur; yalnızca bu etkinlik kaydına yazılır.
final class EventVehicleRequest {
  const EventVehicleRequest({
    this.garageVehicleId,
    this.make,
    this.model,
    this.modelYear,
    this.color,
    this.plate,
    this.seats,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventVehicleRequest.fromJson(Map<String, Object?> json) =>
      EventVehicleRequest(
        garageVehicleId: switch (json['garage_vehicle_id']) {
          null => null,
          final Object v => _readString(
            v,
            'EventVehicleRequest.garage_vehicle_id',
          ),
        },
        make: switch (json['make']) {
          null => null,
          final Object v => _readString(v, 'EventVehicleRequest.make'),
        },
        model: switch (json['model']) {
          null => null,
          final Object v => _readString(v, 'EventVehicleRequest.model'),
        },
        modelYear: switch (json['model_year']) {
          null => null,
          final Object v => _readInt(v, 'EventVehicleRequest.model_year'),
        },
        color: switch (json['color']) {
          null => null,
          final Object v => _readString(v, 'EventVehicleRequest.color'),
        },
        plate: switch (json['plate']) {
          null => null,
          final Object v => _readString(v, 'EventVehicleRequest.plate'),
        },
        seats: switch (json['seats']) {
          null => null,
          final Object v => _readInt(v, 'EventVehicleRequest.seats'),
        },
      );

  /// Çağıranın garajındaki bir araç (`GarageVehicle.id`). Başkasının ya da silinmiş araç `garage-vehicle-not-found`.
  final String? garageVehicleId;

  /// `garage_vehicle_id` yoksa zorunlu (1–40 karakter).
  ///
  /// Kısıtlar: maxLength: 40.
  final String? make;

  /// Kısıtlar: maxLength: 40.
  final String? model;

  /// 0 ya da 1900 – gelecek yıl.
  ///
  /// Kısıtlar: minimum: 0.
  final int? modelYear;

  /// Kısıtlar: maxLength: 30.
  final String? color;

  /// İsteğe bağlı, kişisel veri; yalnızca `plate_enabled` ise. Harf, rakam ve tek boşluk; 2–16 karakter.
  ///
  /// Kısıtlar: maxLength: 16.
  final String? plate;

  /// Boş koltuk sayısı; verilmezse 0. Sıfırdan büyük değer yalnızca `seats_enabled` ise.
  ///
  /// Kısıtlar: minimum: 0; maximum: 8.
  final int? seats;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (garageVehicleId case final value?) 'garage_vehicle_id': value,
    if (make case final value?) 'make': value,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (plate case final value?) 'plate': value,
    if (seats case final value?) 'seats': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventVehicleRequest &&
          garageVehicleId == other.garageVehicleId &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          plate == other.plate &&
          seats == other.seats;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    garageVehicleId,
    make,
    model,
    modelYear,
    color,
    plate,
    seats,
  ]);
}

/// Bir etkinliğin araçlar bileşeninin araçları, isteği yapanın gördüğü haliyle (#240).
final class EventVehicles {
  const EventVehicles({
    required this.vehicles,
    required this.plateEnabled,
    required this.seatsEnabled,
    required this.callerCanParticipate,
    required this.callerCanManage,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventVehicles.fromJson(Map<String, Object?> json) => EventVehicles(
    vehicles: List<EventVehicle>.unmodifiable(
      _readList(json['vehicles'], 'EventVehicles.vehicles').map(
        (Object? e0) =>
            EventVehicle.fromJson(_readObject(e0, 'EventVehicles.vehicles')),
      ),
    ),
    plateEnabled: _readBool(
      json['plate_enabled'],
      'EventVehicles.plate_enabled',
    ),
    seatsEnabled: _readBool(
      json['seats_enabled'],
      'EventVehicles.seats_enabled',
    ),
    callerCanParticipate: _readBool(
      json['caller_can_participate'],
      'EventVehicles.caller_can_participate',
    ),
    callerCanManage: _readBool(
      json['caller_can_manage'],
      'EventVehicles.caller_can_manage',
    ),
  );

  /// Eklenme sırasıyla.
  final List<EventVehicle> vehicles;

  /// Bileşenin `plate` parametresi; kapalıysa plaka yazılamaz.
  final bool plateEnabled;

  /// Bileşenin `seats` parametresi; kapalıysa koltuk paylaşımı yoktur.
  final bool seatsEnabled;

  /// Şu an araç yazabilir ve koltuk isteyebilirsiniz (`going`, susturulmamış; etkinlik bitmemiş, iptal değil, tayfa salt okunur değil).
  final bool callerCanParticipate;

  /// Şu an başkasının aracını ve koltuk isteğini kaldırabilirsiniz (organizatör yetkisi; etkinlik iptal değil, donmamış, tayfa salt okunur değil).
  final bool callerCanManage;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'vehicles': <Object?>[for (final e0 in vehicles) e0.toJson()],
    'plate_enabled': plateEnabled,
    'seats_enabled': seatsEnabled,
    'caller_can_participate': callerCanParticipate,
    'caller_can_manage': callerCanManage,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventVehicles &&
          _deepEquals(vehicles, other.vehicles) &&
          plateEnabled == other.plateEnabled &&
          seatsEnabled == other.seatsEnabled &&
          callerCanParticipate == other.callerCanParticipate &&
          callerCanManage == other.callerCanManage;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(vehicles),
    plateEnabled,
    seatsEnabled,
    callerCanParticipate,
    callerCanManage,
  ]);
}

final class Friend {
  const Friend({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
    required this.state,
    required this.requestedAt,
    this.acceptedAt,
    this.nextAvailable,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Friend.fromJson(Map<String, Object?> json) => Friend(
    userId: _readString(json['user_id'], 'Friend.user_id'),
    displayName: _readString(json['display_name'], 'Friend.display_name'),
    avatarUploadId: switch (json['avatar_upload_id']) {
      null => null,
      final Object v => _readString(v, 'Friend.avatar_upload_id'),
    },
    state: FriendState.fromWire(_readString(json['state'], 'Friend.state')),
    requestedAt: _readDateTime(json['requested_at'], 'Friend.requested_at'),
    acceptedAt: switch (json['accepted_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Friend.accepted_at'),
    },
    nextAvailable: switch (json['next_available']) {
      null => null,
      final Object v => AvailabilitySummary.fromJson(
        _readObject(v, 'Friend.next_available'),
      ),
    },
  );

  final String userId;

  final String displayName;

  final String? avatarUploadId;

  /// `incoming`: size gelen istek; `outgoing`: sizin isteğiniz.
  final FriendState state;

  final DateTime requestedAt;

  final DateTime? acceptedAt;

  /// "Boşum" rozeti (#207): arkadaşın önümüzdeki 7 takvim günündeki
  /// (bugün dahil, bugün … bugün+6, Europe/Istanbul) en yakın boş
  /// günü, not olmadan. Yalnızca `GET /v1/me/friends`'te ve bu
  /// pencerede boş günü varsa döner; 30 günün tamamı
  /// `GET /v1/users/{user_id}/availability` ile görülür.
  final AvailabilitySummary? nextAvailable;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
    'state': state.wire,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    if (acceptedAt case final value?)
      'accepted_at': value.toUtc().toIso8601String(),
    if (nextAvailable case final value?) 'next_available': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId &&
          state == other.state &&
          requestedAt == other.requestedAt &&
          acceptedAt == other.acceptedAt &&
          nextAvailable == other.nextAvailable;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    displayName,
    avatarUploadId,
    state,
    requestedAt,
    acceptedAt,
    nextAvailable,
  ]);
}

final class FriendList {
  const FriendList({required this.friends, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FriendList.fromJson(Map<String, Object?> json) => FriendList(
    friends: List<Friend>.unmodifiable(
      _readList(json['friends'], 'FriendList.friends').map(
        (Object? e0) => Friend.fromJson(_readObject(e0, 'FriendList.friends')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'FriendList.next_page_token'),
    },
  );

  final List<Friend> friends;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'friends': <Object?>[for (final e0 in friends) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendList &&
          _deepEquals(friends, other.friends) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(friends), nextPageToken]);
}

/// `incoming`: size gelen istek; `outgoing`: sizin isteğiniz.
enum FriendState {
  friends('friends'),
  incoming('incoming'),
  outgoing('outgoing'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const FriendState(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('FriendState.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static FriendState fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Arkadaşlık puanı, ortak etkinlik sayısı ve gerekçe bilinçli olarak yoktur (ADR-0030).
final class FriendSuggestion {
  const FriendSuggestion({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
    required this.suggestedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FriendSuggestion.fromJson(Map<String, Object?> json) =>
      FriendSuggestion(
        userId: _readString(json['user_id'], 'FriendSuggestion.user_id'),
        displayName: _readString(
          json['display_name'],
          'FriendSuggestion.display_name',
        ),
        avatarUploadId: switch (json['avatar_upload_id']) {
          null => null,
          final Object v => _readString(v, 'FriendSuggestion.avatar_upload_id'),
        },
        suggestedAt: _readDateTime(
          json['suggested_at'],
          'FriendSuggestion.suggested_at',
        ),
      );

  final String userId;

  final String displayName;

  final String? avatarUploadId;

  final DateTime suggestedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
    'suggested_at': suggestedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendSuggestion &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId &&
          suggestedAt == other.suggestedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    displayName,
    avatarUploadId,
    suggestedAt,
  ]);
}

final class FriendSuggestionList {
  const FriendSuggestionList({required this.suggestions});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FriendSuggestionList.fromJson(Map<String, Object?> json) =>
      FriendSuggestionList(
        suggestions: List<FriendSuggestion>.unmodifiable(
          _readList(
            json['suggestions'],
            'FriendSuggestionList.suggestions',
          ).map(
            (Object? e0) => FriendSuggestion.fromJson(
              _readObject(e0, 'FriendSuggestionList.suggestions'),
            ),
          ),
        ),
      );

  /// Kısıtlar: maxItems: 10.
  final List<FriendSuggestion> suggestions;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'suggestions': <Object?>[for (final e0 in suggestions) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendSuggestionList &&
          _deepEquals(suggestions, other.suggestions);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(suggestions)]);
}

/// Üye garajındaki bir araç (#272). Plaka alanı yoktur.
final class GarageVehicle {
  const GarageVehicle({
    required this.id,
    required this.ownerUserId,
    required this.make,
    this.model,
    this.modelYear,
    this.color,
    this.note,
    required this.photoUploadIds,
    required this.createdAt,
    required this.updatedAt,
    required this.callerCanEdit,
    required this.callerCanRemove,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GarageVehicle.fromJson(Map<String, Object?> json) => GarageVehicle(
    id: _readString(json['id'], 'GarageVehicle.id'),
    ownerUserId: _readString(
      json['owner_user_id'],
      'GarageVehicle.owner_user_id',
    ),
    make: _readString(json['make'], 'GarageVehicle.make'),
    model: switch (json['model']) {
      null => null,
      final Object v => _readString(v, 'GarageVehicle.model'),
    },
    modelYear: switch (json['model_year']) {
      null => null,
      final Object v => _readInt(v, 'GarageVehicle.model_year'),
    },
    color: switch (json['color']) {
      null => null,
      final Object v => _readString(v, 'GarageVehicle.color'),
    },
    note: switch (json['note']) {
      null => null,
      final Object v => _readString(v, 'GarageVehicle.note'),
    },
    photoUploadIds: List<String>.unmodifiable(
      _readList(
        json['photo_upload_ids'],
        'GarageVehicle.photo_upload_ids',
      ).map((Object? e0) => _readString(e0, 'GarageVehicle.photo_upload_ids')),
    ),
    createdAt: _readDateTime(json['created_at'], 'GarageVehicle.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'GarageVehicle.updated_at'),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'GarageVehicle.caller_can_edit',
    ),
    callerCanRemove: _readBool(
      json['caller_can_remove'],
      'GarageVehicle.caller_can_remove',
    ),
  );

  final String id;

  /// Aracın sahibi.
  final String ownerUserId;

  /// 1–40 karakter, tek satır.
  final String make;

  /// En fazla 40 karakter; yoksa alan yoktur.
  final String? model;

  /// Verilmemişse yoktur.
  final int? modelYear;

  /// En fazla 30 karakter; yoksa alan yoktur.
  final String? color;

  /// En fazla 200 karakter, tek satır; yoksa alan yoktur.
  final String? note;

  /// Sahibinin fotoğrafları (`garage_vehicle` yüklemesi), sırasıyla; adreslerini `POST /v1/media/urls` verir.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<String> photoUploadIds;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// Çağıran aracın sahibi mi (düzenler ve siler; `/v1/me/garage`).
  final bool callerCanEdit;

  /// Çağıran aracı tayfanın garajından şimdi kaldırabilir mi (moderatör; yalnızca tayfa garajı listesinde).
  final bool callerCanRemove;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'owner_user_id': ownerUserId,
    'make': make,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (note case final value?) 'note': value,
    'photo_upload_ids': <Object?>[for (final e0 in photoUploadIds) e0],
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'caller_can_edit': callerCanEdit,
    'caller_can_remove': callerCanRemove,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GarageVehicle &&
          id == other.id &&
          ownerUserId == other.ownerUserId &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          note == other.note &&
          _deepEquals(photoUploadIds, other.photoUploadIds) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          callerCanEdit == other.callerCanEdit &&
          callerCanRemove == other.callerCanRemove;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    ownerUserId,
    make,
    model,
    modelYear,
    color,
    note,
    _deepHash(photoUploadIds),
    createdAt,
    updatedAt,
    callerCanEdit,
    callerCanRemove,
  ]);
}

final class GarageVehicleCreateRequest {
  const GarageVehicleCreateRequest({
    required this.make,
    this.model,
    this.modelYear,
    this.color,
    this.note,
    this.photoUploadIds,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GarageVehicleCreateRequest.fromJson(
    Map<String, Object?> json,
  ) => GarageVehicleCreateRequest(
    make: _readString(json['make'], 'GarageVehicleCreateRequest.make'),
    model: switch (json['model']) {
      null => null,
      final Object v => _readString(v, 'GarageVehicleCreateRequest.model'),
    },
    modelYear: switch (json['model_year']) {
      null => null,
      final Object v => _readInt(v, 'GarageVehicleCreateRequest.model_year'),
    },
    color: switch (json['color']) {
      null => null,
      final Object v => _readString(v, 'GarageVehicleCreateRequest.color'),
    },
    note: switch (json['note']) {
      null => null,
      final Object v => _readString(v, 'GarageVehicleCreateRequest.note'),
    },
    photoUploadIds: switch (json['photo_upload_ids']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(v, 'GarageVehicleCreateRequest.photo_upload_ids').map(
          (Object? e0) =>
              _readString(e0, 'GarageVehicleCreateRequest.photo_upload_ids'),
        ),
      ),
    },
    clientRequestId: _readString(
      json['client_request_id'],
      'GarageVehicleCreateRequest.client_request_id',
    ),
  );

  /// 1–40 karakter; boşluklar tekleştirilir.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 1024.
  final String make;

  /// En fazla 40 karakter.
  ///
  /// Kısıtlar: maxLength: 1024.
  final String? model;

  /// 0 ya da 1900 – gelecek yıl.
  ///
  /// Kısıtlar: minimum: 0.
  final int? modelYear;

  /// En fazla 30 karakter.
  ///
  /// Kısıtlar: maxLength: 1024.
  final String? color;

  /// En fazla 200 karakter, tek satır.
  ///
  /// Kısıtlar: maxLength: 1024.
  final String? note;

  /// 0–3 fotoğraf (çağıranın hazır `garage_vehicle` yüklemeleri), sırasıyla.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<String>? photoUploadIds;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'make': make,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (note case final value?) 'note': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GarageVehicleCreateRequest &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          note == other.note &&
          _deepEquals(photoUploadIds, other.photoUploadIds) &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    make,
    model,
    modelYear,
    color,
    note,
    _deepHash(photoUploadIds),
    clientRequestId,
  ]);
}

/// Araç bir bütün olarak yazılır (kısmi güncelleme yok).
final class GarageVehicleRequest {
  const GarageVehicleRequest({
    required this.make,
    this.model,
    this.modelYear,
    this.color,
    this.note,
    this.photoUploadIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GarageVehicleRequest.fromJson(Map<String, Object?> json) =>
      GarageVehicleRequest(
        make: _readString(json['make'], 'GarageVehicleRequest.make'),
        model: switch (json['model']) {
          null => null,
          final Object v => _readString(v, 'GarageVehicleRequest.model'),
        },
        modelYear: switch (json['model_year']) {
          null => null,
          final Object v => _readInt(v, 'GarageVehicleRequest.model_year'),
        },
        color: switch (json['color']) {
          null => null,
          final Object v => _readString(v, 'GarageVehicleRequest.color'),
        },
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'GarageVehicleRequest.note'),
        },
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'GarageVehicleRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'GarageVehicleRequest.photo_upload_ids'),
            ),
          ),
        },
      );

  /// 1–40 karakter; boşluklar tekleştirilir.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 1024.
  final String make;

  /// En fazla 40 karakter.
  ///
  /// Kısıtlar: maxLength: 1024.
  final String? model;

  /// 0 ya da 1900 – gelecek yıl.
  ///
  /// Kısıtlar: minimum: 0.
  final int? modelYear;

  /// En fazla 30 karakter.
  ///
  /// Kısıtlar: maxLength: 1024.
  final String? color;

  /// En fazla 200 karakter, tek satır.
  ///
  /// Kısıtlar: maxLength: 1024.
  final String? note;

  /// 0–3 fotoğraf (çağıranın hazır `garage_vehicle` yüklemeleri), sırasıyla; düzenlemede listede olmayan silinir.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<String>? photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'make': make,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (note case final value?) 'note': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GarageVehicleRequest &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          note == other.note &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    make,
    model,
    modelYear,
    color,
    note,
    _deepHash(photoUploadIds),
  ]);
}

final class GarageVisibility {
  const GarageVisibility({required this.visible});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GarageVisibility.fromJson(Map<String, Object?> json) =>
      GarageVisibility(
        visible: _readBool(json['visible'], 'GarageVisibility.visible'),
      );

  /// Garajınız bu tayfada görünsün mü.
  final bool visible;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'visible': visible};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GarageVisibility && visible == other.visible;

  @override
  int get hashCode => Object.hashAll(<Object?>[visible]);
}

/// Yıllık hedef: tayfa istatistiğinden bir metrik ve hedef değer.
/// İlerleme yalnızca istatistikten dolar, elle artırılmaz.
final class GoalWidgetConfig {
  const GoalWidgetConfig({
    required this.metricKey,
    required this.target,
    this.year,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GoalWidgetConfig.fromJson(Map<String, Object?> json) =>
      GoalWidgetConfig(
        metricKey: _readString(
          json['metric_key'],
          'GoalWidgetConfig.metric_key',
        ),
        target: _readDouble(json['target'], 'GoalWidgetConfig.target'),
        year: switch (json['year']) {
          null => null,
          final Object v => _readInt(v, 'GoalWidgetConfig.year'),
        },
      );

  /// Kısıtlar: maxLength: 130.
  final String metricKey;

  /// Kısıtlar: maximum: 1000000000; exclusiveMinimum: 0.
  final double target;

  /// Yoksa her zaman içinde bulunulan yıl.
  ///
  /// Kısıtlar: minimum: 2000; maximum: 2999.
  final int? year;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_key': metricKey,
    'target': target,
    if (year case final value?) 'year': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalWidgetConfig &&
          metricKey == other.metricKey &&
          target == other.target &&
          year == other.year;

  @override
  int get hashCode => Object.hashAll(<Object?>[metricKey, target, year]);
}

final class GoalWidgetData {
  const GoalWidgetData({
    required this.metricKey,
    required this.target,
    required this.year,
    required this.value,
    required this.eventCount,
    required this.reached,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GoalWidgetData.fromJson(Map<String, Object?> json) => GoalWidgetData(
    metricKey: _readString(json['metric_key'], 'GoalWidgetData.metric_key'),
    target: _readDouble(json['target'], 'GoalWidgetData.target'),
    year: _readInt(json['year'], 'GoalWidgetData.year'),
    value: _readDouble(json['value'], 'GoalWidgetData.value'),
    eventCount: _readInt(json['event_count'], 'GoalWidgetData.event_count'),
    reached: _readBool(json['reached'], 'GoalWidgetData.reached'),
  );

  final String metricKey;

  final double target;

  final int year;

  final double value;

  final int eventCount;

  final bool reached;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_key': metricKey,
    'target': target,
    'year': year,
    'value': value,
    'event_count': eventCount,
    'reached': reached,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalWidgetData &&
          metricKey == other.metricKey &&
          target == other.target &&
          year == other.year &&
          value == other.value &&
          eventCount == other.eventCount &&
          reached == other.reached;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    metricKey,
    target,
    year,
    value,
    eventCount,
    reached,
  ]);
}

final class HomeChampion {
  const HomeChampion({
    required this.eventId,
    required this.eventTitle,
    required this.eventType,
    this.startsAt,
    required this.componentKey,
    this.announcedAt,
    required this.winners,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeChampion.fromJson(Map<String, Object?> json) => HomeChampion(
    eventId: _readString(json['event_id'], 'HomeChampion.event_id'),
    eventTitle: _readString(json['event_title'], 'HomeChampion.event_title'),
    eventType: _readString(json['event_type'], 'HomeChampion.event_type'),
    startsAt: switch (json['starts_at']) {
      null => null,
      final Object v => _readDateTime(v, 'HomeChampion.starts_at'),
    },
    componentKey: _readString(
      json['component_key'],
      'HomeChampion.component_key',
    ),
    announcedAt: switch (json['announced_at']) {
      null => null,
      final Object v => _readDateTime(v, 'HomeChampion.announced_at'),
    },
    winners: List<ChampionWinner>.unmodifiable(
      _readList(json['winners'], 'HomeChampion.winners').map(
        (Object? e0) =>
            ChampionWinner.fromJson(_readObject(e0, 'HomeChampion.winners')),
      ),
    ),
  );

  final String eventId;

  final String eventTitle;

  final String eventType;

  final DateTime? startsAt;

  /// Etkinliğin kutlama bileşeni.
  final String componentKey;

  final DateTime? announcedAt;

  final List<ChampionWinner> winners;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'event_id': eventId,
    'event_title': eventTitle,
    'event_type': eventType,
    if (startsAt case final value?)
      'starts_at': value.toUtc().toIso8601String(),
    'component_key': componentKey,
    if (announcedAt case final value?)
      'announced_at': value.toUtc().toIso8601String(),
    'winners': <Object?>[for (final e0 in winners) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeChampion &&
          eventId == other.eventId &&
          eventTitle == other.eventTitle &&
          eventType == other.eventType &&
          startsAt == other.startsAt &&
          componentKey == other.componentKey &&
          announcedAt == other.announcedAt &&
          _deepEquals(winners, other.winners);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    eventId,
    eventTitle,
    eventType,
    startsAt,
    componentKey,
    announcedAt,
    _deepHash(winners),
  ]);
}

final class HomeMetricValue {
  const HomeMetricValue({
    required this.metricKey,
    required this.value,
    required this.eventCount,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeMetricValue.fromJson(
    Map<String, Object?> json,
  ) => HomeMetricValue(
    metricKey: _readString(json['metric_key'], 'HomeMetricValue.metric_key'),
    value: _readDouble(json['value'], 'HomeMetricValue.value'),
    eventCount: _readInt(json['event_count'], 'HomeMetricValue.event_count'),
  );

  final String metricKey;

  /// Henüz sayılmamış metrikte 0.
  final double value;

  final int eventCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_key': metricKey,
    'value': value,
    'event_count': eventCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeMetricValue &&
          metricKey == other.metricKey &&
          value == other.value &&
          eventCount == other.eventCount;

  @override
  int get hashCode => Object.hashAll(<Object?>[metricKey, value, eventCount]);
}

/// Ana sayfa bileşeni. `kind` istemciye bilgi içindir; anahtar
/// listesi sunucunundur ve büyüyebilir (bugün `upcoming`,
/// `announcements`, `polls`, `questions`, `stats`, `goal`,
/// `countdown`, `champions`, `log_summary`, `daily`, `library`,
/// `question_pool`, `materials`, `garage`).
final class HomeWidget {
  const HomeWidget({
    required this.key,
    required this.kind,
    this.module,
    required this.enabled,
    required this.position,
    this.config,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeWidget.fromJson(Map<String, Object?> json) => HomeWidget(
    key: _readString(json['key'], 'HomeWidget.key'),
    kind: HomeWidgetKind.fromWire(_readString(json['kind'], 'HomeWidget.kind')),
    module: switch (json['module']) {
      null => null,
      final Object v => _readString(v, 'HomeWidget.module'),
    },
    enabled: _readBool(json['enabled'], 'HomeWidget.enabled'),
    position: _readInt(json['position'], 'HomeWidget.position'),
    config: switch (json['config']) {
      null => null,
      final Object v => HomeWidgetConfig.fromJson(
        _readObject(v, 'HomeWidget.config'),
      ),
    },
  );

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  /// `section` eski sabit bölüm (modülünün listesi), `display`
  /// gösterim bileşeni (verisi `…/data`), `module` modül vitrini
  /// (verisi modülün kendi uçlarından).
  final HomeWidgetKind kind;

  /// Bileşenin bağlı olduğu tayfa modülü; yoksa alan yoktur.
  final String? module;

  /// Ana sayfada (`home_widgets`) her zaman true.
  final bool enabled;

  /// Sıradaki kartından sonraki yeri, 0'dan.
  final int position;

  final HomeWidgetConfig? config;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'kind': kind.wire,
    if (module case final value?) 'module': value,
    'enabled': enabled,
    'position': position,
    if (config case final value?) 'config': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidget &&
          key == other.key &&
          kind == other.kind &&
          module == other.module &&
          enabled == other.enabled &&
          position == other.position &&
          config == other.config;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[key, kind, module, enabled, position, config]);
}

/// Bileşenin ayarı: en fazla bileşenin kendi anahtarındaki alan
/// bulunur. Okurken `stats` ve `champions` her zaman ayarlıdır
/// (varsayılanlarla).
final class HomeWidgetConfig {
  const HomeWidgetConfig({
    this.stats,
    this.goal,
    this.countdown,
    this.champions,
    this.logSummary,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeWidgetConfig.fromJson(Map<String, Object?> json) =>
      HomeWidgetConfig(
        stats: switch (json['stats']) {
          null => null,
          final Object v => StatsWidgetConfig.fromJson(
            _readObject(v, 'HomeWidgetConfig.stats'),
          ),
        },
        goal: switch (json['goal']) {
          null => null,
          final Object v => GoalWidgetConfig.fromJson(
            _readObject(v, 'HomeWidgetConfig.goal'),
          ),
        },
        countdown: switch (json['countdown']) {
          null => null,
          final Object v => CountdownWidgetConfig.fromJson(
            _readObject(v, 'HomeWidgetConfig.countdown'),
          ),
        },
        champions: switch (json['champions']) {
          null => null,
          final Object v => ChampionsWidgetConfig.fromJson(
            _readObject(v, 'HomeWidgetConfig.champions'),
          ),
        },
        logSummary: switch (json['log_summary']) {
          null => null,
          final Object v => LogSummaryWidgetConfig.fromJson(
            _readObject(v, 'HomeWidgetConfig.log_summary'),
          ),
        },
      );

  final StatsWidgetConfig? stats;

  final GoalWidgetConfig? goal;

  final CountdownWidgetConfig? countdown;

  final ChampionsWidgetConfig? champions;

  final LogSummaryWidgetConfig? logSummary;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (stats case final value?) 'stats': value.toJson(),
    if (goal case final value?) 'goal': value.toJson(),
    if (countdown case final value?) 'countdown': value.toJson(),
    if (champions case final value?) 'champions': value.toJson(),
    if (logSummary case final value?) 'log_summary': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetConfig &&
          stats == other.stats &&
          goal == other.goal &&
          countdown == other.countdown &&
          champions == other.champions &&
          logSummary == other.logSummary;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[stats, goal, countdown, champions, logSummary]);
}

/// Bileşenin anahtarındaki alan bulunur.
final class HomeWidgetData {
  const HomeWidgetData({
    required this.key,
    this.stats,
    this.goal,
    this.countdown,
    this.champions,
    this.logSummary,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeWidgetData.fromJson(Map<String, Object?> json) => HomeWidgetData(
    key: _readString(json['key'], 'HomeWidgetData.key'),
    stats: switch (json['stats']) {
      null => null,
      final Object v => StatsWidgetData.fromJson(
        _readObject(v, 'HomeWidgetData.stats'),
      ),
    },
    goal: switch (json['goal']) {
      null => null,
      final Object v => GoalWidgetData.fromJson(
        _readObject(v, 'HomeWidgetData.goal'),
      ),
    },
    countdown: switch (json['countdown']) {
      null => null,
      final Object v => CountdownWidgetData.fromJson(
        _readObject(v, 'HomeWidgetData.countdown'),
      ),
    },
    champions: switch (json['champions']) {
      null => null,
      final Object v => ChampionsWidgetData.fromJson(
        _readObject(v, 'HomeWidgetData.champions'),
      ),
    },
    logSummary: switch (json['log_summary']) {
      null => null,
      final Object v => LogSummaryWidgetData.fromJson(
        _readObject(v, 'HomeWidgetData.log_summary'),
      ),
    },
  );

  final String key;

  final StatsWidgetData? stats;

  final GoalWidgetData? goal;

  final CountdownWidgetData? countdown;

  final ChampionsWidgetData? champions;

  final LogSummaryWidgetData? logSummary;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    if (stats case final value?) 'stats': value.toJson(),
    if (goal case final value?) 'goal': value.toJson(),
    if (countdown case final value?) 'countdown': value.toJson(),
    if (champions case final value?) 'champions': value.toJson(),
    if (logSummary case final value?) 'log_summary': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetData &&
          key == other.key &&
          stats == other.stats &&
          goal == other.goal &&
          countdown == other.countdown &&
          champions == other.champions &&
          logSummary == other.logSummary;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    key,
    stats,
    goal,
    countdown,
    champions,
    logSummary,
  ]);
}

final class HomeWidgetInput {
  const HomeWidgetInput({
    required this.key,
    required this.enabled,
    this.config,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeWidgetInput.fromJson(Map<String, Object?> json) =>
      HomeWidgetInput(
        key: _readString(json['key'], 'HomeWidgetInput.key'),
        enabled: _readBool(json['enabled'], 'HomeWidgetInput.enabled'),
        config: switch (json['config']) {
          null => null,
          final Object v => HomeWidgetConfig.fromJson(
            _readObject(v, 'HomeWidgetInput.config'),
          ),
        },
      );

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String key;

  final bool enabled;

  final HomeWidgetConfig? config;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'enabled': enabled,
    if (config case final value?) 'config': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetInput &&
          key == other.key &&
          enabled == other.enabled &&
          config == other.config;

  @override
  int get hashCode => Object.hashAll(<Object?>[key, enabled, config]);
}

/// `section` eski sabit bölüm (modülünün listesi), `display`
/// gösterim bileşeni (verisi `…/data`), `module` modül vitrini
/// (verisi modülün kendi uçlarından).
enum HomeWidgetKind {
  section('section'),
  display('display'),
  module('module'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const HomeWidgetKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('HomeWidgetKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static HomeWidgetKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class HomeWidgetLayout {
  const HomeWidgetLayout({required this.widgets});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeWidgetLayout.fromJson(Map<String, Object?> json) =>
      HomeWidgetLayout(
        widgets: List<HomeWidget>.unmodifiable(
          _readList(json['widgets'], 'HomeWidgetLayout.widgets').map(
            (Object? e0) => HomeWidget.fromJson(
              _readObject(e0, 'HomeWidgetLayout.widgets'),
            ),
          ),
        ),
      );

  final List<HomeWidget> widgets;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'widgets': <Object?>[for (final e0 in widgets) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetLayout && _deepEquals(widgets, other.widgets);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(widgets)]);
}

final class HomeWidgetLayoutInput {
  const HomeWidgetLayoutInput({required this.widgets});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HomeWidgetLayoutInput.fromJson(Map<String, Object?> json) =>
      HomeWidgetLayoutInput(
        widgets: List<HomeWidgetInput>.unmodifiable(
          _readList(json['widgets'], 'HomeWidgetLayoutInput.widgets').map(
            (Object? e0) => HomeWidgetInput.fromJson(
              _readObject(e0, 'HomeWidgetLayoutInput.widgets'),
            ),
          ),
        ),
      );

  /// Bütün liste, yeni sırasıyla.
  ///
  /// Kısıtlar: maxItems: 64.
  final List<HomeWidgetInput> widgets;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'widgets': <Object?>[for (final e0 in widgets) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeWidgetLayoutInput && _deepEquals(widgets, other.widgets);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(widgets)]);
}

/// Dönem. `this_year` Europe/Istanbul takvim yılı; `all_time` tüm
/// zamanlar (`stats`, `log_summary`); `last_30_days` son 30 gün
/// (`champions`).
enum HomeWidgetPeriod {
  thisYear('this_year'),
  allTime('all_time'),
  last30Days('last_30_days'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const HomeWidgetPeriod(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('HomeWidgetPeriod.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static HomeWidgetPeriod fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class InstantEvent {
  const InstantEvent({required this.tayfa, required this.event});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InstantEvent.fromJson(Map<String, Object?> json) => InstantEvent(
    tayfa: Tayfa.fromJson(_readObject(json['tayfa'], 'InstantEvent.tayfa')),
    event: Event.fromJson(_readObject(json['event'], 'InstantEvent.event')),
  );

  final Tayfa tayfa;

  final Event event;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa': tayfa.toJson(),
    'event': event.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstantEvent && tayfa == other.tayfa && event == other.event;

  @override
  int get hashCode => Object.hashAll(<Object?>[tayfa, event]);
}

final class InstantEventCreateRequest {
  const InstantEventCreateRequest({
    required this.event,
    this.inviteeUserIds,
    this.nowRecipientIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InstantEventCreateRequest.fromJson(Map<String, Object?> json) =>
      InstantEventCreateRequest(
        event: EventCreateRequest.fromJson(
          _readObject(json['event'], 'InstantEventCreateRequest.event'),
        ),
        inviteeUserIds: switch (json['invitee_user_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'InstantEventCreateRequest.invitee_user_ids').map(
              (Object? e0) =>
                  _readString(e0, 'InstantEventCreateRequest.invitee_user_ids'),
            ),
          ),
        },
        nowRecipientIds: switch (json['now_recipient_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'InstantEventCreateRequest.now_recipient_ids').map(
              (Object? e0) => _readString(
                e0,
                'InstantEventCreateRequest.now_recipient_ids',
              ),
            ),
          ),
        },
      );

  /// Etkinlik; kuralları tayfa etkinliğiyle aynı. `recurrence` ve
  /// `cover_upload_id` verilemez, `discoverable` `true` olamaz. `client_request_id` isteğin tekrar
  /// gönderim anahtarıdır.
  final EventCreateRequest event;

  /// Doğrudan davet edilecek arkadaşlarınız (en fazla 10, siz değil).
  ///
  /// Kısıtlar: maxItems: 10; uniqueItems: true.
  final List<String>? inviteeUserIds;

  /// Yalnızca `event.starts_now` ile (yoksa `invalid-request`):
  /// etkinliğin başladığını öğrenecek ve davet edilecek
  /// arkadaşlarınız (en fazla 30; siz ve `invitee_user_ids`'deki
  /// kişiler değil). Bildirimde başlık, tür, yer ya da ad yoktur.
  ///
  /// Kısıtlar: maxItems: 30; uniqueItems: true.
  final List<String>? nowRecipientIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'event': event.toJson(),
    if (inviteeUserIds case final value?)
      'invitee_user_ids': <Object?>[for (final e0 in value) e0],
    if (nowRecipientIds case final value?)
      'now_recipient_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstantEventCreateRequest &&
          event == other.event &&
          _deepEquals(inviteeUserIds, other.inviteeUserIds) &&
          _deepEquals(nowRecipientIds, other.nowRecipientIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    event,
    _deepHash(inviteeUserIds),
    _deepHash(nowRecipientIds),
  ]);
}

final class Invitation {
  const Invitation({
    required this.tayfaId,
    required this.tayfaName,
    required this.userId,
    this.inviterUserId,
    required this.invitedAt,
    required this.interests,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Invitation.fromJson(Map<String, Object?> json) => Invitation(
    tayfaId: _readString(json['tayfa_id'], 'Invitation.tayfa_id'),
    tayfaName: _readString(json['tayfa_name'], 'Invitation.tayfa_name'),
    userId: _readString(json['user_id'], 'Invitation.user_id'),
    inviterUserId: switch (json['inviter_user_id']) {
      null => null,
      final Object v => _readString(v, 'Invitation.inviter_user_id'),
    },
    invitedAt: _readDateTime(json['invited_at'], 'Invitation.invited_at'),
    interests: List<String>.unmodifiable(
      _readList(
        json['interests'],
        'Invitation.interests',
      ).map((Object? e0) => _readString(e0, 'Invitation.interests')),
    ),
  );

  final String tayfaId;

  final String tayfaName;

  /// Davet edilen kişi.
  final String userId;

  /// Davet edenin hesabı silinmişse yoktur.
  final String? inviterUserId;

  final DateTime invitedAt;

  /// Tayfanın ilgi alanları (issue
  final List<String> interests;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'tayfa_name': tayfaName,
    'user_id': userId,
    if (inviterUserId case final value?) 'inviter_user_id': value,
    'invited_at': invitedAt.toUtc().toIso8601String(),
    'interests': <Object?>[for (final e0 in interests) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invitation &&
          tayfaId == other.tayfaId &&
          tayfaName == other.tayfaName &&
          userId == other.userId &&
          inviterUserId == other.inviterUserId &&
          invitedAt == other.invitedAt &&
          _deepEquals(interests, other.interests);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    tayfaId,
    tayfaName,
    userId,
    inviterUserId,
    invitedAt,
    _deepHash(interests),
  ]);
}

final class InvitationList {
  const InvitationList({required this.invitations, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InvitationList.fromJson(Map<String, Object?> json) => InvitationList(
    invitations: List<Invitation>.unmodifiable(
      _readList(json['invitations'], 'InvitationList.invitations').map(
        (Object? e0) =>
            Invitation.fromJson(_readObject(e0, 'InvitationList.invitations')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'InvitationList.next_page_token'),
    },
  );

  final List<Invitation> invitations;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'invitations': <Object?>[for (final e0 in invitations) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitationList &&
          _deepEquals(invitations, other.invitations) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(invitations), nextPageToken]);
}

/// Davet linki. Token ya da özeti hiçbir zaman dönmez.
final class Invite {
  const Invite({
    required this.id,
    required this.tayfaId,
    required this.createdByUserId,
    required this.createdAt,
    required this.expiresAt,
    required this.maxUses,
    required this.useCount,
    this.revokedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Invite.fromJson(Map<String, Object?> json) => Invite(
    id: _readString(json['id'], 'Invite.id'),
    tayfaId: _readString(json['tayfa_id'], 'Invite.tayfa_id'),
    createdByUserId: _readString(
      json['created_by_user_id'],
      'Invite.created_by_user_id',
    ),
    createdAt: _readDateTime(json['created_at'], 'Invite.created_at'),
    expiresAt: _readDateTime(json['expires_at'], 'Invite.expires_at'),
    maxUses: _readInt(json['max_uses'], 'Invite.max_uses'),
    useCount: _readInt(json['use_count'], 'Invite.use_count'),
    revokedAt: switch (json['revoked_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Invite.revoked_at'),
    },
  );

  final String id;

  final String tayfaId;

  final String createdByUserId;

  final DateTime createdAt;

  final DateTime expiresAt;

  final int maxUses;

  final int useCount;

  final DateTime? revokedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    'created_by_user_id': createdByUserId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'max_uses': maxUses,
    'use_count': useCount,
    if (revokedAt case final value?)
      'revoked_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invite &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          createdByUserId == other.createdByUserId &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt &&
          maxUses == other.maxUses &&
          useCount == other.useCount &&
          revokedAt == other.revokedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    createdByUserId,
    createdAt,
    expiresAt,
    maxUses,
    useCount,
    revokedAt,
  ]);
}

final class InviteCreateRequest {
  const InviteCreateRequest({required this.ttlSeconds, required this.maxUses});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InviteCreateRequest.fromJson(Map<String, Object?> json) =>
      InviteCreateRequest(
        ttlSeconds: _readInt(
          json['ttl_seconds'],
          'InviteCreateRequest.ttl_seconds',
        ),
        maxUses: _readInt(json['max_uses'], 'InviteCreateRequest.max_uses'),
      );

  /// Linkin geçerlilik süresi; 1 saat ile 30 gün arası.
  ///
  /// Kısıtlar: minimum: 3600; maximum: 2592000.
  final int ttlSeconds;

  /// Kısıtlar: minimum: 1; maximum: 100.
  final int maxUses;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'ttl_seconds': ttlSeconds,
    'max_uses': maxUses,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteCreateRequest &&
          ttlSeconds == other.ttlSeconds &&
          maxUses == other.maxUses;

  @override
  int get hashCode => Object.hashAll(<Object?>[ttlSeconds, maxUses]);
}

final class InviteList {
  const InviteList({required this.invites});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InviteList.fromJson(Map<String, Object?> json) => InviteList(
    invites: List<Invite>.unmodifiable(
      _readList(json['invites'], 'InviteList.invites').map(
        (Object? e0) => Invite.fromJson(_readObject(e0, 'InviteList.invites')),
      ),
    ),
  );

  final List<Invite> invites;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'invites': <Object?>[for (final e0 in invites) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteList && _deepEquals(invites, other.invites);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(invites)]);
}

/// Linki bilen herkesin görebileceği dar görünüm.
final class InvitePreview {
  const InvitePreview({
    required this.tayfaId,
    required this.name,
    required this.memberCount,
    required this.alreadyMember,
    required this.interests,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InvitePreview.fromJson(Map<String, Object?> json) => InvitePreview(
    tayfaId: _readString(json['tayfa_id'], 'InvitePreview.tayfa_id'),
    name: _readString(json['name'], 'InvitePreview.name'),
    memberCount: _readInt(json['member_count'], 'InvitePreview.member_count'),
    alreadyMember: _readBool(
      json['already_member'],
      'InvitePreview.already_member',
    ),
    interests: List<String>.unmodifiable(
      _readList(
        json['interests'],
        'InvitePreview.interests',
      ).map((Object? e0) => _readString(e0, 'InvitePreview.interests')),
    ),
  );

  final String tayfaId;

  final String name;

  final int memberCount;

  /// Zaten etkin üyeyseniz ya da bekleyen isteğiniz varsa.
  final bool alreadyMember;

  /// Tayfanın ilgi alanları (issue #194; avatar rengi). Yalnızca geçerli
  /// davette döner; geçersiz davette hiçbir tayfa bilgisi dönmez.
  final List<String> interests;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'name': name,
    'member_count': memberCount,
    'already_member': alreadyMember,
    'interests': <Object?>[for (final e0 in interests) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitePreview &&
          tayfaId == other.tayfaId &&
          name == other.name &&
          memberCount == other.memberCount &&
          alreadyMember == other.alreadyMember &&
          _deepEquals(interests, other.interests);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    tayfaId,
    name,
    memberCount,
    alreadyMember,
    _deepHash(interests),
  ]);
}

final class InviteTokenRequest {
  const InviteTokenRequest({required this.token});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory InviteTokenRequest.fromJson(Map<String, Object?> json) =>
      InviteTokenRequest(
        token: _readString(json['token'], 'InviteTokenRequest.token'),
      );

  /// Kısıtlar: maxLength: 64.
  final String token;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'token': token};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteTokenRequest && token == other.token;

  @override
  int get hashCode => Object.hashAll(<Object?>[token]);
}

final class JoinByCodeRequest {
  const JoinByCodeRequest({required this.code});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory JoinByCodeRequest.fromJson(Map<String, Object?> json) =>
      JoinByCodeRequest(
        code: _readString(json['code'], 'JoinByCodeRequest.code'),
      );

  /// Katılım kodu; büyük/küçük harf duyarsız.
  ///
  /// Kısıtlar: maxLength: 32.
  final String code;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'code': code};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinByCodeRequest && code == other.code;

  @override
  int get hashCode => Object.hashAll(<Object?>[code]);
}

final class JoinCode {
  const JoinCode({required this.joinCode});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory JoinCode.fromJson(Map<String, Object?> json) =>
      JoinCode(joinCode: _readString(json['join_code'], 'JoinCode.join_code'));

  /// 8 karakter, `[2-9A-HJ-NP-Z]`.
  final String joinCode;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'join_code': joinCode};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JoinCode && joinCode == other.joinCode;

  @override
  int get hashCode => Object.hashAll(<Object?>[joinCode]);
}

/// `approval`: yeni üyeler onay bekler. `open`: hemen etkin olur.
enum JoinPolicy {
  approval('approval'),
  open('open'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const JoinPolicy(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('JoinPolicy.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static JoinPolicy fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class JoinQrResult {
  const JoinQrResult({
    required this.tayfaId,
    required this.eventId,
    required this.pending,
    this.rsvp,
    this.attendance,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory JoinQrResult.fromJson(Map<String, Object?> json) => JoinQrResult(
    tayfaId: _readString(json['tayfa_id'], 'JoinQrResult.tayfa_id'),
    eventId: _readString(json['event_id'], 'JoinQrResult.event_id'),
    pending: _readBool(json['pending'], 'JoinQrResult.pending'),
    rsvp: switch (json['rsvp']) {
      null => null,
      final Object v => RsvpStatus.fromWire(
        _readString(v, 'JoinQrResult.rsvp'),
      ),
    },
    attendance: switch (json['attendance']) {
      null => null,
      final Object v => AttendanceStatus.fromWire(
        _readString(v, 'JoinQrResult.attendance'),
      ),
    },
  );

  final String tayfaId;

  final String eventId;

  /// Onaylı tayfada katılım isteği bırakıldı (ya da zaten bekliyordu); `rsvp` ve `attendance` yok.
  final bool pending;

  final RsvpStatus? rsvp;

  final AttendanceStatus? attendance;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'event_id': eventId,
    'pending': pending,
    if (rsvp case final value?) 'rsvp': value.wire,
    if (attendance case final value?) 'attendance': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinQrResult &&
          tayfaId == other.tayfaId &&
          eventId == other.eventId &&
          pending == other.pending &&
          rsvp == other.rsvp &&
          attendance == other.attendance;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[tayfaId, eventId, pending, rsvp, attendance]);
}

/// QR ile katılım token'ı (ADR-0038 §3). Log'a yazılmaz.
final class JoinQrToken {
  const JoinQrToken({required this.token, required this.expiresAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory JoinQrToken.fromJson(Map<String, Object?> json) => JoinQrToken(
    token: _readString(json['token'], 'JoinQrToken.token'),
    expiresAt: _readDateTime(json['expires_at'], 'JoinQrToken.expires_at'),
  );

  /// base64url, 128 bit. QR `https://tayfam.app/q#<token>` taşır.
  ///
  /// Kısıtlar: minLength: 22; maxLength: 22.
  final String token;

  /// Oluşturmadan 2 dakika sonra.
  final DateTime expiresAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinQrToken &&
          token == other.token &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[token, expiresAt]);
}

final class JoinRequest {
  const JoinRequest({
    required this.userId,
    required this.requestedAt,
    required this.source,
    this.inviterUserId,
    this.inviteId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory JoinRequest.fromJson(Map<String, Object?> json) => JoinRequest(
    userId: _readString(json['user_id'], 'JoinRequest.user_id'),
    requestedAt: _readDateTime(
      json['requested_at'],
      'JoinRequest.requested_at',
    ),
    source: JoinRequestSource.fromWire(
      _readString(json['source'], 'JoinRequest.source'),
    ),
    inviterUserId: switch (json['inviter_user_id']) {
      null => null,
      final Object v => _readString(v, 'JoinRequest.inviter_user_id'),
    },
    inviteId: switch (json['invite_id']) {
      null => null,
      final Object v => _readString(v, 'JoinRequest.invite_id'),
    },
  );

  final String userId;

  final DateTime requestedAt;

  final JoinRequestSource source;

  /// Davet eden ya da linki açan kişi; kodla katılımda yok.
  final String? inviterUserId;

  /// Kullanılan davet linki; yalnızca `source=invite_link`.
  final String? inviteId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    'source': source.wire,
    if (inviterUserId case final value?) 'inviter_user_id': value,
    if (inviteId case final value?) 'invite_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinRequest &&
          userId == other.userId &&
          requestedAt == other.requestedAt &&
          source == other.source &&
          inviterUserId == other.inviterUserId &&
          inviteId == other.inviteId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    requestedAt,
    source,
    inviterUserId,
    inviteId,
  ]);
}

final class JoinRequestList {
  const JoinRequestList({required this.joinRequests, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory JoinRequestList.fromJson(Map<String, Object?> json) =>
      JoinRequestList(
        joinRequests: List<JoinRequest>.unmodifiable(
          _readList(json['join_requests'], 'JoinRequestList.join_requests').map(
            (Object? e0) => JoinRequest.fromJson(
              _readObject(e0, 'JoinRequestList.join_requests'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'JoinRequestList.next_page_token'),
        },
      );

  final List<JoinRequest> joinRequests;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'join_requests': <Object?>[for (final e0 in joinRequests) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinRequestList &&
          _deepEquals(joinRequests, other.joinRequests) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(joinRequests), nextPageToken]);
}

enum JoinRequestSource {
  inviteLink('invite_link'),
  directInvite('direct_invite'),
  code('code'),
  discover('discover'),
  qr('qr'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const JoinRequestSource(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('JoinRequestSource.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static JoinRequestSource fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// WGS 84 derece. Yalnızca gövdede taşınır; log'a yazılmaz.
final class LatLng {
  const LatLng({required this.lat, required this.lng});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LatLng.fromJson(Map<String, Object?> json) => LatLng(
    lat: _readDouble(json['lat'], 'LatLng.lat'),
    lng: _readDouble(json['lng'], 'LatLng.lng'),
  );

  /// Kısıtlar: minimum: -90; maximum: 90.
  final double lat;

  /// Kısıtlar: minimum: -180; maximum: 180.
  final double lng;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng && lat == other.lat && lng == other.lng;

  @override
  int get hashCode => Object.hashAll(<Object?>[lat, lng]);
}

final class LibraryHandOverRequest {
  const LibraryHandOverRequest({this.dueAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryHandOverRequest.fromJson(Map<String, Object?> json) =>
      LibraryHandOverRequest(
        dueAt: switch (json['due_at']) {
          null => null,
          final Object v => _readDateTime(v, 'LibraryHandOverRequest.due_at'),
        },
      );

  /// İsteğe bağlı iade tarihi; şimdiden sonra, en fazla 90 gün.
  final DateTime? dueAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (dueAt case final value?) 'due_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryHandOverRequest && dueAt == other.dueAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[dueAt]);
}

final class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.kind,
    required this.name,
    this.vocabularyId,
    this.note,
    this.photoUploadId,
    this.ownerUserId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.queueLength,
    this.callerQueueRank,
    this.activeLoan,
    this.queue,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryItem.fromJson(Map<String, Object?> json) => LibraryItem(
    id: _readString(json['id'], 'LibraryItem.id'),
    kind: LibraryItemKind.fromWire(
      _readString(json['kind'], 'LibraryItem.kind'),
    ),
    name: _readString(json['name'], 'LibraryItem.name'),
    vocabularyId: switch (json['vocabulary_id']) {
      null => null,
      final Object v => _readString(v, 'LibraryItem.vocabulary_id'),
    },
    note: switch (json['note']) {
      null => null,
      final Object v => _readString(v, 'LibraryItem.note'),
    },
    photoUploadId: switch (json['photo_upload_id']) {
      null => null,
      final Object v => _readString(v, 'LibraryItem.photo_upload_id'),
    },
    ownerUserId: switch (json['owner_user_id']) {
      null => null,
      final Object v => _readString(v, 'LibraryItem.owner_user_id'),
    },
    status: LibraryItemStatus.fromWire(
      _readString(json['status'], 'LibraryItem.status'),
    ),
    createdAt: _readDateTime(json['created_at'], 'LibraryItem.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'LibraryItem.updated_at'),
    queueLength: _readInt(json['queue_length'], 'LibraryItem.queue_length'),
    callerQueueRank: switch (json['caller_queue_rank']) {
      null => null,
      final Object v => _readInt(v, 'LibraryItem.caller_queue_rank'),
    },
    activeLoan: switch (json['active_loan']) {
      null => null,
      final Object v => LibraryLoan.fromJson(
        _readObject(v, 'LibraryItem.active_loan'),
      ),
    },
    queue: switch (json['queue']) {
      null => null,
      final Object v => List<LibraryQueueEntry>.unmodifiable(
        _readList(v, 'LibraryItem.queue').map(
          (Object? e0) =>
              LibraryQueueEntry.fromJson(_readObject(e0, 'LibraryItem.queue')),
        ),
      ),
    },
  );

  final String id;

  final LibraryItemKind kind;

  /// 1–80 karakter, tek satır (kitapta 1–60, tayfa sözlüğündeki adı).
  final String name;

  /// Yalnızca kitapta, tayfa sözlüğündeki değer (ad alanı `book`).
  final String? vocabularyId;

  /// En fazla 300 karakter; satırlar `\n` ile ayrılır. Yoksa alan yoktur.
  final String? note;

  /// Sahibinin fotoğrafı (`library_item` yüklemesi); adresini `POST /v1/media/urls` verir.
  final String? photoUploadId;

  final String? ownerUserId;

  /// `available` ya da `on_loan` (teslim edildi). Tanınmayan değer `unknown`.
  final LibraryItemStatus status;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// Sırada bekleyen kişi sayısı.
  final int queueLength;

  /// Çağıranın sıradaki yeri (1 sıradaki); beklemiyorsa alan yoktur.
  final int? callerQueueRank;

  final LibraryLoan? activeLoan;

  /// Sıra; yalnızca sahibine ve yalnızca `GET …/items/{library_item_id}` ile.
  final List<LibraryQueueEntry>? queue;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.wire,
    'name': name,
    if (vocabularyId case final value?) 'vocabulary_id': value,
    if (note case final value?) 'note': value,
    if (photoUploadId case final value?) 'photo_upload_id': value,
    if (ownerUserId case final value?) 'owner_user_id': value,
    'status': status.wire,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'queue_length': queueLength,
    if (callerQueueRank case final value?) 'caller_queue_rank': value,
    if (activeLoan case final value?) 'active_loan': value.toJson(),
    if (queue case final value?)
      'queue': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryItem &&
          id == other.id &&
          kind == other.kind &&
          name == other.name &&
          vocabularyId == other.vocabularyId &&
          note == other.note &&
          photoUploadId == other.photoUploadId &&
          ownerUserId == other.ownerUserId &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          queueLength == other.queueLength &&
          callerQueueRank == other.callerQueueRank &&
          activeLoan == other.activeLoan &&
          _deepEquals(queue, other.queue);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    kind,
    name,
    vocabularyId,
    note,
    photoUploadId,
    ownerUserId,
    status,
    createdAt,
    updatedAt,
    queueLength,
    callerQueueRank,
    activeLoan,
    _deepHash(queue),
  ]);
}

final class LibraryItemCreateRequest {
  const LibraryItemCreateRequest({
    required this.kind,
    required this.name,
    this.note,
    this.photoUploadId,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryItemCreateRequest.fromJson(Map<String, Object?> json) =>
      LibraryItemCreateRequest(
        kind: LibraryItemKind.fromWire(
          _readString(json['kind'], 'LibraryItemCreateRequest.kind'),
        ),
        name: _readString(json['name'], 'LibraryItemCreateRequest.name'),
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'LibraryItemCreateRequest.note'),
        },
        photoUploadId: switch (json['photo_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'LibraryItemCreateRequest.photo_upload_id',
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'LibraryItemCreateRequest.client_request_id',
        ),
      );

  final LibraryItemKind kind;

  /// Kısıtlar: minLength: 1; maxLength: 1024.
  final String name;

  /// Boş: yok.
  ///
  /// Kısıtlar: maxLength: 4096.
  final String? note;

  final String? photoUploadId;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    'name': name,
    if (note case final value?) 'note': value,
    if (photoUploadId case final value?) 'photo_upload_id': value,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryItemCreateRequest &&
          kind == other.kind &&
          name == other.name &&
          note == other.note &&
          photoUploadId == other.photoUploadId &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    kind,
    name,
    note,
    photoUploadId,
    clientRequestId,
  ]);
}

/// Kalemin türü: kitap, kamp malzemesi, masa oyunu, alet, diğer.
enum LibraryItemKind {
  book('book'),
  campingGear('camping_gear'),
  boardGame('board_game'),
  tool('tool'),
  other('other'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const LibraryItemKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('LibraryItemKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static LibraryItemKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class LibraryItemList {
  const LibraryItemList({required this.items, required this.callerCanAdd});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryItemList.fromJson(Map<String, Object?> json) =>
      LibraryItemList(
        items: List<LibraryItem>.unmodifiable(
          _readList(json['items'], 'LibraryItemList.items').map(
            (Object? e0) =>
                LibraryItem.fromJson(_readObject(e0, 'LibraryItemList.items')),
          ),
        ),
        callerCanAdd: _readBool(
          json['caller_can_add'],
          'LibraryItemList.caller_can_add',
        ),
      );

  final List<LibraryItem> items;

  /// Çağıran şimdi kalem ekleyebilir mi.
  final bool callerCanAdd;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'items': <Object?>[for (final e0 in items) e0.toJson()],
    'caller_can_add': callerCanAdd,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryItemList &&
          _deepEquals(items, other.items) &&
          callerCanAdd == other.callerCanAdd;

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(items), callerCanAdd]);
}

/// `available` ya da `on_loan` (teslim edildi). Tanınmayan değer `unknown`.
enum LibraryItemStatus {
  available('available'),
  onLoan('on_loan'),
  withdrawn('withdrawn'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const LibraryItemStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('LibraryItemStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static LibraryItemStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class LibraryItemUpdateRequest {
  const LibraryItemUpdateRequest({
    required this.name,
    this.note,
    this.photoUploadId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryItemUpdateRequest.fromJson(Map<String, Object?> json) =>
      LibraryItemUpdateRequest(
        name: _readString(json['name'], 'LibraryItemUpdateRequest.name'),
        note: switch (json['note']) {
          null => null,
          final Object v => _readString(v, 'LibraryItemUpdateRequest.note'),
        },
        photoUploadId: switch (json['photo_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'LibraryItemUpdateRequest.photo_upload_id',
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 1024.
  final String name;

  /// Boş: yok.
  ///
  /// Kısıtlar: maxLength: 4096.
  final String? note;

  /// Yoksa fotoğraf kalkar.
  final String? photoUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (note case final value?) 'note': value,
    if (photoUploadId case final value?) 'photo_upload_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryItemUpdateRequest &&
          name == other.name &&
          note == other.note &&
          photoUploadId == other.photoUploadId;

  @override
  int get hashCode => Object.hashAll(<Object?>[name, note, photoUploadId]);
}

/// Bir ödünç; yalnızca iki tarafı görür. `state`: `requested` (istendi),
/// `approved` (sahibi onayladı), `handed_over` (teslim edildi),
/// `returned` (iade alındı), `declined` (reddedildi), `cancelled`
/// (borç alan geri aldı, kalem geri çekildi ya da taraf ayrıldı),
/// `closed` (teslimdeyken taraflardan biri tayfadan ayrıldı, kayıt 30
/// gün sonra iade alınmadan kapandı). Tanınmayan değer `unknown`.
final class LibraryLoan {
  const LibraryLoan({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemKind,
    this.ownerUserId,
    this.borrowerUserId,
    required this.state,
    required this.requestedAt,
    this.approvedAt,
    this.handedOverAt,
    this.dueAt,
    this.orphanedAt,
    this.endedAt,
    required this.callerIsOwner,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryLoan.fromJson(Map<String, Object?> json) => LibraryLoan(
    id: _readString(json['id'], 'LibraryLoan.id'),
    itemId: _readString(json['item_id'], 'LibraryLoan.item_id'),
    itemName: _readString(json['item_name'], 'LibraryLoan.item_name'),
    itemKind: LibraryItemKind.fromWire(
      _readString(json['item_kind'], 'LibraryLoan.item_kind'),
    ),
    ownerUserId: switch (json['owner_user_id']) {
      null => null,
      final Object v => _readString(v, 'LibraryLoan.owner_user_id'),
    },
    borrowerUserId: switch (json['borrower_user_id']) {
      null => null,
      final Object v => _readString(v, 'LibraryLoan.borrower_user_id'),
    },
    state: LibraryLoanState.fromWire(
      _readString(json['state'], 'LibraryLoan.state'),
    ),
    requestedAt: _readDateTime(
      json['requested_at'],
      'LibraryLoan.requested_at',
    ),
    approvedAt: switch (json['approved_at']) {
      null => null,
      final Object v => _readDateTime(v, 'LibraryLoan.approved_at'),
    },
    handedOverAt: switch (json['handed_over_at']) {
      null => null,
      final Object v => _readDateTime(v, 'LibraryLoan.handed_over_at'),
    },
    dueAt: switch (json['due_at']) {
      null => null,
      final Object v => _readDateTime(v, 'LibraryLoan.due_at'),
    },
    orphanedAt: switch (json['orphaned_at']) {
      null => null,
      final Object v => _readDateTime(v, 'LibraryLoan.orphaned_at'),
    },
    endedAt: switch (json['ended_at']) {
      null => null,
      final Object v => _readDateTime(v, 'LibraryLoan.ended_at'),
    },
    callerIsOwner: _readBool(
      json['caller_is_owner'],
      'LibraryLoan.caller_is_owner',
    ),
  );

  final String id;

  final String itemId;

  /// Kalemin adı (kitapta tayfa sözlüğündeki adı).
  final String itemName;

  final LibraryItemKind itemKind;

  /// Kalemin sahibi; hesabı silindiyse yoktur.
  final String? ownerUserId;

  /// Borç alan; hesabı silindiyse yoktur.
  final String? borrowerUserId;

  final LibraryLoanState state;

  final DateTime requestedAt;

  final DateTime? approvedAt;

  final DateTime? handedOverAt;

  /// İade tarihi; yoksa alan yoktur.
  final DateTime? dueAt;

  /// Teslimdeyken taraflardan biri tayfadan ayrıldı; kayıt 30 gün sonra kapanır.
  final DateTime? orphanedAt;

  final DateTime? endedAt;

  /// Çağıran kalemin sahibi mi (değilse borç alandır).
  final bool callerIsOwner;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'item_id': itemId,
    'item_name': itemName,
    'item_kind': itemKind.wire,
    if (ownerUserId case final value?) 'owner_user_id': value,
    if (borrowerUserId case final value?) 'borrower_user_id': value,
    'state': state.wire,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    if (approvedAt case final value?)
      'approved_at': value.toUtc().toIso8601String(),
    if (handedOverAt case final value?)
      'handed_over_at': value.toUtc().toIso8601String(),
    if (dueAt case final value?) 'due_at': value.toUtc().toIso8601String(),
    if (orphanedAt case final value?)
      'orphaned_at': value.toUtc().toIso8601String(),
    if (endedAt case final value?) 'ended_at': value.toUtc().toIso8601String(),
    'caller_is_owner': callerIsOwner,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryLoan &&
          id == other.id &&
          itemId == other.itemId &&
          itemName == other.itemName &&
          itemKind == other.itemKind &&
          ownerUserId == other.ownerUserId &&
          borrowerUserId == other.borrowerUserId &&
          state == other.state &&
          requestedAt == other.requestedAt &&
          approvedAt == other.approvedAt &&
          handedOverAt == other.handedOverAt &&
          dueAt == other.dueAt &&
          orphanedAt == other.orphanedAt &&
          endedAt == other.endedAt &&
          callerIsOwner == other.callerIsOwner;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    itemId,
    itemName,
    itemKind,
    ownerUserId,
    borrowerUserId,
    state,
    requestedAt,
    approvedAt,
    handedOverAt,
    dueAt,
    orphanedAt,
    endedAt,
    callerIsOwner,
  ]);
}

final class LibraryLoanList {
  const LibraryLoanList({required this.loans});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryLoanList.fromJson(Map<String, Object?> json) =>
      LibraryLoanList(
        loans: List<LibraryLoan>.unmodifiable(
          _readList(json['loans'], 'LibraryLoanList.loans').map(
            (Object? e0) =>
                LibraryLoan.fromJson(_readObject(e0, 'LibraryLoanList.loans')),
          ),
        ),
      );

  final List<LibraryLoan> loans;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'loans': <Object?>[for (final e0 in loans) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryLoanList && _deepEquals(loans, other.loans);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(loans)]);
}

enum LibraryLoanState {
  requested('requested'),
  approved('approved'),
  handedOver('handed_over'),
  returned('returned'),
  declined('declined'),
  cancelled('cancelled'),
  closed('closed'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const LibraryLoanState(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('LibraryLoanState.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static LibraryLoanState fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class LibraryQueueEntry {
  const LibraryQueueEntry({required this.userId, required this.rank});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LibraryQueueEntry.fromJson(Map<String, Object?> json) =>
      LibraryQueueEntry(
        userId: _readString(json['user_id'], 'LibraryQueueEntry.user_id'),
        rank: _readInt(json['rank'], 'LibraryQueueEntry.rank'),
      );

  final String userId;

  /// 1 sıradaki.
  final int rank;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'rank': rank,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryQueueEntry &&
          userId == other.userId &&
          rank == other.rank;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, rank]);
}

/// Kısıtlar: varsayılan (sunucu): `going`.
enum ListEventAttendeesStatus {
  going('going'),
  maybe('maybe'),
  notGoing('not_going'),
  waitlist('waitlist'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ListEventAttendeesStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ListEventAttendeesStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ListEventAttendeesStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kısıtlar: varsayılan (sunucu): `incoming`.
enum ListFriendRequestsDirection {
  incoming('incoming'),
  outgoing('outgoing'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ListFriendRequestsDirection(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ListFriendRequestsDirection.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ListFriendRequestsDirection fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kısıtlar: varsayılan (sunucu): `active`.
enum ListMembersStatus {
  active('active'),
  banned('banned'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ListMembersStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ListMembersStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ListMembersStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kısıtlar: varsayılan (sunucu): `open`.
enum ListTayfaReportsStatus {
  open('open'),
  resolved('resolved'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ListTayfaReportsStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ListTayfaReportsStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ListTayfaReportsStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Bir günlük kaydının konumunu kaydı girenin dışında kim görür:
/// `self` kimse; `participants` `going`/`maybe` cevabı verenler,
/// katılımı doğrulananlar, organizatör, moderatör ve yönetici; `tayfa`
/// kaydı gören herkes.
enum LogLocationVisibility {
  self('self'),
  participants('participants'),
  tayfa('tayfa'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const LogLocationVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('LogLocationVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static LogLocationVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Günlük özeti: bir günlük istatistiği (`<tür>.<günlük>.<stat>`,
/// örneğin `birding.sightings.distinct_species`) ve dönem
/// (`this_year` ya da `all_time`).
final class LogSummaryWidgetConfig {
  const LogSummaryWidgetConfig({required this.metricKey, required this.period});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LogSummaryWidgetConfig.fromJson(Map<String, Object?> json) =>
      LogSummaryWidgetConfig(
        metricKey: _readString(
          json['metric_key'],
          'LogSummaryWidgetConfig.metric_key',
        ),
        period: HomeWidgetPeriod.fromWire(
          _readString(json['period'], 'LogSummaryWidgetConfig.period'),
        ),
      );

  /// Kısıtlar: maxLength: 130.
  final String metricKey;

  final HomeWidgetPeriod period;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_key': metricKey,
    'period': period.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogSummaryWidgetConfig &&
          metricKey == other.metricKey &&
          period == other.period;

  @override
  int get hashCode => Object.hashAll(<Object?>[metricKey, period]);
}

final class LogSummaryWidgetData {
  const LogSummaryWidgetData({
    required this.metricKey,
    required this.period,
    this.year,
    required this.value,
    required this.eventCount,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory LogSummaryWidgetData.fromJson(Map<String, Object?> json) =>
      LogSummaryWidgetData(
        metricKey: _readString(
          json['metric_key'],
          'LogSummaryWidgetData.metric_key',
        ),
        period: HomeWidgetPeriod.fromWire(
          _readString(json['period'], 'LogSummaryWidgetData.period'),
        ),
        year: switch (json['year']) {
          null => null,
          final Object v => _readInt(v, 'LogSummaryWidgetData.year'),
        },
        value: _readDouble(json['value'], 'LogSummaryWidgetData.value'),
        eventCount: _readInt(
          json['event_count'],
          'LogSummaryWidgetData.event_count',
        ),
      );

  final String metricKey;

  final HomeWidgetPeriod period;

  /// Europe/Istanbul yılı; tüm zamanlarda yoktur.
  final int? year;

  final double value;

  final int eventCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_key': metricKey,
    'period': period.wire,
    if (year case final value?) 'year': value,
    'value': value,
    'event_count': eventCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogSummaryWidgetData &&
          metricKey == other.metricKey &&
          period == other.period &&
          year == other.year &&
          value == other.value &&
          eventCount == other.eventCount;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[metricKey, period, year, value, eventCount]);
}

final class Material {
  const Material({
    required this.id,
    required this.kind,
    required this.title,
    this.url,
    this.domain,
    this.photoUploadIds,
    required this.subjectKey,
    this.topicKey,
    this.authorUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.callerCanEdit,
    required this.callerCanDelete,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Material.fromJson(Map<String, Object?> json) => Material(
    id: _readString(json['id'], 'Material.id'),
    kind: MaterialKind.fromWire(_readString(json['kind'], 'Material.kind')),
    title: _readString(json['title'], 'Material.title'),
    url: switch (json['url']) {
      null => null,
      final Object v => _readString(v, 'Material.url'),
    },
    domain: switch (json['domain']) {
      null => null,
      final Object v => _readString(v, 'Material.domain'),
    },
    photoUploadIds: switch (json['photo_upload_ids']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(
          v,
          'Material.photo_upload_ids',
        ).map((Object? e0) => _readString(e0, 'Material.photo_upload_ids')),
      ),
    },
    subjectKey: _readString(json['subject_key'], 'Material.subject_key'),
    topicKey: switch (json['topic_key']) {
      null => null,
      final Object v => _readString(v, 'Material.topic_key'),
    },
    authorUserId: switch (json['author_user_id']) {
      null => null,
      final Object v => _readString(v, 'Material.author_user_id'),
    },
    createdAt: _readDateTime(json['created_at'], 'Material.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Material.updated_at'),
    callerCanEdit: _readBool(
      json['caller_can_edit'],
      'Material.caller_can_edit',
    ),
    callerCanDelete: _readBool(
      json['caller_can_delete'],
      'Material.caller_can_delete',
    ),
  );

  final String id;

  final MaterialKind kind;

  /// 1–80 karakter, tek satır.
  final String title;

  /// Yalnızca `link`; sunucunun normalleştirdiği https adresi (en
  /// fazla 500 karakter). Sunucu bu adresi hiç açmadı; istemci
  /// önizleme çekmez, açmadan önce uyarır.
  final String? url;

  /// Yalnızca `link`; sunucunun adresten ayrıştırdığı alan adı (küçük
  /// harf; Türkçe karakterli alan adı punycode). Bağlantıyla birlikte
  /// gösterilir.
  final String? domain;

  /// Yalnızca `note_photo`; yazarın fotoğrafları (`material_note`
  /// yüklemesi), sırasıyla; adreslerini `POST /v1/media/urls` verir.
  /// Yazarın hesabı silinince boşalabilir.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<String>? photoUploadIds;

  /// Ders anahtarı (her zaman var); etiket sonradan emekliye ayrılmış olabilir.
  final String subjectKey;

  /// Konu anahtarı; yoksa alan yoktur.
  final String? topicKey;

  /// Yazar; hesabı silindiyse alan yoktur.
  final String? authorUserId;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// Çağıran şimdi düzenleyebilir mi (yazarı).
  final bool callerCanEdit;

  /// Çağıran şimdi silebilir mi (yazarı, moderatör).
  final bool callerCanDelete;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.wire,
    'title': title,
    if (url case final value?) 'url': value,
    if (domain case final value?) 'domain': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
    'subject_key': subjectKey,
    if (topicKey case final value?) 'topic_key': value,
    if (authorUserId case final value?) 'author_user_id': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'caller_can_edit': callerCanEdit,
    'caller_can_delete': callerCanDelete,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Material &&
          id == other.id &&
          kind == other.kind &&
          title == other.title &&
          url == other.url &&
          domain == other.domain &&
          _deepEquals(photoUploadIds, other.photoUploadIds) &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey &&
          authorUserId == other.authorUserId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          callerCanEdit == other.callerCanEdit &&
          callerCanDelete == other.callerCanDelete;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    kind,
    title,
    url,
    domain,
    _deepHash(photoUploadIds),
    subjectKey,
    topicKey,
    authorUserId,
    createdAt,
    updatedAt,
    callerCanEdit,
    callerCanDelete,
  ]);
}

final class MaterialCreateRequest {
  const MaterialCreateRequest({
    required this.kind,
    required this.title,
    this.url,
    this.photoUploadIds,
    required this.subjectKey,
    this.topicKey,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MaterialCreateRequest.fromJson(Map<String, Object?> json) =>
      MaterialCreateRequest(
        kind: MaterialCreateRequestKind.fromWire(
          _readString(json['kind'], 'MaterialCreateRequest.kind'),
        ),
        title: _readString(json['title'], 'MaterialCreateRequest.title'),
        url: switch (json['url']) {
          null => null,
          final Object v => _readString(v, 'MaterialCreateRequest.url'),
        },
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'MaterialCreateRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'MaterialCreateRequest.photo_upload_ids'),
            ),
          ),
        },
        subjectKey: _readString(
          json['subject_key'],
          'MaterialCreateRequest.subject_key',
        ),
        topicKey: switch (json['topic_key']) {
          null => null,
          final Object v => _readString(v, 'MaterialCreateRequest.topic_key'),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'MaterialCreateRequest.client_request_id',
        ),
      );

  final MaterialCreateRequestKind kind;

  /// Kısıtlar: minLength: 1; maxLength: 1024.
  final String title;

  /// Yalnızca `link`; zorunlu.
  ///
  /// Kısıtlar: maxLength: 2048.
  final String? url;

  /// Yalnızca `note_photo`; 1–3 fotoğraf.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<String>? photoUploadIds;

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String subjectKey;

  /// İsteğe bağlı; dersin altında bir konu.
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? topicKey;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    'title': title,
    if (url case final value?) 'url': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
    'subject_key': subjectKey,
    if (topicKey case final value?) 'topic_key': value,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialCreateRequest &&
          kind == other.kind &&
          title == other.title &&
          url == other.url &&
          _deepEquals(photoUploadIds, other.photoUploadIds) &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    kind,
    title,
    url,
    _deepHash(photoUploadIds),
    subjectKey,
    topicKey,
    clientRequestId,
  ]);
}

enum MaterialCreateRequestKind {
  link('link'),
  notePhoto('note_photo'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MaterialCreateRequestKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('MaterialCreateRequestKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MaterialCreateRequestKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `link` https bağlantı, `note_photo` kişinin kendi not fotoğrafları. Tanınmayan değer `unknown`.
enum MaterialKind {
  link('link'),
  notePhoto('note_photo'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const MaterialKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('MaterialKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MaterialKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class MaterialList {
  const MaterialList({
    required this.materials,
    this.nextPageToken,
    required this.callerCanAdd,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MaterialList.fromJson(Map<String, Object?> json) => MaterialList(
    materials: List<Material>.unmodifiable(
      _readList(json['materials'], 'MaterialList.materials').map(
        (Object? e0) =>
            Material.fromJson(_readObject(e0, 'MaterialList.materials')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'MaterialList.next_page_token'),
    },
    callerCanAdd: _readBool(
      json['caller_can_add'],
      'MaterialList.caller_can_add',
    ),
  );

  final List<Material> materials;

  /// Yoksa son sayfa.
  final String? nextPageToken;

  /// Çağıran şimdi materyal ekleyebilir mi.
  final bool callerCanAdd;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'materials': <Object?>[for (final e0 in materials) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
    'caller_can_add': callerCanAdd,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialList &&
          _deepEquals(materials, other.materials) &&
          nextPageToken == other.nextPageToken &&
          callerCanAdd == other.callerCanAdd;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(materials),
    nextPageToken,
    callerCanAdd,
  ]);
}

final class MaterialUpdateRequest {
  const MaterialUpdateRequest({
    required this.title,
    this.url,
    this.photoUploadIds,
    required this.subjectKey,
    this.topicKey,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MaterialUpdateRequest.fromJson(Map<String, Object?> json) =>
      MaterialUpdateRequest(
        title: _readString(json['title'], 'MaterialUpdateRequest.title'),
        url: switch (json['url']) {
          null => null,
          final Object v => _readString(v, 'MaterialUpdateRequest.url'),
        },
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'MaterialUpdateRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'MaterialUpdateRequest.photo_upload_ids'),
            ),
          ),
        },
        subjectKey: _readString(
          json['subject_key'],
          'MaterialUpdateRequest.subject_key',
        ),
        topicKey: switch (json['topic_key']) {
          null => null,
          final Object v => _readString(v, 'MaterialUpdateRequest.topic_key'),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 1024.
  final String title;

  /// `link` için zorunlu; `note_photo` için verilmez.
  ///
  /// Kısıtlar: maxLength: 2048.
  final String? url;

  /// `note_photo` için 1–3 fotoğraf (kalanlar ve yeniler); listede olmayan silinir.
  ///
  /// Kısıtlar: maxItems: 3.
  final List<String>? photoUploadIds;

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String subjectKey;

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? topicKey;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    if (url case final value?) 'url': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
    'subject_key': subjectKey,
    if (topicKey case final value?) 'topic_key': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialUpdateRequest &&
          title == other.title &&
          url == other.url &&
          _deepEquals(photoUploadIds, other.photoUploadIds) &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    title,
    url,
    _deepHash(photoUploadIds),
    subjectKey,
    topicKey,
  ]);
}

final class MediaUrls {
  const MediaUrls({
    required this.uploadId,
    this.previewUrl,
    this.previewContentType,
    required this.fullUrl,
    required this.fullContentType,
    required this.width,
    required this.height,
    required this.expiresAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MediaUrls.fromJson(Map<String, Object?> json) => MediaUrls(
    uploadId: _readString(json['upload_id'], 'MediaUrls.upload_id'),
    previewUrl: switch (json['preview_url']) {
      null => null,
      final Object v => _readString(v, 'MediaUrls.preview_url'),
    },
    previewContentType: switch (json['preview_content_type']) {
      null => null,
      final Object v => MediaUrlsPreviewContentType.fromWire(
        _readString(v, 'MediaUrls.preview_content_type'),
      ),
    },
    fullUrl: _readString(json['full_url'], 'MediaUrls.full_url'),
    fullContentType: MediaUrlsFullContentType.fromWire(
      _readString(json['full_content_type'], 'MediaUrls.full_content_type'),
    ),
    width: _readInt(json['width'], 'MediaUrls.width'),
    height: _readInt(json['height'], 'MediaUrls.height'),
    expiresAt: _readDateTime(json['expires_at'], 'MediaUrls.expires_at'),
  );

  final String uploadId;

  /// Taşıyıcı link; log'a yazılmaz. `dm_attachment`'ta yoktur.
  final String? previewUrl;

  final MediaUrlsPreviewContentType? previewContentType;

  /// `dm_attachment`'ta şifreli blob.
  final String fullUrl;

  final MediaUrlsFullContentType fullContentType;

  /// Full varyantın genişliği
  final int width;

  final int height;

  /// Linklerin geçerliliği (1 saat).
  final DateTime expiresAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'upload_id': uploadId,
    if (previewUrl case final value?) 'preview_url': value,
    if (previewContentType case final value?)
      'preview_content_type': value.wire,
    'full_url': fullUrl,
    'full_content_type': fullContentType.wire,
    'width': width,
    'height': height,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaUrls &&
          uploadId == other.uploadId &&
          previewUrl == other.previewUrl &&
          previewContentType == other.previewContentType &&
          fullUrl == other.fullUrl &&
          fullContentType == other.fullContentType &&
          width == other.width &&
          height == other.height &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    uploadId,
    previewUrl,
    previewContentType,
    fullUrl,
    fullContentType,
    width,
    height,
    expiresAt,
  ]);
}

enum MediaUrlsFullContentType {
  imageJpeg('image/jpeg'),
  imageWebp('image/webp'),
  applicationOctetStream('application/octet-stream'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MediaUrlsFullContentType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('MediaUrlsFullContentType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MediaUrlsFullContentType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class MediaUrlsList {
  const MediaUrlsList({required this.media});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MediaUrlsList.fromJson(Map<String, Object?> json) => MediaUrlsList(
    media: List<MediaUrls>.unmodifiable(
      _readList(json['media'], 'MediaUrlsList.media').map(
        (Object? e0) =>
            MediaUrls.fromJson(_readObject(e0, 'MediaUrlsList.media')),
      ),
    ),
  );

  final List<MediaUrls> media;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'media': <Object?>[for (final e0 in media) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaUrlsList && _deepEquals(media, other.media);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(media)]);
}

enum MediaUrlsPreviewContentType {
  imageJpeg('image/jpeg'),
  imageWebp('image/webp'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MediaUrlsPreviewContentType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('MediaUrlsPreviewContentType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MediaUrlsPreviewContentType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class MediaUrlsRequest {
  const MediaUrlsRequest({required this.uploadIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MediaUrlsRequest.fromJson(Map<String, Object?> json) =>
      MediaUrlsRequest(
        uploadIds: List<String>.unmodifiable(
          _readList(
            json['upload_ids'],
            'MediaUrlsRequest.upload_ids',
          ).map((Object? e0) => _readString(e0, 'MediaUrlsRequest.upload_ids')),
        ),
      );

  /// Kısıtlar: minItems: 1; maxItems: 100; uniqueItems: true.
  final List<String> uploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'upload_ids': <Object?>[for (final e0 in uploadIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaUrlsRequest && _deepEquals(uploadIds, other.uploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(uploadIds)]);
}

/// Çağıranın kendi garajı (#272).
final class MemberGarage {
  const MemberGarage({required this.vehicles, required this.callerCanAdd});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MemberGarage.fromJson(Map<String, Object?> json) => MemberGarage(
    vehicles: List<GarageVehicle>.unmodifiable(
      _readList(json['vehicles'], 'MemberGarage.vehicles').map(
        (Object? e0) =>
            GarageVehicle.fromJson(_readObject(e0, 'MemberGarage.vehicles')),
      ),
    ),
    callerCanAdd: _readBool(
      json['caller_can_add'],
      'MemberGarage.caller_can_add',
    ),
  );

  /// Eklenme sırasıyla; en fazla 10.
  final List<GarageVehicle> vehicles;

  /// 10'dan az araç var mı.
  final bool callerCanAdd;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'vehicles': <Object?>[for (final e0 in vehicles) e0.toJson()],
    'caller_can_add': callerCanAdd,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberGarage &&
          _deepEquals(vehicles, other.vehicles) &&
          callerCanAdd == other.callerCanAdd;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(vehicles), callerCanAdd]);
}

final class MemberList {
  const MemberList({required this.members, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MemberList.fromJson(Map<String, Object?> json) => MemberList(
    members: List<Membership>.unmodifiable(
      _readList(json['members'], 'MemberList.members').map(
        (Object? e0) =>
            Membership.fromJson(_readObject(e0, 'MemberList.members')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'MemberList.next_page_token'),
    },
  );

  final List<Membership> members;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'members': <Object?>[for (final e0 in members) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberList &&
          _deepEquals(members, other.members) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(members), nextPageToken]);
}

final class Membership {
  const Membership({
    required this.tayfaId,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.mutedUntil,
    this.joinedViaDiscover,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Membership.fromJson(Map<String, Object?> json) => Membership(
    tayfaId: _readString(json['tayfa_id'], 'Membership.tayfa_id'),
    userId: _readString(json['user_id'], 'Membership.user_id'),
    role: Role.fromWire(_readString(json['role'], 'Membership.role')),
    status: MembershipStatus.fromWire(
      _readString(json['status'], 'Membership.status'),
    ),
    joinedAt: switch (json['joined_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Membership.joined_at'),
    },
    mutedUntil: switch (json['muted_until']) {
      null => null,
      final Object v => _readDateTime(v, 'Membership.muted_until'),
    },
    joinedViaDiscover: switch (json['joined_via_discover']) {
      null => null,
      final Object v => _readBool(v, 'Membership.joined_via_discover'),
    },
  );

  final String tayfaId;

  final String userId;

  final Role role;

  final MembershipStatus status;

  /// Üyelik etkin olduğunda.
  final DateTime? joinedAt;

  /// Susturma bitişi; yalnızca üyenin kendisine, moderatöre ve yöneticiye döner.
  final DateTime? mutedUntil;

  /// Kişi Keşfet'ten katılım istedi (ADR-0033). Yalnızca moderatör ve
  /// yöneticiye döner; diğer üyelere hiç dönmez.
  final bool? joinedViaDiscover;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'user_id': userId,
    'role': role.wire,
    'status': status.wire,
    if (joinedAt case final value?)
      'joined_at': value.toUtc().toIso8601String(),
    if (mutedUntil case final value?)
      'muted_until': value.toUtc().toIso8601String(),
    if (joinedViaDiscover case final value?) 'joined_via_discover': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Membership &&
          tayfaId == other.tayfaId &&
          userId == other.userId &&
          role == other.role &&
          status == other.status &&
          joinedAt == other.joinedAt &&
          mutedUntil == other.mutedUntil &&
          joinedViaDiscover == other.joinedViaDiscover;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    tayfaId,
    userId,
    role,
    status,
    joinedAt,
    mutedUntil,
    joinedViaDiscover,
  ]);
}

enum MembershipStatus {
  invited('invited'),
  pending('pending'),
  active('active'),
  banned('banned'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MembershipStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('MembershipStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MembershipStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Şikâyet, tayfa moderatörünün gördüğü haliyle. Şikâyet edenin kimliği,
/// platforma yükselme ve yaş için alan yoktur. `priority:
/// minor_involved` taraflardan birinin (şikâyet eden ya da şikâyet
/// edilen) şikâyet anında 18 yaşından küçük olduğunu ya da bunun
/// bilinmediğini söyler; hangisi olduğu ve kimsenin yaşı gösterilmez.
final class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.tayfaId,
    required this.targetType,
    required this.targetId,
    this.subjectUserId,
    required this.reason,
    this.description,
    required this.priority,
    required this.status,
    this.resolution,
    this.handledByUserId,
    required this.createdAt,
    this.resolvedAt,
    this.channelId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ModerationReport.fromJson(
    Map<String, Object?> json,
  ) => ModerationReport(
    id: _readString(json['id'], 'ModerationReport.id'),
    tayfaId: _readString(json['tayfa_id'], 'ModerationReport.tayfa_id'),
    targetType: ReportTargetType.fromWire(
      _readString(json['target_type'], 'ModerationReport.target_type'),
    ),
    targetId: _readString(json['target_id'], 'ModerationReport.target_id'),
    subjectUserId: switch (json['subject_user_id']) {
      null => null,
      final Object v => _readString(v, 'ModerationReport.subject_user_id'),
    },
    reason: ReportReason.fromWire(
      _readString(json['reason'], 'ModerationReport.reason'),
    ),
    description: switch (json['description']) {
      null => null,
      final Object v => _readString(v, 'ModerationReport.description'),
    },
    priority: ModerationReportPriority.fromWire(
      _readString(json['priority'], 'ModerationReport.priority'),
    ),
    status: ModerationReportStatus.fromWire(
      _readString(json['status'], 'ModerationReport.status'),
    ),
    resolution: switch (json['resolution']) {
      null => null,
      final Object v => ModerationReportResolution.fromWire(
        _readString(v, 'ModerationReport.resolution'),
      ),
    },
    handledByUserId: switch (json['handled_by_user_id']) {
      null => null,
      final Object v => _readString(v, 'ModerationReport.handled_by_user_id'),
    },
    createdAt: _readDateTime(json['created_at'], 'ModerationReport.created_at'),
    resolvedAt: switch (json['resolved_at']) {
      null => null,
      final Object v => _readDateTime(v, 'ModerationReport.resolved_at'),
    },
    channelId: switch (json['channel_id']) {
      null => null,
      final Object v => _readString(v, 'ModerationReport.channel_id'),
    },
  );

  final String id;

  final String tayfaId;

  final ReportTargetType targetType;

  final String targetId;

  /// Şikâyet edilen üye ya da içeriğin yazarı; hesap silindiyse ve anonim etkinlik sorusunda (`event_question`) yoktur. Yazarı gizli şikâyet `member_sanctioned` ile kapatılamaz.
  final String? subjectUserId;

  final ReportReason reason;

  final String? description;

  final ModerationReportPriority priority;

  final ModerationReportStatus status;

  /// Yalnızca çözülmüş şikâyette.
  final ModerationReportResolution? resolution;

  /// Çözen moderatör; açıkken ya da hesap silindiyse yoktur.
  final String? handledByUserId;

  final DateTime createdAt;

  final DateTime? resolvedAt;

  /// Yalnızca `channel_message`: mesajın kanalı (mesajı açmak için).
  /// Kanalı okuyamayan moderatör (içinde olmadığı etkinlik ya da seçili
  /// kişi kanalı) mesajı açamaz ve gizleyemez.
  final String? channelId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    'target_type': targetType.wire,
    'target_id': targetId,
    if (subjectUserId case final value?) 'subject_user_id': value,
    'reason': reason.wire,
    if (description case final value?) 'description': value,
    'priority': priority.wire,
    'status': status.wire,
    if (resolution case final value?) 'resolution': value.wire,
    if (handledByUserId case final value?) 'handled_by_user_id': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (resolvedAt case final value?)
      'resolved_at': value.toUtc().toIso8601String(),
    if (channelId case final value?) 'channel_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModerationReport &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          targetType == other.targetType &&
          targetId == other.targetId &&
          subjectUserId == other.subjectUserId &&
          reason == other.reason &&
          description == other.description &&
          priority == other.priority &&
          status == other.status &&
          resolution == other.resolution &&
          handledByUserId == other.handledByUserId &&
          createdAt == other.createdAt &&
          resolvedAt == other.resolvedAt &&
          channelId == other.channelId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    targetType,
    targetId,
    subjectUserId,
    reason,
    description,
    priority,
    status,
    resolution,
    handledByUserId,
    createdAt,
    resolvedAt,
    channelId,
  ]);
}

final class ModerationReportList {
  const ModerationReportList({required this.reports, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ModerationReportList.fromJson(Map<String, Object?> json) =>
      ModerationReportList(
        reports: List<ModerationReport>.unmodifiable(
          _readList(json['reports'], 'ModerationReportList.reports').map(
            (Object? e0) => ModerationReport.fromJson(
              _readObject(e0, 'ModerationReportList.reports'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(
            v,
            'ModerationReportList.next_page_token',
          ),
        },
      );

  final List<ModerationReport> reports;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'reports': <Object?>[for (final e0 in reports) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModerationReportList &&
          _deepEquals(reports, other.reports) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(reports), nextPageToken]);
}

enum ModerationReportPriority {
  normal('normal'),
  minorInvolved('minor_involved'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ModerationReportPriority(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ModerationReportPriority.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ModerationReportPriority fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Yalnızca çözülmüş şikâyette.
enum ModerationReportResolution {
  contentRemoved('content_removed'),
  memberSanctioned('member_sanctioned'),
  dismissed('dismissed'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ModerationReportResolution(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ModerationReportResolution.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ModerationReportResolution fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

enum ModerationReportStatus {
  open('open'),
  resolved('resolved'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ModerationReportStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ModerationReportStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ModerationReportStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `daily` günün içeriğidir (#269). `library` ortak kütüphanedir (#270). `question_pool` Eğitim soru havuzudur (#271): soruları `pool: question_pool` ile Soru-Cevap uçlarından, ana sayfa bileşeni ve `pool_link` etkinlik bileşeni. `materials` Eğitim materyal kütüphanesidir (#261). `garage` üye garajıdır (#272): üyelerin bu tayfada gösterdiği garajlar ve ana sayfa bileşeni.
enum Module {
  announcements('announcements'),
  events('events'),
  qa('qa'),
  polls('polls'),
  daily('daily'),
  library_('library'),
  questionPool('question_pool'),
  materials('materials'),
  garage('garage'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const Module(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire => _wire ?? (throw StateError('Module.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static Module fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class ModuleUpdate {
  const ModuleUpdate({required this.enabled});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ModuleUpdate.fromJson(Map<String, Object?> json) =>
      ModuleUpdate(enabled: _readBool(json['enabled'], 'ModuleUpdate.enabled'));

  final bool enabled;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'enabled': enabled};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleUpdate && enabled == other.enabled;

  @override
  int get hashCode => Object.hashAll(<Object?>[enabled]);
}

final class MuteRequest {
  const MuteRequest({required this.mutedUntil});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MuteRequest.fromJson(Map<String, Object?> json) => MuteRequest(
    mutedUntil: _readDateTime(json['muted_until'], 'MuteRequest.muted_until'),
  );

  /// Şimdiden sonra, en fazla 30 gün ileri.
  final DateTime mutedUntil;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'muted_until': mutedUntil.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuteRequest && mutedUntil == other.mutedUntil;

  @override
  int get hashCode => Object.hashAll(<Object?>[mutedUntil]);
}

/// Şikâyet, şikâyet eden kişinin gördüğü haliyle. Hangi işlemin yapıldığı
/// ve kimin çözdüğü gösterilmez; yalnızca sonuç (`outcome`) vardır.
final class MyReport {
  const MyReport({
    required this.id,
    this.tayfaId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    this.outcome,
    required this.createdAt,
    this.resolvedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MyReport.fromJson(Map<String, Object?> json) => MyReport(
    id: _readString(json['id'], 'MyReport.id'),
    tayfaId: switch (json['tayfa_id']) {
      null => null,
      final Object v => _readString(v, 'MyReport.tayfa_id'),
    },
    targetType: ReportTargetType.fromWire(
      _readString(json['target_type'], 'MyReport.target_type'),
    ),
    targetId: _readString(json['target_id'], 'MyReport.target_id'),
    reason: ReportReason.fromWire(
      _readString(json['reason'], 'MyReport.reason'),
    ),
    description: switch (json['description']) {
      null => null,
      final Object v => _readString(v, 'MyReport.description'),
    },
    status: MyReportStatus.fromWire(
      _readString(json['status'], 'MyReport.status'),
    ),
    outcome: switch (json['outcome']) {
      null => null,
      final Object v => MyReportOutcome.fromWire(
        _readString(v, 'MyReport.outcome'),
      ),
    },
    createdAt: _readDateTime(json['created_at'], 'MyReport.created_at'),
    resolvedAt: switch (json['resolved_at']) {
      null => null,
      final Object v => _readDateTime(v, 'MyReport.resolved_at'),
    },
  );

  final String id;

  /// Birebir mesaj şikâyetinde ve kişi profilinden yapılan kullanıcı şikâyetinde yoktur.
  final String? tayfaId;

  final ReportTargetType targetType;

  final String targetId;

  final ReportReason reason;

  final String? description;

  final MyReportStatus status;

  /// Yalnızca çözülmüş şikâyette.
  final MyReportOutcome? outcome;

  final DateTime createdAt;

  final DateTime? resolvedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (tayfaId case final value?) 'tayfa_id': value,
    'target_type': targetType.wire,
    'target_id': targetId,
    'reason': reason.wire,
    if (description case final value?) 'description': value,
    'status': status.wire,
    if (outcome case final value?) 'outcome': value.wire,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (resolvedAt case final value?)
      'resolved_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyReport &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          targetType == other.targetType &&
          targetId == other.targetId &&
          reason == other.reason &&
          description == other.description &&
          status == other.status &&
          outcome == other.outcome &&
          createdAt == other.createdAt &&
          resolvedAt == other.resolvedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    targetType,
    targetId,
    reason,
    description,
    status,
    outcome,
    createdAt,
    resolvedAt,
  ]);
}

final class MyReportList {
  const MyReportList({required this.reports, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MyReportList.fromJson(Map<String, Object?> json) => MyReportList(
    reports: List<MyReport>.unmodifiable(
      _readList(json['reports'], 'MyReportList.reports').map(
        (Object? e0) =>
            MyReport.fromJson(_readObject(e0, 'MyReportList.reports')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'MyReportList.next_page_token'),
    },
  );

  final List<MyReport> reports;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'reports': <Object?>[for (final e0 in reports) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyReportList &&
          _deepEquals(reports, other.reports) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(reports), nextPageToken]);
}

/// Yalnızca çözülmüş şikâyette.
enum MyReportOutcome {
  actionTaken('action_taken'),
  dismissed('dismissed'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MyReportOutcome(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('MyReportOutcome.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MyReportOutcome fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

enum MyReportStatus {
  open('open'),
  resolved('resolved'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MyReportStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('MyReportStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MyReportStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class MyTayfa {
  const MyTayfa({
    required this.tayfaId,
    required this.name,
    required this.kind,
    required this.role,
    required this.status,
    this.tayfa,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MyTayfa.fromJson(Map<String, Object?> json) => MyTayfa(
    tayfaId: _readString(json['tayfa_id'], 'MyTayfa.tayfa_id'),
    name: _readString(json['name'], 'MyTayfa.name'),
    kind: TayfaKind.fromWire(_readString(json['kind'], 'MyTayfa.kind')),
    role: Role.fromWire(_readString(json['role'], 'MyTayfa.role')),
    status: MyTayfaStatus.fromWire(
      _readString(json['status'], 'MyTayfa.status'),
    ),
    tayfa: switch (json['tayfa']) {
      null => null,
      final Object v => Tayfa.fromJson(_readObject(v, 'MyTayfa.tayfa')),
    },
  );

  final String tayfaId;

  final String name;

  final TayfaKind kind;

  final Role role;

  final MyTayfaStatus status;

  /// Yalnızca etkin üyelikte.
  final Tayfa? tayfa;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'name': name,
    'kind': kind.wire,
    'role': role.wire,
    'status': status.wire,
    if (tayfa case final value?) 'tayfa': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyTayfa &&
          tayfaId == other.tayfaId &&
          name == other.name &&
          kind == other.kind &&
          role == other.role &&
          status == other.status &&
          tayfa == other.tayfa;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[tayfaId, name, kind, role, status, tayfa]);
}

final class MyTayfaList {
  const MyTayfaList({required this.tayfas, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory MyTayfaList.fromJson(Map<String, Object?> json) => MyTayfaList(
    tayfas: List<MyTayfa>.unmodifiable(
      _readList(json['tayfas'], 'MyTayfaList.tayfas').map(
        (Object? e0) => MyTayfa.fromJson(_readObject(e0, 'MyTayfaList.tayfas')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'MyTayfaList.next_page_token'),
    },
  );

  final List<MyTayfa> tayfas;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfas': <Object?>[for (final e0 in tayfas) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyTayfaList &&
          _deepEquals(tayfas, other.tayfas) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(tayfas), nextPageToken]);
}

enum MyTayfaStatus {
  active('active'),
  pending('pending'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const MyTayfaStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('MyTayfaStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static MyTayfaStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Bildirim yalnızca kimlik taşır; başlık, gövde, yer, isim yoktur.
/// İstemci `target_type` ve `target_id` ile içeriği ilgili uçtan çeker.
final class Notification {
  const Notification({
    required this.id,
    required this.type,
    this.tayfaId,
    this.actorId,
    required this.targetType,
    required this.targetId,
    this.questionId,
    this.subjectUserId,
    this.warningReason,
    this.unreadCount,
    this.resolution,
    required this.read,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Notification.fromJson(Map<String, Object?> json) => Notification(
    id: _readString(json['id'], 'Notification.id'),
    type: NotificationType.fromWire(
      _readString(json['type'], 'Notification.type'),
    ),
    tayfaId: switch (json['tayfa_id']) {
      null => null,
      final Object v => _readString(v, 'Notification.tayfa_id'),
    },
    actorId: switch (json['actor_id']) {
      null => null,
      final Object v => _readString(v, 'Notification.actor_id'),
    },
    targetType: NotificationTargetType.fromWire(
      _readString(json['target_type'], 'Notification.target_type'),
    ),
    targetId: _readString(json['target_id'], 'Notification.target_id'),
    questionId: switch (json['question_id']) {
      null => null,
      final Object v => _readString(v, 'Notification.question_id'),
    },
    subjectUserId: switch (json['subject_user_id']) {
      null => null,
      final Object v => _readString(v, 'Notification.subject_user_id'),
    },
    warningReason: switch (json['warning_reason']) {
      null => null,
      final Object v => NotificationWarningReason.fromWire(
        _readString(v, 'Notification.warning_reason'),
      ),
    },
    unreadCount: switch (json['unread_count']) {
      null => null,
      final Object v => _readInt(v, 'Notification.unread_count'),
    },
    resolution: switch (json['resolution']) {
      null => null,
      final Object v => NotificationResolution.fromWire(
        _readString(v, 'Notification.resolution'),
      ),
    },
    read: _readBool(json['read'], 'Notification.read'),
    createdAt: _readDateTime(json['created_at'], 'Notification.created_at'),
  );

  final String id;

  /// `event_created` (yeni etkinlik), `event_updated` ve
  /// `event_cancelled` (katıldığınız etkinlik değişti/iptal edildi),
  /// `rsvp_promoted` (bekleme listesinden katılımcılara geçtiniz),
  /// `announcement`, `answer_received` (sorunuza cevap),
  /// `join_request` (yönetici/moderatörlere başvuru),
  /// `join_approved` (başvurunuz onaylandı),
  /// `tayfa_deletion_requested` (yönetici/moderatörlere silme talebi),
  /// `tayfa_warned` (hareketsiz tayfa 7 gün içinde arşivlenecek;
  /// `warning_reason` var), `tayfa_archived`, `tayfa_suspended` ve `tayfa_unsuspended` (platform askısı; gerekçe tayfa ayrıntısında), `hike_overdue`
  /// (yürüyüşçü zamanında dönmedi; `subject_user_id` yürüyüşçüdür,
  /// sessize alma bu bildirimi engellemez), `friend_request` (size
  /// arkadaşlık isteği; `target_id` isteyen kişi), `friend_accepted`
  /// (isteğiniz kabul edildi; `target_id` yeni arkadaşınız),
  /// `tayfa_invitation` (bir arkadaşınız sizi tayfaya davet etti;
  /// hedef tayfa), `report_resolved` (şikâyetiniz çözüldü; hedef
  /// `report`, `actor_id` hiçbir zaman yoktur; sonucu
  /// `GET /v1/me/reports/{report_id}` verir). İki arkadaşlık bildirimi
  /// bir tayfayla ilgili değildir, `tayfa_id` yoktur. `dm_request`
  /// (size mesaj isteği) ve `dm_message` (yeni birebir mesaj;
  /// konuşma okunana kadar konuşma başına tek bildirim) yalnızca
  /// "yeni" bilgisi taşır: hedef `dm_conversation`, `actor_id` ve
  /// `tayfa_id` yoktur, içerik de gönderen de yazılmaz; okunmamış
  /// mesaj sayısını `unread_count` taşır. `data_export_ready` (KVKK
  /// veri dışa aktarmanız 7 gün indirilebilir; hedef `data_export`,
  /// `tayfa_id` ve `actor_id` yoktur; push çeviri anahtarları
  /// `push_data_export_ready_title` ve `push_data_export_ready_body`).
  /// `friend_suggestion` (arkadaş önerisi; `target_id` önerilen kişi,
  /// `tayfa_id` ve `actor_id` yoktur; yalnızca uygulama içi, push
  /// gitmez; açık öneriler `GET /v1/me/friend-suggestions`).
  /// `safety_alert` (#210, ADR-0033): sizi güvenlik kişisi seçen
  /// `target_id` (hedef `user`) etkinliğin bitişi ve toleransı geçtiği
  /// halde "Döndüm" demedi; `tayfa_id` ve `actor_id` yoktur, içerik ve
  /// konum taşımaz; etkinliği `GET /v1/me/safety-shares` verir.
  /// Susturma uygulanmaz, push gider.
  /// `celebration` (#255): organizatör (`actor_id`) hedef etkinliğin
  /// bir kutlama bileşeninde kazananı ilan etti; kutlama başına bir
  /// kez, tayfanın ilan eden dışındaki etkin üyelerine. Kazananı
  /// adlandırmaz; kutlamayı bileşenin ucu verir. Yalnızca uygulama
  /// içi, push gitmez.
  /// `badge_earned` (#258, ADR-0039 §4): bir rozet kazanıldı; rozeti
  /// adlandırmaz, `actor_id` yoktur. Kişisel rozette alıcı rozeti
  /// kazanan kişidir, hedef `user` kendisidir (kendi profilinizi
  /// açın) ve `tayfa_id` yoktur; tayfa rozetinde alıcılar tayfanın
  /// yönetici ve moderatörleridir, hedef `tayfa`'dır. Yalnızca
  /// uygulama içi, push gitmez.
  /// `now_started` (#265, ADR-0038 §4): organizatör (`actor_id`)
  /// hedef etkinliği Şimdi başlat ile açtı. Tayfa etkinliğinde
  /// alıcılar tayfanın etkin üyeleridir (tayfa başına günde en fazla
  /// 3); anlık etkinlikte organizatörün seçtiği arkadaşlardır ve
  /// bildirim bir davettir: `tayfa_id` anlık etkinliğin tayfasıdır,
  /// daveti `GET /v1/me/invitations` gösterir, kabul edince etkin üye
  /// olursunuz. Başlık, tür, yer ya da ad taşımaz; push yalnızca
  /// `push_now_started_title` / `push_now_started_body` anahtarlarıdır.
  /// Tayfa seviyesi `none` ya da tayfanın şimdi tercihi (`tayfa_now`)
  /// `none` ise push gitmez.
  /// `library_due` (#270, ADR-0040 §1): ödüncün iade tarihi geçti;
  /// borç alana tek hatırlatma. `library_loan_orphaned`: teslim
  /// edilmiş bir ödünçte taraflardan biri tayfadan ayrıldı; iki tarafa
  /// (ayrılana da) uyarı, kayıt 30 gün sonra kapanır. İkisinde de hedef
  /// ödüncün tayfasıdır (`tayfa`), `actor_id` yoktur; eşyayı ve kişileri
  /// adlandırmaz, ödünçleri `GET /v1/tayfas/{tayfa_id}/library/loans`
  /// verir. Yalnızca uygulama içi, push gitmez.
  /// Tanınmayan değer `unknown`.
  final NotificationType type;

  /// Bildirim bir tayfayla ilgili değilse yoktur.
  final String? tayfaId;

  /// İşlemi yapan; sistem ya da silinmiş hesapsa yoktur. Adı
  /// `GET /v1/users/{user_id}/profile` verir (ortak tayfa gerekmez).
  final String? actorId;

  /// `membership` için `target_id` başvuran kullanıcının kimliğidir;
  /// `user` için bir kullanıcının kimliği (profilini açın); `report`
  /// için kendi şikâyetinizin kimliği; `dm_conversation` için
  /// konuşmanızın kimliği; `data_export` için kendi veri dışa
  /// aktarma talebinizin kimliği (`GET /v1/me/data-exports/{data_export_id}`).
  final NotificationTargetType targetType;

  final String targetId;

  /// Yalnızca `answer_received`; cevaplanan soru.
  final String? questionId;

  /// Yalnızca `hike_overdue`; dönmeyen yürüyüşçü.
  final String? subjectUserId;

  /// Yalnızca `tayfa_warned`.
  final NotificationWarningReason? warningReason;

  /// Yalnızca `dm_request` ve `dm_message`: konuşma başına tek bildirim
  /// vardır; bu, bildirim son güncellendiğinde konuşmadaki okunmamış
  /// mesaj sayınızdır (en fazla 100; istemci "99+" gösterir). Her yeni
  /// mesajda güncellenir; konuşma okununca bildirim okundu olur ve
  /// sonraki mesaj yeni bildirimi 1'den başlatır.
  ///
  /// Kısıtlar: minimum: 1; maximum: 100.
  final int? unreadCount;

  /// Yalnızca `friend_request` ve `tayfa_invitation` (issue #192):
  /// isteğin ya da davetin şu anki durumu. `pending` yanıt bekliyor
  /// (satır içi düğmeler gösterilir); `accepted` kabul edildi;
  /// `declined` siz reddettiniz; `withdrawn` karşı taraf geri çekti;
  /// `expired` artık bilinmiyor. Liste alınırken core'dan hesaplanır,
  /// bildirime yazılmaz; yalnızca alıcıya döner, kimin geri çektiği
  /// söylenmez. O an hesaplanamazsa alan yoktur.
  ///
  /// `friend_suggestion` (issue #208, ADR-0030): `pending` öneri hâlâ
  /// geçerli ("Arkadaş ekle" / "Kapat" gösterilir); `accepted`
  /// arkadaş oldunuz ya da istek gönderildi; `declined` siz
  /// kapattınız; `expired` öneri geri çekildi ya da artık geçerli
  /// değil (neden söylenmez). İstemci `pending` olmayan öneri
  /// bildirimini göstermez.
  final NotificationResolution? resolution;

  final bool read;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.wire,
    if (tayfaId case final value?) 'tayfa_id': value,
    if (actorId case final value?) 'actor_id': value,
    'target_type': targetType.wire,
    'target_id': targetId,
    if (questionId case final value?) 'question_id': value,
    if (subjectUserId case final value?) 'subject_user_id': value,
    if (warningReason case final value?) 'warning_reason': value.wire,
    if (unreadCount case final value?) 'unread_count': value,
    if (resolution case final value?) 'resolution': value.wire,
    'read': read,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notification &&
          id == other.id &&
          type == other.type &&
          tayfaId == other.tayfaId &&
          actorId == other.actorId &&
          targetType == other.targetType &&
          targetId == other.targetId &&
          questionId == other.questionId &&
          subjectUserId == other.subjectUserId &&
          warningReason == other.warningReason &&
          unreadCount == other.unreadCount &&
          resolution == other.resolution &&
          read == other.read &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    type,
    tayfaId,
    actorId,
    targetType,
    targetId,
    questionId,
    subjectUserId,
    warningReason,
    unreadCount,
    resolution,
    read,
    createdAt,
  ]);
}

final class NotificationList {
  const NotificationList({required this.notifications, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory NotificationList.fromJson(Map<String, Object?> json) =>
      NotificationList(
        notifications: List<Notification>.unmodifiable(
          _readList(
            json['notifications'],
            'NotificationList.notifications',
          ).map(
            (Object? e0) => Notification.fromJson(
              _readObject(e0, 'NotificationList.notifications'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'NotificationList.next_page_token'),
        },
      );

  final List<Notification> notifications;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'notifications': <Object?>[for (final e0 in notifications) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationList &&
          _deepEquals(notifications, other.notifications) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(notifications), nextPageToken]);
}

final class NotificationPreference {
  const NotificationPreference({
    required this.scopeType,
    required this.scopeId,
    required this.level,
    this.muteUntil,
    required this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory NotificationPreference.fromJson(
    Map<String, Object?> json,
  ) => NotificationPreference(
    scopeType: NotificationPreferenceScopeType.fromWire(
      _readString(json['scope_type'], 'NotificationPreference.scope_type'),
    ),
    scopeId: _readString(json['scope_id'], 'NotificationPreference.scope_id'),
    level: NotificationPreferenceLevel.fromWire(
      _readString(json['level'], 'NotificationPreference.level'),
    ),
    muteUntil: switch (json['mute_until']) {
      null => null,
      final Object v => _readDateTime(v, 'NotificationPreference.mute_until'),
    },
    updatedAt: _readDateTime(
      json['updated_at'],
      'NotificationPreference.updated_at',
    ),
  );

  /// `tayfa`, `tayfa_now` (tayfanın şimdi bildirimleri) ya da `dm_conversation` (birebir konuşma); kanal sonra gelir.
  final NotificationPreferenceScopeType scopeType;

  final String scopeId;

  final NotificationPreferenceLevel level;

  /// Yoksa süresiz.
  final DateTime? muteUntil;

  final DateTime updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'scope_type': scopeType.wire,
    'scope_id': scopeId,
    'level': level.wire,
    if (muteUntil case final value?)
      'mute_until': value.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreference &&
          scopeType == other.scopeType &&
          scopeId == other.scopeId &&
          level == other.level &&
          muteUntil == other.muteUntil &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    scopeType,
    scopeId,
    level,
    muteUntil,
    updatedAt,
  ]);
}

enum NotificationPreferenceLevel {
  all('all'),
  mentions('mentions'),
  none('none'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const NotificationPreferenceLevel(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('NotificationPreferenceLevel.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationPreferenceLevel fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class NotificationPreferenceList {
  const NotificationPreferenceList({required this.preferences});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory NotificationPreferenceList.fromJson(Map<String, Object?> json) =>
      NotificationPreferenceList(
        preferences: List<NotificationPreference>.unmodifiable(
          _readList(
            json['preferences'],
            'NotificationPreferenceList.preferences',
          ).map(
            (Object? e0) => NotificationPreference.fromJson(
              _readObject(e0, 'NotificationPreferenceList.preferences'),
            ),
          ),
        ),
      );

  final List<NotificationPreference> preferences;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'preferences': <Object?>[for (final e0 in preferences) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferenceList &&
          _deepEquals(preferences, other.preferences);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(preferences)]);
}

final class NotificationPreferenceRequest {
  const NotificationPreferenceRequest({required this.level, this.muteUntil});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory NotificationPreferenceRequest.fromJson(Map<String, Object?> json) =>
      NotificationPreferenceRequest(
        level: NotificationPreferenceRequestLevel.fromWire(
          _readString(json['level'], 'NotificationPreferenceRequest.level'),
        ),
        muteUntil: switch (json['mute_until']) {
          null => null,
          final Object v => _readDateTime(
            v,
            'NotificationPreferenceRequest.mute_until',
          ),
        },
      );

  final NotificationPreferenceRequestLevel level;

  /// Yalnızca `mentions` ya da `none` ile; en fazla bir yıl sonrası.
  final DateTime? muteUntil;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'level': level.wire,
    if (muteUntil case final value?)
      'mute_until': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferenceRequest &&
          level == other.level &&
          muteUntil == other.muteUntil;

  @override
  int get hashCode => Object.hashAll(<Object?>[level, muteUntil]);
}

enum NotificationPreferenceRequestLevel {
  all('all'),
  mentions('mentions'),
  none('none'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const NotificationPreferenceRequestLevel(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'NotificationPreferenceRequestLevel.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationPreferenceRequestLevel fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `tayfa`, `tayfa_now` (tayfanın şimdi bildirimleri) ya da `dm_conversation` (birebir konuşma); kanal sonra gelir.
enum NotificationPreferenceScopeType {
  tayfa('tayfa'),
  tayfaNow('tayfa_now'),
  channel('channel'),
  dmConversation('dm_conversation'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const NotificationPreferenceScopeType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'NotificationPreferenceScopeType.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationPreferenceScopeType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Yalnızca `friend_request` ve `tayfa_invitation` (issue #192):
/// isteğin ya da davetin şu anki durumu. `pending` yanıt bekliyor
/// (satır içi düğmeler gösterilir); `accepted` kabul edildi;
/// `declined` siz reddettiniz; `withdrawn` karşı taraf geri çekti;
/// `expired` artık bilinmiyor. Liste alınırken core'dan hesaplanır,
/// bildirime yazılmaz; yalnızca alıcıya döner, kimin geri çektiği
/// söylenmez. O an hesaplanamazsa alan yoktur.
///
/// `friend_suggestion` (issue #208, ADR-0030): `pending` öneri hâlâ
/// geçerli ("Arkadaş ekle" / "Kapat" gösterilir); `accepted`
/// arkadaş oldunuz ya da istek gönderildi; `declined` siz
/// kapattınız; `expired` öneri geri çekildi ya da artık geçerli
/// değil (neden söylenmez). İstemci `pending` olmayan öneri
/// bildirimini göstermez.
enum NotificationResolution {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  withdrawn('withdrawn'),
  expired('expired'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const NotificationResolution(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('NotificationResolution.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationResolution fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `membership` için `target_id` başvuran kullanıcının kimliğidir;
/// `user` için bir kullanıcının kimliği (profilini açın); `report`
/// için kendi şikâyetinizin kimliği; `dm_conversation` için
/// konuşmanızın kimliği; `data_export` için kendi veri dışa
/// aktarma talebinizin kimliği (`GET /v1/me/data-exports/{data_export_id}`).
enum NotificationTargetType {
  tayfa('tayfa'),
  membership('membership'),
  announcement('announcement'),
  event('event'),
  answer('answer'),
  user('user'),
  report('report'),
  dmConversation('dm_conversation'),
  dataExport('data_export'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const NotificationTargetType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('NotificationTargetType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationTargetType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `event_created` (yeni etkinlik), `event_updated` ve
/// `event_cancelled` (katıldığınız etkinlik değişti/iptal edildi),
/// `rsvp_promoted` (bekleme listesinden katılımcılara geçtiniz),
/// `announcement`, `answer_received` (sorunuza cevap),
/// `join_request` (yönetici/moderatörlere başvuru),
/// `join_approved` (başvurunuz onaylandı),
/// `tayfa_deletion_requested` (yönetici/moderatörlere silme talebi),
/// `tayfa_warned` (hareketsiz tayfa 7 gün içinde arşivlenecek;
/// `warning_reason` var), `tayfa_archived`, `tayfa_suspended` ve `tayfa_unsuspended` (platform askısı; gerekçe tayfa ayrıntısında), `hike_overdue`
/// (yürüyüşçü zamanında dönmedi; `subject_user_id` yürüyüşçüdür,
/// sessize alma bu bildirimi engellemez), `friend_request` (size
/// arkadaşlık isteği; `target_id` isteyen kişi), `friend_accepted`
/// (isteğiniz kabul edildi; `target_id` yeni arkadaşınız),
/// `tayfa_invitation` (bir arkadaşınız sizi tayfaya davet etti;
/// hedef tayfa), `report_resolved` (şikâyetiniz çözüldü; hedef
/// `report`, `actor_id` hiçbir zaman yoktur; sonucu
/// `GET /v1/me/reports/{report_id}` verir). İki arkadaşlık bildirimi
/// bir tayfayla ilgili değildir, `tayfa_id` yoktur. `dm_request`
/// (size mesaj isteği) ve `dm_message` (yeni birebir mesaj;
/// konuşma okunana kadar konuşma başına tek bildirim) yalnızca
/// "yeni" bilgisi taşır: hedef `dm_conversation`, `actor_id` ve
/// `tayfa_id` yoktur, içerik de gönderen de yazılmaz; okunmamış
/// mesaj sayısını `unread_count` taşır. `data_export_ready` (KVKK
/// veri dışa aktarmanız 7 gün indirilebilir; hedef `data_export`,
/// `tayfa_id` ve `actor_id` yoktur; push çeviri anahtarları
/// `push_data_export_ready_title` ve `push_data_export_ready_body`).
/// `friend_suggestion` (arkadaş önerisi; `target_id` önerilen kişi,
/// `tayfa_id` ve `actor_id` yoktur; yalnızca uygulama içi, push
/// gitmez; açık öneriler `GET /v1/me/friend-suggestions`).
/// `safety_alert` (#210, ADR-0033): sizi güvenlik kişisi seçen
/// `target_id` (hedef `user`) etkinliğin bitişi ve toleransı geçtiği
/// halde "Döndüm" demedi; `tayfa_id` ve `actor_id` yoktur, içerik ve
/// konum taşımaz; etkinliği `GET /v1/me/safety-shares` verir.
/// Susturma uygulanmaz, push gider.
/// `celebration` (#255): organizatör (`actor_id`) hedef etkinliğin
/// bir kutlama bileşeninde kazananı ilan etti; kutlama başına bir
/// kez, tayfanın ilan eden dışındaki etkin üyelerine. Kazananı
/// adlandırmaz; kutlamayı bileşenin ucu verir. Yalnızca uygulama
/// içi, push gitmez.
/// `badge_earned` (#258, ADR-0039 §4): bir rozet kazanıldı; rozeti
/// adlandırmaz, `actor_id` yoktur. Kişisel rozette alıcı rozeti
/// kazanan kişidir, hedef `user` kendisidir (kendi profilinizi
/// açın) ve `tayfa_id` yoktur; tayfa rozetinde alıcılar tayfanın
/// yönetici ve moderatörleridir, hedef `tayfa`'dır. Yalnızca
/// uygulama içi, push gitmez.
/// `now_started` (#265, ADR-0038 §4): organizatör (`actor_id`)
/// hedef etkinliği Şimdi başlat ile açtı. Tayfa etkinliğinde
/// alıcılar tayfanın etkin üyeleridir (tayfa başına günde en fazla
/// 3); anlık etkinlikte organizatörün seçtiği arkadaşlardır ve
/// bildirim bir davettir: `tayfa_id` anlık etkinliğin tayfasıdır,
/// daveti `GET /v1/me/invitations` gösterir, kabul edince etkin üye
/// olursunuz. Başlık, tür, yer ya da ad taşımaz; push yalnızca
/// `push_now_started_title` / `push_now_started_body` anahtarlarıdır.
/// Tayfa seviyesi `none` ya da tayfanın şimdi tercihi (`tayfa_now`)
/// `none` ise push gitmez.
/// `library_due` (#270, ADR-0040 §1): ödüncün iade tarihi geçti;
/// borç alana tek hatırlatma. `library_loan_orphaned`: teslim
/// edilmiş bir ödünçte taraflardan biri tayfadan ayrıldı; iki tarafa
/// (ayrılana da) uyarı, kayıt 30 gün sonra kapanır. İkisinde de hedef
/// ödüncün tayfasıdır (`tayfa`), `actor_id` yoktur; eşyayı ve kişileri
/// adlandırmaz, ödünçleri `GET /v1/tayfas/{tayfa_id}/library/loans`
/// verir. Yalnızca uygulama içi, push gitmez.
/// Tanınmayan değer `unknown`.
enum NotificationType {
  eventCreated('event_created'),
  eventUpdated('event_updated'),
  eventCancelled('event_cancelled'),
  rsvpPromoted('rsvp_promoted'),
  announcement('announcement'),
  answerReceived('answer_received'),
  joinRequest('join_request'),
  joinApproved('join_approved'),
  tayfaDeletionRequested('tayfa_deletion_requested'),
  tayfaWarned('tayfa_warned'),
  tayfaArchived('tayfa_archived'),
  tayfaSuspended('tayfa_suspended'),
  tayfaUnsuspended('tayfa_unsuspended'),
  hikeOverdue('hike_overdue'),
  friendRequest('friend_request'),
  friendAccepted('friend_accepted'),
  tayfaInvitation('tayfa_invitation'),
  reportResolved('report_resolved'),
  dmRequest('dm_request'),
  dmMessage('dm_message'),
  dataExportReady('data_export_ready'),
  friendSuggestion('friend_suggestion'),
  safetyAlert('safety_alert'),
  celebration('celebration'),
  badgeEarned('badge_earned'),
  nowStarted('now_started'),
  libraryDue('library_due'),
  libraryLoanOrphaned('library_loan_orphaned'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const NotificationType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('NotificationType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Yalnızca `tayfa_warned`.
enum NotificationWarningReason {
  inactive('inactive'),
  fewMembers('few_members'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const NotificationWarningReason(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('NotificationWarningReason.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NotificationWarningReason fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Tayfanın şimdi bildirimleri; `mentions` yoktur.
final class NowNotificationPreferenceRequest {
  const NowNotificationPreferenceRequest({required this.level, this.muteUntil});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory NowNotificationPreferenceRequest.fromJson(
    Map<String, Object?> json,
  ) => NowNotificationPreferenceRequest(
    level: NowNotificationPreferenceRequestLevel.fromWire(
      _readString(json['level'], 'NowNotificationPreferenceRequest.level'),
    ),
    muteUntil: switch (json['mute_until']) {
      null => null,
      final Object v => _readDateTime(
        v,
        'NowNotificationPreferenceRequest.mute_until',
      ),
    },
  );

  final NowNotificationPreferenceRequestLevel level;

  /// Yalnızca `none` ile; en fazla bir yıl sonrası.
  final DateTime? muteUntil;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'level': level.wire,
    if (muteUntil case final value?)
      'mute_until': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NowNotificationPreferenceRequest &&
          level == other.level &&
          muteUntil == other.muteUntil;

  @override
  int get hashCode => Object.hashAll(<Object?>[level, muteUntil]);
}

enum NowNotificationPreferenceRequestLevel {
  all('all'),
  none('none'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const NowNotificationPreferenceRequestLevel(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'NowNotificationPreferenceRequestLevel.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static NowNotificationPreferenceRequestLevel fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class OutgoingEnvelope {
  const OutgoingEnvelope({
    required this.deviceId,
    required this.registrationId,
    required this.type,
    required this.content,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory OutgoingEnvelope.fromJson(Map<String, Object?> json) =>
      OutgoingEnvelope(
        deviceId: _readString(json['device_id'], 'OutgoingEnvelope.device_id'),
        registrationId: _readInt(
          json['registration_id'],
          'OutgoingEnvelope.registration_id',
        ),
        type: OutgoingEnvelopeType.fromWire(
          _readString(json['type'], 'OutgoingEnvelope.type'),
        ),
        content: _readString(json['content'], 'OutgoingEnvelope.content'),
      );

  final String deviceId;

  /// Gönderenin bu cihazla oturumundaki kayıt kimliği; değişmişse cihaz değişmiştir.
  ///
  /// Kısıtlar: minimum: 1; maximum: 16380.
  final int registrationId;

  /// Signal CiphertextMessageType (2 whisper, 3 prekey).
  final OutgoingEnvelopeType type;

  /// Opak Signal mesajı, 1 B – 64 KiB.
  ///
  /// Kısıtlar: biçim: standart base64.
  final String content;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'device_id': deviceId,
    'registration_id': registrationId,
    'type': type.wire,
    'content': content,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutgoingEnvelope &&
          deviceId == other.deviceId &&
          registrationId == other.registrationId &&
          type == other.type &&
          content == other.content;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[deviceId, registrationId, type, content]);
}

/// Signal CiphertextMessageType (2 whisper, 3 prekey).
enum OutgoingEnvelopeType {
  whisper('whisper'),
  prekey('prekey'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const OutgoingEnvelopeType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('OutgoingEnvelopeType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static OutgoingEnvelopeType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kullanıcının haritadan seçip paylaştığı yer (ADR-0008: içerik,
/// cihaz konumu değil). Log'a yazılmaz.
final class Place {
  const Place({required this.latitude, required this.longitude, this.name});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Place.fromJson(Map<String, Object?> json) => Place(
    latitude: _readDouble(json['latitude'], 'Place.latitude'),
    longitude: _readDouble(json['longitude'], 'Place.longitude'),
    name: switch (json['name']) {
      null => null,
      final Object v => _readString(v, 'Place.name'),
    },
  );

  /// Kısıtlar: minimum: -90; maximum: 90.
  final double latitude;

  /// Kısıtlar: minimum: -180; maximum: 180.
  final double longitude;

  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String? name;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'latitude': latitude,
    'longitude': longitude,
    if (name case final value?) 'name': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Place &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          name == other.name;

  @override
  int get hashCode => Object.hashAll(<Object?>[latitude, longitude, name]);
}

/// Yapılandırılmamış alan yoktur.
final class PlatformVersions {
  const PlatformVersions({this.minSupportedVersion, this.latestVersion});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PlatformVersions.fromJson(Map<String, Object?> json) =>
      PlatformVersions(
        minSupportedVersion: switch (json['min_supported_version']) {
          null => null,
          final Object v => _readString(
            v,
            'PlatformVersions.min_supported_version',
          ),
        },
        latestVersion: switch (json['latest_version']) {
          null => null,
          final Object v => _readString(v, 'PlatformVersions.latest_version'),
        },
      );

  /// Bunun altındaki sürümler `client-outdated` alır.
  final String? minSupportedVersion;

  /// Mağazadaki en son sürüm; yalnızca bilgi.
  final String? latestVersion;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (minSupportedVersion case final value?) 'min_supported_version': value,
    if (latestVersion case final value?) 'latest_version': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformVersions &&
          minSupportedVersion == other.minSupportedVersion &&
          latestVersion == other.latestVersion;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[minSupportedVersion, latestVersion]);
}

/// Gizli ankette (`anonymous`) diğer üyeler, yöneticiler dahil, kimin
/// neye oy verdiğini göremez; `own_option_ids` her zaman yalnızca
/// çağıranın kendi oyudur. Sayımlar her ankette döner.
final class Poll {
  const Poll({
    required this.id,
    required this.tayfaId,
    this.eventId,
    this.createdByUserId,
    required this.question,
    required this.anonymous,
    required this.multipleChoice,
    this.closesAt,
    this.closedAt,
    required this.closed,
    required this.createdAt,
    required this.options,
    required this.voterCount,
    required this.ownOptionIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Poll.fromJson(Map<String, Object?> json) => Poll(
    id: _readString(json['id'], 'Poll.id'),
    tayfaId: _readString(json['tayfa_id'], 'Poll.tayfa_id'),
    eventId: switch (json['event_id']) {
      null => null,
      final Object v => _readString(v, 'Poll.event_id'),
    },
    createdByUserId: switch (json['created_by_user_id']) {
      null => null,
      final Object v => _readString(v, 'Poll.created_by_user_id'),
    },
    question: _readString(json['question'], 'Poll.question'),
    anonymous: _readBool(json['anonymous'], 'Poll.anonymous'),
    multipleChoice: _readBool(json['multiple_choice'], 'Poll.multiple_choice'),
    closesAt: switch (json['closes_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Poll.closes_at'),
    },
    closedAt: switch (json['closed_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Poll.closed_at'),
    },
    closed: _readBool(json['closed'], 'Poll.closed'),
    createdAt: _readDateTime(json['created_at'], 'Poll.created_at'),
    options: List<PollOption>.unmodifiable(
      _readList(json['options'], 'Poll.options').map(
        (Object? e0) => PollOption.fromJson(_readObject(e0, 'Poll.options')),
      ),
    ),
    voterCount: _readInt(json['voter_count'], 'Poll.voter_count'),
    ownOptionIds: List<String>.unmodifiable(
      _readList(
        json['own_option_ids'],
        'Poll.own_option_ids',
      ).map((Object? e0) => _readString(e0, 'Poll.own_option_ids')),
    ),
  );

  final String id;

  final String tayfaId;

  /// Anket bir etkinliğe bağlı değilse yoktur.
  final String? eventId;

  /// Anketi açanın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? createdByUserId;

  final String question;

  final bool anonymous;

  final bool multipleChoice;

  /// Planlanan kapanma zamanı; yoksa elle kapatılana kadar açık.
  final DateTime? closesAt;

  /// Erken kapatıldıysa.
  final DateTime? closedAt;

  /// Erken kapatıldı ya da kapanma zamanı geçti; oy alınmaz.
  final bool closed;

  final DateTime createdAt;

  final List<PollOption> options;

  /// Oy veren kişi sayısı (çok seçimlide kişi bir kez sayılır).
  final int voterCount;

  /// Çağıranın kendi oyu; oy vermediyse boş.
  final List<String> ownOptionIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    if (eventId case final value?) 'event_id': value,
    if (createdByUserId case final value?) 'created_by_user_id': value,
    'question': question,
    'anonymous': anonymous,
    'multiple_choice': multipleChoice,
    if (closesAt case final value?)
      'closes_at': value.toUtc().toIso8601String(),
    if (closedAt case final value?)
      'closed_at': value.toUtc().toIso8601String(),
    'closed': closed,
    'created_at': createdAt.toUtc().toIso8601String(),
    'options': <Object?>[for (final e0 in options) e0.toJson()],
    'voter_count': voterCount,
    'own_option_ids': <Object?>[for (final e0 in ownOptionIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Poll &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          eventId == other.eventId &&
          createdByUserId == other.createdByUserId &&
          question == other.question &&
          anonymous == other.anonymous &&
          multipleChoice == other.multipleChoice &&
          closesAt == other.closesAt &&
          closedAt == other.closedAt &&
          closed == other.closed &&
          createdAt == other.createdAt &&
          _deepEquals(options, other.options) &&
          voterCount == other.voterCount &&
          _deepEquals(ownOptionIds, other.ownOptionIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    eventId,
    createdByUserId,
    question,
    anonymous,
    multipleChoice,
    closesAt,
    closedAt,
    closed,
    createdAt,
    _deepHash(options),
    voterCount,
    _deepHash(ownOptionIds),
  ]);
}

final class PollCreateRequest {
  const PollCreateRequest({
    required this.question,
    required this.options,
    this.anonymous,
    this.multipleChoice,
    this.closesAt,
    this.eventId,
    this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PollCreateRequest.fromJson(Map<String, Object?> json) =>
      PollCreateRequest(
        question: _readString(json['question'], 'PollCreateRequest.question'),
        options: List<String>.unmodifiable(
          _readList(
            json['options'],
            'PollCreateRequest.options',
          ).map((Object? e0) => _readString(e0, 'PollCreateRequest.options')),
        ),
        anonymous: switch (json['anonymous']) {
          null => null,
          final Object v => _readBool(v, 'PollCreateRequest.anonymous'),
        },
        multipleChoice: switch (json['multiple_choice']) {
          null => null,
          final Object v => _readBool(v, 'PollCreateRequest.multiple_choice'),
        },
        closesAt: switch (json['closes_at']) {
          null => null,
          final Object v => _readDateTime(v, 'PollCreateRequest.closes_at'),
        },
        eventId: switch (json['event_id']) {
          null => null,
          final Object v => _readString(v, 'PollCreateRequest.event_id'),
        },
        clientRequestId: switch (json['client_request_id']) {
          null => null,
          final Object v => _readString(
            v,
            'PollCreateRequest.client_request_id',
          ),
        },
      );

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 1–200 karakter, tek satır.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 200.
  final String question;

  /// Her biri 1–100 karakter, tek satır; büyük/küçük harf farkı gözetmeden tekil.
  ///
  /// Kısıtlar: minItems: 2; maxItems: 10.
  final List<String> options;

  /// İlk oydan sonra değiştirilemez.
  ///
  /// Kısıtlar: varsayılan (sunucu): false.
  final bool? anonymous;

  /// Kısıtlar: varsayılan (sunucu): false.
  final bool? multipleChoice;

  /// İsteğe bağlı; gelecekte, en fazla 365 gün sonra.
  final DateTime? closesAt;

  /// İsteğe bağlı; aynı tayfanın etkinliği.
  final String? eventId;

  /// İsteğe bağlı. İstemcinin her oluşturma denemesi için bir kez
  /// ürettiği, tekrar gönderimde aynen kullandığı UUID; aynı kişiden
  /// tekrar gelirse ilk anket döner, ikinci anket açılmaz. Başka bir
  /// tayfada ya da o anket silindikten sonra tekrar kullanılırsa
  /// `validation` (alan `client_request_id`).
  final String? clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'question': question,
    'options': <Object?>[for (final e0 in options) e0],
    if (anonymous case final value?) 'anonymous': value,
    if (multipleChoice case final value?) 'multiple_choice': value,
    if (closesAt case final value?)
      'closes_at': value.toUtc().toIso8601String(),
    if (eventId case final value?) 'event_id': value,
    if (clientRequestId case final value?) 'client_request_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollCreateRequest &&
          question == other.question &&
          _deepEquals(options, other.options) &&
          anonymous == other.anonymous &&
          multipleChoice == other.multipleChoice &&
          closesAt == other.closesAt &&
          eventId == other.eventId &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    question,
    _deepHash(options),
    anonymous,
    multipleChoice,
    closesAt,
    eventId,
    clientRequestId,
  ]);
}

final class PollList {
  const PollList({required this.polls, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PollList.fromJson(Map<String, Object?> json) => PollList(
    polls: List<Poll>.unmodifiable(
      _readList(
        json['polls'],
        'PollList.polls',
      ).map((Object? e0) => Poll.fromJson(_readObject(e0, 'PollList.polls'))),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'PollList.next_page_token'),
    },
  );

  final List<Poll> polls;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'polls': <Object?>[for (final e0 in polls) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollList &&
          _deepEquals(polls, other.polls) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(polls), nextPageToken]);
}

final class PollOption {
  const PollOption({
    required this.id,
    required this.text,
    required this.position,
    required this.voteCount,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PollOption.fromJson(Map<String, Object?> json) => PollOption(
    id: _readString(json['id'], 'PollOption.id'),
    text: _readString(json['text'], 'PollOption.text'),
    position: _readInt(json['position'], 'PollOption.position'),
    voteCount: _readInt(json['vote_count'], 'PollOption.vote_count'),
  );

  final String id;

  final String text;

  final int position;

  final int voteCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'text': text,
    'position': position,
    'vote_count': voteCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollOption &&
          id == other.id &&
          text == other.text &&
          position == other.position &&
          voteCount == other.voteCount;

  @override
  int get hashCode => Object.hashAll(<Object?>[id, text, position, voteCount]);
}

final class PollVoteRequest {
  const PollVoteRequest({required this.optionIds});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PollVoteRequest.fromJson(Map<String, Object?> json) =>
      PollVoteRequest(
        optionIds: List<String>.unmodifiable(
          _readList(
            json['option_ids'],
            'PollVoteRequest.option_ids',
          ).map((Object? e0) => _readString(e0, 'PollVoteRequest.option_ids')),
        ),
      );

  /// Kısıtlar: minItems: 1; maxItems: 10; uniqueItems: true.
  final List<String> optionIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'option_ids': <Object?>[for (final e0 in optionIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollVoteRequest && _deepEquals(optionIds, other.optionIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(optionIds)]);
}

final class PollVoter {
  const PollVoter({required this.userId, required this.votedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PollVoter.fromJson(Map<String, Object?> json) => PollVoter(
    userId: _readString(json['user_id'], 'PollVoter.user_id'),
    votedAt: _readDateTime(json['voted_at'], 'PollVoter.voted_at'),
  );

  final String userId;

  final DateTime votedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'voted_at': votedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollVoter && userId == other.userId && votedAt == other.votedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, votedAt]);
}

final class PollVoterList {
  const PollVoterList({required this.voters, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PollVoterList.fromJson(Map<String, Object?> json) => PollVoterList(
    voters: List<PollVoter>.unmodifiable(
      _readList(json['voters'], 'PollVoterList.voters').map(
        (Object? e0) =>
            PollVoter.fromJson(_readObject(e0, 'PollVoterList.voters')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'PollVoterList.next_page_token'),
    },
  );

  final List<PollVoter> voters;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'voters': <Object?>[for (final e0 in voters) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollVoterList &&
          _deepEquals(voters, other.voters) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(voters), nextPageToken]);
}

/// Etkinliğe bağlı bir soru havuzu sorusu (#271).
final class PoolLinkedQuestion {
  const PoolLinkedQuestion({
    required this.questionId,
    this.authorUserId,
    required this.body,
    required this.subjectKey,
    this.topicKey,
    required this.photoUploadIds,
    required this.answerCount,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PoolLinkedQuestion.fromJson(Map<String, Object?> json) =>
      PoolLinkedQuestion(
        questionId: _readString(
          json['question_id'],
          'PoolLinkedQuestion.question_id',
        ),
        authorUserId: switch (json['author_user_id']) {
          null => null,
          final Object v => _readString(v, 'PoolLinkedQuestion.author_user_id'),
        },
        body: _readString(json['body'], 'PoolLinkedQuestion.body'),
        subjectKey: _readString(
          json['subject_key'],
          'PoolLinkedQuestion.subject_key',
        ),
        topicKey: switch (json['topic_key']) {
          null => null,
          final Object v => _readString(v, 'PoolLinkedQuestion.topic_key'),
        },
        photoUploadIds: List<String>.unmodifiable(
          _readList(
            json['photo_upload_ids'],
            'PoolLinkedQuestion.photo_upload_ids',
          ).map(
            (Object? e0) =>
                _readString(e0, 'PoolLinkedQuestion.photo_upload_ids'),
          ),
        ),
        answerCount: _readInt(
          json['answer_count'],
          'PoolLinkedQuestion.answer_count',
        ),
        createdAt: _readDateTime(
          json['created_at'],
          'PoolLinkedQuestion.created_at',
        ),
      );

  final String questionId;

  /// Yazarın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? authorUserId;

  /// Sorunun metni; fotoğrafı varsa boş olabilir.
  final String body;

  final String subjectKey;

  /// Konu yoksa alan yoktur.
  final String? topicKey;

  /// Kısıtlar: maxItems: 2.
  final List<String> photoUploadIds;

  /// Görünen cevap sayısı.
  final int answerCount;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'question_id': questionId,
    if (authorUserId case final value?) 'author_user_id': value,
    'body': body,
    'subject_key': subjectKey,
    if (topicKey case final value?) 'topic_key': value,
    'photo_upload_ids': <Object?>[for (final e0 in photoUploadIds) e0],
    'answer_count': answerCount,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoolLinkedQuestion &&
          questionId == other.questionId &&
          authorUserId == other.authorUserId &&
          body == other.body &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey &&
          _deepEquals(photoUploadIds, other.photoUploadIds) &&
          answerCount == other.answerCount &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    questionId,
    authorUserId,
    body,
    subjectKey,
    topicKey,
    _deepHash(photoUploadIds),
    answerCount,
    createdAt,
  ]);
}

final class Problem {
  const Problem({
    required this.type,
    required this.title,
    required this.status,
    this.detail,
    this.instance,
    this.requestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Problem.fromJson(Map<String, Object?> json) => Problem(
    type: _readString(json['type'], 'Problem.type'),
    title: _readString(json['title'], 'Problem.title'),
    status: _readInt(json['status'], 'Problem.status'),
    detail: switch (json['detail']) {
      null => null,
      final Object v => _readString(v, 'Problem.detail'),
    },
    instance: switch (json['instance']) {
      null => null,
      final Object v => _readString(v, 'Problem.instance'),
    },
    requestId: switch (json['request_id']) {
      null => null,
      final Object v => _readString(v, 'Problem.request_id'),
    },
  );

  final String type;

  final String title;

  final int status;

  final String? detail;

  final String? instance;

  final String? requestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'title': title,
    'status': status,
    if (detail case final value?) 'detail': value,
    if (instance case final value?) 'instance': value,
    if (requestId case final value?) 'request_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Problem &&
          type == other.type &&
          title == other.title &&
          status == other.status &&
          detail == other.detail &&
          instance == other.instance &&
          requestId == other.requestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    type,
    title,
    status,
    detail,
    instance,
    requestId,
  ]);
}

/// Profil tamamlama formunun bir alanı.
enum ProfileField {
  interests('interests'),
  about('about'),
  occupation('occupation'),
  team('team'),
  languages('languages'),
  socialAccounts('social_accounts'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ProfileField(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ProfileField.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ProfileField fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class PushTokenRegistration {
  const PushTokenRegistration({
    required this.token,
    required this.platform,
    this.tokenType,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory PushTokenRegistration.fromJson(Map<String, Object?> json) =>
      PushTokenRegistration(
        token: _readString(json['token'], 'PushTokenRegistration.token'),
        platform: PushTokenRegistrationPlatform.fromWire(
          _readString(json['platform'], 'PushTokenRegistration.platform'),
        ),
        tokenType: switch (json['token_type']) {
          null => null,
          final Object v => PushTokenRegistrationTokenType.fromWire(
            _readString(v, 'PushTokenRegistration.token_type'),
          ),
        },
      );

  /// `token_type`'a göre FCM kayıt token'ı (`getToken`) ya da Firebase
  /// Installation ID (FID; firebase_messaging 17+ `register()` /
  /// `onRegistered`). Log'a yazılmaz.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 1024; pattern: `^[A-Za-z0-9:_.-]+$`.
  final String token;

  final PushTokenRegistrationPlatform platform;

  /// `token`'ın türü (ADR-0036). Gönderilmezse `registration_token`
  /// sayılır (eski istemciler). firebase_messaging 17+ istemcileri
  /// `onRegistered`'ın verdiği FID'i `fid` ile kaydeder. Oturumun
  /// kaydı türüyle birlikte yenilenir: aynı oturumda token'dan FID'e
  /// geçmek için yeniden `PUT` yeterlidir.
  ///
  /// Kısıtlar: varsayılan (sunucu): `registration_token`.
  final PushTokenRegistrationTokenType? tokenType;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'platform': platform.wire,
    if (tokenType case final value?) 'token_type': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PushTokenRegistration &&
          token == other.token &&
          platform == other.platform &&
          tokenType == other.tokenType;

  @override
  int get hashCode => Object.hashAll(<Object?>[token, platform, tokenType]);
}

enum PushTokenRegistrationPlatform {
  android('android'),
  ios('ios'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const PushTokenRegistrationPlatform(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('PushTokenRegistrationPlatform.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static PushTokenRegistrationPlatform fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `token`'ın türü (ADR-0036). Gönderilmezse `registration_token`
/// sayılır (eski istemciler). firebase_messaging 17+ istemcileri
/// `onRegistered`'ın verdiği FID'i `fid` ile kaydeder. Oturumun
/// kaydı türüyle birlikte yenilenir: aynı oturumda token'dan FID'e
/// geçmek için yeniden `PUT` yeterlidir.
///
/// Kısıtlar: varsayılan (sunucu): `registration_token`.
enum PushTokenRegistrationTokenType {
  registrationToken('registration_token'),
  fid('fid'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const PushTokenRegistrationTokenType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('PushTokenRegistrationTokenType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static PushTokenRegistrationTokenType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Question {
  const Question({
    required this.id,
    required this.tayfaId,
    this.authorUserId,
    required this.title,
    required this.body,
    required this.tags,
    required this.answerCount,
    required this.createdAt,
    required this.updatedAt,
    required this.pool,
    this.subjectKey,
    this.topicKey,
    required this.photoUploadIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Question.fromJson(Map<String, Object?> json) => Question(
    id: _readString(json['id'], 'Question.id'),
    tayfaId: _readString(json['tayfa_id'], 'Question.tayfa_id'),
    authorUserId: switch (json['author_user_id']) {
      null => null,
      final Object v => _readString(v, 'Question.author_user_id'),
    },
    title: _readString(json['title'], 'Question.title'),
    body: _readString(json['body'], 'Question.body'),
    tags: List<Tag>.unmodifiable(
      _readList(
        json['tags'],
        'Question.tags',
      ).map((Object? e0) => Tag.fromJson(_readObject(e0, 'Question.tags'))),
    ),
    answerCount: _readInt(json['answer_count'], 'Question.answer_count'),
    createdAt: _readDateTime(json['created_at'], 'Question.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Question.updated_at'),
    pool: QuestionPool.fromWire(_readString(json['pool'], 'Question.pool')),
    subjectKey: switch (json['subject_key']) {
      null => null,
      final Object v => _readString(v, 'Question.subject_key'),
    },
    topicKey: switch (json['topic_key']) {
      null => null,
      final Object v => _readString(v, 'Question.topic_key'),
    },
    photoUploadIds: List<String>.unmodifiable(
      _readList(
        json['photo_upload_ids'],
        'Question.photo_upload_ids',
      ).map((Object? e0) => _readString(e0, 'Question.photo_upload_ids')),
    ),
  );

  final String id;

  final String tayfaId;

  /// Yazarın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? authorUserId;

  /// Soru havuzunda boştur.
  final String title;

  final String body;

  /// Soru havuzunda boştur.
  final List<Tag> tags;

  /// Görünen cevap sayısı.
  final int answerCount;

  final DateTime createdAt;

  /// Her düzenleme ve geri almada değişir.
  final DateTime updatedAt;

  final QuestionPool pool;

  /// Soru havuzunda ders anahtarı (her zaman var); etiket sonradan emekliye ayrılmış olabilir.
  final String? subjectKey;

  /// Soru havuzunda konu anahtarı; yoksa alan yoktur.
  final String? topicKey;

  /// Soru havuzunda 0–2 fotoğraf (`question_pool` yüklemesi), sırasıyla; adreslerini `POST /v1/media/urls` verir. Soru-Cevap'ta boştur.
  ///
  /// Kısıtlar: maxItems: 2.
  final List<String> photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    if (authorUserId case final value?) 'author_user_id': value,
    'title': title,
    'body': body,
    'tags': <Object?>[for (final e0 in tags) e0.toJson()],
    'answer_count': answerCount,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'pool': pool.wire,
    if (subjectKey case final value?) 'subject_key': value,
    if (topicKey case final value?) 'topic_key': value,
    'photo_upload_ids': <Object?>[for (final e0 in photoUploadIds) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          authorUserId == other.authorUserId &&
          title == other.title &&
          body == other.body &&
          _deepEquals(tags, other.tags) &&
          answerCount == other.answerCount &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          pool == other.pool &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    authorUserId,
    title,
    body,
    _deepHash(tags),
    answerCount,
    createdAt,
    updatedAt,
    pool,
    subjectKey,
    topicKey,
    _deepHash(photoUploadIds),
  ]);
}

final class QuestionCreateRequest {
  const QuestionCreateRequest({
    this.pool,
    this.title,
    this.body,
    this.tags,
    required this.clientRequestId,
    this.subjectKey,
    this.topicKey,
    this.photoUploadIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory QuestionCreateRequest.fromJson(Map<String, Object?> json) =>
      QuestionCreateRequest(
        pool: switch (json['pool']) {
          null => null,
          final Object v => QuestionPool.fromWire(
            _readString(v, 'QuestionCreateRequest.pool'),
          ),
        },
        title: switch (json['title']) {
          null => null,
          final Object v => _readString(v, 'QuestionCreateRequest.title'),
        },
        body: switch (json['body']) {
          null => null,
          final Object v => _readString(v, 'QuestionCreateRequest.body'),
        },
        tags: switch (json['tags']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'QuestionCreateRequest.tags').map(
              (Object? e0) => _readString(e0, 'QuestionCreateRequest.tags'),
            ),
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'QuestionCreateRequest.client_request_id',
        ),
        subjectKey: switch (json['subject_key']) {
          null => null,
          final Object v => _readString(v, 'QuestionCreateRequest.subject_key'),
        },
        topicKey: switch (json['topic_key']) {
          null => null,
          final Object v => _readString(v, 'QuestionCreateRequest.topic_key'),
        },
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'QuestionCreateRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'QuestionCreateRequest.photo_upload_ids'),
            ),
          ),
        },
      );

  /// Yoksa `qa`.
  final QuestionPool? pool;

  /// `qa`'da zorunlu: baştaki ve sondaki boşluklar atıldıktan sonra 10–150 karakter, tek satır. Soru havuzunda verilmez.
  ///
  /// Kısıtlar: maxLength: 150.
  final String? title;

  /// En fazla 10000 karakter; satır sonu olabilir. Soru havuzunda metin ya da fotoğraftan biri zorunludur.
  ///
  /// Kısıtlar: maxLength: 10000.
  final String? body;

  /// Etiket adları; her biri 1–30 karakter, tek satır, iç boşluklar teke iner. Soru havuzunda verilmez.
  ///
  /// Kısıtlar: maxItems: 5.
  final List<String>? tags;

  /// İstemcinin her deneme için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// Soru havuzunda zorunlu; seçilebilir (etkin) bir ders.
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? subjectKey;

  /// Soru havuzunda isteğe bağlı; dersin altındaki seçilebilir bir konu.
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? topicKey;

  /// Soru havuzunda 0–2 fotoğraf (`question_pool` yüklemesi).
  ///
  /// Kısıtlar: maxItems: 2.
  final List<String>? photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (pool case final value?) 'pool': value.wire,
    if (title case final value?) 'title': value,
    if (body case final value?) 'body': value,
    if (tags case final value?) 'tags': <Object?>[for (final e0 in value) e0],
    'client_request_id': clientRequestId,
    if (subjectKey case final value?) 'subject_key': value,
    if (topicKey case final value?) 'topic_key': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionCreateRequest &&
          pool == other.pool &&
          title == other.title &&
          body == other.body &&
          _deepEquals(tags, other.tags) &&
          clientRequestId == other.clientRequestId &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    pool,
    title,
    body,
    _deepHash(tags),
    clientRequestId,
    subjectKey,
    topicKey,
    _deepHash(photoUploadIds),
  ]);
}

final class QuestionList {
  const QuestionList({required this.questions, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory QuestionList.fromJson(Map<String, Object?> json) => QuestionList(
    questions: List<Question>.unmodifiable(
      _readList(json['questions'], 'QuestionList.questions').map(
        (Object? e0) =>
            Question.fromJson(_readObject(e0, 'QuestionList.questions')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'QuestionList.next_page_token'),
    },
  );

  final List<Question> questions;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'questions': <Object?>[for (final e0 in questions) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionList &&
          _deepEquals(questions, other.questions) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(questions), nextPageToken]);
}

/// Sorunun havuzu (#271, ADR-0040 §2): `qa` tayfanın Soru-Cevap'ı
/// (`qa` modülü), `question_pool` Eğitim soru havuzu (`question_pool`
/// modülü). Sorunun havuzu değişmez; soru ve cevap uçları havuzun
/// modülü kapalıyken `module-disabled` döner.
enum QuestionPool {
  qa('qa'),
  questionPool('question_pool'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const QuestionPool(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('QuestionPool.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static QuestionPool fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Verilen alanlar değişir. `title` ve `tags` yalnızca Soru-Cevap'ta;
/// `subject_key` (`topic_key` ile birlikte; `topic_key` yoksa konu
/// kalkar) ve `photo_upload_ids` (fotoğrafların yeni hali; `[]` hepsini
/// kaldırır, kaldırılan dosya silinir) yalnızca soru havuzunda
/// geçerlidir; öbür havuzun alanı `invalid-request` döner.
///
/// Kısıtlar: minProperties: 1.
final class QuestionUpdateRequest {
  const QuestionUpdateRequest({
    this.title,
    this.body,
    this.tags,
    this.subjectKey,
    this.topicKey,
    this.photoUploadIds,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory QuestionUpdateRequest.fromJson(Map<String, Object?> json) =>
      QuestionUpdateRequest(
        title: switch (json['title']) {
          null => null,
          final Object v => _readString(v, 'QuestionUpdateRequest.title'),
        },
        body: switch (json['body']) {
          null => null,
          final Object v => _readString(v, 'QuestionUpdateRequest.body'),
        },
        tags: switch (json['tags']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'QuestionUpdateRequest.tags').map(
              (Object? e0) => _readString(e0, 'QuestionUpdateRequest.tags'),
            ),
          ),
        },
        subjectKey: switch (json['subject_key']) {
          null => null,
          final Object v => _readString(v, 'QuestionUpdateRequest.subject_key'),
        },
        topicKey: switch (json['topic_key']) {
          null => null,
          final Object v => _readString(v, 'QuestionUpdateRequest.topic_key'),
        },
        photoUploadIds: switch (json['photo_upload_ids']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'QuestionUpdateRequest.photo_upload_ids').map(
              (Object? e0) =>
                  _readString(e0, 'QuestionUpdateRequest.photo_upload_ids'),
            ),
          ),
        },
      );

  /// Kısıtlar: minLength: 10; maxLength: 150.
  final String? title;

  /// Kısıtlar: maxLength: 10000.
  final String? body;

  /// Kısıtlar: maxItems: 5.
  final List<String>? tags;

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? subjectKey;

  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  final String? topicKey;

  /// Kısıtlar: maxItems: 2.
  final List<String>? photoUploadIds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (title case final value?) 'title': value,
    if (body case final value?) 'body': value,
    if (tags case final value?) 'tags': <Object?>[for (final e0 in value) e0],
    if (subjectKey case final value?) 'subject_key': value,
    if (topicKey case final value?) 'topic_key': value,
    if (photoUploadIds case final value?)
      'photo_upload_ids': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionUpdateRequest &&
          title == other.title &&
          body == other.body &&
          _deepEquals(tags, other.tags) &&
          subjectKey == other.subjectKey &&
          topicKey == other.topicKey &&
          _deepEquals(photoUploadIds, other.photoUploadIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    title,
    body,
    _deepHash(tags),
    subjectKey,
    topicKey,
    _deepHash(photoUploadIds),
  ]);
}

final class Recurrence {
  const Recurrence({required this.rrule, this.timeZone});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Recurrence.fromJson(Map<String, Object?> json) => Recurrence(
    rrule: _readString(json['rrule'], 'Recurrence.rrule'),
    timeZone: switch (json['time_zone']) {
      null => null,
      final Object v => _readString(v, 'Recurrence.time_zone'),
    },
  );

  /// RFC 5545 RRULE alt kümesi: `FREQ=WEEKLY|MONTHLY`, `INTERVAL=1..52`,
  /// `BYDAY` (aylıkta sıralı: `2SA`, `-1FR`), `COUNT=1..500` ya da
  /// `UNTIL=YYYYMMDDTHHMMSSZ` (en fazla beş yıl), `WKST=MO`.
  /// `starts_at` ilk tekrardır ve kurala uymalıdır.
  ///
  /// Kısıtlar: maxLength: 256.
  final String rrule;

  /// IANA adı; boşsa `Europe/Istanbul`. Yerel saat yaz saatinde korunur.
  ///
  /// Kısıtlar: maxLength: 64.
  final String? timeZone;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'rrule': rrule,
    if (timeZone case final value?) 'time_zone': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recurrence && rrule == other.rrule && timeZone == other.timeZone;

  @override
  int get hashCode => Object.hashAll(<Object?>[rrule, timeZone]);
}

final class ReferralCode {
  const ReferralCode({required this.referralCode});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ReferralCode.fromJson(Map<String, Object?> json) => ReferralCode(
    referralCode: _readString(
      json['referral_code'],
      'ReferralCode.referral_code',
    ),
  );

  final String referralCode;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'referral_code': referralCode,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferralCode && referralCode == other.referralCode;

  @override
  int get hashCode => Object.hashAll(<Object?>[referralCode]);
}

final class ReferralLookupRequest {
  const ReferralLookupRequest({required this.referralCode});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ReferralLookupRequest.fromJson(Map<String, Object?> json) =>
      ReferralLookupRequest(
        referralCode: _readString(
          json['referral_code'],
          'ReferralLookupRequest.referral_code',
        ),
      );

  /// `TYF-` öneki ve büyük/küçük harf fark etmez.
  ///
  /// Kısıtlar: maxLength: 32.
  final String referralCode;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'referral_code': referralCode,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferralLookupRequest && referralCode == other.referralCode;

  @override
  int get hashCode => Object.hashAll(<Object?>[referralCode]);
}

final class ReferredUser {
  const ReferredUser({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ReferredUser.fromJson(Map<String, Object?> json) => ReferredUser(
    userId: _readString(json['user_id'], 'ReferredUser.user_id'),
    displayName: _readString(json['display_name'], 'ReferredUser.display_name'),
    avatarUploadId: switch (json['avatar_upload_id']) {
      null => null,
      final Object v => _readString(v, 'ReferredUser.avatar_upload_id'),
    },
  );

  final String userId;

  final String displayName;

  final String? avatarUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferredUser &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[userId, displayName, avatarUploadId]);
}

final class RefreshRequest {
  const RefreshRequest({required this.refreshToken, this.integrityToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RefreshRequest.fromJson(Map<String, Object?> json) => RefreshRequest(
    refreshToken: _readString(
      json['refresh_token'],
      'RefreshRequest.refresh_token',
    ),
    integrityToken: switch (json['integrity_token']) {
      null => null,
      final Object v => _readString(v, 'RefreshRequest.integrity_token'),
    },
  );

  /// Kısıtlar: maxLength: 64.
  final String refreshToken;

  /// İsteğe bağlı, Android: Play Integrity token'ı; yalnızca
  /// `integrity_check_after` geçtiyse gönderilir, öncesinde yok
  /// sayılır (ADR-0022). `requestHash` =
  /// base64url(SHA-256("tayfam-integrity/v1/refresh\n" + SHA-256(refresh_token))), dolgusuz;
  /// iç özet ham bayttır.
  ///
  /// Kısıtlar: maxLength: 16384.
  final String? integrityToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'refresh_token': refreshToken,
    if (integrityToken case final value?) 'integrity_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefreshRequest &&
          refreshToken == other.refreshToken &&
          integrityToken == other.integrityToken;

  @override
  int get hashCode => Object.hashAll(<Object?>[refreshToken, integrityToken]);
}

final class RegistrationRequest {
  const RegistrationRequest({
    required this.birthDate,
    this.displayName,
    required this.acceptedPrivacyNoticeVersion,
    required this.acceptedTermsVersion,
    this.referralCode,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RegistrationRequest.fromJson(Map<String, Object?> json) =>
      RegistrationRequest(
        birthDate: _readString(
          json['birth_date'],
          'RegistrationRequest.birth_date',
        ),
        displayName: switch (json['display_name']) {
          null => null,
          final Object v => _readString(v, 'RegistrationRequest.display_name'),
        },
        acceptedPrivacyNoticeVersion: _readString(
          json['accepted_privacy_notice_version'],
          'RegistrationRequest.accepted_privacy_notice_version',
        ),
        acceptedTermsVersion: _readString(
          json['accepted_terms_version'],
          'RegistrationRequest.accepted_terms_version',
        ),
        referralCode: switch (json['referral_code']) {
          null => null,
          final Object v => _readString(v, 'RegistrationRequest.referral_code'),
        },
      );

  /// Kısıtlar: biçim: `YYYY-AA-GG` (saat dilimsiz tarih).
  final String birthDate;

  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String? displayName;

  /// Kısıtlar: maxLength: 32.
  final String acceptedPrivacyNoticeVersion;

  /// Kısıtlar: maxLength: 32.
  final String acceptedTermsVersion;

  /// İsteğe bağlı; uygulamaya getiren kişinin referans kodu (Android'de
  /// mağaza referansı, iOS'ta elle). Bir kez kaydedilir; kimseyi
  /// bulmayan kod hata vermeden yok sayılır.
  ///
  /// Kısıtlar: maxLength: 32.
  final String? referralCode;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'birth_date': birthDate,
    if (displayName case final value?) 'display_name': value,
    'accepted_privacy_notice_version': acceptedPrivacyNoticeVersion,
    'accepted_terms_version': acceptedTermsVersion,
    if (referralCode case final value?) 'referral_code': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistrationRequest &&
          birthDate == other.birthDate &&
          displayName == other.displayName &&
          acceptedPrivacyNoticeVersion == other.acceptedPrivacyNoticeVersion &&
          acceptedTermsVersion == other.acceptedTermsVersion &&
          referralCode == other.referralCode;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    birthDate,
    displayName,
    acceptedPrivacyNoticeVersion,
    acceptedTermsVersion,
    referralCode,
  ]);
}

final class RegistrationRequirements {
  const RegistrationRequirements({
    required this.privacyNoticeVersion,
    required this.termsVersion,
    required this.minimumAge,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RegistrationRequirements.fromJson(Map<String, Object?> json) =>
      RegistrationRequirements(
        privacyNoticeVersion: _readString(
          json['privacy_notice_version'],
          'RegistrationRequirements.privacy_notice_version',
        ),
        termsVersion: _readString(
          json['terms_version'],
          'RegistrationRequirements.terms_version',
        ),
        minimumAge: _readInt(
          json['minimum_age'],
          'RegistrationRequirements.minimum_age',
        ),
      );

  final String privacyNoticeVersion;

  final String termsVersion;

  final int minimumAge;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'privacy_notice_version': privacyNoticeVersion,
    'terms_version': termsVersion,
    'minimum_age': minimumAge,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistrationRequirements &&
          privacyNoticeVersion == other.privacyNoticeVersion &&
          termsVersion == other.termsVersion &&
          minimumAge == other.minimumAge;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[privacyNoticeVersion, termsVersion, minimumAge]);
}

final class ReportCreateRequest {
  const ReportCreateRequest({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    this.evidenceText,
    this.evidenceUploadId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ReportCreateRequest.fromJson(Map<String, Object?> json) =>
      ReportCreateRequest(
        targetType: ReportTargetType.fromWire(
          _readString(json['target_type'], 'ReportCreateRequest.target_type'),
        ),
        targetId: _readString(
          json['target_id'],
          'ReportCreateRequest.target_id',
        ),
        reason: ReportReason.fromWire(
          _readString(json['reason'], 'ReportCreateRequest.reason'),
        ),
        description: switch (json['description']) {
          null => null,
          final Object v => _readString(v, 'ReportCreateRequest.description'),
        },
        evidenceText: switch (json['evidence_text']) {
          null => null,
          final Object v => _readString(v, 'ReportCreateRequest.evidence_text'),
        },
        evidenceUploadId: switch (json['evidence_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'ReportCreateRequest.evidence_upload_id',
          ),
        },
      );

  final ReportTargetType targetType;

  /// `tayfa` için yoldaki `tayfa_id` ile aynı olmalıdır.
  final String targetId;

  final ReportReason reason;

  /// İsteğe bağlı; baştaki ve sondaki boşluklar atılır. Satır sonu olabilir.
  ///
  /// Kısıtlar: maxLength: 1000.
  final String? description;

  /// Yalnızca `dm_message` için (kullanıcı şikâyetinde yoktur;
  /// `evidence_upload_id` yoksa zorunlu): şikâyet ettiğiniz
  /// mesajın kendi cihazınızdan paylaştığınız metni. Yalnızca platform
  /// okur; log'a ve olaylara yazılmaz, size geri dönmez.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 2000.
  final String? evidenceText;

  /// Yalnızca `dm_message` için (#205): şikâyet ettiğiniz fotoğrafı
  /// kendi cihazınızdan `report_evidence` yüklemesi olarak (metadata'sız
  /// iki varyant) yükleyip burada verirsiniz. Hazır, kendi ve
  /// kullanılmamış olmalıdır (`upload-not-found`, `upload-not-ready`,
  /// `upload-in-use`). Yalnızca platform paneli görür.
  final String? evidenceUploadId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'target_type': targetType.wire,
    'target_id': targetId,
    'reason': reason.wire,
    if (description case final value?) 'description': value,
    if (evidenceText case final value?) 'evidence_text': value,
    if (evidenceUploadId case final value?) 'evidence_upload_id': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportCreateRequest &&
          targetType == other.targetType &&
          targetId == other.targetId &&
          reason == other.reason &&
          description == other.description &&
          evidenceText == other.evidenceText &&
          evidenceUploadId == other.evidenceUploadId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    targetType,
    targetId,
    reason,
    description,
    evidenceText,
    evidenceUploadId,
  ]);
}

/// Topluluk Kuralları'na göre. `child_safety` (çocuk/genç güvenliği)
/// kuyrukta öne geçer ve hemen platforma da gider; `staff_conduct`
/// (yönetici/moderatörün yetkisini kullanımı) yalnızca platforma gider.
/// `paid_tutoring` ücretli özel ders teklifi ya da reklamıdır (#271,
/// ADR-0040 §2).
enum ReportReason {
  harassment('harassment'),
  hateSpeech('hate_speech'),
  violence('violence'),
  privacy('privacy'),
  impersonation('impersonation'),
  illegalTrade('illegal_trade'),
  drugs('drugs'),
  gambling('gambling'),
  dangerousActivity('dangerous_activity'),
  fakeEvent('fake_event'),
  sexualContent('sexual_content'),
  childSafety('child_safety'),
  spam('spam'),
  copyright('copyright'),
  staffConduct('staff_conduct'),
  other('other'),
  paidTutoring('paid_tutoring'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ReportReason(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ReportReason.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ReportReason fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class ReportResolveRequest {
  const ReportResolveRequest({required this.resolution});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ReportResolveRequest.fromJson(Map<String, Object?> json) =>
      ReportResolveRequest(
        resolution: ReportResolveRequestResolution.fromWire(
          _readString(json['resolution'], 'ReportResolveRequest.resolution'),
        ),
      );

  final ReportResolveRequestResolution resolution;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'resolution': resolution.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportResolveRequest && resolution == other.resolution;

  @override
  int get hashCode => Object.hashAll(<Object?>[resolution]);
}

enum ReportResolveRequestResolution {
  contentRemoved('content_removed'),
  memberSanctioned('member_sanctioned'),
  dismissed('dismissed'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ReportResolveRequestResolution(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('ReportResolveRequestResolution.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ReportResolveRequestResolution fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `dm_message` (birebir mesaj) yalnızca `POST /v1/me/reports` ile;
/// diğerleri yalnızca tayfa ucuyla. `channel_message` kanal mesajıdır
/// (metin, fotoğraf ya da yer; #205). `log_entry` bir günlük bileşeni
/// kaydıdır (#243; eskiden `fishing_catch`). `event_question` soru
/// toplama bileşenindeki bir sorudur (#256); anonim sorunun yazarı
/// tayfa kuyruğunda yer almaz (`subject_user_id` yoktur), yalnızca
/// platform yönetimine görünür. `daily_item` günün içeriği havuzundaki
/// bir içeriktir (#269); `daily` modülü açık olmalıdır. `library_item`
/// ortak kütüphanedeki bir kalemdir (#270; konusu sahibidir); `library`
/// modülü açık, kalem geri çekilmemiş olmalıdır. `material` materyal
/// kütüphanesindeki bir materyaldir (#261; konusu yazarıdır);
/// `materials` modülü açık, materyal görünür olmalıdır.
/// `garage_vehicle` üye garajındaki bir araçtır (#272; konusu
/// sahibidir); `garage` modülü açık, araç bu tayfada görünür olmalıdır.
enum ReportTargetType {
  user('user'),
  tayfa('tayfa'),
  announcement('announcement'),
  event('event'),
  question('question'),
  answer('answer'),
  poll('poll'),
  logEntry('log_entry'),
  dmMessage('dm_message'),
  eventPhoto('event_photo'),
  channelMessage('channel_message'),
  eventQuestion('event_question'),
  dailyItem('daily_item'),
  libraryItem('library_item'),
  material('material'),
  garageVehicle('garage_vehicle'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ReportTargetType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ReportTargetType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ReportTargetType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class RevokedSessions {
  const RevokedSessions({required this.revokedCount});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RevokedSessions.fromJson(Map<String, Object?> json) =>
      RevokedSessions(
        revokedCount: _readInt(
          json['revoked_count'],
          'RevokedSessions.revoked_count',
        ),
      );

  /// Kısıtlar: minimum: 0.
  final int revokedCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'revoked_count': revokedCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RevokedSessions && revokedCount == other.revokedCount;

  @override
  int get hashCode => Object.hashAll(<Object?>[revokedCount]);
}

enum Role {
  member('member'),
  moderator('moderator'),
  admin('admin'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const Role(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire => _wire ?? (throw StateError('Role.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static Role fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class RoleUpdate {
  const RoleUpdate({required this.role});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RoleUpdate.fromJson(Map<String, Object?> json) => RoleUpdate(
    role: Role.fromWire(_readString(json['role'], 'RoleUpdate.role')),
  );

  final Role role;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'role': role.wire};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RoleUpdate && role == other.role;

  @override
  int get hashCode => Object.hashAll(<Object?>[role]);
}

final class RollCallEntry {
  const RollCallEntry({
    required this.userId,
    required this.startedAt,
    this.returnedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RollCallEntry.fromJson(Map<String, Object?> json) => RollCallEntry(
    userId: _readString(json['user_id'], 'RollCallEntry.user_id'),
    startedAt: _readDateTime(json['started_at'], 'RollCallEntry.started_at'),
    returnedAt: switch (json['returned_at']) {
      null => null,
      final Object v => _readDateTime(v, 'RollCallEntry.returned_at'),
    },
  );

  final String userId;

  /// İstemcinin bildirdiği çıkış anı.
  final DateTime startedAt;

  /// İstemcinin bildirdiği dönüş anı; dışarıdayken yoktur.
  final DateTime? returnedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'started_at': startedAt.toUtc().toIso8601String(),
    if (returnedAt case final value?)
      'returned_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RollCallEntry &&
          userId == other.userId &&
          startedAt == other.startedAt &&
          returnedAt == other.returnedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId, startedAt, returnedAt]);
}

final class RollCallPlanRequest {
  const RollCallPlanRequest({this.expectedReturnAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RollCallPlanRequest.fromJson(Map<String, Object?> json) =>
      RollCallPlanRequest(
        expectedReturnAt: switch (json['expected_return_at']) {
          null => null,
          final Object v => _readDateTime(
            v,
            'RollCallPlanRequest.expected_return_at',
          ),
        },
      );

  /// Etkinliğin başlangıcından sonra. Yoksa (ya da `null`) plan kaldırılır.
  final DateTime? expectedReturnAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (expectedReturnAt case final value?)
      'expected_return_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RollCallPlanRequest &&
          expectedReturnAt == other.expectedReturnAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[expectedReturnAt]);
}

final class RollCallReturnRequest {
  const RollCallReturnRequest({this.returnedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RollCallReturnRequest.fromJson(Map<String, Object?> json) =>
      RollCallReturnRequest(
        returnedAt: switch (json['returned_at']) {
          null => null,
          final Object v => _readDateTime(
            v,
            'RollCallReturnRequest.returned_at',
          ),
        },
      );

  /// İstemcinin dönüş zamanı; yoksa şimdi. Çıkıştan önce olamaz.
  final DateTime? returnedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (returnedAt case final value?)
      'returned_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RollCallReturnRequest && returnedAt == other.returnedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[returnedAt]);
}

final class RollCallStartRequest {
  const RollCallStartRequest({this.startedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RollCallStartRequest.fromJson(Map<String, Object?> json) =>
      RollCallStartRequest(
        startedAt: switch (json['started_at']) {
          null => null,
          final Object v => _readDateTime(v, 'RollCallStartRequest.started_at'),
        },
      );

  /// İstemcinin çıkış zamanı; yoksa şimdi. Gelecekte değil, en fazla 48 saat önce.
  final DateTime? startedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (startedAt case final value?)
      'started_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RollCallStartRequest && startedAt == other.startedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[startedAt]);
}

final class Rsvp {
  const Rsvp({required this.status});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Rsvp.fromJson(Map<String, Object?> json) => Rsvp(
    status: RsvpStatus.fromWire(_readString(json['status'], 'Rsvp.status')),
  );

  final RsvpStatus status;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'status': status.wire};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Rsvp && status == other.status;

  @override
  int get hashCode => Object.hashAll(<Object?>[status]);
}

final class RsvpRequest {
  const RsvpRequest({required this.status});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RsvpRequest.fromJson(Map<String, Object?> json) => RsvpRequest(
    status: RsvpRequestStatus.fromWire(
      _readString(json['status'], 'RsvpRequest.status'),
    ),
  );

  final RsvpRequestStatus status;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'status': status.wire};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RsvpRequest && status == other.status;

  @override
  int get hashCode => Object.hashAll(<Object?>[status]);
}

enum RsvpRequestStatus {
  going('going'),
  maybe('maybe'),
  notGoing('not_going'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const RsvpRequestStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('RsvpRequestStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static RsvpRequestStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `waitlist` yalnızca sunucu tarafından verilir (dolu etkinlikte `going`).
enum RsvpStatus {
  going('going'),
  maybe('maybe'),
  notGoing('not_going'),
  waitlist('waitlist'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const RsvpStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('RsvpStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static RsvpStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class SafetyContact {
  const SafetyContact({
    this.contact,
    required this.graceMinutes,
    this.returnedAt,
    this.alertSentAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SafetyContact.fromJson(Map<String, Object?> json) => SafetyContact(
    contact: switch (json['contact']) {
      null => null,
      final Object v => DiscoverPerson.fromJson(
        _readObject(v, 'SafetyContact.contact'),
      ),
    },
    graceMinutes: _readInt(
      json['grace_minutes'],
      'SafetyContact.grace_minutes',
    ),
    returnedAt: switch (json['returned_at']) {
      null => null,
      final Object v => _readDateTime(v, 'SafetyContact.returned_at'),
    },
    alertSentAt: switch (json['alert_sent_at']) {
      null => null,
      final Object v => _readDateTime(v, 'SafetyContact.alert_sent_at'),
    },
  );

  final DiscoverPerson? contact;

  /// Seçilmemişse 0.
  ///
  /// Kısıtlar: minimum: 0; maximum: 1440.
  final int graceMinutes;

  final DateTime? returnedAt;

  final DateTime? alertSentAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (contact case final value?) 'contact': value.toJson(),
    'grace_minutes': graceMinutes,
    if (returnedAt case final value?)
      'returned_at': value.toUtc().toIso8601String(),
    if (alertSentAt case final value?)
      'alert_sent_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetyContact &&
          contact == other.contact &&
          graceMinutes == other.graceMinutes &&
          returnedAt == other.returnedAt &&
          alertSentAt == other.alertSentAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[contact, graceMinutes, returnedAt, alertSentAt]);
}

final class SafetyContactInput {
  const SafetyContactInput({required this.contactUserId, this.graceMinutes});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SafetyContactInput.fromJson(Map<String, Object?> json) =>
      SafetyContactInput(
        contactUserId: _readString(
          json['contact_user_id'],
          'SafetyContactInput.contact_user_id',
        ),
        graceMinutes: switch (json['grace_minutes']) {
          null => null,
          final Object v => _readInt(v, 'SafetyContactInput.grace_minutes'),
        },
      );

  final String contactUserId;

  /// Bitişten sonra beklenecek dakika; yoksa 60.
  ///
  /// Kısıtlar: minimum: 15; maximum: 1440.
  final int? graceMinutes;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'contact_user_id': contactUserId,
    if (graceMinutes case final value?) 'grace_minutes': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetyContactInput &&
          contactUserId == other.contactUserId &&
          graceMinutes == other.graceMinutes;

  @override
  int get hashCode => Object.hashAll(<Object?>[contactUserId, graceMinutes]);
}

/// Katılımcının güvenlik kişisiyle paylaştığı en az bilgi: kim, saat
/// aralığı (başlangıç, bitiş, tolerans) ve durum. Tayfa, etkinlik
/// başlığı ya da kimliği, buluşma yeri, il/ilçe ve koordinat yoktur.
final class SafetyShare {
  const SafetyShare({
    required this.participant,
    required this.startsAt,
    required this.endsAt,
    required this.graceMinutes,
    this.returnedAt,
    this.alertSentAt,
    required this.state,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SafetyShare.fromJson(Map<String, Object?> json) => SafetyShare(
    participant: DiscoverPerson.fromJson(
      _readObject(json['participant'], 'SafetyShare.participant'),
    ),
    startsAt: _readDateTime(json['starts_at'], 'SafetyShare.starts_at'),
    endsAt: _readDateTime(json['ends_at'], 'SafetyShare.ends_at'),
    graceMinutes: _readInt(json['grace_minutes'], 'SafetyShare.grace_minutes'),
    returnedAt: switch (json['returned_at']) {
      null => null,
      final Object v => _readDateTime(v, 'SafetyShare.returned_at'),
    },
    alertSentAt: switch (json['alert_sent_at']) {
      null => null,
      final Object v => _readDateTime(v, 'SafetyShare.alert_sent_at'),
    },
    state: SafetyShareState.fromWire(
      _readString(json['state'], 'SafetyShare.state'),
    ),
  );

  final DiscoverPerson participant;

  final DateTime startsAt;

  final DateTime endsAt;

  /// Alarm `ends_at` + bu süre sonunda gider.
  final int graceMinutes;

  final DateTime? returnedAt;

  final DateTime? alertSentAt;

  /// `not_returned`: henüz dönmedi, alarm gitmedi. `returned`: "Döndüm"
  /// dedi (alarmdan sonra da olabilir). `alert_sent`: alarm gitti,
  /// "Döndüm" yok.
  final SafetyShareState state;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'participant': participant.toJson(),
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'grace_minutes': graceMinutes,
    if (returnedAt case final value?)
      'returned_at': value.toUtc().toIso8601String(),
    if (alertSentAt case final value?)
      'alert_sent_at': value.toUtc().toIso8601String(),
    'state': state.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetyShare &&
          participant == other.participant &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          graceMinutes == other.graceMinutes &&
          returnedAt == other.returnedAt &&
          alertSentAt == other.alertSentAt &&
          state == other.state;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    participant,
    startsAt,
    endsAt,
    graceMinutes,
    returnedAt,
    alertSentAt,
    state,
  ]);
}

final class SafetyShareList {
  const SafetyShareList({required this.shares});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SafetyShareList.fromJson(Map<String, Object?> json) =>
      SafetyShareList(
        shares: List<SafetyShare>.unmodifiable(
          _readList(json['shares'], 'SafetyShareList.shares').map(
            (Object? e0) =>
                SafetyShare.fromJson(_readObject(e0, 'SafetyShareList.shares')),
          ),
        ),
      );

  /// Kısıtlar: maxItems: 50.
  final List<SafetyShare> shares;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'shares': <Object?>[for (final e0 in shares) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetyShareList && _deepEquals(shares, other.shares);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(shares)]);
}

/// `not_returned`: henüz dönmedi, alarm gitmedi. `returned`: "Döndüm"
/// dedi (alarmdan sonra da olabilir). `alert_sent`: alarm gitti,
/// "Döndüm" yok.
enum SafetyShareState {
  notReturned('not_returned'),
  returned('returned'),
  alertSent('alert_sent'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const SafetyShareState(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('SafetyShareState.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SafetyShareState fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Session {
  const Session({
    required this.userId,
    required this.sessionId,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.registrationPending,
    this.consentRequired,
    this.integrityCheckAfter,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Session.fromJson(Map<String, Object?> json) => Session(
    userId: _readString(json['user_id'], 'Session.user_id'),
    sessionId: _readString(json['session_id'], 'Session.session_id'),
    accessToken: _readString(json['access_token'], 'Session.access_token'),
    accessExpiresAt: _readDateTime(
      json['access_expires_at'],
      'Session.access_expires_at',
    ),
    refreshToken: _readString(json['refresh_token'], 'Session.refresh_token'),
    refreshExpiresAt: _readDateTime(
      json['refresh_expires_at'],
      'Session.refresh_expires_at',
    ),
    registrationPending: _readBool(
      json['registration_pending'],
      'Session.registration_pending',
    ),
    consentRequired: switch (json['consent_required']) {
      null => null,
      final Object v => _readBool(v, 'Session.consent_required'),
    },
    integrityCheckAfter: switch (json['integrity_check_after']) {
      null => null,
      final Object v => _readDateTime(v, 'Session.integrity_check_after'),
    },
  );

  final String userId;

  final String sessionId;

  final String accessToken;

  final DateTime accessExpiresAt;

  final String refreshToken;

  final DateTime refreshExpiresAt;

  final bool registrationPending;

  /// Kayıtlı kullanıcı aydınlatma metninin veya kullanım koşullarının
  /// güncel sürümünü onaylamamış. İstemci `/v1/me/consents` ile
  /// yeni metinleri gösterip onay alır.
  final bool? consentRequired;

  /// Bu zamandan sonraki ilk yenilemede `integrity_token` gönderilir
  /// (ADR-0022). Bütünlük denetimi kapalıyken alan yoktur.
  final DateTime? integrityCheckAfter;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'session_id': sessionId,
    'access_token': accessToken,
    'access_expires_at': accessExpiresAt.toUtc().toIso8601String(),
    'refresh_token': refreshToken,
    'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
    'registration_pending': registrationPending,
    if (consentRequired case final value?) 'consent_required': value,
    if (integrityCheckAfter case final value?)
      'integrity_check_after': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          userId == other.userId &&
          sessionId == other.sessionId &&
          accessToken == other.accessToken &&
          accessExpiresAt == other.accessExpiresAt &&
          refreshToken == other.refreshToken &&
          refreshExpiresAt == other.refreshExpiresAt &&
          registrationPending == other.registrationPending &&
          consentRequired == other.consentRequired &&
          integrityCheckAfter == other.integrityCheckAfter;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    sessionId,
    accessToken,
    accessExpiresAt,
    refreshToken,
    refreshExpiresAt,
    registrationPending,
    consentRequired,
    integrityCheckAfter,
  ]);
}

final class SignInRequest {
  const SignInRequest({
    required this.provider,
    required this.idToken,
    required this.nonce,
    required this.platform,
    this.integrityToken,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SignInRequest.fromJson(Map<String, Object?> json) => SignInRequest(
    provider: SignInRequestProvider.fromWire(
      _readString(json['provider'], 'SignInRequest.provider'),
    ),
    idToken: _readString(json['id_token'], 'SignInRequest.id_token'),
    nonce: _readString(json['nonce'], 'SignInRequest.nonce'),
    platform: SignInRequestPlatform.fromWire(
      _readString(json['platform'], 'SignInRequest.platform'),
    ),
    integrityToken: switch (json['integrity_token']) {
      null => null,
      final Object v => _readString(v, 'SignInRequest.integrity_token'),
    },
  );

  final SignInRequestProvider provider;

  /// Kısıtlar: maxLength: 8192.
  final String idToken;

  /// Kısıtlar: minLength: 16; maxLength: 256.
  final String nonce;

  /// `web` yalnızca prod dışında (ADR-0017).
  final SignInRequestPlatform platform;

  /// İsteğe bağlı, Android: Play Integrity standard request token'ı
  /// (ADR-0022). `requestHash` = base64url(SHA-256("tayfam-integrity/v1/sign-in\n" + nonce)),
  /// dolgusuz.
  ///
  /// Kısıtlar: maxLength: 16384.
  final String? integrityToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'provider': provider.wire,
    'id_token': idToken,
    'nonce': nonce,
    'platform': platform.wire,
    if (integrityToken case final value?) 'integrity_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInRequest &&
          provider == other.provider &&
          idToken == other.idToken &&
          nonce == other.nonce &&
          platform == other.platform &&
          integrityToken == other.integrityToken;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    provider,
    idToken,
    nonce,
    platform,
    integrityToken,
  ]);
}

/// `web` yalnızca prod dışında (ADR-0017).
enum SignInRequestPlatform {
  android('android'),
  ios('ios'),
  web('web'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const SignInRequestPlatform(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('SignInRequestPlatform.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SignInRequestPlatform fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

enum SignInRequestProvider {
  google('google'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const SignInRequestProvider(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('SignInRequestProvider.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SignInRequestProvider fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Yalnızca kullanıcı adı; bağlantıyı istemci platformun bilinen
/// adresinden kurar. URL kabul edilmez. Kurallar: `instagram`
/// `^[A-Za-z0-9._]{1,30}$`, `x` `^[A-Za-z0-9_]{1,15}$`, `tiktok`
/// `^[A-Za-z0-9._]{2,24}$`, `youtube` `^[A-Za-z0-9._-]{3,30}$` (baştaki
/// `@` atılır). Platform başına bir hesap.
final class SocialAccount {
  const SocialAccount({required this.platform, required this.username});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SocialAccount.fromJson(Map<String, Object?> json) => SocialAccount(
    platform: SocialAccountPlatform.fromWire(
      _readString(json['platform'], 'SocialAccount.platform'),
    ),
    username: _readString(json['username'], 'SocialAccount.username'),
  );

  final SocialAccountPlatform platform;

  /// Kısıtlar: maxLength: 31.
  final String username;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'platform': platform.wire,
    'username': username,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialAccount &&
          platform == other.platform &&
          username == other.username;

  @override
  int get hashCode => Object.hashAll(<Object?>[platform, username]);
}

enum SocialAccountPlatform {
  instagram('instagram'),
  x('x'),
  tiktok('tiktok'),
  youtube('youtube'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const SocialAccountPlatform(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('SocialAccountPlatform.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SocialAccountPlatform fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class SocialSettings {
  const SocialSettings({
    required this.profilingEnabled,
    required this.hideFromSuggestions,
    required this.discoverVisibleToFriends,
    required this.nowFromFriends,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SocialSettings.fromJson(Map<String, Object?> json) => SocialSettings(
    profilingEnabled: _readBool(
      json['profiling_enabled'],
      'SocialSettings.profiling_enabled',
    ),
    hideFromSuggestions: _readBool(
      json['hide_from_suggestions'],
      'SocialSettings.hide_from_suggestions',
    ),
    discoverVisibleToFriends: _readBool(
      json['discover_visible_to_friends'],
      'SocialSettings.discover_visible_to_friends',
    ),
    nowFromFriends: SocialSettingsNowFromFriends.fromWire(
      _readString(json['now_from_friends'], 'SocialSettings.now_from_friends'),
    ),
  );

  /// "Profilleme": ortak katılımdan arkadaşlık puanı hesaplanır ve öneri yapılır.
  final bool profilingEnabled;

  /// "Beni önerme": kimseye önerilmezsiniz.
  final bool hideFromSuggestions;

  /// "Keşfet'te arkadaşlarım görebilsin" (varsayılan açık): bir
  /// etkinliğe gideceğiniz ya da katıldığınız, arkadaşlarınıza
  /// Keşfet'te gösterilebilir. Katılım geçmişiniz `private` ise bu
  /// ayar açık olsa da gösterilmez.
  final bool discoverVisibleToFriends;

  /// "Şimdi bildirimi kimden" (ADR-0038 §4; varsayılan `all`):
  /// arkadaşlarınızın anlık şimdi etkinliklerinden hangilerinin size
  /// bildirileceği. `close`: yalnızca arkadaş listenizin ilk 20'sindeki
  /// arkadaşlarınızdan (`GET /v1/me/friends` sırası); profilleme
  /// kapalıyken sıra puansız olduğu için `all` gibi davranır. `off`:
  /// hiçbirinden; gönderene söylenmez. Tanınmayan değer `unknown`.
  final SocialSettingsNowFromFriends nowFromFriends;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'profiling_enabled': profilingEnabled,
    'hide_from_suggestions': hideFromSuggestions,
    'discover_visible_to_friends': discoverVisibleToFriends,
    'now_from_friends': nowFromFriends.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialSettings &&
          profilingEnabled == other.profilingEnabled &&
          hideFromSuggestions == other.hideFromSuggestions &&
          discoverVisibleToFriends == other.discoverVisibleToFriends &&
          nowFromFriends == other.nowFromFriends;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    profilingEnabled,
    hideFromSuggestions,
    discoverVisibleToFriends,
    nowFromFriends,
  ]);
}

/// "Şimdi bildirimi kimden" (ADR-0038 §4; varsayılan `all`):
/// arkadaşlarınızın anlık şimdi etkinliklerinden hangilerinin size
/// bildirileceği. `close`: yalnızca arkadaş listenizin ilk 20'sindeki
/// arkadaşlarınızdan (`GET /v1/me/friends` sırası); profilleme
/// kapalıyken sıra puansız olduğu için `all` gibi davranır. `off`:
/// hiçbirinden; gönderene söylenmez. Tanınmayan değer `unknown`.
enum SocialSettingsNowFromFriends {
  all('all'),
  close('close'),
  off('off'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const SocialSettingsNowFromFriends(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('SocialSettingsNowFromFriends.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SocialSettingsNowFromFriends fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kısıtlar: minProperties: 1.
final class SocialSettingsUpdate {
  const SocialSettingsUpdate({
    this.profilingEnabled,
    this.hideFromSuggestions,
    this.discoverVisibleToFriends,
    this.nowFromFriends,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SocialSettingsUpdate.fromJson(Map<String, Object?> json) =>
      SocialSettingsUpdate(
        profilingEnabled: switch (json['profiling_enabled']) {
          null => null,
          final Object v => _readBool(
            v,
            'SocialSettingsUpdate.profiling_enabled',
          ),
        },
        hideFromSuggestions: switch (json['hide_from_suggestions']) {
          null => null,
          final Object v => _readBool(
            v,
            'SocialSettingsUpdate.hide_from_suggestions',
          ),
        },
        discoverVisibleToFriends: switch (json['discover_visible_to_friends']) {
          null => null,
          final Object v => _readBool(
            v,
            'SocialSettingsUpdate.discover_visible_to_friends',
          ),
        },
        nowFromFriends: switch (json['now_from_friends']) {
          null => null,
          final Object v => SocialSettingsUpdateNowFromFriends.fromWire(
            _readString(v, 'SocialSettingsUpdate.now_from_friends'),
          ),
        },
      );

  final bool? profilingEnabled;

  final bool? hideFromSuggestions;

  final bool? discoverVisibleToFriends;

  final SocialSettingsUpdateNowFromFriends? nowFromFriends;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (profilingEnabled case final value?) 'profiling_enabled': value,
    if (hideFromSuggestions case final value?) 'hide_from_suggestions': value,
    if (discoverVisibleToFriends case final value?)
      'discover_visible_to_friends': value,
    if (nowFromFriends case final value?) 'now_from_friends': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialSettingsUpdate &&
          profilingEnabled == other.profilingEnabled &&
          hideFromSuggestions == other.hideFromSuggestions &&
          discoverVisibleToFriends == other.discoverVisibleToFriends &&
          nowFromFriends == other.nowFromFriends;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    profilingEnabled,
    hideFromSuggestions,
    discoverVisibleToFriends,
    nowFromFriends,
  ]);
}

enum SocialSettingsUpdateNowFromFriends {
  all('all'),
  close('close'),
  off('off'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const SocialSettingsUpdateNowFromFriends(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'SocialSettingsUpdateNowFromFriends.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SocialSettingsUpdateNowFromFriends fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kişisel istatistiklerinizi ve kişisel rozetlerinizi profilinizde
/// kimin göreceği (issue #267, ADR-0026 §4). `none` (varsayılan):
/// yalnızca siz. `friends`: arkadaşlarınız. `friends_and_mutual`:
/// arkadaşlarınız ve ortak tayfa üyeleri. Kendi profilinizde her zaman
/// görürsünüz.
enum StatsVisibility {
  none('none'),
  friends('friends'),
  friendsAndMutual('friends_and_mutual'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const StatsVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('StatsVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static StatsVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// İstatistik kartı: tayfa istatistiğinden en fazla 4 metrik
/// (`TayfaStat.metric_key`) ve dönem (`this_year` ya da `all_time`).
/// Ayarsız kart bu yılın dört ortak metriğini gösterir.
final class StatsWidgetConfig {
  const StatsWidgetConfig({required this.metricKeys, required this.period});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory StatsWidgetConfig.fromJson(Map<String, Object?> json) =>
      StatsWidgetConfig(
        metricKeys: List<String>.unmodifiable(
          _readList(json['metric_keys'], 'StatsWidgetConfig.metric_keys').map(
            (Object? e0) => _readString(e0, 'StatsWidgetConfig.metric_keys'),
          ),
        ),
        period: HomeWidgetPeriod.fromWire(
          _readString(json['period'], 'StatsWidgetConfig.period'),
        ),
      );

  /// Kısıtlar: minItems: 1; maxItems: 4.
  final List<String> metricKeys;

  final HomeWidgetPeriod period;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_keys': <Object?>[for (final e0 in metricKeys) e0],
    'period': period.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsWidgetConfig &&
          _deepEquals(metricKeys, other.metricKeys) &&
          period == other.period;

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(metricKeys), period]);
}

final class StatsWidgetData {
  const StatsWidgetData({
    required this.period,
    this.year,
    required this.values,
    this.computedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory StatsWidgetData.fromJson(Map<String, Object?> json) =>
      StatsWidgetData(
        period: HomeWidgetPeriod.fromWire(
          _readString(json['period'], 'StatsWidgetData.period'),
        ),
        year: switch (json['year']) {
          null => null,
          final Object v => _readInt(v, 'StatsWidgetData.year'),
        },
        values: List<HomeMetricValue>.unmodifiable(
          _readList(json['values'], 'StatsWidgetData.values').map(
            (Object? e0) => HomeMetricValue.fromJson(
              _readObject(e0, 'StatsWidgetData.values'),
            ),
          ),
        ),
        computedAt: switch (json['computed_at']) {
          null => null,
          final Object v => _readDateTime(v, 'StatsWidgetData.computed_at'),
        },
      );

  final HomeWidgetPeriod period;

  /// Europe/Istanbul yılı; tüm zamanlarda yoktur.
  final int? year;

  /// Ayardaki metrikler, ayardaki sırayla.
  final List<HomeMetricValue> values;

  /// Son hesaplama; henüz hesaplanmadıysa yoktur.
  final DateTime? computedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'period': period.wire,
    if (year case final value?) 'year': value,
    'values': <Object?>[for (final e0 in values) e0.toJson()],
    if (computedAt case final value?)
      'computed_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsWidgetData &&
          period == other.period &&
          year == other.year &&
          _deepEquals(values, other.values) &&
          computedAt == other.computedAt;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[period, year, _deepHash(values), computedAt]);
}

final class Status {
  const Status({
    required this.status,
    required this.version,
    required this.services,
    required this.checkedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Status.fromJson(Map<String, Object?> json) => Status(
    status: StatusStatus.fromWire(_readString(json['status'], 'Status.status')),
    version: _readString(json['version'], 'Status.version'),
    services: Map<String, StatusServicesValue>.unmodifiable(
      _readObject(json['services'], 'Status.services').map(
        (String k0, Object? e0) => MapEntry(
          k0,
          StatusServicesValue.fromWire(_readString(e0, 'Status.services')),
        ),
      ),
    ),
    checkedAt: _readDateTime(json['checked_at'], 'Status.checked_at'),
  );

  final StatusStatus status;

  final String version;

  final Map<String, StatusServicesValue> services;

  final DateTime checkedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.wire,
    'version': version,
    'services': <String, Object?>{
      for (final e0 in services.entries) e0.key: e0.value.wire,
    },
    'checked_at': checkedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Status &&
          status == other.status &&
          version == other.version &&
          _deepEquals(services, other.services) &&
          checkedAt == other.checkedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    status,
    version,
    _deepHash(services),
    checkedAt,
  ]);
}

enum StatusServicesValue {
  ok('ok'),
  unavailable('unavailable'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const StatusServicesValue(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('StatusServicesValue.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static StatusServicesValue fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

enum StatusStatus {
  ok('ok'),
  degraded('degraded'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const StatusStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('StatusStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static StatusStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Tag {
  const Tag({required this.id, required this.name, this.questionCount});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Tag.fromJson(Map<String, Object?> json) => Tag(
    id: _readString(json['id'], 'Tag.id'),
    name: _readString(json['name'], 'Tag.name'),
    questionCount: switch (json['question_count']) {
      null => null,
      final Object v => _readInt(v, 'Tag.question_count'),
    },
  );

  final String id;

  /// İlk yazıldığı haliyle 1–30 karakter.
  final String name;

  /// Yalnızca etiket listesinde; etiketi taşıyan görünen soru sayısı.
  final int? questionCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    if (questionCount case final value?) 'question_count': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          id == other.id &&
          name == other.name &&
          questionCount == other.questionCount;

  @override
  int get hashCode => Object.hashAll(<Object?>[id, name, questionCount]);
}

final class TagList {
  const TagList({required this.tags});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TagList.fromJson(Map<String, Object?> json) => TagList(
    tags: List<Tag>.unmodifiable(
      _readList(
        json['tags'],
        'TagList.tags',
      ).map((Object? e0) => Tag.fromJson(_readObject(e0, 'TagList.tags'))),
    ),
  );

  final List<Tag> tags;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tags': <Object?>[for (final e0 in tags) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagList && _deepEquals(tags, other.tags);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(tags)]);
}

final class Tayfa {
  const Tayfa({
    this.coverUploadId,
    required this.id,
    required this.name,
    required this.kind,
    this.instantEventId,
    this.convertedAt,
    required this.description,
    required this.interests,
    required this.joinPolicy,
    required this.modules,
    required this.status,
    this.suspendedAt,
    this.deletionAt,
    required this.memberCount,
    required this.membersCanCreateEvents,
    required this.nowCreateMinRole,
    this.joinCode,
    this.pendingJoinRequestCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Tayfa.fromJson(Map<String, Object?> json) => Tayfa(
    coverUploadId: switch (json['cover_upload_id']) {
      null => null,
      final Object v => _readString(v, 'Tayfa.cover_upload_id'),
    },
    id: _readString(json['id'], 'Tayfa.id'),
    name: _readString(json['name'], 'Tayfa.name'),
    kind: TayfaKind.fromWire(_readString(json['kind'], 'Tayfa.kind')),
    instantEventId: switch (json['instant_event_id']) {
      null => null,
      final Object v => _readString(v, 'Tayfa.instant_event_id'),
    },
    convertedAt: switch (json['converted_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Tayfa.converted_at'),
    },
    description: _readString(json['description'], 'Tayfa.description'),
    interests: List<String>.unmodifiable(
      _readList(
        json['interests'],
        'Tayfa.interests',
      ).map((Object? e0) => _readString(e0, 'Tayfa.interests')),
    ),
    joinPolicy: JoinPolicy.fromWire(
      _readString(json['join_policy'], 'Tayfa.join_policy'),
    ),
    modules: TayfaModules.fromJson(
      _readObject(json['modules'], 'Tayfa.modules'),
    ),
    status: TayfaStatus.fromWire(_readString(json['status'], 'Tayfa.status')),
    suspendedAt: switch (json['suspended_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Tayfa.suspended_at'),
    },
    deletionAt: switch (json['deletion_at']) {
      null => null,
      final Object v => _readDateTime(v, 'Tayfa.deletion_at'),
    },
    memberCount: _readInt(json['member_count'], 'Tayfa.member_count'),
    membersCanCreateEvents: _readBool(
      json['members_can_create_events'],
      'Tayfa.members_can_create_events',
    ),
    nowCreateMinRole: Role.fromWire(
      _readString(json['now_create_min_role'], 'Tayfa.now_create_min_role'),
    ),
    joinCode: switch (json['join_code']) {
      null => null,
      final Object v => _readString(v, 'Tayfa.join_code'),
    },
    pendingJoinRequestCount: switch (json['pending_join_request_count']) {
      null => null,
      final Object v => _readInt(v, 'Tayfa.pending_join_request_count'),
    },
    createdAt: _readDateTime(json['created_at'], 'Tayfa.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Tayfa.updated_at'),
  );

  /// Kapak; linkleri `POST /v1/media/urls`.
  final String? coverUploadId;

  final String id;

  /// 3–50 karakter; anlık tayfada etkinliğin başlığıdır (1–120).
  final String name;

  final TayfaKind kind;

  /// Yalnızca anlık tayfada; tayfanın tek etkinliği.
  final String? instantEventId;

  /// Yalnızca anlık tayfadan "Bu ekiple tayfa kur" ile kalıcıya dönmüş
  /// tayfada: dönüşüm anı (ADR-0032 §7). Kurulum dönemi bu andan sayılır.
  final DateTime? convertedAt;

  final String description;

  final List<String> interests;

  final JoinPolicy joinPolicy;

  /// Her modülün açık olup olmadığı.
  final TayfaModules modules;

  /// `warned`: hareketsiz, 7 gün sonra arşivlenir. `archived`: salt okunur.
  final TayfaStatus status;

  /// Platform tayfayı askıya aldıysa (salt okunur). Sebep dönmez.
  final DateTime? suspendedAt;

  /// Silme bekliyorsa tayfanın silineceği zaman (salt okunur).
  final DateTime? deletionAt;

  final int memberCount;

  /// `true` ise her etkin üye etkinlik açabilir; `false` (varsayılan)
  /// ise yalnızca moderatör ve yönetici. Organizatör kendi etkinliğini
  /// her zaman yönetir.
  final bool membersCanCreateEvents;

  /// Tayfada Şimdi başlat (`starts_now`) için gereken en düşük rol;
  /// varsayılan `member` (ADR-0038 §2). `members_can_create_events`
  /// ayarından bağımsızdır. Yalnızca yönetici değiştirir.
  final Role nowCreateMinRole;

  /// Yalnızca yöneticiye döner.
  final String? joinCode;

  /// Onay bekleyen katılım istekleri; yalnızca istekleri onaylayabilen
  /// moderatör ve yöneticiye döner, diğerlerinde alan yoktur.
  ///
  /// Kısıtlar: minimum: 0.
  final int? pendingJoinRequestCount;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (coverUploadId case final value?) 'cover_upload_id': value,
    'id': id,
    'name': name,
    'kind': kind.wire,
    if (instantEventId case final value?) 'instant_event_id': value,
    if (convertedAt case final value?)
      'converted_at': value.toUtc().toIso8601String(),
    'description': description,
    'interests': <Object?>[for (final e0 in interests) e0],
    'join_policy': joinPolicy.wire,
    'modules': modules.toJson(),
    'status': status.wire,
    if (suspendedAt case final value?)
      'suspended_at': value.toUtc().toIso8601String(),
    if (deletionAt case final value?)
      'deletion_at': value.toUtc().toIso8601String(),
    'member_count': memberCount,
    'members_can_create_events': membersCanCreateEvents,
    'now_create_min_role': nowCreateMinRole.wire,
    if (joinCode case final value?) 'join_code': value,
    if (pendingJoinRequestCount case final value?)
      'pending_join_request_count': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tayfa &&
          coverUploadId == other.coverUploadId &&
          id == other.id &&
          name == other.name &&
          kind == other.kind &&
          instantEventId == other.instantEventId &&
          convertedAt == other.convertedAt &&
          description == other.description &&
          _deepEquals(interests, other.interests) &&
          joinPolicy == other.joinPolicy &&
          modules == other.modules &&
          status == other.status &&
          suspendedAt == other.suspendedAt &&
          deletionAt == other.deletionAt &&
          memberCount == other.memberCount &&
          membersCanCreateEvents == other.membersCanCreateEvents &&
          nowCreateMinRole == other.nowCreateMinRole &&
          joinCode == other.joinCode &&
          pendingJoinRequestCount == other.pendingJoinRequestCount &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    coverUploadId,
    id,
    name,
    kind,
    instantEventId,
    convertedAt,
    description,
    _deepHash(interests),
    joinPolicy,
    modules,
    status,
    suspendedAt,
    deletionAt,
    memberCount,
    membersCanCreateEvents,
    nowCreateMinRole,
    joinCode,
    pendingJoinRequestCount,
    createdAt,
    updatedAt,
  ]);
}

final class TayfaConvertRequest {
  const TayfaConvertRequest({
    required this.name,
    this.description,
    this.interests,
    this.joinPolicy,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaConvertRequest.fromJson(Map<String, Object?> json) =>
      TayfaConvertRequest(
        name: _readString(json['name'], 'TayfaConvertRequest.name'),
        description: switch (json['description']) {
          null => null,
          final Object v => _readString(v, 'TayfaConvertRequest.description'),
        },
        interests: switch (json['interests']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'TayfaConvertRequest.interests').map(
              (Object? e0) => _readString(e0, 'TayfaConvertRequest.interests'),
            ),
          ),
        },
        joinPolicy: switch (json['join_policy']) {
          null => null,
          final Object v => JoinPolicy.fromWire(
            _readString(v, 'TayfaConvertRequest.join_policy'),
          ),
        },
      );

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 3–50 karakter.
  ///
  /// Kısıtlar: minLength: 3; maxLength: 50.
  final String name;

  /// Kısıtlar: maxLength: 500.
  final String? description;

  /// Kısıtlar: maxItems: 20; uniqueItems: true.
  final List<String>? interests;

  /// Kısıtlar: varsayılan (sunucu): `approval`.
  final JoinPolicy? joinPolicy;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (description case final value?) 'description': value,
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0],
    if (joinPolicy case final value?) 'join_policy': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaConvertRequest &&
          name == other.name &&
          description == other.description &&
          _deepEquals(interests, other.interests) &&
          joinPolicy == other.joinPolicy;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    name,
    description,
    _deepHash(interests),
    joinPolicy,
  ]);
}

final class TayfaCreateRequest {
  const TayfaCreateRequest({
    required this.name,
    this.description,
    this.interests,
    this.joinPolicy,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaCreateRequest.fromJson(Map<String, Object?> json) =>
      TayfaCreateRequest(
        name: _readString(json['name'], 'TayfaCreateRequest.name'),
        description: switch (json['description']) {
          null => null,
          final Object v => _readString(v, 'TayfaCreateRequest.description'),
        },
        interests: switch (json['interests']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'TayfaCreateRequest.interests').map(
              (Object? e0) => _readString(e0, 'TayfaCreateRequest.interests'),
            ),
          ),
        },
        joinPolicy: switch (json['join_policy']) {
          null => null,
          final Object v => JoinPolicy.fromWire(
            _readString(v, 'TayfaCreateRequest.join_policy'),
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'TayfaCreateRequest.client_request_id',
        ),
      );

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 3–50 karakter.
  ///
  /// Kısıtlar: minLength: 3; maxLength: 50.
  final String name;

  /// Kısıtlar: maxLength: 500.
  final String? description;

  /// Kısıtlar: maxItems: 20; uniqueItems: true.
  final List<String>? interests;

  /// Kısıtlar: varsayılan (sunucu): `approval`.
  final JoinPolicy? joinPolicy;

  /// İstemcinin her açma denemesi için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (description case final value?) 'description': value,
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0],
    if (joinPolicy case final value?) 'join_policy': value.wire,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaCreateRequest &&
          name == other.name &&
          description == other.description &&
          _deepEquals(interests, other.interests) &&
          joinPolicy == other.joinPolicy &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    name,
    description,
    _deepHash(interests),
    joinPolicy,
    clientRequestId,
  ]);
}

final class TayfaDiscover {
  const TayfaDiscover({
    required this.state,
    required this.enabled,
    required this.statsShowcase,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaDiscover.fromJson(Map<String, Object?> json) => TayfaDiscover(
    state: TayfaDiscoverState.fromWire(
      _readString(json['state'], 'TayfaDiscover.state'),
    ),
    enabled: _readBool(json['enabled'], 'TayfaDiscover.enabled'),
    statsShowcase: _readBool(
      json['stats_showcase'],
      'TayfaDiscover.stats_showcase',
    ),
  );

  /// `off` kapalı; `pending` incelemede; `listed` açık (Keşfet'te
  /// görünebilir); `under_review` platform Keşfet'ten çıkardı, yeniden
  /// inceleniyor (neden söylenmez); `rejected` kabul edilmedi.
  final TayfaDiscoverState state;

  /// Yöneticilerin Keşfet isteği.
  final bool enabled;

  /// İstatistik kartı Keşfet vitrininde gösterilir (#267, ADR-0026 §3;
  /// varsayılan açık). `PUT /v1/tayfas/{tayfa_id}/discover/stats-showcase`
  /// ile değişir.
  final bool statsShowcase;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'state': state.wire,
    'enabled': enabled,
    'stats_showcase': statsShowcase,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaDiscover &&
          state == other.state &&
          enabled == other.enabled &&
          statsShowcase == other.statsShowcase;

  @override
  int get hashCode => Object.hashAll(<Object?>[state, enabled, statsShowcase]);
}

final class TayfaDiscoverInput {
  const TayfaDiscoverInput({required this.enabled});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaDiscoverInput.fromJson(Map<String, Object?> json) =>
      TayfaDiscoverInput(
        enabled: _readBool(json['enabled'], 'TayfaDiscoverInput.enabled'),
      );

  final bool enabled;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'enabled': enabled};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaDiscoverInput && enabled == other.enabled;

  @override
  int get hashCode => Object.hashAll(<Object?>[enabled]);
}

/// `off` kapalı; `pending` incelemede; `listed` açık (Keşfet'te
/// görünebilir); `under_review` platform Keşfet'ten çıkardı, yeniden
/// inceleniyor (neden söylenmez); `rejected` kabul edilmedi.
enum TayfaDiscoverState {
  off('off'),
  pending('pending'),
  listed('listed'),
  underReview('under_review'),
  rejected('rejected'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const TayfaDiscoverState(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('TayfaDiscoverState.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static TayfaDiscoverState fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Tayfada görünen garaj araçları (#272).
final class TayfaGarage {
  const TayfaGarage({
    required this.vehicles,
    this.nextPageToken,
    required this.callerVisible,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaGarage.fromJson(Map<String, Object?> json) => TayfaGarage(
    vehicles: List<GarageVehicle>.unmodifiable(
      _readList(json['vehicles'], 'TayfaGarage.vehicles').map(
        (Object? e0) =>
            GarageVehicle.fromJson(_readObject(e0, 'TayfaGarage.vehicles')),
      ),
    ),
    nextPageToken: switch (json['next_page_token']) {
      null => null,
      final Object v => _readString(v, 'TayfaGarage.next_page_token'),
    },
    callerVisible: _readBool(
      json['caller_visible'],
      'TayfaGarage.caller_visible',
    ),
  );

  /// En yeni önce.
  final List<GarageVehicle> vehicles;

  /// Yoksa son sayfa.
  final String? nextPageToken;

  /// Çağıranın kendi garajı bu tayfada görünüyor mu.
  final bool callerVisible;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'vehicles': <Object?>[for (final e0 in vehicles) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
    'caller_visible': callerVisible,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaGarage &&
          _deepEquals(vehicles, other.vehicles) &&
          nextPageToken == other.nextPageToken &&
          callerVisible == other.callerVisible;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    _deepHash(vehicles),
    nextPageToken,
    callerVisible,
  ]);
}

/// `standard`: tayfa. `instant`: anlık etkinliğin gizli, tek etkinlikli
/// tayfası; Keşfet'e çıkmaz, etkinlik bitince 7 gün sonra arşivlenir
/// (ADR-0032).
enum TayfaKind {
  standard('standard'),
  instant('instant'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const TayfaKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('TayfaKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static TayfaKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Her modülün açık olup olmadığı.
final class TayfaModules {
  const TayfaModules({
    this.announcements,
    this.events,
    this.qa,
    this.polls,
    this.daily,
    this.library_,
    this.questionPool,
    this.materials,
    this.garage,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaModules.fromJson(Map<String, Object?> json) => TayfaModules(
    announcements: switch (json['announcements']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.announcements'),
    },
    events: switch (json['events']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.events'),
    },
    qa: switch (json['qa']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.qa'),
    },
    polls: switch (json['polls']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.polls'),
    },
    daily: switch (json['daily']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.daily'),
    },
    library_: switch (json['library']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.library'),
    },
    questionPool: switch (json['question_pool']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.question_pool'),
    },
    materials: switch (json['materials']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.materials'),
    },
    garage: switch (json['garage']) {
      null => null,
      final Object v => _readBool(v, 'TayfaModules.garage'),
    },
  );

  final bool? announcements;

  final bool? events;

  final bool? qa;

  final bool? polls;

  final bool? daily;

  final bool? library_;

  final bool? questionPool;

  final bool? materials;

  final bool? garage;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (announcements case final value?) 'announcements': value,
    if (events case final value?) 'events': value,
    if (qa case final value?) 'qa': value,
    if (polls case final value?) 'polls': value,
    if (daily case final value?) 'daily': value,
    if (library_ case final value?) 'library': value,
    if (questionPool case final value?) 'question_pool': value,
    if (materials case final value?) 'materials': value,
    if (garage case final value?) 'garage': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaModules &&
          announcements == other.announcements &&
          events == other.events &&
          qa == other.qa &&
          polls == other.polls &&
          daily == other.daily &&
          library_ == other.library_ &&
          questionPool == other.questionPool &&
          materials == other.materials &&
          garage == other.garage;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    announcements,
    events,
    qa,
    polls,
    daily,
    library_,
    questionPool,
    materials,
    garage,
  ]);
}

/// Tayfanın Keşfet vitrinindeki istatistik kartı (#267; ADR-0026 §3,
/// ADR-0039 §3). Yalnızca yöneticiler vitrini kapatmamışsa ve tayfanın
/// donmuş (bitişinden 7 gün geçmiş, iptal edilmemiş) en az 3 etkinliği
/// varsa döner; yoksa alan da yoktur ve istemci kart göstermez ("henüz
/// yok" değil). Yalnızca tüm zamanlar toplamı; kişi, tarih, saat, gün,
/// ilçe, koordinat ve yıl kırılımı yoktur. Tayfalar arası sıralama
/// yoktur.
final class TayfaShowcase {
  const TayfaShowcase({required this.stats, required this.badges});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaShowcase.fromJson(Map<String, Object?> json) => TayfaShowcase(
    stats: List<TayfaStat>.unmodifiable(
      _readList(json['stats'], 'TayfaShowcase.stats').map(
        (Object? e0) =>
            TayfaStat.fromJson(_readObject(e0, 'TayfaShowcase.stats')),
      ),
    ),
    badges: List<EarnedBadge>.unmodifiable(
      _readList(json['badges'], 'TayfaShowcase.badges').map(
        (Object? e0) =>
            EarnedBadge.fromJson(_readObject(e0, 'TayfaShowcase.badges')),
      ),
    ),
  );

  /// Ortak metriklerin tayfa toplamı (`events`, `attended`,
  /// `participants`, `duration`; türe göre `<tür>.<metrik>`) ve
  /// katalogda vitrine izin verilen ölçümler (`<tür>.<ölçüm>`).
  /// Günlük metrikleri ve katılımı hassas türlerin metrikleri hiç
  /// gelmez; hassas türler yalnızca genel `events` ve `attended`
  /// toplamına girer (ADR-0037 §7).
  final List<TayfaStat> stats;

  /// Tayfanın rozetleri, kazanılma sırasıyla.
  final List<EarnedBadge> badges;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'stats': <Object?>[for (final e0 in stats) e0.toJson()],
    'badges': <Object?>[for (final e0 in badges) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaShowcase &&
          _deepEquals(stats, other.stats) &&
          _deepEquals(badges, other.badges);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(stats), _deepHash(badges)]);
}

final class TayfaStat {
  const TayfaStat({
    required this.metricKey,
    required this.source,
    required this.value,
    required this.eventCount,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaStat.fromJson(Map<String, Object?> json) => TayfaStat(
    metricKey: _readString(json['metric_key'], 'TayfaStat.metric_key'),
    source: TayfaStatSource.fromWire(
      _readString(json['source'], 'TayfaStat.source'),
    ),
    value: _readDouble(json['value'], 'TayfaStat.value'),
    eventCount: _readInt(json['event_count'], 'TayfaStat.event_count'),
  );

  final String metricKey;

  final TayfaStatSource source;

  final double value;

  /// Değere katkı veren etkinlik sayısı.
  ///
  /// Kısıtlar: minimum: 0.
  final int eventCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric_key': metricKey,
    'source': source.wire,
    'value': value,
    'event_count': eventCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaStat &&
          metricKey == other.metricKey &&
          source == other.source &&
          value == other.value &&
          eventCount == other.eventCount;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[metricKey, source, value, eventCount]);
}

/// Etkin bir üyenin ölçüm ya da günlük metriğindeki katkısı.
final class TayfaStatContribution {
  const TayfaStatContribution({
    required this.userId,
    required this.metricKey,
    required this.value,
    required this.eventCount,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaStatContribution.fromJson(Map<String, Object?> json) =>
      TayfaStatContribution(
        userId: _readString(json['user_id'], 'TayfaStatContribution.user_id'),
        metricKey: _readString(
          json['metric_key'],
          'TayfaStatContribution.metric_key',
        ),
        value: _readDouble(json['value'], 'TayfaStatContribution.value'),
        eventCount: _readInt(
          json['event_count'],
          'TayfaStatContribution.event_count',
        ),
      );

  final String userId;

  final String metricKey;

  final double value;

  /// Kısıtlar: minimum: 0.
  final int eventCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'metric_key': metricKey,
    'value': value,
    'event_count': eventCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaStatContribution &&
          userId == other.userId &&
          metricKey == other.metricKey &&
          value == other.value &&
          eventCount == other.eventCount;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[userId, metricKey, value, eventCount]);
}

enum TayfaStatSource {
  common('common'),
  measure('measure'),
  log('log'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const TayfaStatSource(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('TayfaStatSource.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static TayfaStatSource fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class TayfaStats {
  const TayfaStats({
    this.year,
    required this.years,
    required this.totals,
    required this.contributions,
    this.computedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaStats.fromJson(Map<String, Object?> json) => TayfaStats(
    year: switch (json['year']) {
      null => null,
      final Object v => _readInt(v, 'TayfaStats.year'),
    },
    years: List<int>.unmodifiable(
      _readList(
        json['years'],
        'TayfaStats.years',
      ).map((Object? e0) => _readInt(e0, 'TayfaStats.years')),
    ),
    totals: List<TayfaStat>.unmodifiable(
      _readList(json['totals'], 'TayfaStats.totals').map(
        (Object? e0) =>
            TayfaStat.fromJson(_readObject(e0, 'TayfaStats.totals')),
      ),
    ),
    contributions: List<TayfaStatContribution>.unmodifiable(
      _readList(json['contributions'], 'TayfaStats.contributions').map(
        (Object? e0) => TayfaStatContribution.fromJson(
          _readObject(e0, 'TayfaStats.contributions'),
        ),
      ),
    ),
    computedAt: switch (json['computed_at']) {
      null => null,
      final Object v => _readDateTime(v, 'TayfaStats.computed_at'),
    },
  );

  /// İstenen yıl; tüm zamanlarda yoktur.
  final int? year;

  /// İstatistiği olan yıllar, yeniden eskiye.
  final List<int> years;

  final List<TayfaStat> totals;

  final List<TayfaStatContribution> contributions;

  /// Son hesaplama; henüz hesaplanmadıysa yoktur.
  final DateTime? computedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (year case final value?) 'year': value,
    'years': <Object?>[for (final e0 in years) e0],
    'totals': <Object?>[for (final e0 in totals) e0.toJson()],
    'contributions': <Object?>[for (final e0 in contributions) e0.toJson()],
    if (computedAt case final value?)
      'computed_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaStats &&
          year == other.year &&
          _deepEquals(years, other.years) &&
          _deepEquals(totals, other.totals) &&
          _deepEquals(contributions, other.contributions) &&
          computedAt == other.computedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    year,
    _deepHash(years),
    _deepHash(totals),
    _deepHash(contributions),
    computedAt,
  ]);
}

final class TayfaStatsShowcaseInput {
  const TayfaStatsShowcaseInput({required this.statsShowcase});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaStatsShowcaseInput.fromJson(Map<String, Object?> json) =>
      TayfaStatsShowcaseInput(
        statsShowcase: _readBool(
          json['stats_showcase'],
          'TayfaStatsShowcaseInput.stats_showcase',
        ),
      );

  final bool statsShowcase;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'stats_showcase': statsShowcase,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaStatsShowcaseInput && statsShowcase == other.statsShowcase;

  @override
  int get hashCode => Object.hashAll(<Object?>[statsShowcase]);
}

/// `warned`: hareketsiz, 7 gün sonra arşivlenir. `archived`: salt okunur.
enum TayfaStatus {
  active('active'),
  warned('warned'),
  archived('archived'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const TayfaStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('TayfaStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static TayfaStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kısıtlar: minProperties: 1.
final class TayfaUpdateRequest {
  const TayfaUpdateRequest({
    this.coverUploadId,
    this.name,
    this.description,
    this.interests,
    this.joinPolicy,
    this.membersCanCreateEvents,
    this.nowCreateMinRole,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaUpdateRequest.fromJson(Map<String, Object?> json) =>
      TayfaUpdateRequest(
        coverUploadId: switch (json['cover_upload_id']) {
          null => null,
          final Object v => _readString(
            v,
            'TayfaUpdateRequest.cover_upload_id',
          ),
        },
        name: switch (json['name']) {
          null => null,
          final Object v => _readString(v, 'TayfaUpdateRequest.name'),
        },
        description: switch (json['description']) {
          null => null,
          final Object v => _readString(v, 'TayfaUpdateRequest.description'),
        },
        interests: switch (json['interests']) {
          null => null,
          final Object v => List<String>.unmodifiable(
            _readList(v, 'TayfaUpdateRequest.interests').map(
              (Object? e0) => _readString(e0, 'TayfaUpdateRequest.interests'),
            ),
          ),
        },
        joinPolicy: switch (json['join_policy']) {
          null => null,
          final Object v => JoinPolicy.fromWire(
            _readString(v, 'TayfaUpdateRequest.join_policy'),
          ),
        },
        membersCanCreateEvents: switch (json['members_can_create_events']) {
          null => null,
          final Object v => _readBool(
            v,
            'TayfaUpdateRequest.members_can_create_events',
          ),
        },
        nowCreateMinRole: switch (json['now_create_min_role']) {
          null => null,
          final Object v => Role.fromWire(
            _readString(v, 'TayfaUpdateRequest.now_create_min_role'),
          ),
        },
      );

  /// Kendi hazır `cover` yüklemeniz (bu tayfa için açılmış); `""` kapağı
  /// kaldırır. Eski kapak silinir. Yönetici yetkisi gerekir.
  final String? coverUploadId;

  /// Kısıtlar: minLength: 3; maxLength: 50.
  final String? name;

  /// Kısıtlar: maxLength: 500.
  final String? description;

  /// Kısıtlar: maxItems: 20; uniqueItems: true.
  final List<String>? interests;

  final JoinPolicy? joinPolicy;

  /// `true`: her etkin üye etkinlik açabilir. `false`: yalnızca moderatör ve yönetici.
  final bool? membersCanCreateEvents;

  /// Şimdi başlat (`starts_now`) için gereken en düşük rol (ADR-0038 §2).
  final Role? nowCreateMinRole;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (coverUploadId case final value?) 'cover_upload_id': value,
    if (name case final value?) 'name': value,
    if (description case final value?) 'description': value,
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0],
    if (joinPolicy case final value?) 'join_policy': value.wire,
    if (membersCanCreateEvents case final value?)
      'members_can_create_events': value,
    if (nowCreateMinRole case final value?) 'now_create_min_role': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaUpdateRequest &&
          coverUploadId == other.coverUploadId &&
          name == other.name &&
          description == other.description &&
          _deepEquals(interests, other.interests) &&
          joinPolicy == other.joinPolicy &&
          membersCanCreateEvents == other.membersCanCreateEvents &&
          nowCreateMinRole == other.nowCreateMinRole;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    coverUploadId,
    name,
    description,
    _deepHash(interests),
    joinPolicy,
    membersCanCreateEvents,
    nowCreateMinRole,
  ]);
}

final class TayfaView {
  const TayfaView({
    required this.tayfa,
    required this.callerRole,
    required this.badges,
    required this.homeWidgets,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaView.fromJson(Map<String, Object?> json) => TayfaView(
    tayfa: Tayfa.fromJson(_readObject(json['tayfa'], 'TayfaView.tayfa')),
    callerRole: Role.fromWire(
      _readString(json['caller_role'], 'TayfaView.caller_role'),
    ),
    badges: List<EarnedBadge>.unmodifiable(
      _readList(json['badges'], 'TayfaView.badges').map(
        (Object? e0) =>
            EarnedBadge.fromJson(_readObject(e0, 'TayfaView.badges')),
      ),
    ),
    homeWidgets: List<HomeWidget>.unmodifiable(
      _readList(json['home_widgets'], 'TayfaView.home_widgets').map(
        (Object? e0) =>
            HomeWidget.fromJson(_readObject(e0, 'TayfaView.home_widgets')),
      ),
    ),
  );

  final Tayfa tayfa;

  final Role callerRole;

  /// Tayfanın rozetleri, kazanılma sırasıyla (#258, ADR-0039 §3).
  final List<EarnedBadge> badges;

  /// Ana sayfanın "Sıradaki" kartından sonra gösterdiği bileşenler,
  /// sırasıyla (#268, ADR-0027 §3): yalnızca açık olanlar, modülü
  /// açık olanlar ve tarihi geçmemiş geri sayım. İstemci tanımadığı
  /// anahtarı atlar.
  final List<HomeWidget> homeWidgets;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa': tayfa.toJson(),
    'caller_role': callerRole.wire,
    'badges': <Object?>[for (final e0 in badges) e0.toJson()],
    'home_widgets': <Object?>[for (final e0 in homeWidgets) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaView &&
          tayfa == other.tayfa &&
          callerRole == other.callerRole &&
          _deepEquals(badges, other.badges) &&
          _deepEquals(homeWidgets, other.homeWidgets);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    tayfa,
    callerRole,
    _deepHash(badges),
    _deepHash(homeWidgets),
  ]);
}

final class TayfaVocabularyList {
  const TayfaVocabularyList({
    required this.values,
    required this.callerCanMerge,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaVocabularyList.fromJson(Map<String, Object?> json) =>
      TayfaVocabularyList(
        values: List<TayfaVocabularyValue>.unmodifiable(
          _readList(json['values'], 'TayfaVocabularyList.values').map(
            (Object? e0) => TayfaVocabularyValue.fromJson(
              _readObject(e0, 'TayfaVocabularyList.values'),
            ),
          ),
        ),
        callerCanMerge: _readBool(
          json['caller_can_merge'],
          'TayfaVocabularyList.caller_can_merge',
        ),
      );

  /// Kısıtlar: maxItems: 20.
  final List<TayfaVocabularyValue> values;

  /// Şu an değerleri birleştirebilir ve geri alabilirsiniz.
  final bool callerCanMerge;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'values': <Object?>[for (final e0 in values) e0.toJson()],
    'caller_can_merge': callerCanMerge,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaVocabularyList &&
          _deepEquals(values, other.values) &&
          callerCanMerge == other.callerCanMerge;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(values), callerCanMerge]);
}

final class TayfaVocabularyMergeRequest {
  const TayfaVocabularyMergeRequest({required this.targetId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaVocabularyMergeRequest.fromJson(Map<String, Object?> json) =>
      TayfaVocabularyMergeRequest(
        targetId: _readString(
          json['target_id'],
          'TayfaVocabularyMergeRequest.target_id',
        ),
      );

  /// Birleştirilmemiş hedef değer.
  final String targetId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'target_id': targetId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaVocabularyMergeRequest && targetId == other.targetId;

  @override
  int get hashCode => Object.hashAll(<Object?>[targetId]);
}

/// Tayfa sözlüğünde bir değer (#244).
final class TayfaVocabularyValue {
  const TayfaVocabularyValue({
    required this.id,
    required this.value,
    this.mergedIntoId,
    this.mergedIntoValue,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaVocabularyValue.fromJson(Map<String, Object?> json) =>
      TayfaVocabularyValue(
        id: _readString(json['id'], 'TayfaVocabularyValue.id'),
        value: _readString(json['value'], 'TayfaVocabularyValue.value'),
        mergedIntoId: switch (json['merged_into_id']) {
          null => null,
          final Object v => _readString(
            v,
            'TayfaVocabularyValue.merged_into_id',
          ),
        },
        mergedIntoValue: switch (json['merged_into_value']) {
          null => null,
          final Object v => _readString(
            v,
            'TayfaVocabularyValue.merged_into_value',
          ),
        },
      );

  final String id;

  /// Kısıtlar: minLength: 1; maxLength: 60.
  final String value;

  /// Yalnızca birleştirilmiş değerde, gösterildiği değer.
  final String? mergedIntoId;

  /// Yalnızca birleştirilmiş değerde, hedefin metni.
  final String? mergedIntoValue;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'value': value,
    if (mergedIntoId case final value?) 'merged_into_id': value,
    if (mergedIntoValue case final value?) 'merged_into_value': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaVocabularyValue &&
          id == other.id &&
          value == other.value &&
          mergedIntoId == other.mergedIntoId &&
          mergedIntoValue == other.mergedIntoValue;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, value, mergedIntoId, mergedIntoValue]);
}

final class UnreadNotificationCount {
  const UnreadNotificationCount({required this.unreadCount});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UnreadNotificationCount.fromJson(Map<String, Object?> json) =>
      UnreadNotificationCount(
        unreadCount: _readInt(
          json['unread_count'],
          'UnreadNotificationCount.unread_count',
        ),
      );

  /// Kısıtlar: minimum: 0; maximum: 1000.
  final int unreadCount;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'unread_count': unreadCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreadNotificationCount && unreadCount == other.unreadCount;

  @override
  int get hashCode => Object.hashAll(<Object?>[unreadCount]);
}

final class Upload {
  const Upload({
    required this.id,
    required this.purpose,
    required this.status,
    this.rejectReason,
    this.tayfaId,
    required this.sizeBytes,
    required this.createdAt,
    required this.attached,
    this.urls,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Upload.fromJson(Map<String, Object?> json) => Upload(
    id: _readString(json['id'], 'Upload.id'),
    purpose: UploadPurpose.fromWire(
      _readString(json['purpose'], 'Upload.purpose'),
    ),
    status: UploadStatus.fromWire(_readString(json['status'], 'Upload.status')),
    rejectReason: switch (json['reject_reason']) {
      null => null,
      final Object v => UploadRejectReason.fromWire(
        _readString(v, 'Upload.reject_reason'),
      ),
    },
    tayfaId: switch (json['tayfa_id']) {
      null => null,
      final Object v => _readString(v, 'Upload.tayfa_id'),
    },
    sizeBytes: _readInt(json['size_bytes'], 'Upload.size_bytes'),
    createdAt: _readDateTime(json['created_at'], 'Upload.created_at'),
    attached: _readBool(json['attached'], 'Upload.attached'),
    urls: switch (json['urls']) {
      null => null,
      final Object v => MediaUrls.fromJson(_readObject(v, 'Upload.urls')),
    },
  );

  final String id;

  final UploadPurpose purpose;

  final UploadStatus status;

  final UploadRejectReason? rejectReason;

  final String? tayfaId;

  /// İki varyantın boyutları birlikte.
  final int sizeBytes;

  final DateTime createdAt;

  /// Bir içerik dosyayı kullanıyor. Hazır ama 7 gün bağlanmayan dosya silinir.
  final bool attached;

  /// Yalnızca `ready` iken.
  final MediaUrls? urls;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'purpose': purpose.wire,
    'status': status.wire,
    if (rejectReason case final value?) 'reject_reason': value.wire,
    if (tayfaId case final value?) 'tayfa_id': value,
    'size_bytes': sizeBytes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'attached': attached,
    if (urls case final value?) 'urls': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Upload &&
          id == other.id &&
          purpose == other.purpose &&
          status == other.status &&
          rejectReason == other.rejectReason &&
          tayfaId == other.tayfaId &&
          sizeBytes == other.sizeBytes &&
          createdAt == other.createdAt &&
          attached == other.attached &&
          urls == other.urls;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    purpose,
    status,
    rejectReason,
    tayfaId,
    sizeBytes,
    createdAt,
    attached,
    urls,
  ]);
}

final class UploadCompleteRequest {
  const UploadCompleteRequest({required this.width, required this.height});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UploadCompleteRequest.fromJson(Map<String, Object?> json) =>
      UploadCompleteRequest(
        width: _readInt(json['width'], 'UploadCompleteRequest.width'),
        height: _readInt(json['height'], 'UploadCompleteRequest.height'),
      );

  /// Full varyantın genişliği (piksel); `dm_attachment`'ta 0.
  ///
  /// Kısıtlar: minimum: 0; maximum: 1600.
  final int width;

  /// `dm_attachment`'ta 0.
  ///
  /// Kısıtlar: minimum: 0; maximum: 1600.
  final int height;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadCompleteRequest &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hashAll(<Object?>[width, height]);
}

final class UploadCreateRequest {
  const UploadCreateRequest({
    required this.purpose,
    required this.variants,
    this.tayfaId,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UploadCreateRequest.fromJson(Map<String, Object?> json) =>
      UploadCreateRequest(
        purpose: UploadPurpose.fromWire(
          _readString(json['purpose'], 'UploadCreateRequest.purpose'),
        ),
        variants: List<UploadVariant>.unmodifiable(
          _readList(json['variants'], 'UploadCreateRequest.variants').map(
            (Object? e0) => UploadVariant.fromJson(
              _readObject(e0, 'UploadCreateRequest.variants'),
            ),
          ),
        ),
        tayfaId: switch (json['tayfa_id']) {
          null => null,
          final Object v => _readString(v, 'UploadCreateRequest.tayfa_id'),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'UploadCreateRequest.client_request_id',
        ),
      );

  final UploadPurpose purpose;

  /// Tam bir `preview` ve bir `full`; `dm_attachment`'ta yalnızca bir `blob`.
  ///
  /// Kısıtlar: minItems: 1; maxItems: 2.
  final List<UploadVariant> variants;

  /// `cover`, `log_photo`, `event_photo`, `chat_photo`, `library_item`, `question_pool` ve `material_note` için zorunlu; `avatar`, `dm_attachment`, `report_evidence` ve `garage_vehicle`'da verilmez.
  final String? tayfaId;

  /// Her yükleme denemesi için bir kez üretilen, tekrar gönderimde aynen kullanılan UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'purpose': purpose.wire,
    'variants': <Object?>[for (final e0 in variants) e0.toJson()],
    if (tayfaId case final value?) 'tayfa_id': value,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadCreateRequest &&
          purpose == other.purpose &&
          _deepEquals(variants, other.variants) &&
          tayfaId == other.tayfaId &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    purpose,
    _deepHash(variants),
    tayfaId,
    clientRequestId,
  ]);
}

final class UploadCreated {
  const UploadCreated({required this.upload, required this.targets});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UploadCreated.fromJson(Map<String, Object?> json) => UploadCreated(
    upload: Upload.fromJson(
      _readObject(json['upload'], 'UploadCreated.upload'),
    ),
    targets: List<UploadTarget>.unmodifiable(
      _readList(json['targets'], 'UploadCreated.targets').map(
        (Object? e0) =>
            UploadTarget.fromJson(_readObject(e0, 'UploadCreated.targets')),
      ),
    ),
  );

  final Upload upload;

  /// Her varyant için bir hedef; tekrar gönderimde yükleme artık `pending` değilse boş.
  final List<UploadTarget> targets;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'upload': upload.toJson(),
    'targets': <Object?>[for (final e0 in targets) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadCreated &&
          upload == other.upload &&
          _deepEquals(targets, other.targets);

  @override
  int get hashCode => Object.hashAll(<Object?>[upload, _deepHash(targets)]);
}

/// `garage_vehicle` üye garajındaki bir aracın fotoğrafıdır (#272;
/// araç başına en fazla üç). Garaj kişiye aittir: `tayfa_id` verilmez.
/// `material_note` materyal kütüphanesindeki kişinin kendi not
/// fotoğrafıdır (#261; materyal başına en fazla üç).
/// `library_item` ortak kütüphane kaleminin fotoğrafıdır (#270; kalem
/// başına bir). `question_pool` soru havuzundaki bir sorunun ya da
/// cevabın fotoğrafıdır (#271; her birine en fazla iki; kişinin kendi
/// notu ya da takıldığı soru).
/// `cover` tayfa ya da etkinlik kapağıdır. `event_photo` etkinlik
/// albümünün fotoğrafıdır (`POST .../events/{event_id}/photos`); kapak
/// olarak kullanılamaz. `chat_photo` kanal mesajı fotoğrafı,
/// `dm_attachment` birebir mesajın şifreli eki (tek `blob`),
/// `report_evidence` birebir mesaj şikâyetinin kanıt fotoğrafıdır (#205).
enum UploadPurpose {
  avatar('avatar'),
  logPhoto('log_photo'),
  cover('cover'),
  eventPhoto('event_photo'),
  chatPhoto('chat_photo'),
  dmAttachment('dm_attachment'),
  reportEvidence('report_evidence'),
  libraryItem('library_item'),
  questionPool('question_pool'),
  materialNote('material_note'),
  garageVehicle('garage_vehicle'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const UploadPurpose(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('UploadPurpose.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadPurpose fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `not_image`: bir varyant JPEG/WebP değil ya da bildirilen türde
/// değil. `unsupported_type`: PNG, HEIC, GIF, animasyonlu WebP (istemci
/// dönüştürmeli). `metadata_present`: EXIF (GPS dahil), XMP ya da IPTC
/// var. `dimension_mismatch`: başlıktaki ölçü bildirilenden farklı ya
/// da preview oranı tutmuyor. `size_mismatch`: saklanan boyut
/// bildirilenden farklı. `too_large`: preview 400, full 1600 px'ten
/// büyük. `failed`: dosyadan bağımsız nedenlerle denetlenemedi.
enum UploadRejectReason {
  notImage('not_image'),
  unsupportedType('unsupported_type'),
  metadataPresent('metadata_present'),
  dimensionMismatch('dimension_mismatch'),
  sizeMismatch('size_mismatch'),
  tooLarge('too_large'),
  failed('failed'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const UploadRejectReason(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('UploadRejectReason.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadRejectReason fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `pending` (PUT ve tamamlama bekleniyor) → `ready` | `rejected`.
/// `unknown`: istemciden yeni bir sunucu değeri.
enum UploadStatus {
  pending('pending'),
  ready('ready'),
  rejected('rejected'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const UploadStatus(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('UploadStatus.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadStatus fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class UploadTarget {
  const UploadTarget({
    required this.kind,
    required this.method,
    required this.url,
    required this.headers,
    required this.expiresAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UploadTarget.fromJson(Map<String, Object?> json) => UploadTarget(
    kind: UploadTargetKind.fromWire(
      _readString(json['kind'], 'UploadTarget.kind'),
    ),
    method: UploadTargetMethod.fromWire(
      _readString(json['method'], 'UploadTarget.method'),
    ),
    url: _readString(json['url'], 'UploadTarget.url'),
    headers: Map<String, String>.unmodifiable(
      _readObject(json['headers'], 'UploadTarget.headers').map(
        (String k0, Object? e0) =>
            MapEntry(k0, _readString(e0, 'UploadTarget.headers')),
      ),
    ),
    expiresAt: _readDateTime(json['expires_at'], 'UploadTarget.expires_at'),
  );

  final UploadTargetKind kind;

  final UploadTargetMethod method;

  /// R2'ye imzalı PUT linki. Taşıyıcı link; log'a yazılmaz.
  final String url;

  /// PUT'ta aynen gönderilecek başlıklar (`Content-Type`, `Content-Length`).
  final Map<String, String> headers;

  final DateTime expiresAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    'method': method.wire,
    'url': url,
    'headers': <String, Object?>{
      for (final e0 in headers.entries) e0.key: e0.value,
    },
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadTarget &&
          kind == other.kind &&
          method == other.method &&
          url == other.url &&
          _deepEquals(headers, other.headers) &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    kind,
    method,
    url,
    _deepHash(headers),
    expiresAt,
  ]);
}

enum UploadTargetKind {
  preview('preview'),
  full('full'),
  blob('blob'),

  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.
  unknown('unknown');

  const UploadTargetKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('UploadTargetKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadTargetKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

enum UploadTargetMethod {
  pUT('PUT'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const UploadTargetMethod(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('UploadTargetMethod.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadTargetMethod fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class UploadVariant {
  const UploadVariant({
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UploadVariant.fromJson(Map<String, Object?> json) => UploadVariant(
    kind: UploadVariantKind.fromWire(
      _readString(json['kind'], 'UploadVariant.kind'),
    ),
    contentType: UploadVariantContentType.fromWire(
      _readString(json['content_type'], 'UploadVariant.content_type'),
    ),
    sizeBytes: _readInt(json['size_bytes'], 'UploadVariant.size_bytes'),
  );

  /// `blob` yalnızca `dm_attachment`'ta.
  final UploadVariantKind kind;

  /// `application/octet-stream` yalnızca `blob`'da.
  final UploadVariantContentType contentType;

  /// Dosyanın tam boyutu.
  ///
  /// Kısıtlar: minimum: 1; maximum: 10485760.
  final int sizeBytes;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    'content_type': contentType.wire,
    'size_bytes': sizeBytes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadVariant &&
          kind == other.kind &&
          contentType == other.contentType &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hashAll(<Object?>[kind, contentType, sizeBytes]);
}

/// `application/octet-stream` yalnızca `blob`'da.
enum UploadVariantContentType {
  imageJpeg('image/jpeg'),
  imageWebp('image/webp'),
  applicationOctetStream('application/octet-stream'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const UploadVariantContentType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('UploadVariantContentType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadVariantContentType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// `blob` yalnızca `dm_attachment`'ta.
enum UploadVariantKind {
  preview('preview'),
  full('full'),
  blob('blob'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const UploadVariantKind(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('UploadVariantKind.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UploadVariantKind fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class UploadView {
  const UploadView({required this.upload});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UploadView.fromJson(Map<String, Object?> json) => UploadView(
    upload: Upload.fromJson(_readObject(json['upload'], 'UploadView.upload')),
  );

  final Upload upload;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'upload': upload.toJson()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UploadView && upload == other.upload;

  @override
  int get hashCode => Object.hashAll(<Object?>[upload]);
}

final class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
    required this.self,
    this.friendState,
    required this.mutualTayfas,
    required this.activityVisible,
    this.activityVisibility,
    this.badges,
    this.stats,
    this.birthday,
    this.interests,
    this.about,
    this.occupation,
    this.team,
    this.languages,
    this.socialAccounts,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    userId: _readString(json['user_id'], 'UserProfile.user_id'),
    displayName: _readString(json['display_name'], 'UserProfile.display_name'),
    avatarUploadId: switch (json['avatar_upload_id']) {
      null => null,
      final Object v => _readString(v, 'UserProfile.avatar_upload_id'),
    },
    self: _readBool(json['self'], 'UserProfile.self'),
    friendState: switch (json['friend_state']) {
      null => null,
      final Object v => UserProfileFriendState.fromWire(
        _readString(v, 'UserProfile.friend_state'),
      ),
    },
    mutualTayfas: List<UserProfileMutualTayfasItem>.unmodifiable(
      _readList(json['mutual_tayfas'], 'UserProfile.mutual_tayfas').map(
        (Object? e0) => UserProfileMutualTayfasItem.fromJson(
          _readObject(e0, 'UserProfile.mutual_tayfas'),
        ),
      ),
    ),
    activityVisible: _readBool(
      json['activity_visible'],
      'UserProfile.activity_visible',
    ),
    activityVisibility: switch (json['activity_visibility']) {
      null => null,
      final Object v => ActivityVisibility.fromWire(
        _readString(v, 'UserProfile.activity_visibility'),
      ),
    },
    badges: switch (json['badges']) {
      null => null,
      final Object v => List<EarnedBadge>.unmodifiable(
        _readList(v, 'UserProfile.badges').map(
          (Object? e0) =>
              EarnedBadge.fromJson(_readObject(e0, 'UserProfile.badges')),
        ),
      ),
    },
    stats: switch (json['stats']) {
      null => null,
      final Object v => List<TayfaStat>.unmodifiable(
        _readList(v, 'UserProfile.stats').map(
          (Object? e0) =>
              TayfaStat.fromJson(_readObject(e0, 'UserProfile.stats')),
        ),
      ),
    },
    birthday: switch (json['birthday']) {
      null => null,
      final Object v => Birthday.fromJson(
        _readObject(v, 'UserProfile.birthday'),
      ),
    },
    interests: switch (json['interests']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(
          v,
          'UserProfile.interests',
        ).map((Object? e0) => _readString(e0, 'UserProfile.interests')),
      ),
    },
    about: switch (json['about']) {
      null => null,
      final Object v => _readString(v, 'UserProfile.about'),
    },
    occupation: switch (json['occupation']) {
      null => null,
      final Object v => _readString(v, 'UserProfile.occupation'),
    },
    team: switch (json['team']) {
      null => null,
      final Object v => _readString(v, 'UserProfile.team'),
    },
    languages: switch (json['languages']) {
      null => null,
      final Object v => List<String>.unmodifiable(
        _readList(
          v,
          'UserProfile.languages',
        ).map((Object? e0) => _readString(e0, 'UserProfile.languages')),
      ),
    },
    socialAccounts: switch (json['social_accounts']) {
      null => null,
      final Object v => List<SocialAccount>.unmodifiable(
        _readList(v, 'UserProfile.social_accounts').map(
          (Object? e0) => SocialAccount.fromJson(
            _readObject(e0, 'UserProfile.social_accounts'),
          ),
        ),
      ),
    },
  );

  final String userId;

  final String displayName;

  final String? avatarUploadId;

  final bool self;

  /// Aranızda arkadaşlık ya da istek yoksa alan yoktur.
  final UserProfileFriendState? friendState;

  /// İkinizin de etkin üyesi olduğu tayfalar (en fazla 100); kendi profilinizde boş.
  final List<UserProfileMutualTayfasItem> mutualTayfas;

  /// Katılım geçmişinden size bir şey gösterilip gösterilemeyeceği.
  final bool activityVisible;

  final ActivityVisibility? activityVisibility;

  /// Kişisel rozetler, kazanılma sırasıyla (#258, ADR-0039 §3). Kendi
  /// profilinizde her zaman (yoksa boş liste); başkasınınkinde
  /// yalnızca kişinin kişisel istatistik görünürlüğü size izin
  /// veriyorsa döner (varsayılan kapalı), yoksa alan da yoktur.
  /// Şampiyonluk rozetleri tayfanın içinde ayrıca görünür.
  final List<EarnedBadge>? badges;

  /// Kişisel istatistikler (#267, ADR-0026 §4): kişinin bütün
  /// tayfalarındaki tüm zamanlar toplamı, metrik başına (`attended`,
  /// `duration`, kişisel ölçümler ve günlük kayıtları). Yıl, tarih,
  /// yer ya da tayfa yoktur; hassas ölçüm ve hassas katılım hiç
  /// girmez. `badges` ile aynı kural: kendi profilinizde her zaman
  /// (yoksa boş liste); başkasınınkinde yalnızca kişinin
  /// `stats_visibility` ayarı size izin veriyorsa, yoksa alan da
  /// yoktur (gizlendiği belli edilmez).
  final List<TayfaStat>? stats;

  final Birthday? birthday;

  final List<String>? interests;

  final String? about;

  final String? occupation;

  final String? team;

  final List<String>? languages;

  /// Yalnızca arkadaşlara (ve kendinize) döner.
  final List<SocialAccount>? socialAccounts;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
    'self': self,
    if (friendState case final value?) 'friend_state': value.wire,
    'mutual_tayfas': <Object?>[for (final e0 in mutualTayfas) e0.toJson()],
    'activity_visible': activityVisible,
    if (activityVisibility case final value?) 'activity_visibility': value.wire,
    if (badges case final value?)
      'badges': <Object?>[for (final e0 in value) e0.toJson()],
    if (stats case final value?)
      'stats': <Object?>[for (final e0 in value) e0.toJson()],
    if (birthday case final value?) 'birthday': value.toJson(),
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0],
    if (about case final value?) 'about': value,
    if (occupation case final value?) 'occupation': value,
    if (team case final value?) 'team': value,
    if (languages case final value?)
      'languages': <Object?>[for (final e0 in value) e0],
    if (socialAccounts case final value?)
      'social_accounts': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUploadId == other.avatarUploadId &&
          self == other.self &&
          friendState == other.friendState &&
          _deepEquals(mutualTayfas, other.mutualTayfas) &&
          activityVisible == other.activityVisible &&
          activityVisibility == other.activityVisibility &&
          _deepEquals(badges, other.badges) &&
          _deepEquals(stats, other.stats) &&
          birthday == other.birthday &&
          _deepEquals(interests, other.interests) &&
          about == other.about &&
          occupation == other.occupation &&
          team == other.team &&
          _deepEquals(languages, other.languages) &&
          _deepEquals(socialAccounts, other.socialAccounts);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    displayName,
    avatarUploadId,
    self,
    friendState,
    _deepHash(mutualTayfas),
    activityVisible,
    activityVisibility,
    _deepHash(badges),
    _deepHash(stats),
    birthday,
    _deepHash(interests),
    about,
    occupation,
    team,
    _deepHash(languages),
    _deepHash(socialAccounts),
  ]);
}

/// Aranızda arkadaşlık ya da istek yoksa alan yoktur.
enum UserProfileFriendState {
  friends('friends'),
  incoming('incoming'),
  outgoing('outgoing'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const UserProfileFriendState(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('UserProfileFriendState.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static UserProfileFriendState fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class UserProfileMutualTayfasItem {
  const UserProfileMutualTayfasItem({required this.id, required this.name});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UserProfileMutualTayfasItem.fromJson(Map<String, Object?> json) =>
      UserProfileMutualTayfasItem(
        id: _readString(json['id'], 'UserProfileMutualTayfasItem.id'),
        name: _readString(json['name'], 'UserProfileMutualTayfasItem.name'),
      );

  final String id;

  final String name;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileMutualTayfasItem &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hashAll(<Object?>[id, name]);
}

final class UserRef {
  const UserRef({required this.userId});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory UserRef.fromJson(Map<String, Object?> json) =>
      UserRef(userId: _readString(json['user_id'], 'UserRef.user_id'));

  final String userId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'user_id': userId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserRef && userId == other.userId;

  @override
  int get hashCode => Object.hashAll(<Object?>[userId]);
}

// -------------------------------------------------------------- yardımcılar
// Hata mesajları yalnızca alan yolunu taşır, değeri değil (kesin kural 3).

Never _invalid(String at) => throw FormatException('Geçersiz JSON alanı: $at');

String _readString(Object? value, String at) =>
    value is String ? value : _invalid(at);

int _readInt(Object? value, String at) => value is int ? value : _invalid(at);

double _readDouble(Object? value, String at) =>
    value is num ? value.toDouble() : _invalid(at);

bool _readBool(Object? value, String at) =>
    value is bool ? value : _invalid(at);

/// Yalnızca saat dilimli (`Z` ya da `+03:00`) zamanlar kabul edilir; sonuç UTC.
DateTime _readDateTime(Object? value, String at) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null || !parsed.isUtc) {
    _invalid(at);
  }
  return parsed;
}

Map<String, Object?> _readObject(Object? value, String at) =>
    value is Map<String, Object?> ? value : _invalid(at);

List<Object?> _readList(Object? value, String at) =>
    value is List<Object?> ? value : _invalid(at);

/// Serbest JSON nesnesi (`additionalProperties: true`): değerler çözülmüş
/// JSON'dur ve burada doğrulanmaz; kullanan katman girdi kabul eder.
Map<String, Object?> _readJsonObject(Object? value, String at) =>
    Map<String, Object?>.unmodifiable(_readObject(value, at));

bool _deepEquals(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) ||
          !_deepEquals(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) => switch (value) {
  List<Object?>() => Object.hashAll(value.map(_deepHash)),
  Map<String, Object?>() => Object.hashAllUnordered(
    value.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
  ),
  _ => value.hashCode,
};
