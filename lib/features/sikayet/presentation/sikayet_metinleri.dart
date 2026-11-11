import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Gerekçenin metni (Topluluk Kuralları kategorileri). Bilinmeyen değer
/// "Diğer"e düşer.
String gerekceMetni(AppLocalizations m, ReportReason gerekce) =>
    switch (gerekce) {
      ReportReason.harassment => m.sikayet_gerekce_taciz,
      ReportReason.hateSpeech => m.sikayet_gerekce_nefret,
      ReportReason.violence => m.sikayet_gerekce_siddet,
      ReportReason.privacy => m.sikayet_gerekce_mahremiyet,
      ReportReason.impersonation => m.sikayet_gerekce_taklit,
      ReportReason.illegalTrade => m.sikayet_gerekce_yasadisi_ticaret,
      ReportReason.drugs => m.sikayet_gerekce_uyusturucu,
      ReportReason.gambling => m.sikayet_gerekce_kumar,
      ReportReason.dangerousActivity => m.sikayet_gerekce_tehlikeli,
      ReportReason.fakeEvent => m.sikayet_gerekce_sahte_etkinlik,
      ReportReason.sexualContent => m.sikayet_gerekce_cinsel,
      ReportReason.childSafety => m.sikayet_gerekce_cocuk_guvenligi,
      ReportReason.spam => m.sikayet_gerekce_spam,
      ReportReason.copyright => m.sikayet_gerekce_telif,
      ReportReason.staffConduct => m.sikayet_gerekce_yonetim,
      ReportReason.other || ReportReason.unknown => m.sikayet_gerekce_diger,
    };

/// Gerekçenin altındaki kısa açıklama; yalnızca yönlendirme gerektiren
/// gerekçelerde.
String? gerekceAciklamasi(AppLocalizations m, ReportReason gerekce) =>
    switch (gerekce) {
      ReportReason.childSafety => m.sikayet_gerekce_cocuk_guvenligi_aciklama,
      ReportReason.staffConduct => m.sikayet_gerekce_yonetim_aciklama,
      _ => null,
    };

/// Şikâyet edilen şeyin türü (kuyruktaki etiket).
String hedefTuruMetni(AppLocalizations m, ReportTargetType tur) =>
    switch (tur) {
      ReportTargetType.user => m.sikayet_tur_uye,
      ReportTargetType.tayfa => m.sikayet_tur_tayfa,
      ReportTargetType.announcement => m.sikayet_tur_duyuru,
      ReportTargetType.event => m.sikayet_tur_etkinlik,
      ReportTargetType.question => m.sikayet_tur_soru,
      ReportTargetType.answer => m.sikayet_tur_cevap,
      ReportTargetType.poll => m.sikayet_tur_anket,
      ReportTargetType.fishingCatch => m.sikayet_tur_av_kaydi,
      ReportTargetType.dmMessage => m.sikayet_tur_mesaj,
      ReportTargetType.unknown => m.sikayet_tur_bilinmiyor,
    };

/// Şikâyet sayfasının sorusu ("Bu duyuruyu neden şikâyet ediyorsun?").
String sikayetSorusu(AppLocalizations m, ReportTargetType tur) =>
    switch (tur) {
      ReportTargetType.user => m.sikayet_soru_uye,
      ReportTargetType.tayfa => m.sikayet_soru_tayfa,
      ReportTargetType.announcement => m.sikayet_soru_duyuru,
      ReportTargetType.event => m.sikayet_soru_etkinlik,
      ReportTargetType.question => m.sikayet_soru_soru,
      ReportTargetType.answer => m.sikayet_soru_cevap,
      ReportTargetType.poll => m.sikayet_soru_anket,
      ReportTargetType.fishingCatch => m.sikayet_soru_av_kaydi,
      ReportTargetType.dmMessage => m.sikayet_soru_mesaj,
      ReportTargetType.unknown => m.sikayet_soru_genel,
    };

/// Sonuçlanan şikâyetin sonucu.
String sonucMetni(AppLocalizations m, ModerationReportResolution? sonuc) =>
    switch (sonuc) {
      ModerationReportResolution.contentRemoved => m.sikayet_sonuc_kaldirildi,
      ModerationReportResolution.memberSanctioned =>
        m.sikayet_sonuc_yaptirim,
      ModerationReportResolution.dismissed => m.sikayet_sonuc_islem_yok,
      ModerationReportResolution.unknown || null => m.sikayet_sonuc_bilinmiyor,
    };
