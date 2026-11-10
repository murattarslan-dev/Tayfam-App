import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';

/// Yeniden onay ekranının durumu.
@immutable
final class OnayDurumu {
  const OnayDurumu({
    required this.surumler,
    this.gonderiliyor = false,
    this.hata,
  });

  /// Gösterilen ve onaylanacak güncel sürümler.
  final OnaySurumleri surumler;

  /// Onay isteği sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin hatası (API ya da bağlantı hatası); yoksa `null`.
  /// Metni ekranda `hesapHatasiMetni` verir.
  final Object? hata;
}

/// Yeniden onay akışı (ADR-0012 §5): güncel sürümler okunur, gösterilen
/// sürümler `POST /v1/me/consents` ile onaylanır, ardından
/// `SessionStore.yenile()`. `consent-outdated` gelirse sürümler yeniden
/// okunur ve kullanıcı yeni metinleri yeniden onaylar.
class OnayNotifier extends AsyncNotifier<OnayDurumu> {
  @override
  Future<OnayDurumu> build() async {
    final depo = ref.watch(hesapDeposuProvider);
    final surumler = await depo.onaySurumleri();
    return OnayDurumu(surumler: surumler);
  }

  /// Gösterilen sürümleri onaylar. Sürerken ikinci çağrı yok sayılır.
  Future<void> onayla() async {
    final mevcut = state.value;
    if (mevcut == null || mevcut.gonderiliyor) return;
    final surumler = mevcut.surumler;
    state = AsyncData(OnayDurumu(surumler: surumler, gonderiliyor: true));
    final depo = ref.read(hesapDeposuProvider);
    final oturum = ref.read(sessionStoreProvider);
    final oturumDurumu = ref.read(oturumDurumuProvider.notifier);
    try {
      try {
        await depo.onayla(surumler);
      } on ApiProblem catch (problem) {
        if (problem.type != ProblemType.consentOutdated) rethrow;
        final yeni = await depo.onaySurumleri();
        _bitir(OnayDurumu(surumler: yeni, hata: problem));
        return;
      }
      await oturum.yenile();
      _bitir(OnayDurumu(surumler: surumler));
    } on OturumYok {
      oturumDurumu.ayarla(OturumDurumu.girisYok);
    } on Exception catch (hata) {
      _bitir(OnayDurumu(surumler: surumler, hata: hata));
    }
  }

  /// Oturumu kapatır (başka bir Google hesabıyla girmek için); yönlendirici
  /// giriş ekranına döner.
  Future<void> cikisYap() => ref.read(apiClientProvider).cikisYap();

  void _bitir(OnayDurumu durum) {
    if (ref.mounted) state = AsyncData(durum);
  }
}

/// Yeniden onay ekranının notifier'ı; ekran kapanınca bırakılır. Hata
/// otomatik yeniden denenmez; ekran "Tekrar dene" sunar.
final onayProvider =
    AsyncNotifierProvider.autoDispose<OnayNotifier, OnayDurumu>(
      OnayNotifier.new,
      name: 'onayProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
