import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/anlik_davet.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../arkadas/sahteler.dart' as ark;
import '../tayfa/sahteler.dart';
import '../../core/katalog/sahte_katalog.dart';
import 'sahteler.dart';

/// Anlık tayfanın örnek kimliği.
const String anlikTayfaId = '4e3d2c1b-0a9f-4e8d-9c7b-6a5f4e3d2c1b';

const String anlikYolu = '/v1/instant-events';

const LatLng _nokta = LatLng(lat: 40.6, lng: 31.28);

const AnlikAnahtari _bos = (gun: null, davetli: null);

/// `InstantEvent` JSON'u.
Map<String, Object?> anlikJson() => {
  'tayfa': tayfaJson(
    id: anlikTayfaId,
    ad: 'Göl kampı',
    uyeSayisi: 1,
    tur: 'instant',
    anlikEtkinlikId: ornekEtkinlikId,
  ),
  'event': etkinlikJson(),
};

ProviderContainer _kapsayici(SahteTayfaTasima tasima) {
  final c = ProviderContainer(
    overrides: [
      ...etkinlikOverridelari(tasima: tasima),
      arkadasDeposuProvider.overrideWithValue(ArkadasDeposu(tasima)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Anlık sihirbazı önizlemeye kadar geçerli bir kamp etkinliğiyle doldurur.
EtkinlikSihirbaziNotifier _doldur(
  ProviderContainer c, [
  AnlikAnahtari anahtar = _bos,
]) {
  c.listen(anlikSihirbazProvider(anahtar), (_, _) {});
  return c.read(anlikSihirbazProvider(anahtar).notifier)
    ..turSec(testTuru('camp'))
    ..ileri()
    ..baslikAyarla('  Göl kampı ')
    ..baslangicAyarla(ornekBaslangic)
    ..ileri()
    ..noktaSec(_nokta, ad: 'Abant Gölü', il: 'Bolu', ilce: 'Merkez')
    ..ileri()
    ..ileri();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('açılış değerleri (adres girdisi)', () {
    // Yerel saatle 11 Kasım 12:00; sınır 30 gün sonrası (11 Aralık).
    final simdi = DateTime(2026, 11, 11, 12);

    test('geçerli gün ve davetli kabul edilir', () {
      final a = anlikBaslangicCoz('2026-11-20', ark.kisiId1, simdi: simdi);
      expect(a.gun, DateTime(2026, 11, 20));
      expect(a.davetli, ark.kisiId1);
      expect(
        anlikBaslangicCoz('2026-11-11', null, simdi: simdi).gun,
        DateTime(2026, 11, 11),
        reason: 'bugün',
      );
      expect(
        anlikBaslangicCoz('2026-12-11', null, simdi: simdi).gun,
        DateTime(2026, 12, 11),
        reason: '30. gün',
      );
    });

    final gecersizGunler = {
      'geçmiş': '2026-11-10',
      '30 günden ileri': '2026-12-12',
      'takvimde yok': '2026-02-30',
      'biçim': '20-11-2026',
      'ek metin': '2026-11-20T10:00',
      'boş': '',
    };
    for (final MapEntry(key: ad, value: gun) in gecersizGunler.entries) {
      test('geçersiz gün ($ad) yok sayılır', () {
        expect(anlikBaslangicCoz(gun, null, simdi: simdi).gun, isNull);
      });
    }

    test('davetli UUID değilse yok sayılır', () {
      for (final kotu in ['kimlik', '../t', 'https://kotu.example/x', '']) {
        expect(anlikBaslangicCoz(null, kotu, simdi: simdi).davetli, isNull);
      }
    });

    test(
      'önerilen başlangıç: o gün 19:00; yakınsa bir sonraki saatten sonra',
      () {
        expect(
          anlikOnerilenBaslangic(DateTime(2026, 11, 20), simdi: simdi),
          DateTime(2026, 11, 20, 19).toUtc(),
        );
        final aksam = DateTime(2026, 11, 11, 18, 20);
        expect(
          anlikOnerilenBaslangic(DateTime(2026, 11, 11), simdi: aksam),
          DateTime(2026, 11, 11, 20).toUtc(),
        );
      },
    );

    test('adres: gün ve davetli sorguya yazılır, geri okununca aynı', () {
      final adres = Adresler.anlikEtkinlik(
        gun: DateTime(2026, 11, 20),
        davetli: ark.kisiId1,
      );
      final uri = Uri.parse(adres);
      expect(uri.path, Adresler.anlikEtkinlikYolu);
      final a = anlikBaslangicCoz(
        uri.queryParameters[Adresler.anlikGunParametresi],
        uri.queryParameters[Adresler.anlikDavetliParametresi],
        simdi: simdi,
      );
      expect(a, (gun: DateTime(2026, 11, 20), davetli: ark.kisiId1));
      expect(Adresler.anlikEtkinlik(), Adresler.anlikEtkinlikYolu);
    });
  });

  group('anlık sihirbaz', () {
    test(
      '6 adım: ayrıntıdan sonra davet, sonra önizleme; tekrar ve kapak yok',
      () {
        final c = _kapsayici(etkinlikTasimasi());
        final n = _doldur(c);
        final t = c.read(anlikSihirbazProvider(_bos));
        expect(n.anlik, isTrue);
        expect(n.adimSayisi, anlikAdimSayisi);
        expect(t.adim, SihirbazAdimi.davet);
        n
          ..tekrarAyarla(const TekrarSecimi(siklik: TekrarSikligi.haftalik))
          ..kapakAyarla('11111111-1111-4111-8111-111111111111');
        expect(c.read(anlikSihirbazProvider(_bos)).tekrar, isNull);
        expect(c.read(anlikSihirbazProvider(_bos)).kapak, isNull);
        n.ileri();
        expect(
          c.read(anlikSihirbazProvider(_bos)).adim,
          SihirbazAdimi.anlikOnizleme,
        );
        n.adimaGit(SihirbazAdimi.davet);
        expect(c.read(anlikSihirbazProvider(_bos)).adim, SihirbazAdimi.davet);
        n.ileri();
        expect(
          c.read(anlikSihirbazProvider(_bos)).adim,
          SihirbazAdimi.anlikOnizleme,
          reason: 'Değiştir ile gelinen adımdan önizlemeye dönülür',
        );
      },
    );

    test(
      'davetli seçimi: en çok 10, tekrar dokununca çıkar, biçimsiz yok sayılır',
      () {
        final c = _kapsayici(etkinlikTasimasi());
        final n = _doldur(c);
        List<String> secili() => c.read(anlikSihirbazProvider(_bos)).davetliler;
        final kimlikler = [
          for (var i = 0; i < 12; i++)
            '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        ];
        for (final k in kimlikler) {
          n.davetliDegistir(k);
        }
        expect(secili(), kimlikler.take(anlikDavetliEnCok));
        n
          ..davetliDegistir(kimlikler.first)
          ..davetliDegistir('kimlik-degil');
        expect(secili(), hasLength(anlikDavetliEnCok - 1));
        expect(secili(), isNot(contains(kimlikler.first)));
      },
    );

    test('Boşum açılışı: gün ve davetli işlenir ama "girilen" sayılmaz', () {
      final c = _kapsayici(etkinlikTasimasi());
      final anahtar = (gun: DateTime(2026, 11, 20), davetli: ark.kisiId1);
      c.listen(anlikSihirbazProvider(anahtar), (_, _) {});
      final t = c.read(anlikSihirbazProvider(anahtar));
      expect(t.baslangic, DateTime(2026, 11, 20, 19).toUtc());
      expect(t.bitis, DateTime(2026, 11, 20, 21).toUtc());
      expect(t.davetliler, [ark.kisiId1]);
      final n = c.read(anlikSihirbazProvider(anahtar).notifier);
      expect(n.girdiVar, isFalse);
      n.davetliDegistir(ark.kisiId2);
      expect(n.girdiVar, isTrue);
    });

    test(
      'gönderim: POST /v1/instant-events; tekrar, kapak ve keşfet yok',
      () async {
        final tasima = etkinlikTasimasi({
          'POST $anlikYolu': (_) => anlikJson(),
        });
        final c = _kapsayici(tasima);
        final n = _doldur(c)
          ..davetliDegistir(ark.kisiId1)
          ..davetliDegistir(ark.kisiId2)
          ..ileri();
        await n.gonder();

        final istek = tasima.giden('POST', anlikYolu).single;
        final govde = istek.govde! as Map<String, Object?>;
        expect(govde['invitee_user_ids'], [ark.kisiId1, ark.kisiId2]);
        final etkinlik = govde['event']! as Map<String, Object?>;
        expect(etkinlik['title'], 'Göl kampı');
        expect(etkinlik['type'], 'camp');
        expect(etkinlik['client_request_id'], sahteEtkinlikIstekKimligi);
        expect(etkinlik.containsKey('recurrence'), isFalse);
        expect(etkinlik.containsKey('cover_upload_id'), isFalse);
        expect(etkinlik.containsKey('discoverable'), isFalse);
        expect(tasima.giden('POST', etkinliklerYolu), isEmpty);

        final t = c.read(anlikSihirbazProvider(_bos));
        expect(t.sonuc, ornekEtkinlikId);
        expect(t.anlikSonuc?.tayfa.id, anlikTayfaId);
        final liste = c.read(tayfalarimProvider).value!;
        final eklenen = liste.firstWhere((x) => x.tayfaId == anlikTayfaId);
        expect(eklenen.kind, TayfaKind.instant);
        expect(eklenen.role, Role.admin);
      },
    );

    test('davetli yoksa invitee_user_ids gönderilmez', () async {
      final tasima = etkinlikTasimasi({'POST $anlikYolu': (_) => anlikJson()});
      final c = _kapsayici(tasima);
      final n = _doldur(c)..ileri();
      await n.gonder();
      final govde =
          tasima.giden('POST', anlikYolu).single.govde! as Map<String, Object?>;
      expect(govde.containsKey('invitee_user_ids'), isFalse);
    });

    test('instant-event-limit: girilenler kalır, tekrar denemede aynı istek kimliği', () async {
      var deneme = 0;
      final tasima = etkinlikTasimasi({
        'POST $anlikYolu': (_) => deneme++ == 0
            ? const ApiProblem(status: 429, type: ProblemType.instantEventLimit)
            : anlikJson(),
      });
      final c = _kapsayici(tasima);
      final n = _doldur(c)..ileri();
      await n.gonder();
      var t = c.read(anlikSihirbazProvider(_bos));
      expect(t.hata, isA<ApiProblem>());
      expect(t.baslik, '  Göl kampı ');
      expect(t.anlikSonuc, isNull);

      await n.gonder();
      t = c.read(anlikSihirbazProvider(_bos));
      expect(t.anlikSonuc, isNotNull);
      final kimlikler = [
        for (final i in tasima.giden('POST', anlikYolu))
          ((i.govde! as Map)['event'] as Map)['client_request_id'],
      ];
      expect(kimlikler, [sahteEtkinlikIstekKimligi, sahteEtkinlikIstekKimligi]);
    });
  });

  group('arkadaş daveti (anlık tayfa)', () {
    test(
      'seçilenler sırayla davet edilir; hata olursa kalanlar seçili kalır',
      () async {
        final tasima = etkinlikTasimasi({
          'POST ${ark.tayfaDavetiYolu}': (i) =>
              (i.govde! as Map)['user_id'] == ark.kisiId2
              ? const ApiProblem(status: 403, type: ProblemType.notFriends)
              : {
                  'tayfa_id': anlikTayfaId,
                  'tayfa_name': 'Göl kampı',
                  'user_id': ark.kisiId1,
                  'inviter_user_id': ark.benimId,
                  'invited_at': '2026-11-11T09:00:00Z',
                  'interests': <Object?>[],
                },
        });
        final c = _kapsayici(tasima);
        final provider = anlikDavetProvider(anlikTayfaId);
        c.listen(provider, (_, _) {});
        final n = c.read(provider.notifier)
          ..degistir(ark.kisiId1)
          ..degistir(ark.kisiId2);
        await n.gonder();
        final d = c.read(provider);
        expect(tasima.giden('POST', ark.tayfaDavetiYolu), hasLength(2));
        expect(d.secili, [ark.kisiId2]);
        expect(d.hata, isA<ApiProblem>());
        expect(d.gonderilen, isNull, reason: 'hata varken sayfa kapanmaz');
      },
    );
  });

  group('tayfa özeti', () {
    test('anlık tayfada kurulum kartı ve "7 günde 3 üye" gösterilmez', () {
      final tayfa = Tayfa.fromJson(
        tayfaJson(
          id: anlikTayfaId,
          uyeSayisi: 1,
          tur: 'instant',
          anlikEtkinlikId: ornekEtkinlikId,
        ),
      );
      final ozet = TayfaOzeti(tayfa: tayfa, rol: Role.admin, tur: tayfa.kind);
      expect(ozet.anlik, isTrue);
      expect(ozet.anlikEtkinlikId, ornekEtkinlikId);
      expect(
        kurulumGosterilsin(ozet, simdi: sabitSimdi, yeniOlusturuldu: true),
        isFalse,
      );
      expect(kuralGosterilsin(ozet, simdi: sabitSimdi), isFalse);
    });
  });
}
