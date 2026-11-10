// Dart kaynağını kural denetimi için hazırlayan küçük tarayıcı.
//
// Tam bir ayrıştırıcı değildir; yorumları ve metin sabitlerini (string)
// doğru ayırması yeterlidir. Böylece kurallar yorumdaki veya metindeki
// `Colors.` gibi sözcüklere takılmaz, metin kuralları da yalnızca gerçek
// metin sabitlerine bakar. Konumlar korunur: maskelenen karakterler boşluk
// olur, satır sonları yerinde kalır.

/// Kaynaktaki bir metin sabiti (string literal).
final class MetinSabiti {
  const MetinSabiti({
    required this.baslangic,
    required this.tirnak,
    required this.bitis,
    required this.icerik,
  });

  /// Sabitin ilk karakteri (`r` öneki varsa onun konumu).
  final int baslangic;

  /// Açılış tırnağının konumu.
  final int tirnak;

  /// Kapanış tırnağından sonraki konum.
  final int bitis;

  /// Tırnaklar arasındaki metin; her ara değerin (`$ad`, `${…}`) yerinde
  /// [araDegerIsareti] durur.
  final String icerik;

  /// Ara değerin içerikteki yer tutucusu.
  static const String araDegerIsareti = '\u0000';

  /// Ara değerler çıkarılmış içerik.
  String get duzMetin => icerik.replaceAll(araDegerIsareti, '');
}

/// Kaynaktaki bir yorum.
final class Yorum {
  const Yorum({required this.baslangic, required this.metin});

  /// Yorumun ilk karakterinin konumu.
  final int baslangic;

  /// Yorumun kendisi (`//` veya `/*` dahil).
  final String metin;
}

/// Taranmış bir Dart kaynağı.
final class TaranmisKaynak {
  TaranmisKaynak._({
    required this.kaynak,
    required this.kod,
    required this.yorumsuz,
    required this.metinler,
    required this.yorumlar,
  }) : _satirBaslari = _satirBaslariniBul(kaynak),
       _tirnaktanMetin = {for (final m in metinler) m.tirnak: m};

  /// [kaynak]'ı tarar.
  factory TaranmisKaynak.tara(String kaynak) {
    final tarayici = _Tarayici(kaynak)..tara();
    return TaranmisKaynak._(
      kaynak: kaynak,
      kod: String.fromCharCodes(tarayici.kod),
      yorumsuz: String.fromCharCodes(tarayici.yorumsuz),
      metinler: List.unmodifiable(tarayici.metinler),
      yorumlar: List.unmodifiable(tarayici.yorumlar),
    );
  }

  /// Özgün kaynak.
  final String kaynak;

  /// Yorumları ve metin sabitlerinin içeriği boşlukla maskelenmiş kaynak.
  /// Tırnaklar ve ara değer (`${…}`) içindeki kod yerinde kalır.
  final String kod;

  /// Yalnızca yorumları maskelenmiş kaynak.
  final String yorumsuz;

  /// Kaynaktaki metin sabitleri.
  final List<MetinSabiti> metinler;

  /// Kaynaktaki yorumlar.
  final List<Yorum> yorumlar;

  final List<int> _satirBaslari;
  final Map<int, MetinSabiti> _tirnaktanMetin;

  /// Açılış tırnağı [tirnak] konumunda olan metin sabiti.
  MetinSabiti? tirnaktakiMetin(int tirnak) => _tirnaktanMetin[tirnak];

  /// [ofset]'in 1'den başlayan satır numarası.
  int satir(int ofset) {
    var alt = 0;
    var ust = _satirBaslari.length - 1;
    while (alt < ust) {
      final orta = (alt + ust + 1) ~/ 2;
      if (_satirBaslari[orta] <= ofset) {
        alt = orta;
      } else {
        ust = orta - 1;
      }
    }
    return alt + 1;
  }

  /// [ofset]'in 1'den başlayan sütun numarası.
  int sutun(int ofset) => ofset - _satirBaslari[satir(ofset) - 1] + 1;

  /// [satirNo]'lu satırın metni (satır sonu olmadan).
  String satirMetni(int satirNo) {
    final bas = _satirBaslari[satirNo - 1];
    final son = satirNo < _satirBaslari.length
        ? _satirBaslari[satirNo] - 1
        : kaynak.length;
    return kaynak.substring(bas, son).replaceAll('\r', '');
  }

