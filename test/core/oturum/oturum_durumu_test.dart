import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';

Session _oturum({bool kayitBekliyor = false, bool? onayGerekli}) {
  final simdi = DateTime.now().toUtc();
  return Session(
    userId: '00000000-0000-4000-8000-000000000001',
    sessionId: '00000000-0000-4000-8000-000000000002',
    accessToken: 'erisim',
    accessExpiresAt: simdi.add(const Duration(minutes: 15)),
    refreshToken: 'yenileme',
    refreshExpiresAt: simdi.add(const Duration(days: 90)),
    registrationPending: kayitBekliyor,
    consentRequired: onayGerekli,
  );
}

SessionStore _store(TokenDeposu depo) => SessionStore(
  depo: depo,
  yenileyici: (_, {butunlukTokeni}) async => _oturum(),
  yoklayici: () async {},
);

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

void main() {
  test('SessionStore olayı yönlendirme durumuna çevriliyor', () {
    expect(oturumDurumunaCevir(const OturumKapali()), OturumDurumu.girisYok);
    expect(
      oturumDurumunaCevir(
        const OturumKapali(OturumKapanisNedeni.sunucuSonlandirdi),
      ),
      OturumDurumu.girisYok,
    );
    expect(
      oturumDurumunaCevir(
        const OturumAcik(kayitBekliyor: true, onayGerekli: true),
      ),
      OturumDurumu.kayitBekliyor,
    );
    expect(
      oturumDurumunaCevir(
        const OturumAcik(kayitBekliyor: false, onayGerekli: true),
      ),
      OturumDurumu.onayGerekli,
    );
    expect(
      oturumDurumunaCevir(
        const OturumAcik(kayitBekliyor: false, onayGerekli: false),
      ),
      OturumDurumu.acik,
    );
  });

  group('oturumDurumuProvider', () {
    test('yükleniyor ile başlıyor; kayıt yoksa giriş', () async {
      final store = _store(BellekTokenDeposu());
      final kap = ProviderContainer.test(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
      );
      expect(kap.read(oturumDurumuProvider), OturumDurumu.yukleniyor);
      await _bekle();
      expect(kap.read(oturumDurumuProvider), OturumDurumu.girisYok);
    });

    test('depodaki kayda göre açılıyor', () async {
      final depo = BellekTokenDeposu();
      await _store(depo).oturumAc(_oturum(onayGerekli: true));

      final kap = ProviderContainer.test(
        overrides: [sessionStoreProvider.overrideWithValue(_store(depo))],
      );
      kap.read(oturumDurumuProvider);
      await _bekle();
      expect(kap.read(oturumDurumuProvider), OturumDurumu.onayGerekli);
    });

    test('giriş, yenileme ve kapanış olaylarını izliyor', () async {
      final store = _store(BellekTokenDeposu());
      final kap = ProviderContainer.test(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
      );
      kap.read(oturumDurumuProvider);
      await _bekle();

      await store.oturumAc(_oturum(kayitBekliyor: true));
      await _bekle();
      expect(kap.read(oturumDurumuProvider), OturumDurumu.kayitBekliyor);

      // Kayıt sonrası yenileme: bayraklar temizlenir.
      await store.yenile();
      await _bekle();
      expect(kap.read(oturumDurumuProvider), OturumDurumu.acik);

      await store.kapat(OturumKapanisNedeni.cikis);
      await _bekle();
      expect(kap.read(oturumDurumuProvider), OturumDurumu.girisYok);
    });
  });
}
