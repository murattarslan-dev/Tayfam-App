import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/depo/e2e_anahtar_deposu.dart';

/// Güvenli depoya yazılamadı. Gönderim ya da alım tamamlanmış sayılmaz
/// (ADR-0010: durum depoya yazılmadan mesaj gönderilmiş/alınmış sayılmaz).
final class E2eDepoHatasi implements Exception {
  const E2eDepoHatasi();

  @override
  String toString() => 'E2eDepoHatasi';
}

/// Kimlik anahtar çifti ve kayıt kimliği (depodaki biçim).
final class DepoKimligi {
  const DepoKimligi({
    required this.kayit,
    required this.acikAnahtar,
    required this.kayitKimligi,
  });

  final Uint8List kayit;
  final Uint8List acikAnahtar;
  final int kayitKimligi;
}

/// Bu cihazın sunucudaki kimliği ve Signal cihaz numarası.
final class DepoCihazi {
  const DepoCihazi({required this.id, required this.no});

  final String id;
  final int no;
}

/// İmzalı ön anahtar ya da son çare Kyber ön anahtarı kaydı.
final class DepoImzaliKayit {
  const DepoImzaliKayit({
    required this.id,
    required this.kayit,
    required this.zaman,
    this.emekli,
  });

  final int id;
  final Uint8List kayit;

  /// Üretim zamanı.
  final DateTime zaman;

  /// Yerine yenisi geçtiği an; 30 gün sonra silinir.
  final DateTime? emekli;
}

/// Ön anahtar kimlik sayaçları ve etkin imzalı anahtarlar.
final class DepoSayaci {
  const DepoSayaci({
    this.sonrakiOnAnahtar = 1,
    this.sonrakiKyber = 1,
    this.sonrakiImzali = 1,
    this.etkinImzali,
    this.etkinSonCare,
  });

  final int sonrakiOnAnahtar;
  final int sonrakiKyber;
  final int sonrakiImzali;
  final int? etkinImzali;
  final int? etkinSonCare;

  DepoSayaci ile({
    int? sonrakiOnAnahtar,
    int? sonrakiKyber,
    int? sonrakiImzali,
    int? etkinImzali,
    int? etkinSonCare,
  }) => DepoSayaci(
    sonrakiOnAnahtar: sonrakiOnAnahtar ?? this.sonrakiOnAnahtar,
    sonrakiKyber: sonrakiKyber ?? this.sonrakiKyber,
    sonrakiImzali: sonrakiImzali ?? this.sonrakiImzali,
    etkinImzali: etkinImzali ?? this.etkinImzali,
    etkinSonCare: etkinSonCare ?? this.etkinSonCare,
  );
}

/// Karşı cihazla Signal oturumu.
final class DepoOturumu {
  const DepoOturumu({
    required this.cihazNo,
    required this.kayitKimligi,
    required this.kayit,
  });

  final int cihazNo;
  final int kayitKimligi;
  final Uint8List kayit;
}

/// Karşı cihazın güvenilen (TOFU) kimlik anahtarı.
final class DepoKarsiKimlik {
  const DepoKarsiKimlik({required this.acikAnahtar, required this.kullaniciId});

  final Uint8List acikAnahtar;
  final String kullaniciId;
}

/// E2E kayıtlarının türlü görünümü (ADR-0020 "Depo").
///
/// Açılışta bütün kayıtlar bir kez okunur ([yukle]) ve bellekte tutulur;
/// her yazma önce güvenli depoya, başarılıysa belleğe gider. Okuma ve
/// yazma istisna fırlatmaz; yazma başarısızsa `false` döner (çağıran
/// [E2eDepoHatasi]'na çevirir). Bozuk kayıt yok sayılır.
///
/// Anahtar düzeni (`e2e.` önekli, ayrı ad alanında):
/// `kimlik`, `cihaz`, `sayac`, `imzali.<id>`, `kyber_son_care.<id>`,
/// `onk.<id>`, `kyber.<id>`, `kyber_kullanilan.<id>`, `oturum.<cihazId>`,
/// `kimlik_karsi.<cihazId>`, `gorulen`, `anahtar_olayi.<kullaniciId>`,
/// `karsi_cihazlar.<kullaniciId>`; `gecmis.<sürüm>` geçmiş arşivine ayrılır.
final class E2eDeposu {
  E2eDeposu(this._depo);

  final E2eAnahtarDeposu _depo;

  Map<String, String> _bellek = {};
  Future<void>? _yukleme;

