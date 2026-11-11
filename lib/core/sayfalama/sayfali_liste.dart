import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sayfalı bir liste ucunun bir sayfası: öğeler ve sonraki sayfanın opak
/// token'ı (`next_page_token`; son sayfada `null`).
typedef Sayfa<T> = ({List<T> ogeler, String? sonraki});

/// Sayfalı okunan bir listenin bellekteki durumu (ADR-0006: önbellek
/// yalnızca bellektedir).
///
/// Sayfa token'ı opaktır: ayrıştırılmaz, üretilmez; yalnızca aynı uca geri
/// gönderilir (CLAUDE.md "Sayfalama").
@immutable
final class SayfaliListe<T> {
  const SayfaliListe({
    required this.ogeler,
    this.sonrakiSayfa,
    this.dahaYukleniyor = false,
    this.dahaHatasi,
  });

  /// Okunan öğeler, sunucunun sırasıyla.
  final List<T> ogeler;

  /// Sonraki sayfanın token'ı; son sayfadaysa `null`.
  final String? sonrakiSayfa;

  /// Sonraki sayfa okunuyor.
  final bool dahaYukleniyor;

  /// Sonraki sayfa okunamadıysa hatası; metni ortak eşlemeden gelir.
  final Object? dahaHatasi;

  /// Okunacak başka sayfa var mı.
  bool get dahaVar => sonrakiSayfa != null;

  SayfaliListe<T> _degistir({
    List<T>? ogeler,
    bool dahaYukleniyor = false,
    Object? dahaHatasi,
  }) => SayfaliListe(
    ogeler: ogeler ?? this.ogeler,
    sonrakiSayfa: sonrakiSayfa,
    dahaYukleniyor: dahaYukleniyor,
    dahaHatasi: dahaHatasi,
  );
}

/// Sayfalı bir liste ucunu okuyan `AsyncNotifier`'ların ortak tabanı.
///
/// Alt sınıf [sayfaGetir] ve [kimlik]'i yazar; `build`'de [ilkSayfayiOku]'yu
/// döndürür. [dahaFazla] sonraki sayfayı ekler, [yenile] ilk sayfayı
/// yeniden okur. Sunucu hatalı olarak daha önce görülmüş bir token
/// döndürse bile sonsuz döngü olmaz: o token son sayfa sayılır.
abstract class SayfaliListeNotifier<T> extends AsyncNotifier<SayfaliListe<T>> {
  final Set<String> _gorulen = {};

  /// [sayfaToken] sayfasını okur; ilk sayfa için `null`.
  @protected
  Future<Sayfa<T>> sayfaGetir(String? sayfaToken);

  /// Öğenin kimliği; sayfalar arasında yinelenen öğe bir kez gösterilir.
  @protected
  String kimlik(T oge);

  /// İlk sayfayı okur; `build`'den çağrılır.
  @protected
  Future<SayfaliListe<T>> ilkSayfayiOku() async {
    _gorulen.clear();
    final sayfa = await sayfaGetir(null);
    return SayfaliListe(
      ogeler: List.unmodifiable(_tekil(<T>[], sayfa.ogeler)),
      sonrakiSayfa: _sonraki(sayfa.sonraki),
    );
  }

  /// Sonraki sayfayı okuyup listenin sonuna ekler. Okuma sürerken, liste
  /// yokken ya da son sayfadayken bir şey yapmaz. Okunamazsa eldeki liste
  /// kalır ve [SayfaliListe.dahaHatasi] dolar.
  Future<void> dahaFazla() async {
    final mevcut = state.value;
    if (mevcut == null || mevcut.dahaYukleniyor) return;
    final token = mevcut.sonrakiSayfa;
    if (token == null) return;
    state = AsyncData(mevcut._degistir(dahaYukleniyor: true));
    try {
      final sayfa = await sayfaGetir(token);
      if (!ref.mounted) return;
      final simdiki = state.value;
      // Bu sırada liste yenilendiyse eski sayfa eklenmez.
      if (simdiki == null || !simdiki.dahaYukleniyor) return;
      state = AsyncData(
        SayfaliListe(
          ogeler: List.unmodifiable(_tekil(simdiki.ogeler, sayfa.ogeler)),
          sonrakiSayfa: _sonraki(sayfa.sonraki),
        ),
      );
    } on Exception catch (hata) {
      if (!ref.mounted) return;
      final simdiki = state.value;
      if (simdiki == null || !simdiki.dahaYukleniyor) return;
      state = AsyncData(simdiki._degistir(dahaHatasi: hata));
    }
  }

  /// İlk sayfayı yeniden okur. Okunamazsa eldeki liste kalır; elde liste
  /// yoksa hata gösterilir. Başarıda `null`, aksi halde hata.
  Future<Object?> yenile() async {
    try {
      final yeni = await ilkSayfayiOku();
      if (ref.mounted) state = AsyncData(yeni);
      return null;
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
      return hata;
    }
  }

  /// Bellekteki öğeleri [degistir] ile değiştirir (oluşturma, düzenleme,
  /// silme sonrasında sunucunun cevabını yansıtmak için). Liste yoksa bir
  /// şey yapmaz.
  @protected
  void ogeleriDegistir(List<T> Function(List<T> ogeler) degistir) {
    final mevcut = state.value;
    if (mevcut == null) return;
    state = AsyncData(
      mevcut._degistir(
        ogeler: List.unmodifiable(degistir(mevcut.ogeler)),
        dahaYukleniyor: mevcut.dahaYukleniyor,
        dahaHatasi: mevcut.dahaHatasi,
      ),
    );
  }

  String? _sonraki(String? token) {
    if (token == null || token.isEmpty || !_gorulen.add(token)) return null;
    return token;
  }

  List<T> _tekil(List<T> eski, List<T> yeni) {
    final gorulen = {for (final o in eski) kimlik(o)};
    return [
      ...eski,
      for (final o in yeni)
        if (gorulen.add(kimlik(o))) o,
    ];
  }
}
