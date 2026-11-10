// Tek dosyaya bakan kod kuralları (sabit renk/boşluk/yarıçap, sabit metin,
// harf dönüşümü, log, diske yazma, Riverpod, rastgelelik, API sınırları).
//
// Kurallar [TaranmisKaynak.kod] üzerinde çalışır: yorumlar ve metin
// içerikleri maskelidir, bu yüzden yorumdaki veya metindeki sözcükler
// bulgu üretmez. Metin kuralı [TaranmisKaynak.yorumsuz] üzerinde çalışır.

import 'bulgu.dart';
import 'tarayici.dart';

/// Bir bulgu ekleyen geri çağırma: kural, kaynaktaki konum ve mesaj.
typedef BulguEkle = void Function(KuralTanimi kural, int ofset, String mesaj);

/// [yol]'daki kaynağa tek dosya kurallarını uygular.
void kodKurallariniUygula(String yol, TaranmisKaynak t, BulguEkle ekle) {
  final tema = yol.startsWith('lib/core/tema/');
  if (!tema) {
    _sabitRenk(t, ekle);
    _sabitBosluk(t, ekle);
    _sabitYaricap(t, ekle);
  }
  _sabitMetin(t, ekle);
  if (!yol.startsWith('lib/core/metin/')) {
    _kaliplar(t.kod, _harfDonusumuKaliplari, (ofset, parca) {
      ekle(
        Kurallar.harfDonusumu,
        ofset,
        '`$parca` Türkçede yanlış sonuç verir (i/İ, ı/I); arayüzde harf '
        "dönüştürme yapma, arama ve tekillik için turkceKucukHarf() kullan.",
      );
    });
  }
  _kaliplar(t.kod, _logKaliplari, (ofset, parca) {
    ekle(
      Kurallar.logCiktisi,
      ofset,
      '`$parca`: kişisel veri log\'a girebilir; günlük yalnızca '
      "lib/core/'daki altyapıdan ve kişisel veri olmadan yazılır.",
    );
  });
  _kaliplar(t.kod, _diskKaliplari, (ofset, parca) {
    ekle(
      Kurallar.diskeYazma,
      ofset,
      '`$parca`: diske veya tarayıcı deposuna yazma; içerik yalnızca '
      'bellekte tutulur, kalıcı değerler güvenli depoya gider.',
    );
  });
  _kaliplar(t.kod, _googleFontsKaliplari, (ofset, parca) {
    ekle(
      Kurallar.googleFonts,
      ofset,
      '`$parca`: font uygulamaya gömülüdür, çalışma anında indirilmez.',
    );
  });
  _kaliplar(t.kod, _rastgeleKaliplari, (ofset, parca) {
    ekle(
      Kurallar.guvensizRastgele,
      ofset,
      '`$parca`: rastgele değer yalnızca Random.secure() ile üretilir.',
    );
  });
  _kaliplar(t.kod, _riverpodKaliplari, (ofset, parca) {
    ekle(
      Kurallar.riverpodApi,
      ofset,
      '`$parca`: eski Riverpod API\'si; Notifier / AsyncNotifier / '
      'StreamNotifier veya Provider kullan.',
    );
  });
  _kaliplar(t.kod, _kodUretimiKaliplari, (ofset, parca) {
    ekle(
      Kurallar.kodUretimi,
      ofset,
      '`$parca`: kod üretimi kullanılmaz; provider ve modeller elle '
      "(API modelleri lib/core/api/gen/'deki üreticiyle) yazılır.",
    );
  });
  if (!yol.startsWith('lib/core/api/') &&
      !yol.startsWith('lib/core/realtime/')) {
    _kaliplar(t.kod, _agKaliplari, (ofset, parca) {
      ekle(
        Kurallar.apiTekIstemci,
        ofset,
        '`$parca`: ağ bağlantısı yalnızca ApiClient (lib/core/api/) ve '
        "realtime (lib/core/realtime/) üzerinden kurulur.",
      );
    });
  }
  if (!yol.startsWith('lib/core/realtime/')) {
    for (final m in t.metinler) {
      if (_apiYolu.hasMatch(m.icerik)) {
        ekle(
          Kurallar.elleUc,
          m.baslangic,
          'Elle yazılmış API yolu; uçlar lib/core/api/gen/\'deki üretilmiş '
          'sınıflardan çağrılır.',
        );
      }
    }
  }
  _kaliplar(t.kod, _modelKaliplari, (ofset, parca) {
    ekle(
      Kurallar.elleModel,
      ofset,
      '`$parca`: API modelleri elle yazılmaz; lib/core/api/gen/\'deki '
      'üretilmiş modelleri kullan.',
    );
  });
  if (!yol.startsWith('lib/core/')) {
    _kaliplar(t.kod, _jsonKaliplari, (ofset, parca) {
      ekle(
        Kurallar.elleModel,
        ofset,
        '`$parca`: JSON çözme/kodlama yalnızca lib/core/\'da; özellikler '
        'üretilmiş modelleri kullanır.',
      );
    });
  }
}

