import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/av_gunlugu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Organizatör düzeltmesi bitişten sonra bu süre içinde yapılabilir
/// (sözleşme: `correction-closed`).
const Duration katilimDuzeltmeSuresi = Duration(days: 7);

/// Av günlüğüne bitişten sonra bu süre içinde av eklenebilir (sözleşme:
/// `event-ended`).
const Duration avEklemeSuresi = Duration(days: 7);

/// Katılımcılar listesinde organizatör düzeltmesi gösterilir mi (ADR-0015
/// §6): yönetebilen kullanıcı, iptal edilmemiş etkinlik, bitişten sonraki
/// yedi gün. Kolaylıktır; karar sunucunundur.
bool katilimDuzeltmeAcik(Event etkinlik, DateTime simdi) =>
    etkinlik.callerCanManage &&
    !iptalEdildi(etkinlik) &&
    !simdi.isBefore(etkinlik.endsAt) &&
    simdi.isBefore(etkinlik.endsAt.add(katilimDuzeltmeSuresi));

/// Av eklenebilir mi: katılım doğrulanmış ve bitişten sonraki yedi gün
/// geçmemiş. Kolaylıktır; karar sunucunundur (`not-attended`,
/// `event-ended`).
bool avEklenebilir(Event etkinlik, DateTime simdi) =>
    katilimDogrulandi(etkinlik) &&
    simdi.isBefore(etkinlik.endsAt.add(avEklemeSuresi));

/// Konvoya araç eklenebilir mi: cevap "Geliyorum", iptal edilmemiş ve
/// bitmemiş (sözleşme: `event-not-going`).
bool aracEklenebilir(Event etkinlik, DateTime simdi) =>
    etkinlik.callerRsvp == RsvpStatus.going && katilimAcik(etkinlik, simdi);

/// Türe özel araçların detay ekranındaki işlemleri (ADR-0015 §6): konvoy
/// araçları, kamp malzemeleri, av günlüğü ve organizatör düzeltmesi.
///
/// Durum, bir işlemin sürüp sürmediğidir; aynı anda tek işlem yapılır. Her
/// işlem hatayı döndürür (başarıda `null`); ekran onu `hataBildir` ile
/// gösterir. Yetki sunucudadır; istemci yalnızca düğmeleri sadeleştirir
/// (kesin kural 5).
class AracEylemNotifier extends Notifier<bool> {
  AracEylemNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  bool build() => false;

  EtkinlikDeposu get _depo => ref.read(etkinlikDeposuProvider);

  EtkinlikDetayNotifier get _detay =>
      ref.read(etkinlikDetayProvider(anahtar).notifier);

  Event? get _etkinlik => ref.read(etkinlikDetayProvider(anahtar)).value;

  /// Kendi aracını konvoya ekler; önceki aracının yerini alır.
  Future<Object?> aracKaydet(ConvoyVehicleCreateRequest istek) =>
      _calistir(() async {
        final arac = await _depo.aracEkle(
          anahtar.tayfaId,
          anahtar.etkinlikId,
          istek,
        );
        final etkinlik = _etkinlik;
        if (!ref.mounted || etkinlik == null) return;
        final konvoy = etkinlik.convoy;
        _detay.guncelle(
          etkinlikKopyasi(
            etkinlik,
            convoy: ConvoyDetails(
              route: konvoy?.route,
              vehicles: [
                for (final a in konvoy?.vehicles ?? const <ConvoyVehicle>[])
                  if (a.userId != arac.userId) a,
                arac,
              ],
            ),
          ),
        );
      });

  /// Konvoydan bir aracı çıkarır.
  Future<Object?> aracCikar(String aracId) => _calistir(() async {
    await _depo.aracCikar(anahtar.tayfaId, anahtar.etkinlikId, aracId);
    final etkinlik = _etkinlik;
    if (!ref.mounted || etkinlik == null) return;
    final konvoy = etkinlik.convoy;
    _detay.guncelle(
      etkinlikKopyasi(
        etkinlik,
        convoy: ConvoyDetails(
          route: konvoy?.route,
          vehicles: [
            for (final a in konvoy?.vehicles ?? const <ConvoyVehicle>[])
              if (a.id != aracId) a,
          ],
        ),
      ),
    );
  });

  /// Kamp listesine malzeme ekler.
  Future<Object?> malzemeEkle(CampItemCreateRequest istek) =>
      _calistir(() async {
        final malzeme = await _depo.kampMalzemesiEkle(
          anahtar.tayfaId,
          anahtar.etkinlikId,
          istek,
        );
        final etkinlik = _etkinlik;
        if (!ref.mounted || etkinlik == null) return;
        _detay.guncelle(
          etkinlikKopyasi(
            etkinlik,
            camp: _kampKopyasi(etkinlik.camp, [
              ...?etkinlik.camp?.items,
              malzeme,
            ]),
          ),
        );
      });

  /// Kamp listesinden malzeme çıkarır.
  Future<Object?> malzemeCikar(String malzemeId) => _calistir(() async {
    await _depo.kampMalzemesiCikar(
      anahtar.tayfaId,
      anahtar.etkinlikId,
      malzemeId,
    );
    final etkinlik = _etkinlik;
    if (!ref.mounted || etkinlik == null) return;
    _detay.guncelle(
      etkinlikKopyasi(
        etkinlik,
        camp: _kampKopyasi(etkinlik.camp, [
          for (final m in etkinlik.camp?.items ?? const <CampItem>[])
            if (m.id != malzemeId) m,
        ]),
      ),
    );
  });

