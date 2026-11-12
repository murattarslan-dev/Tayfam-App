import 'dart:convert';
import 'dart:typed_data';

/// Dolgu blok boyutu (Signal istemcileriyle aynı: 160 bayt).
const int dolguBlogu = 160;

/// [veri]'nin sonuna `0x80` ve sıfırlar ekleyip uzunluğu [dolguBlogu]'nun
/// katına çıkarır (ISO/IEC 7816-4). Mesaj uzunluğu sunucuya yalnızca blok
/// sayısı olarak görünür. Zarf ve geçmiş arşivi aynı yardımcıyı kullanır.
Uint8List dolguEkle(Uint8List veri) {
  final uzunluk = (veri.length ~/ dolguBlogu + 1) * dolguBlogu;
  final sonuc = Uint8List(uzunluk)..setRange(0, veri.length, veri);
  sonuc[veri.length] = 0x80;
  return sonuc;
}

/// [dolguEkle]'nin tersi. Dolgu bozuksa `null`.
Uint8List? dolguKaldir(Uint8List veri) {
  var i = veri.length - 1;
  while (i >= 0 && veri[i] == 0) {
    i--;
  }
  if (i < 0 || veri[i] != 0x80) return null;
  return Uint8List.sublistView(veri, 0, i);
}

/// Zarfın düz metin içeriği (ADR-0020): `{v:1, t:"metin", govde}` UTF-8,
/// dolgulu. Yalnızca bellekte yaşar.
Uint8List zarfIcerigiKodla(String govde) => dolguEkle(
  Uint8List.fromList(
    utf8.encode(jsonEncode({'v': 1, 't': 'metin', 'govde': govde})),
  ),
);

/// Çözülmüş zarf baytlarından mesaj metnini okur. Biçim bozuksa, sürüm ya
/// da tür tanınmıyorsa `null` (zarf çözülemedi sayılır).
String? zarfIcerigiCoz(Uint8List duz) {
  final ham = dolguKaldir(duz);
  if (ham == null) return null;
  try {
    final json = jsonDecode(utf8.decode(ham));
    if (json is! Map<String, Object?>) return null;
    final govde = json['govde'];
    if (json['v'] != 1 || json['t'] != 'metin' || govde is! String) {
      return null;
    }
    return govde;
  } on FormatException {
    return null;
  }
}
