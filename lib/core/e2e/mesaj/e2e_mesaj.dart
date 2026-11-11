import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/cihaz/e2e_cihaz.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_alici.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_gonderici.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_guvenlik.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/realtime/realtime.dart';

export 'package:tayfam/core/e2e/cihaz/e2e_cihaz.dart';
export 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';

/// Signal oturumları ve cihaz listesi önbelleği (oturum değişince
/// yeniden kurulur; bellek önbelleği sıfırlanır).
final e2eOturumlariProvider = Provider<E2eOturumlari>((ref) {
  ref.watch(oturumDurumuProvider);
  return E2eOturumlari(
    motor: ref.watch(e2eMotoruProvider),
    depo: ref.watch(e2eDeposuProvider),
    api: ref.watch(apiClientProvider),
    guvenlikDegisti: (kullaniciId, kimlik) => ref
        .read(birebirIcerikProvider.notifier)
        .kullaniciSatiri(
          kullaniciId,
          E2eSistemSatiri(
            kimlik: kimlik,
            tur: E2eSatirTuru.guvenlikKoduDegisti,
            zaman: DateTime.now().toUtc(),
          ),
        ),
  );
}, name: 'e2eOturumlariProvider');

/// Şifreli gönderim.
final e2eGondericiProvider = Provider<E2eGonderici>(
  (ref) => E2eGonderici(
    oturumlar: ref.watch(e2eOturumlariProvider),
    api: ref.watch(apiClientProvider),
    kullaniciKimligi: ref.watch(sessionStoreProvider).kullaniciKimligi,
    cihazKimligi: () => ref.read(e2eDeposuProvider).cihaz?.id,
    yayin: ref.watch(e2eMesajYayiniProvider),
  ),
  name: 'e2eGondericiProvider',
);

/// Zarf alımı.
final e2eAliciProvider = Provider<E2eAlici>((ref) {
  final realtime = ref.watch(realtimeIstemcisiProvider);
  final me = MeApi(ref.watch(apiClientProvider));
  return E2eAlici(
    oturumlar: ref.watch(e2eOturumlariProvider),
    api: ref.watch(apiClientProvider),
    icerikEkle: (m) => ref.read(birebirIcerikProvider.notifier).ekle([m]),
    cozulemedi: (konusmaId, satir) => ref
        .read(birebirIcerikProvider.notifier)
        .konusmaSatiri(konusmaId, satir),
    onayla: (idler) async {
      if (realtime.durum == RealtimeDurumu.acik) {
        try {
          await realtime.zarflariOnayla(idler);
          return;
        } on RealtimeKapali {
          // REST'e düşülür.
        } on TimeoutException {
          // REST'e düşülür.
        }
      }
      await me.ackE2EEnvelopes(body: E2EEnvelopeAck(envelopeIds: idler));
    },
    yayin: ref.watch(e2eMesajYayiniProvider),
  );
}, name: 'e2eAliciProvider');

/// "Güvenlik kodu değişti" denetimi.
final e2eGuvenlikProvider = Provider<E2eGuvenlikDenetcisi>(
  (ref) => E2eGuvenlikDenetcisi(
    oturumlar: ref.watch(e2eOturumlariProvider),
    api: ref.watch(apiClientProvider),
  ),
  name: 'e2eGuvenlikProvider',
);

/// Birebir özelliğinin E2E kapısı: cihaz hazır olunca şifreli gönderir,
/// gönderilen içeriği belleğe ekler; konuşma açılınca güvenlik
/// uyarılarını denetler.
final class E2eBirebir {
  E2eBirebir(this._ref);

  final Ref _ref;

