// SAHTE Signal motoru — YALNIZCA TEST İÇİN.
//
// Bu dosyada GERÇEK KRİPTOGRAFİ YOKTUR. "Şifreleme" baytları ters çevirip
// okunur bir JSON başlığı ekler; "HKDF", "AES-GCM-SIV" ve "güvenlik kodu"
// basit, tersine çevrilebilir hesaplardır. Amaç E2E çekirdeğinin ve geçmiş
// arşivinin testlerinde [SignalMotoru] arayüzünün davranışını (oturum
// kurulumu, tür 2/3, ön anahtar tüketimi, tekrar, sıra dışı mesaj, bozuk
// mesaj, hata türleri, durumsuz kayıt turu) gerçekçi biçimde taklit etmektir.
// lib/ altına taşınmaz, uygulamada kullanılmaz.

import 'dart:convert';
import 'dart:typed_data';

import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// SAHTE: gerçek kripto değildir; yalnızca testlerde kullanılır.
final class SahteSignalMotoru implements SignalMotoru {
  SahteSignalMotoru({int tohum = 1}) : _sayac = tohum;

  /// Yapılan çağrıların adları (sırasıyla), test doğrulaması için.
  final List<String> cagrilar = [];

  /// Konursa bir sonraki çağrı bu türle [SignalHatasi] fırlatır, sonra
  /// temizlenir.
  SignalHatasiTuru? sonrakiHata;

  int _sayac;

  static final Uint8List _kimlikOneki = _utf8('SAHTE-KIMLIK:');

  // ---------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------

  void _cagri(String ad) {
    cagrilar.add(ad);
    final hata = sonrakiHata;
    if (hata != null) {
      sonrakiHata = null;
      throw SignalHatasi(hata);
    }
  }

  /// Belirlenimci "rastgele" baytlar (SAHTE; gerçek rastgelelik değil).
  Uint8List _baytlar(int uzunluk, {int onek = 0x05}) {
    final b = Uint8List(uzunluk);
    b[0] = onek;
    for (var i = 1; i < uzunluk; i++) {
      b[i] = (_sayac * 31 + i * 7) & 0xff;
    }
    _sayac++;
    return b;
  }

  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  static Uint8List _json(Map<String, Object?> m) => _utf8(jsonEncode(m));

  static Map<String, Object?>? _jsonOku(Uint8List b) {
    try {
      final d = jsonDecode(utf8.decode(b));
      return d is Map<String, Object?> ? d : null;
    } on FormatException {
      return null;
    }
  }

  static String _b64(Uint8List b) => base64.encode(b);

  static Uint8List _b64Oku(Object? s) =>
      s is String ? base64.decode(s) : Uint8List(0);

  static Uint8List _ters(Uint8List b) =>
      Uint8List.fromList(b.reversed.toList());

