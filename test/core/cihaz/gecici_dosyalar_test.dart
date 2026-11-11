import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/gecici_dosyalar.dart';

/// Test için boş bir kök klasör; test sonunda silinir.
Future<Directory> _kok() async {
  final kok = await Directory.systemTemp.createTemp('tayfam_test_');
  addTearDown(() async {
    if (await kok.exists()) await kok.delete(recursive: true);
  });
  return kok;
}

String _yol(Directory d, String ad) => '${d.path}${Platform.pathSeparator}$ad';

void main() {
  test('dosya yazılıyor, temizle klasörü siliyor', () async {
    final kok = await _kok();
    final dosyalar = GeciciDosyalar(
      klasor: Directory(_yol(kok, GeciciDosyalar.klasorAdi)),
    );

    final dosya = await dosyalar.yaz(
      'tayfam-verilerim-2026-11-10.zip',
      Uint8List.fromList([1, 2, 3]),
    );
    expect(await dosya.readAsBytes(), [1, 2, 3]);
    expect(dosya.parent.path, dosyalar.klasor.path);

    await dosyalar.temizle();
    expect(await dosya.exists(), isFalse);
    expect(await dosyalar.klasor.exists(), isFalse);

    // Klasör yokken temizlik hata vermez.
    await dosyalar.temizle();
  });

  test('yeni dosya öncekini bırakmıyor', () async {
    final kok = await _kok();
    final dosyalar = GeciciDosyalar(klasor: Directory(_yol(kok, 'k')));

    final ilk = await dosyalar.yaz('a.zip', Uint8List.fromList([1]));
    final ikinci = await dosyalar.yaz('b.zip', Uint8List.fromList([2]));

    expect(await ilk.exists(), isFalse);
    expect(await ikinci.exists(), isTrue);
    expect(await dosyalar.klasor.list().length, 1);
  });

  test('klasör dışına çıkan ya da gizli dosya adı reddediliyor', () async {
    final kok = await _kok();
    final dosyalar = GeciciDosyalar(klasor: Directory(_yol(kok, 'k')));
    for (final ad in ['../a.zip', 'a/b.zip', '.gizli', '', 'ç.zip']) {
      await expectLater(
        dosyalar.yaz(ad, Uint8List(1)),
        throwsArgumentError,
        reason: ad,
      );
    }
    expect(await kok.list().length, 0);
  });

  test('açılış temizliği artıkları ve kopyaları siliyor', () async {
    final kok = await _kok();
    final klasor = Directory(_yol(kok, GeciciDosyalar.klasorAdi));
    final kopyalar = Directory(_yol(kok, 'share_plus'));
    await klasor.create();
    await kopyalar.create();
    await File(_yol(klasor, 'artik.zip')).writeAsBytes([1]);
    await File(_yol(kopyalar, 'kopya.zip')).writeAsBytes([1]);
    final baska = File(_yol(kok, 'baska.txt'));
    await baska.writeAsString('dokunulmaz');

    await GeciciDosyalar(
      klasor: klasor,
      paylasimKopyalari: kopyalar,
    ).acilistaTemizle();

    expect(await klasor.exists(), isFalse);
    expect(await kopyalar.exists(), isFalse);
    expect(await baska.exists(), isTrue);
  });

  test('paylaşım kopyası yalnızca açılışta siliniyor', () async {
    final kok = await _kok();
    final kopyalar = Directory(_yol(kok, 'share_plus'));
    await kopyalar.create();
    final dosyalar = GeciciDosyalar(
      klasor: Directory(_yol(kok, 'k')),
      paylasimKopyalari: kopyalar,
    );

    await dosyalar.yaz('a.zip', Uint8List(1));
    await dosyalar.temizle();

    // Alıcı uygulama kopyayı paylaşımdan sonra da okuyabilir.
    expect(await kopyalar.exists(), isTrue);
  });

  test('cihaz klasörü sistemin geçici dizininde', () {
    final dosyalar = GeciciDosyalar.cihaz();
    expect(dosyalar.klasor.parent.path, Directory.systemTemp.path);
    expect(dosyalar.klasor.path, endsWith(GeciciDosyalar.klasorAdi));
  });
}