  /// Görülen zarf kimliklerinden saklanan en çok sayı.
  static const int gorulenEnCok = 500;

  static const String onek = 'e2e.';
  static const String kimlikAnahtari = '${onek}kimlik';
  static const String cihazAnahtari = '${onek}cihaz';
  static const String sayacAnahtari = '${onek}sayac';
  static const String gorulenAnahtari = '${onek}gorulen';
  static String imzaliAnahtari(int id) => '${onek}imzali.$id';
  static String sonCareAnahtari(int id) => '${onek}kyber_son_care.$id';
  static String onAnahtarAnahtari(int id) => '${onek}onk.$id';
  static String kyberAnahtari(int id) => '${onek}kyber.$id';
  static String kyberKullanilanAnahtari(int id) =>
      '${onek}kyber_kullanilan.$id';
  static String oturumAnahtari(String cihazId) => '${onek}oturum.$cihazId';
  static String karsiKimlikAnahtari(String cihazId) =>
      '${onek}kimlik_karsi.$cihazId';
  static String anahtarOlayiAnahtari(String kullaniciId) =>
      '${onek}anahtar_olayi.$kullaniciId';
  static String karsiCihazlarAnahtari(String kullaniciId) =>
      '${onek}karsi_cihazlar.$kullaniciId';

  /// Depodaki kayıtları bir kez okur.
  Future<void> yukle() => _yukleme ??= _oku();

  Future<void> _oku() async {
    _bellek = Map.of(await _depo.hepsi());
  }

  /// Bütün E2E kayıtlarını siler (bellek dahil).
  Future<bool> temizle() async {
    final tamam = await _depo.temizle();
    _bellek = {};
    _yukleme = Future<void>.value();
    return tamam;
  }

  // ---------------------------------------------------------------- ham

  /// Ham kayıt (geçmiş arşivi gibi başka katmanlar için).
  String? ham(String anahtar) => _bellek[anahtar];

  /// [onek] ile başlayan anahtarlar.
  List<String> anahtarlar(String onek) => [
    for (final a in _bellek.keys)
      if (a.startsWith(onek)) a,
  ];

  /// Ham kayıt yazar; başarısızsa `false`.
  Future<bool> hamYaz(String anahtar, String deger) async {
    if (!await _depo.yaz(anahtar, deger)) return false;
    _bellek[anahtar] = deger;
    return true;
  }

  /// Ham kaydı siler; başarısızsa `false` (bellekten yine de çıkar).
  Future<bool> hamSil(String anahtar) async {
    _bellek.remove(anahtar);
    return _depo.sil(anahtar);
  }

  Future<bool> _jsonYaz(String anahtar, Object deger) =>
      hamYaz(anahtar, jsonEncode(deger));

  Map<String, Object?>? _json(String anahtar) {
    final metin = _bellek[anahtar];
    if (metin == null) return null;
    try {
      final d = jsonDecode(metin);
      return d is Map<String, Object?> ? d : null;
    } on FormatException {
      return null;
    }
  }

  // ------------------------------------------------------------ kimlik

  DepoKimligi? get kimlik {
    final j = _json(kimlikAnahtari);
    final kayit = baytOku(j?['kayit']);
    final acik = baytOku(j?['acik']);
    final kk = j?['kk'];
    if (kayit == null || acik == null || kk is! int) return null;
    return DepoKimligi(kayit: kayit, acikAnahtar: acik, kayitKimligi: kk);
  }

  Future<bool> kimlikYaz(DepoKimligi k) => _jsonYaz(kimlikAnahtari, {
    'v': 1,
    'kayit': base64.encode(k.kayit),
    'acik': base64.encode(k.acikAnahtar),
    'kk': k.kayitKimligi,
  });

  DepoCihazi? get cihaz {
    final j = _json(cihazAnahtari);
    final id = j?['id'];
    final no = j?['no'];
    if (id is! String || no is! int) return null;
    return DepoCihazi(id: id, no: no);
  }

  Future<bool> cihazYaz(DepoCihazi c) =>
      _jsonYaz(cihazAnahtari, {'v': 1, 'id': c.id, 'no': c.no});

  DepoSayaci get sayac {
    final j = _json(sayacAnahtari);
    if (j == null) return const DepoSayaci();
    int sayi(String a) => switch (j[a]) {
      final int v when v > 0 => v,
      _ => 1,
    };
    return DepoSayaci(
      sonrakiOnAnahtar: sayi('onk'),
      sonrakiKyber: sayi('kyber'),
      sonrakiImzali: sayi('imzali'),
      etkinImzali: switch (j['imzali_etkin']) {
        final int v => v,
        _ => null,
      },
      etkinSonCare: switch (j['son_care_etkin']) {
        final int v => v,
        _ => null,
      },
    );
  }

