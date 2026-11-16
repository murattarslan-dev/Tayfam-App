import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/gen/apis/uploads_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/imzali_indirme.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/e2e/ek/ek_servisi.dart';
import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart';
import 'package:tayfam/core/e2e/mesaj/zarf_icerigi.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';

import '../../../features/hesap/sahteler.dart';
import '../../medya/sahteler.dart';
import '../signal/sahte_signal_motoru.dart';

const String _ekId = '5b6f4a1e-9c3d-4f1a-8b9e-8d7c7d0e8c4a';

HazirGoruntu _goruntu() => HazirGoruntu(
  tam: Uint8List.fromList([for (var i = 0; i < 300; i++) i % 256]),
  onizleme: Uint8List.fromList(List.filled(10, 2)),
  tamOlcu: const JpegOlculeri(1600, 1200),
  onizlemeOlcu: const JpegOlculeri(400, 300),
);

/// Bellekte tutulan blob'u veren sahte imzalı indirici.
final class _Indirici implements ImzaliIndirici {
  Uint8List? blob;
  ImzaliIndirmeHatasi? hata;
  final List<(Uri, int)> istekler = [];

  @override
  Future<Uint8List> indir(
    Uri adres, {
    required int beklenenBoyut,
    required int enCok,
  }) async {
    istekler.add((adres, beklenenBoyut));
    final h = hata;
    if (h != null) throw h;
    final b = blob!;
    if (b.length != beklenenBoyut || beklenenBoyut > enCok) {
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.boyut);
    }
    return b;
  }
}

Map<String, Object?> _ekLinki(String id) => {
  'upload_id': id,
  'full_url': '$ornekR2/b/media/$id/full?X-Amz-Signature=sahte',
  'full_content_type': 'application/octet-stream',
  'width': 0,
  'height': 0,
  'expires_at': '2026-11-16T21:00:00Z',
};

final class _Ortam {
  _Ortam({List<MediaUrls> Function(List<String>)? linkler}) {
    servis = E2eEkServisi(
      sifreleyici: EkSifreleyici(motor),
      yukleyici: MedyaYukleyici(
        uploads: UploadsApi(api),
        tasima: MedyaTasima(istemci: sahteDepo(depo)),
        bekle: (_) async {},
      ),
      medya: MedyaOnbellegi(
        isteyici: (idler) async =>
            (linkler ?? (i) => [MediaUrls.fromJson(_ekLinki(i.single))])(idler),
        tasima: MedyaTasima(istemci: sahteDepo(depo)),
        saat: () => DateTime.utc(2026, 11, 16, 20),
      ),
      indirici: indirici,
      onbellek: onbellek,
    );
  }

  final SahteSignalMotoru motor = SahteSignalMotoru();
  final SahteTasima api = SahteTasima();
  final List<http.Request> depo = [];
  final _Indirici indirici = _Indirici();
  final EkOnbellegi onbellek = EkOnbellegi();
  late final E2eEkServisi servis;

  /// Bir görüntüyü şifreler ve [ekId] kimliğiyle zarftaki gibi anahtar
  /// üretir; blob indiriciye konur.
  Future<EkAnahtari> hazirEk({String ekId = _ekId}) async {
    final s = await servis.sifrele(_goruntu());
    indirici.blob = s.blob;
    return EkAnahtari(
      uploadId: ekId,
      anahtar: s.anahtar,
      ozet: s.ozet,
      boyut: s.blob.length,
      genislik: 1600,
      yukseklik: 1200,
    );
  }
}

