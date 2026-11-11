import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/birebir/application/birebir_gonderici.dart';
import 'package:tayfam/features/birebir/application/birebir_islemi.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/application/mesaj_kurallari.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Eksikleri tamamlarken bir seferde okunan en çok sayfa; daha fazlası bir
/// sonraki yenilemeye kalır.
const int eksikSayfaEnCok = 5;

/// Bir birebir konuşmanın ekrandaki durumu.
@immutable
final class KonusmaDurumu {
  const KonusmaDurumu({
    required this.konusma,
    required this.mesajlar,
    this.eskiSayfa,
    this.eskiYukleniyor = false,
    this.eskiHatasi,
    this.giden = const [],
  });

  final Conversation konusma;

  /// Okunan mesajlar, en yeni önce.
  final List<DirectMessage> mesajlar;

  /// Daha eski mesajların opak sayfa token'ı; yoksa `null`.
  final String? eskiSayfa;

  /// Daha eski mesajlar okunuyor.
  final bool eskiYukleniyor;

  /// Daha eski mesajlar okunamadıysa hatası.
  final Object? eskiHatasi;

  /// Sunucu henüz kabul etmemiş giden mesajlar, eskiden yeniye.
  final List<GidenMesaj> giden;

  /// Okunacak daha eski mesaj var mı.
  bool get eskiVar => eskiSayfa != null;

  /// [mesaj] kullanıcının kendi mesajı mı. Karşı tarafın mesajında
  /// gönderen karşı taraftır; hesabı silinmişse gönderen yoktur.
  bool gidenMi(DirectMessage mesaj) {
    final gonderen = mesaj.senderUserId;
    return gonderen != null && gonderen != konusma.otherUserId;
  }

  /// Karşı tarafın okuduğu en yeni giden mesajın kimliği ("Görüldü").
  /// Okundu işareti yalnızca aktif konuşmada gelir; işaretin gösterdiği
  /// mesaj henüz okunmadıysa `null`.
  String? get gorulenGidenId {
    final isaret = konusma.peerLastReadMessageId;
    if (isaret == null) return null;
    var gecti = false;
    for (final m in mesajlar) {
      if (m.id == isaret) gecti = true;
      if (gecti && gidenMi(m)) return m.id;
    }
    return null;
  }

  KonusmaDurumu _degistir({
    Conversation? konusma,
    List<DirectMessage>? mesajlar,
    String? eskiSayfa,
    bool eskiSayfayiSil = false,
    bool eskiYukleniyor = false,
    Object? eskiHatasi,
    List<GidenMesaj>? giden,
  }) => KonusmaDurumu(
    konusma: konusma ?? this.konusma,
    mesajlar: mesajlar ?? this.mesajlar,
    eskiSayfa: eskiSayfayiSil ? null : eskiSayfa ?? this.eskiSayfa,
    eskiYukleniyor: eskiYukleniyor,
    eskiHatasi: eskiHatasi,
    giden: List.unmodifiable(giden ?? this.giden),
  );
}

/// Bir birebir konuşma: mesaj akışı, gönderme, silme, okundu işareti ve
/// mesaj isteğini kabul ya da ret (ADR-0018 §9, düz sürüm).
///
/// Ekran açıkken yaşar (`autoDispose`); oturum değişince yeniden kurulur.
/// Mesajlar yalnızca bellektedir (ADR-0006) ve hiçbir yere yazılmaz,
/// loglanmaz (kesin kural 3). Yeni mesajlar bugün ekran açıkken
/// [yeniler] ile REST'ten çekilir; WebSocket geldiğinde olaylar da aynı
/// birleştirmeden geçer.
class KonusmaNotifier extends AsyncNotifier<KonusmaDurumu> {
  KonusmaNotifier(this.konusmaId);

  /// Adresteki konuşma kimliği (biçimi yönlendiricide doğrulandı).
  final String konusmaId;

  bool _yenileniyor = false;
  String? _isaretlenen;

