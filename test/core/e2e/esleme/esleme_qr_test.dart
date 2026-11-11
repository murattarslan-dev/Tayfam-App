import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';

import '../gecmis/sahteler.dart';

final Uint8List _kod = Uint8List.fromList(List.generate(16, (i) => 200 + i));

EslemeQr _qr() => EslemeQr(
  istekId: istekId,
  cihazId: cihazB,
  kimlikAnahtari: kimlik(2),
  kod: _kod,
);

Matcher _gecersiz() => throwsA(
  isA<EslemeHatasi>().having((h) => h.tur, 'tur', EslemeHataTuru.qrGecersiz),
);

void main() {
  test('kodla → ayrıştır aynı içeriği verir', () {
    final metin = _qr().kodla();
    expect(metin, startsWith('tayfam-esle:v1:$istekId:$cihazB:'));
    expect(metin.length, lessThan(eslemeQrEnUzun));
    expect(metin, isNot(contains('=')));
    final qr = EslemeQr.ayristir(metin);
    expect(qr.istekId, istekId);
    expect(qr.cihazId, cihazB);
    expect(qr.kimlikAnahtari, kimlik(2));
    expect(qr.kod, _kod);
  });

  test('toString içerik yazmaz', () {
    expect(_qr().toString(), isNot(contains(istekId)));
  });

  group('bozuk QR reddedilir', () {
    final k = b64urlKodla(kimlik(2));
    final c = b64urlKodla(_kod);
    final ornekler = {
      'boş': '',
      'başka QR': 'https://tayfam.app/davet#abc',
      'eski/yeni sürüm': 'tayfam-esle:v2:$istekId:$cihazB:$k:$c',
      'eksik alan': 'tayfam-esle:v1:$istekId:$cihazB:$k',
      'fazla alan': 'tayfam-esle:v1:$istekId:$cihazB:$k:$c:x',
      'UUID değil': 'tayfam-esle:v1:istek:$cihazB:$k:$c',
      'kimlik 32 bayt': 'tayfam-esle:v1:$istekId:$cihazB:'
          '${b64urlKodla(kimlik(2).sublist(1))}:$c',
      'kimlik öneki yanlış': 'tayfam-esle:v1:$istekId:$cihazB:'
          '${b64urlKodla(Uint8List.fromList([0x06, ...kimlik(2).sublist(1)]))}:$c',
      'kod 15 bayt': 'tayfam-esle:v1:$istekId:$cihazB:$k:'
          '${b64urlKodla(_kod.sublist(1))}',
      'base64url dışı karakter': 'tayfam-esle:v1:$istekId:$cihazB:$k+:$c',
      'dolgulu base64': 'tayfam-esle:v1:$istekId:$cihazB:$k:$c==',
      'çok uzun': 'tayfam-esle:v1:${'a' * 300}',
    };
    for (final MapEntry(:key, :value) in ornekler.entries) {
      test(key, () => expect(() => EslemeQr.ayristir(value), _gecersiz()));
    }
  });

  test('sabitZamanliEsit', () {
    expect(sabitZamanliEsit(kimlik(1), kimlik(1)), isTrue);
    expect(sabitZamanliEsit(kimlik(1), kimlik(2)), isFalse);
    expect(sabitZamanliEsit(kimlik(1), kimlik(1).sublist(1)), isFalse);
  });
}
