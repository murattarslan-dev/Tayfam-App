import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/kesfet/application/kesfet_ortak.dart';
import 'package:tayfam/features/kesfet/data/kesfet_deposu.dart';

/// Güvenlik kişisi toleransının seçenekleri, dakika (sözleşme 15–1440;
/// 30-kesfet-ve-guvenlik, karar 13).
const List<int> toleransSecenekleri = [30, 60, 120, 240];

/// Güvenlik kişisi seçilirken varsayılan tolerans (sözleşmenin
/// varsayılanı).
const int varsayilanTolerans = 60;

/// Bir etkinlikteki güvenlik kişisi kaydı ve işlemin sürüp sürmediği.
@immutable
final class GuvenlikKisisiDurumu {
  const GuvenlikKisisiDurumu({required this.kayit, this.mesgul = false});

  /// Sunucunun son döndürdüğü kayıt; kişi seçilmemişse `contact` yoktur.
  final SafetyContact kayit;

  /// Bir işlem sürerken `true`; düğmeler pasiftir.
  final bool mesgul;

  /// Kişi seçili mi.
  bool get secili => kayit.contact != null;

  /// "Döndüm" denmiş mi.
  bool get dondu => kayit.returnedAt != null;

  /// Alarm gitmiş mi.
  bool get alarmGitti => kayit.alertSentAt != null;
}

/// Bir etkinliğin güvenlik kişisi (`…/safety-contact`; Tayfam-Api
/// ADR-0033 §10; istemci ADR-0027 §4). Güvenlik kişisi bayrağı kapalıysa
/// okuma `feature-disabled` hatasıyla biter ve kart görünmez.
///
/// Yalnızca bellektedir (ADR-0006); ekran kapanınca bırakılır. Kişinin
/// kimliği ve adı log'a yazılmaz.
class GuvenlikKisisiNotifier extends AsyncNotifier<GuvenlikKisisiDurumu> {
  GuvenlikKisisiNotifier(this.etkinlik);

  final KesfetEtkinligi etkinlik;

  @override
  Future<GuvenlikKisisiDurumu> build() async {
    oturumuDenetle(ref);
    final kayit = await ref
        .watch(kesfetDeposuProvider)
        .guvenlikKisisi(etkinlik.tayfaId, etkinlik.etkinlikId);
    return GuvenlikKisisiDurumu(kayit: kayit);
  }

  /// [kisiId]'yi [toleransDakika] ile güvenlik kişisi yapar.
  Future<Object?> sec(String kisiId, {required int toleransDakika}) => _islem(
    (depo) => depo.guvenlikKisisiSec(
      etkinlik.tayfaId,
      etkinlik.etkinlikId,
      kisiId: kisiId,
      toleransDakika: toleransDakika,
    ),
  );

  /// Güvenlik kişisini kaldırır (bayraksız; alarmdan sonra sunucu
  /// reddeder).
  Future<Object?> kaldir() => _islem((depo) async {
    await depo.guvenlikKisisiniKaldir(etkinlik.tayfaId, etkinlik.etkinlikId);
    return const SafetyContact(graceMinutes: 0);
  });

  /// "Döndüm" (bayraksız); alarm durur.
  Future<Object?> dondum() =>
      _islem((depo) => depo.dondum(etkinlik.tayfaId, etkinlik.etkinlikId));

  Future<Object?> _islem(
    Future<SafetyContact> Function(KesfetDeposu depo) islem,
  ) async {
    final simdiki = state.value;
    if (simdiki == null || simdiki.mesgul) return null;
    state = AsyncData(GuvenlikKisisiDurumu(kayit: simdiki.kayit, mesgul: true));
    SafetyContact? yeni;
    final hata = await kesfetIslemi(ref, () async {
      yeni = await islem(ref.read(kesfetDeposuProvider));
    });
    if (ref.mounted) {
      state = AsyncData(GuvenlikKisisiDurumu(kayit: yeni ?? simdiki.kayit));
    }
    return hata;
  }
}