void _kaliplar(
  String kod,
  List<RegExp> kaliplar,
  void Function(int ofset, String parca) bulundu,
) {
  for (final kalip in kaliplar) {
    for (final m in kalip.allMatches(kod)) {
      final ofset = m.start + _bastakiBosluk(m.group(0)!);
      bulundu(ofset, m.group(0)!.trim());
    }
  }
}

int _bastakiBosluk(String s) => s.length - s.trimLeft().length;

// --- Renk -----------------------------------------------------------------

final List<RegExp> _renkKaliplari = [
  RegExp(r'(?<![\w$])(?:Colors|CupertinoColors)\s*\.\s*[A-Za-z_]\w*'),
  RegExp(r'(?<![\w$])Color\s*\(\s*\d\w*'),
  RegExp(r'(?<![\w$])Color\s*\.\s*(?:fromARGB|fromRGBO|from)\s*\('),
  RegExp(r'(?<![\w$])(?:HSLColor|HSVColor)\s*\.\s*from\w*'),
];

void _sabitRenk(TaranmisKaynak t, BulguEkle ekle) {
  _kaliplar(t.kod, _renkKaliplari, (ofset, parca) {
    ekle(
      Kurallar.sabitRenk,
      ofset,
      'Sabit renk `$parca`; TayfamColors token\'ını kullan '
      '(context.renkler).',
    );
  });
}

// --- Boşluk ve yarıçap ------------------------------------------------------

final RegExp _sayi = RegExp(r'(?<![\w$.])\d+(?:\.\d+)?(?![\w.])');

final RegExp _yalnizSayi = RegExp(r'^-?\d+(?:\.\d+)?$');

final RegExp _kenarBoslugu = RegExp(
  r'(?<![\w$])EdgeInsets(?:Directional)?\s*\.\s*'
  r'(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(',
);

final RegExp _sizedBox = RegExp(r'(?<![\w$])SizedBox\s*\(');

final RegExp _aralikArgumani = RegExp(
  r'(?<![\w$])(?:spacing|runSpacing|mainAxisSpacing|crossAxisSpacing)'
  r'\s*:\s*(-?\d+(?:\.\d+)?)(?![\w.])',
);

final RegExp _yaricap = RegExp(
  r'(?<![\w$])(?:Radius\s*\.\s*(?:circular|elliptical)|'
  r'BorderRadius(?:Directional)?\s*\.\s*circular)\s*\(',
);

bool _sifirDegil(String sayi) => double.parse(sayi) != 0;

/// [acik] parantezli çağrının argümanlarındaki sıfır olmayan sayılar.
List<String> _argumanSayilari(String kod, int acik) {
  final kapa = kapanisiBul(kod, acik);
  if (kapa == null) {
    return const [];
  }
  return [
    for (final m in _sayi.allMatches(kod.substring(acik + 1, kapa)))
      if (_sifirDegil(m.group(0)!)) m.group(0)!,
  ];
}

void _sabitBosluk(TaranmisKaynak t, BulguEkle ekle) {
  final kod = t.kod;
  for (final m in _kenarBoslugu.allMatches(kod)) {
    final sayilar = _argumanSayilari(kod, m.end - 1);
    if (sayilar.isNotEmpty) {
      ekle(
        Kurallar.sabitBosluk,
        m.start,
        'EdgeInsets içinde sabit sayı (${sayilar.join(', ')}); '
        'TayfamSpacing token\'ını kullan.',
      );
    }
  }
  for (final m in _sizedBox.allMatches(kod)) {
    final kapa = kapanisiBul(kod, m.end - 1);
    if (kapa == null) {
      continue;
    }
    final argumanlar = ustDuzeyArgumanlar(kod, m.end - 1, kapa);
    // Çocuğu olan SizedBox bir boyuttur; çocuksuz olan boşluktur.
    if (argumanlar.any((a) => a.ad == 'child')) {
      continue;
    }
    final sayilar = [
      for (final a in argumanlar)
        if ((a.ad == 'width' || a.ad == 'height') &&
            _yalnizSayi.hasMatch(a.deger) &&
            _sifirDegil(a.deger))
          a.deger,
    ];
    if (sayilar.isNotEmpty) {
      ekle(
        Kurallar.sabitBosluk,
        m.start,
        'Boşluk için SizedBox içinde sabit sayı (${sayilar.join(', ')}); '
        'TayfamSpacing token\'ını kullan.',
      );
    }
  }
  for (final m in _aralikArgumani.allMatches(kod)) {
    if (_sifirDegil(m.group(1)!)) {
      ekle(
        Kurallar.sabitBosluk,
        m.start,
        'Sabit aralık `${m.group(0)}`; TayfamSpacing token\'ını kullan.',
      );
    }
  }
}

void _sabitYaricap(TaranmisKaynak t, BulguEkle ekle) {
  final kod = t.kod;
  for (final m in _yaricap.allMatches(kod)) {
    final sayilar = _argumanSayilari(kod, m.end - 1);
    if (sayilar.isNotEmpty) {
      ekle(
        Kurallar.sabitYaricap,
        m.start,
        'Sabit yarıçap (${sayilar.join(', ')}); TayfamRadii token\'ını '
        'kullan.',
      );
    }
  }
}

