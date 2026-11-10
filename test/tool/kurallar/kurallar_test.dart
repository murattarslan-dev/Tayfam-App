import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/kurallar/kurallar.dart';

/// Örnek dosyaların dizini. Her `.ornek` dosyası bir veya birden çok sanal
/// dosya içerir: `// yol: <yol>` (pubspec için `# yol: pubspec.yaml`)
/// satırı yeni bir dosya başlatır. `// beklenen: <kural> [adet]`
/// satırları, örneğin bütününden beklenen bulguları sayar. `kotu/`
/// altındaki her örnek bilerek bozulmuştur; `iyi/` altındakiler hiç bulgu
/// üretmemelidir.
const String _ornekDizini = 'test/tool/kurallar/ornekler';

final RegExp _yolSatiri = RegExp(r'^(?://|#) yol: (\S+)\s*$');

final RegExp _beklenenSatiri = RegExp(
  r'^(?://|#) beklenen: ([a-z-]+)(?: (\d+))?\s*$',
);

final class _Ornek {
  _Ornek(this.ad, this.girdi, this.beklenen);

  final String ad;
  final DenetimGirdisi girdi;
  final Map<String, int> beklenen;
}

_Ornek _ornekOku(File dosya) {
  final dosyalar = <String, StringBuffer>{};
  final beklenen = <String, int>{};
  StringBuffer? simdiki;
  for (final satir in dosya.readAsLinesSync()) {
    final yol = _yolSatiri.firstMatch(satir);
    if (yol != null) {
      simdiki = dosyalar.putIfAbsent(yol.group(1)!, StringBuffer.new);
    }
    final b = _beklenenSatiri.firstMatch(satir);
    if (b != null) {
      final ad = b.group(1)!;
      beklenen[ad] = (beklenen[ad] ?? 0) + int.parse(b.group(2) ?? '1');
    }
    if (simdiki == null) {
      throw StateError('${dosya.path}: ilk satır "// yol: …" olmalı');
    }
    simdiki.writeln(satir);
  }
  final pubspec = dosyalar.remove('pubspec.yaml');
  return _Ornek(
    dosya.uri.pathSegments.last,
    DenetimGirdisi(
      dartDosyalari: {
        for (final MapEntry(:key, :value) in dosyalar.entries)
          key: value.toString(),
      },
      pubspec: pubspec?.toString(),
    ),
    beklenen,
  );
}

List<_Ornek> _ornekler(String alt) {
  final dosyalar =
      Directory('$_ornekDizini/$alt')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ornek'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in dosyalar) _ornekOku(f)];
}

Map<String, int> _say(List<Bulgu> bulgular) {
  final sayilar = <String, int>{};
  for (final b in bulgular) {
    sayilar[b.kural.ad] = (sayilar[b.kural.ad] ?? 0) + 1;
  }
  return sayilar;
}

String _ozet(List<Bulgu> bulgular) =>
    bulgular.isEmpty ? '(bulgu yok)' : bulgular.map((b) => b.ozet).join('\n');