  Future<bool> sayacYaz(DepoSayaci s) => _jsonYaz(sayacAnahtari, {
    'v': 1,
    'onk': s.sonrakiOnAnahtar,
    'kyber': s.sonrakiKyber,
    'imzali': s.sonrakiImzali,
    'imzali_etkin': ?s.etkinImzali,
    'son_care_etkin': ?s.etkinSonCare,
  });

  // ------------------------------------------------------- ön anahtarlar

  DepoImzaliKayit? _imzaliOku(String anahtar, int id) {
    final j = _json(anahtar);
    final kayit = baytOku(j?['kayit']);
    final zaman = j?['zaman'];
    if (kayit == null || zaman is! int) return null;
    final emekli = j?['emekli'];
    return DepoImzaliKayit(
      id: id,
      kayit: kayit,
      zaman: DateTime.fromMillisecondsSinceEpoch(zaman, isUtc: true),
      emekli: emekli is int
          ? DateTime.fromMillisecondsSinceEpoch(emekli, isUtc: true)
          : null,
    );
  }

  Map<String, Object?> _imzaliJson(DepoImzaliKayit k) => {
    'kayit': base64.encode(k.kayit),
    'zaman': k.zaman.millisecondsSinceEpoch,
    'emekli': ?k.emekli?.millisecondsSinceEpoch,
  };

  DepoImzaliKayit? imzali(int id) => _imzaliOku(imzaliAnahtari(id), id);

  Future<bool> imzaliYaz(DepoImzaliKayit k) =>
      _jsonYaz(imzaliAnahtari(k.id), _imzaliJson(k));

  DepoImzaliKayit? sonCare(int id) => _imzaliOku(sonCareAnahtari(id), id);

  Future<bool> sonCareYaz(DepoImzaliKayit k) =>
      _jsonYaz(sonCareAnahtari(k.id), _imzaliJson(k));

  /// Depodaki bütün imzalı ön anahtarlar.
  List<DepoImzaliKayit> get imzalilar => _kimlikliler(
    '${onek}imzali.',
  ).map(imzali).whereType<DepoImzaliKayit>().toList();

  /// Depodaki bütün son çare Kyber anahtarları.
  List<DepoImzaliKayit> get sonCareler => _kimlikliler(
    '${onek}kyber_son_care.',
  ).map(sonCare).whereType<DepoImzaliKayit>().toList();

  List<int> _kimlikliler(String onek) => [
    for (final a in anahtarlar(onek)) ?int.tryParse(a.substring(onek.length)),
  ];

  Uint8List? onAnahtar(int id) => baytOku(_bellek[onAnahtarAnahtari(id)]);

  Uint8List? kyber(int id) => baytOku(_bellek[kyberAnahtari(id)]);

  /// Tek kullanımlık Kyber kayıtları ve son çare kayıtları: tür 3 mesajı
  /// çözerken aday listesi (libsignal'in Java API'si mesajdaki Kyber
  /// kimliğini açmaz).
  List<Uint8List> get kyberAdaylari => [
    for (final id in _kimlikliler('${onek}kyber.')) ?kyber(id),
    for (final k in sonCareler) k.kayit,
  ];

  /// Tek kullanımlık Kyber kimlikleri.
  Set<int> get kyberKimlikleri => _kimlikliler('${onek}kyber.').toSet();

  /// Tek kullanımlık EC kimlikleri.
  Set<int> get onAnahtarKimlikleri => _kimlikliler('${onek}onk.').toSet();

  Future<bool> onAnahtarYaz(int id, Uint8List kayit) =>
      hamYaz(onAnahtarAnahtari(id), base64.encode(kayit));

  Future<bool> kyberYaz(int id, Uint8List kayit) =>
      hamYaz(kyberAnahtari(id), base64.encode(kayit));

  /// Son çare Kyber anahtarıyla görülmüş `(imzalıId, tabanAnahtar)`
  /// çiftleri (tekrar saldırısı denetimi).
  Set<String> kyberKullanilanlar(int kyberId) {
    final metin = _bellek[kyberKullanilanAnahtari(kyberId)];
    if (metin == null) return <String>{};
    try {
      final d = jsonDecode(metin);
      return d is List<Object?> ? d.whereType<String>().toSet() : <String>{};
    } on FormatException {
      return <String>{};
    }
  }

