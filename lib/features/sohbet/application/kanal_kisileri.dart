import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';

/// Etkinlik ya da seçili kişi kanalının katılımcıları
/// (`GET …/channels/{channel_id}/members`, sayfalı; Tayfam-Api #183).
///
/// Yalnızca kimlikler döner; adlar profil önbelleğinden okunur. Kanala
/// bağlıdır: `family` + `autoDispose`; oturum değişince yeniden kurulur.
/// Yalnızca bellektedir (ADR-0006).
class KatilimcilarNotifier extends SayfaliListeNotifier<String> {
  KatilimcilarNotifier(this.kanal);

  final KanalRef kanal;

  @override
  Future<SayfaliListe<String>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(kanalDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<String>> sayfaGetir(String? sayfaToken) => ref
      .read(kanalDeposuProvider)
      .katilimcilar(kanal.tayfaId, kanal.kanalId, sayfaToken: sayfaToken);

  @override
  String kimlik(String oge) => oge;

  /// Çıkarılan kişiyi listeden düşer (sunucu kabul ettikten sonra).
  void dus(String kisi) =>
      ogeleriDegistir((ogeler) => [for (final o in ogeler) if (o != kisi) o]);
}

/// Bir kanalın katılımcıları.
final katilimcilarProvider = AsyncNotifierProvider.autoDispose
    .family<KatilimcilarNotifier, SayfaliListe<String>, KanalRef>(
      KatilimcilarNotifier.new,
      name: 'katilimcilarProvider',
      retry: _yenidenDenemeYok,
    );

/// Kişi seçicideki tayfa üyeleri (`GET /v1/tayfas/{tayfa_id}/members`,
/// etkin üyeler, sayfalı). Tayfaya bağlıdır: `family` + `autoDispose`.
class KanalUyeAdaylariNotifier extends SayfaliListeNotifier<Membership> {
  KanalUyeAdaylariNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<SayfaliListe<Membership>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(kanalDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Membership>> sayfaGetir(String? sayfaToken) => ref
      .read(kanalDeposuProvider)
      .tayfaUyeleri(tayfaId, sayfaToken: sayfaToken);

  @override
  String kimlik(Membership oge) => oge.userId;
}

/// Kişi seçicinin tayfa üyeleri.
final kanalUyeAdaylariProvider = AsyncNotifierProvider.autoDispose
    .family<KanalUyeAdaylariNotifier, SayfaliListe<Membership>, String>(
      KanalUyeAdaylariNotifier.new,
      name: 'kanalUyeAdaylariProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
