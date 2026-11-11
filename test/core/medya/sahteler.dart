import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/gen/apis/uploads_api.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';

import '../../features/hesap/sahteler.dart';

/// Metadata'lı örnek JPEG'ler (sahte GPS, XMP, IPTC, MPF, JFXX, JFIF küçük
/// resmi, yorum ve EOI'den sonra ikinci resim; `tool/medya/`).
Uint8List ornekJpeg({bool ilerlemeli = false}) => File(
  'test/core/medya/ornekler/'
  '${ilerlemeli ? 'metadata_ilerlemeli' : 'metadata_temel'}.jpg',
).readAsBytesSync();

/// Örneklerdeki metadata işaretleri: hiçbiri hazırlanan çıktıda olmamalı.
const List<String> metadataIsaretleri = [
  'Exif\u0000\u0000',
  'http://ns.adobe.com/xap',
  'Photoshop 3.0',
  '8BIM',
  'MPF\u0000',
  'JFXX',
  'TAYFAM-SAHTE',
];

/// [b]'de [isaret] (ASCII) geçiyor mu.
bool baytlardaVar(Uint8List b, String isaret) {
  final aranan = isaret.codeUnits;
  outer:
  for (var i = 0; i + aranan.length <= b.length; i++) {
    for (var j = 0; j < aranan.length; j++) {
      if (b[i + j] != aranan[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// [b]'deki ilk SOFn'nin ölçülerini [genislik]×[yukseklik] yapar (yalnızca
/// başlık; testte piksel çözülmez).
Uint8List sofYaz(Uint8List b, int genislik, int yukseklik) {
  final c = Uint8List.fromList(b);
  var i = 2;
  while (i + 4 < c.length) {
    final m = c[i + 1];
    final n = (c[i + 2] << 8) | c[i + 3];
    if (m == 0xC0 || m == 0xC2) {
      c[i + 5] = yukseklik >> 8;
      c[i + 6] = yukseklik & 0xFF;
      c[i + 7] = genislik >> 8;
      c[i + 8] = genislik & 0xFF;
      return c;
    }
    i += 2 + n;
  }
  throw StateError('SOF yok');
}

/// Bir kodlayıcı çağrısı.
typedef KodlayiciCagrisi = ({
  int minGenislik,
  int minYukseklik,
  bool yonuUygula,
  int ornekleme,
  bool kaynakMi,
});

/// `flutter_image_compress`'in ölçek kuralını canlandıran sahte kodlayıcı.
///
/// En kötü durum: çıktıya kaynağın bütün metadata'sını (örnek JPEG'in
/// EXIF/GPS, XMP, IPTC, MPF, ikinci resim …) **aynen** koyar; yalnızca
/// başlıktaki ölçüyü değiştirir. Kaynak ([kaynak]) için ölçü
/// [kaynakOlcusu]'dur (yönü uygulanmamış); [donuk] ise EXIF yönü 90°
/// sayılır ve `yonuUygula` ile genişlik/yükseklik yer değiştirir. Ara
/// çıktılar için ölçü başlıklarından okunur.
final class SahteKodlayici implements GoruntuKodlayici {
  SahteKodlayici({
    required this.kaynak,
    required this.kaynakOlcusu,
    this.donuk = false,
    this.hata,
  });

  final Uint8List kaynak;
  final JpegOlculeri kaynakOlcusu;
  final bool donuk;
  final Exception? hata;
  final List<KodlayiciCagrisi> cagrilar = [];

  @override
  Future<Uint8List> jpegKodla(
    Uint8List girdi, {
    required int minGenislik,
    required int minYukseklik,
    required int kalite,
    required bool yonuUygula,
    int ornekleme = 1,
  }) async {
    final kaynakMi = identical(girdi, kaynak);
    cagrilar.add((
      minGenislik: minGenislik,
      minYukseklik: minYukseklik,
      yonuUygula: yonuUygula,
      ornekleme: ornekleme,
      kaynakMi: kaynakMi,
    ));
    final h = hata;
    if (h != null) throw h;
    var g = kaynakMi ? kaynakOlcusu.genislik : jpegDenetle(girdi).genislik;
    var y = kaynakMi ? kaynakOlcusu.yukseklik : jpegDenetle(girdi).yukseklik;
    if (kaynakMi && donuk && yonuUygula) (g, y) = (y, g);
    if (ornekleme > 1) {
      g = (g + ornekleme - 1) ~/ ornekleme;
      y = (y + ornekleme - 1) ~/ ornekleme;
    }
    final olcekG = g / minGenislik;
    final olcekY = y / minYukseklik;
    var olcek = olcekG < olcekY ? olcekG : olcekY;
    if (olcek < 1) olcek = 1;
    return sofYaz(ornekJpeg(), (g / olcek).floor(), (y / olcek).floor());
  }
}

/// Sırayla verilen baytları döndüren sahte seçici (`null`: vazgeçildi).
final class SahteSecici implements FotografSecici {
  SahteSecici(this.sonuclar);

  final List<Uint8List?> sonuclar;
  final List<FotografKaynagi> kaynaklar = [];

  @override
  Future<Uint8List?> sec(FotografKaynagi kaynak) async {
    kaynaklar.add(kaynak);
    return sonuclar.isEmpty ? null : sonuclar.removeAt(0);
  }
}

/// Örnek hedef linki (sahte hesap; gerçek değil).
const String ornekR2 = 'https://ornekhesap.r2.cloudflarestorage.com';

/// Örnek yükleme kimliği.
const String ornekUploadId = '7d0e8c4a-5b6f-4a1e-9c3d-2f1a0b9e8d7c';

/// `UploadCreated` JSON'u.
Map<String, Object?> yuklemeAcildiJson({
  String id = ornekUploadId,
  String durum = 'pending',
  int onizlemeBoyutu = 10,
  int tamBoyutu = 20,
}) => {
  'upload': yuklemeJson(id: id, durum: durum),
  'targets': [
    if (durum == 'pending') ...[
      {
        'kind': 'preview',
        'method': 'PUT',
        'url': '$ornekR2/b/incoming/x/preview?X-Amz-Signature=sahte',
        'headers': {
          'Content-Type': 'image/jpeg',
          'Content-Length': '$onizlemeBoyutu',
        },
        'expires_at': '2026-11-11T20:05:00Z',
      },
      {
        'kind': 'full',
        'method': 'PUT',
        'url': '$ornekR2/b/incoming/x/full?X-Amz-Signature=sahte',
        'headers': {
          'Content-Type': 'image/jpeg',
          'Content-Length': '$tamBoyutu',
        },
        'expires_at': '2026-11-11T20:05:00Z',
      },
    ],
  ],
};

/// `Upload` JSON'u.
Map<String, Object?> yuklemeJson({
  String id = ornekUploadId,
  String durum = 'ready',
  String? neden,
}) => {
  'id': id,
  'purpose': 'avatar',
  'status': durum,
  'reject_reason': ?neden,
  'size_bytes': 30,
  'created_at': '2026-11-11T20:00:00Z',
  'attached': false,
};

/// `MediaUrls` JSON'u.
Map<String, Object?> medyaLinkiJson(
  String id, {
  String sonGecerlilik = '2026-11-11T21:00:00Z',
  String alan = ornekR2,
}) => {
  'upload_id': id,
  'preview_url': '$alan/b/media/$id/preview?X-Amz-Signature=sahte',
  'preview_content_type': 'image/jpeg',
  'full_url': '$alan/b/media/$id/full?X-Amz-Signature=sahte',
  'full_content_type': 'image/jpeg',
  'width': 1600,
  'height': 1200,
  'expires_at': sonGecerlilik,
};

/// Depoya giden istekleri kaydeden sahte HTTP istemcisi; [yanit] her
/// isteğe cevap verir (verilmezse 200, gövde örnek JPEG).
MockClient sahteDepo(
  List<http.Request> istekler, {
  http.Response Function(http.Request istek)? yanit,
}) => MockClient((istek) async {
  istekler.add(istek);
  return yanit?.call(istek) ??
      http.Response.bytes(ornekJpeg(), 200, headers: {});
});

/// Medya katmanının sahteleri: seçici, kodlayıcı, depo ve [tasima]
/// (üretilmiş uçlar).
List<Override> medyaOverridelari({
  required ApiTransport tasima,
  FotografSecici? secici,
  GoruntuKodlayici? kodlayici,
  http.Client? depo,
  MedyaLinkIsteyici? linkIsteyici,
}) => [
  if (secici != null) fotografSeciciProvider.overrideWithValue(secici),
  if (kodlayici != null) goruntuKodlayiciProvider.overrideWithValue(kodlayici),
  medyaHttpIstemcisiProvider.overrideWithValue(
    depo ?? sahteDepo(<http.Request>[]),
  ),
  medyaYukleyiciProvider.overrideWith(
    (ref) => MedyaYukleyici(
      uploads: UploadsApi(tasima),
      tasima: ref.watch(medyaTasimaProvider),
      bekle: (_) async {},
    ),
  ),
  if (linkIsteyici != null)
    medyaLinkIsteyiciProvider.overrideWithValue(linkIsteyici),
];

/// Kodlayıcının fırlatabileceği platform hatası.
PlatformException platformHatasi() =>
    PlatformException(code: 'unsupported_format');

/// `POST /v1/uploads` ve `complete`'in yanıtlarını [t]'ye ekler; açılan
/// yüklemenin linklerindeki boyutlar istekteki varyantlarınkidir.
void yuklemeYanitlariEkle(SahteTasima t, {String id = ornekUploadId}) {
  t.yanitlar['POST /v1/uploads'] = () {
    final govde = t.istekler.last.govde! as Map<String, Object?>;
    final varyantlar = govde['variants']! as List<Object?>;
    int boyut(int i) {
      final v = varyantlar[i]! as Map<String, Object?>;
      return v['size_bytes']! as int;
    }

    return yuklemeAcildiJson(
      id: id,
      onizlemeBoyutu: boyut(0),
      tamBoyutu: boyut(1),
    );
  };
  t.yanitlar['POST /v1/uploads/{upload_id}/complete'] = () => {
    'upload': yuklemeJson(id: id),
  };
}
