import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';
import 'package:tayfam/features/sohbet/data/kanal_mesaj_isi.dart';

/// Sunucunun döndürdüğü en büyük okunmamış sayısı; "99+" demektir.
const int okunmamisUstSinir = 100;

/// Şu an ekranda açık olan kanal. Bu kanala gelen mesajlar okunmamış
/// sayılmaz ve 100 abonelik sınırında öncelik onundur (ADR-0007).
class AcikKanalNotifier extends Notifier<KanalRef?> {
  @override
  KanalRef? build() {
    ref.watch(oturumDurumuProvider);
    return null;
  }

  /// Kanal ekranı açılınca.
  void ac(KanalRef kanal) {
    if (ref.mounted) state = kanal;
  }

  /// Kanal ekranı kapanınca; başka bir kanal açıldıysa dokunmaz.
  void kapat(KanalRef kanal) {
    if (ref.mounted && state == kanal) state = null;
  }
}

/// Açık kanal (kalıcı; oturum değişince sıfırlanır).
final acikKanalProvider = NotifierProvider<AcikKanalNotifier, KanalRef?>(
  AcikKanalNotifier.new,
  name: 'acikKanalProvider',
);

/// Bir tayfanın kanal listesi ve okunmamış sayıları (ADR-0018 §9).
///
/// - `GET /v1/tayfas/{tayfa_id}/channels`; yönetim (`staff`) kanallarını
///   yalnızca yönetim görür; bunu sunucu süzer.
/// - Liste canlıyken tayfanın arşivlenmemiş kanallarına abone olunur
///   (ADR-0007; açık kanal önce). Liste bırakılınca (tayfa değişti)
///   abonelikler bırakılır.
/// - `message.created` başka bir kanala geldiyse okunmamış sayısı artar
///   (en çok 100). Kendi gönderdiğimiz mesaj [kendiMesajim] ile düşülür.
/// - `access_lost` alınan kanal listeden çıkar; abonelik `*_not_found`
///   alınca ve bağlantı yeniden kurulunca liste REST'ten yenilenir.
/// - Yalnızca bellektedir (ADR-0006).
class KanallarNotifier extends AsyncNotifier<List<Channel>> {
  KanallarNotifier(this.tayfaId);

  final String tayfaId;

  /// Okunmamış sayılan mesajlar (kanal → mesaj kimlikleri).
  final Map<String, Set<String>> _sayilan = {};

  /// Gönderimi bizden olan ama olayı henüz gelmemiş mesajlar.
  final Set<String> _kendi = {};

  @override
  Future<List<Channel>> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(kanalDeposuProvider);
    final realtime = ref.watch(realtimeIstemcisiProvider);
    _sayilan.clear();
    _kendi.clear();

    final abonelik = realtime.olaylar.listen(_olay);
    ref.onDispose(abonelik.cancel);
    final kuyruk = ref
        .read(cevrimdisiKuyrukProvider.notifier)
        .olaylar
        .listen(_kuyrukOlayi);
    ref.onDispose(kuyruk.cancel);
    ref.listen(acikKanalProvider, (_, _) => _abonelikleriAyarla());
    ref.onDispose(() => realtime.abonelikleriBirak(tayfaId));