  Future<bool> kyberKullanilanYaz(int kyberId, Set<String> ciftler) =>
      _jsonYaz(kyberKullanilanAnahtari(kyberId), ciftler.toList());

  // --------------------------------------------------- karşı cihazlar

  DepoOturumu? oturum(String cihazId) {
    final j = _json(oturumAnahtari(cihazId));
    final kayit = baytOku(j?['kayit']);
    final no = j?['no'];
    final kk = j?['kk'];
    if (kayit == null || no is! int || kk is! int) return null;
    return DepoOturumu(cihazNo: no, kayitKimligi: kk, kayit: kayit);
  }

  Future<bool> oturumYaz(String cihazId, DepoOturumu o) =>
      _jsonYaz(oturumAnahtari(cihazId), {
        'no': o.cihazNo,
        'kk': o.kayitKimligi,
        'kayit': base64.encode(o.kayit),
      });

  DepoKarsiKimlik? karsiKimlik(String cihazId) {
    final j = _json(karsiKimlikAnahtari(cihazId));
    final acik = baytOku(j?['acik']);
    final kullanici = j?['kullanici'];
    if (acik == null || kullanici is! String) return null;
    return DepoKarsiKimlik(acikAnahtar: acik, kullaniciId: kullanici);
  }

  Future<bool> karsiKimlikYaz(String cihazId, DepoKarsiKimlik k) =>
      _jsonYaz(karsiKimlikAnahtari(cihazId), {
        'acik': base64.encode(k.acikAnahtar),
        'kullanici': k.kullaniciId,
      });

  /// Karşı cihazın oturumunu ve güvenilen kimliğini siler (cihaz çıkarıldı
  /// ya da kimliği değişti).
  Future<bool> karsiCihaziSil(String cihazId) async {
    final a = await hamSil(oturumAnahtari(cihazId));
    final b = await hamSil(karsiKimlikAnahtari(cihazId));
    return a && b;
  }

  // ------------------------------------------------------------ zarflar

  /// Daha önce işlenmiş zarf kimlikleri (en eski önce).
  List<String> get gorulenZarflar {
    final metin = _bellek[gorulenAnahtari];
    if (metin == null) return const [];
    try {
      final d = jsonDecode(metin);
      return d is List<Object?> ? d.whereType<String>().toList() : const [];
    } on FormatException {
      return const [];
    }
  }

  /// [zarfId]'yi görülenlere ekler (son [gorulenEnCok] tutulur).
  Future<bool> gorulduYaz(String zarfId) {
    final liste = [...gorulenZarflar.where((z) => z != zarfId), zarfId];
    final kirp = liste.length > gorulenEnCok
        ? liste.sublist(liste.length - gorulenEnCok)
        : liste;
    return _jsonYaz(gorulenAnahtari, kirp);
  }

  // ------------------------------------------------- güvenlik uyarıları

  String? sonAnahtarOlayi(String kullaniciId) =>
      _bellek[anahtarOlayiAnahtari(kullaniciId)];

  Future<bool> sonAnahtarOlayiYaz(String kullaniciId, String olayId) =>
      hamYaz(anahtarOlayiAnahtari(kullaniciId), olayId);

  /// Karşı kullanıcının son bilinen cihaz kümesi; hiç bakılmadıysa `null`.
  Set<String>? karsiCihazlar(String kullaniciId) {
    final metin = _bellek[karsiCihazlarAnahtari(kullaniciId)];
    if (metin == null) return null;
    try {
      final d = jsonDecode(metin);
      return d is List<Object?> ? d.whereType<String>().toSet() : null;
    } on FormatException {
      return null;
    }
  }

  Future<bool> karsiCihazlarYaz(String kullaniciId, Set<String> cihazlar) =>
      _jsonYaz(karsiCihazlarAnahtari(kullaniciId), cihazlar.toList()..sort());
}

/// Base64 metni baytlara çevirir; geçersizse `null`.
Uint8List? baytOku(Object? deger) {
  if (deger is! String) return null;
  try {
    return base64.decode(deger);
  } on FormatException {
    return null;
  }
}

/// Uygulamanın E2E deposu (kalıcı; oturum kapanınca [E2eDeposu.temizle]
/// ile boşaltılır).
final e2eDeposuProvider = Provider<E2eDeposu>(
  (ref) => E2eDeposu(ref.watch(e2eAnahtarDeposuProvider)),
  name: 'e2eDeposuProvider',
);
