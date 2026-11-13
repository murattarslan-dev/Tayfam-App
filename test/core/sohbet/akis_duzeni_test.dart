import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/sohbet/akis_duzeni.dart';

void main() {
  // Yerel saatle kurulur: gün ayrımı cihazın saat dilimindedir.
  AkisGirdisi mesaj(String? yazar, DateTime zaman) =>
      AkisGirdisi(zaman: zaman, yazar: yazar);

  const tek = AkisKonumu(grupBasi: true, grupSonu: true, gunBasi: false);

  group('akisDuzeni', () {
    test('boş akış', () => expect(akisDuzeni(const []), isEmpty));

    test('aynı yazarın ardışık mesajları gruplanır', () {
      final duzen = akisDuzeni([
        mesaj('a', DateTime(2026, 11, 13, 10)),
        mesaj('a', DateTime(2026, 11, 13, 10, 1)),
        mesaj('a', DateTime(2026, 11, 13, 10, 2)),
      ]);
      expect(duzen, const [
        AkisKonumu(grupBasi: true, grupSonu: false, gunBasi: true),
        AkisKonumu(grupBasi: false, grupSonu: false, gunBasi: false),
        AkisKonumu(grupBasi: false, grupSonu: true, gunBasi: false),
      ]);
    });

    test('yazar değişince yeni grup', () {
      final duzen = akisDuzeni([
        mesaj('a', DateTime(2026, 11, 13, 10)),
        mesaj('b', DateTime(2026, 11, 13, 10, 1)),
        mesaj('a', DateTime(2026, 11, 13, 10, 2)),
      ]);
      expect(duzen.skip(1), [tek, tek]);
      expect(duzen.first.grupBasi && duzen.first.grupSonu, isTrue);
    });

    test('aralık beş dakikayı geçince yeni grup', () {
      final duzen = akisDuzeni([
        mesaj('a', DateTime(2026, 11, 13, 10)),
        mesaj('a', DateTime(2026, 11, 13, 10, 5)),
        mesaj('a', DateTime(2026, 11, 13, 10, 11)),
      ]);
      expect(duzen[0].grupSonu, isFalse);
      expect(duzen[1].grupSonu, isTrue);
      expect(duzen[2], tek);
    });

    test('gün değişince ayırıcı ve yeni grup', () {
      final duzen = akisDuzeni([
        mesaj('a', DateTime(2026, 11, 12, 23, 59)),
        mesaj('a', DateTime(2026, 11, 13, 0, 1)),
      ]);
      expect(duzen[0].gunBasi, isTrue);
      expect(duzen[1].gunBasi, isTrue);
      expect(duzen[0].grupSonu, isTrue);
      expect(duzen[1].grupBasi, isTrue);
    });

    test('sistem satırı grubu böler ve gruba girmez', () {
      final duzen = akisDuzeni([
        mesaj('a', DateTime(2026, 11, 13, 10)),
        AkisGirdisi(zaman: DateTime(2026, 11, 13, 10, 1), sistem: true),
        mesaj('a', DateTime(2026, 11, 13, 10, 2)),
      ]);
      expect(duzen[0].grupSonu, isTrue);
      expect(duzen[1].grupBasi && duzen[1].grupSonu, isTrue);
      expect(duzen[2].grupBasi, isTrue);
    });

    test('yazarı bilinmeyen (silinmiş hesap) mesajlar gruplanmaz', () {
      final duzen = akisDuzeni([
        mesaj(null, DateTime(2026, 11, 13, 10)),
        mesaj(null, DateTime(2026, 11, 13, 10, 1)),
      ]);
      expect(duzen[0].grupSonu, isTrue);
      expect(duzen[1].grupBasi, isTrue);
    });
  });
}
