import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Bir etkinliğin bir oylama bileşeni: bileşen uçlarındaki
/// `{component_key}`.
typedef OylamaKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Sözleşmedeki serbest seçenek etiketinin sınırları (kırpıldıktan ve iç
/// boşluklar teke indirildikten sonra).
const int oylamaEtiketiEnAz = 1;
const int oylamaEtiketiEnCok = 100;

final RegExp _boslar = RegExp(r'\s+');

/// Sunucunun yaptığı gibi etiketi kırpar ve iç boşlukları teke indirir.
String oylamaEtiketiniDuzenle(String metin) =>
    metin.trim().replaceAll(_boslar, ' ');

/// Formdaki etiket; boşsa ya da sınırı aşıyorsa `null` (form hatayı
/// gösterir). Denetim ve biçim karakterlerini sunucu reddeder
/// (`invalid-request`); hata formda gösterilir.
String? oylamaEtiketi(String metin) {
  final etiket = oylamaEtiketiniDuzenle(metin);
  final uzunluk = etiket.runes.length;
  if (uzunluk < oylamaEtiketiEnAz || uzunluk > oylamaEtiketiEnCok) {
    return null;
  }
  return etiket;
}

/// Kaynak uygulamanın bu sürümünce tanınıyor mu.
bool oylamaKaynagiTanindi(EventVote oylama) =>
    oylama.source != EventVoteSource.unknown;

/// Seçeneğin arkasındaki kişi oturumdaki kullanıcı mı (kendine, kendi
/// aracına, kendi fotoğrafına oy verilmez). Yalnızca arayüzü sadeleştirir;
/// karar sunucunundur (`vote-own-option`).
bool oylamaKendiSecenegim(EventVoteOption secenek, String? ben) =>
    ben != null && secenek.userId != null && secenek.userId == ben;

/// Seçeneklere yeni serbest seçenek eklenebilir mi (sınır dolmadı).
bool oylamaSecenekEklenebilir(EventVote oylama) =>
    oylama.callerCanEditOptions &&
    oylama.source == EventVoteSource.free &&
    oylama.options.length < oylama.maxOptions;

/// [kimlik]'li seçenek; yoksa `null`.
EventVoteOption? oylamaSecenegi(EventVote oylama, String? kimlik) {
  if (kimlik == null) return null;
  for (final s in oylama.options) {
    if (s.id == kimlik) return s;
  }
  return null;
}

/// Oylamanın yeniden okunmasını gerektiren hatalar: durumu etkinlikle,
/// tür tanımıyla ya da başkasının işlemiyle (kapanış, kaldırılan seçenek)
/// değişmiş.
const Set<ProblemType> _bayatOylamaHatalari = {
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.voteClosed,
  ProblemType.voteOptionsFixed,
  ProblemType.eventItemNotFound,
  ProblemType.eventLimit,
};

/// Oylama bileşeni (`GET …/components/{component_key}/vote`; Tayfam-Api
/// #254), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır (ADR-0024 §5):
/// bileşen değişince REST'ten yeniden okunur; katılım cevabın değişince de
/// (oy hakkı `going` cevabına bağlıdır).
///
/// Oy gizlidir: yanıtta kimin neye oy verdiği yoktur, yalnızca kendi oyun.
/// Durum yalnızca bellekte tutulur ve loglanmaz (ADR-0006). Yazan her uç
/// oylamanın güncel halini döner; durum onunla değişir. Yetki sunucudadır;
/// istemci `caller_can_*` alanlarına göre düğmeleri sadeleştirir (kesin
/// kural 5).
class OylamaNotifier extends AsyncNotifier<EventVote> {
  OylamaNotifier(this.kimlik);

  final OylamaKimligi kimlik;

  @override
  Future<EventVote> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(
      etkinlikDetayProvider(etkinlik)
          .select((d) => (d.value?.status, d.value?.callerRsvp)),
    );
    return ref
        .read(etkinlikDeposuProvider)
        .oylama(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// [secenekId]'ye oy verir (önceki oyun yerine geçer).
  Future<Object?> oyVer(String secenekId) => _yaz(
    (d) =>
        d.oyVer(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, secenekId),
  );

  /// Oyunu geri alır.
  Future<Object?> oyuGeriAl() => _yaz(
    (d) => d.oyuGeriAl(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar),
  );

  /// Serbest seçenek ekler.
  Future<Object?> secenekEkle(String etiket) => _yaz(
    (d) => d.oylamaSecenegiEkle(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      etiket,
    ),
  );

  /// Serbest seçeneği (ve ona verilen oyları) kaldırır.
  Future<Object?> secenegiKaldir(String secenekId) => _yaz(
    (d) => d.oylamaSeceneginiKaldir(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      secenekId,
    ),
  );

  /// Oylamayı kapatır; geri alınmaz.
  Future<Object?> kapat() => _yaz(
    (d) => d.oylamayiKapat(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Oylama bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(
    Future<EventVote> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final oylama = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(oylama);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatOylamaHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir oylama bileşeninin durumu. Hata otomatik yeniden denenmez.
final oylamaProvider = AsyncNotifierProvider.autoDispose
    .family<OylamaNotifier, EventVote, OylamaKimligi>(
      OylamaNotifier.new,
      name: 'oylamaProvider',
      retry: yenidenDenemeYok,
    );
