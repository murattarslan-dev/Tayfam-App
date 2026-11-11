import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';

/// Bildirim izni akışının durumu.
@immutable
final class BildirimIzniDurumu {
  const BildirimIzniDurumu({
    this.izin,
    this.aciklamaGoster = false,
    this.isleniyor = false,
  });

  /// Cihazdaki izin; henüz okunmadıysa ya da push yoksa `null`.
  final BildirimIzni? izin;

  /// Uygulamanın kendi kısa açıklama kartı gösterilmeli.
  final bool aciklamaGoster;

  /// Sistem penceresi ya da ayarlar açık.
  final bool isleniyor;

  BildirimIzniDurumu _degistir({
    BildirimIzni? izin,
    bool? aciklamaGoster,
    bool? isleniyor,
  }) => BildirimIzniDurumu(
    izin: izin ?? this.izin,
    aciklamaGoster: aciklamaGoster ?? this.aciklamaGoster,
    isleniyor: isleniyor ?? this.isleniyor,
  );

  @override
  bool operator ==(Object other) =>
      other is BildirimIzniDurumu &&
      other.izin == izin &&
      other.aciklamaGoster == aciklamaGoster &&
      other.isleniyor == isleniyor;

  @override
  int get hashCode => Object.hash(izin, aciklamaGoster, isleniyor);
}

/// Bildirim izni (istemci ADR-0019 §3; platform sahibi, sohbette):
///
/// - İzin **ilk gerçek ihtiyaçta** istenir: ilk tayfaya katılınca ya da
///   tayfa kurunca, ilk birebir mesaj gönderilince ([ihtiyacDogdu]). Önce
///   uygulamanın kısa açıklama kartı ([BildirimIzniDurumu.aciklamaGoster]),
///   "İzin ver" denirse sistem penceresi gelir.
/// - Kart bir kez gösterilir (kabul ya da ret; bayrak
///   [CihazBayragi.bildirimIzniSoruldu]); izin bir daha kendiliğinden
///   sorulmaz. Profil → Bildirimler'den açılır ([ac]); sistem penceresi
///   artık gelmiyorsa uygulamanın sistem ayarı açılır.
/// - İzin verilince token sunucuya kaydedilir ([PushKaydi.esitle]).
class BildirimIzniNotifier extends Notifier<BildirimIzniDurumu> {
  @override
  BildirimIzniDurumu build() {
    unawaited(yenile());
    return const BildirimIzniDurumu();
  }

  PushPlatformu get _platform => ref.read(pushPlatformuProvider);

  /// İzni cihazdan yeniden okur (Profil → Bildirimler açılınca, uygulama
  /// ön plana dönünce). İzin yeni verildiyse token kaydedilir.
  Future<void> yenile() async {
    final platform = _platform;
    if (!platform.etkin) return;
    final izin = await platform.izin();
    if (!ref.mounted) return;
    final onceki = state.izin;
    state = state._degistir(izin: izin);
    if (izin == BildirimIzni.verildi && onceki != BildirimIzni.verildi) {
      unawaited(ref.read(pushKaydiProvider).esitle());
    }
  }

  /// Bildirimin gerçekten işe yarayacağı bir an geldi. İzin yoksa ve kart
  /// daha önce gösterilmediyse kartı gösterir; aksi halde bir şey yapmaz.
  Future<void> ihtiyacDogdu() async {
    final platform = _platform;
    if (!platform.etkin || state.aciklamaGoster) return;
    final ayarlar = ref.read(cihazAyarlariDeposuProvider);
    if (await _bayrakOku(ayarlar)) return;
    final izin = await platform.izin();
    if (!ref.mounted) return;
    if (izin == BildirimIzni.verildi) {
      state = state._degistir(izin: izin);
      return;
    }
    state = state._degistir(izin: izin, aciklamaGoster: true);
  }

  /// Açıklama kartında "İzin ver": sistem penceresi gösterilir.
  Future<void> aciklamayiKabulEt() async {
    state = state._degistir(aciklamaGoster: false);
    await _bayrakKoy();
    await _iste(ayaraGit: false);
  }

  /// Açıklama kartında "Şimdi değil": bir daha kendiliğinden sorulmaz.
  Future<void> aciklamayiReddet() async {
    state = state._degistir(aciklamaGoster: false);
    await _bayrakKoy();
  }

  /// Profil → Bildirimler'deki "Bildirimleri aç": sistem penceresi
  /// gösterilebiliyorsa o, gösterilemiyorsa uygulamanın sistem ayarı.
  Future<void> ac() async {
    await _bayrakKoy();
    await _iste(ayaraGit: true);
  }

  /// Uygulamanın sistemdeki bildirim ayarlarını açar (izni kapatmak ya da
  /// kanal ayarı için).
  Future<void> ayarlariAc() async {
    await _platform.ayarlariAc();
  }

  Future<void> _iste({required bool ayaraGit}) async {
    final platform = _platform;
    if (!platform.etkin || state.isleniyor) return;
    state = state._degistir(isleniyor: true);
    try {
      final izin = await platform.izinIste();
      if (!ref.mounted) return;
      state = state._degistir(izin: izin);
      if (izin == BildirimIzni.verildi) {
        unawaited(ref.read(pushKaydiProvider).esitle());
      } else if (ayaraGit) {
        await platform.ayarlariAc();
      }
    } finally {
      if (ref.mounted) state = state._degistir(isleniyor: false);
    }
  }

  Future<bool> _bayrakOku(CihazAyarlariDeposu ayarlar) async {
    try {
      return await ayarlar.bayrakOku(CihazBayragi.bildirimIzniSoruldu);
    } on Exception {
      // Okunamazsa sorulmuş sayılır: kart yanlışlıkla tekrar çıkmasın.
      return true;
    }
  }

  Future<void> _bayrakKoy() async {
    try {
      await ref
          .read(cihazAyarlariDeposuProvider)
          .bayrakKoy(CihazBayragi.bildirimIzniSoruldu);
    } on Exception {
      // Yazılamazsa bu çalışmada kart zaten kapandı.
    }
  }
}

/// Bildirim izni akışı (kalıcı; ADR-0001 kural 4). Cihaza aittir,
/// kullanıcıya bağlı değildir.
final bildirimIzniProvider =
    NotifierProvider<BildirimIzniNotifier, BildirimIzniDurumu>(
      BildirimIzniNotifier.new,
      name: 'bildirimIzniProvider',
    );
