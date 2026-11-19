import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/vocabulary_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/bilesenler/sozluk_girisi.dart';

/// Tayfa sözlüğü uçları (Tayfam-Api #244, ADR-0037 §4; tek `ApiClient`
/// üzerinden, ADR-0005). Sözlük içeriği yalnızca bellektedir (ADR-0006).
final class SozlukDeposu {
  SozlukDeposu(ApiTransport istemci) : _api = VocabularyApi(istemci);

  final VocabularyApi _api;

  /// `GET …/vocabulary/{namespace}?q=`: metni ya da ona birleştirilmiş bir
  /// değerin metni [arama]'yı içeren en fazla 20 değer (birleştirilmiş
  /// değerler hedeflerine çözülür). [birlesmis] ise yalnızca
  /// birleştirilmiş değerler, hedefleriyle.
  Future<TayfaVocabularyList> ara(
    String tayfaId,
    String adAlani, {
    String? arama,
    bool birlesmis = false,
  }) => _api.listTayfaVocabulary(
    tayfaId: tayfaId,
    namespace: adAlani,
    q: arama == null || arama.trim().isEmpty ? null : arama.trim(),
    merged: birlesmis ? true : null,
  );

  /// Otomatik tamamlama önerileri ([ara]'nın değerleri).
  Future<List<SozlukOnerisi>> oneriler(
    String tayfaId,
    String adAlani,
    String arama,
  ) async {
    final liste = await ara(tayfaId, adAlani, arama: arama);
    return [for (final d in liste.values) (kimlik: d.id, metin: d.value)];
  }

  /// `POST …/{vocabulary_id}/merge`: [kaynakId]'yi [hedefId]'ye
  /// birleştirir (moderatör, yönetici; yetkiyi sunucu verir).
  Future<TayfaVocabularyValue> birlestir(
    String tayfaId,
    String adAlani,
    String kaynakId,
    String hedefId,
  ) => _api.mergeTayfaVocabulary(
    tayfaId: tayfaId,
    namespace: adAlani,
    vocabularyId: kaynakId,
    body: TayfaVocabularyMergeRequest(targetId: hedefId),
  );

  /// `DELETE …/{vocabulary_id}/merge`: birleştirmeyi geri alır.
  Future<void> geriAl(String tayfaId, String adAlani, String kaynakId) =>
      _api.unmergeTayfaVocabulary(
        tayfaId: tayfaId,
        namespace: adAlani,
        vocabularyId: kaynakId,
      );
}

/// Sözlük uçları.
final sozlukDeposuProvider = Provider<SozlukDeposu>(
  (ref) => SozlukDeposu(ref.watch(apiClientProvider)),
  name: 'sozlukDeposuProvider',
);