/// Etkinlik detayındaki güvenlik kişisi.
final guvenlikKisisiProvider = AsyncNotifierProvider.autoDispose
    .family<GuvenlikKisisiNotifier, GuvenlikKisisiDurumu, KesfetEtkinligi>(
      GuvenlikKisisiNotifier.new,
      name: 'guvenlikKisisiProvider',
      retry: yenidenDenemeYok,
    );

/// Güvenlik kişisi adayları: kabul edilmiş arkadaşlar (ilk sayfa, en çok
/// 100). Seçme sayfası açıkken yaşar.
class GuvenlikAdaylariNotifier extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    oturumuDenetle(ref);
    final arkadaslar = await ref.watch(kesfetDeposuProvider).arkadaslar();
    return [
      for (final a in arkadaslar)
        if (a.state == FriendState.friends) a,
    ];
  }
}

/// Güvenlik kişisi adayları.
final guvenlikAdaylariProvider =
    AsyncNotifierProvider.autoDispose<GuvenlikAdaylariNotifier, List<Friend>>(
      GuvenlikAdaylariNotifier.new,
      name: 'guvenlikAdaylariProvider',
      retry: yenidenDenemeYok,
    );

/// "Her şey yolunda mıydı?" cevabı ve işlemin sürüp sürmediği.
@immutable
final class GeriBildirimDurumu {
  const GeriBildirimDurumu({this.cevap, this.mesgul = false});

  /// Kaydedilmiş cevap; yoksa `null`.
  final EventFeedbackAnswer? cevap;

  /// Kayıt sürerken `true`.
  final bool mesgul;
}

/// Etkinlik sonrası "Her şey yolunda mıydı?" (`…/feedback`; Tayfam-Api
/// ADR-0033 §9). Keşfet bayrağı kapalıysa okuma `feature-disabled` ile
/// biter ve kart görünmez. Cevap yalnızca kişinin kendisine görünür;
/// log'a yazılmaz.
class GeriBildirimNotifier extends AsyncNotifier<GeriBildirimDurumu> {
  GeriBildirimNotifier(this.etkinlik);

  final KesfetEtkinligi etkinlik;

  @override
  Future<GeriBildirimDurumu> build() async {
    oturumuDenetle(ref);
    final kayit = await ref
        .watch(kesfetDeposuProvider)
        .geriBildirim(etkinlik.tayfaId, etkinlik.etkinlikId);
    return GeriBildirimDurumu(cevap: kayit.answer);
  }

  /// [cevap]'ı kaydeder. Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> ver(EventFeedbackInputAnswer cevap) async {
    final simdiki = state.value;
    if (simdiki == null || simdiki.mesgul) return null;
    state = AsyncData(GeriBildirimDurumu(cevap: simdiki.cevap, mesgul: true));
    EventFeedbackAnswer? yeni;
    final hata = await kesfetIslemi(ref, () async {
      final kayit = await ref
          .read(kesfetDeposuProvider)
          .geriBildirimVer(etkinlik.tayfaId, etkinlik.etkinlikId, cevap);
      yeni = kayit.answer;
    });
    if (ref.mounted) {
      state = AsyncData(
        GeriBildirimDurumu(cevap: hata == null ? yeni : simdiki.cevap),
      );
    }
    return hata;
  }
}

/// Etkinlik detayındaki geri bildirim.
final geriBildirimProvider = AsyncNotifierProvider.autoDispose
    .family<GeriBildirimNotifier, GeriBildirimDurumu, KesfetEtkinligi>(
      GeriBildirimNotifier.new,
      name: 'geriBildirimProvider',
      retry: yenidenDenemeYok,
    );

