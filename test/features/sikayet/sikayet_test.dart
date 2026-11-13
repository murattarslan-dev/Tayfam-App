import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/sikayet/application/moderasyon_kuyrugu.dart';
import 'package:tayfam/features/sikayet/application/sikayet_formu.dart';
import 'package:tayfam/features/sikayet/application/sikayet_hedefi.dart';
import 'package:tayfam/features/sikayet/presentation/moderasyon_ekrani.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_sayfasi.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

ProviderContainer _kap(SahteTayfaTasima tasima) {
  final kap = ProviderContainer(overrides: sikayetOverridelari(tasima));
  addTearDown(kap.dispose);
  return kap;
}

const SikayetHedefi _duyuruHedefi = SikayetHedefi.tayfada(
  tayfaId: ornekTayfaId,
  tur: ReportTargetType.announcement,
  id: duyuruId,
);

/// [hedef]'i görünür yapıp dokunur.
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

/// Şikâyet sayfasını açan düğmeli bir ekran.
Widget _acici(SikayetHedefi hedef) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => sikayetSayfasiniAc(context, hedef),
        child: const Text('ac'),
      ),
    ),
  ),
);

Future<void> _sayfayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  SikayetHedefi hedef, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await widgetAc(
    tester,
    _acici(hedef),
    themeMode: themeMode,
    tayfa: sikayetOverridelari(tasima),
  );
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
}

Future<void> _kuyruguAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  const ModerasyonKuyruguEkrani(tayfaId: ornekTayfaId),
  themeMode: themeMode,
  tayfa: sikayetOverridelari(tasima),
);

