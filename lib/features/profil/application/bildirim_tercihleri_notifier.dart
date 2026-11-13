import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/profil/data/bildirim_tercihleri_deposu.dart';

/// Sessize alınmış bir tayfa: [bitis] yoksa süresiz.
@immutable
final class SessizTayfa {
  const SessizTayfa(this.tayfaId, [this.bitis]);

  final String tayfaId;

  /// Sessizliğin bittiği an; süresizde `null`.
  final DateTime? bitis;

  @override
  bool operator ==(Object other) =>
      other is SessizTayfa && other.tayfaId == tayfaId && other.bitis == bitis;

  @override
  int get hashCode => Object.hash(tayfaId, bitis);
}

/// Bildirim ayarları ekranının sessize alınanlar özeti (2026-11-13
/// tasarım: Bildirim-Ayarlari, karar 8).
@immutable
final class SessizOzeti {
  const SessizOzeti({required this.tayfalar, required this.konusmaSayisi});

  /// Sessizdeki tayfalar, sunucunun sırasıyla.
  final List<SessizTayfa> tayfalar;

  /// Sessizdeki birebir konuşma sayısı. Konuşmalar burada listelenmez;
  /// sesleri konuşmanın ⋯ menüsünden açılır.
  final int konusmaSayisi;
}

/// Tercihlerden [simdi] itibarıyla sessizdekiler: tayfada seviye `none` ya
/// da `mentions`, konuşmada `none`; (varsa) süresi dolmamış. Tercihi
/// olmayan ya da süresi dolan `all`'dur (sözleşme). Kimliği UUID biçiminde
/// olmayan kayıt (sunucu girdisi) alınmaz.
SessizOzeti sessizOzeti(
  List<NotificationPreference> tercihler,
  DateTime simdi,
) {
  bool suruyor(NotificationPreference t) {
    final bitis = t.muteUntil;
    return bitis == null || bitis.isAfter(simdi);
  }

  final tayfalar = <SessizTayfa>[];
  var konusma = 0;
  for (final t in tercihler) {
    if (!uuidBicimindeMi(t.scopeId) || !suruyor(t)) continue;
    final sessiz = t.level == NotificationPreferenceLevel.none;
    final yalnizAnma = t.level == NotificationPreferenceLevel.mentions;
    if (t.scopeType == NotificationPreferenceScopeType.tayfa &&
        (sessiz || yalnizAnma)) {
      tayfalar.add(SessizTayfa(t.scopeId, t.muteUntil));
    } else if (t.scopeType == NotificationPreferenceScopeType.dmConversation &&
        sessiz) {
      konusma++;
    }
  }
  return SessizOzeti(tayfalar: tayfalar, konusmaSayisi: konusma);
}

/// Profil → Bildirim ayarları'ndaki sessize alınanlar (`GET
/// /v1/notification-preferences`; karar 8). Tayfanın sesi buradan açılır
/// (`DELETE …/tayfas/{tayfa_id}`); sessize alma tayfa menüsündedir.
///
/// Yalnızca bellektedir (ADR-0006); ekran kapanınca bırakılır, oturum
/// değişince yeniden kurulur.
class SessizOzetiNotifier extends AsyncNotifier<SessizOzeti> {
  @override
  Future<SessizOzeti> build() async {
    if (ref.watch(oturumDurumuProvider) != OturumDurumu.acik) {
      throw const OturumYok();
    }
    final depo = ref.watch(bildirimTercihleriDeposuProvider);
    final tercihler = await depo.tercihler();
    return sessizOzeti(tercihler, ref.read(simdiProvider)());
  }

  /// [tayfaId]'nin sesini açar ve listeden çıkarır. Başarıda `null`, aksi
  /// halde gösterilecek hata.
  Future<Object?> sesiAc(String tayfaId) async {
    try {
      await ref.read(bildirimTercihleriDeposuProvider).tayfaSesiniAc(tayfaId);
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    }
    if (!ref.mounted) return null;
    final ozet = state.value;
    if (ozet != null) {
      state = AsyncData(
        SessizOzeti(
          tayfalar: [
            for (final t in ozet.tayfalar)
              if (t.tayfaId != tayfaId) t,
          ],
          konusmaSayisi: ozet.konusmaSayisi,
        ),
      );
    }
    return null;
  }
}

/// Sessize alınanların özeti. Hata otomatik yeniden denenmez; ekran
/// "Tekrar dene" sunar.
final sessizOzetiProvider =
    AsyncNotifierProvider.autoDispose<SessizOzetiNotifier, SessizOzeti>(
      SessizOzetiNotifier.new,
      name: 'sessizOzetiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