  @override
  Future<KonusmaDurumu> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(birebirDeposuProvider);
    _isaretlenen = null;
    final konusma = await depo.konusma(konusmaId);
    final sayfa = await depo.mesajlar(konusmaId);
    return KonusmaDurumu(
      konusma: konusma,
      mesajlar: mesajlariBirlestir(const [], sayfa.ogeler),
      eskiSayfa: _gecerliToken(sayfa.sonraki),
    );
  }

  /// Konuşmayı ve son gördüğümüz mesajdan sonraki mesajları sunucudan
  /// okur (ekran açıkken ve uygulama ön plana dönünce). Okunamazsa eldeki
  /// durum kalır; arka plan yenilemesi hata göstermez.
  Future<void> yeniler() async {
    final mevcut = state.value;
    if (mevcut == null || _yenileniyor) return;
    _yenileniyor = true;
    try {
      final depo = ref.read(birebirDeposuProvider);
      final konusma = await depo.konusma(konusmaId);
      final gelen = <DirectMessage>[];
      String? eskiSayfa;
      final sonGorulen = mevcut.mesajlar.isEmpty
          ? null
          : mevcut.mesajlar.first.id;
      if (sonGorulen == null) {
        final sayfa = await depo.mesajlar(konusmaId);
        gelen.addAll(sayfa.ogeler);
        eskiSayfa = _gecerliToken(sayfa.sonraki);
      } else {
        String? token;
        var tur = 0;
        do {
          final sayfa = await depo.mesajlar(
            konusmaId,
            sonrakiMesajId: sonGorulen,
            sayfaToken: token,
          );
          gelen.addAll(sayfa.ogeler);
          token = _gecerliToken(sayfa.sonraki);
          tur++;
        } while (token != null && tur < eksikSayfaEnCok);
      }
      if (!ref.mounted) return;
      final simdiki = state.value;
      if (simdiki == null) return;
      state = AsyncData(
        simdiki._degistir(
          konusma: konusma,
          mesajlar: mesajlariBirlestir(simdiki.mesajlar, gelen),
          eskiSayfa: simdiki.mesajlar.isEmpty ? eskiSayfa : null,
        ),
      );
      ref.read(konusmaListesiProvider.notifier).yansit(konusma);
    } on OturumYok {
      oturumKapandi(ref);
    } on Exception {
      // Arka plan yenilemesi; bir sonraki yenilemede yeniden denenir.
    } finally {
      _yenileniyor = false;
    }
  }

  /// Daha eski mesajları okuyup akışın sonuna ekler.
  Future<void> dahaEski() async {
    final mevcut = state.value;
    if (mevcut == null || mevcut.eskiYukleniyor) return;
    final token = mevcut.eskiSayfa;
    if (token == null) return;
    state = AsyncData(mevcut._degistir(eskiYukleniyor: true));
    try {
      final sayfa = await ref
          .read(birebirDeposuProvider)
          .mesajlar(konusmaId, sayfaToken: token);
      if (!ref.mounted) return;
      final simdiki = state.value;
      if (simdiki == null) return;
      final sonraki = _gecerliToken(sayfa.sonraki);
      state = AsyncData(
        simdiki._degistir(
          mesajlar: mesajlariBirlestir(simdiki.mesajlar, sayfa.ogeler),
          eskiSayfa: sonraki,
          eskiSayfayiSil: sonraki == null || sonraki == token,
        ),
      );
    } on OturumYok {
      oturumKapandi(ref);
    } on Exception catch (hata) {
      if (!ref.mounted) return;
      final simdiki = state.value;
      if (simdiki != null) {
        state = AsyncData(simdiki._degistir(eskiHatasi: hata));
      }
    }
  }

  /// [ham] metni gönderir: geçerliyse bekleyen mesaj olarak hemen görünür
  /// ve `true` döner. Geçersizse ya da yazılacak kişi yoksa (hesabı
  /// silinmiş) `false`. Kimin kime yazabileceğine sunucu karar verir
  /// (kesin kural 5); ret, bekleyen mesajın hatası olarak görünür.
  bool gonder(String ham) {
    final metin = birebirMetniniHazirla(ham);
    final mevcut = state.value;
    final alici = mevcut?.konusma.otherUserId;
    if (mevcut == null || alici == null || !birebirMetniGecerli(metin)) {
      return false;
    }
    final giden = GidenMesaj(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      metin: metin,
    );
    state = AsyncData(mevcut._degistir(giden: [...mevcut.giden, giden]));
    unawaited(_gonder(giden, alici));
    return true;
  }

  /// Gönderilemeyen mesajı aynı `client_request_id` ile yeniden dener.
  void tekrarDene(String istekKimligi) {
    final mevcut = state.value;
    final alici = mevcut?.konusma.otherUserId;
    if (mevcut == null || alici == null) return;
    for (final g in mevcut.giden) {
      if (g.istekKimligi == istekKimligi && g.durum == GidenDurumu.basarisiz) {
        final yeni = g.gonderiliyor();
        _gideniDegistir(istekKimligi, (_) => yeni);
        unawaited(_gonder(yeni, alici));
        return;
      }
    }
  }

  /// Gönderilemeyen mesajı bellekten atar.
  void vazgec(String istekKimligi) =>
      _gideniDegistir(istekKimligi, (_) => null);

  Future<void> _gonder(GidenMesaj giden, String alici) async {
    final DirectMessageSent sonuc;
    try {
      sonuc = await ref
          .read(birebirGondericiProvider)
          .gonder(
            aliciId: alici,
            metin: giden.metin,
            istekKimligi: giden.istekKimligi,
          );
    } on OturumYok catch (hata) {
      oturumKapandi(ref);
      if (ref.mounted)
        _gideniDegistir(giden.istekKimligi, (g) => g.basarisiz(hata));
      return;
    } on Exception catch (hata) {
      if (ref.mounted)
        _gideniDegistir(giden.istekKimligi, (g) => g.basarisiz(hata));
      return;
    }
    if (!ref.mounted) return;
    final mevcut = state.value;
    if (mevcut == null) return;
    state = AsyncData(
      mevcut._degistir(
        konusma: sonuc.conversation,
        mesajlar: mesajlariBirlestir(mevcut.mesajlar, [sonuc.message]),
        giden: [
          for (final g in mevcut.giden)
            if (g.istekKimligi != giden.istekKimligi) g,
        ],
      ),
    );
    ref.read(konusmaListesiProvider.notifier).yansit(sonuc.conversation);
  }

  void _gideniDegistir(
    String istekKimligi,
    GidenMesaj? Function(GidenMesaj g) degistir,
  ) {
    final mevcut = state.value;
    if (mevcut == null) return;
    state = AsyncData(
      mevcut._degistir(
        giden: [
          for (final g in mevcut.giden)
            if (g.istekKimligi != istekKimligi)
              g
            else if (degistir(g) case final yeni?)
              yeni,
        ],
      ),
    );
  }

  /// Kendi mesajını siler; metin iki taraftan da kalkar. Başarıda `null`,
  /// aksi halde hata.
  Future<Object?> sil(String mesajId) async {
    final hata = await birebirIslemi(
      ref,
      () => ref.read(birebirDeposuProvider).sil(konusmaId, mesajId),
    );
    if (hata != null || !ref.mounted) return hata;
    final mevcut = state.value;
    if (mevcut != null) {
      state = AsyncData(
        mevcut._degistir(
          mesajlar: [
            for (final m in mevcut.mesajlar)
              m.id == mesajId ? silinmisOlarak(m) : m,
          ],
        ),
      );
    }
    return null;
  }

  /// Size gelen mesaj isteğini kabul eder; konuşma aktif olur.
  Future<Object?> kabulEt() async {
    Conversation? konusma;
    final hata = await birebirIslemi(ref, () async {
      konusma = await ref.read(birebirDeposuProvider).kabulEt(konusmaId);
    });
    final yeni = konusma;
    if (hata != null || yeni == null || !ref.mounted) return hata;
    final mevcut = state.value;
    if (mevcut != null) state = AsyncData(mevcut._degistir(konusma: yeni));
    ref.read(konusmaListesiProvider.notifier).yansit(yeni);
    return null;
  }

  /// Size gelen mesaj isteğini reddeder; konuşma listeden çıkar ve
  /// reddedilenlere geçer. Gönderen bunu öğrenmez.
  Future<Object?> reddet() async {
    final hata = await birebirIslemi(
      ref,
      () => ref.read(birebirDeposuProvider).reddet(konusmaId),
    );
    if (hata != null || !ref.mounted) return hata;
    ref.read(konusmaListesiProvider.notifier).cikar(konusmaId);
    return null;
  }

  /// Konuşmayı en yeni mesaja kadar okundu işaretler (ekran açıkken).
  /// Okundu işareti yalnızca ileri gider; zaten işaretliyse istek gitmez.
  /// Başarısız olursa sessizce bir sonraki değişiklikte yeniden denenir.
  Future<void> okunduIsaretle() async {
    final mevcut = state.value;
    if (mevcut == null || mevcut.mesajlar.isEmpty) return;
    final enYeni = mevcut.mesajlar.first.id;
    if (mevcut.konusma.lastReadMessageId == enYeni || _isaretlenen == enYeni) {
      return;
    }
    _isaretlenen = enYeni;
    try {
      await ref.read(birebirDeposuProvider).okundu(konusmaId, enYeni);
    } on OturumYok {
      oturumKapandi(ref);
      return;
    } on Exception {
      if (ref.mounted && _isaretlenen == enYeni) _isaretlenen = null;
      return;
    }
    if (!ref.mounted) return;
    final simdiki = state.value;
    if (simdiki == null) return;
    final konusma = okunduOlarak(simdiki.konusma, enYeni);
    state = AsyncData(simdiki._degistir(konusma: konusma));
    ref.read(konusmaListesiProvider.notifier).yansit(konusma);
  }

  String? _gecerliToken(String? token) =>
      token == null || token.isEmpty ? null : token;
}

/// Bir birebir konuşma; ekran kapanınca bırakılır.
final konusmaProvider = AsyncNotifierProvider.autoDispose
    .family<KonusmaNotifier, KonusmaDurumu, String>(
      KonusmaNotifier.new,
      name: 'konusmaProvider',
      retry: yenidenDenemeYok,
    );

/// Konuşma ekranı açıkken ve uygulama ön plandayken yeni mesajların
/// REST'ten okunma aralığı. GEÇİCİ: WebSocket (`dm.message_created`,
/// ADR-0007) bağlanınca yalnızca yeniden bağlanmada eksik tamamlamaya
/// iner.
final birebirYenilemeAraligiProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
  name: 'birebirYenilemeAraligiProvider',
);