    final kanallar = await depo.kanallar(tayfaId);
    _abonelikleriAyarla(kanallar);
    return kanallar;
  }

  /// Listeyi REST'ten yeniden okur. Okunamazsa eldeki liste kalır; elde
  /// liste yoksa hata gösterilir. Başarıda `null`, aksi halde hata.
  Future<Object?> yenile() async {
    try {
      final kanallar = await ref.read(kanalDeposuProvider).kanallar(tayfaId);
      if (!ref.mounted) return null;
      _sayilan.clear();
      _ayarla(kanallar);
      return null;
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
      return hata;
    }
  }

  /// Kanal ekranı okundu işaretledi: okunmamış sayısı sıfırlanır.
  void okundu(String kanalId) {
    _sayilan.remove(kanalId);
    _degistir(kanalId, (k) => _okunmamisIle(k, 0));
  }

  /// Gönderdiğimiz mesaj sunucuya yazıldı. Olayı daha önce geldi ve
  /// okunmamış sayıldıysa sayı düşer; gelmediyse geldiğinde sayılmaz.
  void kendiMesajim(String kanalId, String mesajId) {
    final sayilan = _sayilan[kanalId];
    if (sayilan != null && sayilan.remove(mesajId)) {
      _degistir(
        kanalId,
        (k) => _okunmamisIle(k, ((k.unreadCount ?? 1) - 1).clamp(0, 100)),
      );
    } else {
      _kendi.add(mesajId);
    }
  }

  /// Kanal açar; hata fırlatılır (Tayfam-Api #183). Kitle [kitle]:
  /// etkinlik kanalında [etkinlikId] zorunludur, seçili kişi kanalında
  /// [kisiler] ilk üyelerdir (açan her zaman içeridedir; boşsa
  /// gönderilmez). Kim açabileceğine sunucu karar verir.
  Future<Channel> olustur({
    required String ad,
    required KanalKitlesi kitle,
    required int yavasModSaniye,
    String? etkinlikId,
    List<String> kisiler = const [],
  }) async {
    final kanal = await ref
        .read(kanalDeposuProvider)
        .olustur(
          tayfaId,
          ChannelCreateRequest(
            name: ad,
            visibility: kitle.olusturmaDegeri,
            slowModeSeconds: yavasModSaniye,
            eventId: kitle == KanalKitlesi.etkinlik ? etkinlikId : null,
            memberUserIds: kitle == KanalKitlesi.secili && kisiler.isNotEmpty
                ? List.unmodifiable(kisiler)
                : null,
          ),
        );
    if (ref.mounted) kanaliYaz(kanal);
    return kanal;
  }

  /// Kanalın adını, görünürlüğünü ya da yavaş modunu değiştirir; yalnızca
  /// değişen alanlar gönderilir. Değişen yoksa istek gitmez. Etkinlik ve
  /// seçili kişi kanallarının görünürlüğü değiştirilemez (sözleşme);
  /// onlarda [yonetimKanali] yok sayılır.
  Future<Channel> guncelle(
    Channel eski, {
    required String ad,
    required bool yonetimKanali,
    required int yavasModSaniye,
  }) async {
    final sabit = KanalKitlesi.kanaldan(eski).sabit;
    final eskiYonetim = eski.visibility == ChannelVisibility.staff;
    final istek = ChannelUpdateRequest(
      name: ad == eski.name ? null : ad,
      visibility: sabit || yonetimKanali == eskiYonetim
          ? null
          : (yonetimKanali
                ? ChannelUpdateRequestVisibility.staff
                : ChannelUpdateRequestVisibility.members),
      slowModeSeconds: yavasModSaniye == eski.slowModeSeconds
          ? null
          : yavasModSaniye,
    );
    if (istek.toJson().isEmpty) return eski;
    final kanal = await ref
        .read(kanalDeposuProvider)
        .guncelle(tayfaId, eski.id, istek);
    if (ref.mounted) kanaliYaz(kanal);
    return kanal;
  }

  /// Seçili kişi kanalına [kisiler]'i ekler (yalnızca kanalı açan; kararı
  /// sunucu verir). Dönen kanal (yeni kişi sayısıyla) listeye yazılır.
  Future<Channel> katilimciEkle(String kanalId, List<String> kisiler) async {
    final kanal = await ref
        .read(kanalDeposuProvider)
        .katilimciEkle(tayfaId, kanalId, kisiler);
    if (ref.mounted) kanaliYaz(kanal);
    return kanal;
  }

  /// Seçili kişi kanalından [kisi]'yi çıkarır. Ardından kanal yeniden
  /// okunur ki kişi sayısı güncellensin; okunamazsa eldeki kalır.
  Future<void> katilimciCikar(String kanalId, String kisi) async {
    final depo = ref.read(kanalDeposuProvider);
    await depo.katilimciCikar(tayfaId, kanalId, kisi);
    try {
      final kanal = await depo.kanal(tayfaId, kanalId);
      if (ref.mounted) kanaliYaz(kanal);
    } on Exception {
      // Sayı bir sonraki yenilemede düzelir.
    }
  }

  /// Kanalı arşivler ya da arşivden çıkarır.
  Future<Channel> arsivle(String kanalId, {required bool arsivde}) async {
    final kanal = await ref
        .read(kanalDeposuProvider)
        .arsivle(tayfaId, kanalId, arsivde: arsivde);
    if (ref.mounted) kanaliYaz(kanal);
    return kanal;
  }

  /// Oluşturulan ya da değiştirilen kanalı listeye yazar.
  void kanaliYaz(Channel kanal) {
    final liste = state.value;
    if (liste == null) return;
    final mevcut = liste.any((k) => k.id == kanal.id);
    final yeni = mevcut
        ? [
            for (final k in liste)
              if (k.id == kanal.id)
                _okunmamisIle(kanal, k.unreadCount ?? 0)
              else
                k,
          ]
        : [...liste, kanal];
    _ayarla(kanalSirala(yeni));
  }

  // ------------------------------------------------------------------ iç

  void _ayarla(List<Channel> kanallar) {
    state = AsyncData(List.unmodifiable(kanallar));
    _abonelikleriAyarla(kanallar);
  }

  void _abonelikleriAyarla([List<Channel>? kanallar]) {
    final liste = kanallar ?? state.value;
    if (liste == null) return;
    final acik = ref.read(acikKanalProvider);
    ref.read(realtimeIstemcisiProvider).abonelikleriAyarla(tayfaId, [
      for (final k in liste)
        if (k.archivedAt == null) (tayfaId: tayfaId, kanalId: k.id),
    ], oncelikli: acik?.tayfaId == tayfaId ? acik : null);
  }

  void _degistir(String kanalId, Channel Function(Channel) degistir) {
    final liste = state.value;
    if (liste == null) return;
    state = AsyncData(
      List.unmodifiable([
        for (final k in liste)
          if (k.id == kanalId) degistir(k) else k,
      ]),
    );
  }

  void _kuyrukOlayi(KuyrukOlayi olay) {
    if (olay
        case KuyrukGonderildi(
          isi: KanalMesajIsi(tayfaId: final t, :final kanalId),
          :final ChannelMessage sonuc,
        )
        when t == tayfaId) {
      kendiMesajim(kanalId, sonuc.id);
    }
  }

  void _olay(RealtimeOlayi olay) {
    switch (olay) {
      case KanalMesajiGeldi(:final mesaj, :final kanal, geriAlindi: false)
          when kanal.tayfaId == tayfaId:
        if (_kendi.remove(mesaj.id)) return;
        if (ref.read(acikKanalProvider) == kanal) return;
        final sayilan = _sayilan.putIfAbsent(mesaj.channelId, () => {});
        if (!sayilan.add(mesaj.id)) return;
        _degistir(
          mesaj.channelId,
          (k) => _okunmamisIle(
            k,
            ((k.unreadCount ?? 0) + 1).clamp(0, okunmamisUstSinir),
          ),
        );
      case AbonelikBitti(:final kanal, :final neden)
          when kanal.tayfaId == tayfaId:
        if (neden == AbonelikBitisNedeni.erisimKalmadi) {
          final liste = state.value;
          if (liste != null) {
            _ayarla([
              for (final k in liste)
                if (k.id != kanal.kanalId) k,
            ]);
          }
        } else if (neden == AbonelikBitisNedeni.bulunamadi) {
          unawaited(yenile());
        }
      case Baglandi():
        // Kopukken gelen mesajların sayısı REST'ten alınır.
        if (state.hasValue) unawaited(yenile());
      default:
        break;
    }
  }
}

