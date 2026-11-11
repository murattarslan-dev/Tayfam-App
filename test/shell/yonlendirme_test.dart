import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';
import 'package:tayfam/shell/yonlendirme.dart';

import '../yardimcilar.dart';

String? _yonlendir(
  String adres, {
  OturumDurumu oturum = OturumDurumu.acik,
  String? aktifTayfaId,
  bool guncellemeGerekli = false,
  Set<String>? etkinTayfalar,
  bool tayfalarBekleniyor = false,
  TanitimDurumu tanitim = TanitimDurumu.gosterildi,
}) {
  return yonlendir(
    oturum: oturum,
    aktifTayfaId: aktifTayfaId,
    konum: Uri.parse(adres),
    guncellemeGerekli: guncellemeGerekli,
    etkinTayfalar: etkinTayfalar,
    tayfalarBekleniyor: tayfalarBekleniyor,
    tanitim: tanitim,
  );
}

const String _ucuncuTayfaId = '5e6f7a8b-9c0d-4e1f-a2b3-c4d5e6f7a8b9';

void main() {
  group('açılış ve güncelleme', () {
    test('güncelleme gerekiyorsa her adres güncelleme ekranına gidiyor', () {
      for (final oturum in OturumDurumu.values) {
        for (final adres in ['/', '/giris', '/kayit', '/t/$ornekTayfaId']) {
          expect(
            _yonlendir(adres, oturum: oturum, guncellemeGerekli: true),
            '/guncelleme',
            reason: '$oturum $adres',
          );
        }
        expect(
          _yonlendir('/guncelleme', oturum: oturum, guncellemeGerekli: true),
          isNull,
        );
      }
    });

    test('oturum kaydı okunurken açılış ekranı gösteriliyor', () {
      expect(_yonlendir('/', oturum: OturumDurumu.yukleniyor), '/acilis');
      expect(_yonlendir('/profil', oturum: OturumDurumu.yukleniyor), '/acilis');
      expect(_yonlendir('/acilis', oturum: OturumDurumu.yukleniyor), isNull);
    });

    test('yüklenince açılış ve güncelleme adresleri bırakılıyor', () {
      expect(_yonlendir('/acilis', oturum: OturumDurumu.girisYok), '/giris');
      expect(_yonlendir('/acilis'), '/karsilama');
      expect(_yonlendir('/guncelleme'), '/karsilama');
      expect(
        _yonlendir('/acilis', aktifTayfaId: ornekTayfaId),
        '/t/$ornekTayfaId',
      );
    });
  });

  group('oturum korumaları', () {
    test('giriş yoksa giriş ekranına gidiliyor', () {
      expect(_yonlendir('/sohbet', oturum: OturumDurumu.girisYok), '/giris');
      expect(_yonlendir('/giris', oturum: OturumDurumu.girisYok), isNull);
    });

    test('kayıt bekliyorsa kayıt ekranına gidiliyor', () {
      expect(
        _yonlendir('/t/$ornekTayfaId', oturum: OturumDurumu.kayitBekliyor),
        '/kayit',
      );
      expect(_yonlendir('/kayit', oturum: OturumDurumu.kayitBekliyor), isNull);
    });

    test('yeniden onay gerekiyorsa onay ekranına gidiliyor', () {
      expect(_yonlendir('/profil', oturum: OturumDurumu.onayGerekli), '/onay');
      expect(_yonlendir('/onay', oturum: OturumDurumu.onayGerekli), isNull);
    });

    test('oturum açıkken oturum ekranlarından ana adrese dönülüyor', () {
      expect(_yonlendir('/giris'), '/karsilama');
      expect(
        _yonlendir('/kayit', aktifTayfaId: ornekTayfaId),
        '/t/$ornekTayfaId',
      );
    });
  });

  group('ana adres', () {
    test('tayfası yoksa kök karşılamaya gidiyor', () {
      expect(_yonlendir('/'), '/karsilama');
      expect(_yonlendir('/karsilama'), isNull);
    });

    test('aktif tayfa varsa kök ve karşılama tayfaya gidiyor', () {
      expect(_yonlendir('/', aktifTayfaId: ornekTayfaId), '/t/$ornekTayfaId');
      expect(
        _yonlendir('/karsilama', aktifTayfaId: ornekTayfaId),
        '/t/$ornekTayfaId',
      );
    });
  });

  group('adresteki tayfa kimliği', () {
    test('UUID biçimindeki kimlik olduğu gibi kabul ediliyor', () {
      expect(_yonlendir('/t/$ornekTayfaId'), isNull);
      expect(_yonlendir('/t/$ikinciTayfaId/deneme'), isNull);
      // Aktif tayfadan farklı bir tayfa da adresten açılabilir; üyelik ve
      // içerik sunucunun cevabına göre belirlenir.
      expect(
        _yonlendir('/t/$ikinciTayfaId', aktifTayfaId: ornekTayfaId),
        isNull,
      );
    });

    test('UUID biçiminde olmayan kimlik karşılamaya gidiyor', () {
      for (final adres in [
        '/t',
        '/t/',
        '/t/abc',
        '/t/abc/deneme',
        '/t/%2E%2E',
        '/t/$ornekTayfaId-ek',
      ]) {
        expect(_yonlendir(adres), '/karsilama', reason: adres);
      }
    });
  });

  test('diğer adresler değiştirilmiyor', () {
    expect(_yonlendir('/sohbet'), isNull);
    expect(_yonlendir('/bildirimler'), isNull);
    expect(_yonlendir('/profil'), isNull);
    expect(_yonlendir('/tayfa-olustur'), isNull);
    expect(_yonlendir('/bilinmeyen'), isNull);
  });

  group('tayfa listesi (ADR-0014 §1)', () {
    test('liste ilk kez okunurken ana adres açılış ekranı', () {
      for (final adres in ['/', '/karsilama', '/giris']) {
        expect(
          _yonlendir(adres, tayfalarBekleniyor: true),
          '/acilis',
          reason: adres,
        );
      }
      expect(_yonlendir('/acilis', tayfalarBekleniyor: true), isNull);
      // Aktif tayfa biliniyorsa beklenmez.
      expect(
        _yonlendir('/', aktifTayfaId: ornekTayfaId, tayfalarBekleniyor: true),
        '/t/$ornekTayfaId',
      );
      // Liste gelince açılış ekranı ana adrese döner.
      expect(_yonlendir('/acilis'), '/karsilama');
    });

    test('üye olunmayan tayfa adresi karşılamaya dönüyor', () {
      expect(
        _yonlendir(
          '/t/$_ucuncuTayfaId/deneme',
          aktifTayfaId: ornekTayfaId,
          etkinTayfalar: {ornekTayfaId, ikinciTayfaId},
        ),
        '/karsilama',
      );
      // Karşılama da ana adrese çevrilir.
      expect(
        _yonlendir('/karsilama', aktifTayfaId: ornekTayfaId),
        '/t/$ornekTayfaId',
      );
    });

    test('etkin üyelikteki ya da aktif tayfa adresi açılıyor', () {
      final etkin = {ornekTayfaId, ikinciTayfaId};
      expect(
        _yonlendir(
          '/t/$ikinciTayfaId',
          aktifTayfaId: ornekTayfaId,
          etkinTayfalar: etkin,
        ),
        isNull,
      );
      // Aktif tayfa listede olmasa da döngü olmaz.
      expect(
        _yonlendir(
          '/t/$ornekTayfaId',
          aktifTayfaId: ornekTayfaId,
          etkinTayfalar: const {},
        ),
        isNull,
      );
    });

    test('liste bilinmiyorken (yükleniyor, hata) adres denetlenmiyor', () {
      expect(
        _yonlendir('/t/$_ucuncuTayfaId', aktifTayfaId: ornekTayfaId),
        isNull,
      );
    });

    test('adresle eşitleme: yalnızca etkin ve farklı tayfa', () {
      final etkin = {ornekTayfaId, ikinciTayfaId};
      String? esitle(String adres, {String? aktif, Set<String>? liste}) =>
          adresleEsitle(
            konum: Uri.parse(adres),
            aktifTayfaId: aktif,
            etkinTayfalar: liste,
          );

      expect(
        esitle('/t/$ikinciTayfaId/deneme', aktif: ornekTayfaId, liste: etkin),
        ikinciTayfaId,
      );
      expect(
        esitle('/t/$ornekTayfaId', aktif: ornekTayfaId, liste: etkin),
        isNull,
      );
      expect(esitle('/t/$_ucuncuTayfaId', liste: etkin), isNull);
      expect(esitle('/t/$ikinciTayfaId'), isNull);
      expect(esitle('/sohbet', liste: etkin), isNull);
      expect(esitle('/t/abc', liste: etkin), isNull);
    });

    test('adresteki tayfa kimliği', () {
      expect(adrestekiTayfaId(Uri.parse('/t/$ornekTayfaId/x')), ornekTayfaId);
      expect(adrestekiTayfaId(Uri.parse('/t/abc')), isNull);
      expect(adrestekiTayfaId(Uri.parse('/t')), isNull);
      expect(adrestekiTayfaId(Uri.parse('/profil')), isNull);
    });
  });

  group('hoş geldin tanıtımı (ADR-0017)', () {
    const yok = OturumDurumu.girisYok;
    const gosterilmedi = TanitimDurumu.gosterilmedi;

    test('oturum yokken gösterilmediyse tanıtıma gidiliyor', () {
      for (final adres in ['/', '/giris', '/acilis', '/karsilama']) {
        expect(
          _yonlendir(adres, oturum: yok, tanitim: gosterilmedi),
          '/hos-geldin',
          reason: adres,
        );
      }
      expect(
        _yonlendir('/hos-geldin', oturum: yok, tanitim: gosterilmedi),
        isNull,
      );
    });

    test('sıra: sürüm denetimi → tanıtım → giriş', () {
      expect(
        _yonlendir(
          '/hos-geldin',
          oturum: yok,
          tanitim: gosterilmedi,
          guncellemeGerekli: true,
        ),
        '/guncelleme',
      );
      expect(
        _yonlendir('/', oturum: OturumDurumu.yukleniyor, tanitim: gosterilmedi),
        '/acilis',
      );
      expect(
        _yonlendir('/', oturum: yok, tanitim: TanitimDurumu.yukleniyor),
        '/acilis',
      );
      expect(
        _yonlendir('/acilis', oturum: yok, tanitim: TanitimDurumu.yukleniyor),
        isNull,
      );
      expect(_yonlendir('/hos-geldin', oturum: yok), '/giris');
    });

    test('gösterildiyse ya da oturum varsa tanıtım atlanıyor', () {
      expect(_yonlendir('/', oturum: yok), '/giris');
      expect(_yonlendir('/hos-geldin', tanitim: gosterilmedi), '/karsilama');
      expect(_yonlendir('/', tanitim: gosterilmedi), '/karsilama');
      expect(
        _yonlendir(
          '/hos-geldin',
          oturum: OturumDurumu.kayitBekliyor,
          tanitim: gosterilmedi,
        ),
        '/kayit',
      );
    });

    test('gelinen adresin yolu tanıtım adresinde korunuyor', () {
      final adres = _yonlendir('/sohbet', oturum: yok, tanitim: gosterilmedi);
      expect(adres, Adresler.hosGeldinAdresi('/sohbet'));
      final uri = Uri.parse(adres!);
      expect(uri.path, '/hos-geldin');
      expect(uri.queryParameters[Adresler.hedefParametresi], '/sohbet');

      // Davet token'ı (fragment) ve sorgu hiçbir zaman taşınmaz.
      final davet = Uri.parse(
        _yonlendir('/davet#gizli-token', oturum: yok, tanitim: gosterilmedi)!,
      );
      expect(davet.queryParameters[Adresler.hedefParametresi], '/davet');
      expect(davet.toString(), isNot(contains('gizli-token')));
      expect(korunacakHedef(Uri.parse('/r/ORNEK1?kaynak=x')), '/r/ORNEK1');
    });

    test('kök, karşılama ve oturum ekranları hedef olarak korunmuyor', () {
      for (final adres in ['', '/', '/karsilama', '/giris', '/hos-geldin']) {
        expect(korunacakHedef(Uri.parse(adres)), isNull, reason: adres);
      }
    });

    test('hedef parametresi doğrulanıyor', () {
      expect(guvenliHedef('/sohbet'), '/sohbet');
      expect(guvenliHedef('/t/$ornekTayfaId'), '/t/$ornekTayfaId');
      for (final kotu in [
        null,
        '',
        'sohbet',
        '//ornek.test/x',
        'https://ornek.test/x',
        '/sohbet?x=1',
        '/sohbet#x',
      ]) {
        expect(guvenliHedef(kotu), isNull, reason: kotu);
      }
    });
  });
}