void main() {
  group('açma (ADR-0026 §4)', () {
    test('link → tam boyutta indir → özet → çöz; bellekte tutulur', () async {
      final o = _Ortam();
      final ek = await o.hazirEk();
      expect(await o.servis.ac(ek), _goruntu().tam);
      expect(o.indirici.istekler.single.$2, ek.boyut);
      expect(o.indirici.istekler.single.$1.path, contains('/full'));
      // İkinci açılış ağa gitmez.
      expect(await o.servis.ac(ek), _goruntu().tam);
      expect(o.indirici.istekler, hasLength(1));
      expect(o.onbellek.toplamBayt, _goruntu().tam.length);
    });

    test('yanlış özet: EkDogrulanamadi, önbelleğe girmez', () async {
      final o = _Ortam();
      final ek = await o.hazirEk();
      final bozuk = EkAnahtari(
        uploadId: ek.uploadId,
        anahtar: ek.anahtar,
        ozet: Uint8List.fromList(ek.ozet)..[3] ^= 1,
        boyut: ek.boyut,
        genislik: 1,
        yukseklik: 1,
      );
      o.motor.cagrilar.clear();
      await expectLater(o.servis.ac(bozuk), throwsA(isA<EkDogrulanamadi>()));
      expect(o.motor.cagrilar, isNot(contains('aes256GcmCoz')));
      expect(o.onbellek.oku(_ekId), isNull);
    });

    test('sunucunun verdiği blob değiştirilmişse reddedilir', () async {
      final o = _Ortam();
      final ek = await o.hazirEk();
      o.indirici.blob = Uint8List.fromList(o.indirici.blob!)..[20] ^= 1;
      await expectLater(o.servis.ac(ek), throwsA(isA<EkDogrulanamadi>()));
    });

    test(
      'boyut tutmazsa doğrulanamadı; bağlantı hatası tekrar denenebilir',
      () async {
        final o = _Ortam();
        final ek = await o.hazirEk();
        o.indirici.hata = const ImzaliIndirmeHatasi(
          ImzaliIndirmeHataTuru.boyut,
        );
        await expectLater(o.servis.ac(ek), throwsA(isA<EkDogrulanamadi>()));
        o.indirici.hata = const ImzaliIndirmeHatasi(
          ImzaliIndirmeHataTuru.baglanti,
        );
        await expectLater(o.servis.ac(ek), throwsA(isA<ImzaliIndirmeHatasi>()));
        o.indirici.hata = null;
        expect(await o.servis.ac(ek), _goruntu().tam);
      },
    );

    test('görülemeyen ek ve görüntü linki (blob değil)', () async {
      final yok = _Ortam(linkler: (_) => const []);
      await expectLater(
        yok.servis.ac(await yok.hazirEk()),
        throwsA(isA<EkGorulemez>()),
      );
      final gorsel = _Ortam(
        linkler: (i) => [MediaUrls.fromJson(medyaLinkiJson(i.single))],
      );
      await expectLater(
        gorsel.servis.ac(await gorsel.hazirEk()),
        throwsA(isA<EkDogrulanamadi>()),
      );
    });
  });

  group('yükleme', () {
    test(
      'dm_attachment: tek blob, tayfasız, tamamlama 0×0; zarf içeriği',
      () async {
        final o = _Ortam();
        o.api.yanitlar['POST /v1/uploads'] = () => {
          'upload': yuklemeJson(id: _ekId, durum: 'pending'),
          'targets': [
            {
              'kind': 'blob',
              'method': 'PUT',
              'url': '$ornekR2/b/incoming/x/full?X-Amz-Signature=sahte',
              'headers': {'Content-Type': 'application/octet-stream'},
              'expires_at': '2026-11-16T20:05:00Z',
            },
          ],
        };
        o.api.yanitlar['POST /v1/uploads/{upload_id}/complete'] = () => {
          'upload': yuklemeJson(id: _ekId),
        };
        final goruntu = _goruntu();
        final sifreli = await o.servis.sifrele(goruntu);
        final icerik = await o.servis.yukle(
          goruntu: goruntu,
          ek: sifreli,
          istekKimligi: 'b1b2c3d4-0000-4000-8000-000000000009',
        );
        final ac = o.api.istekler.first.govde! as Map<String, Object?>;
        expect(ac['purpose'], 'dm_attachment');
        expect(ac.containsKey('tayfa_id'), isFalse);
        expect(ac['variants'], [
          {
            'kind': 'blob',
            'content_type': 'application/octet-stream',
            'size_bytes': sifreli.blob.length,
          },
        ]);
        expect(o.api.istekler.last.govde, {'width': 0, 'height': 0});
        // Depoya şifreli blob gider; düz görüntü gitmez.
        expect(o.depo.single.bodyBytes, sifreli.blob);
        expect(icerik.ek.uploadId, _ekId);
        expect(icerik.ek.ozet, sifreli.ozet);
        expect(icerik.ek.boyut, sifreli.blob.length);
        // Gönderen kendi fotoğrafını ağdan indirmeden görür.
        expect(o.onbellek.oku(_ekId), goruntu.tam);
      },
    );
  });

  test('bellek önbelleği sınırı: en eski kullanılan atılır', () {
    final o = EkOnbellegi();
    final buyuk = Uint8List(EkOnbellegi.baytEnCok ~/ 2 + 1);
    o
      ..yaz('a', buyuk)
      ..yaz('b', buyuk);
    expect(o.oku('a'), isNull);
    expect(o.oku('b'), isNotNull);
    o.temizle();
    expect(o.toplamBayt, 0);
  });
}
