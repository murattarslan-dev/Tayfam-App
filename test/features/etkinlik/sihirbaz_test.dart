import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import '../../core/katalog/sahte_katalog.dart';
import 'sahteler.dart';

const SihirbazAnahtari _olusturma = (tayfaId: ornekTayfaId, duzenlenen: null);

const LatLng _nokta = LatLng(lat: 40.6, lng: 31.28);

ProviderContainer _kapsayici(SahteTayfaTasima tasima) {
  final c = ProviderContainer(overrides: etkinlikOverridelari(tasima: tasima));
  addTearDown(c.dispose);
  return c;
}

/// Sihirbazı son adıma kadar geçerli bir kamp etkinliğiyle doldurur.
EtkinlikSihirbaziNotifier _doldur(
  ProviderContainer c, [
  SihirbazAnahtari anahtar = _olusturma,
]) {
  c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
  final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier)
    ..turSec(testTuru('camp'))
    ..ileri()
    ..baslikAyarla('  Göl kampı ')
    ..aciklamaAyarla('Çadırını getir.')
    ..baslangicAyarla(ornekBaslangic)
    ..ileri()
    ..noktaSec(_nokta, ad: 'Abant Gölü', il: 'Bolu', ilce: 'Merkez')
    ..ileri();
  return n;
}

