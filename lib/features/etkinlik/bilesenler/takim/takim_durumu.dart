import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınırlar (`EventTeamsRequest`, `EventTeamsGenerateRequest`).
const int takimAdiEnCok = 40;
const int takimSayisiEnCok = 50;
const int takimSeviyeEnAz = 1;
const int takimSeviyeEnCok = 5;

/// Seviyesi gönderilmeyen katılımcının sunucuda sayıldığı seviye.
const int takimVarsayilanSeviye = 3;

/// Elle kurmada bir takımın alabileceği en çok kişi: sözleşmeye göre
/// yalnızca `team_count` ile `team_size` birlikte verilmişse sınır vardır.
int? takimKisiSiniri(EventTeams takimlar) =>
    takimlar.teamCount != null ? takimlar.teamSize : null;

/// Elle kurmada en çok takım sayısı (`team_count`; yoksa 50).
int takimSiniri(EventTeams takimlar) =>
    max(1, min(takimlar.teamCount ?? takimSayisiEnCok, takimSayisiEnCok));

/// Elle kurma formunun başlangıç taslağı: mevcut takımlar sırasıyla; takım
/// yoksa `team_count` (yoksa 2) boş takım.
List<({String ad, List<String> uyeler})> takimTaslagi(EventTeams takimlar) {
  if (takimlar.teams.isEmpty) {
    final adet = min(takimlar.teamCount ?? 2, takimSiniri(takimlar));
    return [for (var i = 0; i < adet; i++) (ad: '', uyeler: const <String>[])];
  }
  final sirali = [...takimlar.teams]
    ..sort((a, b) => a.position.compareTo(b.position));
  return [
    for (final takim in sirali) (ad: takim.name ?? '', uyeler: takim.memberIds),
  ];
}

/// Elle kurma isteği: [adlar] takımların sırasıyla adları (boş ya da
/// yalnızca boşluk: adsız), [atama] kişi → takımın sırası (0'dan),
/// [kisiSirasi] kişilerin formdaki sırası (takımdaki sıra da budur).
///
/// Kişi sınırını ([kisiSiniri]) aşan takımların sıraları döner; varsa istek
/// `null`'dır. Ad uzunluğunu alan sınırlar; son sözü sunucu söyler.
({EventTeamsRequest? istek, Set<int> dolanlar}) takimIstegi({
  required List<String> adlar,
  required Map<String, int> atama,
  required List<String> kisiSirasi,
  int? kisiSiniri,
}) {
  final uyeler = List<List<String>>.generate(adlar.length, (_) => <String>[]);
  final gorulen = <String>{};
  for (final kisi in [...kisiSirasi, ...atama.keys]) {
    if (!gorulen.add(kisi)) continue;
    final sira = atama[kisi];
    if (sira == null || sira < 0 || sira >= adlar.length) continue;
    uyeler[sira].add(kisi);
  }
  final dolanlar = <int>{
    if (kisiSiniri != null)
      for (final (sira, liste) in uyeler.indexed)
        if (liste.length > kisiSiniri) sira,
  };
  if (dolanlar.isNotEmpty) return (istek: null, dolanlar: dolanlar);
  return (
    istek: EventTeamsRequest(
      teams: [
        for (final (sira, ad) in adlar.indexed)
          EventTeamsRequestTeamsItem(
            name: ad.trim().isEmpty ? null : ad.trim(),
            memberIds: uyeler[sira],
          ),
      ],
    ),
    dolanlar: const {},
  );
}

/// Dengeli kurma isteği: yalnızca varsayılandan (3) farklı seviyeler
/// gönderilir (gönderilmeyen 3 sayılır; gereğinden fazla veri gitmez).
/// Seviyeler yalnızca formun belleğindedir; saklanmaz, önbelleğe alınmaz.
EventTeamsGenerateRequest takimSeviyeIstegi(Map<String, int> seviyeler) {
  final gidenler = [
    for (final MapEntry(key: kisi, value: seviye) in seviyeler.entries)
      if (seviye != takimVarsayilanSeviye &&
          seviye >= takimSeviyeEnAz &&
          seviye <= takimSeviyeEnCok)
        EventTeamsGenerateRequestLevelsItem(userId: kisi, level: seviye),
  ];
  return EventTeamsGenerateRequest(levels: gidenler.isEmpty ? null : gidenler);
}

/// Bir etkinliğin bir takım bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef TakimKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Formdaki kişi seçimi: etkinliğe "Geliyorum" diyenler.
KatilimcilarAnahtari takimKatilimcilari(TakimKimligi kimlik) => (
  tayfaId: kimlik.tayfaId,
  etkinlikId: kimlik.etkinlikId,
  durum: ListEventAttendeesStatus.going,
);

/// Takımların yeniden okunmasını gerektiren hatalar: takımlar, mod,
/// etkinliğin durumu ya da yetki değişmiş.
const Set<ProblemType> _bayatTakimHatalari = {
  ProblemType.teamsManual,
  ProblemType.teamsNotParticipant,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Takım kurma bileşeninin durumu (`GET …/components/{component_key}/
/// teams`; Tayfam-Api #248), çağıranın gördüğü haliyle. Bölüm açıkken
/// canlıdır (ADR-0024 §5): takımlar ya da etkinliğin durumu değişince
/// REST'ten yeniden okunur.
///
/// Yazan her uç takımların güncel halini döner; durum onunla değişir.
/// Dengeli kurmadaki seviyeler burada tutulmaz. Yetki sunucudadır; istemci
/// yalnızca düğmeleri sadeleştirir (kesin kural 5).
class TakimNotifier extends AsyncNotifier<EventTeams> {
  TakimNotifier(this.kimlik);

  final TakimKimligi kimlik;

  @override
  Future<EventTeams> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .takimlar(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Takımları elle kurar (organizatör, moderatör, yönetici).
  Future<Object?> elleKur(EventTeamsRequest istek) => _yaz(
    (d) => d.takimlariElleKur(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      istek,
    ),
  );

  /// Takımları sunucu kurar (rastgele ya da dengeli).
  Future<Object?> olustur(EventTeamsGenerateRequest istek) => _yaz(
    (d) => d.takimlariOlustur(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      istek,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Takımlar bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(
    Future<EventTeams> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final takimlar = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(takimlar);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatTakimHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir takım bileşeninin durumu. Hata otomatik yeniden denenmez.
final takimProvider = AsyncNotifierProvider.autoDispose
    .family<TakimNotifier, EventTeams, TakimKimligi>(
      TakimNotifier.new,
      name: 'takimProvider',
      retry: yenidenDenemeYok,
    );
