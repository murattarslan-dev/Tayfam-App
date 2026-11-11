import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_islemleri.dart';

/// Bir etkinliğin anahtarı: adresteki tayfa ve etkinlik kimliği.
typedef EtkinlikAnahtari = ({String tayfaId, String etkinlikId});

/// Etkinlik detayı (ADR-0015 §3): `GET .../events/{event_id}`, türe özel
/// ayrıntılarıyla. Ekran kapanınca bırakılır; veri yalnızca bellektedir.
class EtkinlikDetayNotifier extends AsyncNotifier<Event> {
  EtkinlikDetayNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  Future<Event> build() => ref
      .read(etkinlikIslemleriProvider)
      .etkinlik(anahtar.tayfaId, anahtar.etkinlikId);

  /// Baştan okur (aşağı çekince). Hata ekranda gösterilir.
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu ekranda gösterilir.
    }
  }

  /// Bir işlemin sonucunu gösterir.
  void guncelle(Event etkinlik) {
    if (etkinlik.id != anahtar.etkinlikId) return;
    state = AsyncData(etkinlik);
  }

  /// Arka planda yeniden okur; hata gösterilmez, eldeki veri kalır.
  Future<void> sessizceYenile() async {
    try {
      final etkinlik = await ref
          .read(etkinlikIslemleriProvider)
          .etkinlik(anahtar.tayfaId, anahtar.etkinlikId);
      if (ref.mounted) guncelle(etkinlik);
    } on Exception {
      // Eldeki veri kalır.
    }
  }
}

/// Bir etkinliğin detayı. Hata otomatik yeniden denenmez.
final etkinlikDetayProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikDetayNotifier, Event, EtkinlikAnahtari>(
      EtkinlikDetayNotifier.new,
      name: 'etkinlikDetayProvider',
      retry: yenidenDenemeYok,
    );

/// Detay ekranında süren işlem.
enum EtkinlikEylemi { katilim, iptal, takvim }

/// Detay ekranının işlemleri: katılım cevabı, iptal ve takvime ekleme.
/// Durum, süren işlemdir (yoksa `null`); aynı anda tek işlem yapılır.
///
/// Her işlem hatayı döndürür (başarıda `null`); ekran onu `hataBildir` ile
/// gösterir. Yetki kararı sunucudadır (`permission-denied`,
/// `event-cancelled`, `event-ended`); istemci yalnızca düğmeleri
/// sadeleştirir.
class EtkinlikEylemNotifier extends Notifier<EtkinlikEylemi?> {
  EtkinlikEylemNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  EtkinlikEylemi? build() => null;

  EtkinlikIslemleri get _islemler => ref.read(etkinlikIslemleriProvider);

  EtkinlikDetayNotifier get _detay =>
      ref.read(etkinlikDetayProvider(anahtar).notifier);

  /// Katılım cevabını verir. Kaydedilen cevap (dolu etkinlikte bekleme
  /// listesi) ve sayılar hemen gösterilir; etkinlik ardından yeniden okunur
  /// ve katılımcı listeleri tazelenir.
  Future<Object?> katil(RsvpRequestStatus durum) async {
    final etkinlik = ref.read(etkinlikDetayProvider(anahtar)).value;
    if (state != null || etkinlik == null || durum == RsvpRequestStatus.unknown) {
      return null;
    }
    return _calistir(EtkinlikEylemi.katilim, () async {
      final kaydedilen = await _islemler.katilim(
        anahtar.tayfaId,
        anahtar.etkinlikId,
        durum,
      );
      if (!ref.mounted) return;
      final guncel = ref.read(etkinlikDetayProvider(anahtar)).value ?? etkinlik;
      _detay.guncelle(katilimiUygula(guncel, kaydedilen));
      ref.invalidate(katilimcilarProvider);
      etkinlikListeleriniYenile(ref, anahtar.tayfaId);
      unawaited(_detay.sessizceYenile());
    });
  }

  /// Etkinliği [gerekce] ile iptal eder.
  Future<Object?> iptalEt(String gerekce) async {
    final metin = gerekce.trim();
    if (state != null || metin.isEmpty) return null;
    return _calistir(EtkinlikEylemi.iptal, () async {
      final etkinlik = await _islemler.iptalEt(
        anahtar.tayfaId,
        anahtar.etkinlikId,
        metin,
      );
      if (!ref.mounted) return;
      _detay.guncelle(etkinlik);
      etkinlikListeleriniYenile(ref, anahtar.tayfaId);
    });
  }

  /// `.ics` dosyasını indirir ve paylaşım menüsüyle takvime verir.
  Future<Object?> takvimeEkle({Rect? konum}) async {
    if (state != null) return null;
    return _calistir(EtkinlikEylemi.takvim, () async {
      final icerik = await _islemler.takvim(
        anahtar.tayfaId,
        anahtar.etkinlikId,
      );
      if (!ref.mounted) return;
      await ref.read(takvimPaylasiciProvider).paylas(icerik, konum: konum);
    });
  }

  Future<Object?> _calistir(
    EtkinlikEylemi eylem,
    Future<void> Function() islem,
  ) async {
    state = eylem;
    try {
      await islem();
      return null;
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      return hata;
    } on UnsupportedError catch (hata) {
      // Web geliştirme derlemesinde dosya paylaşımı yoktur.
      return hata;
    } finally {
      if (ref.mounted) state = null;
    }
  }
}

/// Detay ekranının işlemleri; ekran kapanınca bırakılır.
final etkinlikEylemProvider = NotifierProvider.autoDispose
    .family<EtkinlikEylemNotifier, EtkinlikEylemi?, EtkinlikAnahtari>(
      EtkinlikEylemNotifier.new,
      name: 'etkinlikEylemProvider',
    );