void main() {
  group('SikayetHedefi', () {
    test('gerekçeler hedefe göre: sahte etkinlik, yönetim şikâyeti', () {
      expect(_duyuruHedefi.gerekceler, isNot(contains(ReportReason.fakeEvent)));
      expect(
        _duyuruHedefi.gerekceler,
        isNot(contains(ReportReason.staffConduct)),
      );
      expect(_duyuruHedefi.gerekceler.first, ReportReason.childSafety);
      const etkinlik = SikayetHedefi.tayfada(
        tayfaId: ornekTayfaId,
        tur: ReportTargetType.event,
        id: duyuruId,
      );
      expect(etkinlik.gerekceler, contains(ReportReason.fakeEvent));
      const uye = SikayetHedefi.tayfada(
        tayfaId: ornekTayfaId,
        tur: ReportTargetType.user,
        id: uyeId,
      );
      expect(uye.gerekceler, contains(ReportReason.staffConduct));
      expect(
        const SikayetHedefi.tayfa(ornekTayfaId).gerekceler,
        contains(ReportReason.staffConduct),
      );
      const mesaj = SikayetHedefi.birebirMesaj(id: mesajId, mesajMetni: 'x');
      expect(mesaj.gerekceler, isNot(contains(ReportReason.staffConduct)));
      expect(mesaj.yalnizcaPlatform, isTrue);
      expect(_duyuruHedefi.yalnizcaPlatform, isFalse);
    });

    test('kişi profilinden kullanıcı yalnızca platforma gider (#187)', () {
      const kisi = SikayetHedefi.kullanici(uyeId);
      expect(kisi.tur, ReportTargetType.user);
      expect(kisi.tayfaId, isNull);
      expect(kisi.yalnizcaPlatform, isTrue);
      expect(kisi.gerekceler, isNot(contains(ReportReason.staffConduct)));
      expect(kisi.istek(ReportReason.harassment, '').toJson(), {
        'target_type': 'user',
        'target_id': uyeId,
        'reason': 'harassment',
      });
    });

    test('tayfa hedefinin kimliği tayfanın kimliği', () {
      const hedef = SikayetHedefi.tayfa(ornekTayfaId);
      expect(hedef.id, ornekTayfaId);
      expect(hedef.istek(ReportReason.other, '').toJson(), {
        'target_type': 'tayfa',
        'target_id': ornekTayfaId,
        'reason': 'other',
      });
    });

    test('not kırpılır; boş not gönderilmez', () {
      expect(
        _duyuruHedefi.istek(ReportReason.spam, '  reklam  ').description,
        'reklam',
      );
      expect(_duyuruHedefi.istek(ReportReason.spam, '   ').description, isNull);
    });

    test('birebir mesaj metni kırpılır ve 2000 karakterde kesilir', () {
      expect(kanitMetni('  merhaba  '), 'merhaba');
      expect(kanitMetni('   '), isNull);
      final uzun = '🙂' * (kanitMetniEnCok + 5);
      expect(kanitMetni(uzun)!.runes.length, kanitMetniEnCok);
      final istek = const SikayetHedefi.birebirMesaj(
        id: mesajId,
        mesajMetni: ' kaba söz ',
      ).istek(ReportReason.harassment, '');
      expect(istek.toJson(), {
        'target_type': 'dm_message',
        'target_id': mesajId,
        'reason': 'harassment',
        'evidence_text': 'kaba söz',
      });
    });
  });

  group('SikayetFormuNotifier', () {
    test('tayfa ucuna gider; ikinci gönderim istek atmaz', () async {
      final tasima = SahteTayfaTasima({
        'POST $sikayetlerYolu': yanit(benimSikayetimJson()),
      });
      final kap = _kap(tasima);
      final saglayici = sikayetFormuProvider(_duyuruHedefi);
      kap.listen(saglayici, (_, _) {});

      final tamam = await kap
          .read(saglayici.notifier)
          .gonder(ReportReason.spam, 'reklam');

      expect(tamam, isTrue);
      expect(kap.read(saglayici).gonderildi, isTrue);
      final giden = tasima.giden('POST', sikayetlerYolu).single;
      expect(giden.yolParametreleri['tayfa_id'], ornekTayfaId);
      expect(giden.govde, {
        'target_type': 'announcement',
        'target_id': duyuruId,
        'reason': 'spam',
        'description': 'reklam',
      });
      await kap.read(saglayici.notifier).gonder(ReportReason.spam, '');
      expect(tasima.giden('POST', sikayetlerYolu), hasLength(1));
    });

    test('birebir mesaj yalnızca platform ucuna, metinle gider', () async {
      final tasima = SahteTayfaTasima({
        'POST $benimSikayetlerimYolu': yanit(
          benimSikayetimJson(tur: 'dm_message', hedef: mesajId, tayfa: null),
        ),
      });
      final kap = _kap(tasima);
      const hedef = SikayetHedefi.birebirMesaj(
        id: mesajId,
        mesajMetni: 'kaba söz',
      );
      final saglayici = sikayetFormuProvider(hedef);
      kap.listen(saglayici, (_, _) {});

      await kap.read(saglayici.notifier).gonder(ReportReason.harassment, '');

      expect(tasima.giden('POST', sikayetlerYolu), isEmpty);
      expect(tasima.giden('POST', benimSikayetlerimYolu).single.govde, {
        'target_type': 'dm_message',
        'target_id': mesajId,
        'reason': 'harassment',
        'evidence_text': 'kaba söz',
      });
    });

    test('kişi profilinden kullanıcı şikâyeti platform ucuna gider', () async {
      final tasima = SahteTayfaTasima({
        'POST $benimSikayetlerimYolu': yanit(
          benimSikayetimJson(tur: 'user', hedef: uyeId, tayfa: null),
        ),
      });
      final kap = _kap(tasima);
      const hedef = SikayetHedefi.kullanici(uyeId);
      final saglayici = sikayetFormuProvider(hedef);
      kap.listen(saglayici, (_, _) {});

      final tamam = await kap
          .read(saglayici.notifier)
          .gonder(ReportReason.impersonation, ' sahte hesap ');

      expect(tamam, isTrue);
      expect(tasima.giden('POST', sikayetlerYolu), isEmpty);
      expect(tasima.giden('POST', benimSikayetlerimYolu).single.govde, {
        'target_type': 'user',
        'target_id': uyeId,
        'reason': 'impersonation',
        'description': 'sahte hesap',
      });
    });

    test('biçimsiz kimlik ve boş mesajla istek gitmez', () async {
      final tasima = SahteTayfaTasima();
      final kap = _kap(tasima);
      for (final hedef in const [
        SikayetHedefi.tayfada(
          tayfaId: ornekTayfaId,
          tur: ReportTargetType.answer,
          id: 'bozuk',
        ),
        SikayetHedefi.birebirMesaj(id: mesajId, mesajMetni: '  '),
      ]) {
        final saglayici = sikayetFormuProvider(hedef);
        kap.listen(saglayici, (_, _) {});
        final tamam = await kap
            .read(saglayici.notifier)
            .gonder(ReportReason.spam, '');
        expect(tamam, isFalse);
        expect(kap.read(saglayici).hata, isA<GecersizHedef>());
      }
      expect(tasima.istekler, isEmpty);
    });

    test('sınır hatası gösterilir', () async {
      final tasima = SahteTayfaTasima({
        'POST $sikayetlerYolu': yanit(
          const ApiProblem(type: ProblemType.reportLimit, status: 429),
        ),
      });
      final kap = _kap(tasima);
      final saglayici = sikayetFormuProvider(_duyuruHedefi);
      kap.listen(saglayici, (_, _) {});

      final tamam = await kap
          .read(saglayici.notifier)
          .gonder(ReportReason.spam, '');

      expect(tamam, isFalse);
      expect(kap.read(saglayici).hata, isA<ApiProblem>());
      expect(kap.read(saglayici).gonderildi, isFalse);
    });
  });

  group('ModerasyonKuyruguNotifier', () {
    test('açık kuyruk okunur; sonuçlandırma listeden çıkarır', () async {
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(
          kuyrukJson([
            kuyrukSikayetiJson(),
            kuyrukSikayetiJson(id: sikayetId2, tur: 'user', hedef: uyeId),
          ]),
        ),
        'POST $cozumYolu': yanit(
          kuyrukSikayetiJson(durum: 'resolved', sonuc: 'dismissed'),
        ),
      });
      final kap = _kap(tasima);
      final saglayici = moderasyonKuyruguProvider((
        tayfaId: ornekTayfaId,
        acik: true,
      ));
      kap.listen(saglayici, (_, _) {});
      final liste = await kap.read(saglayici.future);
      expect(liste.ogeler, hasLength(2));
      expect(
        tasima.giden('GET', sikayetlerYolu).single.sorgu['status'],
        'open',
      );

      final hata = await kap
          .read(saglayici.notifier)
          .sonuclandir(
            liste.ogeler.first,
            ModerationReportResolution.dismissed,
          );

      expect(hata, isNull);
      expect(tasima.giden('POST', cozumYolu).single.govde, {
        'resolution': 'dismissed',
      });
      expect(kap.read(saglayici).value!.ogeler.single.id, sikayetId2);
    });

    test('kaldır ve sonuçlandır: önce DELETE, sonra çözüm', () async {
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(
          kuyrukJson([kuyrukSikayetiJson(tur: 'answer', hedef: cevapId)]),
        ),
        'DELETE $cevapYolu': yanit(null),
        'POST $cozumYolu': yanit(
          kuyrukSikayetiJson(durum: 'resolved', sonuc: 'content_removed'),
        ),
      });
      final kap = _kap(tasima);
      final saglayici = moderasyonKuyruguProvider((
        tayfaId: ornekTayfaId,
        acik: true,
      ));
      kap.listen(saglayici, (_, _) {});
      final liste = await kap.read(saglayici.future);

      final hata = await kap
          .read(saglayici.notifier)
          .kaldirVeSonuclandir(liste.ogeler.single);

      expect(hata, isNull);
      expect(tasima.istekler.map((i) => i.toString()), [
        'GET $sikayetlerYolu',
        'DELETE $cevapYolu',
        'POST $cozumYolu',
      ]);
      expect(tasima.giden('POST', cozumYolu).single.govde, {
        'resolution': 'content_removed',
      });
      expect(kap.read(saglayici).value!.ogeler, isEmpty);
    });

    test('işlem yapılmadan sonuçlandırma hatası döner', () async {
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(kuyrukJson([kuyrukSikayetiJson()])),
        'POST $cozumYolu': yanit(
          const ApiProblem(type: ProblemType.reportActionMissing, status: 409),
        ),
      });
      final kap = _kap(tasima);
      final saglayici = moderasyonKuyruguProvider((
        tayfaId: ornekTayfaId,
        acik: true,
      ));
      kap.listen(saglayici, (_, _) {});
      final liste = await kap.read(saglayici.future);

      final hata = await kap
          .read(saglayici.notifier)
          .sonuclandir(
            liste.ogeler.single,
            ModerationReportResolution.contentRemoved,
          );

      expect(hata, isA<ApiProblem>());
      expect(kap.read(saglayici).value!.ogeler, hasLength(1));
    });

    test('silinen içerik önizlemede "görünmüyor"', () async {
      final tasima = SahteTayfaTasima({
        'GET $duyuruYolu': yanit(
          const ApiProblem(type: ProblemType.announcementNotFound, status: 404),
        ),
      });
      final kap = _kap(tasima);
      final saglayici = hedefOnizlemesiProvider((
        tayfaId: ornekTayfaId,
        tur: ReportTargetType.announcement,
        id: duyuruId,
      ));
      kap.listen(saglayici, (_, _) {});

      final onizleme = await kap.read(saglayici.future);

      expect(onizleme.gorunmuyor, isTrue);
      expect(onizleme.baslik, isNull);
    });
  });

  group('şikâyet sayfası', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${tema.name}: 2× yazı, 320 dp, taşmasız; gönderilir', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = SahteTayfaTasima({
          'POST $sikayetlerYolu': yanit(benimSikayetimJson()),
        });
        await _sayfayiAc(tester, tasima, _duyuruHedefi, themeMode: tema);

        expect(find.text(arbMetni('sikayet_soru_duyuru')), findsOneWidget);
        expect(find.text(arbMetni('sikayet_gizlilik')), findsOneWidget);
        expect(
          find.text(arbMetni('sikayet_gerekce_cocuk_guvenligi_aciklama')),
          findsOneWidget,
        );
        // Gerekçe seçilmeden gönderilemez.
        await _dokun(tester, find.text(arbMetni('sikayet_gonder')));
        expect(tasima.istekler, isEmpty);

        await _dokun(tester, find.text(arbMetni('sikayet_gerekce_spam')));
        await _dokun(tester, find.text(arbMetni('sikayet_gonder')));

        expect(tasima.giden('POST', sikayetlerYolu), hasLength(1));
        expect(find.text(arbMetni('sikayet_soru_duyuru')), findsNothing);
        expect(find.text(arbMetni('sikayet_iletildi')), findsOneWidget);
      });
    }

    testWidgets('hata sayfada gösterilir, sayfa açık kalır', (tester) async {
      ekranBoyutu(tester);
      final tasima = SahteTayfaTasima({
        'POST $sikayetlerYolu': yanit(
          const ApiProblem(type: ProblemType.reportTargetNotFound, status: 404),
        ),
      });
      await _sayfayiAc(tester, tasima, _duyuruHedefi);

      await _dokun(tester, find.text(arbMetni('sikayet_gerekce_spam')));
      await _dokun(tester, find.text(arbMetni('sikayet_gonder')));

      expect(
        find.text(arbMetni('hata_report_target_not_found')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('sikayet_soru_duyuru')), findsOneWidget);
    });

    testWidgets('birebir mesaj: metin gösterilir, platform notu', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final tasima = SahteTayfaTasima({
        'POST $benimSikayetlerimYolu': yanit(
          benimSikayetimJson(tur: 'dm_message', hedef: mesajId, tayfa: null),
        ),
      });
      await widgetAc(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => birebirMesajiSikayetEt(
                context,
                mesajId: mesajId,
                mesajMetni: 'Kaba bir mesaj',
              ),
              child: const Text('ac'),
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
        tayfa: sikayetOverridelari(tasima),
      );
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      expect(find.text('Kaba bir mesaj'), findsOneWidget);
      expect(find.text(arbMetni('sikayet_gizlilik_platform')), findsOneWidget);
      expect(find.text(arbMetni('sikayet_gerekce_yonetim')), findsNothing);

      await _dokun(tester, find.text(arbMetni('sikayet_gerekce_taciz')));
      await _dokun(tester, find.text(arbMetni('sikayet_gonder')));

      expect(
        tasima.giden('POST', benimSikayetlerimYolu).single.govde,
        containsPair('evidence_text', 'Kaba bir mesaj'),
      );
    });
  });

  group('moderasyon kuyruğu ekranı', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${tema.name}: 2× yazı, 320 dp; öncelik ve önizleme', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        final tasima = SahteTayfaTasima({
          'GET $sikayetlerYolu': yanit(
            kuyrukJson([
              kuyrukSikayetiJson(
                gerekce: 'child_safety',
                oncelik: 'minor_involved',
                not: 'Rahatsız edici',
              ),
            ]),
          ),
          'GET $duyuruYolu': yanit(duyuruJson()),
        });
        await _kuyruguAc(tester, tasima, themeMode: tema);

        expect(find.text(arbMetni('sikayet_oncelikli')), findsOneWidget);
        expect(
          find.text(arbMetni('sikayet_gerekce_cocuk_guvenligi')),
          findsOneWidget,
        );
        expect(find.text('İçerik: Pazar buluşması'), findsOneWidget);
        expect(
          find.text('Şikâyet edenin notu: Rahatsız edici'),
          findsOneWidget,
        );
        expect(find.text('Üye Kişi'), findsOneWidget);
        expect(find.text(arbMetni('sikayet_sonuclandir')), findsOneWidget);
        expect(find.text(arbMetni('sikayet_kaldir')), findsOneWidget);
      });
    }

    testWidgets('boş kuyruk metni', (tester) async {
      ekranBoyutu(tester);
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(kuyrukJson([])),
      });
      await _kuyruguAc(tester, tasima);
      expect(find.text(arbMetni('sikayet_kuyruk_acik_bos')), findsOneWidget);
    });

    testWidgets('yetki yoksa hata ve tekrar dene', (tester) async {
      ekranBoyutu(tester);
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(
          const ApiProblem(type: ProblemType.permissionDenied, status: 403),
        ),
      });
      await _kuyruguAc(tester, tasima);
      expect(find.text(arbMetni('hata_permission_denied')), findsOneWidget);
      expect(find.text(arbMetni('sikayet_tekrar_dene')), findsOneWidget);
    });

    testWidgets('üye şikâyeti: "İçerik kaldırıldı" seçeneği yok; reddedilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(
          kuyrukJson([kuyrukSikayetiJson(tur: 'user', hedef: uyeId)]),
        ),
        'POST $cozumYolu': yanit(
          kuyrukSikayetiJson(
            tur: 'user',
            hedef: uyeId,
            durum: 'resolved',
            sonuc: 'dismissed',
          ),
        ),
      });
      await _kuyruguAc(tester, tasima);

      expect(find.text(arbMetni('sikayet_kaldir')), findsNothing);
      await _dokun(tester, find.text(arbMetni('sikayet_sonuclandir')));
      expect(find.text(arbMetni('sikayet_sonuc_kaldirildi')), findsNothing);
      await _dokun(tester, find.text(arbMetni('sikayet_sonuc_islem_yok')));

      expect(tasima.giden('POST', cozumYolu).single.govde, {
        'resolution': 'dismissed',
      });
      expect(find.text(arbMetni('sikayet_sonuclandi')), findsOneWidget);
      expect(find.text(arbMetni('sikayet_kuyruk_acik_bos')), findsOneWidget);
    });

    testWidgets('içerik kaldırma onay ister', (tester) async {
      ekranBoyutu(tester);
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(
          kuyrukJson([kuyrukSikayetiJson(tur: 'answer', hedef: cevapId)]),
        ),
        'DELETE $cevapYolu': yanit(null),
        'POST $cozumYolu': yanit(
          kuyrukSikayetiJson(durum: 'resolved', sonuc: 'content_removed'),
        ),
      });
      await _kuyruguAc(tester, tasima);

      await _dokun(tester, find.text(arbMetni('sikayet_kaldir')));
      await _dokun(tester, find.text(arbMetni('sikayet_vazgec')));
      expect(tasima.giden('DELETE', cevapYolu), isEmpty);

      await _dokun(tester, find.text(arbMetni('sikayet_kaldir')));
      await _dokun(tester, find.text(arbMetni('sikayet_kaldir_onayla')));

      expect(tasima.giden('DELETE', cevapYolu), hasLength(1));
      expect(find.text(arbMetni('sikayet_kaldirildi')), findsOneWidget);
    });

    testWidgets('sonuçlanan: kaldırılan cevap geri alınır', (tester) async {
      ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
      ikiKatYazi(tester);
      final tasima = SahteTayfaTasima({
        'GET $sikayetlerYolu': (i) => i.sorgu['status'] == 'resolved'
            ? kuyrukJson([
                kuyrukSikayetiJson(
                  tur: 'answer',
                  hedef: cevapId,
                  durum: 'resolved',
                  sonuc: 'content_removed',
                ),
              ])
            : kuyrukJson([]),
        'POST $cevapGeriAlmaYolu': yanit({
          'id': cevapId,
          'question_id': duyuruId,
          'tayfa_id': ornekTayfaId,
          'body': 'cevap',
          'vote_count': 0,
          'voted': false,
          'created_at': '2026-11-10T10:00:00Z',
          'updated_at': '2026-11-10T10:00:00Z',
        }),
      });
      await _kuyruguAc(tester, tasima, themeMode: ThemeMode.dark);

      await tester.tap(find.text(arbMetni('sikayet_kuyruk_sonuclanan')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('sikayet_sonuc_kaldirildi')), findsOneWidget);
      expect(find.text('Moderatör'), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('sikayet_geri_al')));
      // Onay penceresi: onay düğmesi de "Geri al".
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('sikayet_geri_al')),
        ),
      );

      final giden = tasima.giden('POST', cevapGeriAlmaYolu).single;
      expect(giden.yolParametreleri['answer_id'], cevapId);
      expect(find.text(arbMetni('sikayet_geri_alindi')), findsOneWidget);
    });
  });
}