void main() {
  test('adımlar: hatalı adımda ilerlenmez, girilenler korunur', () {
    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier);
    EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(_olusturma));

    n.ileri();
    expect(t().adim, 0);
    expect(t().hatalar, {TaslakHatasi.tur});

    n.turSec(testTuru('hike'));
    expect(t().hatalar, isEmpty, reason: 'düzeltilen alanın hatası kalkar');
    n.ileri();
    expect(t().adim, 1);

    n.ileri();
    expect(t().adim, 1);
    expect(t().hatalar, {
      TaslakHatasi.baslik,
      TaslakHatasi.baslangicYok,
      TaslakHatasi.bitis,
    });

    n
      ..baslikAyarla('Kaçkar')
      ..baslangicAyarla(sabitSimdi.subtract(const Duration(hours: 1)));
    expect(t().hatalar, {TaslakHatasi.baslangicGecmis});
    n.baslangicAyarla(ornekBaslangic);
    expect(t().bitis, ornekBaslangic.add(varsayilanSure));
    n.ileri();
    expect(t().adim, 2);

    expect(n.geri(), isTrue);
    expect(t().adim, 1);
    expect(t().baslik, 'Kaçkar');
    expect(n.geri(), isTrue);
    expect(n.geri(), isFalse, reason: 'ilk adımda sihirbaz kapanabilir');
    expect(t().tur, 'hike');
  });

  test('yer adımı: yüz yüze nokta, il, ilçe; çevrimiçi https bağlantı', () {
    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier)
      ..turSec(testTuru('general'))
      ..ileri()
      ..baslikAyarla('Buluşma')
      ..baslangicAyarla(ornekBaslangic)
      ..ileri()
      ..ileri();
    EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(_olusturma));
    expect(t().adim, 2);
    expect(t().hatalar, {
      TaslakHatasi.nokta,
      TaslakHatasi.il,
      TaslakHatasi.ilce,
    });

    n.yerAyarla(t().yer.kopya(mod: EventMode.online, baglanti: 'http://x'));
    expect(t().hatalar, {TaslakHatasi.baglanti});
    n.yerAyarla(t().yer.kopya(baglanti: 'https://ornek.tayfam.app/oda'));
    expect(t().hatalar, isEmpty);
  });

  test('önizleme: "Değiştir" adıma götürür, "İleri" önizlemeye döner', () {
    final c = _kapsayici(etkinlikTasimasi());
    final n = _doldur(c);
    EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(_olusturma));
    expect(t().adim, SihirbazAdimi.ayrinti);
    n.ileri();
    expect(t().adim, SihirbazAdimi.onizleme);
    n.ileri();
    expect(t().adim, SihirbazAdimi.onizleme, reason: 'son adım; gönder ayrı');

    n.adimaGit(SihirbazAdimi.bilgi);
    expect(t().adim, SihirbazAdimi.bilgi);
    expect(t().onizlemeyeDon, isTrue);
    n.baslikAyarla('Yeni ad');
    n.ileri();
    expect(t().adim, SihirbazAdimi.onizleme);
    expect(t().onizlemeyeDon, isFalse);
    expect(t().baslik, 'Yeni ad');

    // Önizlemeden gelinen adımda hata varsa geçilmez.
    n
      ..adimaGit(SihirbazAdimi.bilgi)
      ..baslikAyarla('')
      ..ileri();
    expect(t().adim, SihirbazAdimi.bilgi);
    expect(t().hatalar, {TaslakHatasi.baslik});

    // "Geri" önizlemeye dönüşü bırakır.
    n
      ..baslikAyarla('Göl kampı')
      ..geri();
    expect(t().adim, SihirbazAdimi.tur);
    expect(t().onizlemeyeDon, isFalse);
  });

  test('"Değiştir" yalnızca önizlemeden', () {
    final c = _kapsayici(etkinlikTasimasi());
    final n = _doldur(c)..adimaGit(SihirbazAdimi.tur);
    expect(
      c.read(etkinlikSihirbaziProvider(_olusturma)).adim,
      SihirbazAdimi.ayrinti,
    );
    n
      ..ileri()
      ..adimaGit(SihirbazAdimi.onizleme);
    expect(
      c.read(etkinlikSihirbaziProvider(_olusturma)).adim,
      SihirbazAdimi.onizleme,
    );
  });

  test('girdi var mı: kapatma onayı için', () {
    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier);
    expect(n.girdiVar, isFalse);
    n.ileri();
    expect(n.girdiVar, isFalse, reason: 'hata gösterilmesi girdi değildir');
    n.turSec(testTuru('camp'));
    expect(n.girdiVar, isTrue);
  });

  test('harita seçicinin önerisi yalnızca boş alanları doldurur', () {
    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier);
    n
      ..yerAyarla(const YerBilgisi(il: 'Düzce'))
      ..noktaSec(_nokta, ad: 'Abant Gölü', il: 'Bolu', ilce: 'Merkez');
    final yer = c.read(etkinlikSihirbaziProvider(_olusturma)).yer;
    expect(yer.nokta, _nokta);
    expect(yer.noktaAdi, 'Abant Gölü');
    expect(yer.il, 'Düzce');
    expect(yer.ilce, 'Merkez');
  });

  test(
    'oluşturma gövdesi ve tekrar; hata sonrası aynı client_request_id',
    () async {
      var deneme = 0;
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => deneme++ == 0
            ? const ApiProblem(type: ProblemType.unavailable, status: 503)
            : etkinlikJson(),
      });
      final c = _kapsayici(tasima);
      final n = _doldur(c)
        ..kontenjanAyarla('12')
        ..tekrarAyarla(const TekrarSecimi(aralik: 2));
      EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(_olusturma));
      expect(t().adim, 3);

      await n.gonder();
      expect(t().hata, isA<ApiProblem>());
      expect(t().sonuc, isNull);

      await n.gonder();
      expect(t().sonuc, ornekEtkinlikId);

      final istekler = tasima.giden('POST', etkinliklerYolu);
      expect(istekler, hasLength(2));
      expect(istekler[0].govde, istekler[1].govde);
      final govde = istekler[1].govde! as Map<String, Object?>;
      expect(govde, {
        'type': 'camp',
        'mode': 'in_person',
        'title': 'Göl kampı',
        'description': 'Çadırını getir.',
        'starts_at': '2026-11-14T06:00:00.000Z',
        'ends_at': '2026-11-14T08:00:00.000Z',
        'meeting_point_name': 'Abant Gölü',
        'meeting_point': {'lat': 40.6, 'lng': 31.28},
        'city': 'Bolu',
        'district': 'Merkez',
        'capacity': 12,
        'recurrence': {
          'rrule': 'FREQ=WEEKLY;INTERVAL=2',
          'time_zone': 'Europe/Istanbul',
        },
        'client_request_id': sahteEtkinlikIstekKimligi,
      });
    },
  );

  test('gönderirken hatalı adıma dönülür; istek gitmez', () async {
    final tasima = etkinlikTasimasi();
    final c = _kapsayici(tasima);
    final n = _doldur(c)..kontenjanAyarla('abc');
    await n.gonder();
    final t = c.read(etkinlikSihirbaziProvider(_olusturma));
    expect(t.adim, 3);
    expect(t.hatalar, {TaslakHatasi.kontenjan});
    expect(tasima.giden('POST', etkinliklerYolu), isEmpty);
  });

  test('katalog alanları: zorunlu alanlar ve fields gövdesi', () {
    final tanim = testTuru('gaming');
    final oyun = EtkinlikTaslagi(
      istekKimligi: sahteEtkinlikIstekKimligi,
      tur: tanim.key,
      turTanimi: tanim,
      alanlar: const {'game': ' Valorant '},
      baslik: 'Turnuva',
      baslangic: ornekBaslangic,
      bitis: ornekBaslangic.add(const Duration(hours: 2)),
      yer: const YerBilgisi(
        mod: EventMode.online,
        baglanti: 'https://ornek.tayfam.app/oda',
      ),
    );
    // Platform zorunlu (tanımdan); alan başına hata alan çizicide.
    expect(adimHatalari(3, oyun, simdi: sabitSimdi), {TaslakHatasi.alanlar});
    final tamam = oyun.kopya(
      alanlar: const {'game': ' Valorant ', 'platform': 'pc'},
    );
    expect(adimHatalari(3, tamam, simdi: sabitSimdi), isEmpty);
    final govde = olusturmaIstegi(tamam).toJson();
    expect(govde['type'], 'gaming');
    expect(govde['fields'], {'game': 'Valorant', 'platform': 'pc'});
    expect(govde.containsKey('gaming'), isFalse);

    // Alanı olmayan türde `fields` gönderilmez.
    final genel = testTuru('general');
    final sade = tamam.kopya(tur: genel.key, turTanimi: genel);
    expect(olusturmaIstegi(sade).toJson().containsKey('fields'), isFalse);
  });

  test('tür adımı: tanımsız ve alan türü tanınmayan tür seçilemez', () {
    const bos = EtkinlikTaslagi(istekKimligi: sahteEtkinlikIstekKimligi);
    expect(adimHatalari(0, bos, simdi: sabitSimdi), {TaslakHatasi.tur});
    // Tanımı olmayan anahtar (katalog gelmeden) geçmez.
    expect(adimHatalari(0, bos.kopya(tur: 'camp'), simdi: sabitSimdi), {
      TaslakHatasi.tur,
    });
    final gelecek = testTuru('gelecek_tur');
    expect(
      adimHatalari(
        0,
        bos.kopya(tur: gelecek.key, turTanimi: gelecek),
        simdi: sabitSimdi,
      ),
      {TaslakHatasi.tur},
    );

    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier);
    EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(_olusturma));
    n
      ..turSec(gelecek)
      ..turSec(testTuru('eski_tur'));
    expect(t().tur, isNull, reason: 'tanınmayan alan türü ve emekli tür');
  });

  test('tür değişince alan değerleri bırakılır, mod türe uyar', () {
    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier);
    EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(_olusturma));

    n
      ..turSec(testTuru('gaming'))
      ..alanlariAyarla(const {'game': 'Valorant'});
    expect(t().alanlar, {'game': 'Valorant'});
    expect(t().yer.mod, EventMode.inPerson);

    // Yalnızca çevrimiçi yapılabilen tür: mod çevrimiçine çekilir.
    n.turSec(testTuru('quiz_night'));
    expect(t().tur, 'quiz_night');
    expect(t().alanlar, isEmpty);
    expect(t().yer.mod, EventMode.online);
    expect(turModlari(t().turTanimi), [EventMode.online]);

    n.turSec(testTuru('dog_walk'));
    expect(t().yer.mod, EventMode.inPerson);
  });

  test('yürüyüşün ayrıntı adımı katalog alanlarıyla hatasız', () {
    final yuruyus = EtkinlikTaslagi(
      istekKimligi: sahteEtkinlikIstekKimligi,
      tur: 'hike',
      baslangic: ornekBaslangic,
    );
    expect(adimHatalari(3, yuruyus, simdi: sabitSimdi), isEmpty);
  });

  group('düzenleme', () {
    test('tür değişmez, ilk adım 1; yalnızca değişen alanlar gider', () async {
      final eski = ornekEtkinlik(yonetebilir: true, kontenjan: 10);
      final anahtar = (tayfaId: ornekTayfaId, duzenlenen: eski);
      final tasima = etkinlikTasimasi({
        'PATCH $etkinlikYolu': (_) => etkinlikJson(baslik: 'Yeni ad'),
      });
      final c = _kapsayici(tasima);
      c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
      final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier);
      EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(anahtar));

      expect(t().adim, 1);
      expect(t().tur, 'camp');
      expect(t().istekKimligi, sahteEtkinlikIstekKimligi);
      n.turSec(testTuru('hike'));
      expect(t().tur, 'camp');
      expect(n.geri(), isFalse);

      n
        ..baslikAyarla('Yeni ad')
        ..ileri()
        ..ileri()
        ..kontenjanAyarla('');
      await n.gonder();

      expect(t().sonuc, ornekEtkinlikId);
      expect(tasima.giden('PATCH', etkinlikYolu).single.govde, {
        'title': 'Yeni ad',
        'capacity': 0,
      });
    });

    test(
      'katalog alanları tanım gelince okunur; değişince tamamı gider',
      () async {
        final eski = Event.fromJson({
          ...etkinlikJson(tur: 'gaming', mod: 'online', yonetebilir: true),
          'type_version': 2,
          'fields': {'game': 'Valorant', 'platform': 'pc'},
        });
        final anahtar = (tayfaId: ornekTayfaId, duzenlenen: eski);
        final tasima = etkinlikTasimasi({
          'PATCH $etkinlikYolu': (_) =>
              etkinlikJson(tur: 'gaming', mod: 'online'),
        });
        final c = _kapsayici(tasima);
        c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
        final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier);
        EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(anahtar));

        // Tanım gelmeden alanlar çizilmez ve gönderilmez.
        expect(t().turTanimi, isNull);
        expect(t().alanlar, isEmpty);
        // Başka sürümün tanımı etkinliğe uygulanmaz.
        n.tanimGeldi(testTuru('sports'));
        expect(t().turTanimi, isNull);

        n.tanimGeldi(testTuru('gaming'));
        expect(t().alanlar, {'game': 'Valorant', 'platform': 'pc'});
        expect(n.girdiVar, isFalse, reason: 'tanımın gelmesi girdi değildir');

        n.alanlariAyarla(const {'game': 'Valorant', 'platform': 'xbox'});
        expect(n.girdiVar, isTrue);
        await n.gonder();

        expect(t().sonuc, ornekEtkinlikId);
        expect(tasima.giden('PATCH', etkinlikYolu).single.govde, {
          'fields': {'game': 'Valorant', 'platform': 'xbox'},
        });
      },
    );

    test('değişiklik yoksa istek gitmez', () async {
      final eski = ornekEtkinlik(yonetebilir: true);
      final anahtar = (tayfaId: ornekTayfaId, duzenlenen: eski);
      final tasima = etkinlikTasimasi();
      final c = _kapsayici(tasima);
      c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
      final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier)
        ..ileri()
        ..ileri();
      await n.gonder();
      expect(c.read(etkinlikSihirbaziProvider(anahtar)).sonuc, eski.id);
      expect(tasima.giden('PATCH', etkinlikYolu), isEmpty);
    });

    test('geçmişte başlamış etkinliğin zamanı değişmediyse hata yok', () {
      final eski = Event.fromJson(
        etkinlikJson(baslangic: sabitSimdi.subtract(const Duration(hours: 1))),
      );
      final t = duzenlemeTaslagi(eski, sahteEtkinlikIstekKimligi);
      expect(adimHatalari(1, t, simdi: sabitSimdi, eski: eski), isEmpty);
      expect(
        adimHatalari(
          1,
          t.kopya(baslangic: eski.startsAt.add(const Duration(minutes: 1))),
          simdi: sabitSimdi,
          eski: eski,
        ),
        contains(TaslakHatasi.baslangicGecmis),
      );
    });

    test('yer değişince mod ve bütün yer alanları birlikte gider', () {
      final eski = ornekEtkinlik();
      final t = duzenlemeTaslagi(eski, sahteEtkinlikIstekKimligi);
      final istek = duzenlemeIstegi(
        t.kopya(
          yer: t.yer.kopya(
            mod: EventMode.online,
            baglanti: 'https://ornek.tayfam.app/oda',
          ),
        ),
        eski,
      );
      expect(istek?.toJson(), {
        'mode': 'online',
        'online_url': 'https://ornek.tayfam.app/oda',
      });
    });
  });

  group('"Halka açık yerde buluşur" (discoverable; ADR-0027)', () {
    test('düzenlemede işaret yalnızca değişince ve yüz yüzede gider', () {
      final eski = ornekEtkinlik();
      final t = duzenlemeTaslagi(eski, sahteEtkinlikIstekKimligi);
      expect(t.yer.halkaAcik, isFalse);
      final isaretli = t.kopya(yer: t.yer.kopya(halkaAcik: true));
      expect(duzenlemeIstegi(isaretli, eski)?.toJson(), {'discoverable': true});
      expect(duzenlemeIstegi(t, eski), isNull);
      // Çevrim içine geçince işaret anlamsızdır; değişmediyse gönderilmez.
      final cevrimici = isaretli.kopya(
        yer: isaretli.yer.kopya(
          mod: EventMode.online,
          baglanti: 'https://ornek.tayfam.app/oda',
        ),
      );
      expect(
        duzenlemeIstegi(cevrimici, eski)?.toJson().containsKey('discoverable'),
        isFalse,
      );
    });

    test('oluşturmada yalnızca işaretliyse gönderilir', () {
      final t = duzenlemeTaslagi(ornekEtkinlik(), sahteEtkinlikIstekKimligi);
      expect(olusturmaIstegi(t).toJson().containsKey('discoverable'), isFalse);
      final isaretli = t.kopya(yer: t.yer.kopya(halkaAcik: true));
      expect(olusturmaIstegi(isaretli).toJson()['discoverable'], isTrue);
    });
  });

  group('ders/konu alanı (study_tags; Tayfam-Api ADR-0043)', () {
    final tanim = CatalogEventType.fromJson({
      ...testTuru('general').toJson(),
      'key': 'study_group',
      'definition': {
        'fields': [
          dersAlani('subjects', enCok: 5).toJson(),
          {
            'key': 'not',
            'kind': 'text',
            'labels': {'tr': 'Not'},
          },
        ],
      },
    });

    test('alanı tanınan türde etkinlik oluşturma açık (ADR-0025 §9)', () {
      const bos = EtkinlikTaslagi(istekKimligi: sahteEtkinlikIstekKimligi);
      expect(
        adimHatalari(
          0,
          bos.kopya(tur: tanim.key, turTanimi: tanim),
          simdi: sabitSimdi,
        ),
        isEmpty,
      );

      final c = _kapsayici(etkinlikTasimasi());
      c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
      c.read(etkinlikSihirbaziProvider(_olusturma).notifier).turSec(tanim);
      expect(c.read(etkinlikSihirbaziProvider(_olusturma)).tur, 'study_group');
    });

    test('düzenlemede değişmeyen emekli seçim geri gönderilir', () {
      final eski = Event.fromJson({
        ...etkinlikJson(tur: 'study_group'),
        'fields': {
          'subjects': ['yks_matematik_eski', 'yks_fizik'],
        },
      });
      final t = duzenlemeTaslagi(
        eski,
        sahteEtkinlikIstekKimligi,
        tanim: tanim,
      );
      expect(t.alanlar, {
        'subjects': ['yks_matematik_eski', 'yks_fizik'],
      });
      final degisti = t.kopya(
        alanlar: {...t.alanlar, 'not': 'Kitabını getir'},
        alanlarDegisti: true,
      );
      expect(adimHatalari(3, degisti, simdi: sabitSimdi, eski: eski), isEmpty);
      expect(duzenlemeIstegi(degisti, eski)?.toJson(), {
        'fields': {
          'subjects': ['yks_matematik_eski', 'yks_fizik'],
          'not': 'Kitabını getir',
        },
      });
    });
  });
}
