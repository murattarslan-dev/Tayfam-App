import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';

/// Arkadaşlar (`GET /v1/me/friends`, sayfalı; ADR-0018 §7). Liste yalnızca
/// kullanıcının kendisine görünür (sözleşme). Yalnızca bellektedir
/// (ADR-0006); oturum değişince sıfırlanır.
class ArkadaslarNotifier extends SayfaliListeNotifier<Friend> {
  @override
  Future<SayfaliListe<Friend>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(arkadasDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Friend>> sayfaGetir(String? sayfaToken) =>
      ref.read(arkadasDeposuProvider).arkadaslar(sayfaToken: sayfaToken);

  @override
  String kimlik(Friend oge) => oge.userId;

  /// Arkadaşlıktan çıkarır; karşı tarafa bildirilmez.
  Future<Object?> cikar(String kullaniciId) => arkadasIslemi(ref, () async {
    await ref.read(arkadasDeposuProvider).arkadasligiKaldir(kullaniciId);
    if (!ref.mounted) return;
    ogeleriDegistir(
      (ogeler) => [
        for (final a in ogeler)
          if (a.userId != kullaniciId) a,
      ],
    );
    arkadaslikDegisti(ref, arkadaslar: false);
  });
}

/// Arkadaş listesi.
final arkadaslarProvider =
    AsyncNotifierProvider.autoDispose<
      ArkadaslarNotifier,
      SayfaliListe<Friend>
    >(
      ArkadaslarNotifier.new,
      name: 'arkadaslarProvider',
      retry: yenidenDenemeYok,
    );

/// Gelen ya da gönderilen arkadaşlık istekleri
/// (`GET /v1/me/friend-requests?direction=…`, sayfalı).
class ArkadasIstekleriNotifier extends SayfaliListeNotifier<Friend> {
  ArkadasIstekleriNotifier(this.yon);

  /// İsteklerin yönü: gelen (`incoming`) ya da gönderilen (`outgoing`).
  final ListFriendRequestsDirection yon;

  @override
  Future<SayfaliListe<Friend>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(arkadasDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Friend>> sayfaGetir(String? sayfaToken) => ref
      .read(arkadasDeposuProvider)
      .istekler(yon, sayfaToken: sayfaToken);

  @override
  String kimlik(Friend oge) => oge.userId;

  /// Gelen isteği kabul eder; kişi arkadaş olur.
  Future<Object?> kabulEt(String kullaniciId) => arkadasIslemi(ref, () async {
    await ref.read(arkadasDeposuProvider).istegiKabulEt(kullaniciId);
    _cikar(kullaniciId);
  });

  /// Gelen isteği reddeder ya da gönderilen isteği geri çeker
  /// (`DELETE /v1/me/friends/{user_id}`); karşı tarafa bildirilmez.
  Future<Object?> kaldir(String kullaniciId) => arkadasIslemi(ref, () async {
    await ref.read(arkadasDeposuProvider).arkadasligiKaldir(kullaniciId);
    _cikar(kullaniciId);
  });

  void _cikar(String kullaniciId) {
    if (!ref.mounted) return;
    ogeleriDegistir(
      (ogeler) => [
        for (final i in ogeler)
          if (i.userId != kullaniciId) i,
      ],
    );
    arkadaslikDegisti(ref, atlanacakYon: yon);
  }
}

/// Bir yöndeki arkadaşlık istekleri.
final arkadasIstekleriProvider = AsyncNotifierProvider.autoDispose
    .family<
      ArkadasIstekleriNotifier,
      SayfaliListe<Friend>,
      ListFriendRequestsDirection
    >(
      ArkadasIstekleriNotifier.new,
      name: 'arkadasIstekleriProvider',
      retry: yenidenDenemeYok,
    );

/// Cevap bekleyen gelen arkadaşlık isteği var mı (Arkadaşlar girişindeki
/// rozet). Yalnızca ilk kaydı ister; okunamazsa rozet gösterilmez.
class GelenIstekVarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(arkadasDeposuProvider);
    final sayfa = await depo.istekler(
      ListFriendRequestsDirection.incoming,
      sayfaBoyutu: 1,
    );
    return sayfa.ogeler.isNotEmpty;
  }
}

/// Gelen arkadaşlık isteği var mı.
final gelenIstekVarProvider =
    AsyncNotifierProvider.autoDispose<GelenIstekVarNotifier, bool>(
      GelenIstekVarNotifier.new,
      name: 'gelenIstekVarProvider',
      retry: yenidenDenemeYok,
    );

/// Engellenen kullanıcılar (`GET /v1/me/blocks`, sayfalı). Sizi
/// engelleyenler hiç listelenmez (sözleşme).
class EngellenenlerNotifier extends SayfaliListeNotifier<BlockedUser> {
  @override
  Future<SayfaliListe<BlockedUser>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(arkadasDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<BlockedUser>> sayfaGetir(String? sayfaToken) =>
      ref.read(arkadasDeposuProvider).engellenenler(sayfaToken: sayfaToken);

  @override
  String kimlik(BlockedUser oge) => oge.userId;

  /// Engeli kaldırır; arkadaşlık geri gelmez (sözleşme).
  Future<Object?> engeliKaldir(String kullaniciId) =>
      arkadasIslemi(ref, () async {
        await ref.read(arkadasDeposuProvider).engeliKaldir(kullaniciId);
        if (!ref.mounted) return;
        ogeleriDegistir(
          (ogeler) => [
            for (final e in ogeler)
              if (e.userId != kullaniciId) e,
          ],
        );
      });
}

/// Engellenen kullanıcılar.
final engellenenlerProvider =
    AsyncNotifierProvider.autoDispose<
      EngellenenlerNotifier,
      SayfaliListe<BlockedUser>
    >(
      EngellenenlerNotifier.new,
      name: 'engellenenlerProvider',
      retry: yenidenDenemeYok,
    );

/// Arkadaşlık durumu değişti: açık listeler ve rozet yeniden okunur.
/// Çağıran liste kendini zaten güncellediği için atlanır ([arkadaslar]
/// `false` ya da [atlanacakYon]). Kişinin profili kendi notifier'ında
/// güncellenir.
void arkadaslikDegisti(
  Ref ref, {
  bool arkadaslar = true,
  ListFriendRequestsDirection? atlanacakYon,
}) {
  if (!ref.mounted) return;
  if (arkadaslar && ref.read(arkadaslarProvider.exists)) {
    ref.invalidate(arkadaslarProvider);
  }
  for (final yon in const [
    ListFriendRequestsDirection.incoming,
    ListFriendRequestsDirection.outgoing,
  ]) {
    if (yon == atlanacakYon) continue;
    final istekler = arkadasIstekleriProvider(yon);
    if (ref.read(istekler.exists)) ref.invalidate(istekler);
  }
  if (ref.read(gelenIstekVarProvider.exists)) {
    ref.invalidate(gelenIstekVarProvider);
  }
}
