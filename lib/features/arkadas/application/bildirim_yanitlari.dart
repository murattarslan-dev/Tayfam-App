import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/application/tayfa_davetleri_notifier.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Davet kabulünün sonucu: hata ya da üyeliğin hemen etkin olup olmadığı
/// (onaylı katılımlı tayfada davet eden yönetimde değilse istek onay
/// bekler; sözleşme).
typedef DavetYaniti = ({Object? hata, bool etkin});

/// Bildirim satırından arkadaşlık isteğine ve tayfa davetine cevap
/// (2026-11-13 tasarım: Bildirimler, karar 2). İstekler ve davetler
/// ekranlarıyla aynı uçları ve aynı sonrasını kullanır: açık listeler ve
/// rozetler yeniden okunur, davet kabulünde tayfa listesi yenilenir.
///
/// Yetki ve durum kararı sunucudadır (kesin kural 5): istek ya da davet
/// artık yoksa sunucunun hatası döner ve ekran gösterir. Hata log'a
/// yazılmaz.
final class BildirimYanitlari {
  BildirimYanitlari(this._ref);

  final Ref _ref;

  ArkadasDeposu get _depo => _ref.read(arkadasDeposuProvider);

  /// `POST /v1/me/friend-requests/{user_id}/acceptance`. Başarıda `null`.
  Future<Object?> istegiKabulEt(String kullaniciId) =>
      arkadasIslemi(_ref, () async {
        await _depo.istegiKabulEt(kullaniciId);
        arkadaslikDegisti(_ref);
      });

  /// `DELETE /v1/me/friends/{user_id}`: gelen isteği reddeder; karşı
  /// tarafa bildirilmez. Başarıda `null`.
  Future<Object?> istegiReddet(String kullaniciId) =>
      arkadasIslemi(_ref, () async {
        await _depo.arkadasligiKaldir(kullaniciId);
        arkadaslikDegisti(_ref, arkadaslar: false);
      });

  /// `POST /v1/me/invitations/{tayfa_id}/acceptance`.
  Future<DavetYaniti> davetiKabulEt(String tayfaId) async {
    var etkin = false;
    final hata = await arkadasIslemi(_ref, () async {
      final uyelik = await _depo.davetiKabulEt(tayfaId);
      etkin = uyelik.status == MembershipStatus.active;
      _davetlerDegisti();
      if (!_ref.mounted) return;
      unawaited(_ref.read(tayfalarimProvider.notifier).yenile());
    });
    return (hata: hata, etkin: hata == null && etkin);
  }

  /// `DELETE /v1/me/invitations/{tayfa_id}`: davet edene bildirilmez.
  /// Başarıda `null`.
  Future<Object?> davetiReddet(String tayfaId) =>
      arkadasIslemi(_ref, () async {
        await _depo.davetiReddet(tayfaId);
        _davetlerDegisti();
      });

  /// Açık davet listesi ve profil rozeti yeniden okunur.
  void _davetlerDegisti() {
    if (!_ref.mounted) return;
    if (_ref.read(tayfaDavetleriProvider.exists)) {
      _ref.invalidate(tayfaDavetleriProvider);
    }
    if (_ref.read(gelenDavetVarProvider.exists)) {
      _ref.invalidate(gelenDavetVarProvider);
    }
  }
}

/// Bildirim satırından arkadaşlık ve davet cevapları. Durum tutmaz.
final bildirimYanitlariProvider = Provider<BildirimYanitlari>(
  BildirimYanitlari.new,
  name: 'bildirimYanitlariProvider',
);
