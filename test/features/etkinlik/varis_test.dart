import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/data/konum_servisi.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const EtkinlikAnahtari _anahtar = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
);

Event _etkinlik({
  String? cevap = 'going',
  String mod = 'in_person',
  String tur = 'camp',
  DateTime? baslangic,
  String? katilim,
  bool iptal = false,
}) => Event.fromJson(
  etkinlikJson(
    cevap: cevap,
    mod: mod,
    tur: tur,
    baslangic: baslangic ?? yakinBaslangic,
    sure: const Duration(hours: 3),
    katilim: katilim,
    iptal: iptal,
  ),
);

/// Her kalıcı yazmayı kaydeden token deposu.
final class _KaydedenDepo implements TokenDeposu {
  final List<String> yazilan = [];

  @override
  Future<String?> oku() async => null;

  @override
  Future<void> yaz(String kayit) async => yazilan.add(kayit);

  @override
  Future<void> sil() async {}
}

/// Son tayfa deposunun yazmalarını kaydeden sahtesi.
final class _KaydedenSonTayfa implements SonTayfaDeposu {
  final List<String> yazilan = [];

  @override
  Future<String?> oku() async => null;

  @override
  Future<void> yaz(String tayfaId) async => yazilan.add(tayfaId);

  @override
  Future<void> sil() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pencere ve cevap kuralları', () {
    test('pencere başlangıçtan 30 dakika önce açılır, bitişte kapanır', () {
      final e = _etkinlik(baslangic: ornekBaslangic);
      final bas = e.startsAt;
      final acilis = bas.subtract(varisPenceresiOncesi);
      expect(varisPenceresiAcik(e, acilis), isTrue);
      expect(
        varisPenceresiAcik(e, acilis.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        varisPenceresiAcik(e, e.endsAt.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(varisPenceresiAcik(e, e.endsAt), isFalse);
      final iptal = _etkinlik(baslangic: ornekBaslangic, iptal: true);
      expect(varisPenceresiAcik(iptal, bas), isFalse);
    });

    test('düğme yalnızca "Geliyorum" cevabıyla ve doğrulanmamışken', () {
      expect(varisDugmesiGorunur(_etkinlik(), sabitSimdi), isTrue);
      for (final cevap in [null, 'maybe', 'not_going', 'waitlist']) {
        expect(
          varisDugmesiGorunur(_etkinlik(cevap: cevap), sabitSimdi),
          isFalse,
          reason: '$cevap',
        );
      }
      expect(
        varisDugmesiGorunur(_etkinlik(katilim: 'attended'), sabitSimdi),
        isFalse,
      );
      expect(
        varisDugmesiGorunur(_etkinlik(baslangic: ornekBaslangic), sabitSimdi),
        isFalse,
        reason: 'pencere henüz açılmadı',
      );
      expect(
        varisDugmesiGorunur(_etkinlik(tur: 'hike'), sabitSimdi),
        isFalse,
        reason: 'yürüyüşte katılım "Çıktım" ile',
      );
    });
  });

  group('VarisNotifier', () {
    late SahteKonumServisi konum;

    ProviderContainer kapsayici(
      SahteTayfaTasima tasima, {
      SonTayfaDeposu? sonTayfa,
      List<Override> ek = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          ...etkinlikOverridelari(
            tasima: tasima,
            konum: konum,
            sonTayfa: sonTayfa,
          ),
          ...ek,
        ],
      );
      addTearDown(c.dispose);
      c.listen(etkinlikDetayProvider(_anahtar), (_, _) {});
      c.listen(varisProvider(_anahtar), (_, _) {});
      return c;
    }

    setUp(() => konum = SahteKonumServisi());

    test('yüz yüze: konum yalnızca istek gövdesinde gider', () async {
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => _etkinlik().toJson(),
        'POST $varisYolu': (_) => {
          'attendance': 'attended',
          'method': 'location',
        },
      });
      final c = kapsayici(tasima);
      await c.read(etkinlikDetayProvider(_anahtar).future);
      expect(konum.okuma, 0, reason: 'konum düğmeye basmadan istenmez');

      final sonuc = await c.read(varisProvider(_anahtar).notifier).bildir();

      expect(sonuc, isA<VarisBasarili>());
      expect(konum.okuma, 1);
      expect(tasima.giden('POST', varisYolu).single.govde, {
        'location': {'lat': sahteKonum.lat, 'lng': sahteKonum.lng},
      });
      expect(c.read(varisProvider(_anahtar)), isNull);
      final e = c.read(etkinlikDetayProvider(_anahtar)).value!;
      expect(e.callerAttendance, AttendanceStatus.attended);
    });

    test('çevrimiçi: konum istenmez, gövde boş ("Katıldım")', () async {
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => _etkinlik(mod: 'online').toJson(),
        'POST $varisYolu': (_) => {
          'attendance': 'attended',
          'method': 'online',
        },
      });
      final c = kapsayici(tasima);
      await c.read(etkinlikDetayProvider(_anahtar).future);

      final sonuc = await c.read(varisProvider(_anahtar).notifier).bildir();

