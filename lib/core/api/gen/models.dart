// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

/// Sözleşmedeki şemalar ve satır içi tipleri (ADR-0005).
///
/// Modeller değişmezdir. Okurken tanınmayan JSON alanları yok
/// sayılır; yazarken `null` alanlar yazılmaz. Zamanlar UTC.
/// `toString` bilerek üretilmez: alan değerleri log'a
/// düşmesin (CLAUDE.md kesin kural 3).
library;

final class Account {
  const Account({required this.referralCode, required this.activityVisibility});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Account.fromJson(Map<String, Object?> json) => Account(
    referralCode: _readString(json['referral_code'], 'Account.referral_code'),
    activityVisibility: ActivityVisibility.fromWire(
      _readString(json['activity_visibility'], 'Account.activity_visibility'),
    ),
  );

  /// Örn. `TYF-8K2M4Q`; paylaşım linki `tayfam.app/r/<kod>`.
  final String referralCode;

  final ActivityVisibility activityVisibility;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'referral_code': referralCode,
    'activity_visibility': activityVisibility.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          referralCode == other.referralCode &&
          activityVisibility == other.activityVisibility;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[referralCode, activityVisibility]);
}

final class AccountUpdate {
  const AccountUpdate({required this.activityVisibility});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AccountUpdate.fromJson(Map<String, Object?> json) => AccountUpdate(
    activityVisibility: ActivityVisibility.fromWire(
      _readString(
        json['activity_visibility'],
        'AccountUpdate.activity_visibility',
      ),
    ),
  );

  final ActivityVisibility activityVisibility;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'activity_visibility': activityVisibility.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountUpdate && activityVisibility == other.activityVisibility;

  @override
  int get hashCode => Object.hashAll(<Object?>[activityVisibility]);
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
    eventType: EventType.fromWire(
      _readString(json['event_type'], 'ActivityRecord.event_type'),
    ),
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

  final EventType eventType;

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
    'event_type': eventType.wire,
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
          updatedAt == other.updatedAt;

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
          updatedAt == other.updatedAt;

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
  ]);
}

final class AnswerCreateRequest {
  const AnswerCreateRequest({
    required this.body,
    required this.clientRequestId,
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
      );

  /// Boşluklar atıldıktan sonra 1–10000 karakter; satır sonu olabilir.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 10000.
  final String body;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerCreateRequest &&
          body == other.body &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[body, clientRequestId]);
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

final class AnswerUpdateRequest {
  const AnswerUpdateRequest({required this.body});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory AnswerUpdateRequest.fromJson(Map<String, Object?> json) =>
      AnswerUpdateRequest(
        body: _readString(json['body'], 'AnswerUpdateRequest.body'),
      );

  /// Kısıtlar: minLength: 1; maxLength: 10000.
  final String body;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{'body': body};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerUpdateRequest && body == other.body;

  @override
  int get hashCode => Object.hashAll(<Object?>[body]);
}

/// `location`: buluşma noktasına 300 m içinde check-in. `online`:
/// çevrimiçi etkinlikte "Katıldım". `hike_start`: yürüyüşe çıkış.
/// `organizer`: organizatör düzeltmesi.
enum AttendanceMethod {
  location('location'),
  online('online'),
  hikeStart('hike_start'),
  organizer('organizer'),

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

final class CampDetails {
  const CampDetails({
    this.siteName,
    this.hasWater,
    this.hasToilet,
    this.notes,
    this.items,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CampDetails.fromJson(Map<String, Object?> json) => CampDetails(
    siteName: switch (json['site_name']) {
      null => null,
      final Object v => _readString(v, 'CampDetails.site_name'),
    },
    hasWater: switch (json['has_water']) {
      null => null,
      final Object v => _readBool(v, 'CampDetails.has_water'),
    },
    hasToilet: switch (json['has_toilet']) {
      null => null,
      final Object v => _readBool(v, 'CampDetails.has_toilet'),
    },
    notes: switch (json['notes']) {
      null => null,
      final Object v => _readString(v, 'CampDetails.notes'),
    },
    items: switch (json['items']) {
      null => null,
      final Object v => List<CampItem>.unmodifiable(
        _readList(v, 'CampDetails.items').map(
          (Object? e0) =>
              CampItem.fromJson(_readObject(e0, 'CampDetails.items')),
        ),
      ),
    },
  );

  final String? siteName;

  /// Bilinmiyorsa yoktur.
  final bool? hasWater;

  /// Bilinmiyorsa yoktur.
  final bool? hasToilet;

  final String? notes;

  /// Yalnızca tek etkinlik yanıtında.
  final List<CampItem>? items;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (siteName case final value?) 'site_name': value,
    if (hasWater case final value?) 'has_water': value,
    if (hasToilet case final value?) 'has_toilet': value,
    if (notes case final value?) 'notes': value,
    if (items case final value?)
      'items': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampDetails &&
          siteName == other.siteName &&
          hasWater == other.hasWater &&
          hasToilet == other.hasToilet &&
          notes == other.notes &&
          _deepEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    siteName,
    hasWater,
    hasToilet,
    notes,
    _deepHash(items),
  ]);
}

final class CampDetailsInput {
  const CampDetailsInput({
    this.siteName,
    this.hasWater,
    this.hasToilet,
    this.notes,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CampDetailsInput.fromJson(Map<String, Object?> json) =>
      CampDetailsInput(
        siteName: switch (json['site_name']) {
          null => null,
          final Object v => _readString(v, 'CampDetailsInput.site_name'),
        },
        hasWater: switch (json['has_water']) {
          null => null,
          final Object v => _readBool(v, 'CampDetailsInput.has_water'),
        },
        hasToilet: switch (json['has_toilet']) {
          null => null,
          final Object v => _readBool(v, 'CampDetailsInput.has_toilet'),
        },
        notes: switch (json['notes']) {
          null => null,
          final Object v => _readString(v, 'CampDetailsInput.notes'),
        },
      );

  /// Kısıtlar: maxLength: 120.
  final String? siteName;

  final bool? hasWater;

  final bool? hasToilet;

  /// Kısıtlar: maxLength: 1000.
  final String? notes;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (siteName case final value?) 'site_name': value,
    if (hasWater case final value?) 'has_water': value,
    if (hasToilet case final value?) 'has_toilet': value,
    if (notes case final value?) 'notes': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampDetailsInput &&
          siteName == other.siteName &&
          hasWater == other.hasWater &&
          hasToilet == other.hasToilet &&
          notes == other.notes;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[siteName, hasWater, hasToilet, notes]);
}

final class CampItem {
  const CampItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.assignedUserId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CampItem.fromJson(Map<String, Object?> json) => CampItem(
    id: _readString(json['id'], 'CampItem.id'),
    name: _readString(json['name'], 'CampItem.name'),
    quantity: _readInt(json['quantity'], 'CampItem.quantity'),
    assignedUserId: switch (json['assigned_user_id']) {
      null => null,
      final Object v => _readString(v, 'CampItem.assigned_user_id'),
    },
  );

  final String id;

  final String name;

  final int quantity;

