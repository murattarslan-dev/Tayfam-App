import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Davet kabulünün sonucu: hata ya da üyeliğin hemen etkin olup olmadığı
/// (tayfa onaylı katılımlıysa ve davet eden yönetimde değilse istek onay
/// bekler; sözleşme).
typedef DavetKabulu = ({Object? hata, bool etkin});

/// Size gelen, cevaplanmamış doğrudan tayfa davetleri
/// (`GET /v1/me/invitations`, yeniden eskiye, sayfalı; ADR-0018 §7).
/// Yalnızca bellektedir (ADR-0006).
class TayfaDavetleriNotifier extends SayfaliListeNotifier<Invitation> {
  @override
  Future<SayfaliListe<Invitation>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(arkadasDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Invitation>> sayfaGetir(String? sayfaToken) =>
      ref.read(arkadasDeposuProvider).gelenDavetler(sayfaToken: sayfaToken);

  @override
  String kimlik(Invitation oge) => oge.tayfaId;

  /// Daveti kabul eder; tayfa listesi yenilenir.
  Future<DavetKabulu> kabulEt(String tayfaId) async {
    var etkin = false;
    final hata = await arkadasIslemi(ref, () async {
      final uyelik = await ref
          .read(arkadasDeposuProvider)
          .davetiKabulEt(tayfaId);
      etkin = uyelik.status == MembershipStatus.active;
      _cikar(tayfaId);
      if (!ref.mounted) return;
      unawaited(ref.read(tayfalarimProvider.notifier).yenile());
    });
    return (hata: hata, etkin: hata == null && etkin);
  }

  /// Daveti reddeder; davet edene bildirilmez.
  Future<Object?> reddet(String tayfaId) => arkadasIslemi(ref, () async {
    await ref.read(arkadasDeposuProvider).davetiReddet(tayfaId);
    _cikar(tayfaId);
  });

  void _cikar(String tayfaId) {
    if (!ref.mounted) return;
    ogeleriDegistir(
      (ogeler) => [
        for (final d in ogeler)
          if (d.tayfaId != tayfaId) d,
      ],
    );
    if (ref.read(gelenDavetVarProvider.exists)) {
      ref.invalidate(gelenDavetVarProvider);
    }
  }
}

/// Gelen tayfa davetleri.
final tayfaDavetleriProvider =
    AsyncNotifierProvider.autoDispose<
      TayfaDavetleriNotifier,
      SayfaliListe<Invitation>
    >(
      TayfaDavetleriNotifier.new,
      name: 'tayfaDavetleriProvider',
      retry: yenidenDenemeYok,
    );

/// Cevap bekleyen tayfa daveti var mı (profil girişindeki rozet). Yalnızca
/// ilk kaydı ister; okunamazsa rozet gösterilmez.
class GelenDavetVarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(arkadasDeposuProvider);
    final sayfa = await depo.gelenDavetler(sayfaBoyutu: 1);
    return sayfa.ogeler.isNotEmpty;
  }
}

/// Gelen tayfa daveti var mı.
final gelenDavetVarProvider =
    AsyncNotifierProvider.autoDispose<GelenDavetVarNotifier, bool>(
      GelenDavetVarNotifier.new,
      name: 'gelenDavetVarProvider',
      retry: yenidenDenemeYok,
    );
