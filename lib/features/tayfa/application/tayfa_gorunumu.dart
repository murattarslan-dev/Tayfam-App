import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
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
      _bulunamadiysaListeyiYenile(problem);
      rethrow;
    }
  }

  /// Görünümü yeniden okur (ana sayfa aşağı çekilince). Okunamazsa eldeki
  /// görünüm kalır; elde görünüm yoksa hata gösterilir.
  Future<void> yenile() async {
    try {
      final gorunum = await ref.read(tayfaDeposuProvider).tayfa(tayfaId);
      if (ref.mounted) state = AsyncData(gorunum);
    } on Exception catch (hata, yigin) {
      if (hata is ApiProblem) _bulunamadiysaListeyiYenile(hata);
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
    }
  }

  void _bulunamadiysaListeyiYenile(ApiProblem problem) {
    if (problem.type == ProblemType.tayfaNotFound && ref.mounted) {
      unawaited(ref.read(tayfalarimProvider.notifier).yenile());
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

/// Ana sayfada gösterilen tayfa bilgisi: ad, üye sayısı, durum, (yalnızca
/// yöneticiye dönen) katılım kodu, kullanıcının rolü ve açık modüller.
///
/// Rol ve modüller arayüzü sadeleştirmek içindir; bir işlemin yapılıp
/// yapılamayacağına sunucu karar verir (kesin kural 5).
@immutable
final class TayfaOzeti {
  const TayfaOzeti({this.ad, this.tayfa, this.rol});

  /// Tayfanın adı; bilinmiyorsa `null`.
  final String? ad;

  /// Tam tayfa bilgisi; henüz bilinmiyorsa `null`.
  final Tayfa? tayfa;

  /// Kullanıcının bu tayfadaki rolü; bilinmiyorsa `null`.
  final Role? rol;

  /// Kullanıcı moderatör ya da yönetici: duyuru yazma, düzenleme,
  /// sabitleme ve silme düğmeleri gösterilir (ADR-0015 §2).
  bool get yonetimde => rol == Role.moderator || rol == Role.admin;

  /// "Etkinlik aç" gösterilir: moderatör, yönetici ya da tayfada
  /// `members_can_create_events` açıksa her üye (sözleşme).
  bool get etkinlikAcabilir =>
      yonetimde || (tayfa?.membersCanCreateEvents ?? false);

  /// Sunucunun açık dediği modüllerin anahtarları; tayfa bilinmiyorsa boş.
  Set<String> get acikModuller {
    final tayfa = this.tayfa;
    if (tayfa == null) return const {};
    return acikModulAnahtarlari(tayfa.modules);
  }

  /// Onay bekleyen katılım isteği sayısı (rozet). Alan yalnızca istekleri
  /// onaylayabilen moderatör ve yöneticiye döner; alan yoksa ya da 0 ise
  /// `null` ve rozet görünmez. Yetki kararı sunucudadır (kesin kural 5).
  int? get bekleyenIstekSayisi => bekleyenIstekRozeti(tayfa);

  /// Paylaşılacak katılım kodu; yalnızca yöneticiye döner (sözleşme). Kod
  /// yoksa paylaşım düğmesi görünmez; bu bir kolaylıktır, yetki kararı
  /// değildir (kesin kural 5).
  String? get katilimKodu {
    final kod = tayfa?.joinCode;
    return kod == null || kod.isEmpty ? null : kod;
  }
}

/// [tayfa]'nın `pending_join_request_count` alanından rozet sayısı: alan
/// yoksa (yetki yok) ya da 0 ise `null`.
int? bekleyenIstekRozeti(Tayfa? tayfa) {
  final sayi = tayfa?.pendingJoinRequestCount;
  return sayi == null || sayi <= 0 ? null : sayi;
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
  final rol = gorunum?.callerRole ?? listedeki?.role;
  return TayfaOzeti(
    ad: ad == null || ad.isEmpty ? null : ad,
    tayfa: tayfa,
    rol: rol == Role.unknown ? null : rol,
  );
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
