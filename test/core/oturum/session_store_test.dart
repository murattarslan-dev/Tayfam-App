import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';

final DateTime _simdi = DateTime.utc(2026, 11, 10, 9);

Session _oturum(
  int n, {
  Duration erisimOmru = const Duration(minutes: 15),
  bool kayitBekliyor = false,
  bool? onayGerekli,
  DateTime? butunlukSonrasi,
}) => Session(
  userId: '00000000-0000-4000-8000-000000000001',
  sessionId: '00000000-0000-4000-8000-000000000002',
  accessToken: 'erisim-$n',
  accessExpiresAt: _simdi.add(erisimOmru),
  refreshToken: 'yenileme-$n',
  refreshExpiresAt: _simdi.add(const Duration(days: 90)),
  registrationPending: kayitBekliyor,
  consentRequired: onayGerekli,
  integrityCheckAfter: butunlukSonrasi,
);

/// Yazma ve silmeleri sayan bellek deposu.
final class _SayanDepo implements TokenDeposu {
  final BellekTokenDeposu _ic = BellekTokenDeposu();
  int yazma = 0;
  int silme = 0;

  /// Verilirse `oku` bu hatayı atar (çözülemeyen kayıt).
  Exception? okumaHatasi;

  @override
  Future<String?> oku() {
    final hata = okumaHatasi;
    if (hata != null) return Future.error(hata);
    return _ic.oku();
  }

  @override
  Future<void> yaz(String kayit) {
    yazma++;
    return _ic.yaz(kayit);
  }

  @override
  Future<void> sil() {
    silme++;
    return _ic.sil();
  }
}

/// Yenileme ucunun sahtesi: gönderilen token'ları kaydeder; yanıtı test
/// belirler.
final class _SahteSunucu {
  final List<String> gonderilen = [];

  /// Her yenilemede gönderilen bütünlük token'ı (yoksa `null`).
  final List<String?> kanitlar = [];
  int yoklama = 0;
  Object? yoklamaHatasi;
  Future<Session> Function(String token)? yanit;
  int _sayac = 1;

  Future<Session> yenile(String token, {String? butunlukTokeni}) {
    gonderilen.add(token);
    kanitlar.add(butunlukTokeni);
    final ozel = yanit;
    if (ozel != null) return ozel(token);
    _sayac++;
    return Future.value(_oturum(_sayac));
  }

  Future<void> yokla() async {
    yoklama++;
    final hata = yoklamaHatasi;
    if (hata != null) throw hata;
  }
}

final class _Kurulum {
  _Kurulum({DateTime? saat, YenilemeKaniti? kanit})
    : saat = saat ?? _simdi {
    oturum = SessionStore(
      depo: depo,
      yenileyici: sunucu.yenile,
      yoklayici: sunucu.yokla,
      kanit: kanit,
      saat: () => this.saat,
      bekle: (sure) async => beklemeler.add(sure),
      gunluk: gunluk.add,
    );
    oturum.olaylar.listen(olaylar.add);
    addTearDown(oturum.dispose);
  }

  DateTime saat;
  final _SayanDepo depo = _SayanDepo();
  final _SahteSunucu sunucu = _SahteSunucu();
  final List<Duration> beklemeler = [];
  final List<OturumOlayi> olaylar = [];
  final List<String> gunluk = [];
  late final SessionStore oturum;

  Future<String?> depodakiYenileme() async {
    final metin = await depo.oku();
    return metin == null ? null : KayitliOturum.coz(metin)?.yenilemeTokeni;
  }
}

/// Olay akışındaki teslimleri bekler.
Future<void> _akisBosalsin() => Future<void>.delayed(Duration.zero);

