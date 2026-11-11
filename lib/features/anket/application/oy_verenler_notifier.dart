import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/data/anket_deposu.dart';

/// Oy verenler listesinin anahtarı: tayfa, anket ve seçenek.
///
/// Anketin kendisi anahtardadır: gizli olup olmadığı listeyi açmadan önce
/// bilinir ve istek göndermeden denetlenir.
typedef OyVerenlerAnahtari = ({String tayfaId, Poll anket, String secenekId});

/// Gizli ankette oy verenler istendi; istek gönderilmedi (kesin kural 7).
final class GizliAnketOyVerenleri implements Exception {
  const GizliAnketOyVerenleri();

  @override
  String toString() => 'GizliAnketOyVerenleri';
}

/// Açık (gizli olmayan) ankette bir seçeneğe oy verenler
/// (`GET …/options/{option_id}/voters`, sayfalı, en eski oy önce;
/// ADR-0018 §5).
///
/// Gizli ankette ([oyVerenlerGorunur] `false`) uca hiç gidilmez:
/// ekran bu listeyi açmaz, açılsa bile [build] istek göndermeden
/// [GizliAnketOyVerenleri] ile biter. Sunucu da `poll-anonymous` ile
/// reddeder. Yalnızca bellektedir (ADR-0006).
class OyVerenlerNotifier extends SayfaliListeNotifier<PollVoter> {
  OyVerenlerNotifier(this.anahtar);

  final OyVerenlerAnahtari anahtar;

  @override
  Future<SayfaliListe<PollVoter>> build() async {
    ref.watch(oturumDurumuProvider);
    ref.watch(anketDeposuProvider);
    if (!oyVerenlerGorunur(anahtar.anket)) {
      throw const GizliAnketOyVerenleri();
    }
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<PollVoter>> sayfaGetir(String? sayfaToken) {
    if (!oyVerenlerGorunur(anahtar.anket)) {
      throw const GizliAnketOyVerenleri();
    }
    return ref
        .read(anketDeposuProvider)
        .oyVerenler(
          anahtar.tayfaId,
          anahtar.anket.id,
          anahtar.secenekId,
          sayfaToken: sayfaToken,
        );
  }

  @override
  String kimlik(PollVoter oge) => oge.userId;
}

/// Bir seçeneğe oy verenler; sayfa kapanınca bırakılır.
final oyVerenlerProvider = AsyncNotifierProvider.autoDispose
    .family<OyVerenlerNotifier, SayfaliListe<PollVoter>, OyVerenlerAnahtari>(
      OyVerenlerNotifier.new,
      name: 'oyVerenlerProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
