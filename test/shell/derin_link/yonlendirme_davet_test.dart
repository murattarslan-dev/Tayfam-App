import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';
import 'package:tayfam/shell/yonlendirme.dart';

import '../../yardimcilar.dart';

String? _yonlendir(
  String adres, {
  OturumDurumu oturum = OturumDurumu.acik,
  TanitimDurumu tanitim = TanitimDurumu.gosterildi,
  bool davetBekliyor = true,
  bool guncellemeGerekli = false,
}) => yonlendir(
  oturum: oturum,
  aktifTayfaId: ornekTayfaId,
  konum: Uri.parse(adres),
  tanitim: tanitim,
  davetBekliyor: davetBekliyor,
  guncellemeGerekli: guncellemeGerekli,
  etkinTayfalar: {ornekTayfaId},
);

void main() {
  group('bekleyen davet (ADR-0018 §6)', () {
    test('oturum açıkken davet ekranına gidilir', () {
      expect(_yonlendir('/'), '/davet');
      expect(_yonlendir('/t/$ornekTayfaId'), '/davet');
      expect(_yonlendir('/giris'), '/davet');
      expect(_yonlendir('/davet'), isNull);
    });

    test('davet yokken /davet adresi olduğu gibi kalır', () {
      expect(_yonlendir('/davet', davetBekliyor: false), isNull);
      expect(_yonlendir('/', davetBekliyor: false), '/t/$ornekTayfaId');
    });

    test('önce giriş, kayıt ve yeniden onay gelir', () {
      expect(_yonlendir('/', oturum: OturumDurumu.girisYok), '/giris');
      expect(_yonlendir('/', oturum: OturumDurumu.kayitBekliyor), '/kayit');
      expect(_yonlendir('/', oturum: OturumDurumu.onayGerekli), '/onay');
      expect(_yonlendir('/davet', oturum: OturumDurumu.yukleniyor), '/acilis');
    });

    test('tanıtım gösterilmediyse önce tanıtım, hedefi davet ekranı', () {
      expect(
        _yonlendir(
          '/',
          oturum: OturumDurumu.girisYok,
          tanitim: TanitimDurumu.gosterilmedi,
        ),
        Adresler.hosGeldinAdresi('/davet'),
      );
    });

    test('güncelleme gerekiyorsa davetten önce güncelleme ekranı', () {
      expect(_yonlendir('/', guncellemeGerekli: true), '/guncelleme');
    });
  });
}
