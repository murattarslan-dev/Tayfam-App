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
    ..turSec(EventType.camp)
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

    n.turSec(EventType.hike);
    expect(t().hatalar, isEmpty, reason: 'düzeltilen alanın hatası kalkar');
    n.ileri();
    expect(t().adim, 1);

    n.ileri();
    expect(t().adim, 1);
    expect(t().hatalar, {TaslakHatasi.baslik, TaslakHatasi.baslangicYok,
        TaslakHatasi.bitis});

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
    expect(t().tur, EventType.hike);
  });

  test('yer adımı: yüz yüze nokta, il, ilçe; çevrimiçi https bağlantı', () {
    final c = _kapsayici(etkinlikTasimasi());
    c.listen(etkinlikSihirbaziProvider(_olusturma), (_, _) {});
    final n = c.read(etkinlikSihirbaziProvider(_olusturma).notifier)
      ..turSec(EventType.general)
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

  test('oluşturma gövdesi ve tekrar; hata sonrası aynı client_request_id', () async {
    var deneme = 0;
    final tasima = etkinlikTasimasi({
      'POST $etkinliklerYolu': (_) => deneme++ == 0
          ? const ApiProblem(type: ProblemType.unavailable, status: 503)
          : etkinlikJson(),
    });
    final c = _kapsayici(tasima);
    final n = _doldur(c)
      ..kontenjanAyarla('12')
      ..ayrintiAyarla(
        const TurAyrintisi(kampYeri: 'Göl kenarı', su: true),
      )
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
      'camp': {'site_name': 'Göl kenarı', 'has_water': true},
      'recurrence': {
        'rrule': 'FREQ=WEEKLY;INTERVAL=2',
        'time_zone': 'Europe/Istanbul',
      },
      'client_request_id': sahteEtkinlikIstekKimligi,
    });
  });

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

  test('oyun ve spor: zorunlu alanlar ve gövde', () {
    final oyun = EtkinlikTaslagi(
      istekKimligi: sahteEtkinlikIstekKimligi,
      tur: EventType.gaming,
      ayrinti: const TurAyrintisi(oyun: ' Valorant '),
    );
    expect(
      adimHatalari(3, oyun, simdi: sabitSimdi),
      {TaslakHatasi.platform},
    );
    expect(
      turAyrintisi(
        EventType.gaming,
        oyun.ayrinti.kopya(platform: GamingDetailsPlatform.pc),
      ).gaming?.toJson(),
      {'game': 'Valorant', 'platform': 'pc'},
    );
    final spor = EtkinlikTaslagi(
      istekKimligi: sahteEtkinlikIstekKimligi,
      tur: EventType.sports,
    );
    expect(adimHatalari(3, spor, simdi: sabitSimdi), {TaslakHatasi.spor});
  });

  test('yürüyüş alanları: ondalık virgül, aralıklar', () {
    final t = EtkinlikTaslagi(
      istekKimligi: sahteEtkinlikIstekKimligi,
      tur: EventType.hike,
      baslangic: ornekBaslangic,
      ayrinti: TurAyrintisi(
        zorluk: 3,
        mesafe: '12,5',
        yukselti: '850',
        tolerans: '45',
        donus: ornekBaslangic.add(const Duration(hours: 6)),
      ),
    );
    expect(adimHatalari(3, t, simdi: sabitSimdi), isEmpty);
    expect(turAyrintisi(EventType.hike, t.ayrinti).hike?.toJson(), {
      'difficulty': 3,
      'distance_km': 12.5,
      'elevation_m': 850,
      'expected_return_at': '2026-11-14T12:00:00.000Z',
      'return_grace_minutes': 45,
    });
    final hatali = EtkinlikTaslagi(
      istekKimligi: sahteEtkinlikIstekKimligi,
      tur: EventType.hike,
      baslangic: ornekBaslangic,
      ayrinti: TurAyrintisi(
        mesafe: '1001',
        yukselti: '-1',
        tolerans: 'x',
        donus: ornekBaslangic,
      ),
    );
    expect(adimHatalari(3, hatali, simdi: sabitSimdi), {
      TaslakHatasi.mesafe,
      TaslakHatasi.yukselti,
      TaslakHatasi.tolerans,
      TaslakHatasi.donus,
    });
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
      expect(t().tur, EventType.camp);
      expect(t().istekKimligi, sahteEtkinlikIstekKimligi);
      n.turSec(EventType.hike);
      expect(t().tur, EventType.camp);
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
}