  /// Toplam satır sayısı.
  int get satirSayisi => _satirBaslari.length;

  static List<int> _satirBaslariniBul(String kaynak) {
    final baslar = <int>[0];
    for (var i = 0; i < kaynak.length; i++) {
      if (kaynak.codeUnitAt(i) == _satirSonu) {
        baslar.add(i + 1);
      }
    }
    return baslar;
  }
}

/// [kod] içinde [acik] konumundaki açılış parantezinin (`(`, `[`, `{`)
/// kapanışı; bulunamazsa `null`. [kod], [TaranmisKaynak.kod] olmalıdır
/// (metin ve yorum içindeki parantezler maskelenmiş).
int? kapanisiBul(String kod, int acik) {
  var derinlik = 0;
  for (var i = acik; i < kod.length; i++) {
    final c = kod.codeUnitAt(i);
    if (c == _acParantez || c == _acKoseli || c == _acSuslu) {
      derinlik++;
    } else if (c == _kapaParantez || c == _kapaKoseli || c == _kapaSuslu) {
      derinlik--;
      if (derinlik == 0) {
        return i;
      }
    }
  }
  return null;
}

/// Bir çağrının üst düzey argümanı.
final class Arguman {
  const Arguman({required this.ofset, required this.ad, required this.deger});

  /// Değerin kaynaktaki konumu.
  final int ofset;

  /// Adlı argümanın adı; konumsal argümanda `null`.
  final String? ad;

  /// Argümanın değeri (baştaki ve sondaki boşluk atılmış).
  final String deger;
}

final RegExp _adliArguman = RegExp(r'^(\s*)([A-Za-z_$][\w$]*)(\s*:\s*)');

/// [kod] içinde [acik]–[kapa] parantezleri arasındaki üst düzey argümanlar.
List<Arguman> ustDuzeyArgumanlar(String kod, int acik, int kapa) {
  final sonuc = <Arguman>[];
  var derinlik = 0;
  var bas = acik + 1;
  for (var i = acik + 1; i <= kapa; i++) {
    final c = kod.codeUnitAt(i);
    if (c == _acParantez || c == _acKoseli || c == _acSuslu) {
      derinlik++;
    } else if (i < kapa &&
        (c == _kapaParantez || c == _kapaKoseli || c == _kapaSuslu)) {
      derinlik--;
    } else if ((c == _virgul && derinlik == 0) || i == kapa) {
      final parca = kod.substring(bas, i);
      if (parca.trim().isNotEmpty) {
        final adli = _adliArguman.firstMatch(parca);
        if (adli != null) {
          final degerBas = adli.end;
          final deger = parca.substring(degerBas);
          final bosluk = deger.length - deger.trimLeft().length;
          sonuc.add(
            Arguman(
              ofset: bas + degerBas + bosluk,
              ad: adli.group(2),
              deger: deger.trim(),
            ),
          );
        } else {
          final bosluk = parca.length - parca.trimLeft().length;
          sonuc.add(
            Arguman(ofset: bas + bosluk, ad: null, deger: parca.trim()),
          );
        }
      }
      bas = i + 1;
    }
  }
  return sonuc;
}

const int _satirSonu = 0x0A;
const int _satirBasi = 0x0D;
const int _bosluk = 0x20;
const int _egik = 0x2F;
const int _yildiz = 0x2A;
const int _tekTirnak = 0x27;
const int _ciftTirnak = 0x22;
const int _tersEgik = 0x5C;
const int _dolar = 0x24;
const int _r = 0x72;
const int _acSuslu = 0x7B;
const int _kapaSuslu = 0x7D;
const int _acParantez = 0x28;
const int _kapaParantez = 0x29;
const int _acKoseli = 0x5B;
const int _kapaKoseli = 0x5D;
const int _virgul = 0x2C;

