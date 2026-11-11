import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_islemleri.dart';

/// Sayfalı bir listenin durumu: okunan öğeler, sonraki sayfanın opak
/// token'ı, sonraki sayfa okunuyor mu ve son sayfa okumasının hatası.
@immutable
final class SayfaliListe<T> {
  const SayfaliListe({
    required this.ogeler,
    this.sonrakiToken,
    this.yukleniyor = false,
    this.hata,
  });

  final List<T> ogeler;

  /// Sonraki sayfanın token'ı; son sayfadaysa `null`.
  final String? sonrakiToken;

  /// Sonraki sayfa okunuyor.
  final bool yukleniyor;

  /// Sonraki sayfa okunamadıysa hatası.
  final Object? hata;

  /// Okunacak başka sayfa var mı.
  bool get dahaVar => sonrakiToken != null;
}

/// Bir sayfa okuyan fonksiyon.
typedef SayfaOkuyucu<T> =
    Future<({List<T> ogeler, String? sonraki})> Function(String? token);

/// Sayfalı listelerin ortak notifier'ı: ilk sayfa `build`'de, sonrakiler
/// [dahaFazla] ile okunur. Sunucu aynı token'ı tekrar döndürürse liste
/// orada biter (sonsuz döngü olmasın). Veri yalnızca bellektedir
/// (ADR-0006).
abstract class SayfaliNotifier<T> extends AsyncNotifier<SayfaliListe<T>> {
  final Set<String> _gorulenTokenlar = {};

  /// Bir sayfayı okur.
  Future<({List<T> ogeler, String? sonraki})> sayfaOku(String? token);

  /// Öğenin tekilliği için anahtarı.
  String anahtar(T oge);

  @override
  Future<SayfaliListe<T>> build() async {
    _gorulenTokenlar.clear();
    final sayfa = await sayfaOku(null);
    return SayfaliListe(
      ogeler: List.unmodifiable(sayfa.ogeler),
      sonrakiToken: _yeniToken(sayfa.sonraki),
    );
  }

  /// Sonraki sayfayı okur. Okuma sürerken ya da son sayfadayken bir şey
  /// yapmaz; hata listenin altında gösterilir.
  Future<void> dahaFazla() async {
    final mevcut = state.value;
    final token = mevcut?.sonrakiToken;
    if (mevcut == null || token == null || mevcut.yukleniyor) return;
    state = AsyncData(
      SayfaliListe(
        ogeler: mevcut.ogeler,
        sonrakiToken: token,
        yukleniyor: true,
      ),
    );
    try {
      final sayfa = await sayfaOku(token);
      if (!ref.mounted) return;
      final gorulen = {for (final o in mevcut.ogeler) anahtar(o)};
      state = AsyncData(
        SayfaliListe(
          ogeler: List.unmodifiable([
            ...mevcut.ogeler,
            for (final o in sayfa.ogeler)
              if (gorulen.add(anahtar(o))) o,
          ]),
          sonrakiToken: _yeniToken(sayfa.sonraki),
        ),
      );
    } on Exception catch (hata) {
      if (!ref.mounted) return;
      state = AsyncData(
        SayfaliListe(ogeler: mevcut.ogeler, sonrakiToken: token, hata: hata),
      );
    }
  }

  /// Listeyi baştan okur (aşağı çekince). Hata durumda ekranda gösterilir;
  /// burada fırlatılmaz.
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu ekranda gösterilir.
    }
  }

  String? _yeniToken(String? token) {
    if (token == null || token.isEmpty || !_gorulenTokenlar.add(token)) {
      return null;
    }
    return token;
  }
}

/// Bir tayfanın bitmemiş etkinlikleri, başlangıca göre (iptal edilenler
/// dahil; ADR-0015 §3).
class EtkinlikListesiNotifier extends SayfaliNotifier<Event> {
  EtkinlikListesiNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<({List<Event> ogeler, String? sonraki})> sayfaOku(
    String? token,
  ) async {
    final yanit = await ref
        .read(etkinlikIslemleriProvider)
        .sayfa(tayfaId, token: token);
    return (ogeler: yanit.events, sonraki: yanit.nextPageToken);
  }

  @override
  String anahtar(Event oge) => oge.id;
}

