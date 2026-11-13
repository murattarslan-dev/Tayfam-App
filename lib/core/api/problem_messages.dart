/// Hata türünden kullanıcıya gösterilecek metne tek eşleme (ADR-0005 §4,
/// ADR-0008).
///
/// Sunucunun `title` ve `detail` alanları hiçbir yerde gösterilmez; metin
/// yalnızca `type` kodundan gelir. Her kodun anahtarı `hata_<kod>`'dur
/// (tireler alt çizgi olur).
library;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [hata] için kullanıcıya gösterilecek metin.
///
/// [ApiProblem] koduna göre, [ApiOffline] ve [ApiTimeout] kendi metinleriyle
/// gösterilir; başka her hata (beklenmeyen istisnalar dahil) genel hata
/// metnine düşer.
String hataMetni(AppLocalizations m, Object hata) => switch (hata) {
  ApiProblem(type: ProblemType.unknown, :final status)
      when sunucuUlasilamiyorMu(status) =>
    m.hata_sunucu_ulasilamiyor,
  ApiProblem(:final type) => problemMetni(m, type),
  ApiOffline() => m.hata_baglanti_yok,
  ApiTimeout() => m.hata_zaman_asimi,
  _ => m.hata_genel,
};

/// [type] kodunun metni. `default` dalı yoktur: sözleşmeye yeni bir kod
/// eklenip üretici çalışınca derleyici eksik dalı gösterir. Bilinmeyen kod
/// ([ProblemType.unknown]) genel hata metnine düşer.
String problemMetni(AppLocalizations m, ProblemType type) => switch (type) {
  ProblemType.invalidRequest => m.hata_invalid_request,
  ProblemType.missingClientHeader => m.hata_missing_client_header,
  ProblemType.clientOutdated => m.hata_client_outdated,
  ProblemType.invalidClientVersion => m.hata_invalid_client_version,
  ProblemType.integrityRequired => m.hata_integrity_required,
  ProblemType.unauthenticated => m.hata_unauthenticated,
  ProblemType.notFound => m.hata_not_found,
  ProblemType.rateLimited => m.hata_rate_limited,
  ProblemType.unavailable => m.hata_unavailable,
  ProblemType.internal => m.hata_internal,
  ProblemType.invalidCredentials => m.hata_invalid_credentials,
  ProblemType.unsupportedProvider => m.hata_unsupported_provider,
  ProblemType.ageBlocked => m.hata_age_blocked,
  ProblemType.accountSanctioned => m.hata_account_sanctioned,
  ProblemType.reasonRequired => m.hata_reason_required,
  ProblemType.sanctionConflict => m.hata_sanction_conflict,
  ProblemType.decisionNotApplicable => m.hata_decision_not_applicable,
  ProblemType.tayfaStateConflict => m.hata_tayfa_state_conflict,
  ProblemType.invalidRefresh => m.hata_invalid_refresh,
  ProblemType.refreshConflict => m.hata_refresh_conflict,
  ProblemType.invalidBirthDate => m.hata_invalid_birth_date,
  ProblemType.consentOutdated => m.hata_consent_outdated,
  ProblemType.alreadyRegistered => m.hata_already_registered,
  ProblemType.invalidDisplayName => m.hata_invalid_display_name,
  ProblemType.tayfaNotFound => m.hata_tayfa_not_found,
  ProblemType.permissionDenied => m.hata_permission_denied,
  ProblemType.muted => m.hata_muted,
  ProblemType.tayfaReadOnly => m.hata_tayfa_read_only,
  ProblemType.tayfaCreateLimit => m.hata_tayfa_create_limit,
  ProblemType.deletionAlreadyRequested => m.hata_deletion_already_requested,
  ProblemType.deletionNotRequested => m.hata_deletion_not_requested,
  ProblemType.invalidJoinCode => m.hata_invalid_join_code,
  ProblemType.inviteInvalid => m.hata_invite_invalid,
  ProblemType.inviteExpired => m.hata_invite_expired,
  ProblemType.inviteRevoked => m.hata_invite_revoked,
  ProblemType.inviteExhausted => m.hata_invite_exhausted,
  ProblemType.inviteNotFound => m.hata_invite_not_found,
  ProblemType.alreadyMember => m.hata_already_member,
  ProblemType.alreadyPending => m.hata_already_pending,
  ProblemType.banned => m.hata_banned,
  ProblemType.memberNotFound => m.hata_member_not_found,
  ProblemType.roleHierarchy => m.hata_role_hierarchy,
  ProblemType.lastAdmin => m.hata_last_admin,
  ProblemType.moduleDisabled => m.hata_module_disabled,
  ProblemType.announcementNotFound => m.hata_announcement_not_found,
  ProblemType.eventNotFound => m.hata_event_not_found,
  ProblemType.eventCancelled => m.hata_event_cancelled,
  ProblemType.eventEnded => m.hata_event_ended,
  ProblemType.eventNotGoing => m.hata_event_not_going,
  ProblemType.eventItemNotFound => m.hata_event_item_not_found,
  ProblemType.eventLimit => m.hata_event_limit,
  ProblemType.eventTypeMismatch => m.hata_event_type_mismatch,
  ProblemType.checkInClosed => m.hata_check_in_closed,
  ProblemType.checkInTooFar => m.hata_check_in_too_far,
  ProblemType.checkInAttemptsExhausted => m.hata_check_in_attempts_exhausted,
  ProblemType.correctionClosed => m.hata_correction_closed,
  ProblemType.hikeNotStarted => m.hata_hike_not_started,
  ProblemType.notAttended => m.hata_not_attended,
  ProblemType.eventSeriesNotFound => m.hata_event_series_not_found,
  ProblemType.eventSeriesEnded => m.hata_event_series_ended,
  ProblemType.questionNotFound => m.hata_question_not_found,
  ProblemType.answerNotFound => m.hata_answer_not_found,
  ProblemType.tagNotFound => m.hata_tag_not_found,
  ProblemType.ownAnswerVote => m.hata_own_answer_vote,
  ProblemType.tagLimit => m.hata_tag_limit,
  ProblemType.pollNotFound => m.hata_poll_not_found,
  ProblemType.pollClosed => m.hata_poll_closed,
  ProblemType.pollAnonymous => m.hata_poll_anonymous,
  ProblemType.userNotFound => m.hata_user_not_found,
  ProblemType.friendRequestLimit => m.hata_friend_request_limit,
  ProblemType.friendRequestNotFound => m.hata_friend_request_not_found,
  ProblemType.alreadyFriends => m.hata_already_friends,
  ProblemType.friendRequestPending => m.hata_friend_request_pending,
  ProblemType.notFriends => m.hata_not_friends,
  ProblemType.directInviteLimit => m.hata_direct_invite_limit,
  ProblemType.invitationNotFound => m.hata_invitation_not_found,
  ProblemType.alreadyInvited => m.hata_already_invited,
  ProblemType.inviteNotAllowed => m.hata_invite_not_allowed,
  ProblemType.reportNotFound => m.hata_report_not_found,
  ProblemType.reportTargetNotFound => m.hata_report_target_not_found,
  ProblemType.reportLimit => m.hata_report_limit,
  ProblemType.reportAlreadyResolved => m.hata_report_already_resolved,
  ProblemType.reportActionMissing => m.hata_report_action_missing,
  ProblemType.referralCodeNotFound => m.hata_referral_code_not_found,
  ProblemType.reauthenticationRequired => m.hata_reauthentication_required,
  ProblemType.sessionNotFound => m.hata_session_not_found,
  ProblemType.notificationNotFound => m.hata_notification_not_found,
  ProblemType.channelNotFound => m.hata_channel_not_found,
  ProblemType.messageNotFound => m.hata_message_not_found,
  ProblemType.channelArchived => m.hata_channel_archived,
  ProblemType.channelNameTaken => m.hata_channel_name_taken,
  ProblemType.eventChannelExists => m.hata_event_channel_exists,
  ProblemType.notTayfaMember => m.hata_not_tayfa_member,
  ProblemType.slowMode => m.hata_slow_mode,
  ProblemType.forbiddenOrigin => m.hata_forbidden_origin,
  ProblemType.conversationNotFound => m.hata_conversation_not_found,
  ProblemType.directMessageNotAllowed => m.hata_direct_message_not_allowed,
  ProblemType.messageRequestPending => m.hata_message_request_pending,
  ProblemType.messageRequestLimit => m.hata_message_request_limit,
  ProblemType.messageRequestNotFound => m.hata_message_request_not_found,
  ProblemType.uploadNotFound => m.hata_upload_not_found,
  ProblemType.uploadNotReady => m.hata_upload_not_ready,
  ProblemType.uploadInUse => m.hata_upload_in_use,
  ProblemType.uploadNotReceived => m.hata_upload_not_received,
  ProblemType.uploadRateLimited => m.hata_upload_rate_limited,
  ProblemType.uploadQuotaExceeded => m.hata_upload_quota_exceeded,
  ProblemType.dataExportNotFound => m.hata_data_export_not_found,
  ProblemType.dataExportInProgress => m.hata_data_export_in_progress,
  ProblemType.dataExportLimit => m.hata_data_export_limit,
  ProblemType.dataExportNotReady => m.hata_data_export_not_ready,
  ProblemType.dataExportExpired => m.hata_data_export_expired,
  ProblemType.e2eDeviceNotRegistered => m.hata_e2e_device_not_registered,
  ProblemType.e2eDeviceAlreadyRegistered =>
    m.hata_e2e_device_already_registered,
  ProblemType.e2eDeviceLimit => m.hata_e2e_device_limit,
  ProblemType.e2eDevicesChanged => m.hata_e2e_devices_changed,
  ProblemType.e2eRecipientUnavailable => m.hata_e2e_recipient_unavailable,
  ProblemType.e2eRequired => m.hata_e2e_required,
  ProblemType.e2eNotPaired => m.hata_e2e_not_paired,
  ProblemType.e2eAlreadyPaired => m.hata_e2e_already_paired,
  ProblemType.e2ePairedDeviceExists => m.hata_e2e_paired_device_exists,
  ProblemType.e2eHistoryKeyStale => m.hata_e2e_history_key_stale,
  ProblemType.e2eLinkRequestNotFound => m.hata_e2e_link_request_not_found,
  ProblemType.unknown => m.hata_genel,
};

/// Problem gövdesi olmadan gelen ağ geçidi hataları: API'nin önündeki
/// katman (Cloudflare tüneli) sunucuya ulaşamadığında 502/503/504 ya da
/// Cloudflare'in 520–530 kodlarını kendi sayfasıyla döndürür. Sunucunun
/// kendi `problem+json` cevabı (ör. `unavailable`) kendi metnini alır.
bool sunucuUlasilamiyorMu(int status) =>
    const {502, 503, 504}.contains(status) || (status >= 520 && status <= 530);
