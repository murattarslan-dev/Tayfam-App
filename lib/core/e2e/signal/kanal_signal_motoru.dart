import 'package:flutter/services.dart';

import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// [SignalMotoru]'nun Android uygulaması: `tayfam/e2e/signal` platform
/// kanalı üzerinden Kotlin köprüsü (`SignalKoprusu.kt`) ve Signal'in resmi
/// `org.signal:libsignal-android` paketi (ADR-0010, güncelleme
/// 2026-11-11).
///
/// Köprü durumsuzdur; bu sınıf da durum tutmaz. Kanal hata kodu
/// [SignalHatasiTuru] adıdır; mesaj ve ayrıntı taşınmaz. Hiçbir şey
/// log'lanmaz.
final class KanalSignalMotoru implements SignalMotoru {
  KanalSignalMotoru([MethodChannel? kanal])
    : _kanal = kanal ?? const MethodChannel(kanalAdi);

  /// Platform kanalının adı (Kotlin tarafıyla aynı).
  static const String kanalAdi = 'tayfam/e2e/signal';

  final MethodChannel _kanal;

  Future<Map<Object?, Object?>> _cagir(
    String yontem, [
    Map<String, Object?> arg = const {},
  ]) async {
    final Map<Object?, Object?>? sonuc;
    try {
      sonuc = await _kanal.invokeMapMethod<Object?, Object?>(yontem, arg);
    } on PlatformException catch (e) {
      throw SignalHatasi(_tur(e.code));
    } on MissingPluginException {
      throw UnsupportedError('E2E bu platformda yok');
    }
    if (sonuc == null) {
      throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
    }
    return sonuc;
  }

  static SignalHatasiTuru _tur(String kod) {
    for (final t in SignalHatasiTuru.values) {
      if (t.name == kod) return t;
    }
    return SignalHatasiTuru.bilinmeyen;
  }

  static Uint8List _bayt(Map<Object?, Object?> m, String ad) {
    final d = m[ad];
    if (d is Uint8List) return d;
    throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
  }

  static Uint8List? _baytVeyaNull(Map<Object?, Object?> m, String ad) {
    final d = m[ad];
    if (d == null) return null;
    if (d is Uint8List) return d;
    throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
  }

  static int _tam(Map<Object?, Object?> m, String ad) {
    final d = m[ad];
    if (d is int) return d;
    throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
  }

  static int? _tamVeyaNull(Map<Object?, Object?> m, String ad) {
    final d = m[ad];
    if (d == null) return null;
    if (d is int) return d;
    throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
  }

  static Map<String, Object?> _ortak({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
  }) => {
    'kimlik': kimlik,
    'kayitKimligi': kayitKimligi,
    'yerelAd': yerelAdres.ad,
    'yerelCihaz': yerelAdres.cihazNo,
    'ad': adres.ad,
    'cihaz': adres.cihazNo,
  };

  @override
  Future<KimlikKaydi> kimlikUret() async {
    final m = await _cagir('kimlikUret');
    return KimlikKaydi(
      kayit: _bayt(m, 'kayit'),
      acikAnahtar: _bayt(m, 'acik'),
      kayitKimligi: _tam(m, 'kayitKimligi'),
    );
  }

  @override
  Future<List<OnAnahtarKaydi>> onAnahtarUret(int baslangicId, int adet) async {
    final m = await _cagir('onAnahtarUret', {
      'baslangicId': baslangicId,
      'adet': adet,
    });
    final liste = m['anahtarlar'];
    if (liste is! List<Object?>) {
      throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
    }
    return [
      for (final o in liste)
        if (o is Map<Object?, Object?>)
          OnAnahtarKaydi(
            id: _tam(o, 'id'),
            kayit: _bayt(o, 'kayit'),
            acikAnahtar: _bayt(o, 'acik'),
          )
        else
          throw const SignalHatasi(SignalHatasiTuru.bilinmeyen),
    ];
  }

  @override
  Future<ImzaliOnAnahtarKaydi> imzaliOnAnahtarUret(
    Uint8List kimlik,
    int id,
  ) async {
    final m = await _cagir('imzaliOnAnahtarUret', {'kimlik': kimlik, 'id': id});
    return ImzaliOnAnahtarKaydi(
      id: _tam(m, 'id'),
      kayit: _bayt(m, 'kayit'),
      acikAnahtar: _bayt(m, 'acik'),
      imza: _bayt(m, 'imza'),
      zaman: _tam(m, 'zaman'),
    );
  }

  @override
  Future<KyberOnAnahtarKaydi> kyberOnAnahtarUret(
    Uint8List kimlik,
    int id,
  ) async {
    final m = await _cagir('kyberOnAnahtarUret', {'kimlik': kimlik, 'id': id});
    return KyberOnAnahtarKaydi(
      id: _tam(m, 'id'),
      kayit: _bayt(m, 'kayit'),
      acikAnahtar: _bayt(m, 'acik'),
      imza: _bayt(m, 'imza'),
    );
  }

