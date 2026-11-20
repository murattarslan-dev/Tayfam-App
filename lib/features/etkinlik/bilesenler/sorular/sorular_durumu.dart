import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınır (`EventQuestion.body`): kırpılıp iç boşlukları teke
/// indirildikten sonra 1–500 karakter.
const int soruMetniEnCok = 500;

final RegExp _boslar = RegExp(r'\s+');

/// Sunucunun yaptığı gibi metni kırpar ve iç boşlukları (satır sonu dahil)
/// teke indirir.
String soruMetniniDuzenle(String metin) =>
    metin.trim().replaceAll(_boslar, ' ');

/// Soru formu: metin düzenlenir; boşsa ya da sınırı aşıyorsa `null`
/// (form hatayı gösterir). [anonim] yalnızca bileşen izin veriyorsa
/// (`anonymous_allowed`) ve seçiliyse gönderilir. [istekKimligi] form
/// açılırken bir kez üretilir; tekrar gönderimde aynı kalır.
EventQuestionCreateRequest? soruIstegi({
  required String metin,
  required bool anonim,
  required String istekKimligi,
}) {
  final govde = soruMetniniDuzenle(metin);
  final uzunluk = govde.runes.length;
  if (uzunluk < 1 || uzunluk > soruMetniEnCok) return null;
  return EventQuestionCreateRequest(
    body: govde,
    anonymous: anonim ? true : null,
    clientRequestId: istekKimligi,
  );
}

/// Çağıranın sorduğu soru sayısı (kişi başı sınır için; anonim sorular
/// dahil, `caller_is_author`).
int kendiSorularim(EventQuestionList liste) =>
    liste.questions.where((s) => s.callerIsAuthor).length;

/// Bir etkinliğin bir soru toplama bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef SorularKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Soruların yeniden okunmasını gerektiren hatalar: soru başkasının
/// işlemiyle ya da etkinliğin durumuyla değişmiş.
const Set<ProblemType> _bayatHatalar = {
  ProblemType.eventItemNotFound,
  ProblemType.eventNotGoing,
  ProblemType.eventCancelled,
  ProblemType.eventEnded,
  ProblemType.componentFrozen,
  ProblemType.eventLimit,
};

/// Soru toplama bileşeninin soruları (`GET …/components/{component_key}/
/// questions`; Tayfam-Api #256), çağıranın gördüğü haliyle. Bölüm açıkken
/// canlıdır (ADR-0024 §5): biri soru sorunca, oy verince ya da organizatör
/// işaretleyince liste REST'ten yeniden okunur; katılım cevabın değişince
/// de (`caller_can_ask` "Geliyorum" cevabına bağlıdır).
///
/// Yazan uçlar (soru dışında) gövdesiz döner; başarıdan sonra liste
/// yeniden okunur. Anonim sorunun yazarı yanıtta yoktur, istemci de
/// tutmaz. Yetki sunucudadır (kesin kural 5).
class SorularNotifier extends AsyncNotifier<EventQuestionList> {
  SorularNotifier(this.kimlik);

  final SorularKimligi kimlik;

  @override
  Future<EventQuestionList> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(
      etkinlikDetayProvider(etkinlik).select((d) => d.value?.callerRsvp),
    );
    return ref
        .read(etkinlikDeposuProvider)
        .sorular(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Soru sorar.
  Future<Object?> sor(EventQuestionCreateRequest istek) => _yaz(
    (d) => d.soruSor(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, istek),
  );

  /// [ver] ise oy verir, değilse oyu geri alır.
  Future<Object?> oy(String soruId, {required bool ver}) => _yaz(
    (d) => d.soruyaOy(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      soruId,
      ver: ver,
    ),
  );

  /// [isaretle] ise cevaplandı işaretler, değilse işareti kaldırır.
  Future<Object?> cevaplandi(String soruId, {required bool isaretle}) => _yaz(
    (d) => d.soruCevaplandi(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      soruId,
      isaretle: isaretle,
    ),
  );

  /// Soruyu kaldırır.
  Future<Object?> kaldir(String soruId) => _yaz(
    (d) => d.soruyuKaldir(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      soruId,
    ),
  );

  /// Başarıda liste yeniden okunur ve `null` döner; değilse hata döner ve
  /// çağıranda gösterilir. Liste bayatlamışsa (soru kaldırıldı, etkinlik
  /// bitti, sınır doldu) yeniden okunur.
  Future<Object?> _yaz(Future<void> Function(EtkinlikDeposu depo) islem) async {
    try {
      await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) ref.invalidateSelf();
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatHatalar.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir soru toplama bileşeninin durumu. Hata otomatik yeniden denenmez.
final sorularProvider = AsyncNotifierProvider.autoDispose
    .family<SorularNotifier, EventQuestionList, SorularKimligi>(
      SorularNotifier.new,
      name: 'sorularProvider',
      retry: yenidenDenemeYok,
    );
