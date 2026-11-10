// Yönerge (import / export / part) kuralları: ADR-0002'deki katman
// sınırları, özellikler arası döngü ve belirli paketlerin nerede
// kullanılabileceği.

import 'bulgu.dart';
import 'kod_kurallari.dart';
import 'tarayici.dart';

/// Bir `import`, `export` veya `part` yönergesi.
final class Yonerge {
  const Yonerge({required this.tur, required this.uri, required this.ofset});

  /// `import`, `export` veya `part`.
  final String tur;

  /// Yönergedeki adres (koşullu adresler ayrı yönerge sayılır).
  final String uri;

  /// Yönergenin kaynaktaki konumu.
  final int ofset;
}

final RegExp _yonerge = RegExp(
  r"""^[ \t]*(import|export|part)\s+(['"])([^'"]*)\2([^;]*);""",
  multiLine: true,
);

final RegExp _kosulluAdres = RegExp(r"""['"]([^'"]*)['"]""");

/// [t]'deki yönergeler.
List<Yonerge> yonergeleriBul(TaranmisKaynak t) {
  final sonuc = <Yonerge>[];
  for (final m in _yonerge.allMatches(t.yorumsuz)) {
    final ofset = m.start + m.group(0)!.indexOf(m.group(1)!);
    final tur = m.group(1)!;
    sonuc.add(Yonerge(tur: tur, uri: m.group(3)!, ofset: ofset));
    for (final k in _kosulluAdres.allMatches(m.group(4)!)) {
      sonuc.add(Yonerge(tur: tur, uri: k.group(1)!, ofset: ofset));
    }
  }
  return sonuc;
}

/// [kaynakYol]'daki dosyanın [uri] yönergesinin repo içindeki hedefi
/// (`lib/…`); başka bir pakete veya `dart:`'a gidiyorsa `null`.
String? hedefYolu(String kaynakYol, String uri, String paketAdi) {
  final onek = 'package:$paketAdi/';
  if (uri.startsWith(onek)) {
    return 'lib/${uri.substring(onek.length)}';
  }
  if (uri.contains(':')) {
    return null;
  }
  final parcalar = kaynakYol.split('/')..removeLast();
  for (final p in uri.split('/')) {
    if (p == '..') {
      if (parcalar.isEmpty) {
        return null;
      }
      parcalar.removeLast();
    } else if (p != '.' && p.isNotEmpty) {
      parcalar.add(p);
    }
  }
  return parcalar.join('/');
}

/// `package:<ad>/…` adresinin paket adı; değilse `null`.
String? paketAdiniBul(String uri) {
  if (!uri.startsWith('package:')) {
    return null;
  }
  final son = uri.indexOf('/');
  return son < 0 ? null : uri.substring('package:'.length, son);
}

/// lib/ altındaki bir dosyanın katmanı.
enum Katman { core, shell, ozellik, kok, l10n, diger }

final RegExp _ozellikYolu = RegExp(r'^lib/features/([^/]+)/');

/// [yol]'un bağlı olduğu özellik; özellik dosyası değilse `null`.
String? ozellikAdi(String yol) => _ozellikYolu.firstMatch(yol)?.group(1);

/// [yol]'un katmanı.
Katman katman(String yol) {
  if (yol.startsWith('lib/core/')) {
    return Katman.core;
  }
  if (yol.startsWith('lib/shell/')) {
    return Katman.shell;
  }
  if (ozellikAdi(yol) != null) {
    return Katman.ozellik;
  }
  if (yol.startsWith('lib/l10n/')) {
    return Katman.l10n;
  }
  if (RegExp(r'^lib/[^/]+\.dart$').hasMatch(yol)) {
    return Katman.kok;
  }
  return Katman.diger;
}

/// Özelliğin tek dışa açık dosyası.
String disaAcikDosya(String ozellik) => 'lib/features/$ozellik/$ozellik.dart';

/// Özellikler arası bağımlılık kenarı ve ilk görüldüğü yer.
final class OzellikKenari {
  const OzellikKenari({
    required this.kaynak,
    required this.hedef,
    required this.yol,
    required this.ofset,
  });

  final String kaynak;
  final String hedef;
  final String yol;
  final int ofset;
}

/// Paketlerin hangi kurala göre nerede kullanılamayacağı.
final class _PaketKurali {
  const _PaketKurali(this.kural, this.izinliOnek, this.gerekce);