/// Etkinlik listesi ekranının sayfalı listesi. Tayfaya bağlıdır; ekran
/// kapanınca bırakılır. Hata otomatik yeniden denenmez.
final etkinlikListesiProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikListesiNotifier, SayfaliListe<Event>, String>(
      EtkinlikListesiNotifier.new,
      name: 'etkinlikListesiProvider',
      retry: yenidenDenemeYok,
    );

/// Bir etkinliğin bir cevaptaki katılımcılarının anahtarı.
typedef KatilimcilarAnahtari = ({
  String tayfaId,
  String etkinlikId,
  ListEventAttendeesStatus durum,
});

/// Bir etkinliğin bir cevaptaki katılımcıları, eskiden yeniye (bekleme
/// listesinde bekleme sırasıyla).
class KatilimcilarNotifier extends SayfaliNotifier<Attendee> {
  KatilimcilarNotifier(this.anahtarlar);

  final KatilimcilarAnahtari anahtarlar;

  @override
  Future<({List<Attendee> ogeler, String? sonraki})> sayfaOku(
    String? token,
  ) async {
    final yanit = await ref
        .read(etkinlikIslemleriProvider)
        .katilimcilar(
          anahtarlar.tayfaId,
          anahtarlar.etkinlikId,
          anahtarlar.durum,
          token: token,
        );
    return (ogeler: yanit.attendees, sonraki: yanit.nextPageToken);
  }

  @override
  String anahtar(Attendee oge) => oge.userId;
}

/// Katılımcılar listesi; detay ekranı kapanınca bırakılır.
final katilimcilarProvider = AsyncNotifierProvider.autoDispose
    .family<KatilimcilarNotifier, SayfaliListe<Attendee>, KatilimcilarAnahtari>(
      KatilimcilarNotifier.new,
      name: 'katilimcilarProvider',
      retry: yenidenDenemeYok,
    );

/// Bir kullanıcının görünen adı (organizatör ve katılımcı satırları).
/// Satır görünürken okunur, ekrandan çıkınca bırakılır; yalnızca
/// bellektedir.
class KullaniciAdiNotifier extends AsyncNotifier<String> {
  KullaniciAdiNotifier(this.kullaniciId);

  final String kullaniciId;

  @override
  Future<String> build() =>
      ref.read(etkinlikIslemleriProvider).kullaniciAdi(kullaniciId);
}

/// Kullanıcı kimliğinden görünen ad.
final kullaniciAdiProvider = AsyncNotifierProvider.autoDispose
    .family<KullaniciAdiNotifier, String, String>(
      KullaniciAdiNotifier.new,
      name: 'kullaniciAdiProvider',
      retry: yenidenDenemeYok,
    );

/// Hatalı okuma otomatik yeniden denenmez; kullanıcı "Tekrar dene"ye ya da
/// aşağı çekerek yeniler.
Duration? yenidenDenemeYok(int deneme, Object hata) => null;

/// Etkinlik listesi ve ana sayfa bölümü dahil, tayfanın etkinlik
/// listelerini yeniden okutur (oluşturma, düzenleme, iptal sonrası).
void etkinlikListeleriniYenile(Ref ref, String tayfaId) {
  ref.invalidate(etkinlikListesiProvider(tayfaId));
}

/// Kullanıcı bu tayfada etkinlik açabilir mi: yönetici, moderatör ya da
/// tayfada üyelerin etkinlik açması açıksa üye. Yalnızca "Etkinlik aç"
/// düğmesini göstermek içindir; karar sunucunundur (kesin kural 5).
class EtkinlikAcabilirNotifier extends AsyncNotifier<bool> {
  EtkinlikAcabilirNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<bool> build() async {
    final gorunum = await ref
        .read(etkinlikIslemleriProvider)
        .tayfaGorunumu(tayfaId);
    return switch (gorunum.callerRole) {
      Role.admin || Role.moderator => true,
      Role.member || Role.unknown => gorunum.tayfa.membersCanCreateEvents,
    };
  }
}

/// "Etkinlik aç" düğmesi gösterilsin mi; okunamazsa gösterilmez.
final etkinlikAcabilirProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikAcabilirNotifier, bool, String>(
      EtkinlikAcabilirNotifier.new,
      name: 'etkinlikAcabilirProvider',
      retry: yenidenDenemeYok,
    );
