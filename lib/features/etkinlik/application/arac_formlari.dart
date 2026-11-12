import 'package:tayfam/core/api/gen/models.dart';

/// Sözleşmedeki sınırlar (`ConvoyVehicleCreateRequest`,
/// `CampItemCreateRequest`, `FishingCatchCreateRequest`).
const int aracMarkaEnCok = 40;
const int aracModelEnCok = 40;
const int aracRenkEnCok = 30;
const int plakaEnAz = 2;
const int plakaEnCok = 16;
const int aracYiliEnAz = 1900;
const int malzemeAdiEnCok = 60;
const int malzemeAdediEnCok = 999;
const int avTuruEnCok = 60;
const double avBoyuEnCok = 1000;

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

/// Konvoy aracı formundaki bir alanın hatası.
enum AracHatasi { marka, model, yil, renk, plaka }

/// Konvoy aracı formu (plaka isteğe bağlı; sunucu 30 günde siler).
/// [buYil] yerel takvimdeki yıl; model yılı en çok gelecek yıl olabilir.
///
/// Hata yoksa istek, varsa yalnızca hatalar döner.
({ConvoyVehicleCreateRequest? istek, Set<AracHatasi> hatalar}) aracIstegi({
  required String marka,
  String model = '',
  String yil = '',
  String renk = '',
  String plaka = '',
  required int buYil,
}) {
  final hatalar = <AracHatasi>{};
  final m = marka.trim();
  if (m.isEmpty || _uzunluk(m) > aracMarkaEnCok) hatalar.add(AracHatasi.marka);
  if (_uzunluk(model.trim()) > aracModelEnCok) hatalar.add(AracHatasi.model);
  if (_uzunluk(renk.trim()) > aracRenkEnCok) hatalar.add(AracHatasi.renk);
  int? modelYili;
  final yilMetni = yil.trim();
  if (yilMetni.isNotEmpty) {
    modelYili = int.tryParse(yilMetni);
    if (modelYili == null ||
        modelYili < aracYiliEnAz ||
        modelYili > buYil + 1) {
      hatalar.add(AracHatasi.yil);
    }
  }
  final p = plaka.trim();
  if (p.isNotEmpty &&
      (_uzunluk(p) < plakaEnAz ||
          _uzunluk(p) > plakaEnCok ||
          !_plakaBicimi.hasMatch(p))) {
    hatalar.add(AracHatasi.plaka);
  }
  if (hatalar.isNotEmpty) return (istek: null, hatalar: hatalar);
  return (
    istek: ConvoyVehicleCreateRequest(
      make: m,
      model: _doluysa(model),
      modelYear: modelYili,
      color: _doluysa(renk),
      plate: _doluysa(plaka),
    ),
    hatalar: const {},
  );
}

/// Kamp malzemesi formundaki bir alanın hatası.
enum MalzemeHatasi { ad, adet }

/// Kamp malzemesi formu; adet boşsa sunucu 1 sayar.
({CampItemCreateRequest? istek, Set<MalzemeHatasi> hatalar}) malzemeIstegi({
  required String ad,
  String adet = '',
}) {
  final hatalar = <MalzemeHatasi>{};
  final a = ad.trim();
  if (a.isEmpty || _uzunluk(a) > malzemeAdiEnCok) hatalar.add(MalzemeHatasi.ad);
  int? sayi;
  final adetMetni = adet.trim();
  if (adetMetni.isNotEmpty) {
    sayi = int.tryParse(adetMetni);
    if (sayi == null || sayi < 0 || sayi > malzemeAdediEnCok) {
      hatalar.add(MalzemeHatasi.adet);
    }
  }
  if (hatalar.isNotEmpty) return (istek: null, hatalar: hatalar);
  return (
    istek: CampItemCreateRequest(name: a, quantity: sayi),
    hatalar: const {},
  );
}

/// Av formundaki bir alanın hatası.
enum AvHatasi { tur, boy }

/// Av formu: tür, boy (cm, bir ondalık; Türkçe virgül de kabul edilir),
/// isteğe bağlı yer (kullanıcının haritada bilerek seçtiği nokta; cihaz
/// konumu değildir) ve yerin görünürlüğü.
({FishingCatchCreateRequest? istek, Set<AvHatasi> hatalar}) avIstegi({
  required String tur,
  required String boy,
  LatLng? yer,
  FishingCatchCreateRequestVisibility gorunurluk =
      FishingCatchCreateRequestVisibility.self,
  String? fotograf,
  required String istekKimligi,
}) {
  final hatalar = <AvHatasi>{};
  final t = tur.trim();
  if (t.isEmpty || _uzunluk(t) > avTuruEnCok) hatalar.add(AvHatasi.tur);
  final sayi = double.tryParse(boy.trim().replaceAll(',', '.'));
  final yuvarlak = sayi == null || sayi.isNaN ? null : (sayi * 10).round() / 10;
  if (yuvarlak == null || yuvarlak <= 0 || yuvarlak > avBoyuEnCok) {
    hatalar.add(AvHatasi.boy);
  }
  if (hatalar.isNotEmpty || yuvarlak == null) {
    return (istek: null, hatalar: hatalar);
  }
  return (
    istek: FishingCatchCreateRequest(
      species: t,
      lengthCm: yuvarlak,
      location: yer,
      visibility: yer == null ? null : gorunurluk,
      photoUploadId: fotograf,
      clientRequestId: istekKimligi,
    ),
    hatalar: const {},
  );
}