void main() {
  group('oturum yokken', () {
    test('durum kapalı; token istenince OturumYok', () async {
      final k = _Kurulum();
      expect(await k.oturum.durum(), const OturumKapali());
      await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
      expect(k.sunucu.gonderilen, isEmpty);
    });

    test('kapat bir şey yaymaz', () async {
      final k = _Kurulum();
      await k.oturum.kapat(OturumKapanisNedeni.cikis);
      await _akisBosalsin();
      expect(k.olaylar, isEmpty);
    });
  });

  group('kullanıcı kimliği (E2E, ADR-0020)', () {
    test('girişten gelir ve depoya yazılır', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      expect(
        await k.oturum.kullaniciKimligi(),
        '00000000-0000-4000-8000-000000000001',
      );
      final kayit = KayitliOturum.coz((await k.depo.oku())!);
      expect(kayit?.kullaniciId, '00000000-0000-4000-8000-000000000001');
      expect(k.sunucu.gonderilen, isEmpty);
    });

    test('eski kayıtta yoksa bir kez yenilenir', () async {
      final k = _Kurulum();
      await k.depo.yaz(
        KayitliOturum(
          erisimTokeni: 'erisim-1',
          erisimBitis: _simdi.add(const Duration(minutes: 15)),
          yenilemeTokeni: 'yenileme-1',
          yenilemeBitis: _simdi.add(const Duration(days: 90)),
          kayitBekliyor: false,
          onayGerekli: false,
        ).kodla(),
      );
      expect(
        await k.oturum.kullaniciKimligi(),
        '00000000-0000-4000-8000-000000000001',
      );
      expect(k.sunucu.gonderilen, ['yenileme-1']);
    });

    test('oturum yoksa OturumYok', () async {
      final k = _Kurulum();
      await expectLater(k.oturum.kullaniciKimligi(), throwsA(isA<OturumYok>()));
    });
  });

  group('oturum açma ve depo', () {
    test('giriş yanıtı depoya yazılır ve OturumAcik yayılır', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1, kayitBekliyor: true));
      await _akisBosalsin();

      expect(await k.depodakiYenileme(), 'yenileme-1');
      expect(k.olaylar, [
        const OturumAcik(kayitBekliyor: true, onayGerekli: false),
      ]);
      expect(await k.oturum.erisimTokeni(), 'erisim-1');
      expect(k.sunucu.gonderilen, isEmpty);
    });

    test('açılışta depodaki kayıt okunur', () async {
      final k = _Kurulum();
      await k.depo.yaz(
        KayitliOturum(
          erisimTokeni: 'erisim-7',
          erisimBitis: _uzakGelecek,
          yenilemeTokeni: 'yenileme-7',
          yenilemeBitis: _uzakGelecek,
          kayitBekliyor: false,
          onayGerekli: true,
        ).kodla(),
      );

      expect(
        await k.oturum.durum(),
        const OturumAcik(kayitBekliyor: false, onayGerekli: true),
      );
      expect(await k.oturum.erisimTokeni(), 'erisim-7');
    });

    test('bozuk kayıt silinir, oturum yok sayılır', () async {
      final k = _Kurulum();
      await k.depo.yaz('{bozuk');
      expect(await k.oturum.durum(), const OturumKapali());
      expect(await k.depo.oku(), isNull);
    });

    test('çözülemeyen kayıt silinir, giriş istenir (#12)', () async {
      final k = _Kurulum();
      await k.depo.yaz('cozulemeyen');
      k.depo.okumaHatasi = Exception('çözülemedi');

      expect(await k.oturum.durum(), const OturumKapali());
      await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
      expect(k.depo.silme, 1);
      expect(k.gunluk, ['oturum: depo okunamadı']);
      k.depo.okumaHatasi = null;
      expect(await k.depo.oku(), isNull);
      expect(k.sunucu.gonderilen, isEmpty);
    });

    test('yenileme süresi geçmiş kayıt silinir', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      final yeni = _Kurulum(saat: _simdi.add(const Duration(days: 91)));
      await yeni.depo.yaz((await k.depo.oku())!);

      expect(await yeni.oturum.durum(), const OturumKapali());
      expect(await yeni.depo.oku(), isNull);
      expect(yeni.sunucu.gonderilen, isEmpty);
    });

    test('kayıt token yazmayan toString taşır', () {
      final kayit = KayitliOturum(
        erisimTokeni: 'erisim-gizli',
        erisimBitis: _uzakGelecek,
        yenilemeTokeni: 'yenileme-gizli',
        yenilemeBitis: _uzakGelecek,
        kayitBekliyor: false,
        onayGerekli: false,
      );
      expect('$kayit', isNot(contains('gizli')));
    });
  });

  group('yenileme', () {
    test('bitişe 60 saniyeden az kalınca istekten önce yenilenir', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      k.saat = _simdi.add(const Duration(minutes: 14, seconds: 1));

      expect(await k.oturum.erisimTokeni(), 'erisim-2');
      expect(k.sunucu.gonderilen, ['yenileme-1']);
      expect(k.sunucu.yoklama, 1);
      expect(await k.depodakiYenileme(), 'yenileme-2');
    });

    test('bitişe 60 saniyeden çok varken yenilenmez', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      k.saat = _simdi.add(const Duration(minutes: 13, seconds: 59));

      expect(await k.oturum.erisimTokeni(), 'erisim-1');
      expect(k.sunucu.gonderilen, isEmpty);
    });

    test('eşzamanlı 5 istek tek yenileme yapar', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1, erisimOmru: Duration.zero));
      final cevap = Completer<Session>();
      k.sunucu.yanit = (_) => cevap.future;

      final tokenlar = Future.wait([
        for (var i = 0; i < 5; i++) k.oturum.erisimTokeni(),
      ]);
      await _akisBosalsin();
      expect(k.sunucu.gonderilen, ['yenileme-1']);

      cevap.complete(_oturum(2));
      expect(await tokenlar, List.filled(5, 'erisim-2'));
      expect(k.sunucu.gonderilen, ['yenileme-1']);
    });

    test('reddedilen token zaten yenilendiyse ikinci yenileme olmaz', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));

      final birinci = k.oturum.reddedildi('erisim-1');
      final ikinci = k.oturum.reddedildi('erisim-1');
      expect(await birinci, 'erisim-2');
      expect(await ikinci, 'erisim-2');
      // Yenileme bittikten sonra eski token'la gelen ret de yenilemez.
      expect(await k.oturum.reddedildi('erisim-1'), 'erisim-2');
      expect(k.sunucu.gonderilen, ['yenileme-1']);
    });

    test('yanıt beklenirken yenileme token\'ı depoda durmaz', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      String? gonderimAnindaDepo = 'okunmadı';
      k.sunucu.yanit = (_) async {
        gonderimAnindaDepo = await k.depo.oku();
        return _oturum(2);
      };

      await k.oturum.yenile();
      expect(gonderimAnindaDepo, isNull);
      expect(await k.depodakiYenileme(), 'yenileme-2');
    });

    test('bayraklar değişince olay yayılır, değişmezse yayılmaz', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1, kayitBekliyor: true));
      k.sunucu.yanit = (_) async => _oturum(2, kayitBekliyor: true);
      await k.oturum.yenile();
      k.sunucu.yanit = (_) async => _oturum(3);
      await k.oturum.yenile();
      await _akisBosalsin();

      expect(k.olaylar, [
        const OturumAcik(kayitBekliyor: true, onayGerekli: false),
        const OturumAcik(kayitBekliyor: false, onayGerekli: false),
      ]);
    });
  });

  group('yenileme hataları', () {
    test('invalid-refresh oturumu kapatır ve token\'ları siler', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      k.sunucu.yanit = (_) async =>
          throw const ApiProblem(type: ProblemType.invalidRefresh, status: 401);

      await expectLater(k.oturum.yenile(), throwsA(isA<OturumYok>()));
      await _akisBosalsin();

      expect(await k.depo.oku(), isNull);
      expect(
        k.olaylar.last,
        const OturumKapali(OturumKapanisNedeni.yenilemeReddedildi),
      );
      await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
    });

    test(
      'refresh-conflict oturumu kapatmaz; depodaki yeni token kullanılır',
      () async {
        final k = _Kurulum();
        await k.oturum.oturumAc(_oturum(1, erisimOmru: Duration.zero));
        k.sunucu.yanit = (_) async {
          // Başka bir süreç aynı anda yeniledi ve depoya yazdı.
          await k.depo.yaz(
            KayitliOturum(
              erisimTokeni: 'erisim-baska',
              erisimBitis: _uzakGelecek,
              yenilemeTokeni: 'yenileme-baska',
              yenilemeBitis: _uzakGelecek,
              kayitBekliyor: false,
              onayGerekli: false,
            ).kodla(),
          );
          throw const ApiProblem(
            type: ProblemType.refreshConflict,
            status: 409,
          );
        };

        expect(await k.oturum.erisimTokeni(), 'erisim-baska');
        await _akisBosalsin();

        expect(k.beklemeler, [const Duration(seconds: 1)]);
        expect(k.olaylar.whereType<OturumKapali>(), isEmpty);
        expect(k.sunucu.gonderilen, ['yenileme-1']);
        expect(await k.oturum.erisimTokeni(), 'erisim-baska');
      },
    );

    test('refresh-conflict sonrası depoda yeni token yoksa eskisi yeniden '
        'gönderilmez, oturum kapanır', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      k.sunucu.yanit = (_) async => throw const ApiProblem(
        type: ProblemType.refreshConflict,
        status: 409,
      );

      await expectLater(k.oturum.yenile(), throwsA(isA<OturumYok>()));
      expect(k.sunucu.gonderilen, ['yenileme-1']);
      expect(await k.depo.oku(), isNull);
    });

    test('bağlantı yoksa token harcanmaz, oturum açık kalır', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1, erisimOmru: Duration.zero));
      k.sunucu.yoklamaHatasi = const ApiOffline();

      await expectLater(k.oturum.erisimTokeni(), throwsA(isA<ApiOffline>()));
      expect(k.sunucu.gonderilen, isEmpty);
      expect(await k.depodakiYenileme(), 'yenileme-1');

      k.sunucu.yoklamaHatasi = null;
      expect(await k.oturum.erisimTokeni(), 'erisim-2');
      expect(k.sunucu.gonderilen, ['yenileme-1']);
    });

    test(
      'yanıt gelmeden bağlantı koparsa token bir daha gönderilmez',
      () async {
        final k = _Kurulum();
        await k.oturum.oturumAc(_oturum(1, erisimOmru: Duration.zero));
        k.sunucu.yanit = (_) async => throw const ApiTimeout();

        await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
        await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
        await _akisBosalsin();

        expect(k.sunucu.gonderilen, ['yenileme-1']);
        expect(await k.depo.oku(), isNull);
        expect(
          k.olaylar.last,
          const OturumKapali(OturumKapanisNedeni.yenilemeBasarisiz),
        );
      },
    );

    test(
      'yenileme sürerken kapanan oturum eski sonuçla geri açılmaz',
      () async {
        final k = _Kurulum();
        await k.oturum.oturumAc(_oturum(1));
        final cevap = Completer<Session>();
        k.sunucu.yanit = (_) => cevap.future;

        final yenileme = k.oturum.yenile();
        await _akisBosalsin();
        await k.oturum.kapat(OturumKapanisNedeni.cikis);
        cevap.complete(_oturum(2));

        await expectLater(yenileme, throwsA(isA<OturumYok>()));
        expect(await k.depo.oku(), isNull);
        await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
      },
    );
  });

  group('kapatma', () {
    test('token\'lar silinir, neden bir kez yayılır', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1));
      await k.oturum.kapat(OturumKapanisNedeni.cikis);
      await k.oturum.kapat(OturumKapanisNedeni.cikis);
      await _akisBosalsin();

      expect(await k.depo.oku(), isNull);
      expect(k.olaylar.whereType<OturumKapali>().toList(), [
        const OturumKapali(OturumKapanisNedeni.cikis),
      ]);
      expect(await k.oturum.durum(), const OturumKapali());
    });

    test('günlükte token yok', () async {
      final k = _Kurulum();
      await k.oturum.oturumAc(_oturum(1, erisimOmru: Duration.zero));
      k.sunucu.yanit = (_) async =>
          throw const ApiProblem(type: ProblemType.invalidRefresh, status: 401);
      await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));

      expect(k.gunluk, isNotEmpty);
      for (final satir in k.gunluk) {
        expect(satir, isNot(contains('erisim-')));
        expect(satir, isNot(contains('yenileme-')));
      }
    });
  });

  group('bütünlük kanıtı (istemci ADR-0023)', () {
    test('integrity_check_after depoya yazılır ve okunur', () async {
      final k = _Kurulum();
      final sonra = _simdi.add(const Duration(hours: 24));
      await k.oturum.oturumAc(_oturum(1, butunlukSonrasi: sonra));
      final kayit = KayitliOturum.coz((await k.depo.oku())!);
      expect(kayit?.butunlukSonrasi, sonra);
    });

    test('zamanı gelmeden yenilemede kanıt istenmez', () async {
      final istenen = <String>[];
      final k = _Kurulum(
        kanit: (token) async {
          istenen.add(token);
          return 'kanit';
        },
      );
      await k.oturum.oturumAc(
        _oturum(
          1,
          erisimOmru: Duration.zero,
          butunlukSonrasi: _simdi.add(const Duration(hours: 1)),
        ),
      );
      expect(await k.oturum.erisimTokeni(), 'erisim-2');
      expect(istenen, isEmpty);
      expect(k.sunucu.kanitlar, [null]);
    });

    test('alan yoksa (denetim kapalı) kanıt istenmez', () async {
      final istenen = <String>[];
      final k = _Kurulum(
        kanit: (token) async {
          istenen.add(token);
          return 'kanit';
        },
      );
      await k.oturum.oturumAc(_oturum(1, erisimOmru: Duration.zero));
      await k.oturum.erisimTokeni();
      expect(istenen, isEmpty);
      expect(k.sunucu.kanitlar, [null]);
    });

    test('zamanı geçtiyse yenileme kanıt taşır', () async {
      final istenen = <String>[];
      final k = _Kurulum(
        kanit: (token) async {
          istenen.add(token);
          return 'kanit';
        },
      );
      await k.oturum.oturumAc(
        _oturum(
          1,
          erisimOmru: Duration.zero,
          butunlukSonrasi: _simdi.subtract(const Duration(seconds: 1)),
        ),
      );
      expect(await k.oturum.erisimTokeni(), 'erisim-2');
      // Kanıt sağlayıcısına harcanmamış yenileme token'ı verilir (özeti
      // orada alınır); yoklamadan sonra, gönderimden önce.
      expect(istenen, ['yenileme-1']);
      expect(k.sunucu.yoklama, 1);
      expect(k.sunucu.kanitlar, ['kanit']);
    });

    test('kanıt alınamazsa yenileme kanıtsız gider', () async {
      final k = _Kurulum(kanit: (_) async => null);
      await k.oturum.oturumAc(
        _oturum(1, erisimOmru: Duration.zero, butunlukSonrasi: _simdi),
      );
      expect(await k.oturum.erisimTokeni(), 'erisim-2');
      expect(k.sunucu.kanitlar, [null]);
    });

    test('kanıt hatası yenilemeyi bozmaz', () async {
      final k = _Kurulum(kanit: (_) async => throw const FormatException());
      await k.oturum.oturumAc(
        _oturum(1, erisimOmru: Duration.zero, butunlukSonrasi: _simdi),
      );
      expect(await k.oturum.erisimTokeni(), 'erisim-2');
      expect(k.sunucu.kanitlar, [null]);
    });

    test('yeni yanıtın zamanı sonraki yenilemeyi belirler', () async {
      final istenen = <String>[];
      final k = _Kurulum(
        kanit: (token) async {
          istenen.add(token);
          return 'kanit';
        },
      );
      await k.oturum.oturumAc(
        _oturum(1, erisimOmru: Duration.zero, butunlukSonrasi: _simdi),
      );
      k.sunucu.yanit = (_) async => _oturum(
        2,
        erisimOmru: Duration.zero,
        butunlukSonrasi: _simdi.add(const Duration(hours: 24)),
      );
      await k.oturum.erisimTokeni();
      k.sunucu.yanit = (_) async => _oturum(3);
      await k.oturum.erisimTokeni();
      expect(istenen, ['yenileme-1']);
      expect(k.sunucu.kanitlar, ['kanit', null]);
    });

    test('kanıt beklenirken eşzamanlı istekler tek yenileme yapar', () async {
      final kapi = Completer<String?>();
      var istek = 0;
      final k = _Kurulum(
        kanit: (_) {
          istek++;
          return kapi.future;
        },
      );
      await k.oturum.oturumAc(
        _oturum(1, erisimOmru: Duration.zero, butunlukSonrasi: _simdi),
      );
      final tokenler = Future.wait([
        for (var i = 0; i < 4; i++) k.oturum.erisimTokeni(),
      ]);
      await _akisBosalsin();
      // Kanıt beklenirken yenileme token'ı henüz gönderilmedi.
      expect(k.sunucu.gonderilen, isEmpty);
      expect(await k.depodakiYenileme(), 'yenileme-1');
      kapi.complete('kanit');
      expect(await tokenler, List.filled(4, 'erisim-2'));
      expect(istek, 1);
      expect(k.sunucu.gonderilen, ['yenileme-1']);
      expect(k.sunucu.kanitlar, ['kanit']);
    });

    test('integrity-required: kanıtla bir kez yenilenir', () async {
      final k = _Kurulum(kanit: (_) async => 'kanit');
      await k.oturum.oturumAc(
        _oturum(1, butunlukSonrasi: _simdi.add(const Duration(hours: 5))),
      );
      final ilk = await k.oturum.erisimTokeni();
      expect(await k.oturum.butunlukGerekti(ilk), 'erisim-2');
      expect(k.sunucu.kanitlar, ['kanit']);
      // Kanıtla alınan token da reddedilirse bir daha yenilenmez.
      expect(await k.oturum.butunlukGerekti('erisim-2'), isNull);
      expect(k.sunucu.gonderilen, ['yenileme-1']);
    });

    test('integrity-required: token zaten değiştiyse yenilemez', () async {
      final k = _Kurulum(kanit: (_) async => 'kanit');
      await k.oturum.oturumAc(_oturum(1));
      expect(await k.oturum.butunlukGerekti('eski'), 'erisim-1');
      expect(k.sunucu.gonderilen, isEmpty);
    });

    test('integrity-required zorlaması sonraki yenilemeye taşmaz', () async {
      final k = _Kurulum(kanit: (_) async => 'kanit');
      await k.oturum.oturumAc(_oturum(1));
      await k.oturum.butunlukGerekti('erisim-1');
      await k.oturum.yenile();
      expect(k.sunucu.kanitlar, ['kanit', null]);
    });
  });
}

final DateTime _uzakGelecek = DateTime.utc(2100);
