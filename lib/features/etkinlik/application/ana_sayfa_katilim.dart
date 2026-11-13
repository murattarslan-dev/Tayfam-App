import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Ana sayfadaki "Sıradaki" etkinlik kartında listeden seçilen ilk
/// etkinlik: iptal edilmemiş ve bitmemiş olan en yakın etkinlik
/// (liste sunucunun sırasıyla başlangıca göredir). Yoksa `null`.
Event? siradakiEtkinlik(List<Event> etkinlikler, DateTime simdi) {
  for (final e in etkinlikler) {
    if (katilimAcik(e, simdi)) return e;
  }
  return null;
}

/// Ana sayfadaki katılım cevabı (2026-11-13 yeniden tasarım; ADR-0015
/// Notlar): "Geliyorum", "Belki", "Gelmiyorum" detaya gitmeden verilir.
///
/// Mantık etkinlik detayındakiyle aynıdır (`EtkinlikEylemNotifier.katil`):
/// sunucunun kaydettiği cevap (dolu etkinlikte bekleme listesi) ve sayıların
/// yerel tahmini hemen listeye yansır, ardından liste sunucudan yeniden
/// okunur. Durum, cevabı gönderilen etkinliğin kimliğidir (yoksa `null`);
/// aynı anda tek işlem yapılır. Yetki kararı sunucudadır
/// (`event-cancelled`, `event-ended`, `permission-denied`).
class AnaSayfaKatilimNotifier extends Notifier<String?> {
  AnaSayfaKatilimNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  String? build() => null;

  /// [etkinlik] için [durum] cevabını verir. Başarıda `null`, aksi halde
  /// gösterilecek hata.
  Future<Object?> katil(Event etkinlik, RsvpRequestStatus durum) async {
    if (state != null || durum == RsvpRequestStatus.unknown) return null;
    state = etkinlik.id;
    try {
      final kaydedilen = await ref
          .read(etkinlikDeposuProvider)
          .katilim(tayfaId, etkinlik.id, durum);
      if (!ref.mounted) return null;
      final liste = ref.read(etkinlikListesiProvider(tayfaId).notifier);
      final guncel = _bul(etkinlik.id) ?? etkinlik;
      liste.yansit(katilimiUygula(guncel, kaydedilen));
      ref.invalidate(katilimcilarProvider);
      unawaited(liste.yenile());
      return null;
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      return hata;
    } finally {
      if (ref.mounted) state = null;
    }
  }

  Event? _bul(String etkinlikId) {
    final liste = ref.read(etkinlikListesiProvider(tayfaId)).value?.ogeler;
    if (liste == null) return null;
    for (final e in liste) {
      if (e.id == etkinlikId) return e;
    }
    return null;
  }
}

/// Bir tayfanın ana sayfasındaki katılım işlemi; ana sayfa kapanınca
/// bırakılır.
final anaSayfaKatilimProvider = NotifierProvider.autoDispose
    .family<AnaSayfaKatilimNotifier, String?, String>(
      AnaSayfaKatilimNotifier.new,
      name: 'anaSayfaKatilimProvider',
    );