// --- Sabit kullanıcı metni ----------------------------------------------------

final RegExp _metinWidgeti = RegExp(
  r"""(?<![\w$])(?:Text|SelectableText)\s*\(\s*r?['"]""",
);

final RegExp _metinArgumani = RegExp(
  r'(?<![\w$])(?:tooltip|semanticLabel|semanticsLabel|label|hintText|'
  r'labelText|helperText|errorText|counterText|prefixText|suffixText|'
  r"""title)\s*:\s*r?['"]""",
);

final RegExp _textSpan = RegExp(r'(?<![\w$])TextSpan\s*\(');

final RegExp _metinBasi = RegExp(r"""^r?['"]""");

final RegExp _harf = RegExp(r'\p{L}', unicode: true);

void _sabitMetin(TaranmisKaynak t, BulguEkle ekle) {
  void denetle(int tirnak, int ofset) {
    final metin = t.tirnaktakiMetin(tirnak);
    if (metin == null || !_harf.hasMatch(metin.duzMetin)) {
      return;
    }
    final gosterim = metin.duzMetin.length <= 30
        ? metin.duzMetin
        : '${metin.duzMetin.substring(0, 30)}…';
    ekle(
      Kurallar.sabitMetin,
      ofset,
      "Sabit kullanıcı metni '$gosterim'; metni lib/l10n/app_tr.arb'ye "
      '@açıklamasıyla ekle ve AppLocalizations\'tan oku.',
    );
  }

  final kaynak = t.yorumsuz;
  for (final m in _metinWidgeti.allMatches(kaynak)) {
    denetle(m.end - 1, m.start);
  }
  for (final m in _metinArgumani.allMatches(kaynak)) {
    denetle(m.end - 1, m.start);
  }
  for (final m in _textSpan.allMatches(kaynak)) {
    final kapa = kapanisiBul(t.kod, m.end - 1);
    if (kapa == null) {
      continue;
    }
    for (final a in ustDuzeyArgumanlar(t.kod, m.end - 1, kapa)) {
      if (a.ad != 'text') {
        continue;
      }
      final bas = _metinBasi.firstMatch(kaynak.substring(a.ofset));
      if (bas != null) {
        denetle(a.ofset + bas.end - 1, m.start);
      }
    }
  }
}

// --- Diğer kalıplar ------------------------------------------------------------

final List<RegExp> _harfDonusumuKaliplari = [
  RegExp(r'\.\s*(?:toUpperCase|toLowerCase)\s*\('),
];

final List<RegExp> _logKaliplari = [
  RegExp(r'(?<![\w$.])(?:print|debugPrint|debugPrintStack)\s*\('),
  RegExp(r'(?<![\w$])(?:stdout|stderr)\s*\.\s*\w+'),
  RegExp(r'(?<![\w$])debugLogDiagnostics\s*:\s*true'),
];

final List<RegExp> _diskKaliplari = [
  RegExp(r'(?<![\w$])(?:SharedPreferences\w*|File|Directory|RandomAccessFile)'
      r'\s*[.(]'),
  RegExp(r'\.\s*(?:writeAsString|writeAsStringSync|writeAsBytes|'
      r'writeAsBytesSync|openWrite)\s*\('),
  RegExp(r'(?<![\w$])(?:localStorage|sessionStorage|indexedDB)(?![\w$])'),
];

final List<RegExp> _googleFontsKaliplari = [
  RegExp(r'(?<![\w$])GoogleFonts\s*\.\s*\w*'),
];

final List<RegExp> _rastgeleKaliplari = [
  RegExp(r'(?<![\w$])Random\s*\('),
];

final List<RegExp> _riverpodKaliplari = [
  RegExp(
    r'(?<![\w$])(?:StateNotifierProvider|StateNotifier|'
    r'ChangeNotifierProvider|StateProvider)(?![\w$])',
  ),
];

final List<RegExp> _kodUretimiKaliplari = [
  RegExp(r'@(?:riverpod|Riverpod|freezed|Freezed|JsonSerializable)(?![\w$])'),
];

final List<RegExp> _agKaliplari = [
  RegExp(r'(?<![\w$])HttpClient\s*\('),
  RegExp(r'(?<![\w$])WebSocket\s*\.\s*connect(?![\w$])'),
];

final RegExp _apiYolu = RegExp(r'(?:^|/)v\d+(?:/|$)');

final List<RegExp> _modelKaliplari = [
  RegExp(r'(?<![\w$])factory\s+[\w$]+\s*\.\s*fromJson(?![\w$])'),
  RegExp(
    r'(?<![\w$.])fromJson\s*\(\s*(?:final\s+)?(?:Map|Object|dynamic)(?![\w$])',
  ),
  RegExp(r'(?<![\w$.])toJson\s*\(\s*\)\s*(?:=>|\{|async)'),
];

final List<RegExp> _jsonKaliplari = [
  RegExp(r'(?<![\w$])(?:jsonDecode|jsonEncode|JsonDecoder|JsonEncoder)'
      r'(?![\w$])'),
  RegExp(r'(?<![\w$])json\s*\.\s*(?:decode|encode)\s*\('),
];
