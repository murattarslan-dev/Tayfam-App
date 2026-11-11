import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';

/// Push mesajının `data`'sını bildirime çevirir (Tayfam-Api ADR-0019 §4:
/// `notification_id`, `type`, `target_type`, `target_id`, varsa
/// `tayfa_id`, `question_id`, `subject_user_id`, `reason`).
///
/// `data` sunucudan gelen girdidir (CLAUDE.md, "Doğrula"): kimlikler UUID
/// biçiminde, `type` ve `target_type` bilinen değerlerden biri olmalıdır.
/// Zorunlu alan eksik ya da biçimsizse, isteğe bağlı bir kimlik verilmiş
/// ama biçimsizse `null` döner. Push'ta içerik yoktur; okundu bilgisi ve
/// zaman listede değil sunucudadır, [Notification.read] `false`,
/// [Notification.createdAt] [simdi]'dir.
Notification? pushBildirimi(PushVerisi veri, {required DateTime simdi}) {
  final id = veri['notification_id'];
  final hedefId = veri['target_id'];
  final turAdi = veri['type'];
  final hedefTuru = veri['target_type'];
  if (id == null || !uuidBicimindeMi(id)) return null;
  if (hedefId == null || !uuidBicimindeMi(hedefId)) return null;
  if (turAdi == null || hedefTuru == null) return null;
  final tur = NotificationType.fromWire(turAdi);
  final hedef = NotificationTargetType.fromWire(hedefTuru);
  if (tur == NotificationType.unknown ||
      hedef == NotificationTargetType.unknown) {
    return null;
  }
  final (tayfaGecerli, tayfaId) = _istegeBagliKimlik(veri['tayfa_id']);
  final (soruGecerli, soruId) = _istegeBagliKimlik(veri['question_id']);
  final (kisiGecerli, kisiId) = _istegeBagliKimlik(veri['subject_user_id']);
  if (!tayfaGecerli || !soruGecerli || !kisiGecerli) return null;
  final neden = veri['reason'];
  return Notification(
    id: id,
    type: tur,
    tayfaId: tayfaId,
    targetType: hedef,
    targetId: hedefId,
    questionId: soruId,
    subjectUserId: kisiId,
    warningReason: neden == null
        ? null
        : NotificationWarningReason.fromWire(neden),
    read: false,
    createdAt: simdi.toUtc(),
  );
}

/// Push'a dokununca açılacak adres: bildirimin hedefi ([bildirimAdresi]);
/// veri doğrulanamazsa ya da hedefin ekranı yoksa Bildirimler sekmesi.
String pushAdresi(Notification? bildirim) {
  if (bildirim == null) return Adresler.bildirimler;
  return bildirimAdresi(bildirim) ?? Adresler.bildirimler;
}

/// Yoksa geçerli ve `null`; varsa yalnızca UUID biçimindeyse geçerli.
(bool, String?) _istegeBagliKimlik(String? deger) {
  if (deger == null) return (true, null);
  return uuidBicimindeMi(deger) ? (true, deger) : (false, null);
}
