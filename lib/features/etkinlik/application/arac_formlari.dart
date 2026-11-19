import 'package:tayfam/core/api/gen/models.dart';

/// Sözleşmedeki sınırlar (`CampItemCreateRequest`,
/// `FishingCatchCreateRequest`). Araç formu `vehicles` bileşenindedir
/// (`bilesenler/araclar/`, #228).
const int malzemeAdiEnCok = 60;
const int malzemeAdediEnCok = 999;
const int avTuruEnCok = 60;
const double avBoyuEnCok = 1000;

int _uzunluk(String metin) => metin.runes.length;

/// Kamp malzemesi formundaki bir alanın hatası.
enum MalzemeHatasi { ad, adet }

/// Kamp malzemesi formu; adet boşsa sunucu 1 sayar. [getiren] "Kim
/// getirecek?" seçimidir (`assigned_user_id`; kendisi ya da seçilen kişi);
/// `null` ise "Henüz kimse" ve alan gönderilmez.
({CampItemCreateRequest? istek, Set<MalzemeHatasi> hatalar}) malzemeIstegi({
  required String ad,
  String adet = '',
  String? getiren,
}) {
  final hatalar = <MalzemeHatasi>{};
  final a = ad.trim();
  if (a.isEmpty || _uzunluk(a) > malzemeAdiEnCok) hatalar.add(MalzemeHatasi.ad);
  int? sayi;
  final adetMetni = adet.trim();
  if (adetMetni.isNotEmpty) {
    sayi = int.tryParse(adetMetni);
    if (sayi == null || sayi < 1 || sayi > malzemeAdediEnCok) {
      hatalar.add(MalzemeHatasi.adet);
    }
  }
  if (hatalar.isNotEmpty) return (istek: null, hatalar: hatalar);
  return (
    istek: CampItemCreateRequest(
      name: a,
      quantity: sayi,
      assignedUserId: getiren,
    ),
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
