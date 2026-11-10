import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/hesap/application/kayit_notifier.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';

final OnaySurumleri _surumler = OnaySurumleri.olustur(
  aydinlatma: '2026-11-08',
  kosullar: '2026-11-08',
);

final DateTime _bugun = DateTime(2026, 11, 10, 15, 30);

KayitFormSonucu _denetle({
  String ad = 'Deniz Örnek',
  String? googleAdi = 'Deniz Örnek',
  DateTime? dogumTarihi,
  bool aydinlatma = true,
  bool kosullar = true,
  String referans = '',
}) => kayitFormunuDenetle(
  ad: ad,
  googleAdi: googleAdi,
  dogumTarihi: dogumTarihi ?? DateTime(2009, 3, 12),
  aydinlatmaOnayi: aydinlatma,
  kosullarOnayi: kosullar,
  referansKodu: referans,
  surumler: _surumler,
  bugun: _bugun,
);

void main() {
  test('geçerli form; Google adı değişmediyse ad gönderilmiyor', () {
    final sonuc = _denetle();
    expect(sonuc.hatalar, isEmpty);
    final bilgi = sonuc.bilgi!;
    expect(bilgi.ad, isNull);
    expect(bilgi.referansKodu, isNull);
    expect(bilgi.dogumTarihi, DateTime(2009, 3, 12));
    expect(bilgi.surumler, _surumler);
  });

  test('değişen ad baştaki ve sondaki boşluklar atılarak gönderiliyor', () {
    expect(_denetle(ad: '  Deniz  ').bilgi!.ad, 'Deniz');
    expect(_denetle(ad: ' Deniz Örnek ').bilgi!.ad, isNull);
    expect(_denetle(googleAdi: null, ad: 'Deniz').bilgi!.ad, 'Deniz');
  });

  test('ad 1–40 karakter olmalı', () {
    expect(_denetle(ad: '   ').hatalar, {KayitFormHatasi.ad});
    expect(_denetle(ad: 'a' * 41).hatalar, {KayitFormHatasi.ad});
    expect(_denetle(ad: 'ğ' * 40).hatalar, isEmpty);
    expect(_denetle(googleAdi: null, ad: '').hatalar, {KayitFormHatasi.ad});
  });

  test('doğum tarihi seçilmiş ve bugünden ileri olmamalı', () {
    final secilmemis = kayitFormunuDenetle(
      ad: 'Deniz',
      googleAdi: null,
      dogumTarihi: null,
      aydinlatmaOnayi: true,
      kosullarOnayi: true,
      referansKodu: '',
      surumler: _surumler,
      bugun: _bugun,
    );
    expect(secilmemis.hatalar, {KayitFormHatasi.dogumTarihi});
    expect(_denetle(dogumTarihi: DateTime(2026, 11, 11)).hatalar, {
      KayitFormHatasi.dogumTarihi,
    });
    // Bugün seçilebilir; yaş sınırı istemcide denetlenmez.
    expect(_denetle(dogumTarihi: DateTime(2026, 11, 10)).hatalar, isEmpty);
    expect(_denetle(dogumTarihi: DateTime(2020)).hatalar, isEmpty);
  });

  test('iki metin ayrı ayrı onaylanmalı', () {
    expect(_denetle(aydinlatma: false).hatalar, {KayitFormHatasi.aydinlatma});
    expect(_denetle(kosullar: false).hatalar, {KayitFormHatasi.kosullar});
    expect(_denetle(aydinlatma: false, kosullar: false).hatalar, {
      KayitFormHatasi.aydinlatma,
      KayitFormHatasi.kosullar,
    });
  });

  test('referans kodu isteğe bağlı, en fazla 32 karakter', () {
    expect(_denetle(referans: ' KOD1 ').bilgi!.referansKodu, 'KOD1');
    expect(_denetle(referans: 'K' * 32).hatalar, isEmpty);
    expect(_denetle(referans: 'K' * 33).hatalar, {
      KayitFormHatasi.referansKodu,
    });
  });
}
