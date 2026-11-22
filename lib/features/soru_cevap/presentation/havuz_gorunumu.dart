import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Soru havuzu sorusunun (`pool: question_pool`; App ADR-0033 §2,
/// Tayfam-Api ADR-0040 §2) soru-cevap ekranlarındaki görünümü.
///
/// Soru havuzu Soru-Cevap'ın uçlarını ve ekranlarını kullanır: soru
/// detayı, cevap listesi, faydalı oyu, silme ve şikâyet aynıdır. Havuz
/// sorusunda başlık ve etiket yoktur; ders/konu ve fotoğraflar vardır.
/// Bu farkları soru havuzu özelliği bu arayüzle verir ve kayıtta
/// ([soruHavuzuGorunumuProvider]) bağlanır; soru-cevap özelliği soru
/// havuzunu import etmez (ADR-0002).
abstract interface class SoruHavuzuGorunumu {
  /// Detay ekranında sorunun kendisi (ders/konu, yazar, metin,
  /// fotoğraflar).
  Widget soruIcerigi(BuildContext context, Question soru);

  /// Cevap kartında metnin altındaki ek (fotoğraflar); yoksa `null`.
  Widget? cevapEki(BuildContext context, Answer cevap);

  /// Sorunun düzenleme formunu açar.
  Future<void> soruyuDuzenle(BuildContext context, Question soru);

  /// Cevap formunu açar; [duzenlenen] verilirse o cevabı düzenler.
  Future<void> cevapFormunuAc(
    BuildContext context,
    Question soru, {
    Answer? duzenlenen,
  });

  /// Detaydaki soru değişti (düzenleme, yenileme, cevap sayısı): havuzun
  /// açık listelerine yansıtılır.
  void soruDegisti(WidgetRef ref, Question soru);

  /// Soru silindi: havuzun açık listelerinden çıkarılır.
  void soruSilindi(WidgetRef ref, Question soru);
}

/// Kayıtlı soru havuzu görünümü; kayıtta (`shell/kayitlar.dart`) soru
/// havuzu özelliğinin uygulamasıyla değiştirilir. `null` iken havuz
/// sorusu da Soru-Cevap görünümüyle çizilir.
final soruHavuzuGorunumuProvider = Provider<SoruHavuzuGorunumu?>(
  (ref) => null,
  name: 'soruHavuzuGorunumuProvider',
);

/// [soru] soru havuzunun mu.
bool havuzSorusuMu(Question soru) => soru.pool == QuestionPool.questionPool;
