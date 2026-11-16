import 'dart:typed_data';

import 'package:tayfam/core/e2e/mesaj/zarf_icerigi.dart';

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

/// Zarfın düz metin içeriği (ADR-0020, istemci ADR-0028 §3): `{v:1,
/// t:"metin", govde}`, `{v:1, t:"foto", ek:{…}}` ya da `{v:1, t:"yer",
/// enlem, boylam, ad?}`; UTF-8 JSON, dolgulu. Yalnızca bellekte yaşar.
Uint8List zarfIcerigiKodla(BirebirIcerik icerik) =>
    dolguEkle(icerikJsonu(icerik));

/// Çözülmüş zarf baytlarından mesajın içeriğini okur. Biçim bozuksa,
/// sürüm ya da tür tanınmıyorsa veya bir alan sınır dışındaysa `null`
/// (zarf çözülemedi sayılır).
BirebirIcerik? zarfIcerigiCoz(Uint8List duz) {
  final ham = dolguKaldir(duz);
  if (ham == null) return null;
  final json = icerikNesnesi(ham);
  if (json == null) return null;
  return BirebirIcerik.oku(json);
}
