import 'package:tayfam/core/api/gen/models.dart';

/// "En faydalı" etiketi için ilk cevabın en az alması gereken faydalı oyu.
const int enFaydaliEnAzOy = 1;

/// "En faydalı" etiketini alan cevabın kimliği (platform sahibi kararı,
/// 2026-11-13; ADR-0018 Notlar): cevaplar sunucunun sırasıyla (faydalı oyu
/// çoktan aza) gelir; listedeki ilk cevap en az [enFaydaliEnAzOy] oy
/// almışsa odur. Yeni bir alan gerekmez, sıralama istemcide yeniden
/// yapılmaz. Liste boşsa ya da ilk cevabın oyu yoksa `null`.
String? enFaydaliCevapKimligi(List<Answer> cevaplar) {
  final ilk = cevaplar.firstOrNull;
  if (ilk == null || ilk.voteCount < enFaydaliEnAzOy) return null;
  return ilk.id;
}
