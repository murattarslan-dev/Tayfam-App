import 'package:flutter_test/flutter_test.dart';

import '../../../tool/kurallar/kurallar.dart';

void main() {
  test('yorumlar iki görünümde de maskelenir, konumlar korunur', () {
    const kaynak = 'a(); // Colors.red\n/* b /* iç */ c */ d();\n/// belge\n';
    final t = TaranmisKaynak.tara(kaynak);
    expect(t.kod.length, kaynak.length);
    expect(t.yorumsuz.length, kaynak.length);
    expect(t.kod, isNot(contains('Colors')));
    expect(t.yorumsuz, isNot(contains('Colors')));
    expect(t.kod, contains('d();'));
    expect(t.kod.split('\n'), hasLength(4));
    expect(t.yorumlar.map((y) => y.metin), [
      '// Colors.red',
      '/* b /* iç */ c */',
      '/// belge',
    ]);
  });

  test('metin içeriği kod görünümünde maskelenir, ara değer kalır', () {
    const kaynak = r"""f('Colors.red ${ad.toUpperCase()} $soyad', "x");""";
    final t = TaranmisKaynak.tara(kaynak);
    expect(t.kod, isNot(contains('Colors')));
    expect(t.kod, contains('ad.toUpperCase()'));
    expect(t.yorumsuz, kaynak);
    expect(t.metinler, hasLength(2));
    final ilk = t.metinler.firstWhere((m) => m.tirnak == 2);
    expect(ilk.icerik, 'Colors.red \u0000 \u0000');
    expect(ilk.duzMetin, 'Colors.red  ');
    expect(t.tirnaktakiMetin(kaynak.indexOf('"x"'))?.icerik, 'x');
  });

  test('ham, üç tırnaklı, kaçışlı ve iç içe metinler', () {
    const kaynak = r"""
a = r'$x \n';
b = '''
çok satır 'iç'
''';
c = 'it\'s';
d = '${m['k']}';
""";
    final t = TaranmisKaynak.tara(kaynak);
    final icerikler = t.metinler.map((m) => m.icerik).toList();
    expect(icerikler, contains(r'$x \n'));
    expect(icerikler, contains("\nçok satır 'iç'\n"));
    expect(icerikler, contains(r"it\'s"));
    expect(icerikler, contains('k'));
    expect(icerikler, contains('\u0000'));
    expect(t.kod, contains("m['"));
    expect(t.kod, isNot(contains('satır')));
  });

  test('satır ve sütun', () {
    const kaynak = 'ab\ncd\n\nef';
    final t = TaranmisKaynak.tara(kaynak);
    expect(t.satir(0), 1);
    expect(t.sutun(1), 2);
    expect(t.satir(3), 2);
    expect(t.sutun(4), 2);
    expect(t.satir(7), 4);
    expect(t.satirSayisi, 4);
    expect(t.satirMetni(2), 'cd');
    expect(t.satirMetni(3), '');
  });

  test('parantez kapanışı ve üst düzey argümanlar', () {
    const kaynak = "f(a, b: g(1, 2), c: [3, ')'], 4)";
    final t = TaranmisKaynak.tara(kaynak);
    final kapa = kapanisiBul(t.kod, 1);
    expect(kapa, kaynak.length - 1);
    final argumanlar = ustDuzeyArgumanlar(t.kod, 1, kapa!);
    expect(argumanlar.map((a) => a.ad), [null, 'b', 'c', null]);
    expect(argumanlar[1].deger, 'g(1, 2)');
    expect(argumanlar[3].deger, '4');
    expect(kaynak.substring(argumanlar[2].ofset), startsWith('['));
  });
}
