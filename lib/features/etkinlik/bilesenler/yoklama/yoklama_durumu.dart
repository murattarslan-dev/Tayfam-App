import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Bir etkinliğin bir yoklama bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef YoklamaKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// "Çıktım" görünür mü: henüz çıkılmamış, cevap "Geliyorum" ve varış
/// penceresi açık (başlangıçtan 30 dakika önce ile bitiş arası, iptal
/// edilmemiş). Kolaylıktır; karar sunucunundur (`event-not-going`,
/// `check-in-closed`).
bool yoklamadaCikabilir(
  EventRollCall yoklama,
  Event etkinlik,
  DateTime simdi,
) =>
    yoklama.mine == null &&
    etkinlik.callerRsvp == RsvpStatus.going &&
    varisPenceresiAcik(etkinlik, simdi);

/// "Döndüm" görünür mü: çıkılmış ve henüz dönülmemiş. Güvenlik sinyalidir;
/// bitişten sonra ve iptal edilmiş etkinlikte de görünür.
bool yoklamadanDonebilir(EventRollCall yoklama) {
  final kayit = yoklama.mine;
  return kayit != null && kayit.returnedAt == null;
}

/// Dönmeme alarmının çalacağı an: beklenen dönüş + tolerans. Alarm
/// kapalıysa ya da beklenen dönüş yazılmadıysa `null` (alarm kurulmaz).
DateTime? alarmZamani(EventRollCall yoklama) {
  final donus = yoklama.expectedReturnAt;
  if (!yoklama.alarm || donus == null) return null;
  return donus.add(Duration(minutes: yoklama.returnGraceMinutes));
}

/// [kayit] gecikmiş mi: dönmemiş ve alarm anı geçmiş. Yalnızca listede
/// vurgu içindir; bildirimi sunucu gönderir.
bool gecikti(RollCallEntry kayit, EventRollCall yoklama, DateTime simdi) {
  final alarm = alarmZamani(yoklama);
  return kayit.returnedAt == null && alarm != null && simdi.isAfter(alarm);
}

/// Yoklamanın yeniden okunmasını gerektiren hatalar: yoklama başkasının
/// işlemiyle ya da etkinliğin durumuyla değişmiş.
const Set<ProblemType> _bayatYoklamaHatalari = {
  ProblemType.hikeNotStarted,
  ProblemType.checkInClosed,
  ProblemType.eventNotGoing,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
};

/// Yoklama bileşeni (`GET …/components/{component_key}/roll-call`;
/// Tayfam-Api #242), çağıranın gördüğü haliyle: plan, kendi kaydı ve
/// yönetene herkesin kaydı. Bölüm açıkken canlıdır (ADR-0024 §5): bileşen
/// değişince ve katılım cevabı değişince REST'ten yeniden okunur.
///
/// Cihaz konumu hiçbir uçta gönderilmez (Tayfam-Api ADR-0008). Yazan her
/// uç yoklamanın güncel halini döner; durum onunla değişir. Yetki
/// sunucudadır; istemci yalnızca düğmeleri sadeleştirir (kesin kural 5).
class YoklamaNotifier extends AsyncNotifier<EventRollCall> {
  YoklamaNotifier(this.kimlik);

  final YoklamaKimligi kimlik;

  EtkinlikAnahtari get _etkinlik =>
      (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);

  @override
  Future<EventRollCall> build() {
    bilesenDegisiminiIzle(ref, _etkinlik, kimlik.anahtar);
    ref.watch(
      etkinlikDetayProvider(_etkinlik).select((d) => d.value?.callerRsvp),
    );
    return ref
        .read(etkinlikDeposuProvider)
        .yoklama(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu bölümde gösterilir.
    }
  }

  /// "Çıktım": katılım sayılır; etkinlikte katılım doğrulanmış gösterilir
  /// ve katılımcılar yeniden okunur.
  Future<Object?> cik() async {
    final hata = await _yaz(
      (d) => d.yoklamadaCik(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar),
    );
    if (hata != null || !ref.mounted) return hata;
    final detay = ref.read(etkinlikDetayProvider(_etkinlik).notifier);
    final etkinlik = ref.read(etkinlikDetayProvider(_etkinlik)).value;
    if (etkinlik != null) {
      detay.guncelle(
        etkinlikKopyasi(etkinlik, katilim: AttendanceStatus.attended),
      );
    }
    ref.invalidate(katilimcilarProvider);
    unawaited(detay.sessizceYenile());
    return null;
  }

  /// "Döndüm".
  Future<Object?> don() => _yaz(
    (d) => d.yoklamadanDon(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar),
  );

  /// Beklenen dönüşü [donus] yapar; `null` ise kaldırır (alarm kurulmaz).
  Future<Object?> donusYaz(DateTime? donus) => _yaz(
    (d) => d.beklenenDonusYaz(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      donus,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Yoklama bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(
    Future<EventRollCall> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final yoklama = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(yoklama);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatYoklamaHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir yoklama bileşeninin durumu. Hata otomatik yeniden denenmez.
final yoklamaProvider = AsyncNotifierProvider.autoDispose
    .family<YoklamaNotifier, EventRollCall, YoklamaKimligi>(
      YoklamaNotifier.new,
      name: 'yoklamaProvider',
      retry: yenidenDenemeYok,
    );
