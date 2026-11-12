// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

/// Sözleşmedeki hata kodları (ADR-0005).
library;

/// Problem yanıtının `type` alanındaki kod: `https://tayfam.app/problems/<kod>`.
///
/// Kaynak: `components.responses.Problem` → `x-problem-types`.
/// Bilinmeyen kod [unknown] olur ve genel hata metnine düşer.
enum ProblemType {
  invalidRequest('invalid-request'),
  missingClientHeader('missing-client-header'),
  clientOutdated('client-outdated'),
  invalidClientVersion('invalid-client-version'),
  integrityRequired('integrity-required'),
  unauthenticated('unauthenticated'),
  notFound('not-found'),
  rateLimited('rate-limited'),
  unavailable('unavailable'),
  internal('internal'),
  invalidCredentials('invalid-credentials'),
  unsupportedProvider('unsupported-provider'),
  ageBlocked('age-blocked'),
  accountSanctioned('account-sanctioned'),
  reasonRequired('reason-required'),
  sanctionConflict('sanction-conflict'),
  decisionNotApplicable('decision-not-applicable'),
  tayfaStateConflict('tayfa-state-conflict'),
  invalidRefresh('invalid-refresh'),
  refreshConflict('refresh-conflict'),
  invalidBirthDate('invalid-birth-date'),
  consentOutdated('consent-outdated'),
  alreadyRegistered('already-registered'),
  invalidDisplayName('invalid-display-name'),
  tayfaNotFound('tayfa-not-found'),
  permissionDenied('permission-denied'),
  muted('muted'),
  tayfaReadOnly('tayfa-read-only'),
  tayfaCreateLimit('tayfa-create-limit'),
  deletionAlreadyRequested('deletion-already-requested'),
  deletionNotRequested('deletion-not-requested'),
  invalidJoinCode('invalid-join-code'),
  inviteInvalid('invite-invalid'),
  inviteExpired('invite-expired'),
  inviteRevoked('invite-revoked'),
  inviteExhausted('invite-exhausted'),
  inviteNotFound('invite-not-found'),
  alreadyMember('already-member'),
  alreadyPending('already-pending'),
  banned('banned'),
  memberNotFound('member-not-found'),
  roleHierarchy('role-hierarchy'),
  lastAdmin('last-admin'),
  moduleDisabled('module-disabled'),
  announcementNotFound('announcement-not-found'),
  eventNotFound('event-not-found'),
  eventCancelled('event-cancelled'),
  eventEnded('event-ended'),
  eventNotGoing('event-not-going'),
  eventItemNotFound('event-item-not-found'),
  eventLimit('event-limit'),
  eventTypeMismatch('event-type-mismatch'),
  checkInClosed('check-in-closed'),
  checkInTooFar('check-in-too-far'),
  checkInAttemptsExhausted('check-in-attempts-exhausted'),
  correctionClosed('correction-closed'),
  hikeNotStarted('hike-not-started'),
  notAttended('not-attended'),
  eventSeriesNotFound('event-series-not-found'),
  eventSeriesEnded('event-series-ended'),
  questionNotFound('question-not-found'),
  answerNotFound('answer-not-found'),
  tagNotFound('tag-not-found'),
  ownAnswerVote('own-answer-vote'),
  tagLimit('tag-limit'),
  pollNotFound('poll-not-found'),
  pollClosed('poll-closed'),
  pollAnonymous('poll-anonymous'),
  userNotFound('user-not-found'),
  friendRequestLimit('friend-request-limit'),
  friendRequestNotFound('friend-request-not-found'),
  alreadyFriends('already-friends'),
  friendRequestPending('friend-request-pending'),
  notFriends('not-friends'),
  directInviteLimit('direct-invite-limit'),
  invitationNotFound('invitation-not-found'),
  alreadyInvited('already-invited'),
  inviteNotAllowed('invite-not-allowed'),
  reportNotFound('report-not-found'),
  reportTargetNotFound('report-target-not-found'),
  reportLimit('report-limit'),
  reportAlreadyResolved('report-already-resolved'),
  reportActionMissing('report-action-missing'),
  uploadNotFound('upload-not-found'),
  uploadNotReady('upload-not-ready'),
  uploadInUse('upload-in-use'),
  uploadNotReceived('upload-not-received'),
  uploadRateLimited('upload-rate-limited'),
  uploadQuotaExceeded('upload-quota-exceeded'),
  referralCodeNotFound('referral-code-not-found'),
  reauthenticationRequired('reauthentication-required'),
  sessionNotFound('session-not-found'),
  dataExportNotFound('data-export-not-found'),
  dataExportInProgress('data-export-in-progress'),
  dataExportLimit('data-export-limit'),
  dataExportNotReady('data-export-not-ready'),
  dataExportExpired('data-export-expired'),
  notificationNotFound('notification-not-found'),
  channelNotFound('channel-not-found'),
  messageNotFound('message-not-found'),
  channelArchived('channel-archived'),
  channelNameTaken('channel-name-taken'),
  slowMode('slow-mode'),
  forbiddenOrigin('forbidden-origin'),
  conversationNotFound('conversation-not-found'),
  directMessageNotAllowed('direct-message-not-allowed'),
  messageRequestPending('message-request-pending'),
  messageRequestLimit('message-request-limit'),
  messageRequestNotFound('message-request-not-found'),
  e2eDeviceNotRegistered('e2e-device-not-registered'),
  e2eDeviceAlreadyRegistered('e2e-device-already-registered'),
  e2eDeviceLimit('e2e-device-limit'),
  e2eDevicesChanged('e2e-devices-changed'),
  e2eRecipientUnavailable('e2e-recipient-unavailable'),
  e2eRequired('e2e-required'),
  e2eNotPaired('e2e-not-paired'),
  e2eAlreadyPaired('e2e-already-paired'),
  e2ePairedDeviceExists('e2e-paired-device-exists'),
  e2eHistoryKeyStale('e2e-history-key-stale'),
  e2eLinkRequestNotFound('e2e-link-request-not-found'),

  /// Sözleşmede yok: okunurken tanınmayan değer.
  /// Sunucuya hiçbir zaman gönderilmez.
  unknown(null);

  const ProblemType(this._wire);

  final String? _wire;

  /// JSON'daki değer. Sözleşmede olmayan [unknown] gönderilemez;
  /// [StateError] fırlatır.
  String get wire =>
      _wire ?? (throw StateError('ProblemType.unknown gönderilemez'));

  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.
  static ProblemType fromWire(String wire) {
    for (final value in values) {
      if (value._wire == wire) {
        return value;
      }
    }
    return unknown;
  }
}
