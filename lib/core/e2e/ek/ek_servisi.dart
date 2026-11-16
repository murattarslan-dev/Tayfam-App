import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/imzali_indirme.dart';
import 'package:tayfam/core/e2e/cihaz/e2e_cihaz.dart' show e2eMotoruProvider;
import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart';
import 'package:tayfam/core/e2e/mesaj/zarf_icerigi.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/goruntu_onbellegi.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Ek bu kullanıcıya görünmüyor (silinmiş, yetkisiz ya da bilinmeyen;
/// sunucu nedenini söylemez).
final class EkGorulemez implements Exception {
  const EkGorulemez();

  @override
  String toString() => 'EkGorulemez';
}

/// Çözülmüş ek görüntüleri için bellek önbelleği (ADR-0006, istemci
/// ADR-0028 §4): en çok [baytEnCok] bayt, en eski kullanılan önce atılır.
/// Diske hiçbir şey yazılmaz; oturum değişince boşalır.
final class EkOnbellegi {
  /// Önbelleğin üst sınırı.
  static const int baytEnCok = 32 * 1024 * 1024;

  final Map<String, Uint8List> _baytlar = {};
  int _toplam = 0;

  /// Önbellekteki bayt toplamı (testler için).
  @visibleForTesting
  int get toplamBayt => _toplam;

  /// [uploadId]'nin çözülmüş görüntüsü; yoksa `null`.
  Uint8List? oku(String uploadId) {
    final veri = _baytlar.remove(uploadId);
    if (veri != null) _baytlar[uploadId] = veri;
    return veri;
  }

  /// [uploadId] için [veri]'yi saklar.
  void yaz(String uploadId, Uint8List veri) {
    if (veri.length > baytEnCok) return;
    final eski = _baytlar.remove(uploadId);
    if (eski != null) _toplam -= eski.length;
    _baytlar[uploadId] = veri;
    _toplam += veri.length;
    while (_toplam > baytEnCok && _baytlar.isNotEmpty) {
      final ilk = _baytlar.keys.first;
      _toplam -= _baytlar.remove(ilk)!.length;
    }
  }

  /// Her şeyi bırakır.
  void temizle() {
    _baytlar.clear();
    _toplam = 0;
  }
}

/// Birebir mesaj eklerinin (şifreli fotoğraf) hazırlanması ve açılması
/// (istemci ADR-0028 §2, §4).
///
/// - [hazirla]: ADR-0021 hattından geçmiş görüntünün tam varyantını yeni
///   bir anahtarla şifreler, `dm_attachment` olarak yükler ve zarfa
///   girecek [FotografIcerigi]'ni döndürür.
/// - [ac]: link → imzalı linkten tam `boyut` bayt → özet → çözme. Sonuç
///   yalnızca bellektedir.
///
/// Anahtar, blob ve çözülmüş görüntü diske yazılmaz ve loglanmaz.
final class E2eEkServisi {
  E2eEkServisi({
    required this.sifreleyici,
    required this._yukleyici,
    required this._medya,
    required this._indirici,
    required this.onbellek,
  });

  final EkSifreleyici sifreleyici;
  final MedyaYukleyici _yukleyici;
  final MedyaOnbellegi _medya;
  final ImzaliIndirici _indirici;
  final EkOnbellegi onbellek;

  final Map<String, Future<Uint8List>> _acilanlar = {};

  /// [goruntu]'yü şifreler. Aynı iş tekrar denenirken aynı [SifreliEk]
  /// kullanılmalıdır (çağıran saklar); yeni anahtar yeni blob demektir.
  Future<SifreliEk> sifrele(HazirGoruntu goruntu) =>
      sifreleyici.sifrele(goruntu.tam);

  /// [ek]'i aynı [istekKimligi] ile yükler ve zarf içeriğini döndürür.
  /// Gönderenin kendi görüntüsü çözülmüş önbelleğe konur.
  Future<FotografIcerigi> yukle({
    required HazirGoruntu goruntu,
    required SifreliEk ek,
    required String istekKimligi,
  }) async {
    final uploadId = await _yukleyici.sifreliEkYukle(
      blob: ek.blob,
      istekKimligi: istekKimligi,
    );
    onbellek.yaz(uploadId, goruntu.tam);
    return FotografIcerigi(
      EkAnahtari(
        uploadId: uploadId,
        anahtar: ek.anahtar,
        ozet: ek.ozet,
        boyut: ek.blob.length,
        genislik: goruntu.tamOlcu.genislik,
        yukseklik: goruntu.tamOlcu.yukseklik,
      ),
    );
  }

