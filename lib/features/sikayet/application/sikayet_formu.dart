import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/sikayet/application/sikayet_hedefi.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';

/// Şikâyet gönderiminin durumu.
@immutable
final class SikayetGonderimi {
  const SikayetGonderimi({
    this.gonderiliyor = false,
    this.hata,
    this.gonderildi = false,
  });

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son denemenin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Şikâyet sunucuya ulaştı (yeni ya da aynı hedefin önceki şikâyeti).
  final bool gonderildi;
}

/// Bir hedefin şikâyet formu (ADR-0018 §8). Aynı hedefin ikinci
/// şikâyetini sunucu yeni kayıt açmadan karşılar (`200`); istemci ikisini
/// ayırmaz, "iletildi" der.
///
/// Hedef kimliği girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez. Birebir mesaj metni boşsa gönderilmez (sözleşme:
/// `evidence_text` zorunlu). Metin ve not yalnızca istek gövdesinde gider;
/// saklanmaz, log'a yazılmaz.
class SikayetFormuNotifier extends Notifier<SikayetGonderimi> {
  SikayetFormuNotifier(this.hedef);

  /// Şikâyet edilen şey.
  final SikayetHedefi hedef;

  @override
  SikayetGonderimi build() => const SikayetGonderimi();

  /// [gerekce] ve isteğe bağlı [not] ile gönderir. Başarıda `true`.
  Future<bool> gonder(ReportReason gerekce, String not) async {
    if (state.gonderiliyor || state.gonderildi) return state.gonderildi;
    state = const SikayetGonderimi(gonderiliyor: true);
    final depo = ref.read(sikayetDeposuProvider);
    try {
      final tayfaId = hedef.tayfaId;
      if (!uuidBicimindeMi(hedef.id) ||
          (tayfaId != null && !uuidBicimindeMi(tayfaId)) ||
          (hedef.mesajMetni != null &&
              kanitMetni(hedef.mesajMetni!) == null)) {
        throw const GecersizHedef();
      }
      final istek = hedef.istek(gerekce, not);
      if (tayfaId == null) {
        await depo.birebirMesajiSikayetEt(istek);
      } else {
        await depo.tayfadaSikayetEt(tayfaId, istek);
      }
      if (!ref.mounted) return true;
      state = const SikayetGonderimi(gonderildi: true);
      return true;
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
        state = SikayetGonderimi(hata: hata);
      }
      return false;
    } on Exception catch (hata) {
      if (ref.mounted) state = SikayetGonderimi(hata: hata);
      return false;
    }
  }
}

/// Hedef kimliği biçimsiz ya da birebir mesaj metni boş; istek
/// gönderilmedi. Genel hata metniyle gösterilir.
final class GecersizHedef implements Exception {
  const GecersizHedef();

  @override
  String toString() => 'GecersizHedef';
}

/// Bir hedefin şikâyet formu; sayfa kapanınca atılır.
final sikayetFormuProvider = NotifierProvider.autoDispose
    .family<SikayetFormuNotifier, SikayetGonderimi, SikayetHedefi>(
      SikayetFormuNotifier.new,
      name: 'sikayetFormuProvider',
    );