  /// [aliciId]'ye şifreli gönderir (yalnızca REST, aynı
  /// [istekKimligi]). Cihaz hazır değilse ya da gönderim başarısızsa
  /// hata fırlatılır.
  Future<DirectMessageSent> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) async {
    await _ref.read(e2eCihazProvider.notifier).hazirOl();
    final (sonuc, icerik) = await _ref
        .read(e2eGondericiProvider)
        .gonder(aliciId: aliciId, metin: metin, istekKimligi: istekKimligi);
    _ref.read(birebirIcerikProvider.notifier).ekle([icerik]);
    return sonuc;
  }

  /// Konuşma açıldı: karşı tarafın anahtar olayları ve cihaz listesi
  /// denetlenir, yeni "güvenlik kodu değişti" satırları eklenir. Hata
  /// sessizce yutulur (bir sonraki açılışta yeniden denenir).
  Future<void> konusmaAcildi(String karsiId) async {
    if (!_ref.read(e2eCihazProvider).hazir) return;
    try {
      final satirlar = await _ref.read(e2eGuvenlikProvider).denetle(karsiId);
      final icerik = _ref.read(birebirIcerikProvider.notifier);
      for (final s in satirlar) {
        icerik.kullaniciSatiri(karsiId, s);
      }
    } on Exception {
      // Uyarı denetimi en iyi çabadır.
    }
  }
}

/// Birebir özelliğinin E2E kapısı.
final e2eBirebirProvider = Provider<E2eBirebir>(
  E2eBirebir.new,
  name: 'e2eBirebirProvider',
);

/// E2E'nin uygulama düzeyindeki işleri (ADR-0020): cihaz hazır olunca ve
/// her yeniden bağlanmada bekleyen zarfları çeker; WebSocket'ten gelen
/// zarfları işler; ön anahtar azalma sinyalinde yükleme yapar; kendi
/// hesabına eklenen yeni cihazları bilgi satırı olarak gösterir.
///
/// Kabuk açılınca bir kez okunur; kendisi bir şey tutmaz.
final e2eYoneticisiProvider = Provider<void>((ref) {
  if (!ref.watch(e2eEtkinProvider)) return;
  final realtime = ref.watch(realtimeIstemcisiProvider);

  Future<void> cek() async {
    if (!ref.read(e2eCihazProvider).hazir) return;
    try {
      await ref.read(e2eAliciProvider).cek();
    } on Exception {
      // Bir sonraki bağlanmada ya da açılışta yeniden denenir.
    }
  }

  Future<void> zarfGeldi(E2EEnvelope zarf) async {
    if (!ref.read(e2eCihazProvider).hazir) return;
    try {
      await ref.read(e2eAliciProvider).zarfGeldi(zarf);
    } on Exception {
      // Onaylanmayan zarf yeniden bağlanınca REST'ten gelir.
    }
  }

  Future<void> kendiCihazlari() async {
    try {
      final benId = await ref.read(sessionStoreProvider).kullaniciKimligi();
      final olaylar = await ref
          .read(e2eCihazYoneticisiProvider)
          .yeniKendiCihazlari(benId);
      final icerik = ref.read(birebirIcerikProvider.notifier);
      for (final o in olaylar) {
        icerik.genelSatir(
          E2eSistemSatiri(
            kimlik: 'kendi:${o.id}',
            tur: E2eSatirTuru.yeniKendiCihazi,
            zaman: o.createdAt,
          ),
        );
      }
    } on Exception {
      // En iyi çaba.
    }
  }

  ref.listen(e2eCihazProvider, (onceki, simdiki) {
    if (simdiki.hazir && onceki?.hazir != true) {
      unawaited(cek());
      unawaited(kendiCihazlari());
    }
  }, fireImmediately: true);

  final abonelik = realtime.olaylar.listen((olay) {
    switch (olay) {
      case DmZarfiGeldi(:final zarf):
        unawaited(zarfGeldi(zarf));
      case E2eOnAnahtarlarAzaldi():
        unawaited(ref.read(e2eCihazProvider.notifier).onAnahtarlarAzaldi());
      case Baglandi():
        unawaited(cek());
      default:
        break;
    }
  });
  ref.onDispose(abonelik.cancel);
}, name: 'e2eYoneticisiProvider');