bool _harf(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;

bool _rakam(int c) => c >= 0x30 && c <= 0x39;

bool _tanimlayiciKarakteri(int c) => _harf(c) || _rakam(c) || c == _dolar;

final class _Tarayici {
  _Tarayici(this.s)
    : kod = List<int>.of(s.codeUnits),
      yorumsuz = List<int>.of(s.codeUnits);

  final String s;
  final List<int> kod;
  final List<int> yorumsuz;
  final List<MetinSabiti> metinler = [];
  final List<Yorum> yorumlar = [];
  int i = 0;

  void tara() => _kodTara(araDeger: false);

  int _kar(int k) => k >= 0 && k < s.length ? s.codeUnitAt(k) : -1;

  void _bosalt(List<int> hedef, int bas, int son) {
    for (var k = bas; k < son && k < hedef.length; k++) {
      final c = hedef[k];
      if (c != _satirSonu && c != _satirBasi) {
        hedef[k] = _bosluk;
      }
    }
  }

  bool _tirnakMi(int c) => c == _tekTirnak || c == _ciftTirnak;

  /// Kodu tarar. [araDeger] ise bir `${…}` içindedir ve eşi olmayan ilk
  /// `}`'de (konumu [i]'de bırakarak) döner.
  void _kodTara({required bool araDeger}) {
    var derinlik = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      final sonraki = _kar(i + 1);
      if (c == _egik && sonraki == _egik) {
        _satirYorumu();
      } else if (c == _egik && sonraki == _yildiz) {
        _blokYorumu();
      } else if (_tirnakMi(c)) {
        _metin(ham: false);
      } else if (c == _r &&
          _tirnakMi(sonraki) &&
          !_tanimlayiciKarakteri(_kar(i - 1))) {
        _metin(ham: true);
      } else if (c == _acSuslu) {
        derinlik++;
        i++;
      } else if (c == _kapaSuslu) {
        if (araDeger && derinlik == 0) {
          return;
        }
        derinlik--;
        i++;
      } else {
        i++;
      }
    }
  }

  void _satirYorumu() {
    final bas = i;
    var son = s.indexOf('\n', i);
    if (son < 0) {
      son = s.length;
    }
    yorumlar.add(Yorum(baslangic: bas, metin: s.substring(bas, son)));
    _bosalt(kod, bas, son);
    _bosalt(yorumsuz, bas, son);
    i = son;
  }

  void _blokYorumu() {
    final bas = i;
    var derinlik = 0;
    while (i < s.length) {
      if (_kar(i) == _egik && _kar(i + 1) == _yildiz) {
        derinlik++;
        i += 2;
      } else if (_kar(i) == _yildiz && _kar(i + 1) == _egik) {
        derinlik--;
        i += 2;
        if (derinlik == 0) {
          break;
        }
      } else {
        i++;
      }
    }
    yorumlar.add(Yorum(baslangic: bas, metin: s.substring(bas, i)));
    _bosalt(kod, bas, i);
    _bosalt(yorumsuz, bas, i);
  }

  void _metin({required bool ham}) {
    final bas = i;
    if (ham) {
      i++;
    }
    final tirnak = i;
    final q = s.codeUnitAt(i);
    final uclu = _kar(i + 1) == q && _kar(i + 2) == q;
    i += uclu ? 3 : 1;
    final icerik = StringBuffer();
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      final kapanis = uclu
          ? c == q && _kar(i + 1) == q && _kar(i + 2) == q
          : c == q;
      if (kapanis) {
        i += uclu ? 3 : 1;
        break;
      }
      if (!uclu && c == _satirSonu) {
        // Kapanmamış metin; satır sonunda bırakılır.
        break;
      }
      if (!ham && c == _tersEgik) {
        final son = i + 2 > s.length ? s.length : i + 2;
        icerik.write(s.substring(i, son));
        _bosalt(kod, i, son);
        i = son;
      } else if (!ham && c == _dolar && _kar(i + 1) == _acSuslu) {
        icerik.write(MetinSabiti.araDegerIsareti);
        _bosalt(kod, i, i + 2);
        i += 2;
        _kodTara(araDeger: true);
        if (i < s.length) {
          _bosalt(kod, i, i + 1);
          i++;
        }
      } else if (!ham && c == _dolar && _harf(_kar(i + 1))) {
        var son = i + 1;
        while (son < s.length &&
            (_harf(s.codeUnitAt(son)) || _rakam(s.codeUnitAt(son)))) {
          son++;
        }
        icerik.write(MetinSabiti.araDegerIsareti);
        _bosalt(kod, i, son);
        i = son;
      } else {
        icerik.writeCharCode(c);
        _bosalt(kod, i, i + 1);
        i++;
      }
    }
    metinler.add(
      MetinSabiti(
        baslangic: bas,
        tirnak: tirnak,
        bitis: i,
        icerik: icerik.toString(),
      ),
    );
  }
}
