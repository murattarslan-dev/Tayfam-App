import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/kesfet/application/gorunurluk.dart';
import 'package:tayfam/features/kesfet/application/guvenlik_agi.dart';
import 'package:tayfam/features/kesfet/application/kesfet_akisi.dart';
import 'package:tayfam/features/kesfet/application/kesfet_ortak.dart';

import '../tayfa/sahteler.dart' show SahteTayfaTasima;
import 'sahteler.dart';

ProviderContainer _kap(SahteTayfaTasima tasima) {
  final kap = ProviderContainer(overrides: kesfetOverridelari(tasima));
  addTearDown(kap.dispose);
  return kap;
}

const KesfetEtkinligi _anahtar = (
  tayfaId: kesfetTayfaId,
  etkinlikId: kesfetEtkinlikId,
);

void main() {
  group('Keşfet bayrağı (cevaba bakar)', () {
    test('akış okununca girişler görünür; boş liste de açık sayılır', () async {
      final tasima = kesfetTasimasi({
        'GET $akisYolu': yanit({'items': <Object?>[]}),
      });
      final kap = _kap(tasima);
      kap.listen(kesfetAcikProvider, (_, _) {});
      expect(kap.read(kesfetAcikProvider), isFalse);
      await kap.read(kesfetAkisiProvider.future);
      expect(kap.read(kesfetAcikProvider), isTrue);
    });

    test('feature-disabled: girişler gizli ve akış hatası bilinir', () async {
      final tasima = kesfetTasimasi({
        'GET $akisYolu': yanit(ozellikKapaliHatasi),
      });
      final kap = _kap(tasima);
      kap.listen(kesfetAcikProvider, (_, _) {});
      await expectLater(
        kap.read(kesfetAkisiProvider.future),
        throwsA(isA<ApiProblem>()),
      );
      expect(kap.read(kesfetAcikProvider), isFalse);
      expect(ozellikKapali(kap.read(kesfetAkisiProvider).error), isTrue);
    });

    test('başka hata: giriş yine gizli (vaat edilmez)', () async {
      final tasima = kesfetTasimasi({
        'GET $akisYolu': yanit(problem(ProblemType.unavailable, status: 503)),
      });
      final kap = _kap(tasima);
      kap.listen(kesfetAcikProvider, (_, _) {});
      await expectLater(
        kap.read(kesfetAkisiProvider.future),
        throwsA(isA<ApiProblem>()),
      );
      expect(kap.read(kesfetAcikProvider), isFalse);
    });
  });

  group('Keşfet\'ten katılım', () {
    test(
      'istek gider, kart "gönderildi" olur, tayfa listesi yenilenir',
      () async {
        final tasima = kesfetTasimasi({
          'POST $kesfetKatilYolu': yanit({
            'tayfa_id': kesfetTayfaId,
            'user_id': ayseId,
            'role': 'member',
            'status': 'pending',
          }),
        });
        final kap = _kap(tasima);
        kap.listen(kesfetKatilimProvider, (_, _) {});
        final sonuc = await kap
            .read(kesfetKatilimProvider.notifier)
            .katil(kesfetTayfaId);
        expect(sonuc, isA<KatilimGonderildi>());
        expect(
          kap.read(kesfetKatilimProvider)[kesfetTayfaId],
          KatilimAsamasi.gonderildi,
        );
        expect(tasima.giden('POST', kesfetKatilYolu).single.yolParametreleri, {
          'tayfa_id': kesfetTayfaId,
        });
        expect(tasima.giden('GET', '/v1/tayfas'), isNotEmpty);
      },
    );

    test('already-pending başarı sayılır', () async {
      final tasima = kesfetTasimasi({
        'POST $kesfetKatilYolu': yanit(problem(ProblemType.alreadyPending)),
      });
      final kap = _kap(tasima);
      kap.listen(kesfetKatilimProvider, (_, _) {});
      final sonuc = await kap
          .read(kesfetKatilimProvider.notifier)
          .katil(kesfetTayfaId);
      expect(sonuc, isA<KatilimGonderildi>());
    });

    test('already-member ve hata: kart eski haline döner', () async {
      final tasima = kesfetTasimasi({
        'POST $kesfetKatilYolu': yanit(problem(ProblemType.alreadyMember)),
      });
      final kap = _kap(tasima);
      kap.listen(kesfetKatilimProvider, (_, _) {});
      final sonuc = await kap
          .read(kesfetKatilimProvider.notifier)
          .katil(kesfetTayfaId);
      expect(sonuc, isA<ZatenUye>());
      expect(kap.read(kesfetKatilimProvider), isEmpty);
    });

    test('tayfa-not-found: akış yeniden okunur', () async {
      final tasima = kesfetTasimasi({
        'POST $kesfetKatilYolu': yanit(
          problem(ProblemType.tayfaNotFound, status: 404),
        ),
      });
      final kap = _kap(tasima);
      kap.listen(kesfetAkisiProvider, (_, _) {});
      kap.listen(kesfetKatilimProvider, (_, _) {});
      await kap.read(kesfetAkisiProvider.future);
      final sonuc = await kap
          .read(kesfetKatilimProvider.notifier)
          .katil(kesfetTayfaId);
      expect(sonuc, isA<ArtikAkistaDegil>());
      expect(tasima.giden('GET', akisYolu), hasLength(2));
    });
  });

  group('güvenlik kişisi', () {
    test('seçme gövdesi: kişi ve tolerans', () async {
      final tasima = kesfetTasimasi({
        'PUT $guvenlikYolu': yanit(guvenlikJson(tolerans: 120)),
      });
      final kap = _kap(tasima);
      kap.listen(guvenlikKisisiProvider(_anahtar), (_, _) {});
      await kap.read(guvenlikKisisiProvider(_anahtar).future);
      final hata = await kap
          .read(guvenlikKisisiProvider(_anahtar).notifier)
          .sec(ayseId, toleransDakika: 120);
      expect(hata, isNull);
      expect(tasima.giden('PUT', guvenlikYolu).single.govde, {
        'contact_user_id': ayseId,
        'grace_minutes': 120,
      });
      final durum = kap.read(guvenlikKisisiProvider(_anahtar)).value!;
      expect(durum.secili, isTrue);
      expect(durum.kayit.graceMinutes, 120);
    });

    test('kaldırma kişiyi siler; döndüm zamanı yazar', () async {
      final tasima = kesfetTasimasi({
        'GET $guvenlikYolu': yanit(guvenlikJson()),
        'DELETE $guvenlikYolu': yanit(null),
        'POST $dondumYolu': yanit(guvenlikJson(donus: '2026-11-16T09:30:00Z')),
      });
      final kap = _kap(tasima);
      kap.listen(guvenlikKisisiProvider(_anahtar), (_, _) {});
      await kap.read(guvenlikKisisiProvider(_anahtar).future);
      final notifier = kap.read(guvenlikKisisiProvider(_anahtar).notifier);
      expect(await notifier.dondum(), isNull);
      expect(kap.read(guvenlikKisisiProvider(_anahtar)).value!.dondu, isTrue);
      expect(await notifier.kaldir(), isNull);
      expect(kap.read(guvenlikKisisiProvider(_anahtar)).value!.secili, isFalse);
    });

    test('hata: kayıt değişmez, hata döner', () async {
      final tasima = kesfetTasimasi({
        'GET $guvenlikYolu': yanit(guvenlikJson(alarm: '2026-11-16T10:00:00Z')),
        'DELETE $guvenlikYolu': yanit(problem(ProblemType.safetyContactClosed)),
      });
      final kap = _kap(tasima);
      kap.listen(guvenlikKisisiProvider(_anahtar), (_, _) {});
      await kap.read(guvenlikKisisiProvider(_anahtar).future);
      final hata = await kap
          .read(guvenlikKisisiProvider(_anahtar).notifier)
          .kaldir();
      expect((hata! as ApiProblem).type, ProblemType.safetyContactClosed);
      final durum = kap.read(guvenlikKisisiProvider(_anahtar)).value!;
      expect(durum.secili, isTrue);
      expect(durum.mesgul, isFalse);
    });

    test('bayrak kapalı: okuma feature-disabled ile biter', () async {
      final tasima = kesfetTasimasi({
        'GET $guvenlikYolu': yanit(ozellikKapaliHatasi),
      });
      final kap = _kap(tasima);
      kap.listen(guvenlikKisisiProvider(_anahtar), (_, _) {});
      await expectLater(
        kap.read(guvenlikKisisiProvider(_anahtar).future),
        throwsA(isA<ApiProblem>()),
      );
      expect(
        ozellikKapali(kap.read(guvenlikKisisiProvider(_anahtar)).error),
        isTrue,
      );
    });

    test('adaylar yalnızca kabul edilmiş arkadaşlar', () async {
      final kap = _kap(kesfetTasimasi());
      kap.listen(guvenlikAdaylariProvider, (_, _) {});
      final adaylar = await kap.read(guvenlikAdaylariProvider.future);
      expect([for (final a in adaylar) a.userId], [ayseId, mehmetId]);
    });
  });

  group('geri bildirim ve tayfa ayarı', () {
    test('cevap gönderilir ve tutulur', () async {
      final tasima = kesfetTasimasi({
        'PUT $geriBildirimYolu': yanit({
          'answer': 'serious',
          'updated_at': '2026-11-16T12:00:00Z',
        }),
      });
      final kap = _kap(tasima);
      kap.listen(geriBildirimProvider(_anahtar), (_, _) {});
      await kap.read(geriBildirimProvider(_anahtar).future);
      final hata = await kap
          .read(geriBildirimProvider(_anahtar).notifier)
          .ver(EventFeedbackInputAnswer.serious);
      expect(hata, isNull);
      expect(tasima.giden('PUT', geriBildirimYolu).single.govde, {
        'answer': 'serious',
      });
      expect(
        kap.read(geriBildirimProvider(_anahtar)).value!.cevap,
        EventFeedbackAnswer.serious,
      );
    });

    test('5 üyeden az: hata döner, ayar eski kalır', () async {
      final tasima = kesfetTasimasi({
        'PUT $tayfaKesfetYolu': yanit(
          problem(ProblemType.discoverTooFewMembers),
        ),
      });
      final kap = _kap(tasima);
      kap.listen(tayfaKesfetProvider(kesfetTayfaId), (_, _) {});
      await kap.read(tayfaKesfetProvider(kesfetTayfaId).future);
      final hata = await kap
          .read(tayfaKesfetProvider(kesfetTayfaId).notifier)
          .ayarla(acik: true);
      expect((hata! as ApiProblem).type, ProblemType.discoverTooFewMembers);
      expect(tasima.giden('PUT', tayfaKesfetYolu).single.govde, {
        'enabled': true,
      });
      final durum = kap.read(tayfaKesfetProvider(kesfetTayfaId)).value!;
      expect(durum.ayar.enabled, isFalse);
      expect(durum.mesgul, isFalse);
    });
  });

  group('görünürlük kuralları', () {
    final bas = DateTime.utc(2026, 11, 16, 6);
    final bitis = bas.add(const Duration(hours: 3));

    test('güvenlik kartı adayı: yüz yüze, iptalsiz, "Geliyorum"', () {
      final simdi = bas.subtract(const Duration(days: 1));
      expect(guvenlikKartiAdayi(kesfetEtkinligi(), simdi), isTrue);
      expect(
        guvenlikKartiAdayi(kesfetEtkinligi(mod: 'online'), simdi),
        isFalse,
      );
      expect(guvenlikKartiAdayi(kesfetEtkinligi(iptal: true), simdi), isFalse);
      expect(
        guvenlikKartiAdayi(kesfetEtkinligi(cevap: 'maybe'), simdi),
        isFalse,
      );
      expect(
        guvenlikKartiAdayi(
          kesfetEtkinligi(),
          bitis.add(const Duration(hours: 49)),
        ),
        isFalse,
      );
    });

    test('kart: seçilmemişse bitişe kadar, seçilmişse +tolerans +24 saat', () {
      final e = kesfetEtkinligi();
      final bos = SafetyContact.fromJson(guvenlikJson(kisi: false));
      final secili = SafetyContact.fromJson(guvenlikJson());
      expect(guvenlikKartiGorunur(e, bos, bitis), isFalse);
      expect(
        guvenlikKartiGorunur(
          e,
          bos,
          bitis.subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(
        guvenlikKartiGorunur(e, secili, bitis.add(const Duration(hours: 24))),
        isTrue,
      );
      expect(
        guvenlikKartiGorunur(e, secili, bitis.add(const Duration(hours: 25))),
        isFalse,
      );
    });

    test('"Döndüm" başladıktan sonra; değiştirme bitişe ve alarma kadar', () {
      final e = kesfetEtkinligi();
      final secili = SafetyContact.fromJson(guvenlikJson());
      final alarmli = SafetyContact.fromJson(
        guvenlikJson(alarm: '2026-11-16T10:00:00Z'),
      );
      expect(
        dondumGorunur(e, secili, bas.subtract(const Duration(minutes: 1))),
        isFalse,
      );
      expect(dondumGorunur(e, secili, bas), isTrue);
      expect(guvenlikKisisiDegisebilir(e, secili, bas), isTrue);
      expect(guvenlikKisisiDegisebilir(e, secili, bitis), isFalse);
      expect(guvenlikKisisiDegisebilir(e, alarmli, bas), isFalse);
    });

    test('geri bildirim: yalnızca halka açık, doğrulanmış, 7 gün', () {
      final uygun = kesfetEtkinligi(halkaAcik: true, katilim: 'attended');
      expect(geriBildirimAdayi(uygun, bitis), isTrue);
      expect(
        geriBildirimAdayi(uygun, bitis.subtract(const Duration(minutes: 1))),
        isFalse,
      );
      expect(
        geriBildirimAdayi(uygun, bitis.add(const Duration(days: 7))),
        isFalse,
      );
      expect(
        geriBildirimAdayi(kesfetEtkinligi(katilim: 'attended'), bitis),
        isFalse,
      );
      expect(
        geriBildirimAdayi(kesfetEtkinligi(halkaAcik: true), bitis),
        isFalse,
      );
    });
  });
}