  /// [ek]'in çözülmüş görüntüsü. Görülemiyorsa [EkGorulemez]; özet,
  /// boyut, biçim ya da etiket tutmazsa [EkDogrulanamadi]; bağlantı
  /// hatası olduğu gibi fırlatılır (tekrar denenebilir).
  Future<Uint8List> ac(EkAnahtari ek) {
    final hazir = onbellek.oku(ek.uploadId);
    if (hazir != null) return Future.value(hazir);
    final anahtar = ek.uploadId;
    return _acilanlar[anahtar] ??= _ac(ek).whenComplete(() {
      _acilanlar.remove(anahtar);
    });
  }

  Future<Uint8List> _ac(EkAnahtari ek) async {
    final link = await _medya.link(ek.uploadId);
    if (link == null) throw const EkGorulemez();
    if (!link.sifreliEk) throw const EkDogrulanamadi();
    final Uint8List blob;
    try {
      blob = await _indirici.indir(
        link.tam,
        beklenenBoyut: ek.boyut,
        enCok: ekEnCokBayt,
      );
    } on ImzaliIndirmeHatasi catch (h) {
      if (h.tur == ImzaliIndirmeHataTuru.boyut ||
          h.tur == ImzaliIndirmeHataTuru.gecersizAdres) {
        throw const EkDogrulanamadi();
      }
      rethrow;
    }
    final duz = await sifreleyici.coz(
      blob: blob,
      anahtar: ek.anahtar,
      ozet: ek.ozet,
    );
    _goruntuyuDenetle(duz, ek);
    onbellek.yaz(ek.uploadId, duz);
    return duz;
  }

  /// Çözülen baytlar, bitmap'e açılmadan önce, gönderen hattının ürettiği
  /// biçimde olmalı: metadata'sız tek JPEG, en uzun kenar en çok
  /// [tamUzunKenar] ve ölçüler zarftakiyle aynı. Aksi halde (ör. bellek
  /// tüketmek için devasa piksel ölçülü görüntü) [EkDogrulanamadi].
  static void _goruntuyuDenetle(Uint8List duz, EkAnahtari ek) {
    final JpegOlculeri olcu;
    try {
      olcu = jpegDenetle(duz);
    } on JpegHatasi {
      throw const EkDogrulanamadi();
    }
    if (olcu.uzunKenar > tamUzunKenar ||
        olcu.genislik != ek.genislik ||
        olcu.yukseklik != ek.yukseklik) {
      throw const EkDogrulanamadi();
    }
  }
}

/// Çözülmüş ek önbelleği (oturum değişince yeniden kurulur).
final ekOnbellegiProvider = Provider<EkOnbellegi>((ref) {
  ref.watch(oturumDurumuProvider);
  final onbellek = EkOnbellegi();
  ref.onDispose(() {
    onbellek.temizle();
    // Çözülmüş bitmap'ler Flutter'ın görüntü önbelleğinde de kalmasın.
    flutterGoruntuOnbelleginiTemizle();
  });
  return onbellek;
}, name: 'ekOnbellegiProvider');

/// Uygulamanın ek servisi.
final e2eEkServisiProvider = Provider<E2eEkServisi>(
  (ref) => E2eEkServisi(
    sifreleyici: EkSifreleyici(ref.watch(e2eMotoruProvider)),
    yukleyici: ref.watch(medyaYukleyiciProvider),
    medya: ref.watch(medyaOnbellegiProvider),
    indirici: ref.watch(imzaliIndiriciProvider),
    onbellek: ref.watch(ekOnbellegiProvider),
  ),
  name: 'e2eEkServisiProvider',
);

/// Bir ekin çözülmüş görüntüsü; görsel kapanınca bırakılır (baytlar
/// [EkOnbellegi]'nde kalır). Hata otomatik yeniden denenmez.
class BirebirEkNotifier extends AsyncNotifier<Uint8List> {
  BirebirEkNotifier(this.ek);

  final EkAnahtari ek;

  @override
  Future<Uint8List> build() => ref.watch(e2eEkServisiProvider).ac(ek);
}

/// Bir ekin çözülmüş görüntüsü (`family` + `autoDispose`).
final birebirEkProvider = AsyncNotifierProvider.autoDispose
    .family<BirebirEkNotifier, Uint8List, EkAnahtari>(
      BirebirEkNotifier.new,
      name: 'birebirEkProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
