import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

import '../../../yardimcilar.dart';
import '../sahte_e2e_istemcisi.dart';
import '../sahte_e2e_sunucu.dart';

const String _ali = '5e6f7081-0000-4000-8000-0000000000a1';

/// Oturum durumu dışarıdan değiştirilebilen notifier.
class _Oturum extends OturumDurumuNotifier {
  _Oturum(this._ilk);

  final OturumDurumu _ilk;

  @override
  OturumDurumu build() => _ilk;
}

ProviderContainer _kap(
  SahteE2eIstemcisi i, {
  OturumDurumu oturum = OturumDurumu.acik,
  bool etkin = true,
}) => ProviderContainer.test(
  overrides: [
    e2eEtkinProvider.overrideWithValue(etkin),
    oturumDurumuProvider.overrideWith(() => _Oturum(oturum)),
    e2eDeposuProvider.overrideWithValue(i.depo),
    e2eCihazYoneticisiProvider.overrideWithValue(i.yonetici),
  ],
);

Future<E2eCihazBilgisi> _bekle(ProviderContainer kap) async {
  for (var i = 0; i < 50; i++) {
    final d = kap.read(e2eCihazProvider);
    if (d.durum != E2eCihazDurumu.hazirlaniyor) return d;
    await pumpEventQueue();
  }
  return kap.read(e2eCihazProvider);
}

void main() {
  test('oturum açılınca cihaz kaydedilir ve durum yayınlanır', () async {
    final s = SahteE2eSunucu();
    final i = SahteE2eIstemcisi(s, _ali);
    final kap = _kap(i);
    kap.listen(e2eCihazProvider, (_, _) {});
    expect(kap.read(e2eCihazProvider).durum, E2eCihazDurumu.hazirlaniyor);
    final d = await _bekle(kap);
    expect(d.durum, E2eCihazDurumu.hazir);
    expect(d.cihazId, s.oturumCihazi(i.tasima.oturum)!.id);
    expect(d.eslesmis, isFalse);
    expect(d.gecmisAnahtariSurumu, 0);
    await kap.read(e2eCihazProvider.notifier).hazirOl();
  });

  test('cihaz sınırı: sinirDolu; gönderim e2e-device-limit alır', () async {
    final s = SahteE2eSunucu();
    for (var n = 0; n < 5; n++) {
      await SahteE2eIstemcisi(s, _ali, tohum: n + 10).hazirla();
    }
    final kap = _kap(SahteE2eIstemcisi(s, _ali, tohum: 99));
    kap.listen(e2eCihazProvider, (_, _) {});
    expect((await _bekle(kap)).durum, E2eCihazDurumu.sinirDolu);
    await expectLater(
      kap.read(e2eCihazProvider.notifier).hazirOl(),
      throwsA(
        isA<ApiProblem>().having(
          (p) => p.type,
          'type',
          ProblemType.e2eDeviceLimit,
        ),
      ),
    );
  });

  test('oturum yoksa bütün E2E kayıtları silinir', () async {
    final s = SahteE2eSunucu();
    final i = SahteE2eIstemcisi(s, _ali);
    await i.hazirla();
    expect(i.ham.kayitlar, isNotEmpty);
    final kap = _kap(i, oturum: OturumDurumu.girisYok);
    kap.listen(e2eCihazProvider, (_, _) {});
    await pumpEventQueue();
    expect(kap.read(e2eCihazProvider).durum, E2eCihazDurumu.kapali);
    expect(i.ham.kayitlar, isEmpty);
    expect(i.depo.kimlik, isNull);
  });

  test('çıkışta (açık → giriş yok) temizlenir', () async {
    final s = SahteE2eSunucu();
    final i = SahteE2eIstemcisi(s, _ali);
    final kap = _kap(i);
    kap.listen(e2eCihazProvider, (_, _) {});
    await _bekle(kap);
    expect(i.ham.kayitlar, isNotEmpty);
    kap.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    kap.read(e2eCihazProvider);
    await pumpEventQueue();
    expect(i.ham.kayitlar, isEmpty);
  });

  test('web derlemesi: desteklenmiyor, ağ yok', () async {
    final s = SahteE2eSunucu();
    final kap = _kap(SahteE2eIstemcisi(s, _ali), etkin: false);
    expect(kap.read(e2eCihazProvider).durum, E2eCihazDurumu.desteklenmiyor);
    await pumpEventQueue();
    expect(s.istekler, isEmpty);
  });

  test('hata sonrası yeniden denenir', () async {
    final s = SahteE2eSunucu();
    var kapali = true;
    s.araya = (_) => kapali ? const ApiOffline() : null;
    final kap = _kap(SahteE2eIstemcisi(s, _ali));
    kap.listen(e2eCihazProvider, (_, _) {});
    final d = await _bekle(kap);
    expect(d.durum, E2eCihazDurumu.hata);
    expect(d.hata, isA<ApiOffline>());
    kapali = false;
    await kap.read(e2eCihazProvider.notifier).yenidenDene();
    expect(kap.read(e2eCihazProvider).durum, E2eCihazDurumu.hazir);
  });

  test('SabitOturumDurumu yardımcısı ile uyumlu', () {
    // yardimcilar.dart'taki sabit oturum E2E provider'ı bozmaz.
    final kap = ProviderContainer.test(
      overrides: [
        e2eEtkinProvider.overrideWithValue(false),
        oturumDurumuProvider.overrideWith(
          () => SabitOturumDurumu(OturumDurumu.acik),
        ),
      ],
    );
    expect(kap.read(e2eCihazProvider).durum, E2eCihazDurumu.desteklenmiyor);
  });
}
