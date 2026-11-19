import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/sozluk_girisi.dart';

import 'bilesen_test_yardimcisi.dart';

const String _levrekId = '1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e';
const String _lufer = '2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f';

const List<SozlukOnerisi> _oneriler = [
  (kimlik: _levrekId, metin: 'Levrek'),
  (kimlik: _lufer, metin: 'Lüfer'),
];

/// Girişin değerini tutan kap: her değişiklik [kayit]'a yazılır.
class _Kap extends StatefulWidget {
  const _Kap({required this.ara, required this.kayit});

  final Future<List<SozlukOnerisi>> Function(String arama) ara;
  final List<(String, String?)> kayit;

  @override
  State<_Kap> createState() => _KapState();
}

class _KapState extends State<_Kap> {
  String _metin = '';
  String? _kimlik;

  @override
  Widget build(BuildContext context) => SozlukGirisi(
    etiket: 'Tür',
    metin: _metin,
    kimlik: _kimlik,
    enCokUzunluk: 60,
    ara: widget.ara,
    onDegisti: (metin, kimlik) {
      widget.kayit.add((metin, kimlik));
      setState(() {
        _metin = metin;
        _kimlik = kimlik;
      });
    },
  );
}

/// Aramaları sayan sahte arayıcı.
final class _Arayici {
  _Arayici([this.sonuc = _oneriler]);

  final List<SozlukOnerisi> sonuc;
  final List<String> aramalar = [];

  Future<List<SozlukOnerisi>> ara(String arama) async {
    aramalar.add(arama);
    return sonuc;
  }
}

Future<void> _yaz(WidgetTester tester, String metin) async {
  await tester.enterText(find.byType(TextField), metin);
  await tester.pump(sozlukAramaGecikmesi);
  await tester.pump();
}

void main() {
  test('sözlük anahtarı: Türkçe küçük harf, tek boşluk', () {
    expect(sozlukAnahtari('  IŞIK   Balığı '), 'ışık balığı');
    expect(sozlukAnahtari('İstavrit'), 'istavrit');
    expect(sozlukEslesmesi(' levrek ', _oneriler)?.kimlik, _levrekId);
    expect(sozlukEslesmesi('Lev', _oneriler), isNull);
    expect(sozlukEslesmesi('  ', _oneriler), isNull);
  });

  ortakTestler(() => _Kap(ara: _Arayici().ara, kayit: []));

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('öneriler açıkken taşma yok, erişilebilirlik kuralları', (
        tester,
      ) async {
        await bileseniAc(
          tester,
          _Kap(ara: _Arayici().ara, kayit: []),
          mod: mod,
        );
        await _yaz(tester, 'L');
        await _yaz(tester, 'Le');
        expect(find.text('Levrek'), findsOneWidget);
        expect(find.text('Lüfer'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await erisilebilirlikDenetle(tester);
      });

      testWidgets('öneri seçilince kimliğiyle; ipucu "sözlükten"', (
        tester,
      ) async {
        final kayit = <(String, String?)>[];
        await bileseniAc(
          tester,
          _Kap(ara: _Arayici().ara, kayit: kayit),
          mod: mod,
        );
        await _yaz(tester, 'le');
        await tester.tap(find.text('Levrek'));
        await tester.pump();
        expect(kayit.last, ('Levrek', _levrekId));
        // Seçimden sonra öneri listesi kapanır.
        expect(find.text('Lüfer'), findsNothing);
        expect(find.text(arbMetni('bilesen_vocab_sozlukten')), findsOneWidget);

        // Metin değişince kimlik düşer: yeni değer olarak gider.
        await _yaz(tester, 'Levrekler');
        expect(kayit.last.$2, isNull);
        expect(find.text(arbMetni('bilesen_vocab_yeni_deger')), findsOneWidget);
      });
    });
  }

  testWidgets('aramaya 300 ms gecikme ve en az 2 harf', (tester) async {
    final arayici = _Arayici();
    await bileseniAc(
      tester,
      _Kap(ara: arayici.ara, kayit: []),
      mod: ThemeMode.light,
    );
    await tester.enterText(find.byType(TextField), 'L');
    await tester.pump(const Duration(seconds: 1));
    expect(arayici.aramalar, isEmpty);

    await tester.enterText(find.byType(TextField), 'Le');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'Lev ');
    await tester.pump(const Duration(milliseconds: 200));
    expect(arayici.aramalar, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(arayici.aramalar, ['Lev']);
  });

  testWidgets('yazılan metin bilinen değerse kimlik kendiliğinden', (
    tester,
  ) async {
    final kayit = <(String, String?)>[];
    await bileseniAc(
      tester,
      _Kap(ara: _Arayici().ara, kayit: kayit),
      mod: ThemeMode.light,
    );
    await _yaz(tester, 'LEVREK');
    expect(kayit.last, ('LEVREK', _levrekId));
    expect(find.text(arbMetni('bilesen_vocab_sozlukten')), findsOneWidget);
  });

  testWidgets('bilinmeyen metin: kimlik yok, "yeni değer" ipucu', (
    tester,
  ) async {
    final kayit = <(String, String?)>[];
    await bileseniAc(
      tester,
      _Kap(ara: _Arayici(const []).ara, kayit: kayit),
      mod: ThemeMode.light,
    );
    await _yaz(tester, 'Kofana');
    expect(kayit.last, ('Kofana', null));
    expect(find.text(arbMetni('bilesen_vocab_yeni_deger')), findsOneWidget);
  });

  testWidgets('arama hatası formu durdurmaz: öneri yok', (tester) async {
    final kayit = <(String, String?)>[];
    await bileseniAc(
      tester,
      _Kap(ara: (_) async => throw const FormatException('ağ'), kayit: kayit),
      mod: ThemeMode.light,
    );
    await _yaz(tester, 'Levrek');
    expect(tester.takeException(), isNull);
    expect(kayit.last, ('Levrek', null));
    expect(find.byIcon(Icons.history), findsNothing);
  });

  testWidgets('eski aramanın geç gelen sonucu yok sayılır', (tester) async {
    final yavas = Completer<List<SozlukOnerisi>>();
    final aramalar = <String>[];
    await bileseniAc(
      tester,
      _Kap(
        ara: (arama) {
          aramalar.add(arama);
          return arama == 'Le'
              ? yavas.future
              : Future.value(const [(kimlik: _lufer, metin: 'Lüfer')]);
        },
        kayit: [],
      ),
      mod: ThemeMode.light,
    );
    await _yaz(tester, 'Le');
    await _yaz(tester, 'Lü');
    expect(aramalar, ['Le', 'Lü']);
    expect(find.text('Lüfer'), findsOneWidget);
    yavas.complete(_oneriler);
    await tester.pump();
    expect(find.text('Levrek'), findsNothing);
    expect(find.text('Lüfer'), findsOneWidget);
  });
}
