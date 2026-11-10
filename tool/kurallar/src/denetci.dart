// Denetimin giriş noktası: dosyaları tarar, kuralları uygular, satır içi
// istisnaları işler.
//
// İstisna biçimi (bulgunun satırında ya da hemen üstündeki satırda):
//
//   // kural-istisnası: <kural>[, <kural>…] — <gerekçe>
//
// Ayraç uzun tire (—), kısa tire (–) veya boşluklarla çevrili kısa çizgi
// (-) olabilir. pubspec.yaml'da yorum `#` ile başlar. Gerekçesiz veya
// bilinmeyen kurallı istisna kendisi bir hatadır; hiçbir bulguyu
// kapatmayan istisna uyarıdır.

import 'arb_pubspec_kurallari.dart';
import 'bulgu.dart';
import 'import_kurallari.dart';
import 'kod_kurallari.dart';
import 'tarayici.dart';

/// Denetlenecek dosyalar.
final class DenetimGirdisi {
  DenetimGirdisi({
    required this.dartDosyalari,
    this.pubspec,
    this.arbDosyalari = const {},
    this.paketAdi = 'tayfam',
  });

  /// lib/ altındaki Dart dosyaları (yol → içerik), üretilmişler dahil.
  final Map<String, String> dartDosyalari;

  /// pubspec.yaml içeriği.
  final String? pubspec;

  /// lib/l10n/ altındaki ARB dosyaları (yol → içerik).
  final Map<String, String> arbDosyalari;

  /// pubspec.yaml'daki paket adı.
  final String paketAdi;
}

/// Kuralların uygulanmadığı üretilmiş kod.
bool uretilmisMi(String yol) =>
    yol.startsWith('lib/core/api/gen/') ||
    RegExp(r'^lib/l10n/app_localizations[\w]*\.dart$').hasMatch(yol);

final RegExp _istisnaIsareti = RegExp(
  r'^(?://|#)\s*kural-istisnas[ıi]\s*:(.*)$',
);

final RegExp _istisnaAyraci = RegExp(r'\s+[—–-]\s+|\s*[—–]\s*');

final RegExp _dosyaParcasi = RegExp(r'^[a-z][a-z0-9_]*$');

final class _Istisna {
  _Istisna({
    required this.satir,
    required this.sutun,
    required this.hedefSatir,
    required this.kurallar,
  });

  final int satir;
  final int sutun;
  final int hedefSatir;
  final Set<String> kurallar;
  bool kullanildi = false;
}

