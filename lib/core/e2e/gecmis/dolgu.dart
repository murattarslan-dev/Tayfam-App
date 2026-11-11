import 'dart:typed_data';

/// Düz metin dolgusunun blok boyu (Signal'deki gibi 160 bayt). Arşiv
/// kaydı, eşleştirme cevabı, anahtar paylaşımı ve zarf düz metni aynı
/// yardımcıyı kullanır: uzunluk yalnızca 160'ın katı olarak görünür.
const int dolguBlogu = 160;

/// ISO/IEC 7816-4 dolgusu: [veri] ‖ 0x80 ‖ 0x00…, uzunluk [dolguBlogu]'nun
/// katı. Boş veri de bir blok olur.
Uint8List dolgula(Uint8List veri) {
  final uzunluk =
      ((veri.length + 1 + dolguBlogu - 1) ~/ dolguBlogu) * dolguBlogu;
  return Uint8List(uzunluk)
    ..setAll(0, veri)
    ..[veri.length] = 0x80;
}

/// [dolgula]'nın tersi. Uzunluk blok katı değilse ya da işaret baytı
/// yoksa `null`.
Uint8List? dolguyuKaldir(Uint8List veri) {
  if (veri.isEmpty || veri.length % dolguBlogu != 0) return null;
  var i = veri.length - 1;
  while (i >= 0 && veri[i] == 0) {
    i--;
  }
  if (i < 0 || veri[i] != 0x80) return null;
  return Uint8List.fromList(Uint8List.sublistView(veri, 0, i));
}
