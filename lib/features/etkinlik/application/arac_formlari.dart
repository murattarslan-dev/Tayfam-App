import 'package:tayfam/core/api/gen/models.dart';

/// Sözleşmedeki sınırlar (`FishingCatchCreateRequest`). Araç formu
/// `vehicles` (`bilesenler/araclar/`, #228), malzeme formu `checklist`
/// bileşenindedir (`bilesenler/liste/`, #229).
const int avTuruEnCok = 60;
const double avBoyuEnCok = 1000;

int _uzunluk(String metin) => metin.runes.length;

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
