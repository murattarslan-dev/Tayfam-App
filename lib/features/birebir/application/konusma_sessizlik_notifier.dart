import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/birebir/application/birebir_islemi.dart';
import 'package:tayfam/features/birebir/data/sessiz_deposu.dart';

/// Sessize almanın süre seçenekleri (konuşma menüsü).
enum SessizSure {
  /// 8 saat.
  sekizSaat(Duration(hours: 8)),

  /// 1 hafta.
  birHafta(Duration(days: 7)),

  /// Süresiz: "Sesi aç" seçilene kadar.
  suresiz(null);

  const SessizSure(this.uzunluk);

  /// Süre; süresizde `null`. Sözleşmenin üst sınırı (bir yıl) aşılmaz.
  final Duration? uzunluk;
}

/// Bir konuşmanın sessizliği: [bitis] yoksa süresiz.
final class Sessizlik {
  const Sessizlik([this.bitis]);

  /// Sessizliğin bittiği an; süresizde `null`.
  final DateTime? bitis;

  /// [simdi] itibarıyla sürüyor mu.
  bool etkin(DateTime simdi) {
    final b = bitis;
    return b == null || b.isAfter(simdi);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Sessizlik && bitis == other.bitis;

  @override
  int get hashCode => bitis.hashCode;
}

/// Tercihlerden [simdi] itibarıyla sessizdeki birebir konuşmalar:
/// kapsamı `dm_conversation`, seviyesi `none` ve (varsa) süresi
/// dolmamış olanlar. Tercihi olmayan ya da süresi dolan konuşma `all`'dur
/// (sözleşme); tayfa tercihleri burada yoktur.
Map<String, Sessizlik> konusmaSessizlikleri(
  List<NotificationPreference> tercihler,
  DateTime simdi,
) => {
  for (final t in tercihler)
    if (t.scopeType == NotificationPreferenceScopeType.dmConversation &&
        t.level == NotificationPreferenceLevel.none &&
        Sessizlik(t.muteUntil).etkin(simdi))
      t.scopeId: Sessizlik(t.muteUntil),
};

/// [sessizlikler]'e göre [konusmaId] [simdi] itibarıyla sessizde mi.
bool konusmaSessizde(
  Map<String, Sessizlik>? sessizlikler,
  String konusmaId,
  DateTime simdi,
) => sessizlikler?[konusmaId]?.etkin(simdi) ?? false;

/// Sessizlik hesaplarında kullanılan saat (testlerde sabitlenir).
final birebirSaatiProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
  name: 'birebirSaatiProvider',
);

/// Kullanıcının sessize aldığı birebir konuşmalar (`GET
/// /v1/notification-preferences`; Tayfam-Api ADR-0019 §3).
///
/// Oturum boyunca yaşar ve oturum değişince yeniden kurulur (ADR-0001);
/// oturum açık değilse istek atmadan boş döner. Yalnızca bellektedir,
/// diske yazılmaz (ADR-0006). Konuşma listesi yenilenince yeniden okunur.
class KonusmaSessizlikNotifier extends AsyncNotifier<Map<String, Sessizlik>> {
  @override
  Future<Map<String, Sessizlik>> build() async {
    final oturum = ref.watch(oturumDurumuProvider);
    final depo = ref.watch(sessizDeposuProvider);
    if (oturum != OturumDurumu.acik) return const {};
    final tercihler = await depo.tercihler();
    return konusmaSessizlikleri(tercihler, ref.read(birebirSaatiProvider)());
  }

  /// [konusmaId]'yi [sure] boyunca sessize alır. Başarıda `null`, aksi
  /// halde gösterilecek hata (ör. `conversation-not-found`).
  Future<Object?> sessizeAl(String konusmaId, SessizSure sure) {
    final uzunluk = sure.uzunluk;
    final bitis = uzunluk == null
        ? null
        : ref.read(birebirSaatiProvider)().add(uzunluk);
    return birebirIslemi(ref, () async {
      final tercih = await ref
          .read(sessizDeposuProvider)
          .sessizeAl(konusmaId, bitis: bitis);
      if (!ref.mounted) return;
      _yaz(
        konusmaId,
        tercih.level == NotificationPreferenceLevel.none
            ? Sessizlik(tercih.muteUntil)
            : null,
      );
    });
  }

  /// [konusmaId]'nin sesini açar (varsayılan `all`). Başarıda `null`,
  /// aksi halde gösterilecek hata.
  Future<Object?> sesiAc(String konusmaId) => birebirIslemi(ref, () async {
    await ref.read(sessizDeposuProvider).sesiAc(konusmaId);
    if (ref.mounted) _yaz(konusmaId, null);
  });

  void _yaz(String konusmaId, Sessizlik? sessizlik) {
    final eski = state.value ?? const <String, Sessizlik>{};
    state = AsyncData({
      for (final e in eski.entries)
        if (e.key != konusmaId) e.key: e.value,
      if (sessizlik != null) konusmaId: sessizlik,
    });
  }
}

/// Sessize alınan birebir konuşmalar (konuşma kimliği → sessizlik).
final konusmaSessizlikProvider =
    AsyncNotifierProvider<KonusmaSessizlikNotifier, Map<String, Sessizlik>>(
      KonusmaSessizlikNotifier.new,
      name: 'konusmaSessizlikProvider',
      retry: yenidenDenemeYok,
    );