/// Kullanıcıyı güvenlik kişisi seçenlerin paylaşımları (`GET
/// /v1/me/safety-shares`; Tayfam-Api ADR-0033 §10). Yalnızca en az bilgi:
/// kim, saat aralığı, durum. Bayrak kapalıysa `feature-disabled`.
class GuvenlikPaylasimlariNotifier extends AsyncNotifier<List<SafetyShare>> {
  @override
  Future<List<SafetyShare>> build() {
    oturumuDenetle(ref);
    return ref.watch(kesfetDeposuProvider).paylasimlar();
  }
}

/// Güvenlik kişisi olunan paylaşımlar; ekran ya da profil girişi açıkken
/// yaşar.
final guvenlikPaylasimlariProvider =
    AsyncNotifierProvider.autoDispose<
      GuvenlikPaylasimlariNotifier,
      List<SafetyShare>
    >(
      GuvenlikPaylasimlariNotifier.new,
      name: 'guvenlikPaylasimlariProvider',
      retry: yenidenDenemeYok,
    );

/// Tayfanın Keşfet ayarı ve kaydın sürüp sürmediği.
@immutable
final class TayfaKesfetDurumu {
  const TayfaKesfetDurumu({required this.ayar, this.mesgul = false});

  final TayfaDiscover ayar;
  final bool mesgul;
}

/// Tayfa ayarlarındaki "Keşfet'te göster" (`/v1/tayfas/{id}/discover`;
/// Tayfam-Api ADR-0033 §15). Bayraktan bağımsızdır. Yöneticiye özeldir;
/// okuma 403 ya da anlık tayfada `tayfa-not-found` ile biterse bölüm
/// görünmez (yetki sunucuda; kesin kural 5).
class TayfaKesfetNotifier extends AsyncNotifier<TayfaKesfetDurumu> {
  TayfaKesfetNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<TayfaKesfetDurumu> build() async {
    oturumuDenetle(ref);
    final ayar = await ref.watch(kesfetDeposuProvider).tayfaAyari(tayfaId);
    return TayfaKesfetDurumu(ayar: ayar);
  }

  /// Keşfet isteğini [acik] yapar. Başarıda `null`, aksi halde gösterilecek
  /// hata (5 üyeden azsa `discover-too-few-members`).
  Future<Object?> ayarla({required bool acik}) async {
    final simdiki = state.value;
    if (simdiki == null || simdiki.mesgul) return null;
    state = AsyncData(TayfaKesfetDurumu(ayar: simdiki.ayar, mesgul: true));
    TayfaDiscover? yeni;
    final hata = await kesfetIslemi(ref, () async {
      yeni = await ref
          .read(kesfetDeposuProvider)
          .tayfaAyariniDegistir(tayfaId, acik: acik);
    });
    if (ref.mounted) {
      state = AsyncData(TayfaKesfetDurumu(ayar: yeni ?? simdiki.ayar));
    }
    return hata;
  }

  /// İstatistik vitrinini [goster] yapar (#250; Tayfam-Api ADR-0026 §3).
  /// Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> vitriniAyarla({required bool goster}) async {
    final simdiki = state.value;
    if (simdiki == null || simdiki.mesgul) return null;
    state = AsyncData(TayfaKesfetDurumu(ayar: simdiki.ayar, mesgul: true));
    TayfaDiscover? yeni;
    final hata = await kesfetIslemi(ref, () async {
      yeni = await ref
          .read(kesfetDeposuProvider)
          .vitrinAyariniDegistir(tayfaId, goster: goster);
    });
    if (ref.mounted) {
      state = AsyncData(TayfaKesfetDurumu(ayar: yeni ?? simdiki.ayar));
    }
    return hata;
  }
}

/// Tayfa ayarlarındaki Keşfet bölümü.
final tayfaKesfetProvider = AsyncNotifierProvider.autoDispose
    .family<TayfaKesfetNotifier, TayfaKesfetDurumu, String>(
      TayfaKesfetNotifier.new,
      name: 'tayfaKesfetProvider',
      retry: yenidenDenemeYok,
    );
