// Katalog ikon haritasının anahtar listesi (ADR-0024 §2).
//
// İstemcinin sabit ikon haritası (`lib/core/katalog/ikonlar.dart`) ile
// Tayfam-Api platform panelinin ikon listesi aynı anahtarları taşımalıdır:
// panel haritada olmayan bir ikon seçtirirse istemci genel ikon gösterir.
// Bu kütüphane haritadaki anahtarları okur ve başka bir listeyle
// karşılaştırır. Flutter'a bağlı değildir (harita kaynak metninden okunur).

/// İkon haritasının kaynak dosyası.
const String ikonHaritasiDosyasi = 'lib/core/katalog/ikonlar.dart';

final RegExp _haritaBasi = RegExp(
  r'const\s+Map<String,\s*IconData>\s+katalogIkonlari\s*=\s*\{',
);

final RegExp _satir = RegExp(r"^\s*'([^']*)'\s*:\s*Icons\.\w+,\s*$");

final RegExp _anahtar = RegExp(r'^[a-z][a-z0-9_]{1,39}$');

/// Haritanın biçimi beklenenden farklıysa fırlatılır.
final class IkonHaritasiHatasi implements Exception {
  IkonHaritasiHatasi(this.mesaj);

  final String mesaj;

  @override
  String toString() => 'katalog_ikonlari: $mesaj';
}

/// [kaynak]'taki (`ikonlar.dart`) `katalogIkonlari` haritasının anahtarları,
/// sıralı. Harita bulunamazsa, bir satır `'anahtar': Icons.ad,` biçiminde
/// değilse, anahtar biçimsiz ya da yinelenmişse [IkonHaritasiHatasi].
List<String> ikonAnahtarlari(String kaynak) {
  final bas = _haritaBasi.firstMatch(kaynak);
  if (bas == null) {
    throw IkonHaritasiHatasi('katalogIkonlari haritası bulunamadı');
  }
  final son = kaynak.indexOf('};', bas.end);
  if (son < 0) throw IkonHaritasiHatasi('harita kapanmıyor');
  final anahtarlar = <String>{};
  for (final satir in kaynak.substring(bas.end, son).split('\n')) {
    if (satir.trim().isEmpty || satir.trim().startsWith('//')) continue;
    final eslesme = _satir.firstMatch(satir);
    if (eslesme == null) {
      throw IkonHaritasiHatasi('beklenmeyen satır: ${satir.trim()}');
    }
    final anahtar = eslesme.group(1)!;
    if (!_anahtar.hasMatch(anahtar)) {
      throw IkonHaritasiHatasi('biçimsiz anahtar: $anahtar');
    }
    if (!anahtarlar.add(anahtar)) {
      throw IkonHaritasiHatasi('yinelenen anahtar: $anahtar');
    }
  }
  if (anahtarlar.isEmpty) throw IkonHaritasiHatasi('harita boş');
  return anahtarlar.toList()..sort();
}

/// Satır başına bir anahtar taşıyan liste metnindeki anahtarlar (boş
/// satırlar ve `#` ile başlayan yorumlar atlanır), sıralı ve tekil.
List<String> listeAnahtarlari(String metin) => {
  for (final satir in metin.split('\n'))
    if (satir.trim().isNotEmpty && !satir.trim().startsWith('#')) satir.trim(),
}.toList()..sort();

/// İki anahtar listesinin farkı.
final class IkonFarki {
  const IkonFarki({required this.eksik, required this.fazla});

  /// İstemci haritasında olup öteki listede olmayanlar.
  final List<String> eksik;

  /// Öteki listede olup istemci haritasında olmayanlar (istemci bunlar
  /// için genel ikon gösterir).
  final List<String> fazla;

  bool get ayni => eksik.isEmpty && fazla.isEmpty;
}

/// İstemci haritasındaki [istemci] anahtarlarını [diger] listeyle
/// karşılaştırır.
IkonFarki ikonlariKarsilastir(List<String> istemci, List<String> diger) =>
    IkonFarki(
      eksik: [
        for (final a in istemci)
          if (!diger.contains(a)) a,
      ],
      fazla: [
        for (final a in diger)
          if (!istemci.contains(a)) a,
      ],
    );
