import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/data/tayfa_deposu.dart';

/// Tayfa ana sayfası açılınca `GET /v1/tayfas/{tayfa_id}` ile tazelenen
/// tam görünüm (ADR-0014 §1). Tayfaya bağlıdır: `family(tayfaId)` +
/// `autoDispose`; sayfa kapanınca bırakılır.
///
/// `tayfa-not-found` gelirse (çıkarılma, tayfa silinmesi) tayfa listesi
/// yenilenir; aktif tayfa liste üzerinden uzlaşır.
class TayfaGorunumuNotifier extends AsyncNotifier<TayfaView> {
  TayfaGorunumuNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<TayfaView> build() async {
    final depo = ref.watch(tayfaDeposuProvider);
    try {
      return await depo.tayfa(tayfaId);
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.tayfaNotFound && ref.mounted) {
        unawaited(ref.read(tayfalarimProvider.notifier).yenile());
      }
      rethrow;
    }
  }
}

/// Bir tayfanın tam görünümü. Hata otomatik yeniden denenmez.
final tayfaGorunumuProvider = AsyncNotifierProvider.autoDispose
    .family<TayfaGorunumuNotifier, TayfaView, String>(
      TayfaGorunumuNotifier.new,
      name: 'tayfaGorunumuProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Ana sayfanın üst bölümünde gösterilen tayfa bilgisi: ad, üye sayısı,
/// durum ve (yalnızca yöneticiye dönen) katılım kodu.
@immutable
final class TayfaOzeti {
  const TayfaOzeti({this.ad, this.tayfa});

  /// Tayfanın adı; bilinmiyorsa `null`.
  final String? ad;

  /// Tam tayfa bilgisi; henüz bilinmiyorsa `null`.
  final Tayfa? tayfa;

  /// Paylaşılacak katılım kodu; yalnızca yöneticiye döner (sözleşme). Kod
  /// yoksa paylaşım düğmesi görünmez; bu bir kolaylıktır, yetki kararı
  /// değildir (kesin kural 5).
  String? get katilimKodu {
    final kod = tayfa?.joinCode;
    return kod == null || kod.isEmpty ? null : kod;
  }
}

/// [tayfaId]'nin özeti: önce tazelenen görünümden, yoksa tayfa listesinden.
final tayfaOzetiProvider = Provider.autoDispose.family<TayfaOzeti, String>((
  ref,
  tayfaId,
) {
  final gorunum = ref.watch(tayfaGorunumuProvider(tayfaId)).value;
  final listedeki = _listedeBul(ref.watch(tayfalarimProvider).value, tayfaId);
  final tayfa = gorunum?.tayfa ?? listedeki?.tayfa;
  final ad = tayfa?.name ?? listedeki?.name;
  return TayfaOzeti(ad: ad == null || ad.isEmpty ? null : ad, tayfa: tayfa);
}, name: 'tayfaOzetiProvider');

MyTayfa? _listedeBul(List<MyTayfa>? liste, String tayfaId) {
  if (liste == null) return null;
  for (final t in liste) {
    if (t.tayfaId == tayfaId) return t;
  }
  return null;
}

/// Ana sayfanın mor üst bölümündeki bilgi şeridi (ADR-0014 §6).
enum TayfaDurumTuru {
  /// `suspended_at` dolu: askıya alındı; sebep gösterilmez.
  askida,

  /// `deletion_at` dolu: silinme zamanı gösterilir.
  silinecek,

  /// `archived`: salt okunur.
  arsiv,

  /// `warned`: hareketsiz; 7 gün içinde etkinlik olmazsa arşivlenir.
  uyari,
}

/// Gösterilecek tek durum şeridi.
@immutable
final class TayfaDurumu {
  const TayfaDurumu(this.tur, {this.zaman});

  final TayfaDurumTuru tur;

  /// [TayfaDurumTuru.silinecek] için silinme zamanı (UTC).
  final DateTime? zaman;

  @override
  bool operator ==(Object other) =>
      other is TayfaDurumu && other.tur == tur && other.zaman == zaman;

  @override
  int get hashCode => Object.hash(tur, zaman);
}

/// [tayfa]'nın şeridi; durum olağansa `null`. Birden çok durum varsa en
/// ağırı gösterilir: askı, silinme, arşiv, uyarı. Şerit yalnızca bilgidir;
/// düğmeler sunucunun hatalarına göre davranır, istemci durumdan yetki
/// çıkarmaz (ADR-0014 §6).
TayfaDurumu? tayfaDurumu(Tayfa tayfa) {
  if (tayfa.suspendedAt != null) {
    return const TayfaDurumu(TayfaDurumTuru.askida);
  }
  final silinme = tayfa.deletionAt;
  if (silinme != null) {
    return TayfaDurumu(TayfaDurumTuru.silinecek, zaman: silinme);
  }
  return switch (tayfa.status) {
    TayfaStatus.archived => const TayfaDurumu(TayfaDurumTuru.arsiv),
    TayfaStatus.warned => const TayfaDurumu(TayfaDurumTuru.uyari),
    TayfaStatus.active || TayfaStatus.unknown => null,
  };
}