/// Sunucunun sırası: arşivlenmemişler önce, arşivlenenler sonda.
List<Channel> kanalSirala(List<Channel> kanallar) => [
  for (final k in kanallar)
    if (k.archivedAt == null) k,
  for (final k in kanallar)
    if (k.archivedAt != null) k,
];

Channel _okunmamisIle(Channel k, int sayi) => Channel(
  id: k.id,
  tayfaId: k.tayfaId,
  name: k.name,
  visibility: k.visibility,
  slowModeSeconds: k.slowModeSeconds,
  creatorUserId: k.creatorUserId,
  archivedAt: k.archivedAt,
  createdAt: k.createdAt,
  updatedAt: k.updatedAt,
  unreadCount: sayi,
  lastReadMessageId: k.lastReadMessageId,
  eventId: k.eventId,
  memberCount: k.memberCount,
  archiveAt: k.archiveAt,
);

/// [etkinlikId] etkinliğinin görebildiğin kanalı: arşivlenmemiş olan
/// önce; yoksa `null`. Etkinlik kanalını yalnızca kitlesi görür
/// (Tayfam-Api #183).
Channel? etkinlikKanali(List<Channel> kanallar, String etkinlikId) {
  Channel? arsivde;
  for (final k in kanallar) {
    if (k.visibility != ChannelVisibility.event || k.eventId != etkinlikId) {
      continue;
    }
    if (k.archivedAt == null) return k;
    arsivde ??= k;
  }
  return arsivde;
}

/// Tayfanın kanalları (`family(tayfaId)` + `autoDispose`; ADR-0001).
final kanallarProvider = AsyncNotifierProvider.autoDispose
    .family<KanallarNotifier, List<Channel>, String>(
      KanallarNotifier.new,
      name: 'kanallarProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Aktif tayfanın kanallarındaki okunmamış mesaj toplamı (Sohbet sekmesi
/// rozeti; ADR-0003). Liste yoksa ya da okunamadıysa 0. Kabuk bunu
/// izlediği için aktif tayfanın kanal listesi (ve abonelikleri) uygulama
/// açıkken canlı kalır.
final okunmamisKanalSayisiProvider = Provider<int>((ref) {
  final tayfaId = ref.watch(aktifTayfaIdProvider);
  if (tayfaId == null) return 0;
  final liste = ref.watch(kanallarProvider(tayfaId)).value;
  if (liste == null) return 0;
  var toplam = 0;
  for (final k in liste) {
    if (k.archivedAt == null) toplam += k.unreadCount ?? 0;
  }
  return toplam;
}, name: 'okunmamisKanalSayisiProvider');