  @override
  Future<Uint8List> paketIsle({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
    Uint8List? mevcutOturum,
    required OnAnahtarPaketi paket,
  }) async {
    final m = await _cagir('paketIsle', {
      ..._ortak(
        kimlik: kimlik,
        kayitKimligi: kayitKimligi,
        yerelAdres: yerelAdres,
        adres: adres,
      ),
      'oturum': mevcutOturum,
      'paket': {
        'kayitKimligi': paket.kayitKimligi,
        'cihazNo': paket.cihazNo,
        'onAnahtarId': paket.onAnahtarId,
        'onAnahtar': paket.onAnahtar,
        'imzaliOnAnahtarId': paket.imzaliOnAnahtarId,
        'imzaliOnAnahtar': paket.imzaliOnAnahtar,
        'imzaliOnAnahtarImzasi': paket.imzaliOnAnahtarImzasi,
        'kimlikAnahtari': paket.kimlikAnahtari,
        'kyberOnAnahtarId': paket.kyberOnAnahtarId,
        'kyberOnAnahtar': paket.kyberOnAnahtar,
        'kyberOnAnahtarImzasi': paket.kyberOnAnahtarImzasi,
      },
    });
    return _bayt(m, 'oturum');
  }

  @override
  Future<SifreliMesaj> sifrele({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
    required Uint8List oturum,
    required Uint8List duz,
  }) async {
    final m = await _cagir('sifrele', {
      ..._ortak(
        kimlik: kimlik,
        kayitKimligi: kayitKimligi,
        yerelAdres: yerelAdres,
        adres: adres,
      ),
      'oturum': oturum,
      'duz': duz,
    });
    return SifreliMesaj(
      tur: _tam(m, 'tur'),
      sifreli: _bayt(m, 'sifreli'),
      yeniOturum: _bayt(m, 'oturum'),
    );
  }

  @override
  Future<OnAnahtarBilgisi> onAnahtarMesajiIncele(Uint8List sifreli) async {
    final m = await _cagir('onAnahtarMesajiIncele', {'sifreli': sifreli});
    return OnAnahtarBilgisi(
      onAnahtarId: _tamVeyaNull(m, 'onAnahtarId'),
      imzaliOnAnahtarId: _tam(m, 'imzaliId'),
      gondericiKimligi: _bayt(m, 'gondericiKimligi'),
      kayitKimligi: _tam(m, 'kayitKimligi'),
      tabanAnahtar: _bayt(m, 'tabanAnahtar'),
    );
  }

  @override
  Future<CozulmusMesaj> coz({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi yerelAdres,
    required SignalAdresi adres,
    required int tur,
    required Uint8List sifreli,
    Uint8List? oturum,
    Uint8List? onAnahtar,
    Uint8List? imzaliOnAnahtar,
    List<Uint8List> kyberOnAnahtarlari = const [],
  }) async {
    final m = await _cagir('coz', {
      ..._ortak(
        kimlik: kimlik,
        kayitKimligi: kayitKimligi,
        yerelAdres: yerelAdres,
        adres: adres,
      ),
      'tur': tur,
      'sifreli': sifreli,
      'oturum': oturum,
      'onAnahtar': onAnahtar,
      'imzaliOnAnahtar': imzaliOnAnahtar,
      'kyberOnAnahtarlari': kyberOnAnahtarlari,
    });
    return CozulmusMesaj(
      duz: _bayt(m, 'duz'),
      yeniOturum: _bayt(m, 'oturum'),
      kullanilanOnAnahtarId: _tamVeyaNull(m, 'onAnahtarId'),
      kullanilanImzaliId: _tamVeyaNull(m, 'imzaliId'),
      kullanilanKyberId: _tamVeyaNull(m, 'kyberId'),
      kyberTabanAnahtari: _baytVeyaNull(m, 'kyberTaban'),
      karsiKimlik: _bayt(m, 'karsiKimlik'),
    );
  }

  @override
  Future<Uint8List> hkdf({
    required Uint8List girdi,
    Uint8List? tuz,
    required Uint8List bilgi,
    required int uzunluk,
  }) async {
    final m = await _cagir('hkdf', {
      'girdi': girdi,
      'tuz': tuz,
      'bilgi': bilgi,
      'uzunluk': uzunluk,
    });
    return _bayt(m, 'cikti');
  }

  @override
  Future<Uint8List> aesGcmSivSifrele({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List duz,
    required Uint8List aad,
  }) async {
    final m = await _cagir('aesGcmSivSifrele', {
      'anahtar': anahtar,
      'nonce': nonce,
      'duz': duz,
      'aad': aad,
    });
    return _bayt(m, 'sifreli');
  }

  @override
  Future<Uint8List?> aesGcmSivCoz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreli,
    required Uint8List aad,
  }) async {
    final m = await _cagir('aesGcmSivCoz', {
      'anahtar': anahtar,
      'nonce': nonce,
      'sifreli': sifreli,
      'aad': aad,
    });
    return _baytVeyaNull(m, 'duz');
  }

  @override
  Future<Uint8List?> aes256GcmCoz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreliVeEtiket,
    required Uint8List aad,
  }) async {
    final m = await _cagir('aes256GcmCoz', {
      'anahtar': anahtar,
      'nonce': nonce,
      'sifreliVeEtiket': sifreliVeEtiket,
      'aad': aad,
    });
    return _baytVeyaNull(m, 'duz');
  }

  @override
  Future<String> guvenlikKodu({
    required Uint8List yerelKimlikAcik,
    required Uint8List yerelTanimlayici,
    required Uint8List karsiKimlikAcik,
    required Uint8List karsiTanimlayici,
  }) async {
    final m = await _cagir('guvenlikKodu', {
      'yerelKimlik': yerelKimlikAcik,
      'yerelTanimlayici': yerelTanimlayici,
      'karsiKimlik': karsiKimlikAcik,
      'karsiTanimlayici': karsiTanimlayici,
    });
    final kod = m['kod'];
    if (kod is String) return kod;
    throw const SignalHatasi(SignalHatasiTuru.bilinmeyen);
  }
}
