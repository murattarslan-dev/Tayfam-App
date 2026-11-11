import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';
import 'package:tayfam/features/sohbet/data/kanal_mesaj_isi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Kanal mesajının en uzun hâli (sözleşme: 1–4000 karakter).
const int mesajEnUzun = 4000;

/// Bir kanalın bellekteki mesaj akışı.
@immutable
final class KanalAkisi {
  const KanalAkisi({
    required this.mesajlar,
    this.eskiSayfa,
    this.eskiYukleniyor = false,
    this.eskiHatasi,
  });

  /// Mesajlar, en yeni önce.
  final List<ChannelMessage> mesajlar;

  /// Daha eski mesajların opak sayfa token'ı; yoksa `null`.
  final String? eskiSayfa;

  final bool eskiYukleniyor;
  final Object? eskiHatasi;

  KanalAkisi _ile({
    List<ChannelMessage>? mesajlar,
    String? eskiSayfa,
    bool eskiSayfaSil = false,
    bool eskiYukleniyor = false,
    Object? eskiHatasi,
  }) => KanalAkisi(
    mesajlar: List.unmodifiable(mesajlar ?? this.mesajlar),
    eskiSayfa: eskiSayfaSil ? null : (eskiSayfa ?? this.eskiSayfa),
    eskiYukleniyor: eskiYukleniyor,
    eskiHatasi: eskiHatasi,
  );
}

/// Bir kanalın mesaj akışı (ADR-0018 §9, ADR-0007).
///
/// - İlk sayfa REST'ten (en yeni önce) okunur; daha eskiler
///   [eskileriYukle] ile.
/// - `message.created` / `message.restored` / `message.deleted` olayları
///   akışı günceller; mesajlar `id` ile tekilleştirilir.
/// - Bağlantı yeniden kurulunca kaçırılanlar, eldeki en yeni mesajdan
///   itibaren (`after_message_id`) REST'ten çekilir.
/// - Gönderim çevrimdışı kuyruktan geçer ([gonder]); gönderilen mesaj
///   bekleyen balonun yerine geçer.
/// - Ekran açıkken en yeni mesaj okundu işaretlenir.
/// - Yalnızca bellektedir; mesaj metni hiçbir yere yazılmaz.
class KanalAkisiNotifier extends AsyncNotifier<KanalAkisi> {
  KanalAkisiNotifier(this.kanal);

  final KanalRef kanal;

  String? _isaretlenen;

  @override
  Future<KanalAkisi> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(kanalDeposuProvider);
    final realtime = ref.watch(realtimeIstemcisiProvider);
    _isaretlenen = null;

    final olaylar = realtime.olaylar.listen(_olay);
    ref.onDispose(olaylar.cancel);
    final kuyruk = ref
        .read(cevrimdisiKuyrukProvider.notifier)
        .olaylar
        .listen(_kuyrukOlayi);
    ref.onDispose(kuyruk.cancel);

