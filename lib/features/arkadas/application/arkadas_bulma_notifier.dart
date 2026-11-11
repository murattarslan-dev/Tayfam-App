import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';

/// Referans kodunun sözleşmedeki en büyük uzunluğu.
const int referansKoduEnFazla = 32;

/// Referans koduyla bulunan kişi ve (istek gönderildiyse) arkadaşlık
/// durumu.
@immutable
final class BulunanKisi {
  const BulunanKisi(this.kisi, {this.durum});

  /// Kodun sahibi: yalnızca kimlik, ad, avatar (sözleşme).
  final ReferredUser kisi;

  /// Gönderilen isteğin sonucu; istek gönderilmediyse `null`.
  final FriendState? durum;
}

/// Referans koduyla arkadaş bulma (`POST /v1/referral-lookups`; ADR-0018
/// §7). Durum `null` iken henüz arama yapılmamıştır.
///
/// Kod yalnızca istek gövdesinde gider; durumda tutulmaz, diske ve log'a
/// yazılmaz (kesin kural 3). Saatte 10 arama sınırını sunucu uygular
/// (`rate-limited`).
class ArkadasBulmaNotifier extends AsyncNotifier<BulunanKisi?> {
  @override
  Future<BulunanKisi?> build() async => null;

  /// [kod]'un sahibini arar. Boş ya da çok uzun kod gönderilmez.
  Future<void> ara(String kod) async {
    final temiz = referansKoduTemizle(kod);
    if (temiz == null || state.isLoading) return;
    state = const AsyncLoading();
    try {
      final kisi = await ref.read(arkadasDeposuProvider).kodlaBul(temiz);
      if (ref.mounted) state = AsyncData(BulunanKisi(kisi));
    } on Exception catch (hata, yigin) {
      if (ref.mounted) state = AsyncError(hata, yigin);
    }
  }

  /// Bulunan kişiye arkadaşlık isteği gönderir. Başarıda `null`, aksi
  /// halde hata.
  Future<Object?> istekGonder() async {
    final bulunan = state.value;
    if (bulunan == null) return null;
    return arkadasIslemi(ref, () async {
      final sonuc = await ref
          .read(arkadasDeposuProvider)
          .istekGonder(bulunan.kisi.userId);
      if (!ref.mounted) return;
      state = AsyncData(BulunanKisi(bulunan.kisi, durum: sonuc.state));
      arkadaslikDegisti(ref);
    });
  }
}

/// Arkadaş bulma ekranının durumu.
final arkadasBulmaProvider =
    AsyncNotifierProvider.autoDispose<ArkadasBulmaNotifier, BulunanKisi?>(
      ArkadasBulmaNotifier.new,
      name: 'arkadasBulmaProvider',
      retry: yenidenDenemeYok,
    );

/// Girilen kodun baştaki ve sondaki boşlukları atılmış hali; boşsa ya da
/// sözleşmedeki uzunluğu aşıyorsa `null`. Büyük/küçük harf ve `TYF-` öneki
/// sunucuda yorumlanır (sözleşme); burada değiştirilmez.
String? referansKoduTemizle(String kod) {
  final temiz = kod.trim();
  if (temiz.isEmpty || temiz.length > referansKoduEnFazla) return null;
  return temiz;
}