      expect(sonuc, isA<VarisBasarili>());
      expect(konum.okuma, 0);
      expect(tasima.giden('POST', varisYolu).single.govde, isEmpty);
    });

    for (final (ad, engel) in [
      ('izin reddi', const KonumIzniYok(kalici: false)),
      ('kalıcı ret', const KonumIzniYok(kalici: true)),
      ('yaklaşık konum', const KonumYaklasik()),
      ('servis kapalı', const KonumServisiKapali()),
      ('okunamadı', const KonumAlinamadi()),
    ]) {
      test('$ad: istek gönderilmez, engel döner', () async {
        konum.sonuc = engel;
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => _etkinlik().toJson(),
        });
        final c = kapsayici(tasima);
        await c.read(etkinlikDetayProvider(_anahtar).future);

        final sonuc = await c.read(varisProvider(_anahtar).notifier).bildir();

        expect(sonuc, isA<VarisKonumEngeli>());
        expect((sonuc! as VarisKonumEngeli).neden, same(engel));
        expect(tasima.giden('POST', varisYolu), isEmpty);
        expect(c.read(varisProvider(_anahtar)), isNull);
      });
    }

    test('ayarlar: servis kapalıysa konum, değilse uygulamanınki', () async {
      final c = kapsayici(etkinlikTasimasi());
      final n = c.read(varisProvider(_anahtar).notifier);
      await n.ayarlariAc(const KonumServisiKapali());
      await n.ayarlariAc(const KonumIzniYok(kalici: true));
      expect(konum.konumAyarlari, 1);
      expect(konum.uygulamaAyarlari, 1);
    });

    test('uzak: sunucu hatası döner, katılım değişmez', () async {
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => _etkinlik().toJson(),
        'POST $varisYolu': (_) =>
            const ApiProblem(type: ProblemType.checkInTooFar, status: 409),
      });
      final c = kapsayici(tasima);
      await c.read(etkinlikDetayProvider(_anahtar).future);

      final sonuc = await c.read(varisProvider(_anahtar).notifier).bildir();

      expect(sonuc, isA<VarisHatasi>());
      expect(
        ((sonuc! as VarisHatasi).hata as ApiProblem).type,
        ProblemType.checkInTooFar,
      );
      final e = c.read(etkinlikDetayProvider(_anahtar)).value!;
      expect(e.callerAttendance, isNull);
    });

    test("konum log'a ve kalıcı depoya gitmez", () async {
      // Gerçek HTTP katmanı: günlük satırları ve istek gövdesi görülür.
      final gunluk = <String>[];
      final gidenGovdeler = <String>[];
      var ilk = true;
      final katman = HttpTasima(
        istemci: MockClient((istek) async {
          gidenGovdeler.add(istek.body);
          if (ilk) {
            ilk = false;
            return _problemYaniti('check-in-too-far', 409);
          }
          return _jsonYaniti({'attendance': 'attended', 'method': 'location'});
        }),
        tabanAdres: Uri.parse('https://api.ornek.test'),
        istemciAdi: 'android',
        gunluk: gunluk.add,
      );
      final depo = _KaydedenDepo();
      final sonTayfa = _KaydedenSonTayfa();
      final kanalCagrilari = <MethodCall>[];
      const kanal = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (cagri) async {
            kanalCagrilari.add(cagri);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .setMockMethodCallHandler(kanal, null),
      );

      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => _etkinlik().toJson(),
        // Varış bildirimi gerçek HTTP katmanından geçer (token sahte).
        'POST $varisYolu': (i) => katman.gonder(
          method: i.method,
          pathTemplate: i.yol,
          pathParams: i.yolParametreleri,
          body: i.govde,
          erisimTokeni: 'deneme-tokeni',
        ),
      });
      final c = kapsayici(
        tasima,
        sonTayfa: sonTayfa,
        ek: [tokenDeposuProvider.overrideWithValue(depo)],
      );
      await c.read(etkinlikDetayProvider(_anahtar).future);
      final n = c.read(varisProvider(_anahtar).notifier);

      expect(await n.bildir(), isA<VarisHatasi>());
      expect(await n.bildir(), isA<VarisBasarili>());

      // Konum yalnızca istek gövdesinde gitti.
      expect(gidenGovdeler, hasLength(2));
      for (final govde in gidenGovdeler) {
        expect(jsonDecode(govde), {
          'location': {'lat': sahteKonum.lat, 'lng': sahteKonum.lng},
        });
      }
      // Günlükte yalnızca yöntem, yol şablonu, durum ve problem türü var.
      expect(gunluk, [
        'POST /v1/tayfas/{tayfa_id}/events/{event_id}/check-in → 409 '
            'checkInTooFar',
        'POST /v1/tayfas/{tayfa_id}/events/{event_id}/check-in → 200',
      ]);
      for (final satir in gunluk) {
        expect(satir, isNot(contains('40.6')));
        expect(satir, isNot(contains('31.28')));
      }
      // Kalıcı depolara hiçbir şey yazılmadı.
      expect(depo.yazilan, isEmpty);
      expect(sonTayfa.yazilan, isEmpty);
      expect(kanalCagrilari, isEmpty);
      // Durumda ve detayda cihaz konumu yok.
      expect(c.read(varisProvider(_anahtar)), isNull);
      final e = c.read(etkinlikDetayProvider(_anahtar)).value!;
      expect(jsonEncode(e.toJson()), isNot(contains('40.600123')));
    });
  });
}

http.Response _jsonYaniti(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _problemYaniti(String tur, int durum) => http.Response(
  jsonEncode({
    'type': 'https://tayfam.app/problems/$tur',
    'title': 'Çok uzak',
    'status': durum,
  }),
  durum,
  headers: {'content-type': 'application/problem+json'},
);
