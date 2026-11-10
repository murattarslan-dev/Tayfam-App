import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/data/tayfa_deposu.dart';

/// Listedeki etkin üyeliklerin kimlikleri, sunucunun sırasıyla.
List<String> etkinIdleri(List<MyTayfa> liste) => [
  for (final t in liste)
    if (t.status == MyTayfaStatus.active) t.tayfaId,
];

/// Listedeki etkin üyelikler, sunucunun sırasıyla.
List<MyTayfa> etkinTayfalar(List<MyTayfa> liste) => [
  for (final t in liste)
    if (t.status == MyTayfaStatus.active) t,
];

/// Listedeki bekleyen katılım istekleri. Bunlarda yalnızca kimlik ve ad
/// vardır; içerik gösterilmez (ADR-0014 §2).
List<MyTayfa> bekleyenTayfalar(List<MyTayfa> liste) => [
  for (final t in liste)
    if (t.status == MyTayfaStatus.pending) t,
];

/// Kullanıcının etkin üyelikleri ve bekleyen katılım istekleri
/// (`GET /v1/tayfas`, bütün sayfalar; ADR-0014 §1).
///
/// Oturuma bağlıdır: oturum durumu değişince yeniden kurulur, oturum açık
/// değilken boştur (ADR-0001 kural 8). Uygulama boyunca yaşar (`keepAlive`;
/// Riverpod 3'te `autoDispose` olmayan provider kalıcıdır). Liste her
/// gelişinde aktif tayfa uzlaştırılır; liste alınamazsa son tayfa güvenli
/// depodan doğrulanmadan geri yüklenir.
///
/// Yenileme: uygulama ön plana dönünce ve katılım, oluşturma ya da geri
/// çekmeden sonra ([yenile]). Yenileme sürerken eski liste görünür kalır.
class TayfalarimNotifier extends AsyncNotifier<List<MyTayfa>> {
  @override
  Future<List<MyTayfa>> build() async {
    final oturum = ref.watch(oturumDurumuProvider);
    if (oturum != OturumDurumu.acik) return const [];
    final depo = ref.watch(tayfaDeposuProvider);
    final List<MyTayfa> liste;
    try {
      liste = await depo.tayfalarim();
    } on Exception {
      if (ref.mounted) {
        await ref.read(aktifTayfaIdProvider.notifier).kayittanYukle();
      }
      rethrow;
    }
    if (ref.mounted) {
      final aktif = ref.read(aktifTayfaIdProvider.notifier);
      await aktif.uzlastir(etkinIdleri(liste));
    }
    return liste;
  }

  /// Listeyi yeniden okur ve aktif tayfayı uzlaştırır. Okunamazsa eldeki
  /// liste kalır; elde liste yoksa hata gösterilir. Okunduysa `true`.
  Future<bool> yenile() async {
    if (ref.read(oturumDurumuProvider) != OturumDurumu.acik) return false;
    final depo = ref.read(tayfaDeposuProvider);
    try {
      final liste = await depo.tayfalarim();
      if (!ref.mounted) return false;
      state = AsyncData(liste);
      final aktif = ref.read(aktifTayfaIdProvider.notifier);
      await aktif.uzlastir(etkinIdleri(liste));
      return true;
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
      return false;
    }
  }

  /// [tayfa]'yı listenin başına ekler (aynı kimlik varsa yerine koyar).
  /// Sunucunun cevabı (katılım, oluşturma) listeye yenilemeden önce
  /// yansısın diye; ardından [yenile] çağrılır.
  void ekle(MyTayfa tayfa) {
    final eski = state.value ?? const <MyTayfa>[];
    state = AsyncData(
      List.unmodifiable([
        tayfa,
        for (final t in eski)
          if (t.tayfaId != tayfa.tayfaId) t,
      ]),
    );
  }

  /// Bekleyen katılım isteğini geri çeker
  /// (`DELETE /v1/tayfas/{tayfa_id}/membership`). Başarıda `null`, aksi
  /// halde gösterilecek hata (metni ortak eşlemeden, ADR-0005 §4).
  Future<Object?> geriCek(String tayfaId) async {
    try {
      await ref.read(tayfaDeposuProvider).istegiGeriCek(tayfaId);
    } on Exception catch (hata) {
      return hata;
    }
    if (!ref.mounted) return null;
    final eski = state.value ?? const <MyTayfa>[];
    state = AsyncData(
      List.unmodifiable([
        for (final t in eski)
          if (t.tayfaId != tayfaId) t,
      ]),
    );
    unawaited(yenile());
    return null;
  }
}

/// Kullanıcının tayfaları (etkin ve bekleyen). Hata otomatik yeniden
/// denenmez; ekranlar "Tekrar dene" sunar, uygulama ön plana dönünce
/// yenilenir.
final tayfalarimProvider =
    AsyncNotifierProvider<TayfalarimNotifier, List<MyTayfa>>(
      TayfalarimNotifier.new,
      name: 'tayfalarimProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Etkin üyeliklerin kimlikleri; liste henüz bilinmiyorsa (yükleniyor ya
/// da alınamadı) `null`. Yönlendirici adresteki kimliği bununla denetler
/// (ADR-0014 §1); erişim kararı yine sunucudadır.
final etkinTayfaIdleriProvider = Provider<Set<String>?>((ref) {
  final durum = ref.watch(tayfalarimProvider);
  if (durum.isLoading || durum.hasError || !durum.hasValue) return null;
  return etkinIdleri(durum.requireValue).toSet();
}, name: 'etkinTayfaIdleriProvider');

/// Tayfa listesi ilk kez okunuyor (henüz liste yok). Yönlendirici bu
/// sırada karşılama yerine açılış ekranını gösterir.
final tayfalarYukleniyorProvider = Provider<bool>((ref) {
  final durum = ref.watch(tayfalarimProvider);
  return durum.isLoading;
}, name: 'tayfalarYukleniyorProvider');

/// Bir tayfanın gösterilecek adı ([tayfalarimProvider]'dan); bilinmiyorsa
/// `null`. Tayfaya bağlı olduğu için `family(tayfaId)` + `autoDispose`
/// (ADR-0001, kural 3).
final tayfaAdiProvider = Provider.autoDispose.family<String?, String>((
  ref,
  tayfaId,
) {
  final liste = ref.watch(tayfalarimProvider).value;
  if (liste == null) return null;
  for (final t in liste) {
    if (t.tayfaId == tayfaId) return t.name.isEmpty ? null : t.name;
  }
  return null;
}, name: 'tayfaAdiProvider');

/// Yeni oluşturulan tayfanın ana sayfasında gösterilen davet kısayolu
/// (ADR-0014 §4): değer, kısayolun gösterileceği tayfanın kimliğidir.
/// Oturum değişince sıfırlanır.
class DavetKisayoluNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(oturumDurumuProvider);
    return null;
  }

  /// [tayfaId]'nin ana sayfasında kısayolu gösterir.
  void goster(String tayfaId) => state = tayfaId;

  /// Kısayolu kapatır.
  void kapat() => state = null;
}

/// Davet kısayolunun gösterileceği tayfa; yoksa `null`.
final davetKisayoluProvider = NotifierProvider<DavetKisayoluNotifier, String?>(
  DavetKisayoluNotifier.new,
  name: 'davetKisayoluProvider',
);
