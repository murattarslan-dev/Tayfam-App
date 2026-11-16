import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';

/// "Arkadaş ekle"nin sonucu: hata ya da arkadaşlığın hemen kurulup
/// kurulmadığı (karşı tarafın isteği bekliyorsa `POST
/// /v1/me/friend-requests` arkadaşlığı hemen kurar; sözleşme).
typedef OneriEklemeSonucu = ({Object? hata, bool arkadas});

/// Arkadaş önerileri (`GET /v1/me/friend-suggestions`; Tayfam-Api
/// ADR-0030 §4; 2026-11-16 tasarım: 25-arkadas-onerisi). Liste sunucuda
/// en çok 10 öneridir; sayfalama yoktur.
///
/// Puan, ortak etkinlik sayısı ve önerinin gerekçesi sözleşmede yoktur;
/// burada da tutulmaz. Liste yalnızca bellektedir (ADR-0006) ve oturum
/// değişince sıfırlanır.
class OnerilerNotifier extends AsyncNotifier<List<FriendSuggestion>> {
  @override
  Future<List<FriendSuggestion>> build() {
    ref.watch(oturumDurumuProvider);
    return ref.watch(arkadasDeposuProvider).oneriler();
  }

  /// "Arkadaş ekle": `POST /v1/me/friend-requests`. Başarıda öneri
  /// listeden düşer (sunucu da düşürür).
  Future<OneriEklemeSonucu> ekle(String kullaniciId) async {
    final sonuc = await oneriyiArkadasEkle(ref, kullaniciId, liste: false);
    if (sonuc.hata == null && ref.mounted) _dusur(kullaniciId);
    return sonuc;
  }

  /// "Kapat": `DELETE /v1/me/friend-suggestions/{user_id}`. Başarıda
  /// `null`; öneri listeden düşer.
  Future<Object?> kapat(String kullaniciId) async {
    final hata = await arkadasOnerisiniKapat(ref, kullaniciId, liste: false);
    if (hata == null && ref.mounted) _dusur(kullaniciId);
    return hata;
  }

  void _dusur(String kullaniciId) {
    final liste = state.value;
    if (liste == null) return;
    state = AsyncData([
      for (final o in liste)
        if (o.userId != kullaniciId) o,
    ]);
  }
}

/// Size yapılan arkadaş önerileri; ekran kapanınca bırakılır.
final arkadasOnerileriProvider =
    AsyncNotifierProvider.autoDispose<OnerilerNotifier, List<FriendSuggestion>>(
      OnerilerNotifier.new,
      name: 'arkadasOnerileriProvider',
      retry: yenidenDenemeYok,
    );

/// Öneriye "Arkadaş ekle" (Arkadaşlar ekranı ve bildirim satırı aynı yolu
/// kullanır). Başarıda arkadaşlık listeleri ve [liste] `true` ise açık
/// öneri listesi güncellenir (listenin kendisi çağırıyorsa `false`; bir
/// sağlayıcı kendini okuyamaz). Hata log'a yazılmaz.
Future<OneriEklemeSonucu> oneriyiArkadasEkle(
  Ref ref,
  String kullaniciId, {
  bool liste = true,
}) async {
  var arkadas = false;
  final hata = await arkadasIslemi(ref, () async {
    final sonuc = await ref
        .read(arkadasDeposuProvider)
        .istekGonder(kullaniciId);
    arkadas = sonuc.state == FriendState.friends;
    if (liste) _onerilerDegisti(ref, kullaniciId);
    arkadaslikDegisti(ref, arkadaslar: arkadas);
  });
  return (hata: hata, arkadas: hata == null && arkadas);
}

/// Öneriyi kapatır ("Kapat"). Başarıda `null`; [liste] için
/// [oneriyiArkadasEkle]'ye bakın.
Future<Object?> arkadasOnerisiniKapat(
  Ref ref,
  String kullaniciId, {
  bool liste = true,
}) => arkadasIslemi(ref, () async {
  await ref.read(arkadasDeposuProvider).oneriyiKapat(kullaniciId);
  if (liste) _onerilerDegisti(ref, kullaniciId);
});

/// Açık öneri listesi varsa kişi listeden düşürülür.
void _onerilerDegisti(Ref ref, String kullaniciId) {
  if (!ref.mounted || !ref.read(arkadasOnerileriProvider.exists)) return;
  ref.read(arkadasOnerileriProvider.notifier)._dusur(kullaniciId);
}
