import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınırlar (`ChecklistItemRequest`).
const int maddeAdiEnCok = 60;
const int maddeAdediEnCok = 999;

int _uzunluk(String metin) => metin.runes.length;

/// Madde formundaki bir alanın hatası.
enum MaddeHatasi { ad, adet }

/// Madde formu. Adet yalnızca [adetAcik] ise (bileşenin `quantity`
/// parametresi) ve doluysa gönderilir; boşsa sunucu 1 sayar. [ustlenen]
/// "Kim?" seçimidir (`assigned_user_id`; kendisi ya da seçilen kişi);
/// `null` ise "Henüz kimse" ve alan gönderilmez.
///
/// Hata yoksa istek, varsa yalnızca hatalar döner.
({ChecklistItemRequest? istek, Set<MaddeHatasi> hatalar}) maddeIstegi({
  required String ad,
  String adet = '',
  bool adetAcik = true,
  String? ustlenen,
}) {
  final hatalar = <MaddeHatasi>{};
  final a = ad.trim();
  if (a.isEmpty || _uzunluk(a) > maddeAdiEnCok) hatalar.add(MaddeHatasi.ad);
  int? sayi;
  final adetMetni = adetAcik ? adet.trim() : '';
  if (adetMetni.isNotEmpty) {
    sayi = int.tryParse(adetMetni);
    if (sayi == null || sayi < 1 || sayi > maddeAdediEnCok) {
      hatalar.add(MaddeHatasi.adet);
    }
  }
  if (hatalar.isNotEmpty) return (istek: null, hatalar: hatalar);
  return (
    istek: ChecklistItemRequest(
      name: a,
      quantity: sayi,
      assignedUserId: ustlenen,
    ),
    hatalar: const {},
  );
}

/// Listenin çeviri anahtarı (`label`): tanınmayan değer `item` gibi
/// gösterilir.
String listeEtiketi(Checklist liste) =>
    liste.label == ChecklistLabel.unknown ? 'item' : liste.label.wire;

/// Bir etkinliğin bir liste bileşeni: bileşen uçlarındaki
/// `{component_key}` ile (bir etkinlikte birden çok liste olabilir).
typedef ListeKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Listenin yeniden okunmasını gerektiren hatalar: liste başkasının
/// işlemiyle ya da etkinliğin durumuyla değişmiş.
const Set<ProblemType> _bayatListeHatalari = {
  ProblemType.eventItemTaken,
  ProblemType.eventItemNotFound,
  ProblemType.eventNotGoing,
  ProblemType.eventCancelled,
  ProblemType.eventEnded,
};

/// Liste bileşeninin maddeleri (`GET …/components/{component_key}/items`;
/// Tayfam-Api #241), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): bileşen değişince ve katılım cevabın değişince REST'ten
/// yeniden okunur (`caller_can_take` "Geliyorum" cevabına bağlıdır).
///
/// Yazan her uç listenin güncel halini döner; durum onunla değişir. Yetki
/// sunucudadır; istemci yalnızca düğmeleri sadeleştirir (kesin kural 5).
class ListeNotifier extends AsyncNotifier<Checklist> {
  ListeNotifier(this.kimlik);

  final ListeKimligi kimlik;

  @override
  Future<Checklist> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(
      etkinlikDetayProvider(etkinlik).select((d) => d.value?.callerRsvp),
    );
    return ref
        .read(etkinlikDeposuProvider)
        .liste(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Listeye madde ekler (organizatör, moderatör, yönetici).
  Future<Object?> ekle(ChecklistItemRequest istek) => _yaz(
    (d) =>
        d.maddeEkle(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, istek),
  );

  /// Maddeyi listeden çıkarır.
  Future<Object?> cikar(String maddeId) => _yaz(
    (d) =>
        d.maddeCikar(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, maddeId),
  );

  /// Maddeyi [kullaniciId]'ye atar ("Ben getiririm"); `null` ise atamayı
  /// kaldırır ("Vazgeç"; gövdede alan yok).
  Future<Object?> ata(String maddeId, String? kullaniciId) => _yaz(
    (d) => d.maddeAta(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      maddeId,
      kullaniciId,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Liste bayatlamışsa (başkası üstlendi, madde silindi,
  /// etkinlik bitti) yeniden okunur.
  Future<Object?> _yaz(
    Future<Checklist> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final liste = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(liste);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatListeHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir liste bileşeninin durumu. Hata otomatik yeniden denenmez.
final listeProvider = AsyncNotifierProvider.autoDispose
    .family<ListeNotifier, Checklist, ListeKimligi>(
      ListeNotifier.new,
      name: 'listeProvider',
      retry: yenidenDenemeYok,
    );