/// [girdi]'yi denetler; bulgular yol, satır ve sütuna göre sıralıdır.
List<Bulgu> denetle(DenetimGirdisi girdi) {
  final bulgular = <Bulgu>[];
  final istisnalar = <String, List<_Istisna>>{};
  final kenarlar = <OzellikKenari>[];
  final kullanilanAdlar = <String>{};
  final taranmis = <String, TaranmisKaynak>{};
  final yollar = girdi.dartDosyalari.keys.toList()..sort();

  for (final yol in yollar) {
    final t = TaranmisKaynak.tara(girdi.dartDosyalari[yol]!);
    taranmis[yol] = t;
    for (final m in _erisim.allMatches(t.kod)) {
      kullanilanAdlar.add(m.group(1)!);
    }
    if (uretilmisMi(yol)) {
      continue;
    }

    void ekle(KuralTanimi kural, int ofset, String mesaj) {
      bulgular.add(
        Bulgu(
          kural: kural,
          yol: yol,
          satir: t.satir(ofset),
          sutun: t.sutun(ofset),
          mesaj: mesaj,
        ),
      );
    }

    istisnalar[yol] = _dartIstisnalari(yol, t, bulgular);
    _dosyaAdi(yol, bulgular);
    kodKurallariniUygula(yol, t, ekle);
    yonergeKurallariniUygula(
      yol: yol,
      yonergeler: yonergeleriBul(t),
      paketAdi: girdi.paketAdi,
      ekle: ekle,
      kenarlar: kenarlar,
    );
  }

  donguleriBul(kenarlar, (yol, ofset, mesaj) {
    final t = taranmis[yol]!;
    bulgular.add(
      Bulgu(
        kural: Kurallar.importDongusu,
        yol: yol,
        satir: t.satir(ofset),
        sutun: t.sutun(ofset),
        mesaj: mesaj,
      ),
    );
  });
  _disaAcikDosyalar(yollar, bulgular);

  final pubspec = girdi.pubspec;
  if (pubspec != null) {
    istisnalar['pubspec.yaml'] = _satirIstisnalari(
      'pubspec.yaml',
      pubspec.split('\n'),
      bulgular,
    );
    bulgular.addAll(pubspecKurallari(pubspec));
  }
  bulgular.addAll(
    arbKurallari(
      arbDosyalari: girdi.arbDosyalari,
      kullanilanAdlar: kullanilanAdlar,
    ),
  );

  final sonuc = <Bulgu>[];
  for (final b in bulgular) {
    if (b.kural != Kurallar.istisnaBicimi && _istisnaKapatir(istisnalar, b)) {
      continue;
    }
    sonuc.add(b);
  }
  for (final MapEntry(key: yol, value: liste) in istisnalar.entries) {
    for (final i in liste) {
      if (!i.kullanildi) {
        sonuc.add(
          Bulgu(
            kural: Kurallar.istisnaKullanilmayan,
            yol: yol,
            satir: i.satir,
            sutun: i.sutun,
            mesaj:
                'İstisna (${i.kurallar.join(', ')}) hiçbir bulguyu '
                'kapatmıyor; kaldır.',
          ),
        );
      }
    }
  }
  sonuc.sort((a, b) {
    final yol = a.yol.compareTo(b.yol);
    if (yol != 0) {
      return yol;
    }
    final satir = a.satir.compareTo(b.satir);
    return satir != 0 ? satir : a.sutun.compareTo(b.sutun);
  });
  return sonuc;
}

final RegExp _erisim = RegExp(r'\.\s*([a-z][a-z0-9_]*)');

bool _istisnaKapatir(Map<String, List<_Istisna>> istisnalar, Bulgu b) {
  var kapatti = false;
  for (final i in istisnalar[b.yol] ?? const <_Istisna>[]) {
    if (i.hedefSatir == b.satir && i.kurallar.contains(b.kural.ad)) {
      i.kullanildi = true;
      kapatti = true;
    }
  }
  return kapatti;
}

List<_Istisna> _dartIstisnalari(
  String yol,
  TaranmisKaynak t,
  List<Bulgu> bulgular,
) {
  final satirlar = [for (var s = 1; s <= t.satirSayisi; s++) t.satirMetni(s)];
  final sonuc = <_Istisna>[];
  for (final y in t.yorumlar) {
    if (!y.metin.startsWith('//')) {
      continue;
    }
    final istisna = _istisnaOku(
      yol: yol,
      yorum: y.metin.trimRight(),
      satir: t.satir(y.baslangic),
      sutun: t.sutun(y.baslangic),
      satirlar: satirlar,
      bulgular: bulgular,
    );
    if (istisna != null) {
      sonuc.add(istisna);
    }
  }
  return sonuc;
}

List<_Istisna> _satirIstisnalari(
  String yol,
  List<String> satirlar,
  List<Bulgu> bulgular,
) {
  final temiz = [for (final s in satirlar) s.replaceAll('\r', '')];
  final sonuc = <_Istisna>[];
  for (var s = 0; s < temiz.length; s++) {
    final bas = temiz[s].indexOf('#');
    if (bas < 0) {
      continue;
    }
    final istisna = _istisnaOku(
      yol: yol,
      yorum: temiz[s].substring(bas).trimRight(),
      satir: s + 1,
      sutun: bas + 1,
      satirlar: temiz,
      bulgular: bulgular,
    );
    if (istisna != null) {
      sonuc.add(istisna);
    }
  }
  return sonuc;
}

