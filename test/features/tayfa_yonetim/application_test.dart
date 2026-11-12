import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/davetler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/katilim_istekleri_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/tayfa_ayarlari.dart';
import 'package:tayfam/features/tayfa_yonetim/application/uyeler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/yetki.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Membership _uye(String rol, {String durum = 'active', String? susturma}) =>
    Membership.fromJson(
      uyeJson(uyeId1, rol: rol, durum: durum, susturma: susturma),
    );

ProviderContainer _kap(SahteTayfaTasima tasima) {
  final kap = ProviderContainer(overrides: yonetimOverridelari(tasima));
  addTearDown(kap.dispose);
  return kap;
}

void main() {
  group('uyeEylemleri', () {
    test('yönetici alt seviyedekine her şeyi yapar', () {
      final e = uyeEylemleri(
        ben: Role.admin,
        hedef: _uye('member'),
        kendisi: false,
      );
      expect(e.atanabilirRoller, [Role.moderator, Role.admin]);
      expect(e.susturabilir && e.cikarabilir && e.banlayabilir, isTrue);
    });

    test('moderatör rol değiştiremez, üyeyi susturur', () {
      final e = uyeEylemleri(
        ben: Role.moderator,
        hedef: _uye('member'),
        kendisi: false,
      );
      expect(e.atanabilirRoller, isEmpty);
      expect(e.susturabilir, isTrue);
    });

    test('aynı ya da üst seviyeye dokunulmaz', () {
      expect(
        uyeEylemleri(
          ben: Role.moderator,
          hedef: _uye('moderator'),
          kendisi: false,
        ).herhangi,
        isFalse,
      );
      expect(
        uyeEylemleri(
          ben: Role.admin,
          hedef: _uye('admin'),
          kendisi: false,
        ).herhangi,
        isFalse,
      );
      expect(
        uyeEylemleri(
          ben: Role.member,
          hedef: _uye('member'),
          kendisi: false,
        ).herhangi,
        isFalse,
      );
    });

    test('kendine ve banlıya işlem yok', () {
      expect(
        uyeEylemleri(
          ben: Role.admin,
          hedef: _uye('member'),
          kendisi: true,
        ).herhangi,
        isFalse,
      );
      expect(
        uyeEylemleri(
          ben: Role.admin,
          hedef: _uye('member', durum: 'banned'),
          kendisi: false,
        ).herhangi,
        isFalse,
      );
    });
  });

  test('rol filtresi', () {
    final uyeler = [
      Membership.fromJson(uyeJson(uyeId1, rol: 'admin')),
      Membership.fromJson(uyeJson(uyeId2, rol: 'moderator')),
      Membership.fromJson(uyeJson(uyeId3)),
    ];
    expect(uyeleriSuz(uyeler, UyeFiltresi.hepsi), hasLength(3));
    expect(uyeleriSuz(uyeler, UyeFiltresi.yonetici).single.userId, uyeId1);
    expect(uyeleriSuz(uyeler, UyeFiltresi.moderator).single.userId, uyeId2);
    expect(uyeleriSuz(uyeler, UyeFiltresi.uye).single.userId, uyeId3);
  });

  test('susturulmuş: bitiş gelecekteyse', () {
    expect(
      susturulmus(_uye('member', susturma: '2026-11-12T00:00:00Z'), sabitSimdi),
      isTrue,
    );
    expect(
      susturulmus(_uye('member', susturma: '2026-11-01T00:00:00Z'), sabitSimdi),
      isFalse,
    );
    expect(susturulmus(_uye('member'), sabitSimdi), isFalse);
  });

  group('tayfaSessizde', () {
    NotificationPreference t(Map<String, Object?> j) =>
        NotificationPreference.fromJson(j);

    test('tercih yoksa sessiz değil', () {
      expect(tayfaSessizde(const [], ornekTayfaId, sabitSimdi), isFalse);
    });

    test('none süresiz sessiz; süresi dolmuşsa değil', () {
      expect(
        tayfaSessizde([t(tercihJson())], ornekTayfaId, sabitSimdi),
        isTrue,
      );
      expect(
        tayfaSessizde(
          [t(tercihJson(bitis: '2026-11-01T00:00:00Z'))],
          ornekTayfaId,
          sabitSimdi,
        ),
        isFalse,
      );
    });

    test('başka tayfanın tercihi sayılmaz; all sessiz değil', () {
      expect(
        tayfaSessizde(
          [t(tercihJson(tayfa: ikinciTayfaId))],
          ornekTayfaId,
          sabitSimdi,
        ),
        isFalse,
      );
      expect(
        tayfaSessizde([t(tercihJson(seviye: 'all'))], ornekTayfaId, sabitSimdi),
        isFalse,
      );
    });
  });

  test('davet linki: token yalnızca fragment\'ta', () {
    final link = davetLinki(sahteDavetTokeni);
    final uri = Uri.parse(link);
    expect(uri.scheme, 'https');
    expect(uri.host, 'tayfam.app');
    expect(uri.path, '/davet');
    expect(uri.query, isEmpty);
    expect(uri.fragment, sahteDavetTokeni);
  });

  group('tayfa bilgileri', () {
    final tayfa = ornekTayfa(ornekTayfaId);

    test('değişiklik yoksa null', () {
      expect(
        bilgiDegisiklikleri(
          tayfa,
          ad: ' Klasikçiler ',
          aciklama: '',
          ilgi: {EventType.convoy},
          katilim: JoinPolicy.approval,
          uyeEtkinlikAcar: false,
        ),
        isNull,
      );
    });

    test('yalnızca değişen alanlar gönderilir', () {
      final istek = bilgiDegisiklikleri(
        tayfa,
        ad: 'Klasikçiler',
        aciklama: ' Pazar buluşmaları ',
        ilgi: {EventType.hike, EventType.convoy},
        katilim: JoinPolicy.open,
        uyeEtkinlikAcar: false,
      );
      expect(istek!.toJson(), {
        'description': 'Pazar buluşmaları',
        'interests': ['convoy', 'hike'],
        'join_policy': 'open',
      });
    });

    test('ad ve açıklama doğrulaması', () {
      expect(bilgiHatasi(ad: ' ab ', aciklama: ''), BilgiHatasi.adUzunlugu);
      expect(bilgiHatasi(ad: 'a' * 51, aciklama: ''), BilgiHatasi.adUzunlugu);
      expect(
        bilgiHatasi(ad: 'Tayfa', aciklama: 'a' * 501),
        BilgiHatasi.aciklamaUzunlugu,
      );
      expect(bilgiHatasi(ad: 'Tayfa', aciklama: 'a' * 500), isNull);
    });
  });

  group('notifier\'lar', () {
    test('susturma: şimdiden süre kadar sonrası UTC gönderilir', () async {
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $uyelerYolu': yanit(uyeListesiJson([uyeJson(uyeId1)])),
          'PUT $susturmaYolu': yanit(
            uyeJson(uyeId1, susturma: '2026-11-12T12:00:00Z'),
          ),
        },
      );
      final kap = _kap(tasima);
      final saglayici = uyelerProvider((
        tayfaId: ornekTayfaId,
        banlilar: false,
      ));
      kap.listen(saglayici, (_, _) {});
      await kap.read(saglayici.future);

      final hata = await kap
          .read(saglayici.notifier)
          .sustur(uyeId1, const Duration(days: 1));

      expect(hata, isNull);
      final istek = tasima.giden('PUT', susturmaYolu).single;
      expect(istek.yolParametreleri['user_id'], uyeId1);
      expect(istek.govde, {'muted_until': '2026-11-12T12:00:00.000Z'});
      expect(
        kap.read(saglayici).value!.ogeler.single.mutedUntil,
        DateTime.utc(2026, 11, 12, 12),
      );
    });

    test('banlanan listeden çıkar; hata döner', () async {
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $uyelerYolu': yanit(
            uyeListesiJson([uyeJson(uyeId1), uyeJson(uyeId2)]),
          ),
          'PUT $banYolu': (i) => i.yolParametreleri['user_id'] == uyeId2
              ? const ApiProblem(type: ProblemType.roleHierarchy, status: 403)
              : null,
        },
      );
      final kap = _kap(tasima);
      final saglayici = uyelerProvider((
        tayfaId: ornekTayfaId,
        banlilar: false,
      ));
      kap.listen(saglayici, (_, _) {});
      await kap.read(saglayici.future);

      expect(await kap.read(saglayici.notifier).banla(uyeId1), isNull);
      final hata = await kap.read(saglayici.notifier).banla(uyeId2);
      expect(hata, isA<ApiProblem>());
      expect(kap.read(saglayici).value!.ogeler.map((u) => u.userId), [uyeId2]);
    });

    test('ban gerekçesi: kapalı liste gövdede; staff_conduct gitmez', () async {
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $uyelerYolu': yanit(
            uyeListesiJson([uyeJson(uyeId1), uyeJson(uyeId2)]),
          ),
          'PUT $banYolu': yanit(null),
        },
      );
      final kap = _kap(tasima);
      final saglayici = uyelerProvider((
        tayfaId: ornekTayfaId,
        banlilar: false,
      ));
      kap.listen(saglayici, (_, _) {});
      await kap.read(saglayici.future);
      final n = kap.read(saglayici.notifier);

      expect(await n.banla(uyeId1, gerekce: ReportReason.harassment), isNull);
      expect(await n.banla(uyeId2, gerekce: ReportReason.staffConduct), isNull);

      final istekler = tasima.giden('PUT', banYolu);
      expect(istekler[0].govde, {'reason': 'harassment'});
      expect(istekler[1].govde, isNull);
    });

    test('ban gerekçeleri: şikâyet nedenleri, staff_conduct hariç', () {
      expect(banGerekceleri, isNot(contains(ReportReason.staffConduct)));
      expect(banGerekceleri, isNot(contains(ReportReason.unknown)));
      expect(banGerekceleri.toSet(), {
        for (final r in ReportReason.values)
          if (r != ReportReason.staffConduct && r != ReportReason.unknown) r,
      });
      expect(banGerekceleri.first, ReportReason.childSafety);
    });

    test('banlılar listesi status=banned ister', () async {
      final tasima = yonetimTasimasi();
      final kap = _kap(tasima);
      final saglayici = uyelerProvider((tayfaId: ornekTayfaId, banlilar: true));
      kap.listen(saglayici, (_, _) {});
      await kap.read(saglayici.future);
      expect(tasima.giden('GET', uyelerYolu).single.sorgu['status'], 'banned');
    });

    test('onay listeden çıkarır, bekleyen sayısını yeniler', () async {
      var bekleyen = 1;
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $tayfaYolu': (_) => yonetimGorunumu(bekleyen: bekleyen),
          'GET /v1/tayfas': (_) => listeJson([
            etkinJson(ornekTayfaId, rol: 'admin', bekleyen: bekleyen),
          ]),
          'GET $isteklerYolu': (_) =>
              istekListesiJson([if (bekleyen > 0) istekJson(uyeId1)]),
          'POST $onayYolu': (_) {
            bekleyen = 0;
            return uyeJson(uyeId1);
          },
        },
      );
      final kap = _kap(tasima);
      final liste = katilimIstekleriProvider(ornekTayfaId);
      final gorunum = tayfaGorunumuProvider(ornekTayfaId);
      final ozet = tayfaOzetiProvider(ornekTayfaId);
      kap
        ..listen(liste, (_, _) {})
        ..listen(gorunum, (_, _) {})
        ..listen(ozet, (_, _) {})
        ..listen(tayfalarimProvider, (_, _) {});
      await kap.read(liste.future);
      await kap.read(gorunum.future);
      await kap.read(tayfalarimProvider.future);
      expect(kap.read(ozet).bekleyenIstekSayisi, 1);
      final listeIstegi = tasima.giden('GET', '/v1/tayfas').length;

      expect(await kap.read(liste.notifier).onayla(uyeId1), isNull);
      await pumpEventQueue();
      expect(kap.read(liste).value!.ogeler, isEmpty);
      // Sayı yeniden okunan görünümden gelir; 0 iken rozet yok.
      expect(kap.read(ozet).bekleyenIstekSayisi, isNull);
      expect(
        tasima.giden('GET', '/v1/tayfas').length,
        greaterThan(listeIstegi),
      );
      // `page_size=1` ile var/yok yoklaması yapılmaz.
      expect(
        tasima.giden('GET', isteklerYolu).map((i) => i.sorgu['page_size']),
        everyElement(isNot('1')),
      );
    });

    test('bekleyen sayısı: alan yoksa ya da 0 ise rozet yok', () {
      TayfaOzeti ozet(int? bekleyen) => TayfaOzeti(
        tayfa: Tayfa.fromJson(tayfaJson(id: ornekTayfaId, bekleyen: bekleyen)),
        rol: Role.moderator,
      );
      expect(ozet(null).bekleyenIstekSayisi, isNull);
      expect(ozet(0).bekleyenIstekSayisi, isNull);
      expect(ozet(3).bekleyenIstekSayisi, 3);
      expect(const TayfaOzeti().bekleyenIstekSayisi, isNull);
    });

    test('davet: token yalnızca dönen linkte, durumda yok', () async {
      final tasima = yonetimTasimasi(
        yanitlar: {
          'POST $davetlerYolu': yanit({
            'invite': davetJson(davetId1, kullanilan: 0),
            'token': sahteDavetTokeni,
          }),
        },
      );
      final kap = _kap(tasima);
      final saglayici = davetlerProvider(ornekTayfaId);
      kap.listen(saglayici, (_, _) {});
      await kap.read(saglayici.future);

      final sonuc = await kap
          .read(saglayici.notifier)
          .olustur(sure: const Duration(days: 7), kullanim: 10);

      expect(sonuc.hata, isNull);
      expect(sonuc.link, 'https://tayfam.app/davet#$sahteDavetTokeni');
      expect(tasima.giden('POST', davetlerYolu).single.govde, {
        'ttl_seconds': 604800,
        'max_uses': 10,
      });
      expect(kap.read(saglayici).value!.single.id, davetId1);
    });

    test('sessize alma ve açma', () async {
      final tasima = yonetimTasimasi(
        yanitlar: {
          'PUT $tercihYolu': yanit(tercihJson()),
          'DELETE $tercihYolu': yanit(null),
        },
      );
      final kap = _kap(tasima);
      final saglayici = tayfaSessizProvider(ornekTayfaId);
      kap.listen(saglayici, (_, _) {});
      expect(await kap.read(saglayici.future), isFalse);

      expect(await kap.read(saglayici.notifier).ayarla(sessiz: true), isNull);
      expect(kap.read(saglayici).value, isTrue);
      expect(tasima.giden('PUT', tercihYolu).single.govde, {'level': 'none'});

      expect(await kap.read(saglayici.notifier).ayarla(sessiz: false), isNull);
      expect(kap.read(saglayici).value, isFalse);
      expect(tasima.giden('DELETE', tercihYolu), hasLength(1));
    });
  });
}