  /// Getirecek kişi.
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
      other is CampItem &&
          id == other.id &&
          name == other.name &&
          quantity == other.quantity &&
          assignedUserId == other.assignedUserId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[id, name, quantity, assignedUserId]);
}

final class CampItemCreateRequest {
  const CampItemCreateRequest({
    required this.name,
    this.quantity,
    this.assignedUserId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory CampItemCreateRequest.fromJson(Map<String, Object?> json) =>
      CampItemCreateRequest(
        name: _readString(json['name'], 'CampItemCreateRequest.name'),
        quantity: switch (json['quantity']) {
          null => null,
          final Object v => _readInt(v, 'CampItemCreateRequest.quantity'),
        },
        assignedUserId: switch (json['assigned_user_id']) {
          null => null,
          final Object v => _readString(
            v,
            'CampItemCreateRequest.assigned_user_id',
          ),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 60.
  final String name;

  /// 0 ya da yok: 1.
  ///
  /// Kısıtlar: minimum: 0; maximum: 999.
  final int? quantity;

  /// Tayfanın etkin bir üyesi.
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
      other is CampItemCreateRequest &&
          name == other.name &&
          quantity == other.quantity &&
          assignedUserId == other.assignedUserId;

  @override
  int get hashCode => Object.hashAll(<Object?>[name, quantity, assignedUserId]);
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
          lastReadMessageId == other.lastReadMessageId;

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
  ]);
}

final class ChannelCreateRequest {
  const ChannelCreateRequest({
    required this.name,
    this.visibility,
    this.slowModeSeconds,
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
      );

  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String name;

  /// Kısıtlar: varsayılan (sunucu): `members`.
  final ChannelCreateRequestVisibility? visibility;

  /// Kısıtlar: minimum: 0; maximum: 3600; varsayılan (sunucu): 0.
  final int? slowModeSeconds;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (visibility case final value?) 'visibility': value.wire,
    if (slowModeSeconds case final value?) 'slow_mode_seconds': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelCreateRequest &&
          name == other.name &&
          visibility == other.visibility &&
          slowModeSeconds == other.slowModeSeconds;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[name, visibility, slowModeSeconds]);
}

/// Kısıtlar: varsayılan (sunucu): `members`.
enum ChannelCreateRequestVisibility {
  members('members'),
  staff('staff'),

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

final class ChannelMessage {
  const ChannelMessage({
    required this.id,
    required this.channelId,
    this.authorUserId,
    this.body,
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
    body: switch (json['body']) {
      null => null,
      final Object v => _readString(v, 'ChannelMessage.body'),
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

  /// Silinmiş mesajda yoktur.
  final String? body;

  final bool deleted;

  /// Yalnızca yöneticilere; moderasyonla gizlenmiş ve hâlâ geri alınabilir.
  final bool? restorable;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'channel_id': channelId,
    if (authorUserId case final value?) 'author_user_id': value,
    if (body case final value?) 'body': value,
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
          body == other.body &&
          deleted == other.deleted &&
          restorable == other.restorable &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    channelId,
    authorUserId,
    body,
    deleted,
    restorable,
    createdAt,
  ]);
}

final class ChannelMessageCreateRequest {
  const ChannelMessageCreateRequest({
    required this.body,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ChannelMessageCreateRequest.fromJson(Map<String, Object?> json) =>
      ChannelMessageCreateRequest(
        body: _readString(json['body'], 'ChannelMessageCreateRequest.body'),
        clientRequestId: _readString(
          json['client_request_id'],
          'ChannelMessageCreateRequest.client_request_id',
        ),
      );

  /// Kısıtlar: minLength: 1; maxLength: 4000.
  final String body;

  /// İstemcinin ürettiği tekrar gönderim anahtarı; mesaj kimliği sunucudadır.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'body': body,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelMessageCreateRequest &&
          body == other.body &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[body, clientRequestId]);
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

/// `members`: tüm etkin üyeler; `staff`: yalnızca yönetici ve moderatörler.
enum ChannelVisibility {
  members('members'),
  staff('staff'),

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

final class ConvoyDetails {
  const ConvoyDetails({this.route, this.vehicles});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConvoyDetails.fromJson(Map<String, Object?> json) => ConvoyDetails(
    route: switch (json['route']) {
      null => null,
      final Object v => List<LatLng>.unmodifiable(
        _readList(v, 'ConvoyDetails.route').map(
          (Object? e0) =>
              LatLng.fromJson(_readObject(e0, 'ConvoyDetails.route')),
        ),
      ),
    },
    vehicles: switch (json['vehicles']) {
      null => null,
      final Object v => List<ConvoyVehicle>.unmodifiable(
        _readList(v, 'ConvoyDetails.vehicles').map(
          (Object? e0) =>
              ConvoyVehicle.fromJson(_readObject(e0, 'ConvoyDetails.vehicles')),
        ),
      ),
    },
  );

  /// Boş ya da 2–500 nokta.
  final List<LatLng>? route;

  /// Yalnızca tek etkinlik yanıtında.
  final List<ConvoyVehicle>? vehicles;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (route case final value?)
      'route': <Object?>[for (final e0 in value) e0.toJson()],
    if (vehicles case final value?)
      'vehicles': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvoyDetails &&
          _deepEquals(route, other.route) &&
          _deepEquals(vehicles, other.vehicles);

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(route), _deepHash(vehicles)]);
}

final class ConvoyDetailsInput {
  const ConvoyDetailsInput({this.route});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConvoyDetailsInput.fromJson(Map<String, Object?> json) =>
      ConvoyDetailsInput(
        route: switch (json['route']) {
          null => null,
          final Object v => List<LatLng>.unmodifiable(
            _readList(v, 'ConvoyDetailsInput.route').map(
              (Object? e0) =>
                  LatLng.fromJson(_readObject(e0, 'ConvoyDetailsInput.route')),
            ),
          ),
        },
      );

  /// Boş ya da 2–500 nokta.
  ///
  /// Kısıtlar: maxItems: 500.
  final List<LatLng>? route;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (route case final value?)
      'route': <Object?>[for (final e0 in value) e0.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvoyDetailsInput && _deepEquals(route, other.route);

  @override
  int get hashCode => Object.hashAll(<Object?>[_deepHash(route)]);
}

final class ConvoyVehicle {
  const ConvoyVehicle({
    required this.id,
    required this.userId,
    required this.make,
    this.model,
    this.modelYear,
    this.color,
    this.plate,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConvoyVehicle.fromJson(Map<String, Object?> json) => ConvoyVehicle(
    id: _readString(json['id'], 'ConvoyVehicle.id'),
    userId: _readString(json['user_id'], 'ConvoyVehicle.user_id'),
    make: _readString(json['make'], 'ConvoyVehicle.make'),
    model: switch (json['model']) {
      null => null,
      final Object v => _readString(v, 'ConvoyVehicle.model'),
    },
    modelYear: switch (json['model_year']) {
      null => null,
      final Object v => _readInt(v, 'ConvoyVehicle.model_year'),
    },
    color: switch (json['color']) {
      null => null,
      final Object v => _readString(v, 'ConvoyVehicle.color'),
    },
    plate: switch (json['plate']) {
      null => null,
      final Object v => _readString(v, 'ConvoyVehicle.plate'),
    },
  );

  final String id;

  final String userId;

  final String make;

  final String? model;

  /// Verilmemişse yoktur.
  final int? modelYear;

  final String? color;

  /// Yalnızca katılımcılara (`going`) ve organizatöre döner.
  final String? plate;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'make': make,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (plate case final value?) 'plate': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvoyVehicle &&
          id == other.id &&
          userId == other.userId &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          plate == other.plate;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    userId,
    make,
    model,
    modelYear,
    color,
    plate,
  ]);
}

final class ConvoyVehicleCreateRequest {
  const ConvoyVehicleCreateRequest({
    required this.make,
    this.model,
    this.modelYear,
    this.color,
    this.plate,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory ConvoyVehicleCreateRequest.fromJson(Map<String, Object?> json) =>
      ConvoyVehicleCreateRequest(
        make: _readString(json['make'], 'ConvoyVehicleCreateRequest.make'),
        model: switch (json['model']) {
          null => null,
          final Object v => _readString(v, 'ConvoyVehicleCreateRequest.model'),
        },
        modelYear: switch (json['model_year']) {
          null => null,
          final Object v => _readInt(
            v,
            'ConvoyVehicleCreateRequest.model_year',
          ),
        },
        color: switch (json['color']) {
          null => null,
          final Object v => _readString(v, 'ConvoyVehicleCreateRequest.color'),
        },
        plate: switch (json['plate']) {
          null => null,
          final Object v => _readString(v, 'ConvoyVehicleCreateRequest.plate'),
        },
      );

  /// Kısıtlar: minLength: 1; maxLength: 40.
  final String make;

  /// Kısıtlar: maxLength: 40.
  final String? model;

  /// 0 ya da 1900 – gelecek yıl.
  final int? modelYear;

  /// Kısıtlar: maxLength: 30.
  final String? color;

  /// İsteğe bağlı, kişisel veri. Harf, rakam ve tek boşluk; 2–16 karakter.
  ///
  /// Kısıtlar: maxLength: 16.
  final String? plate;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'make': make,
    if (model case final value?) 'model': value,
    if (modelYear case final value?) 'model_year': value,
    if (color case final value?) 'color': value,
    if (plate case final value?) 'plate': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConvoyVehicleCreateRequest &&
          make == other.make &&
          model == other.model &&
          modelYear == other.modelYear &&
          color == other.color &&
          plate == other.plate;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[make, model, modelYear, color, plate]);
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
    this.body,
    required this.deleted,
    required this.createdAt,
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
    body: switch (json['body']) {
      null => null,
      final Object v => _readString(v, 'DirectMessage.body'),
    },
    deleted: _readBool(json['deleted'], 'DirectMessage.deleted'),
    createdAt: _readDateTime(json['created_at'], 'DirectMessage.created_at'),
  );

  final String id;

  final String conversationId;

  /// Gönderenin hesabı silindiyse yoktur.
  final String? senderUserId;

  /// Silinmiş mesajda yoktur.
  final String? body;

  final bool deleted;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'conversation_id': conversationId,
    if (senderUserId case final value?) 'sender_user_id': value,
    if (body case final value?) 'body': value,
    'deleted': deleted,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectMessage &&
          id == other.id &&
          conversationId == other.conversationId &&
          senderUserId == other.senderUserId &&
          body == other.body &&
          deleted == other.deleted &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    conversationId,
    senderUserId,
    body,
    deleted,
    createdAt,
  ]);
}

final class DirectMessageCreateRequest {
  const DirectMessageCreateRequest({
    required this.recipientUserId,
    required this.body,
    required this.clientRequestId,
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
        body: _readString(json['body'], 'DirectMessageCreateRequest.body'),
        clientRequestId: _readString(
          json['client_request_id'],
          'DirectMessageCreateRequest.client_request_id',
        ),
      );

  final String recipientUserId;

  /// Kısıtlar: minLength: 1; maxLength: 4000.
  final String body;

  /// İstemcinin ürettiği tekrar gönderim anahtarı.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'recipient_user_id': recipientUserId,
    'body': body,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectMessageCreateRequest &&
          recipientUserId == other.recipientUserId &&
          body == other.body &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[recipientUserId, body, clientRequestId]);
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

/// Bir etkin üyenin gördüğü etkinlik. Türe özel ayrıntı (`convoy`,
/// `camp`, `hike`, `fishing`, `gaming`, `sports`) yalnızca tek etkinlik
/// yanıtında ve en fazla biri dolu gelir.
final class Event {
  const Event({
    required this.id,
    required this.tayfaId,
    required this.type,
    required this.mode,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
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
    this.convoy,
    this.camp,
    this.hike,
    this.fishing,
    this.gaming,
    this.sports,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Event.fromJson(Map<String, Object?> json) => Event(
    id: _readString(json['id'], 'Event.id'),
    tayfaId: _readString(json['tayfa_id'], 'Event.tayfa_id'),
    type: EventType.fromWire(_readString(json['type'], 'Event.type')),
    mode: EventMode.fromWire(_readString(json['mode'], 'Event.mode')),
    title: _readString(json['title'], 'Event.title'),
    description: _readString(json['description'], 'Event.description'),
    startsAt: _readDateTime(json['starts_at'], 'Event.starts_at'),
    endsAt: _readDateTime(json['ends_at'], 'Event.ends_at'),
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
    convoy: switch (json['convoy']) {
      null => null,
      final Object v => ConvoyDetails.fromJson(_readObject(v, 'Event.convoy')),
    },
    camp: switch (json['camp']) {
      null => null,
      final Object v => CampDetails.fromJson(_readObject(v, 'Event.camp')),
    },
    hike: switch (json['hike']) {
      null => null,
      final Object v => HikeDetails.fromJson(_readObject(v, 'Event.hike')),
    },
    fishing: switch (json['fishing']) {
      null => null,
      final Object v => FishingDetails.fromJson(
        _readObject(v, 'Event.fishing'),
      ),
    },
    gaming: switch (json['gaming']) {
      null => null,
      final Object v => GamingDetails.fromJson(_readObject(v, 'Event.gaming')),
    },
    sports: switch (json['sports']) {
      null => null,
      final Object v => SportsDetails.fromJson(_readObject(v, 'Event.sports')),
    },
  );

  final String id;

  final String tayfaId;

  final EventType type;

  final EventMode mode;

  final String title;

  final String description;

  final DateTime startsAt;

  final DateTime endsAt;

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

  final ConvoyDetails? convoy;

  final CampDetails? camp;

  final HikeDetails? hike;

  final FishingDetails? fishing;

  final GamingDetails? gaming;

  final SportsDetails? sports;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tayfa_id': tayfaId,
    'type': type.wire,
    'mode': mode.wire,
    'title': title,
    'description': description,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
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
    if (convoy case final value?) 'convoy': value.toJson(),
    if (camp case final value?) 'camp': value.toJson(),
    if (hike case final value?) 'hike': value.toJson(),
    if (fishing case final value?) 'fishing': value.toJson(),
    if (gaming case final value?) 'gaming': value.toJson(),
    if (sports case final value?) 'sports': value.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          id == other.id &&
          tayfaId == other.tayfaId &&
          type == other.type &&
          mode == other.mode &&
          title == other.title &&
          description == other.description &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
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
          updatedAt == other.updatedAt &&
          convoy == other.convoy &&
          camp == other.camp &&
          hike == other.hike &&
          fishing == other.fishing &&
          gaming == other.gaming &&
          sports == other.sports;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    tayfaId,
    type,
    mode,
    title,
    description,
    startsAt,
    endsAt,
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
    convoy,
    camp,
    hike,
    fishing,
    gaming,
    sports,
  ]);
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

/// Yüz yüze: `meeting_point`, `city`, `district` zorunlu; `online_url`
/// boş. Çevrimiçi: `online_url` (https) zorunlu; yer alanları boş.
/// Türe özel ayrıntı en fazla bir tane ve türle aynı olur; `gaming` ve
/// `sports` için zorunlu, `general` için yoktur.
final class EventCreateRequest {
  const EventCreateRequest({
    required this.type,
    required this.mode,
    required this.title,
    this.description,
    required this.startsAt,
    required this.endsAt,
    this.meetingPointName,
    this.meetingPoint,
    this.city,
    this.district,
    this.onlineUrl,
    this.capacity,
    this.discoverable,
    this.convoy,
    this.camp,
    this.hike,
    this.fishing,
    this.gaming,
    this.sports,
    this.recurrence,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventCreateRequest.fromJson(
    Map<String, Object?> json,
  ) => EventCreateRequest(
    type: EventType.fromWire(
      _readString(json['type'], 'EventCreateRequest.type'),
    ),
    mode: EventMode.fromWire(
      _readString(json['mode'], 'EventCreateRequest.mode'),
    ),
    title: _readString(json['title'], 'EventCreateRequest.title'),
    description: switch (json['description']) {
      null => null,
      final Object v => _readString(v, 'EventCreateRequest.description'),
    },
    startsAt: _readDateTime(json['starts_at'], 'EventCreateRequest.starts_at'),
    endsAt: _readDateTime(json['ends_at'], 'EventCreateRequest.ends_at'),
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
    convoy: switch (json['convoy']) {
      null => null,
      final Object v => ConvoyDetailsInput.fromJson(
        _readObject(v, 'EventCreateRequest.convoy'),
      ),
    },
    camp: switch (json['camp']) {
      null => null,
      final Object v => CampDetailsInput.fromJson(
        _readObject(v, 'EventCreateRequest.camp'),
      ),
    },
    hike: switch (json['hike']) {
      null => null,
      final Object v => HikeDetails.fromJson(
        _readObject(v, 'EventCreateRequest.hike'),
      ),
    },
    fishing: switch (json['fishing']) {
      null => null,
      final Object v => FishingDetails.fromJson(
        _readObject(v, 'EventCreateRequest.fishing'),
      ),
    },
    gaming: switch (json['gaming']) {
      null => null,
      final Object v => GamingDetails.fromJson(
        _readObject(v, 'EventCreateRequest.gaming'),
      ),
    },
    sports: switch (json['sports']) {
      null => null,
      final Object v => SportsDetails.fromJson(
        _readObject(v, 'EventCreateRequest.sports'),
      ),
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

  final EventType type;

  final EventMode mode;

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 1–120 karakter.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 120.
  final String title;

  /// Kısıtlar: maxLength: 5000.
  final String? description;

  /// Gelecekte
  final DateTime startsAt;

  /// Başlangıçtan sonra
  final DateTime endsAt;

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

  final bool? discoverable;

  final ConvoyDetailsInput? convoy;

  final CampDetailsInput? camp;

  final HikeDetails? hike;

  final FishingDetails? fishing;

  final GamingDetails? gaming;

  final SportsDetails? sports;

  final Recurrence? recurrence;

  /// İstemcinin her açma denemesi için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wire,
    'mode': mode.wire,
    'title': title,
    if (description case final value?) 'description': value,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    if (meetingPointName case final value?) 'meeting_point_name': value,
    if (meetingPoint case final value?) 'meeting_point': value.toJson(),
    if (city case final value?) 'city': value,
    if (district case final value?) 'district': value,
    if (onlineUrl case final value?) 'online_url': value,
    if (capacity case final value?) 'capacity': value,
    if (discoverable case final value?) 'discoverable': value,
    if (convoy case final value?) 'convoy': value.toJson(),
    if (camp case final value?) 'camp': value.toJson(),
    if (hike case final value?) 'hike': value.toJson(),
    if (fishing case final value?) 'fishing': value.toJson(),
    if (gaming case final value?) 'gaming': value.toJson(),
    if (sports case final value?) 'sports': value.toJson(),
    if (recurrence case final value?) 'recurrence': value.toJson(),
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCreateRequest &&
          type == other.type &&
          mode == other.mode &&
          title == other.title &&
          description == other.description &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          meetingPointName == other.meetingPointName &&
          meetingPoint == other.meetingPoint &&
          city == other.city &&
          district == other.district &&
          onlineUrl == other.onlineUrl &&
          capacity == other.capacity &&
          discoverable == other.discoverable &&
          convoy == other.convoy &&
          camp == other.camp &&
          hike == other.hike &&
          fishing == other.fishing &&
          gaming == other.gaming &&
          sports == other.sports &&
          recurrence == other.recurrence &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    type,
    mode,
    title,
    description,
    startsAt,
    endsAt,
    meetingPointName,
    meetingPoint,
    city,
    district,
    onlineUrl,
    capacity,
    discoverable,
    convoy,
    camp,
    hike,
    fishing,
    gaming,
    sports,
    recurrence,
    clientRequestId,
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

/// Tayfanın ilgi alanları etkinlik türleriyle aynı değerleri kullanır.
enum EventType {
  convoy('convoy'),
  camp('camp'),
  hike('hike'),
  fishing('fishing'),
  gaming('gaming'),
  sports('sports'),
  general('general'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const EventType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('EventType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static EventType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

/// Kurallar açmadakiyle aynıdır; tür değişmez.
///
/// Kısıtlar: minProperties: 1.
final class EventUpdateRequest {
  const EventUpdateRequest({
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
    this.convoy,
    this.camp,
    this.hike,
    this.fishing,
    this.gaming,
    this.sports,
    this.applyToSeries,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory EventUpdateRequest.fromJson(Map<String, Object?> json) =>
      EventUpdateRequest(
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
          final Object v => _readString(
            v,
            'EventUpdateRequest.meeting_point_name',
          ),
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
        convoy: switch (json['convoy']) {
          null => null,
          final Object v => ConvoyDetailsInput.fromJson(
            _readObject(v, 'EventUpdateRequest.convoy'),
          ),
        },
        camp: switch (json['camp']) {
          null => null,
          final Object v => CampDetailsInput.fromJson(
            _readObject(v, 'EventUpdateRequest.camp'),
          ),
        },
        hike: switch (json['hike']) {
          null => null,
          final Object v => HikeDetails.fromJson(
            _readObject(v, 'EventUpdateRequest.hike'),
          ),
        },
        fishing: switch (json['fishing']) {
          null => null,
          final Object v => FishingDetails.fromJson(
            _readObject(v, 'EventUpdateRequest.fishing'),
          ),
        },
        gaming: switch (json['gaming']) {
          null => null,
          final Object v => GamingDetails.fromJson(
            _readObject(v, 'EventUpdateRequest.gaming'),
          ),
        },
        sports: switch (json['sports']) {
          null => null,
          final Object v => SportsDetails.fromJson(
            _readObject(v, 'EventUpdateRequest.sports'),
          ),
        },
        applyToSeries: switch (json['apply_to_series']) {
          null => null,
          final Object v => _readBool(v, 'EventUpdateRequest.apply_to_series'),
        },
      );

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

  final bool? discoverable;

  final ConvoyDetailsInput? convoy;

  final CampDetailsInput? camp;

  final HikeDetails? hike;

  final FishingDetails? fishing;

  final GamingDetails? gaming;

  final SportsDetails? sports;

  /// `true` yalnızca seriye ait etkinlikte geçerlidir; yoksa `false`.
  final bool? applyToSeries;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
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
    if (convoy case final value?) 'convoy': value.toJson(),
    if (camp case final value?) 'camp': value.toJson(),
    if (hike case final value?) 'hike': value.toJson(),
    if (fishing case final value?) 'fishing': value.toJson(),
    if (gaming case final value?) 'gaming': value.toJson(),
    if (sports case final value?) 'sports': value.toJson(),
    if (applyToSeries case final value?) 'apply_to_series': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventUpdateRequest &&
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
          convoy == other.convoy &&
          camp == other.camp &&
          hike == other.hike &&
          fishing == other.fishing &&
          gaming == other.gaming &&
          sports == other.sports &&
          applyToSeries == other.applyToSeries;

  @override
  int get hashCode => Object.hashAll(<Object?>[
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
    convoy,
    camp,
    hike,
    fishing,
    gaming,
    sports,
    applyToSeries,
  ]);
}

final class FishingCatch {
  const FishingCatch({
    required this.id,
    required this.userId,
    required this.species,
    required this.lengthCm,
    this.location,
    required this.visibility,
    required this.createdAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FishingCatch.fromJson(Map<String, Object?> json) => FishingCatch(
    id: _readString(json['id'], 'FishingCatch.id'),
    userId: _readString(json['user_id'], 'FishingCatch.user_id'),
    species: _readString(json['species'], 'FishingCatch.species'),
    lengthCm: _readDouble(json['length_cm'], 'FishingCatch.length_cm'),
    location: switch (json['location']) {
      null => null,
      final Object v => LatLng.fromJson(
        _readObject(v, 'FishingCatch.location'),
      ),
    },
    visibility: FishingCatchVisibility.fromWire(
      _readString(json['visibility'], 'FishingCatch.visibility'),
    ),
    createdAt: _readDateTime(json['created_at'], 'FishingCatch.created_at'),
  );

  final String id;

  final String userId;

  final String species;

  final double lengthCm;

  /// Avcıya, `tayfa` görünürlüğünde noktayı görebilenlere döner.
  final LatLng? location;

  final FishingCatchVisibility visibility;

  final DateTime createdAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'species': species,
    'length_cm': lengthCm,
    if (location case final value?) 'location': value.toJson(),
    'visibility': visibility.wire,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FishingCatch &&
          id == other.id &&
          userId == other.userId &&
          species == other.species &&
          lengthCm == other.lengthCm &&
          location == other.location &&
          visibility == other.visibility &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    userId,
    species,
    lengthCm,
    location,
    visibility,
    createdAt,
  ]);
}

final class FishingCatchCreateRequest {
  const FishingCatchCreateRequest({
    required this.species,
    required this.lengthCm,
    this.location,
    this.visibility,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FishingCatchCreateRequest.fromJson(Map<String, Object?> json) =>
      FishingCatchCreateRequest(
        species: _readString(
          json['species'],
          'FishingCatchCreateRequest.species',
        ),
        lengthCm: _readDouble(
          json['length_cm'],
          'FishingCatchCreateRequest.length_cm',
        ),
        location: switch (json['location']) {
          null => null,
          final Object v => LatLng.fromJson(
            _readObject(v, 'FishingCatchCreateRequest.location'),
          ),
        },
        visibility: switch (json['visibility']) {
          null => null,
          final Object v => FishingCatchCreateRequestVisibility.fromWire(
            _readString(v, 'FishingCatchCreateRequest.visibility'),
          ),
        },
        clientRequestId: _readString(
          json['client_request_id'],
          'FishingCatchCreateRequest.client_request_id',
        ),
      );

  /// Kısıtlar: minLength: 1; maxLength: 60.
  final String species;

  /// Bir ondalık.
  ///
  /// Kısıtlar: maximum: 1000; exclusiveMinimum: 0.
  final double lengthCm;

  final LatLng? location;

  /// Konumu kim görür; av kendisi her etkin üyeye görünür.
  ///
  /// Kısıtlar: varsayılan (sunucu): `self`.
  final FishingCatchCreateRequestVisibility? visibility;

  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'species': species,
    'length_cm': lengthCm,
    if (location case final value?) 'location': value.toJson(),
    if (visibility case final value?) 'visibility': value.wire,
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FishingCatchCreateRequest &&
          species == other.species &&
          lengthCm == other.lengthCm &&
          location == other.location &&
          visibility == other.visibility &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    species,
    lengthCm,
    location,
    visibility,
    clientRequestId,
  ]);
}

/// Konumu kim görür; av kendisi her etkin üyeye görünür.
///
/// Kısıtlar: varsayılan (sunucu): `self`.
enum FishingCatchCreateRequestVisibility {
  self('self'),
  tayfa('tayfa'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const FishingCatchCreateRequestVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError(
        'FishingCatchCreateRequestVisibility.unknown gönderilemez',
      ));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static FishingCatchCreateRequestVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class FishingCatchList {
  const FishingCatchList({required this.catches, this.nextPageToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FishingCatchList.fromJson(Map<String, Object?> json) =>
      FishingCatchList(
        catches: List<FishingCatch>.unmodifiable(
          _readList(json['catches'], 'FishingCatchList.catches').map(
            (Object? e0) => FishingCatch.fromJson(
              _readObject(e0, 'FishingCatchList.catches'),
            ),
          ),
        ),
        nextPageToken: switch (json['next_page_token']) {
          null => null,
          final Object v => _readString(v, 'FishingCatchList.next_page_token'),
        },
      );

  final List<FishingCatch> catches;

  final String? nextPageToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'catches': <Object?>[for (final e0 in catches) e0.toJson()],
    if (nextPageToken case final value?) 'next_page_token': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FishingCatchList &&
          _deepEquals(catches, other.catches) &&
          nextPageToken == other.nextPageToken;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[_deepHash(catches), nextPageToken]);
}

enum FishingCatchVisibility {
  self('self'),
  tayfa('tayfa'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const FishingCatchVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('FishingCatchVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static FishingCatchVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class FishingDetails {
  const FishingDetails({this.spotVisibility});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory FishingDetails.fromJson(Map<String, Object?> json) => FishingDetails(
    spotVisibility: switch (json['spot_visibility']) {
      null => null,
      final Object v => FishingDetailsSpotVisibility.fromWire(
        _readString(v, 'FishingDetails.spot_visibility'),
      ),
    },
  );

  /// `participants`: buluşma noktasını yalnızca organizatör, moderatör,
  /// yönetici ve `going`/`maybe` cevabı verenler görür. Yoksa `tayfa`.
  final FishingDetailsSpotVisibility? spotVisibility;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (spotVisibility case final value?) 'spot_visibility': value.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FishingDetails && spotVisibility == other.spotVisibility;

  @override
  int get hashCode => Object.hashAll(<Object?>[spotVisibility]);
}

/// `participants`: buluşma noktasını yalnızca organizatör, moderatör,
/// yönetici ve `going`/`maybe` cevabı verenler görür. Yoksa `tayfa`.
enum FishingDetailsSpotVisibility {
  tayfa('tayfa'),
  participants('participants'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const FishingDetailsSpotVisibility(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ??
      (throw StateError('FishingDetailsSpotVisibility.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static FishingDetailsSpotVisibility fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class Friend {
  const Friend({
    required this.userId,
    required this.displayName,
    this.avatarUploadId,
    required this.state,
    required this.requestedAt,
    this.acceptedAt,
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
  );

  final String userId;

  final String displayName;

  final String? avatarUploadId;

  /// `incoming`: size gelen istek; `outgoing`: sizin isteğiniz.
  final FriendState state;

  final DateTime requestedAt;

  final DateTime? acceptedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'display_name': displayName,
    if (avatarUploadId case final value?) 'avatar_upload_id': value,
    'state': state.wire,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    if (acceptedAt case final value?)
      'accepted_at': value.toUtc().toIso8601String(),
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
          acceptedAt == other.acceptedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    userId,
    displayName,
    avatarUploadId,
    state,
    requestedAt,
    acceptedAt,
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

final class GamingDetails {
  const GamingDetails({required this.game, required this.platform});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory GamingDetails.fromJson(Map<String, Object?> json) => GamingDetails(
    game: _readString(json['game'], 'GamingDetails.game'),
    platform: GamingDetailsPlatform.fromWire(
      _readString(json['platform'], 'GamingDetails.platform'),
    ),
  );

  /// Kısıtlar: minLength: 1; maxLength: 60.
  final String game;

  final GamingDetailsPlatform platform;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'game': game,
    'platform': platform.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamingDetails &&
          game == other.game &&
          platform == other.platform;

  @override
  int get hashCode => Object.hashAll(<Object?>[game, platform]);
}

enum GamingDetailsPlatform {
  pc('pc'),
  playstation('playstation'),
  xbox('xbox'),
  switch_('switch'),
  mobile('mobile'),
  other('other'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const GamingDetailsPlatform(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('GamingDetailsPlatform.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static GamingDetailsPlatform fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}

final class HikeCheckin {
  const HikeCheckin({required this.startedAt, this.returnedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HikeCheckin.fromJson(Map<String, Object?> json) => HikeCheckin(
    startedAt: _readDateTime(json['started_at'], 'HikeCheckin.started_at'),
    returnedAt: switch (json['returned_at']) {
      null => null,
      final Object v => _readDateTime(v, 'HikeCheckin.returned_at'),
    },
  );

  final DateTime startedAt;

  /// Dönülmediyse yoktur.
  final DateTime? returnedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'started_at': startedAt.toUtc().toIso8601String(),
    if (returnedAt case final value?)
      'returned_at': value.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HikeCheckin &&
          startedAt == other.startedAt &&
          returnedAt == other.returnedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[startedAt, returnedAt]);
}

final class HikeDetails {
  const HikeDetails({
    this.difficulty,
    this.distanceKm,
    this.elevationM,
    this.expectedReturnAt,
    this.returnGraceMinutes,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HikeDetails.fromJson(Map<String, Object?> json) => HikeDetails(
    difficulty: switch (json['difficulty']) {
      null => null,
      final Object v => _readInt(v, 'HikeDetails.difficulty'),
    },
    distanceKm: switch (json['distance_km']) {
      null => null,
      final Object v => _readDouble(v, 'HikeDetails.distance_km'),
    },
    elevationM: switch (json['elevation_m']) {
      null => null,
      final Object v => _readInt(v, 'HikeDetails.elevation_m'),
    },
    expectedReturnAt: switch (json['expected_return_at']) {
      null => null,
      final Object v => _readDateTime(v, 'HikeDetails.expected_return_at'),
    },
    returnGraceMinutes: switch (json['return_grace_minutes']) {
      null => null,
      final Object v => _readInt(v, 'HikeDetails.return_grace_minutes'),
    },
  );

  /// 0: verilmemiş.
  ///
  /// Kısıtlar: minimum: 0; maximum: 5.
  final int? difficulty;

  /// 0: verilmemiş; iki ondalık.
  ///
  /// Kısıtlar: minimum: 0; maximum: 1000.
  final double? distanceKm;

  /// 0: verilmemiş.
  ///
  /// Kısıtlar: minimum: 0; maximum: 9000.
  final int? elevationM;

  /// Başlangıçtan sonra.
  final DateTime? expectedReturnAt;

  /// 0: varsayılan 30.
  ///
  /// Kısıtlar: minimum: 0; maximum: 1440.
  final int? returnGraceMinutes;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (difficulty case final value?) 'difficulty': value,
    if (distanceKm case final value?) 'distance_km': value,
    if (elevationM case final value?) 'elevation_m': value,
    if (expectedReturnAt case final value?)
      'expected_return_at': value.toUtc().toIso8601String(),
    if (returnGraceMinutes case final value?) 'return_grace_minutes': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HikeDetails &&
          difficulty == other.difficulty &&
          distanceKm == other.distanceKm &&
          elevationM == other.elevationM &&
          expectedReturnAt == other.expectedReturnAt &&
          returnGraceMinutes == other.returnGraceMinutes;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    difficulty,
    distanceKm,
    elevationM,
    expectedReturnAt,
    returnGraceMinutes,
  ]);
}

final class HikeReturnRequest {
  const HikeReturnRequest({this.returnedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HikeReturnRequest.fromJson(Map<String, Object?> json) =>
      HikeReturnRequest(
        returnedAt: switch (json['returned_at']) {
          null => null,
          final Object v => _readDateTime(v, 'HikeReturnRequest.returned_at'),
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
      other is HikeReturnRequest && returnedAt == other.returnedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[returnedAt]);
}

final class HikeStartRequest {
  const HikeStartRequest({this.startedAt});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory HikeStartRequest.fromJson(Map<String, Object?> json) =>
      HikeStartRequest(
        startedAt: switch (json['started_at']) {
          null => null,
          final Object v => _readDateTime(v, 'HikeStartRequest.started_at'),
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
      other is HikeStartRequest && startedAt == other.startedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[startedAt]);
}

final class Invitation {
  const Invitation({
    required this.tayfaId,
    required this.tayfaName,
    required this.userId,
    this.inviterUserId,
    required this.invitedAt,
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
  );

  final String tayfaId;

  final String tayfaName;

  /// Davet edilen kişi.
  final String userId;

  /// Davet edenin hesabı silinmişse yoktur.
  final String? inviterUserId;

  final DateTime invitedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'tayfa_name': tayfaName,
    'user_id': userId,
    if (inviterUserId case final value?) 'inviter_user_id': value,
    'invited_at': invitedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invitation &&
          tayfaId == other.tayfaId &&
          tayfaName == other.tayfaName &&
          userId == other.userId &&
          inviterUserId == other.inviterUserId &&
          invitedAt == other.invitedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    tayfaId,
    tayfaName,
    userId,
    inviterUserId,
    invitedAt,
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
  );

  final String tayfaId;

  final String name;

  final int memberCount;

  /// Zaten etkin üyeyseniz ya da bekleyen isteğiniz varsa.
  final bool alreadyMember;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'name': name,
    'member_count': memberCount,
    'already_member': alreadyMember,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitePreview &&
          tayfaId == other.tayfaId &&
          name == other.name &&
          memberCount == other.memberCount &&
          alreadyMember == other.alreadyMember;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[tayfaId, name, memberCount, alreadyMember]);
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
  );

  final String tayfaId;

  final String userId;

  final Role role;

  final MembershipStatus status;

  /// Üyelik etkin olduğunda.
  final DateTime? joinedAt;

  /// Susturma bitişi; yalnızca üyenin kendisine, moderatöre ve yöneticiye döner.
  final DateTime? mutedUntil;

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
          mutedUntil == other.mutedUntil;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    tayfaId,
    userId,
    role,
    status,
    joinedAt,
    mutedUntil,
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
  );

  final String id;

  final String tayfaId;

  final ReportTargetType targetType;

  final String targetId;

  /// Şikâyet edilen üye ya da içeriğin yazarı; hesap silindiyse yoktur.
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
          resolvedAt == other.resolvedAt;

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

enum Module {
  announcements('announcements'),
  events('events'),
  qa('qa'),
  polls('polls'),

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

  /// Birebir mesaj şikâyetinde yoktur.
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

  final Role role;

  final MyTayfaStatus status;

  /// Yalnızca etkin üyelikte.
  final Tayfa? tayfa;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa_id': tayfaId,
    'name': name,
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
          role == other.role &&
          status == other.status &&
          tayfa == other.tayfa;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[tayfaId, name, role, status, tayfa]);
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
  /// mesaj sayısını `unread_count` taşır. Tanınmayan değer `unknown`.
  final NotificationType type;

  /// Bildirim bir tayfayla ilgili değilse yoktur.
  final String? tayfaId;

  /// İşlemi yapan; sistem ya da silinmiş hesapsa yoktur.
  final String? actorId;

  /// `membership` için `target_id` başvuran kullanıcının kimliğidir;
  /// `user` için bir kullanıcının kimliği (profilini açın); `report`
  /// için kendi şikâyetinizin kimliği; `dm_conversation` için
  /// konuşmanızın kimliği.
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

  /// Şimdilik yalnızca `tayfa`; kanal ve konuşma sonra gelir.
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

/// Şimdilik yalnızca `tayfa`; kanal ve konuşma sonra gelir.
enum NotificationPreferenceScopeType {
  tayfa('tayfa'),
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

/// `membership` için `target_id` başvuran kullanıcının kimliğidir;
/// `user` için bir kullanıcının kimliği (profilini açın); `report`
/// için kendi şikâyetinizin kimliği; `dm_conversation` için
/// konuşmanızın kimliği.
enum NotificationTargetType {
  tayfa('tayfa'),
  membership('membership'),
  announcement('announcement'),
  event('event'),
  answer('answer'),
  user('user'),
  report('report'),
  dmConversation('dm_conversation'),

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
/// mesaj sayısını `unread_count` taşır. Tanınmayan değer `unknown`.
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

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'question': question,
    'options': <Object?>[for (final e0 in options) e0],
    if (anonymous case final value?) 'anonymous': value,
    if (multipleChoice case final value?) 'multiple_choice': value,
    if (closesAt case final value?)
      'closes_at': value.toUtc().toIso8601String(),
    if (eventId case final value?) 'event_id': value,
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
          eventId == other.eventId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    question,
    _deepHash(options),
    anonymous,
    multipleChoice,
    closesAt,
    eventId,
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
  );

  final String id;

  final String tayfaId;

  /// Yazarın hesabı silindiyse yoktur ("Silinmiş kullanıcı").
  final String? authorUserId;

  final String title;

  final String body;

  final List<Tag> tags;

  /// Görünen cevap sayısı.
  final int answerCount;

  final DateTime createdAt;

  /// Her düzenleme ve geri almada değişir.
  final DateTime updatedAt;

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
          updatedAt == other.updatedAt;

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
  ]);
}

final class QuestionCreateRequest {
  const QuestionCreateRequest({
    required this.title,
    this.body,
    this.tags,
    required this.clientRequestId,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory QuestionCreateRequest.fromJson(Map<String, Object?> json) =>
      QuestionCreateRequest(
        title: _readString(json['title'], 'QuestionCreateRequest.title'),
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
      );

  /// Baştaki ve sondaki boşluklar atıldıktan sonra 10–150 karakter, tek satır.
  ///
  /// Kısıtlar: minLength: 10; maxLength: 150.
  final String title;

  /// En fazla 10000 karakter; satır sonu olabilir.
  ///
  /// Kısıtlar: maxLength: 10000.
  final String? body;

  /// Etiket adları; her biri 1–30 karakter, tek satır, iç boşluklar teke iner.
  ///
  /// Kısıtlar: maxItems: 5.
  final List<String>? tags;

  /// İstemcinin her deneme için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    if (body case final value?) 'body': value,
    if (tags case final value?) 'tags': <Object?>[for (final e0 in value) e0],
    'client_request_id': clientRequestId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionCreateRequest &&
          title == other.title &&
          body == other.body &&
          _deepEquals(tags, other.tags) &&
          clientRequestId == other.clientRequestId;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[title, body, _deepHash(tags), clientRequestId]);
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

/// Kısıtlar: minProperties: 1.
final class QuestionUpdateRequest {
  const QuestionUpdateRequest({this.title, this.body, this.tags});

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
      );

  /// Kısıtlar: minLength: 10; maxLength: 150.
  final String? title;

  /// Kısıtlar: maxLength: 10000.
  final String? body;

  /// Kısıtlar: maxItems: 5.
  final List<String>? tags;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (title case final value?) 'title': value,
    if (body case final value?) 'body': value,
    if (tags case final value?) 'tags': <Object?>[for (final e0 in value) e0],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionUpdateRequest &&
          title == other.title &&
          body == other.body &&
          _deepEquals(tags, other.tags);

  @override
  int get hashCode => Object.hashAll(<Object?>[title, body, _deepHash(tags)]);
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
  const RefreshRequest({required this.refreshToken});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory RefreshRequest.fromJson(Map<String, Object?> json) => RefreshRequest(
    refreshToken: _readString(
      json['refresh_token'],
      'RefreshRequest.refresh_token',
    ),
  );

  /// Kısıtlar: maxLength: 64.
  final String refreshToken;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'refresh_token': refreshToken,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefreshRequest && refreshToken == other.refreshToken;

  @override
  int get hashCode => Object.hashAll(<Object?>[refreshToken]);
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
      );

  final ReportTargetType targetType;

  /// `tayfa` için yoldaki `tayfa_id` ile aynı olmalıdır.
  final String targetId;

  final ReportReason reason;

  /// İsteğe bağlı; baştaki ve sondaki boşluklar atılır. Satır sonu olabilir.
  ///
  /// Kısıtlar: maxLength: 1000.
  final String? description;

  /// Yalnızca ve zorunlu olarak `dm_message` için: şikâyet ettiğiniz
  /// mesajın kendi cihazınızdan paylaştığınız metni. Yalnızca platform
  /// okur; log'a ve olaylara yazılmaz, size geri dönmez.
  ///
  /// Kısıtlar: minLength: 1; maxLength: 2000.
  final String? evidenceText;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'target_type': targetType.wire,
    'target_id': targetId,
    'reason': reason.wire,
    if (description case final value?) 'description': value,
    if (evidenceText case final value?) 'evidence_text': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportCreateRequest &&
          targetType == other.targetType &&
          targetId == other.targetId &&
          reason == other.reason &&
          description == other.description &&
          evidenceText == other.evidenceText;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    targetType,
    targetId,
    reason,
    description,
    evidenceText,
  ]);
}

/// Topluluk Kuralları'na göre. `child_safety` (çocuk/genç güvenliği)
/// kuyrukta öne geçer ve hemen platforma da gider; `staff_conduct`
/// (yönetici/moderatörün yetkisini kullanımı) yalnızca platforma gider.
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
/// diğerleri yalnızca tayfa ucuyla. Kanal mesajları bu listede değildir.
enum ReportTargetType {
  user('user'),
  tayfa('tayfa'),
  announcement('announcement'),
  event('event'),
  question('question'),
  answer('answer'),
  poll('poll'),
  fishingCatch('fishing_catch'),
  dmMessage('dm_message'),

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
          consentRequired == other.consentRequired;

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
  ]);
}

final class SignInRequest {
  const SignInRequest({
    required this.provider,
    required this.idToken,
    required this.nonce,
    required this.platform,
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
  );

  final SignInRequestProvider provider;

  /// Kısıtlar: maxLength: 8192.
  final String idToken;

  /// Kısıtlar: minLength: 16; maxLength: 256.
  final String nonce;

  /// `web` yalnızca prod dışında (ADR-0017).
  final SignInRequestPlatform platform;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'provider': provider.wire,
    'id_token': idToken,
    'nonce': nonce,
    'platform': platform.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInRequest &&
          provider == other.provider &&
          idToken == other.idToken &&
          nonce == other.nonce &&
          platform == other.platform;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[provider, idToken, nonce, platform]);
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

final class SportsDetails {
  const SportsDetails({required this.sport, this.venueName});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory SportsDetails.fromJson(Map<String, Object?> json) => SportsDetails(
    sport: SportsDetailsSport.fromWire(
      _readString(json['sport'], 'SportsDetails.sport'),
    ),
    venueName: switch (json['venue_name']) {
      null => null,
      final Object v => _readString(v, 'SportsDetails.venue_name'),
    },
  );

  final SportsDetailsSport sport;

  /// Kısıtlar: maxLength: 120.
  final String? venueName;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'sport': sport.wire,
    if (venueName case final value?) 'venue_name': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SportsDetails &&
          sport == other.sport &&
          venueName == other.venueName;

  @override
  int get hashCode => Object.hashAll(<Object?>[sport, venueName]);
}

enum SportsDetailsSport {
  football('football'),
  tableFootball('table_football'),
  basketball('basketball'),
  volleyball('volleyball'),
  tennis('tennis'),
  tableTennis('table_tennis'),
  other('other'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const SportsDetailsSport(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('SportsDetailsSport.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static SportsDetailsSport fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
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
    required this.id,
    required this.name,
    required this.description,
    required this.interests,
    required this.joinPolicy,
    required this.modules,
    required this.status,
    this.suspendedAt,
    this.deletionAt,
    required this.memberCount,
    required this.membersCanCreateEvents,
    this.joinCode,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory Tayfa.fromJson(Map<String, Object?> json) => Tayfa(
    id: _readString(json['id'], 'Tayfa.id'),
    name: _readString(json['name'], 'Tayfa.name'),
    description: _readString(json['description'], 'Tayfa.description'),
    interests: List<EventType>.unmodifiable(
      _readList(json['interests'], 'Tayfa.interests').map(
        (Object? e0) => EventType.fromWire(_readString(e0, 'Tayfa.interests')),
      ),
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
    joinCode: switch (json['join_code']) {
      null => null,
      final Object v => _readString(v, 'Tayfa.join_code'),
    },
    createdAt: _readDateTime(json['created_at'], 'Tayfa.created_at'),
    updatedAt: _readDateTime(json['updated_at'], 'Tayfa.updated_at'),
  );

  final String id;

  final String name;

  final String description;

  final List<EventType> interests;

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

  /// Yalnızca yöneticiye döner.
  final String? joinCode;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'interests': <Object?>[for (final e0 in interests) e0.wire],
    'join_policy': joinPolicy.wire,
    'modules': modules.toJson(),
    'status': status.wire,
    if (suspendedAt case final value?)
      'suspended_at': value.toUtc().toIso8601String(),
    if (deletionAt case final value?)
      'deletion_at': value.toUtc().toIso8601String(),
    'member_count': memberCount,
    'members_can_create_events': membersCanCreateEvents,
    if (joinCode case final value?) 'join_code': value,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tayfa &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          _deepEquals(interests, other.interests) &&
          joinPolicy == other.joinPolicy &&
          modules == other.modules &&
          status == other.status &&
          suspendedAt == other.suspendedAt &&
          deletionAt == other.deletionAt &&
          memberCount == other.memberCount &&
          membersCanCreateEvents == other.membersCanCreateEvents &&
          joinCode == other.joinCode &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    name,
    description,
    _deepHash(interests),
    joinPolicy,
    modules,
    status,
    suspendedAt,
    deletionAt,
    memberCount,
    membersCanCreateEvents,
    joinCode,
    createdAt,
    updatedAt,
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
          final Object v => List<EventType>.unmodifiable(
            _readList(v, 'TayfaCreateRequest.interests').map(
              (Object? e0) => EventType.fromWire(
                _readString(e0, 'TayfaCreateRequest.interests'),
              ),
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

  /// Kısıtlar: maxItems: 7; uniqueItems: true.
  final List<EventType>? interests;

  /// Kısıtlar: varsayılan (sunucu): `approval`.
  final JoinPolicy? joinPolicy;

  /// İstemcinin her açma denemesi için bir kez ürettiği, tekrar gönderimde aynen kullandığı UUID.
  final String clientRequestId;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    if (description case final value?) 'description': value,
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0.wire],
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

/// Her modülün açık olup olmadığı.
final class TayfaModules {
  const TayfaModules({this.announcements, this.events, this.qa, this.polls});

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
  );

  final bool? announcements;

  final bool? events;

  final bool? qa;

  final bool? polls;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (announcements case final value?) 'announcements': value,
    if (events case final value?) 'events': value,
    if (qa case final value?) 'qa': value,
    if (polls case final value?) 'polls': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaModules &&
          announcements == other.announcements &&
          events == other.events &&
          qa == other.qa &&
          polls == other.polls;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[announcements, events, qa, polls]);
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
    this.name,
    this.description,
    this.interests,
    this.joinPolicy,
    this.membersCanCreateEvents,
  });

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaUpdateRequest.fromJson(Map<String, Object?> json) =>
      TayfaUpdateRequest(
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
          final Object v => List<EventType>.unmodifiable(
            _readList(v, 'TayfaUpdateRequest.interests').map(
              (Object? e0) => EventType.fromWire(
                _readString(e0, 'TayfaUpdateRequest.interests'),
              ),
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
      );

  /// Kısıtlar: minLength: 3; maxLength: 50.
  final String? name;

  /// Kısıtlar: maxLength: 500.
  final String? description;

  /// Kısıtlar: maxItems: 7; uniqueItems: true.
  final List<EventType>? interests;

  final JoinPolicy? joinPolicy;

  /// `true`: her etkin üye etkinlik açabilir. `false`: yalnızca moderatör ve yönetici.
  final bool? membersCanCreateEvents;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    if (name case final value?) 'name': value,
    if (description case final value?) 'description': value,
    if (interests case final value?)
      'interests': <Object?>[for (final e0 in value) e0.wire],
    if (joinPolicy case final value?) 'join_policy': value.wire,
    if (membersCanCreateEvents case final value?)
      'members_can_create_events': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaUpdateRequest &&
          name == other.name &&
          description == other.description &&
          _deepEquals(interests, other.interests) &&
          joinPolicy == other.joinPolicy &&
          membersCanCreateEvents == other.membersCanCreateEvents;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    name,
    description,
    _deepHash(interests),
    joinPolicy,
    membersCanCreateEvents,
  ]);
}

final class TayfaView {
  const TayfaView({required this.tayfa, required this.callerRole});

  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.
  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]
  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).
  factory TayfaView.fromJson(Map<String, Object?> json) => TayfaView(
    tayfa: Tayfa.fromJson(_readObject(json['tayfa'], 'TayfaView.tayfa')),
    callerRole: Role.fromWire(
      _readString(json['caller_role'], 'TayfaView.caller_role'),
    ),
  );

  final Tayfa tayfa;

  final Role callerRole;

  /// JSON nesnesine yazar; `null` alanlar yazılmaz.
  Map<String, Object?> toJson() => <String, Object?>{
    'tayfa': tayfa.toJson(),
    'caller_role': callerRole.wire,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TayfaView &&
          tayfa == other.tayfa &&
          callerRole == other.callerRole;

  @override
  int get hashCode => Object.hashAll(<Object?>[tayfa, callerRole]);
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
          activityVisibility == other.activityVisibility;

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