  final KuralTanimi kural;

  /// Bu önekli dosyalarda serbest; `null` ise hiçbir yerde.
  final String? izinliOnek;

  final String gerekce;
}

const Map<String, _PaketKurali> _paketKurallari = {
  'http': _PaketKurali(
    Kurallar.apiTekIstemci,
    'lib/core/api/',
    "HTTP yalnızca ApiClient'tan (lib/core/api/)",
  ),
  'dio': _PaketKurali(
    Kurallar.apiTekIstemci,
    null,
    'ADR-0005 http paketini seçti',
  ),
  'web_socket_channel': _PaketKurali(
    Kurallar.apiTekIstemci,
    'lib/core/realtime/',
    'WebSocket yalnızca lib/core/realtime/\'da',
  ),
  'shared_preferences': _PaketKurali(
    Kurallar.diskeYazma,
    null,
    'içerik diske yazılmaz',
  ),
  'path_provider': _PaketKurali(
    Kurallar.diskeYazma,
    null,
    'içerik diske yazılmaz',
  ),
  'sqflite': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'hive': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'hive_flutter': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'isar': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'drift': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'sembast': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'get_storage': _PaketKurali(Kurallar.diskeYazma, null, 'disk önbelleği yok'),
  'google_fonts': _PaketKurali(
    Kurallar.googleFonts,
    null,
    'font uygulamaya gömülüdür',
  ),
  'riverpod_annotation': _PaketKurali(
    Kurallar.kodUretimi,
    null,
    'provider\'lar elle tanımlanır',
  ),
  'freezed_annotation': _PaketKurali(
    Kurallar.kodUretimi,
    null,
    'modeller üreticiden gelir',
  ),
  'json_annotation': _PaketKurali(
    Kurallar.kodUretimi,
    null,
    'modeller üreticiden gelir',
  ),
};

const Set<String> _eskiRiverpod = {
  'package:flutter_riverpod/legacy.dart',
  'package:riverpod/legacy.dart',
  'package:hooks_riverpod/legacy.dart',
};

/// [yol]'daki yönergelere katman ve paket kurallarını uygular;
/// özellikler arası kenarları [kenarlar]'a ekler.
void yonergeKurallariniUygula({
  required String yol,
  required List<Yonerge> yonergeler,
  required String paketAdi,
  required BulguEkle ekle,
  required List<OzellikKenari> kenarlar,
}) {
  final kaynakKatmani = katman(yol);
  final kaynakOzellik = ozellikAdi(yol);
  for (final y in yonergeler) {
    _paketYonergesi(yol, y, ekle);
    if (y.tur == 'part' &&
        (y.uri.endsWith('.g.dart') || y.uri.endsWith('.freezed.dart'))) {
      ekle(
        Kurallar.kodUretimi,
        y.ofset,
        "Üretilmiş part dosyası '${y.uri}'; kod üretimi kullanılmaz.",
      );
    }
    final hedef = hedefYolu(yol, y.uri, paketAdi);
    if (hedef == null || !hedef.startsWith('lib/')) {
      continue;
    }
    final hedefKatmani = katman(hedef);
    final hedefOzellik = ozellikAdi(hedef);
    if (kaynakKatmani == Katman.core) {
      if (hedefKatmani == Katman.shell ||
          hedefKatmani == Katman.ozellik ||
          hedefKatmani == Katman.kok) {
        ekle(
          Kurallar.importSiniri,
          y.ofset,
          "core/ '$hedef' dosyasını ${y.tur} edemez; ortak ihtiyaç "
          "core/'a taşınır, kayıtlar shell/'den provider override'ıyla "
          'verilir.',
        );
      }
    } else if (kaynakKatmani == Katman.ozellik) {
      if (hedefKatmani == Katman.shell || hedefKatmani == Katman.kok) {
        ekle(
          Kurallar.importSiniri,
          y.ofset,
          "Özellik '$hedef' dosyasını ${y.tur} edemez; özellikler "
          "yalnızca core/'u ve başka özelliklerin dışa açık dosyasını "
          'kullanır.',
        );
      } else if (hedefOzellik != null && hedefOzellik != kaynakOzellik) {
        _disaAcikMi(y, hedef, hedefOzellik, ekle);
        kenarlar.add(
          OzellikKenari(
            kaynak: kaynakOzellik!,
            hedef: hedefOzellik,
            yol: yol,
            ofset: y.ofset,
          ),
        );
      }
    } else if (kaynakKatmani == Katman.shell && hedefOzellik != null) {
      _disaAcikMi(y, hedef, hedefOzellik, ekle);
    }
  }
}

