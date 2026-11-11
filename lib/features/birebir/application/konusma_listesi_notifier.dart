import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/birebir/application/birebir_islemi.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';

/// Konuşmaların sırası (sunucuyla aynı): son mesajı en yeni olan önce.
int konusmaSirasi(Conversation a, Conversation b) {
  final zaman = b.lastMessageAt.compareTo(a.lastMessageAt);
  return zaman != 0 ? zaman : a.id.compareTo(b.id);
}

/// [konusma]'nın okunmamış sayısı sıfırlanmış ve okundu işareti
/// [mesajId]'ye taşınmış hali (modellerde `copyWith` yoktur).
Conversation okunduOlarak(Conversation konusma, String mesajId) => Conversation(
  id: konusma.id,
  otherUserId: konusma.otherUserId,
  status: konusma.status,
  unreadCount: 0,
  lastReadMessageId: mesajId,
  peerLastReadMessageId: konusma.peerLastReadMessageId,
  lastMessageAt: konusma.lastMessageAt,
  createdAt: konusma.createdAt,
);

/// Kullanıcının birebir konuşmaları (`GET
/// /v1/direct-messages/conversations`, sayfalı; ADR-0018 §9).
///
/// Oturum boyunca yaşar (Sohbet sekmesinin rozeti de buradan okunur) ve
/// oturum değişince yeniden kurulur (ADR-0001 kural 8). Oturum açık
/// değilse istek atmadan boş döner. Yalnızca bellektedir (ADR-0006).
/// Mesaj istekleri (`request_received`) aynı listededir; ekranlar ayırır.
class KonusmaListesiNotifier extends SayfaliListeNotifier<Conversation> {
  @override
  Future<SayfaliListe<Conversation>> build() async {
    final oturum = ref.watch(oturumDurumuProvider);
    ref.watch(birebirDeposuProvider);
    if (oturum != OturumDurumu.acik) return const SayfaliListe(ogeler: []);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Conversation>> sayfaGetir(String? sayfaToken) =>
      ref.read(birebirDeposuProvider).konusmalar(sayfaToken: sayfaToken);

  @override
  String kimlik(Conversation oge) => oge.id;

  /// Sunucudan gelen [konusma]'yı listeye yansıtır (yeni ya da değişmiş)
  /// ve sırayı korur.
  void yansit(Conversation konusma) => ogeleriDegistir(
    (ogeler) => [
      konusma,
      for (final k in ogeler)
        if (k.id != konusma.id) k,
    ]..sort(konusmaSirasi),
  );

  /// Konuşmayı listeden çıkarır (reddedilen istek).
  void cikar(String konusmaId) => ogeleriDegistir(
    (ogeler) => [
      for (final k in ogeler)
        if (k.id != konusmaId) k,
    ],
  );

  /// Listede yüklü konuşmalardan [kullaniciId] ile olanı; yoksa `null`.
  Conversation? kisiyle(String kullaniciId) {
    for (final k in state.value?.ogeler ?? const <Conversation>[]) {
      if (k.otherUserId == kullaniciId) return k;
    }
    return null;
  }
}

/// Kullanıcının birebir konuşmaları. Hata otomatik yeniden denenmez;
/// ekranlar "Tekrar dene" sunar, aşağı çekince yenilenir.
final konusmaListesiProvider =
    AsyncNotifierProvider<KonusmaListesiNotifier, SayfaliListe<Conversation>>(
      KonusmaListesiNotifier.new,
      name: 'konusmaListesiProvider',
      retry: yenidenDenemeYok,
    );

/// Yüklü konuşmalardaki okunmamış birebir mesaj sayısı (Sohbet sekmesinin
/// rozeti). Liste okunamadıysa 0.
final birebirOkunmamisSayisiProvider = Provider<int>((ref) {
  final liste = ref.watch(konusmaListesiProvider).value;
  if (liste == null) return 0;
  return liste.ogeler.fold(0, (toplam, k) => toplam + k.unreadCount);
}, name: 'birebirOkunmamisSayisiProvider');

/// Yüklü konuşmalardan size gelen mesaj istekleri (`request_received`).
final mesajIstekleriProvider = Provider<List<Conversation>>((ref) {
  final liste = ref.watch(konusmaListesiProvider).value;
  if (liste == null) return const [];
  return [
    for (final k in liste.ogeler)
      if (k.status == ConversationStatus.requestReceived) k,
  ];
}, name: 'mesajIstekleriProvider');