/// Bir yorumu istisna olarak okur; istisna değilse `null`. Biçimi bozuksa
/// [bulgular]'a `istisna-bicimi` ekler ve `null` döner.
_Istisna? _istisnaOku({
  required String yol,
  required String yorum,
  required int satir,
  required int sutun,
  required List<String> satirlar,
  required List<Bulgu> bulgular,
}) {
  final m = _istisnaIsareti.firstMatch(yorum);
  if (m == null) {
    return null;
  }
  void hata(String mesaj) {
    bulgular.add(
      Bulgu(
        kural: Kurallar.istisnaBicimi,
        yol: yol,
        satir: satir,
        sutun: sutun,
        mesaj: mesaj,
      ),
    );
  }

  final govde = m.group(1)!.trim();
  final ayrac = _istisnaAyraci.firstMatch(govde);
  final gerekce = ayrac == null ? '' : govde.substring(ayrac.end).trim();
  if (ayrac == null || gerekce.isEmpty) {
    hata(
      'İstisnanın gerekçesi yok; biçim: '
      '"// kural-istisnası: <kural> — <gerekçe>".',
    );
    return null;
  }
  final adlar = {
    for (final ad in govde.substring(0, ayrac.start).split(','))
      if (ad.trim().isNotEmpty) ad.trim(),
  };
  final bilinmeyen = [
    for (final ad in adlar)
      if (Kurallar.bul(ad) == null || ad == Kurallar.istisnaBicimi.ad) ad,
  ];
  if (adlar.isEmpty || bilinmeyen.isNotEmpty) {
    hata(
      'İstisnada bilinmeyen kural: ${bilinmeyen.join(', ')}. Kurallar: '
      '`dart run tool/kurallar/bin/kurallar.dart --liste`.',
    );
    return null;
  }
  return _Istisna(
    satir: satir,
    sutun: sutun,
    hedefSatir: _hedefSatir(satirlar, satir, sutun),
    kurallar: adlar,
  );
}

/// Yorum kendi satırında yalnızsa bir sonraki kod satırına, değilse kendi
/// satırına uygulanır.
int _hedefSatir(List<String> satirlar, int satir, int sutun) {
  final once = satirlar[satir - 1].substring(0, sutun - 1);
  if (once.trim().isNotEmpty) {
    return satir;
  }
  for (var s = satir; s < satirlar.length; s++) {
    final metin = satirlar[s].trim();
    if (metin.isEmpty || metin.startsWith('//') || metin.startsWith('#')) {
      continue;
    }
    return s + 1;
  }
  return satir;
}

void _dosyaAdi(String yol, List<Bulgu> bulgular) {
  final parcalar = yol.split('/');
  for (var i = 1; i < parcalar.length; i++) {
    final son = i == parcalar.length - 1;
    final ad = son && parcalar[i].endsWith('.dart')
        ? parcalar[i].substring(0, parcalar[i].length - '.dart'.length)
        : parcalar[i];
    if (!_dosyaParcasi.hasMatch(ad)) {
      bulgular.add(
        Bulgu(
          kural: Kurallar.dosyaAdi,
          yol: yol,
          satir: 1,
          mesaj: "'${parcalar[i]}' ASCII snake_case değil.",
        ),
      );
      return;
    }
  }
}

void _disaAcikDosyalar(List<String> yollar, List<Bulgu> bulgular) {
  final ilkDosya = <String, String>{};
  for (final yol in yollar) {
    final ozellik = ozellikAdi(yol);
    if (ozellik != null && !uretilmisMi(yol)) {
      ilkDosya.putIfAbsent(ozellik, () => yol);
    }
  }
  for (final MapEntry(key: ozellik, value: yol) in ilkDosya.entries) {
    final acik = disaAcikDosya(ozellik);
    if (!yollar.contains(acik)) {
      bulgular.add(
        Bulgu(
          kural: Kurallar.ozellikDisaAcikDosya,
          yol: yol,
          satir: 1,
          mesaj: "'$ozellik' özelliğinin dışa açık dosyası '$acik' yok.",
        ),
      );
    }
  }
}
