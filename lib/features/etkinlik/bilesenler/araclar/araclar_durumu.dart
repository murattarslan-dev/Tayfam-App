import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınırlar (`EventVehicleRequest`).
const int aracMarkaEnCok = 40;
const int aracModelEnCok = 40;
const int aracRenkEnCok = 30;
const int plakaEnAz = 2;
const int plakaEnCok = 16;
const int aracYiliEnAz = 1900;
const int koltukEnCok = 8;

/// Plaka: harf, rakam ve kelimeler arasında tek boşluk (sözleşme).
final RegExp _plakaBicimi = RegExp(
  r'^[\p{L}\p{N}]+( [\p{L}\p{N}]+)*$',
  unicode: true,
);

int _uzunluk(String metin) => metin.runes.length;

String? _doluysa(String metin) {
  final kirpik = metin.trim();
  return kirpik.isEmpty ? null : kirpik;
}

/// Araç formundaki bir alanın hatası.
enum AracHatasi { marka, model, yil, renk, plaka, koltuk }

/// Araç formu. Plaka isteğe bağlıdır ve yalnızca [plakaAcik] ise gönderilir
/// (bileşenin `plate` parametresi; sunucu 30 günde siler). Boş koltuk
/// yalnızca [koltukAcik] ise gönderilir (`seats` parametresi; boşsa 0).
/// [buYil] yerel takvimdeki yıl; model yılı en çok gelecek yıl olabilir.
///
/// [garajAraci] verilirse araç kendi garajından seçilmiştir (Tayfam-Api
/// ADR-0040 §4): marka, model, yıl ve renk gönderilmez, sunucu garajdan
/// kopyalar; yalnızca plaka ve koltuk bu kayda yazılır.
///
/// Hata yoksa istek, varsa yalnızca hatalar döner.
({EventVehicleRequest? istek, Set<AracHatasi> hatalar}) aracIstegi({
  String? garajAraci,
  String marka = '',
  String model = '',
  String yil = '',
  String renk = '',
  String plaka = '',
  String koltuk = '',
  bool plakaAcik = false,
  bool koltukAcik = false,
  required int buYil,
}) {
  final hatalar = <AracHatasi>{};
  final garajdan = garajAraci != null;
  final m = garajdan ? '' : marka.trim();
  if (!garajdan && (m.isEmpty || _uzunluk(m) > aracMarkaEnCok)) {
    hatalar.add(AracHatasi.marka);
  }
  if (!garajdan && _uzunluk(model.trim()) > aracModelEnCok) {
    hatalar.add(AracHatasi.model);
  }
  if (!garajdan && _uzunluk(renk.trim()) > aracRenkEnCok) {
    hatalar.add(AracHatasi.renk);
  }
  int? modelYili;
  final yilMetni = garajdan ? '' : yil.trim();
  if (yilMetni.isNotEmpty) {
    modelYili = int.tryParse(yilMetni);
    if (modelYili == null ||
        modelYili < aracYiliEnAz ||
        modelYili > buYil + 1) {
      hatalar.add(AracHatasi.yil);
    }
  }
  final p = plakaAcik ? plaka.trim() : '';
  if (p.isNotEmpty &&
      (_uzunluk(p) < plakaEnAz ||
          _uzunluk(p) > plakaEnCok ||
          !_plakaBicimi.hasMatch(p))) {
    hatalar.add(AracHatasi.plaka);
  }
  int? koltukSayisi;
  final koltukMetni = koltukAcik ? koltuk.trim() : '';
  if (koltukMetni.isNotEmpty) {
    koltukSayisi = int.tryParse(koltukMetni);
    if (koltukSayisi == null ||
        koltukSayisi < 0 ||
        koltukSayisi > koltukEnCok) {
      hatalar.add(AracHatasi.koltuk);
    }
  }
  if (hatalar.isNotEmpty) return (istek: null, hatalar: hatalar);
  return (
    istek: EventVehicleRequest(
      garageVehicleId: garajAraci,
      make: garajdan ? null : m,
      model: garajdan ? null : _doluysa(model),
      modelYear: modelYili,
      color: garajdan ? null : _doluysa(renk),
      plate: _doluysa(p),
      seats: koltukSayisi,
    ),
    hatalar: const {},
  );
}

/// Araçtaki boş koltuk sayısı: sahibinin yazdığı koltuklardan onaylanmış
/// yolcular düşülür.
int bosKoltuk(EventVehicle arac) {
  final bos = arac.seats - arac.riderUserIds.length;
  return bos < 0 ? 0 : bos;
}

/// Bir etkinliğin bir araçlar bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef AracKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Listenin yeniden okunmasını gerektiren hatalar: liste başkasının
/// işlemiyle değişmiş (koltuk doldu, istek ya da araç kalktı).
const Set<ProblemType> _bayatListeHatalari = {
  ProblemType.vehicleFull,
  ProblemType.vehicleSeatsTaken,
  ProblemType.seatRequestDriver,
  ProblemType.eventItemNotFound,
  ProblemType.eventNotGoing,
};

/// Araçlar bileşeninin araçları (`GET …/components/{component_key}/vehicles`;
/// Tayfam-Api #240), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): bileşen değişince ve katılım cevabın değişince REST'ten
/// yeniden okunur. Plaka kişisel veridir: yalnızca bellekte tutulur,
/// önbelleğe alınmaz, loglanmaz.
///
/// Yazan her uç araçların güncel halini döner; durum onunla değişir.
/// Yetki sunucudadır; istemci yalnızca düğmeleri sadeleştirir (kesin
/// kural 5).
class AraclarNotifier extends AsyncNotifier<EventVehicles> {
  AraclarNotifier(this.kimlik);

  final AracKimligi kimlik;

  @override
  Future<EventVehicles> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    // Plaka ve koltuk isteği "Geliyorum" cevabına bağlıdır.
    ref.watch(
      etkinlikDetayProvider(etkinlik).select((d) => d.value?.callerRsvp),
    );
    return ref
        .read(etkinlikDeposuProvider)
        .araclar(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Kendi aracını yazar; önceki aracının yerini alır.
  Future<Object?> aracYaz(EventVehicleRequest istek) => _yaz(
    (d) => d.aracYaz(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, istek),
  );

  /// Aracı koltuk istekleriyle birlikte çıkarır.
  Future<Object?> aracCikar(String aracId) => _yaz(
    (d) =>
        d.aracCikar(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, aracId),
  );

  /// Bu araçta koltuk ister.
  Future<Object?> koltukIste(String aracId) => _yaz(
    (d) =>
        d.koltukIste(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, aracId),
  );

  /// Araç sahibi [kullaniciId]'nin isteğini onaylar.
  Future<Object?> koltukOnayla(String aracId, String kullaniciId) => _yaz(
    (d) => d.koltukOnayla(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      aracId,
      kullaniciId,
    ),
  );

  /// [kullaniciId]'nin bu araçtaki isteğini kaldırır: geri çekme, reddetme
  /// ya da yolcuyu çıkarma.
  Future<Object?> koltukBirak(String aracId, String kullaniciId) => _yaz(
    (d) => d.koltukBirak(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      aracId,
      kullaniciId,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Liste bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(
    Future<EventVehicles> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final araclar = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(araclar);
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

/// Bir araçlar bileşeninin durumu. Hata otomatik yeniden denenmez.
final araclarProvider = AsyncNotifierProvider.autoDispose
    .family<AraclarNotifier, EventVehicles, AracKimligi>(
      AraclarNotifier.new,
      name: 'araclarProvider',
      retry: yenidenDenemeYok,
    );