void main() {
  final kotuOrnekler = _ornekler('kotu');
  final iyiOrnekler = _ornekler('iyi');

  group('bilerek bozulmuş örnekler', () {
    for (final o in kotuOrnekler) {
      test(o.ad, () {
        expect(o.beklenen, isNotEmpty, reason: 'beklenen satırı yok');
        final bulgular = denetle(o.girdi);
        expect(_say(bulgular), o.beklenen, reason: _ozet(bulgular));
      });
    }
  });

  group('kurallara uyan örnekler', () {
    for (final o in iyiOrnekler) {
      test(o.ad, () {
        final bulgular = denetle(o.girdi);
        expect(bulgular, isEmpty, reason: _ozet(bulgular));
      });
    }
  });

  test('ARB dışındaki her kural en az bir bozuk örnekle denenir', () {
    final denenen = {for (final o in kotuOrnekler) ...o.beklenen.keys};
    final arb = {
      Kurallar.arbAciklama.ad,
      Kurallar.arbAnahtarAdi.ad,
      Kurallar.arbKullanilmayan.ad,
    };
    final eksik = [
      for (final k in Kurallar.hepsi)
        if (!arb.contains(k.ad) && !denenen.contains(k.ad)) k.ad,
    ];
    expect(eksik, isEmpty);
  });

  test('kural adları benzersiz ve her kuralın dayanağı var', () {
    final adlar = Kurallar.hepsi.map((k) => k.ad).toList();
    expect(adlar.toSet(), hasLength(adlar.length));
    for (final k in Kurallar.hepsi) {
      expect(k.dayanak, isNotEmpty, reason: k.ad);
      expect(k.aciklama, isNotEmpty, reason: k.ad);
      expect(Kurallar.bul(k.ad), same(k));
    }
    expect(Kurallar.bul('olmayan'), isNull);
  });

  group('ARB', () {
    const kod =
        'String a(AppLocalizations m) => '
        'm.etkinlik_baslik + m.aciklamasiz;\n';

    test('açıklama, anahtar adı ve kullanılmayan anahtar', () {
      const arb = '''
{
  "@@locale": "tr",
  "etkinlik_baslik": "Etkinlikler",
  "@etkinlik_baslik": {"description": "Etkinlik listesinin başlığı."},
  "aciklamasiz": "Metin",
  "KotuAd": "Metin",
  "@KotuAd": {"description": "Bozuk ad."}
}
''';
      final bulgular = denetle(
        DenetimGirdisi(
          dartDosyalari: {'lib/shell/ornek.dart': kod},
          arbDosyalari: {sablonArb: arb},
        ),
      );
      expect(_say(bulgular), {
        'arb-aciklama': 1,
        'arb-anahtar-adi': 1,
        'arb-kullanilmayan': 1,
      }, reason: _ozet(bulgular));
      final aciklamasiz = bulgular.firstWhere(
        (b) => b.kural == Kurallar.arbAciklama,
      );
      expect(aciklamasiz.satir, 5);
      expect(
        bulgular.firstWhere((b) => b.kural == Kurallar.arbKullanilmayan).seviye,
        Seviye.uyari,
      );
    });

    test('ikinci dil dosyasında açıklama aranmaz', () {
      final bulgular = denetle(
        DenetimGirdisi(
          dartDosyalari: {'lib/shell/ornek.dart': kod},
          arbDosyalari: {'lib/l10n/app_en.arb': '{"etkinlik_baslik": "Events"}'},
        ),
      );
      expect(bulgular, isEmpty, reason: _ozet(bulgular));
    });

    test('okunamayan ARB hatadır', () {
      final bulgular = denetle(
        DenetimGirdisi(
          dartDosyalari: const {},
          arbDosyalari: {sablonArb: '{"a": '},
        ),
      );
      expect(_say(bulgular), {'arb-aciklama': 1});
    });
  });

  group('istisna', () {
    test('pubspec.yaml satırında # ile yazılır', () {
      const pubspec = '''
name: tayfam
dependencies:
  # kural-istisnası: yasak-paket — örnek gerekçe
  dio: ^5.0.0
  get_it: ^8.0.0 # kural-istisnası: yasak-paket - kısa çizgili ayraç
''';
      final bulgular = denetle(
        DenetimGirdisi(dartDosyalari: const {}, pubspec: pubspec),
      );
      expect(bulgular, isEmpty, reason: _ozet(bulgular));
    });

    test('birden çok kural virgülle yazılır', () {
      const kaynak = '''
import 'package:flutter/material.dart';

const BoxDecoration a = BoxDecoration(
  // kural-istisnası: sabit-renk, sabit-yaricap — örnek gerekçe
  color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(4)),
);
''';
      final bulgular = denetle(
        DenetimGirdisi(dartDosyalari: {'lib/shell/ornek.dart': kaynak}),
      );
      expect(bulgular, isEmpty, reason: _ozet(bulgular));
    });

    test('başka bir satırı kapatmaz', () {
      const kaynak = '''
import 'package:flutter/material.dart';

// kural-istisnası: sabit-renk — yalnızca alttaki satır

const Color a = Colors.black;
const Color b = Colors.white;
''';
      final bulgular = denetle(
        DenetimGirdisi(dartDosyalari: {'lib/shell/ornek.dart': kaynak}),
      );
      expect(_say(bulgular), {'sabit-renk': 1}, reason: _ozet(bulgular));
      expect(bulgular.single.satir, 6);
    });
  });

  test('bulgunun satırı, sütunu ve özeti', () {
    const kaynak = '''
import 'package:flutter/material.dart';

const Color a =
    Colors.black;
''';
    final bulgular = denetle(
      DenetimGirdisi(dartDosyalari: {'lib/shell/ornek.dart': kaynak}),
    );
    final b = bulgular.single;
    expect(b.yol, 'lib/shell/ornek.dart');
    expect(b.satir, 4);
    expect(b.sutun, 5);
    expect(b.seviye, Seviye.hata);
    expect(b.ozet, startsWith('lib/shell/ornek.dart:4:5: [sabit-renk] '));
    expect(b.ozet, contains('ADR-0004'));
  });

  group('yol çözümleme', () {
    test('paket ve göreli adresler', () {
      const kaynak = 'lib/features/anket/presentation/anket_ekrani.dart';
      expect(
        hedefYolu(kaynak, 'package:tayfam/core/tema/tema.dart', 'tayfam'),
        'lib/core/tema/tema.dart',
      );
      expect(
        hedefYolu(kaynak, '../application/anketler.dart', 'tayfam'),
        'lib/features/anket/application/anketler.dart',
      );
      expect(
        hedefYolu(kaynak, './anket_karti.dart', 'tayfam'),
        'lib/features/anket/presentation/anket_karti.dart',
      );
      expect(hedefYolu(kaynak, 'dart:io', 'tayfam'), isNull);
      expect(hedefYolu(kaynak, 'package:http/http.dart', 'tayfam'), isNull);
    });

    test('katmanlar', () {
      expect(katman('lib/core/api/api_client.dart'), Katman.core);
      expect(katman('lib/shell/yonlendirici.dart'), Katman.shell);
      expect(katman('lib/features/tayfa/tayfa.dart'), Katman.ozellik);
      expect(katman('lib/app.dart'), Katman.kok);
      expect(katman('lib/l10n/app_localizations.dart'), Katman.l10n);
    });
  });
}