  /// Av günlüğüne av ekler. Tekrar denemede aynı `client_request_id`
  /// gönderilir (form açılınca bir kez üretilir).
  Future<Object?> avEkle(FishingCatchCreateRequest istek) => _calistir(
    () async {
      final av = await _depo.avEkle(anahtar.tayfaId, anahtar.etkinlikId, istek);
      if (!ref.mounted) return;
      ref.read(avGunluguProvider(anahtar).notifier).eklendi(av);
    },
    yenile: false,
  );

  /// Av günlüğünden av çıkarır.
  Future<Object?> avCikar(String avId) => _calistir(() async {
    await _depo.avCikar(anahtar.tayfaId, anahtar.etkinlikId, avId);
    if (!ref.mounted) return;
    ref.read(avGunluguProvider(anahtar).notifier).cikarildi(avId);
  }, yenile: false);

  /// Organizatör düzeltmesi: [kullaniciId]'nin katılımını ekler ([ekle])
  /// ya da kaldırır. Katılımcı listeleri ardından yeniden okunur.
  Future<Object?> katilimDuzelt(String kullaniciId, {required bool ekle}) =>
      _calistir(() async {
        await _depo.katilimDuzelt(
          anahtar.tayfaId,
          anahtar.etkinlikId,
          kullaniciId,
          ekle: ekle,
        );
        if (!ref.mounted) return;
        ref.invalidate(katilimcilarProvider);
      });

  Future<Object?> _calistir(
    Future<void> Function() islem, {
    bool yenile = true,
  }) async {
    if (state) return null;
    state = true;
    try {
      await islem();
      if (yenile && ref.mounted) unawaited(_detay.sessizceYenile());
      return null;
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      return hata;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

CampDetails _kampKopyasi(CampDetails? kamp, List<CampItem> malzemeler) =>
    CampDetails(
      siteName: kamp?.siteName,
      hasWater: kamp?.hasWater,
      hasToilet: kamp?.hasToilet,
      notes: kamp?.notes,
      items: malzemeler,
    );

/// Türe özel araçların işlemleri; detay ekranı kapanınca bırakılır.
final aracEylemProvider = NotifierProvider.autoDispose
    .family<AracEylemNotifier, bool, EtkinlikAnahtari>(
      AracEylemNotifier.new,
      name: 'aracEylemProvider',
    );

/// Yürüyüş yoklamasının ekrandaki durumu.
@immutable
final class YuruyusDurumu {
  const YuruyusDurumu({this.kayit, this.suruyor = false});

  /// Sunucunun döndürdüğü yoklama (çıkış ve varsa dönüş); bu ekranda
  /// henüz bildirilmediyse `null`. Yalnızca bellektedir.
  final HikeCheckin? kayit;

  /// "Çıktım" ya da "Döndüm" gönderiliyor.
  final bool suruyor;
}

/// Yürüyüş yoklaması (ADR-0015 §6): "Çıktım" (`hike-start`, katılım sayılır)
/// ve "Döndüm" (`hike-return`). Dönmeme alarmı sunucudadır.
///
/// Sözleşmede yoklamayı okuyan uç yoktur; tekrar gönderim ilk çıkışı ya da
/// dönüşü döndürdüğü için düğmeye yeniden basmak güvenlidir.
class YuruyusNotifier extends Notifier<YuruyusDurumu> {
  YuruyusNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  YuruyusDurumu build() => const YuruyusDurumu();

  /// "Çıktım". Katılım doğrulanmış gösterilir.
  Future<Object?> cik() => _gonder(() async {
    final kayit = await ref
        .read(etkinlikDeposuProvider)
        .yuruyuseCik(anahtar.tayfaId, anahtar.etkinlikId);
    if (!ref.mounted) return kayit;
    final detay = ref.read(etkinlikDetayProvider(anahtar).notifier);
    final etkinlik = ref.read(etkinlikDetayProvider(anahtar)).value;
    if (etkinlik != null) {
      detay.guncelle(
        etkinlikKopyasi(etkinlik, katilim: AttendanceStatus.attended),
      );
    }
    ref.invalidate(katilimcilarProvider);
    unawaited(detay.sessizceYenile());
    return kayit;
  });

  /// "Döndüm".
  Future<Object?> don() => _gonder(
    () => ref
        .read(etkinlikDeposuProvider)
        .yuruyustenDon(anahtar.tayfaId, anahtar.etkinlikId),
  );

  Future<Object?> _gonder(Future<HikeCheckin> Function() islem) async {
    if (state.suruyor) return null;
    final onceki = state.kayit;
    state = YuruyusDurumu(kayit: onceki, suruyor: true);
    try {
      final kayit = await islem();
      if (ref.mounted) state = YuruyusDurumu(kayit: kayit);
      return null;
    } on OturumYok {
      if (ref.mounted) {
        state = YuruyusDurumu(kayit: onceki);
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      if (ref.mounted) state = YuruyusDurumu(kayit: onceki);
      return hata;
    }
  }
}

/// Bir yürüyüşün yoklaması; detay ekranı kapanınca bırakılır.
final yuruyusProvider = NotifierProvider.autoDispose
    .family<YuruyusNotifier, YuruyusDurumu, EtkinlikAnahtari>(
      YuruyusNotifier.new,
      name: 'yuruyusProvider',
    );
