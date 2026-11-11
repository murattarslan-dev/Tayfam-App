import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/imzali_indirme.dart';

/// Sahte imzalı link (gerçek değil).
final Uri _link = Uri.parse(
  'https://depo.ornek.test/exports/sahte?X-Amz-Signature=sahte-imza',
);

Matcher _hata(ImzaliIndirmeHataTuru tur) =>
    isA<ImzaliIndirmeHatasi>().having((h) => h.tur, 'tur', tur);

/// Gövdeyi [parcalar] hâlinde akıtan sahte istemci; gelen istekleri
/// kaydeder. Gerçek ağ yok.
MockClient _istemci(
  List<http.BaseRequest> istekler, {
  int durum = 200,
  List<List<int>> parcalar = const [],
  int? uzunluk,
}) => MockClient.streaming((istek, _) async {
  istekler.add(istek);
  return http.StreamedResponse(
    Stream.fromIterable(parcalar),
    durum,
    contentLength: uzunluk,
  );
});

void main() {
  test('dosya akışla indiriliyor; token ve Tayfam başlıkları yok', () async {
    final istekler = <http.BaseRequest>[];
    final indirici = HttpImzaliIndirici(
      _istemci(
        istekler,
        parcalar: [
          [1, 2, 3],
          [4, 5],
        ],
        uzunluk: 5,
      ),
    );

    final dosya = await indirici.indir(_link, beklenenBoyut: 5, enCok: 100);

    expect(dosya, Uint8List.fromList([1, 2, 3, 4, 5]));
    final istek = istekler.single;
    expect(istek.method, 'GET');
    expect(istek.url, _link);
    expect(istek.followRedirects, isFalse);
    final basliklar = [for (final k in istek.headers.keys) k.toLowerCase()];
    expect(basliklar, isNot(contains('authorization')));
    expect(basliklar, isNot(contains('cookie')));
    expect(basliklar.where((k) => k.startsWith('x-tayfam')), isEmpty);
  });

  test('https olmayan ya da kullanıcı bilgili link istenmiyor', () async {
    final istekler = <http.BaseRequest>[];
    final indirici = HttpImzaliIndirici(_istemci(istekler));
    for (final adres in [
      'http://depo.ornek.test/x',
      'https://kullanici:parola@depo.ornek.test/x',
      'file:///etc/hosts',
    ]) {
      await expectLater(
        indirici.indir(Uri.parse(adres), beklenenBoyut: 1, enCok: 10),
        throwsA(_hata(ImzaliIndirmeHataTuru.gecersizAdres)),
      );
    }
    expect(istekler, isEmpty);
  });

  test('sınırı aşan beklenen boyut hiç denenmiyor', () async {
    final istekler = <http.BaseRequest>[];
    final indirici = HttpImzaliIndirici(_istemci(istekler));
    for (final boyut in [0, -1, 11]) {
      await expectLater(
        indirici.indir(_link, beklenenBoyut: boyut, enCok: 10),
        throwsA(_hata(ImzaliIndirmeHataTuru.boyut)),
      );
    }
    expect(istekler, isEmpty);
  });

  test('beklenenden uzun gövde kesiliyor', () async {
    final indirici = HttpImzaliIndirici(
      _istemci(
        [],
        parcalar: [
          [1, 2, 3],
          [4, 5, 6],
        ],
      ),
    );
    await expectLater(
      indirici.indir(_link, beklenenBoyut: 4, enCok: 100),
      throwsA(_hata(ImzaliIndirmeHataTuru.boyut)),
    );
  });

  test('kısa gövde ya da farklı Content-Length reddediliyor', () async {
    final kisa = HttpImzaliIndirici(
      _istemci(
        [],
        parcalar: [
          [1, 2],
        ],
      ),
    );
    await expectLater(
      kisa.indir(_link, beklenenBoyut: 4, enCok: 100),
      throwsA(_hata(ImzaliIndirmeHataTuru.boyut)),
    );
    final farkli = HttpImzaliIndirici(
      _istemci(
        [],
        parcalar: [
          [1, 2, 3, 4],
        ],
        uzunluk: 9,
      ),
    );
    await expectLater(
      farkli.indir(_link, beklenenBoyut: 4, enCok: 100),
      throwsA(_hata(ImzaliIndirmeHataTuru.boyut)),
    );
  });

  test('200 dışı durum (ör. süresi dolmuş link) hata', () async {
    final indirici = HttpImzaliIndirici(_istemci([], durum: 403));
    await expectLater(
      indirici.indir(_link, beklenenBoyut: 4, enCok: 100),
      throwsA(_hata(ImzaliIndirmeHataTuru.durum)),
    );
  });

  test('bağlantı hatası türe çevriliyor; mesajda link yok', () async {
    final indirici = HttpImzaliIndirici(
      MockClient.streaming(
        (istek, _) async => throw http.ClientException('koptu', istek.url),
      ),
    );
    Object? yakalanan;
    try {
      await indirici.indir(_link, beklenenBoyut: 4, enCok: 100);
    } on ImzaliIndirmeHatasi catch (hata) {
      yakalanan = hata;
    }
    expect(yakalanan, _hata(ImzaliIndirmeHataTuru.baglanti));
    expect(yakalanan.toString(), isNot(contains('depo.ornek.test')));
    expect(yakalanan.toString(), isNot(contains('sahte-imza')));
  });

  test('süre aşımı', () async {
    final indirici = HttpImzaliIndirici(
      MockClient.streaming(
        (istek, _) => Completer<http.StreamedResponse>().future,
      ),
      zamanAsimi: const Duration(milliseconds: 10),
    );
    await expectLater(
      indirici.indir(_link, beklenenBoyut: 4, enCok: 100),
      throwsA(_hata(ImzaliIndirmeHataTuru.zamanAsimi)),
    );
  });
}
