import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınır: bir kayıtta en çok bu kadar alan değeri
/// (`EventLogEntryCreateRequest.values`).
const int gunlukAlanEnCok = 8;

/// Bir etkinliğin bir günlük bileşeni: bileşen uçlarındaki
/// `{component_key}` ile (bir etkinlikte birden çok günlük olabilir).
typedef GunlukKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Günlüğün kayıt alanları: bileşenin `fields` parametresi (`CatalogField`
/// listesi; ADR-0024 §3). Tanım girdidir: biçimi bozuk, anahtarı geçersiz
/// ya da tekrar eden alan atlanır; en çok [gunlukAlanEnCok] alan alınır.
List<CatalogField> gunlukAlanlari(BilesenParametreleri params) {
  final gorulen = <String>{};
  final alanlar = <CatalogField>[];
  for (final ham in params.nesneler('fields')) {
    final CatalogField alan;
    try {
      alan = CatalogField.fromJson(ham);
    } on FormatException {
      continue;
    }
    if (!katalogAnahtariMi(alan.key) || !gorulen.add(alan.key)) continue;
    alanlar.add(alan);
    if (alanlar.length == gunlukAlanEnCok) break;
  }
  return List.unmodifiable(alanlar);
}

/// Kayıt formundaki bir hata (alanların hataları ayrıca döner).
enum GunlukHatasi {
  /// Hiçbir alana değer girilmedi (zorunlu alanı olmayan günlükte de kayıt
  /// boş olamaz).
  bos,
}

/// Kayıt formundan `POST …/entries` gövdesi. Değerler tanıma göre
/// doğrulanır ([alanHatalari]); hata varsa istek yerine hatalar döner.
/// Yer yalnızca [yer] seçildiyse gider: kişinin haritada bilerek
/// işaretlediği noktadır, cihazın konumu değildir (ADR-0008); görünürlük
/// yalnızca yerle gönderilir.
({
  EventLogEntryCreateRequest? istek,
  Map<String, AlanHatasi> alanHatalari,
  Set<GunlukHatasi> hatalar,
})
gunlukIstegi({
  required List<CatalogField> alanlar,
  required AlanDegerleri degerler,
  LatLng? yer,
  LogLocationVisibility? gorunurluk,
  String? fotograf,
  required String istekKimligi,
}) {
  final alanHatasi = alanHatalari(alanlar, degerler);
  if (alanHatasi.isNotEmpty) {
    return (istek: null, alanHatalari: alanHatasi, hatalar: const {});
  }
  final govde = alanGovdesi(alanlar, degerler);
  if (govde.isEmpty) {
    return (
      istek: null,
      alanHatalari: const {},
      hatalar: const {GunlukHatasi.bos},
    );
  }
  return (
    istek: EventLogEntryCreateRequest(
      values: govde,
      location: yer,
      locationVisibility: yer == null ? null : gorunurluk,
      photoUploadId: fotograf,
      clientRequestId: istekKimligi,
    ),
    alanHatalari: const {},
    hatalar: const {},
  );
}

/// Günlüğün yeniden okunmasını gerektiren hatalar: kayıt başkasının
/// işlemiyle ya da etkinliğin/bileşenin durumuyla değişmiş.
const Set<ProblemType> _bayatGunlukHatalari = {
  ProblemType.eventItemNotFound,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.notAttended,
};

/// Günlük bileşeninin kayıtları (`GET …/components/{component_key}/entries`;
/// Tayfam-Api #243), eskiden yeniye, sayfalı. Yalnızca bellektedir
/// (ADR-0006). Bölüm açıkken canlıdır (ADR-0024 §5): bileşen değişince ve
/// katılımın doğrulanınca REST'ten yeniden okunur (`caller_can_add`
/// doğrulanmış katılıma bağlıdır).
///
/// Konum gizliliği sunucunundur: bir kaydın yeri yalnızca sunucu
/// döndürdüyse gösterilir. Yetki sunucudadır; istemci yalnızca düğmeleri
/// sadeleştirir (kesin kural 5).
class GunlukNotifier extends SayfaliListeNotifier<EventLogEntry> {
  GunlukNotifier(this.bilesen);

  final GunlukKimligi bilesen;

  EventLogEntryList? _bilgi;

  /// Son okunan sayfa: günlüğün parametreleri (`location_enabled`,
  /// `location_default`, `max_entries`) ve `caller_can_add`. Liste
  /// okunmadan `null`.
  EventLogEntryList? get bilgi => _bilgi;

  @override
  Future<SayfaliListe<EventLogEntry>> build() {
    final etkinlik = (tayfaId: bilesen.tayfaId, etkinlikId: bilesen.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, bilesen.anahtar);
    ref.watch(
      etkinlikDetayProvider(etkinlik)
          .select((d) => (d.value?.callerAttendance, d.value?.status)),
    );
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<EventLogEntry>> sayfaGetir(String? sayfaToken) async {
    final liste = await ref
        .read(etkinlikDeposuProvider)
        .gunlukKayitlari(
          bilesen.tayfaId,
          bilesen.etkinlikId,
          bilesen.anahtar,
          sayfaToken: sayfaToken,
        );
    _bilgi = liste;
    return (ogeler: liste.entries, sonraki: liste.nextPageToken);
  }

  @override
  String kimlik(EventLogEntry oge) => oge.id;

  /// Günlüğe kayıt ekler; eklenen kayıt listenin sonuna konur. Tekrar
  /// denemede aynı `client_request_id` gönderilir (form açılınca bir kez
  /// üretilir). Başarıda `null`, değilse hata döner.
  Future<Object?> ekle(EventLogEntryCreateRequest istek) => _yaz(() async {
    final kayit = await ref
        .read(etkinlikDeposuProvider)
        .gunlugeEkle(
          bilesen.tayfaId,
          bilesen.etkinlikId,
          bilesen.anahtar,
          istek,
        );
    if (!ref.mounted) return;
    ogeleriDegistir(
      (kayitlar) => [
        for (final k in kayitlar)
          if (k.id != kayit.id) k,
        kayit,
      ],
    );
  });

  /// Kaydı günlükten çıkarır.
  Future<Object?> cikar(String kayitId) => _yaz(() async {
    await ref
        .read(etkinlikDeposuProvider)
        .gunluktenCikar(
          bilesen.tayfaId,
          bilesen.etkinlikId,
          bilesen.anahtar,
          kayitId,
        );
    if (!ref.mounted) return;
    ogeleriDegistir(
      (kayitlar) => [
        for (final k in kayitlar)
          if (k.id != kayitId) k,
      ],
    );
  });

  /// Başarıda `null`, değilse hata döner; hata çağıranda gösterilir.
  /// Günlük bayatlamışsa (kayıt silinmiş, günlük donmuş, etkinlik iptal)
  /// yeniden okunur.
  Future<Object?> _yaz(Future<void> Function() islem) async {
    try {
      await islem();
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatGunlukHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir günlük bileşeninin durumu; detay ekranı kapanınca bırakılır. Hata
/// otomatik yeniden denenmez.
final gunlukProvider = AsyncNotifierProvider.autoDispose
    .family<GunlukNotifier, SayfaliListe<EventLogEntry>, GunlukKimligi>(
      GunlukNotifier.new,
      name: 'gunlukProvider',
      retry: yenidenDenemeYok,
    );