  static Uint8List _kimlikAcik(Uint8List kimlik) {
    if (kimlik.length != _kimlikOneki.length + 33) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
    }
    return Uint8List.sublistView(kimlik, _kimlikOneki.length);
  }

  static Map<String, Object?> _oturumOku(Uint8List? oturum) {
    if (oturum == null) {
      throw const SignalHatasi(SignalHatasiTuru.oturumYok);
    }
    final m = _jsonOku(oturum);
    if (m == null || m['sahte'] != 'oturum') {
      throw const SignalHatasi(SignalHatasiTuru.oturumYok);
    }
    return m;
  }

  static Map<String, Object?> _yeniAlanOturumu(Uint8List karsi) => {
    'sahte': 'oturum',
    'karsi': _b64(karsi),
    'gonderilen': 0,
    'alinan': <int>[],
    'kurulum': null,
  };

  static int? _kayitId(Uint8List kayit, String tur) {
    final m = _jsonOku(kayit);
    if (m == null || m['sahte'] != tur) return null;
    final id = m['id'];
    return id is int ? id : null;
  }

  // ---------------------------------------------------------------------
  // Anahtar üretimi
  // ---------------------------------------------------------------------

  @override
  Future<KimlikKaydi> kimlikUret() async {
    _cagri('kimlikUret');
    final acik = _baytlar(33);
    return KimlikKaydi(
      kayit: Uint8List.fromList([..._kimlikOneki, ...acik]),
      acikAnahtar: acik,
      kayitKimligi: 1 + _sayac % 16380,
    );
  }

  @override
  Future<List<OnAnahtarKaydi>> onAnahtarUret(
    int baslangicId,
    int adet,
  ) async {
    _cagri('onAnahtarUret');
    final sonuc = <OnAnahtarKaydi>[];
    var id = baslangicId;
    for (var i = 0; i < adet; i++) {
      if (id > 0xFFFFFF || id < 1) id = 1;
      sonuc.add(
        OnAnahtarKaydi(
          id: id,
          kayit: _json({'sahte': 'on', 'id': id}),
          acikAnahtar: _baytlar(33),
        ),
      );
      id++;
    }
    return sonuc;
  }

  @override
  Future<ImzaliOnAnahtarKaydi> imzaliOnAnahtarUret(
    Uint8List kimlik,
    int id,
  ) async {
    _cagri('imzaliOnAnahtarUret');
    _kimlikAcik(kimlik);
    return ImzaliOnAnahtarKaydi(
      id: id,
      kayit: _json({'sahte': 'imzali', 'id': id}),
      acikAnahtar: _baytlar(33),
      imza: _baytlar(64, onek: 0),
      zaman: 1700000000000 + _sayac,
    );
  }

  @override
  Future<KyberOnAnahtarKaydi> kyberOnAnahtarUret(
    Uint8List kimlik,
    int id,
  ) async {
    _cagri('kyberOnAnahtarUret');
    _kimlikAcik(kimlik);
    return KyberOnAnahtarKaydi(
      id: id,
      kayit: _json({'sahte': 'kyber', 'id': id}),
      acikAnahtar: _baytlar(1569, onek: 0x08),
      imza: _baytlar(64, onek: 0),
    );
  }

  // ---------------------------------------------------------------------
  // Oturum
  // ---------------------------------------------------------------------

  @override
  Future<Uint8List> paketIsle({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi adres,
    Uint8List? mevcutOturum,
    required OnAnahtarPaketi paket,
  }) async {
    _cagri('paketIsle');
    _kimlikAcik(kimlik);
    if (paket.kimlikAnahtari.length != 33 ||
        paket.imzaliOnAnahtarImzasi.length != 64 ||
        paket.kyberOnAnahtarImzasi.length != 64 ||
        paket.kyberOnAnahtar.length != 1569) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
    }
    return _json({
      'sahte': 'oturum',
      'karsi': _b64(paket.kimlikAnahtari),
      'gonderilen': 0,
      'alinan': <int>[],
      'kurulum': {
        'op': paket.onAnahtarId,
        'ip': paket.imzaliOnAnahtarId,
        'ky': paket.kyberOnAnahtarId,
        'tb': _b64(_baytlar(33)),
      },
    });
  }

  @override
  Future<SifreliMesaj> sifrele({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi adres,
    required Uint8List oturum,
    required Uint8List duz,
  }) async {
    _cagri('sifrele');
    final acik = _kimlikAcik(kimlik);
    final o = _oturumOku(oturum);
    final n = (o['gonderilen'] as int?) ?? 0;
    final kurulum = o['kurulum'];
    final baslik = <String, Object?>{'sahte': 'mesaj', 'n': n};
    final int tur;
    if (kurulum is Map<String, Object?>) {
      tur = SignalMesajTuru.onAnahtar;
      baslik
        ..['g'] = _b64(acik)
        ..['kk'] = kayitKimligi
        ..addAll(kurulum);
    } else {
      tur = SignalMesajTuru.signal;
    }
    baslik['d'] = _b64(_ters(duz));
    o['gonderilen'] = n + 1;
    return SifreliMesaj(tur: tur, sifreli: _json(baslik), yeniOturum: _json(o));
  }

  @override
  Future<OnAnahtarBilgisi> onAnahtarMesajiIncele(Uint8List sifreli) async {
    _cagri('onAnahtarMesajiIncele');
    final m = _jsonOku(sifreli);
    if (m == null || m['sahte'] != 'mesaj' || m['ip'] is! int) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
    return OnAnahtarBilgisi(
      onAnahtarId: m['op'] as int?,
      imzaliOnAnahtarId: m['ip'] as int,
      gondericiKimligi: _b64Oku(m['g']),
      kayitKimligi: (m['kk'] as int?) ?? 0,
      tabanAnahtar: _b64Oku(m['tb']),
    );
  }

  @override
  Future<CozulmusMesaj> coz({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi adres,
    required int tur,
    required Uint8List sifreli,
    Uint8List? oturum,
    Uint8List? onAnahtar,
    Uint8List? imzaliOnAnahtar,
    List<Uint8List> kyberOnAnahtarlari = const [],
  }) async {
    _cagri('coz');
    _kimlikAcik(kimlik);
    final m = _jsonOku(sifreli);
    if (m == null || m['sahte'] != 'mesaj' || m['n'] is! int) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
    final n = m['n'] as int;
    final onAnahtarliMi = m['ip'] is int;
    if ((tur == SignalMesajTuru.onAnahtar) != onAnahtarliMi) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }

    Map<String, Object?> o;
    int? kullanilanOn;
    int? kullanilanImzali;
    int? kullanilanKyber;
    Uint8List? taban;
    if (tur == SignalMesajTuru.onAnahtar) {
      final ip = m['ip'] as int;
      final op = m['op'] as int?;
      final ky = m['ky'] as int?;
      if (imzaliOnAnahtar == null ||
          _kayitId(imzaliOnAnahtar, 'imzali') != ip) {
        throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
      }
      if (op != null &&
          (onAnahtar == null || _kayitId(onAnahtar, 'on') != op)) {
        throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
      }
      if (ky == null ||
          !kyberOnAnahtarlari.any((k) => _kayitId(k, 'kyber') == ky)) {
        throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
      }
      final karsi = _b64Oku(m['g']);
      Map<String, Object?>? mevcut;
      if (oturum != null) {
        final x = _jsonOku(oturum);
        if (x != null && x['karsi'] == _b64(karsi)) mevcut = x;
      }
      o = mevcut ?? _yeniAlanOturumu(karsi);
      kullanilanOn = op;
      kullanilanImzali = ip;
      kullanilanKyber = ky;
      taban = _b64Oku(m['tb']);
    } else {
      o = _oturumOku(oturum);
    }

    final alinan = [...((o['alinan'] as List<Object?>?) ?? const <Object?>[])];
    if (alinan.contains(n)) {
      throw const SignalHatasi(SignalHatasiTuru.eskiMesaj);
    }
    final d = m['d'];
    if (d is! String) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
    final Uint8List govde;
    try {
      govde = base64.decode(d);
    } on FormatException {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
    alinan.add(n);
    o
      ..['alinan'] = alinan
      // Karşı taraftan mesaj alınca ön anahtar kurulumu tamamlanır.
      ..['kurulum'] = null;
    return CozulmusMesaj(
      duz: _ters(govde),
      yeniOturum: _json(o),
      kullanilanOnAnahtarId: kullanilanOn,
      kullanilanImzaliId: kullanilanImzali,
      kullanilanKyberId: kullanilanKyber,
      kyberTabanAnahtari: taban,
      karsiKimlik: _b64Oku(o['karsi']),
    );
  }

  // ---------------------------------------------------------------------
  // Simetrik yapı taşları (SAHTE)
  // ---------------------------------------------------------------------

  @override
  Future<Uint8List> hkdf({
    required Uint8List girdi,
    Uint8List? tuz,
    required Uint8List bilgi,
    required int uzunluk,
  }) async {
    _cagri('hkdf');
    final kaynak = [...girdi, ...?tuz, 0xff, ...bilgi];
    final sonuc = Uint8List(uzunluk);
    var t = 17;
    for (var i = 0; i < uzunluk; i++) {
      t = (t * 31 + kaynak[i % kaynak.length] + i) & 0xffff;
      sonuc[i] = t & 0xff;
    }
    return sonuc;
  }

  static Uint8List _etiket(
    Uint8List anahtar,
    Uint8List nonce,
    Uint8List aad,
    Uint8List govde,
  ) {
    final e = Uint8List(16);
    final hepsi = [...anahtar, ...nonce, ...aad, ...govde];
    for (var i = 0; i < hepsi.length; i++) {
      e[i % 16] = (e[i % 16] * 7 + hepsi[i] + i) & 0xff;
    }
    return e;
  }

  @override
  Future<Uint8List> aesGcmSivSifrele({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List duz,
    required Uint8List aad,
  }) async {
    _cagri('aesGcmSivSifrele');
    if (anahtar.length != 32 || nonce.length != 12) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
    }
    final govde = _ters(duz);
    return Uint8List.fromList([
      ...govde,
      ..._etiket(anahtar, nonce, aad, govde),
    ]);
  }

  @override
  Future<Uint8List?> aesGcmSivCoz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreli,
    required Uint8List aad,
  }) async {
    _cagri('aesGcmSivCoz');
    if (anahtar.length != 32 || nonce.length != 12) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
    }
    if (sifreli.length < 16) return null;
    final govde = Uint8List.sublistView(sifreli, 0, sifreli.length - 16);
    final etiket = Uint8List.sublistView(sifreli, sifreli.length - 16);
    final beklenen = _etiket(anahtar, nonce, aad, govde);
    for (var i = 0; i < 16; i++) {
      if (etiket[i] != beklenen[i]) return null;
    }
    return _ters(govde);
  }

  // ---------------------------------------------------------------------
  // Güvenlik kodu (SAHTE; iki tarafta aynı)
  // ---------------------------------------------------------------------

  static String _yarim(Uint8List acik, Uint8List tanimlayici) {
    final b = StringBuffer();
    final kaynak = [...tanimlayici, ...acik];
    var t = 5;
    for (var i = 0; i < 30; i++) {
      t = (t * 31 + kaynak[i % kaynak.length] + i) % 100003;
      b.write(t % 10);
    }
    return b.toString();
  }

  @override
  Future<String> guvenlikKodu({
    required Uint8List yerelKimlikAcik,
    required Uint8List yerelTanimlayici,
    required Uint8List karsiKimlikAcik,
    required Uint8List karsiTanimlayici,
  }) async {
    _cagri('guvenlikKodu');
    final a = _yarim(yerelKimlikAcik, yerelTanimlayici);
    final b = _yarim(karsiKimlikAcik, karsiTanimlayici);
    return a.compareTo(b) <= 0 ? '$a$b' : '$b$a';
  }
}
