import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/arkadas/application/arkadas_bulma_notifier.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/kisi_profili_notifier.dart';
import 'package:tayfam/features/arkadas/application/tayfa_davetleri_notifier.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

ProviderContainer _kap(SahteTayfaTasima tasima) {
  final kap = ProviderContainer(overrides: arkadasOverridelari(tasima));
  addTearDown(kap.dispose);
  return kap;
}

void main() {
  group('referansKoduTemizle', () {
    test('boşlukları atar, harfleri değiştirmez', () {
      expect(referansKoduTemizle('  tyf-ab12 '), 'tyf-ab12');
    });

    test('boş ya da çok uzun kod gönderilmez', () {
      expect(referansKoduTemizle('   '), isNull);
      expect(referansKoduTemizle('A' * (referansKoduEnFazla + 1)), isNull);
    });
  });

  group('arkadaş bulma', () {
    test('kod gövdede gider; bulunan kişiye istek gönderilir', () async {
      final tasima = arkadasTasimasi({
        'POST $referansYolu': yanit({
          'user_id': kisiId1,
          'display_name': kisiAdi(kisiId1),
        }),
        'POST $isteklerYolu': yanit(arkadasJson(kisiId1, durum: 'outgoing')),
      });
      final kap = _kap(tasima);
      final dinleyici = kap.listen(arkadasBulmaProvider, (_, _) {});
      addTearDown(dinleyici.close);
      await kap.read(arkadasBulmaProvider.future);

      await kap.read(arkadasBulmaProvider.notifier).ara(' $sahteReferansKodu ');
      final istek = tasima.giden('POST', referansYolu).single;
      expect(istek.govde, {'referral_code': sahteReferansKodu});
      expect(istek.sorgu, isEmpty);
      expect(kap.read(arkadasBulmaProvider).value?.kisi.userId, kisiId1);

      final hata = await kap.read(arkadasBulmaProvider.notifier).istekGonder();
      expect(hata, isNull);
      expect(tasima.giden('POST', isteklerYolu).single.govde, {
        'user_id': kisiId1,
      });
      expect(
        kap.read(arkadasBulmaProvider).value?.durum,
        FriendState.outgoing,
      );
    });

    test('bulunamayan kod hata olarak kalır', () async {
      final tasima = arkadasTasimasi({
        'POST $referansYolu': yanit(
          const ApiProblem(type: ProblemType.referralCodeNotFound, status: 404),
        ),
      });
      final kap = _kap(tasima);
      final dinleyici = kap.listen(arkadasBulmaProvider, (_, _) {});
      addTearDown(dinleyici.close);
      await kap.read(arkadasBulmaProvider.future);

      await kap.read(arkadasBulmaProvider.notifier).ara(sahteReferansKodu);
      expect(kap.read(arkadasBulmaProvider).error, isA<ApiProblem>());
    });

    test('boş kod için istek yapılmaz', () async {
      final tasima = arkadasTasimasi();
      final kap = _kap(tasima);
      final dinleyici = kap.listen(arkadasBulmaProvider, (_, _) {});
      addTearDown(dinleyici.close);
      await kap.read(arkadasBulmaProvider.notifier).ara('  ');
      expect(tasima.giden('POST', referansYolu), isEmpty);
    });
  });

  group('arkadaşlar ve istekler', () {
    test('sayfalı liste; çıkarınca listeden düşer', () async {
      final tasima = arkadasTasimasi({
        'GET $arkadaslarYolu': (i) => i.sorgu['page_token'] == null
            ? arkadasListesiJson([arkadasJson(kisiId1)], sonraki: 's2')
            : arkadasListesiJson([arkadasJson(kisiId2)]),
        'DELETE $arkadasYolu': yanit(null),
      });
      final kap = _kap(tasima);
      final dinleyici = kap.listen(arkadaslarProvider, (_, _) {});
      addTearDown(dinleyici.close);
      final ilk = await kap.read(arkadaslarProvider.future);
      expect(ilk.ogeler.map((a) => a.userId), [kisiId1]);
      expect(tasima.giden('GET', arkadaslarYolu).single.sorgu['page_size'], '50');

      await kap.read(arkadaslarProvider.notifier).dahaFazla();
      expect(tasima.giden('GET', arkadaslarYolu).last.sorgu['page_token'], 's2');

      final hata = await kap.read(arkadaslarProvider.notifier).cikar(kisiId1);
      expect(hata, isNull);
      expect(
        tasima.giden('DELETE', arkadasYolu).single.yolParametreleri['user_id'],
        kisiId1,
      );
      expect(
        kap.read(arkadaslarProvider).value!.ogeler.map((a) => a.userId),
        [kisiId2],
      );
    });

    test('gelen isteği kabul edince arkadaş listesi tazelenir', () async {
      final tasima = arkadasTasimasi({
        'GET $isteklerYolu': yanit(
          arkadasListesiJson([arkadasJson(kisiId1, durum: 'incoming')]),
        ),
        'POST $kabulYolu': yanit(arkadasJson(kisiId1)),
      });
      final kap = _kap(tasima);
      final gelen = arkadasIstekleriProvider(
        ListFriendRequestsDirection.incoming,
      );
      final d1 = kap.listen(gelen, (_, _) {});
      final d2 = kap.listen(arkadaslarProvider, (_, _) {});
      addTearDown(d1.close);
      addTearDown(d2.close);
      await kap.read(gelen.future);
      await kap.read(arkadaslarProvider.future);
      expect(
        tasima.giden('GET', isteklerYolu).single.sorgu['direction'],
        'incoming',
      );

      final hata = await kap.read(gelen.notifier).kabulEt(kisiId1);
      expect(hata, isNull);
      expect(kap.read(gelen).value!.ogeler, isEmpty);
      await kap.read(arkadaslarProvider.future);
      expect(tasima.giden('GET', arkadaslarYolu), hasLength(2));
    });

    test('gönderilen isteği geri çekmek DELETE ile', () async {
      final tasima = arkadasTasimasi({
        'GET $isteklerYolu': yanit(
          arkadasListesiJson([arkadasJson(kisiId1, durum: 'outgoing')]),
        ),
        'DELETE $arkadasYolu': yanit(null),
      });
      final kap = _kap(tasima);
      final giden = arkadasIstekleriProvider(
        ListFriendRequestsDirection.outgoing,
      );
      final d = kap.listen(giden, (_, _) {});
      addTearDown(d.close);
      await kap.read(giden.future);

      expect(await kap.read(giden.notifier).kaldir(kisiId1), isNull);
      expect(tasima.giden('DELETE', arkadasYolu), hasLength(1));
      expect(kap.read(giden).value!.ogeler, isEmpty);
    });

    test('gelen istek rozeti yalnızca ilk kaydı ister', () async {
      final tasima = arkadasTasimasi({
        'GET $isteklerYolu': yanit(
          arkadasListesiJson([arkadasJson(kisiId1, durum: 'incoming')]),
        ),
      });
      final kap = _kap(tasima);
      final d = kap.listen(gelenIstekVarProvider, (_, _) {});
      addTearDown(d.close);
      expect(await kap.read(gelenIstekVarProvider.future), isTrue);
      final istek = tasima.giden('GET', isteklerYolu).single;
      expect(istek.sorgu['page_size'], '1');
      expect(istek.sorgu['direction'], 'incoming');
    });

    test('engel kaldırılınca listeden düşer', () async {
      final tasima = arkadasTasimasi({
        'GET $engellerYolu': yanit({
          'users': [engelJson(kisiId1, ad: 'Kişi 1'), engelJson(kisiId2)],
        }),
        'DELETE $engelYolu': yanit(null),
      });
      final kap = _kap(tasima);
      final d = kap.listen(engellenenlerProvider, (_, _) {});
      addTearDown(d.close);
      await kap.read(engellenenlerProvider.future);

      final hata = await kap
          .read(engellenenlerProvider.notifier)
          .engeliKaldir(kisiId1);
      expect(hata, isNull);
      expect(
        kap.read(engellenenlerProvider).value!.ogeler.map((e) => e.userId),
        [kisiId2],
      );
    });
  });

  group('kişi profili', () {
    test('istek gönderince durum yansır ve profil tazelenir', () async {
      var durum = '';
      final tasima = arkadasTasimasi({
        'GET $profilYolu': (_) => kisiProfiliJson(
          kisiId1,
          durum: durum.isEmpty ? null : durum,
        ),
        'POST $isteklerYolu': (_) {
          durum = 'outgoing';
          return arkadasJson(kisiId1, durum: 'outgoing');
        },
      });
      final kap = _kap(tasima);
      final profil = kisiProfiliProvider(kisiId1);
      final d = kap.listen(profil, (_, _) {});
      addTearDown(d.close);
      expect((await kap.read(profil.future)).friendState, isNull);

      expect(await kap.read(profil.notifier).istekGonder(), isNull);
      expect(
        kap.read(profil).value!.friendState,
        UserProfileFriendState.outgoing,
      );
      await pumpEventQueue();
      expect(tasima.giden('GET', profilYolu), hasLength(2));
    });

    test('engelleme PUT ile; arkadaş listesi tazelenir', () async {
      final tasima = arkadasTasimasi({
        'GET $profilYolu': yanit(kisiProfiliJson(kisiId1, durum: 'friends')),
        'PUT $engelYolu': yanit(null),
      });
      final kap = _kap(tasima);
      final profil = kisiProfiliProvider(kisiId1);
      final d1 = kap.listen(profil, (_, _) {});
      final d2 = kap.listen(arkadaslarProvider, (_, _) {});
      addTearDown(d1.close);
      addTearDown(d2.close);
      await kap.read(profil.future);
      await kap.read(arkadaslarProvider.future);

      expect(await kap.read(profil.notifier).engelle(), isNull);
      expect(
        tasima.giden('PUT', engelYolu).single.yolParametreleri['user_id'],
        kisiId1,
      );
      await kap.read(arkadaslarProvider.future);
      expect(tasima.giden('GET', arkadaslarYolu), hasLength(2));
    });

    test('tayfaya davet gövdede kişiyi taşır; hata döner', () async {
      final tasima = arkadasTasimasi({
        'POST $tayfaDavetiYolu': yanit(
          const ApiProblem(type: ProblemType.alreadyInvited, status: 409),
        ),
      });
      final kap = _kap(tasima);
      final profil = kisiProfiliProvider(kisiId1);
      final d = kap.listen(profil, (_, _) {});
      addTearDown(d.close);
      await kap.read(profil.future);

      final hata = await kap
          .read(profil.notifier)
          .tayfayaDavetEt(ornekTayfaId);
      expect(hata, isA<ApiProblem>());
      final istek = tasima.giden('POST', tayfaDavetiYolu).single;
      expect(istek.yolParametreleri['tayfa_id'], ornekTayfaId);
      expect(istek.govde, {'user_id': kisiId1});
    });

    test('katılım geçmişi sayfalı okunur', () async {
      final tasima = arkadasTasimasi({
        'GET $gecmisYolu': yanit({
          'records': [kayitJson(), kayitJson(uye: false, mod: 'online')],
        }),
      });
      final kap = _kap(tasima);
      final gecmis = katilimGecmisiProvider(kisiId1);
      final d = kap.listen(gecmis, (_, _) {});
      addTearDown(d.close);
      final liste = await kap.read(gecmis.future);
      expect(liste.ogeler, hasLength(2));
      expect(liste.dahaVar, isFalse);
    });
  });

  group('gelen tayfa davetleri', () {
    test('kabul: etkin üyelik, tayfa listesi yenilenir', () async {
      final tasima = arkadasTasimasi({
        'GET $davetlerimYolu': yanit({
          'invitations': [davetJson(ornekTayfaId)],
        }),
        'POST $davetKabulYolu': yanit(uyelikJson(ornekTayfaId)),
      });
      final kap = _kap(tasima);
      final d = kap.listen(tayfaDavetleriProvider, (_, _) {});
      addTearDown(d.close);
      await kap.read(tayfaDavetleriProvider.future);
      final onceki = tasima.giden('GET', '/v1/tayfas').length;

      final sonuc = await kap
          .read(tayfaDavetleriProvider.notifier)
          .kabulEt(ornekTayfaId);
      expect(sonuc.hata, isNull);
      expect(sonuc.etkin, isTrue);
      expect(kap.read(tayfaDavetleriProvider).value!.ogeler, isEmpty);
      await pumpEventQueue();
      expect(tasima.giden('GET', '/v1/tayfas').length, greaterThan(onceki));
    });

    test('kabul: onay bekleyen üyelik', () async {
      final tasima = arkadasTasimasi({
        'GET $davetlerimYolu': yanit({
          'invitations': [davetJson(ornekTayfaId)],
        }),
        'POST $davetKabulYolu': yanit(
          uyelikJson(ornekTayfaId, durum: 'pending'),
        ),
      });
      final kap = _kap(tasima);
      final d = kap.listen(tayfaDavetleriProvider, (_, _) {});
      addTearDown(d.close);
      await kap.read(tayfaDavetleriProvider.future);

      final sonuc = await kap
          .read(tayfaDavetleriProvider.notifier)
          .kabulEt(ornekTayfaId);
      expect(sonuc.etkin, isFalse);
    });

    test('ret DELETE ile', () async {
      final tasima = arkadasTasimasi({
        'GET $davetlerimYolu': yanit({
          'invitations': [davetJson(ornekTayfaId)],
        }),
        'DELETE $davetimYolu': yanit(null),
      });
      final kap = _kap(tasima);
      final d = kap.listen(tayfaDavetleriProvider, (_, _) {});
      addTearDown(d.close);
      await kap.read(tayfaDavetleriProvider.future);

      expect(
        await kap.read(tayfaDavetleriProvider.notifier).reddet(ornekTayfaId),
        isNull,
      );
      expect(tasima.giden('DELETE', davetimYolu), hasLength(1));
    });
  });
}
