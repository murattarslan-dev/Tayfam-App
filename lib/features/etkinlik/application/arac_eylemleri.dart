import 'dart:async';

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

/// Türe özel araçların detay ekranındaki işlemleri (ADR-0015 §6): av
/// günlüğü ve organizatör düzeltmesi. Konvoy araçları `vehicles` (#228),
/// kamp malzemeleri `checklist` bileşenine (#229) taşındı.
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

/// Türe özel araçların işlemleri; detay ekranı kapanınca bırakılır.
final aracEylemProvider = NotifierProvider.autoDispose
    .family<AracEylemNotifier, bool, EtkinlikAnahtari>(
      AracEylemNotifier.new,
      name: 'aracEylemProvider',
    );