    final sayfa = await depo.mesajlar(kanal.tayfaId, kanal.kanalId);
    return KanalAkisi(
      mesajlar: List.unmodifiable(_tekil(sayfa.messages)),
      eskiSayfa: sayfa.nextPageToken,
    );
  }

  /// Daha eski bir sayfa okur. Okunamazsa eldeki akış kalır.
  Future<void> eskileriYukle() async {
    final mevcut = state.value;
    final token = mevcut?.eskiSayfa;
    if (mevcut == null || token == null || mevcut.eskiYukleniyor) return;
    state = AsyncData(mevcut._ile(eskiYukleniyor: true));
    try {
      final sayfa = await ref
          .read(kanalDeposuProvider)
          .mesajlar(kanal.tayfaId, kanal.kanalId, sayfaToken: token);
      if (!ref.mounted) return;
      final simdiki = state.value ?? mevcut;
      final yeniToken = sayfa.nextPageToken;
      state = AsyncData(
        simdiki._ile(
          mesajlar: _tekil([...simdiki.mesajlar, ...sayfa.messages]),
          eskiSayfa: yeniToken,
          // Aynı token yeniden gelirse son sayfa sayılır (sonsuz döngü yok).
          eskiSayfaSil: yeniToken == null || yeniToken == token,
        ),
      );
    } on Exception catch (hata) {
      if (!ref.mounted) return;
      final simdiki = state.value ?? mevcut;
      state = AsyncData(simdiki._ile(eskiHatasi: hata));
    }
  }

  /// [metin]'i çevrimdışı kuyruğa koyar. Boş (yalnız boşluk) ya da
  /// [mesajEnUzun]'dan uzun metin gönderilmez; `false` döner.
  bool gonder(String metin) {
    if (metin.trim().isEmpty || metin.length > mesajEnUzun) return false;
    ref
        .read(cevrimdisiKuyrukProvider.notifier)
        .ekle(
          KanalMesajIsi(
            tayfaId: kanal.tayfaId,
            kanalId: kanal.kanalId,
            metin: metin,
            istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
            realtime: ref.read(realtimeIstemcisiProvider),
            depo: ref.read(kanalDeposuProvider),
          ),
        );
    return true;
  }

  /// Mesajı siler (kendi mesajı ya da yönetimin moderasyonu; kararı sunucu
  /// verir). Hata fırlatılır; ekran kısa bildirimle gösterir.
  Future<void> sil(String mesajId) async {
    await ref
        .read(kanalDeposuProvider)
        .sil(kanal.tayfaId, kanal.kanalId, mesajId);
    if (!ref.mounted) return;
    _silindiIsaretle(mesajId);
  }

  /// Moderasyonla gizlenen mesajı geri alır (yönetici).
  Future<void> geriAl(String mesajId) async {
    final mesaj = await ref
        .read(kanalDeposuProvider)
        .geriAl(kanal.tayfaId, kanal.kanalId, mesajId);
    if (!ref.mounted) return;
    _yaz(mesaj);
  }

  /// En yeni mesajı okundu işaretler (ekran açıkken). Aynı mesaj için
  /// tekrar istek gönderilmez; hata sessizce yutulur (sonraki mesajda
  /// yeniden denenir).
  Future<void> okunduIsaretle() async {
    final mesajlar = state.value?.mesajlar;
    if (mesajlar == null || mesajlar.isEmpty) return;
    final enYeni = mesajlar.first.id;
    final kanallar = kanallarProvider(kanal.tayfaId);
    if (ref.read(kanallar.exists)) {
      ref.read(kanallar.notifier).okundu(kanal.kanalId);
    }
    if (enYeni == _isaretlenen) return;
    _isaretlenen = enYeni;
    try {
      await ref
          .read(kanalDeposuProvider)
          .okundu(kanal.tayfaId, kanal.kanalId, enYeni);
    } on Exception {
      if (_isaretlenen == enYeni) _isaretlenen = null;
    }
  }

  // ------------------------------------------------------------------ iç

  void _olay(RealtimeOlayi olay) {
    switch (olay) {
      case KanalMesajiGeldi(:final mesaj, kanal: final k) when k == kanal:
        _yaz(mesaj);
      case KanalMesajiSilindi(:final mesajId, kanal: final k) when k == kanal:
        _silindiIsaretle(mesajId);
      case Baglandi():
        unawaited(_eksikleriCek());
      default:
        break;
    }
  }

  void _kuyrukOlayi(KuyrukOlayi olay) {
    if (olay
        case KuyrukGonderildi(
          isi: KanalMesajIsi(:final kanalId),
          :final ChannelMessage sonuc,
        )
        when kanalId == kanal.kanalId) {
      _yaz(sonuc);
    }
  }

  /// Bağlantı koptuğu sürece kaçırılanları, eldeki en yeni mesajdan
  /// itibaren çeker.
  Future<void> _eksikleriCek() async {
    final mevcut = state.value;
    if (mevcut == null) return;
    final depo = ref.read(kanalDeposuProvider);
    final sonId = mevcut.mesajlar.isEmpty ? null : mevcut.mesajlar.first.id;
    try {
      if (sonId == null) {
        final sayfa = await depo.mesajlar(kanal.tayfaId, kanal.kanalId);
        if (!ref.mounted) return;
        for (final m in sayfa.messages.reversed) {
          _yaz(m);
        }
        return;
      }
      String? token;
      final gorulen = <String>{};
      do {
        final sayfa = await depo.mesajlar(
          kanal.tayfaId,
          kanal.kanalId,
          sonrakiId: sonId,
          sayfaToken: token,
        );
        if (!ref.mounted) return;
        for (final m in sayfa.messages) {
          _yaz(m);
        }
        token = sayfa.nextPageToken;
      } while (token != null && gorulen.add(token));
    } on Exception {
      // Sonraki bağlantıda ya da ekran yeniden açılınca tamamlanır.
    }
  }

  /// Mesajı akışa yazar: varsa yerine koyar, yoksa zamanına göre ekler.
  void _yaz(ChannelMessage mesaj) {
    final mevcut = state.value;
    if (mevcut == null || mesaj.channelId != kanal.kanalId) return;
    final liste = [
      for (final m in mevcut.mesajlar)
        if (m.id != mesaj.id) m,
      mesaj,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(
      mevcut._ile(
        mesajlar: liste,
        eskiYukleniyor: mevcut.eskiYukleniyor,
        eskiHatasi: mevcut.eskiHatasi,
      ),
    );
  }

  void _silindiIsaretle(String mesajId) {
    final mevcut = state.value;
    if (mevcut == null) return;
    state = AsyncData(
      mevcut._ile(
        mesajlar: [
          for (final m in mevcut.mesajlar)
            if (m.id == mesajId) silinmisMesaj(m) else m,
        ],
        eskiYukleniyor: mevcut.eskiYukleniyor,
        eskiHatasi: mevcut.eskiHatasi,
      ),
    );
  }

  List<ChannelMessage> _tekil(List<ChannelMessage> mesajlar) {
    final gorulen = <String>{};
    return [
      for (final m in mesajlar)
        if (gorulen.add(m.id)) m,
    ];
  }
}

/// Silinmiş mesaj: metin bellekten de atılır ("Bu mesaj silindi").
ChannelMessage silinmisMesaj(ChannelMessage m) => ChannelMessage(
  id: m.id,
  channelId: m.channelId,
  authorUserId: m.authorUserId,
  deleted: true,
  restorable: m.restorable,
  createdAt: m.createdAt,
);

/// Kanalın mesaj akışı (`family` + `autoDispose`; ADR-0001).
final kanalAkisiProvider = AsyncNotifierProvider.autoDispose
    .family<KanalAkisiNotifier, KanalAkisi, KanalRef>(
      KanalAkisiNotifier.new,
      name: 'kanalAkisiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
