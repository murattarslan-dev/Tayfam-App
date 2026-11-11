import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/realtime/realtime.dart';
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

  /// Okunacak daha eski mesaj var mı.
  bool get eskiVar => eskiSayfa != null;

  /// Akışta uçtan uca şifreli mesaj var mı (web geliştirme derlemesinde
  /// yazma alanı yerine "yalnızca mobil uygulamada" gösterilir).
  bool get sifreliVar =>
      mesajlar.any((m) => m.encryption == DirectMessageEncryption.e2e);

  /// Akışta düz sürümde yazılmış (`encryption: server`) mesaj var mı.
  bool get duzVar => mesajlar.any(
    (m) => m.encryption == DirectMessageEncryption.server && !m.deleted,
  );

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
  }) => KonusmaDurumu(
    konusma: konusma ?? this.konusma,
    mesajlar: mesajlar ?? this.mesajlar,
    eskiSayfa: eskiSayfayiSil ? null : eskiSayfa ?? this.eskiSayfa,
    eskiYukleniyor: eskiYukleniyor,
    eskiHatasi: eskiHatasi,
  );
}

/// Bir birebir konuşma: mesaj akışı, gönderme, silme, okundu işareti ve
/// mesaj isteğini kabul ya da ret (ADR-0018 §9, düz sürüm).
///
/// Ekran açıkken yaşar (`autoDispose`); oturum değişince yeniden kurulur.
/// Mesajlar yalnızca bellektedir (ADR-0006) ve hiçbir yere yazılmaz,
/// loglanmaz (kesin kural 3).
///
/// - WebSocket olayları (`dm.message_created`, `dm.message_deleted`,
///   `dm.conversation_accepted`, `dm.read`) bellekteki durumu günceller;
///   bağlantı yeniden kurulunca kaçırılanlar REST'ten çekilir (ADR-0007).
/// - Gönderim çevrimdışı kuyruktan geçer ([gonder]; ADR-0006): bağlantı
///   açıksa `dm.send`, değilse aynı `client_request_id` ile REST. Bekleyen
///   mesajlar [bekleyenBirebirProvider]'dadır; gönderilen mesaj bekleyen
///   balonun yerine geçer.
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
    final realtime = ref.watch(realtimeIstemcisiProvider);
    _isaretlenen = null;
    final olaylar = realtime.olaylar.listen(_olay);
    ref.onDispose(olaylar.cancel);
    final kuyruk = ref
        .read(cevrimdisiKuyrukProvider.notifier)
        .olaylar
        .listen(_kuyrukOlayi);
    ref.onDispose(kuyruk.cancel);
    final konusma = await depo.konusma(konusmaId);
    final sayfa = await depo.mesajlar(konusmaId);
    // Karşı tarafın cihaz/anahtar değişiklikleri: "güvenlik kodu
    // değişti" satırları (ADR-0020; en iyi çaba).
    final karsi = konusma.otherUserId;
    if (karsi != null && ref.read(e2eEtkinProvider)) {
      unawaited(ref.read(e2eBirebirProvider).konusmaAcildi(karsi));
    }
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
      await _arsiviGenislet(sayfa.ogeler);
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

  /// Eski sayfadaki şifreli mesajların metni için geçmiş arşivinin
  /// sonraki sayfalarını ister (ADR-0020 §3). Arşiv konuşma ekranı
  /// açıkken yaşar; ekran onu izlemiyorsa (E2E yok) istek atılmaz.
  /// Arşiv okunamazsa mesajlar yine gösterilir; metni olmayan şifreli
  /// mesaj "okunamıyor" kalır.
  Future<void> _arsiviGenislet(List<DirectMessage> mesajlar) async {
    final arsiv = konusmaArsiviProvider(konusmaId);
    if (!ref.read(e2eEtkinProvider) || !ref.exists(arsiv)) return;
    final sifreliler = [
      for (final m in mesajlar)
        if (m.encryption == DirectMessageEncryption.e2e && !m.deleted) m.id,
    ];
    try {
      await ref.read(arsiv.notifier).kapsa(sifreliler);
    } on OturumYok {
      rethrow;
    } on Exception {
      // En iyi çaba; bir sonraki eski sayfada yeniden denenir.
    }
  }

  /// [ham] metni çevrimdışı kuyruğa koyar: geçerliyse bekleyen mesaj
  /// olarak hemen görünür ve `true` döner. Geçersizse ya da yazılacak
  /// kişi yoksa (hesabı silinmiş) `false`. Kimin kime yazabileceğine
  /// sunucu karar verir (kesin kural 5); ret, bekleyen mesajın hatası
  /// olarak görünür.
  bool gonder(String ham) {
    final metin = birebirMetniniHazirla(ham);
    final alici = state.value?.konusma.otherUserId;
    if (alici == null || !birebirMetniGecerli(metin)) return false;
    ref
        .read(cevrimdisiKuyrukProvider.notifier)
        .ekle(
          BirebirMesajIsi(
            aliciId: alici,
            metin: metin,
            istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
            gonderici: ref.read(birebirGondericiProvider),
          ),
        );
    // İlk gerçek ihtiyaç: bildirim izni açıklaması (istemci ADR-0019 §3).
    unawaited(ref.read(bildirimIzniProvider.notifier).ihtiyacDogdu());
    return true;
  }

  /// Gönderilemeyen mesajı aynı `client_request_id` ile yeniden dener.
  void tekrarDene(String istekKimligi) =>
      ref.read(cevrimdisiKuyrukProvider.notifier).tekrarDene(istekKimligi);

  /// Bekleyen ya da gönderilemeyen mesajı kuyruktan atar.
  void vazgec(String istekKimligi) =>
      ref.read(cevrimdisiKuyrukProvider.notifier).sil(istekKimligi);

  void _kuyrukOlayi(KuyrukOlayi olay) {
    if (olay
        case KuyrukGonderildi(
          isi: BirebirMesajIsi(),
          :final BirebirGonderimi sonuc,
        )
        when sonuc.mesaj.conversationId == konusmaId) {
      _mesajiYaz(sonuc.mesaj, durum: sonuc.durum, konusma: sonuc.konusma);
    }
  }

  void _olay(RealtimeOlayi olay) {
    switch (olay) {
      case DmMesajiGeldi(:final mesaj) when mesaj.conversationId == konusmaId:
        _mesajiYaz(mesaj);
      case DmMesajiSilindi(:final konusmaId, :final mesajId)
          when konusmaId == this.konusmaId:
        _silindiIsaretle(mesajId);
      case DmKonusmaKabulEdildi(:final konusmaId)
          when konusmaId == this.konusmaId:
        _durumuDegistir(ConversationStatus.active);
      case DmOkundu(
            :final konusmaId,
            :final kullaniciId,
            :final sonOkunanMesajId,
          )
          when konusmaId == this.konusmaId:
        _karsiOkudu(kullaniciId, sonOkunanMesajId);
      case Baglandi():
        unawaited(yeniler());
      default:
        break;
    }
  }

  /// [mesaj]'ı akışa yazar; gönderimden geldiyse konuşmanın yeni durumunu
  /// da ([durum] ya da sunucunun döndürdüğü [konusma]) yansıtır.
  void _mesajiYaz(
    DirectMessage mesaj, {
    ConversationStatus? durum,
    Conversation? konusma,
  }) {
    final mevcut = state.value;
    if (mevcut == null) return;
    final yeniKonusma =
        konusma ??
        (durum == null
            ? mevcut.konusma
            : _konusmaDegistir(mevcut.konusma, durum: durum));
    state = AsyncData(
      mevcut._degistir(
        konusma: yeniKonusma,
        mesajlar: mesajlariBirlestir(mevcut.mesajlar, [mesaj]),
      ),
    );
    if (konusma != null || durum != null) {
      ref.read(konusmaListesiProvider.notifier).yansit(yeniKonusma);
    }
  }

  void _silindiIsaretle(String mesajId) {
    final mevcut = state.value;
    if (mevcut == null) return;
    state = AsyncData(
      mevcut._degistir(
        mesajlar: [
          for (final m in mevcut.mesajlar)
            m.id == mesajId ? silinmisOlarak(m) : m,
        ],
      ),
    );
  }

  void _durumuDegistir(ConversationStatus durum) {
    final mevcut = state.value;
    if (mevcut == null) return;
    final konusma = _konusmaDegistir(mevcut.konusma, durum: durum);
    state = AsyncData(mevcut._degistir(konusma: konusma));
    ref.read(konusmaListesiProvider.notifier).yansit(konusma);
  }

  void _karsiOkudu(String kullaniciId, String mesajId) {
    final mevcut = state.value;
    if (mevcut == null || kullaniciId != mevcut.konusma.otherUserId) return;
    state = AsyncData(
      mevcut._degistir(
        konusma: _konusmaDegistir(mevcut.konusma, karsiOkundu: mesajId),
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
    _silindiIsaretle(mesajId);
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

  Conversation _konusmaDegistir(
    Conversation k, {
    ConversationStatus? durum,
    String? karsiOkundu,
  }) => Conversation(
    id: k.id,
    otherUserId: k.otherUserId,
    status: durum ?? k.status,
    unreadCount: k.unreadCount,
    lastReadMessageId: k.lastReadMessageId,
    peerLastReadMessageId: karsiOkundu ?? k.peerLastReadMessageId,
    lastMessageAt: k.lastMessageAt,
    createdAt: k.createdAt,
  );

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

/// WebSocket bağlantısı yokken (web geliştirme derlemesi, kopuk
/// bağlantı) konuşma ekranı açık ve uygulama ön plandayken yeni mesajların
/// REST'ten okunma aralığı.
final birebirYenilemeAraligiProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
  name: 'birebirYenilemeAraligiProvider',
);

/// [aliciId]'ye giden, kuyrukta bekleyen ya da gönderilemeyen birebir
/// mesajlar, eklenme sırasıyla (ADR-0006: bekleyen saat, gönderilemeyen
/// uyarı ikonuyla gösterilir).
final bekleyenBirebirProvider = Provider.autoDispose
    .family<List<GidenMesaj>, String>((ref, aliciId) {
      final ogeler = ref.watch(cevrimdisiKuyrukProvider);
      return [
        for (final o in ogeler)
          if (o.isi case BirebirMesajIsi(:final metin, aliciId: final a)
              when a == aliciId)
            GidenMesaj(
              istekKimligi: o.istekKimligi,
              metin: metin,
              durum: o.durum == KuyrukDurumu.gonderilemedi
                  ? GidenDurumu.basarisiz
                  : GidenDurumu.gonderiliyor,
              hata: o.hata,
            ),
      ];
    }, name: 'bekleyenBirebirProvider');
