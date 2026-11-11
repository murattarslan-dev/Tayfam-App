import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/birebir/application/birebir_islemi.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';

/// Reddedilen mesaj istekleri (`GET
/// /v1/direct-messages/declined-requests`; ADR-0018 §9). Listeyi yalnızca
/// kullanıcı görür; gönderen ne reddi ne bu listeyi öğrenir. Ekran
/// kapanınca bırakılır.
class ReddedilenlerNotifier extends SayfaliListeNotifier<DeclinedRequest> {
  @override
  Future<SayfaliListe<DeclinedRequest>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(birebirDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<DeclinedRequest>> sayfaGetir(String? sayfaToken) =>
      ref.read(birebirDeposuProvider).reddedilenler(sayfaToken: sayfaToken);

  @override
  String kimlik(DeclinedRequest oge) => oge.conversationId;

  /// İsteği reddedilenler listesinden çıkarır; konuşma yeniden gelen
  /// bekleyen istek olur, bu yüzden konuşma listesi yenilenir. Gönderene
  /// bildirim gitmez. Başarıda `null`, aksi halde hata.
  Future<Object?> listedenCikar(String konusmaId) async {
    final hata = await birebirIslemi(
      ref,
      () => ref.read(birebirDeposuProvider).reddedilenlerdenCikar(konusmaId),
    );
    if (hata != null || !ref.mounted) return hata;
    ogeleriDegistir(
      (ogeler) => [
        for (final r in ogeler)
          if (r.conversationId != konusmaId) r,
      ],
    );
    await ref.read(konusmaListesiProvider.notifier).yenile();
    return null;
  }
}

/// Reddedilen mesaj istekleri.
final reddedilenlerProvider =
    AsyncNotifierProvider.autoDispose<
      ReddedilenlerNotifier,
      SayfaliListe<DeclinedRequest>
    >(
      ReddedilenlerNotifier.new,
      name: 'reddedilenlerProvider',
      retry: yenidenDenemeYok,
    );