void _disaAcikMi(Yonerge y, String hedef, String ozellik, BulguEkle ekle) {
  final acik = disaAcikDosya(ozellik);
  if (hedef != acik) {
    ekle(
      Kurallar.importSiniri,
      y.ofset,
      "'$hedef' '$ozellik' özelliğinin iç dosyası; yalnızca '$acik' "
      'kullanılabilir.',
    );
  }
}

void _paketYonergesi(String yol, Yonerge y, BulguEkle ekle) {
  if (_eskiRiverpod.contains(y.uri)) {
    ekle(
      Kurallar.riverpodApi,
      y.ofset,
      "'${y.uri}': Riverpod'un eski (legacy) API'si kullanılmaz.",
    );
  }
  if (y.uri == 'dart:developer' && !yol.startsWith('lib/core/')) {
    ekle(
      Kurallar.logCiktisi,
      y.ofset,
      "dart:developer yalnızca lib/core/'daki günlük altyapısında; "
      'özellikler doğrudan log yazmaz.',
    );
  }
  final paket = paketAdiniBul(y.uri);
  final kural = _paketKurallari[paket];
  if (paket == null || kural == null) {
    return;
  }
  final izinli = kural.izinliOnek;
  if (izinli != null && yol.startsWith(izinli)) {
    return;
  }
  ekle(
    kural.kural,
    y.ofset,
    "'$paket' paketi burada kullanılmaz: ${kural.gerekce}.",
  );
}

/// Özellikler arası döngüleri bulur; her döngü (güçlü bağlı bileşen)
/// için bir bulgu ekler.
void donguleriBul(
  List<OzellikKenari> kenarlar,
  void Function(String yol, int ofset, String mesaj) ekle,
) {
  final komsular = <String, Set<String>>{};
  for (final k in kenarlar) {
    komsular.putIfAbsent(k.kaynak, () => <String>{}).add(k.hedef);
    komsular.putIfAbsent(k.hedef, () => <String>{});
  }
  final dugumler = komsular.keys.toList()..sort();
  for (final bilesen in _gucluBilesenler(dugumler, komsular)) {
    if (bilesen.length < 2) {
      continue;
    }
    final uyeler = bilesen.toList()..sort();
    final ilk = kenarlar.firstWhere(
      (k) => bilesen.contains(k.kaynak) && bilesen.contains(k.hedef),
    );
    ekle(
      ilk.yol,
      ilk.ofset,
      'Özellikler arasında döngüsel bağımlılık: ${uyeler.join(', ')}. '
      "Ortak ihtiyacı core/'a taşı.",
    );
  }
}

/// Tarjan algoritmasıyla güçlü bağlı bileşenler.
List<Set<String>> _gucluBilesenler(
  List<String> dugumler,
  Map<String, Set<String>> komsular,
) {
  var sayac = 0;
  final sira = <String, int>{};
  final enDusuk = <String, int>{};
  final yigin = <String>[];
  final yiginda = <String>{};
  final sonuc = <Set<String>>[];

  void ziyaret(String d) {
    sira[d] = sayac;
    enDusuk[d] = sayac;
    sayac++;
    yigin.add(d);
    yiginda.add(d);
    final hedefler = komsular[d]!.toList()..sort();
    for (final h in hedefler) {
      if (!sira.containsKey(h)) {
        ziyaret(h);
        enDusuk[d] = enDusuk[d]! < enDusuk[h]! ? enDusuk[d]! : enDusuk[h]!;
      } else if (yiginda.contains(h)) {
        enDusuk[d] = enDusuk[d]! < sira[h]! ? enDusuk[d]! : sira[h]!;
      }
    }
    if (enDusuk[d] == sira[d]) {
      final bilesen = <String>{};
      while (true) {
        final u = yigin.removeLast();
        yiginda.remove(u);
        bilesen.add(u);
        if (u == d) {
          break;
        }
      }
      sonuc.add(bilesen);
    }
  }

  for (final d in dugumler) {
    if (!sira.containsKey(d)) {
      ziyaret(d);
    }
  }
  return sonuc;
}
