import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_deposu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

/// Uygulama ön plana dönünce katalog en fazla bu sıklıkta yeniden çekilir
/// (ADR-0024 §1).
const Duration katalogYenilemeAraligi = Duration(hours: 1);

/// Etkinlik türü kataloğu (ADR-0024 §1).
///
/// - `GET /v1/catalog` ile okunur ([gerekli]): kabuk açılınca (oturum
///   açıldıktan sonra; `KatalogYenileyici`) ve kataloğa ihtiyaç duyan bir
///   ekran açılınca. Okunana kadar değer `null`'dır. Yanıt **yalnızca
///   bellekte** tutulur (ADR-0006).
/// - Yeniden çekilir: uygulama ön plana dönünce en fazla saatte bir
///   ([onPlanaDondu]) ve tanınmayan bir tür anahtarıyla karşılaşınca, her
///   anahtar için bir kez ([bilinmeyenTur]). Yeniden çekerken eldeki
///   sürüm `If-None-Match` ile gider; `304` gelirse eldeki katalog kalır.
/// - Katalog gelmeden ekranlar çalışır: tür adı yerine "Etkinlik", ikon
///   yerine genel ikon gösterilir. Yenileme hatasında eldeki katalog
///   korunur.
/// - Katalog herkese aynıdır ve kişisel veri taşımaz; bu yüzden oturum
///   değişince sıfırlanmaz. İçeriği yine de log'a yazılmaz.
/// - Kendiliğinden istek atmaz: izlemek okumayı başlatmaz (çipler ve
///   kartlar yalnızca eldekini gösterir).
class KatalogNotifier extends Notifier<AsyncValue<Katalog?>> {
  DateTime? _sonOkuma;
  final Set<String> _arananTurler = {};
  Future<void>? _suren;

  @override
  AsyncValue<Katalog?> build() => const AsyncData(null);

  /// Katalog elde yoksa okur (süren bir okuma varsa ona katılır); eldeyse
  /// bir şey yapmaz.
  Future<void> gerekli() async {
    if (!ref.mounted || state.value != null) return;
    await yenile();
  }

  /// Kataloğu yeniden çeker. Süren bir çekme varsa ona katılır. Hata
  /// fırlatmaz: elde katalog varsa o kalır, yoksa durum hataya döner
  /// (tür seçimi "Tekrar dene" gösterir).
  Future<void> yenile() => _suren ??= _yenile().whenComplete(() {
    _suren = null;
  });

  Future<void> _yenile() async {
    if (!ref.mounted) return;
    final eldeki = state.value;
    if (eldeki == null) state = const AsyncLoading();
    try {
      final yeni = await ref
          .read(katalogDeposuProvider)
          .oku(etag: eldeki?.etag);
      if (!ref.mounted) return;
      _sonOkuma = ref.read(simdiProvider)();
      state = AsyncData(yeni == null ? eldeki : Katalog(yeni));
    } on Exception catch (hata, iz) {
      if (ref.mounted && eldeki == null) state = AsyncError(hata, iz);
    }
  }

  /// Uygulama ön plana döndü: son okumanın üstünden
  /// [katalogYenilemeAraligi] geçtiyse (ya da katalog hiç okunamadıysa)
  /// yeniden çeker.
  Future<void> onPlanaDondu() async {
    if (!ref.mounted) return;
    final son = _sonOkuma;
    if (son != null &&
        ref.read(simdiProvider)().difference(son) < katalogYenilemeAraligi) {
      return;
    }
    await yenile();
  }

  /// Katalogda olmayan bir tür anahtarı görüldü (sunucu yeni bir tür
  /// eklemiş olabilir): her anahtar için bir kez yeniden çeker. Katalog
  /// henüz gelmediyse ya da anahtar biçimsizse bir şey yapmaz.
  Future<void> bilinmeyenTur(String anahtar) async {
    if (!ref.mounted) return;
    final eldeki = state.value;
    if (eldeki == null ||
        eldeki.tur(anahtar) != null ||
        !katalogAnahtariMi(anahtar) ||
        !_arananTurler.add(anahtar)) {
      return;
    }
    await yenile();
  }
}

/// Uygulama boyunca yaşayan katalog (açıkça kalıcı: `autoDispose` değil;
/// ADR-0001 kural 4).
final katalogProvider = NotifierProvider<KatalogNotifier, AsyncValue<Katalog?>>(
  KatalogNotifier.new,
  name: 'katalogProvider',
);

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Bir tür sürümünün anahtarı: tür anahtarı ve sürümü (etkinliğin `type`
/// ve `type_version` alanları).
typedef TurSurumu = ({String tur, int surum});

/// Bir etkinliğin oluşturulduğu tür sürümü (ADR-0024 §1).
///
/// Güncel katalogdaki sürüm aynıysa o kullanılır; değilse (tür sonradan
/// değişti ya da emekliye ayrıldı) sürüm sunucudan çekilir ve uygulama
/// açıkken bellekte kalır (bir tür sürümü hiç değişmez). Bilinmeyen tür
/// ya da sürümde (`catalog-type-not-found`) `null`'dır. Anahtar girdi
/// kabul edilir: biçimi geçersizse istek atılmaz.
class TurSurumuNotifier extends AsyncNotifier<CatalogEventType?> {
  TurSurumuNotifier(this.anahtar);

  final TurSurumu anahtar;

  @override
  Future<CatalogEventType?> build() async {
    final guncel = ref.watch(
      katalogProvider.select((k) => k.value?.tur(anahtar.tur)),
    );
    if (guncel != null && guncel.version == anahtar.surum) return guncel;
    if (!katalogAnahtariMi(anahtar.tur) || anahtar.surum < 1) return null;
    try {
      final surum = await ref
          .read(katalogDeposuProvider)
          .surumOku(anahtar.tur, anahtar.surum);
      // Sunucunun cevabı da girdidir: istenen tür ve sürüm olmalı.
      if (surum.key != anahtar.tur || surum.version != anahtar.surum) {
        return null;
      }
      return surum;
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.catalogTypeNotFound) return null;
      rethrow;
    }
  }
}

/// Tür sürümleri; oturum boyunca bellekte (açıkça kalıcı). Hata otomatik
/// yeniden denenmez.
final turSurumuProvider =
    AsyncNotifierProvider.family<
      TurSurumuNotifier,
      CatalogEventType?,
      TurSurumu
    >(
      TurSurumuNotifier.new,
      name: 'turSurumuProvider',
      retry: _yenidenDenemeYok,
    );
