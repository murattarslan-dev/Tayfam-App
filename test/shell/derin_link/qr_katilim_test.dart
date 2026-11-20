import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';
import 'package:tayfam/shell/derin_link/derin_link.dart';
import 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';
import 'package:tayfam/shell/derin_link/qr_katilim.dart';
import 'package:tayfam/shell/derin_link/qr_katilim_ekrani.dart';
import 'package:tayfam/shell/yonlendirme.dart';

import '../../features/etkinlik/sahteler.dart';
import '../../features/tayfa/sahteler.dart';
import '../../yardimcilar.dart';

/// Biçimi geçerli, açıkça sahte QR token'ı (22 karakter base64url).
const String _token = 'sahte_qr-sahte_qr-0123';

const String _katilYolu = '/v1/join-qr';

GelenAdres _ayristir(String adres) => gelenAdresiAyristir(Uri.parse(adres));

Map<String, Object?> _sonucJson({
  bool bekliyor = false,
  String? cevap = 'going',
  String? katilim,
}) => {
  'tayfa_id': ornekTayfaId,
  'event_id': ornekEtkinlikId,
  'pending': bekliyor,
  'rsvp': ?cevap,
  'attendance': ?katilim,
};

/// Token'ın hiçbir log satırına düşmediğini denetlemek için `debugPrint`
/// çıktısını toplar.
List<String> _loglariTopla() {
  final loglar = <String>[];
  final onceki = debugPrint;
  debugPrint = (mesaj, {wrapWidth}) {
    if (mesaj != null) loglar.add(mesaj);
  };
  addTearDown(() => debugPrint = onceki);
  return loglar;
}

ProviderContainer _kapsayici(SahteTayfaTasima tasima) {
  final c = ProviderContainer(
    overrides: [
      ...etkinlikOverridelari(tasima: tasima),
      qrKatilimDeposuProvider.overrideWithValue(QrKatilimDeposu(tasima)),
    ],
  );
  addTearDown(c.dispose);
  c.listen(qrKatilimProvider, (_, _) {});
  return c;
}

final class _SahteAyarlar implements AyarlarAcici {
  @override
  bool get destekleniyor => false;

  @override
  Future<bool> ac() async => false;
}

Widget _gorunum(QrKatilimDurumu durum) => QrKatilimGorunumu(
  durum: durum,
  ayarlar: _SahteAyarlar(),
  tekrarOkut: () {},
  tekrarDene: () {},
  kapat: () {},
  etkinligeGit: (_, _) {},
  kamera: durum is QrOkutuluyor ? const Placeholder() : null,
);

void main() {
  group('gelenAdresiAyristir: QR ile katılım linki', () {
    test('tam uygulama linki', () {
      expect(
        _ayristir('https://tayfam.app/q#$_token'),
        const QrKatilimLinki(_token),
      );
    });

    test('yalnızca yol + fragment (eski gömücü biçimi)', () {
      expect(_ayristir('/q#$_token'), const QrKatilimLinki(_token));
    });

    test('fragmentsiz iç /q adresi uygulamanın kendi ekranı', () {
      expect(_ayristir('/q'), isA<IcAdres>());
    });

    test('QR linki ayrıştırıcıdan geçer', () {
      expect(
        _ayristir(Adresler.qrKatilimLinki(_token)),
        const QrKatilimLinki(_token),
      );
      expect(Adresler.qrKatilimLinki(_token), 'https://tayfam.app/q#$_token');
    });

    for (final adres in [
      'http://tayfam.app/q#$_token',
      'https://tayfam.app.kotu.example/q#$_token',
      'https://kotu.example/q#$_token',
      'https://www.tayfam.app/q#$_token',
      'https://tayfam.app:8443/q#$_token',
      'https://biri@tayfam.app/q#$_token',
      'https://tayfam.app/qr#$_token',
      'https://tayfam.app/q/x#$_token',
      'https://tayfam.app/x/q#$_token',
      'https://tayfam.app/q?token=$_token',
      'https://tayfam.app/q?utm=x#$_token',
      'https://tayfam.app/q',
      'https://tayfam.app/q#',
      'https://tayfam.app/q#${_token}a',
      'https://tayfam.app/q#kısa',
      'https://tayfam.app/q#sahte_qr.sahte_qr.0123',
      'tayfam://q#$_token',
    ]) {
      test('reddedilir: $adres', () {
        expect(_ayristir(adres), isA<GecersizLink>());
      });
    }

    test('toString token içermez', () {
      expect(const QrKatilimLinki(_token).toString(), isNot(contains(_token)));
    });
  });

  group('qrMetnindenToken (kamerayla okunan metin)', () {
    test('yalnızca tam https://tayfam.app/q#<token> kabul edilir', () {
      expect(qrMetnindenToken('https://tayfam.app/q#$_token'), _token);
    });

    for (final metin in [
      '/q#$_token',
      'q#$_token',
      _token,
      'https://tayfam.app/davet#$_token',
      'https://tayfam.app/r/TYF-8K2M4Q',
      'https://kotu.example/q#$_token',
      'https://tayfam.app/q?x=1#$_token',
      'javascript:alert(1)',
      '',
      'http://[::1',
    ]) {
      test('reddedilir: "$metin"', () {
        expect(qrMetnindenToken(metin), isNull);
      });
    }
  });

  group('derin link kutusu', () {
    test('QR linki kutuya alınır, adres köke döner; token bir kez alınır', () {
      final kutu = DerinLinkKutusu();
      final konum = kutu.yakala(
        Uri.parse('https://tayfam.app/q#$_token'),
        oturumAcik: true,
      );
      expect(konum.toString(), Adresler.kok);
      expect(konum.toString(), isNot(contains(_token)));
      expect(kutu.qrBekliyor, isTrue);
      expect(kutu.qrTokeniAl(), _token);
      expect(kutu.qrBekliyor, isFalse);
      expect(kutu.qrTokeniAl(), isNull);
    });

    test('geçersiz QR linki kutuya alınmaz', () {
      final kutu = DerinLinkKutusu()
        ..yakala(Uri.parse('https://kotu.example/q#$_token'), oturumAcik: true);
      expect(kutu.qrBekliyor, isFalse);
    });

    test('iç /q adresi olduğu gibi kalır', () {
      final kutu = DerinLinkKutusu();
      expect(kutu.yakala(Uri.parse('/q'), oturumAcik: true).path, '/q');
      expect(kutu.qrBekliyor, isFalse);
    });
  });

  group('yönlendirme', () {
    test('oturum açıkken bekleyen QR /q ekranına götürür', () {
      String? yonlendirQr(String adres) => yonlendir(
        oturum: OturumDurumu.acik,
        aktifTayfaId: ornekTayfaId,
        konum: Uri.parse(adres),
        qrBekliyor: true,
      );
      expect(yonlendirQr('/'), qrYolu);
      expect(yonlendirQr(Adresler.tayfa(ornekTayfaId)), qrYolu);
      expect(yonlendirQr(qrYolu), isNull);
    });

    test('bekleyen davet QR\'dan önce gelir', () {
      expect(
        yonlendir(
          oturum: OturumDurumu.acik,
          aktifTayfaId: ornekTayfaId,
          konum: Uri.parse('/'),
          davetBekliyor: true,
          qrBekliyor: true,
        ),
        davetYolu,
      );
    });

    test('oturum yokken önce giriş; tanıtım hedefi /q (adreste token yok)',
        () {
      expect(
        yonlendir(
          oturum: OturumDurumu.girisYok,
          aktifTayfaId: null,
          konum: Uri.parse('/'),
          qrBekliyor: true,
        ),
        Adresler.giris,
      );
      final hedef = yonlendir(
        oturum: OturumDurumu.girisYok,
        aktifTayfaId: null,
        konum: Uri.parse('/'),
        qrBekliyor: true,
        tanitim: TanitimDurumu.gosterilmedi,
      );
      expect(hedef, Adresler.hosGeldinAdresi(qrYolu));
      expect(hedef, isNot(contains(_token)));
    });
  });

  group('QR ile katılım notifier\'ı', () {
    test('derin linkle gelen token hemen gönderilir, kutudan bırakılır; '
        'log ve durumda token yok', () async {
      final loglar = _loglariTopla();
      final durumlar = <String>[];
      final tasima = etkinlikTasimasi({
        'POST $_katilYolu': (_) => _sonucJson(),
      });
      final c = ProviderContainer(
        overrides: [
          ...etkinlikOverridelari(tasima: tasima),
          qrKatilimDeposuProvider.overrideWithValue(QrKatilimDeposu(tasima)),
        ],
      );
      addTearDown(c.dispose);
      final kutu = c.read(derinLinkKutusuProvider)
        ..yakala(Uri.parse('https://tayfam.app/q#$_token'), oturumAcik: true);
      c.listen(
        qrKatilimProvider,
        (_, sonraki) => durumlar.add(sonraki.toString()),
        fireImmediately: true,
      );
      expect(kutu.qrBekliyor, isFalse);
      expect(c.read(qrKatilimProvider), isA<QrKatiliniyor>());
      await pumpEventQueue();

      final istek = tasima.giden('POST', _katilYolu).single;
      expect(istek.govde, {'token': _token});
      final durum = c.read(qrKatilimProvider);
      expect(durum, isA<QrKatilimSonucu>());
      expect((durum as QrKatilimSonucu).sonuc.eventId, ornekEtkinlikId);
      expect(c.read(qrKatilimProvider.notifier).tekrarDenenebilir, isFalse);

      expect(loglar.where((l) => l.contains(_token)), isEmpty);
      expect(durumlar, hasLength(greaterThan(1)));
      expect(durumlar.where((d) => d.contains(_token)), isEmpty);
    });

    test('kutuda token yoksa kamera açılır; istek gitmez', () async {
      final tasima = etkinlikTasimasi();
      final c = _kapsayici(tasima);
      expect(c.read(qrKatilimProvider), isA<QrOkutuluyor>());
      await pumpEventQueue();
      expect(tasima.giden('POST', _katilYolu), isEmpty);
    });

    test('başka alan adının QR\'ı reddedilir; istek gitmez', () async {
      final tasima = etkinlikTasimasi();
      final c = _kapsayici(tasima);
      await c
          .read(qrKatilimProvider.notifier)
          .kodOkundu('https://kotu.example/q#$_token');
      expect(c.read(qrKatilimProvider), isA<QrTaninmadi>());
      expect(tasima.giden('POST', _katilYolu), isEmpty);

      c.read(qrKatilimProvider.notifier).tekrarOkut();
      expect(c.read(qrKatilimProvider), isA<QrOkutuluyor>());
    });

    test('okunan geçerli QR yalnızca gövdede gider', () async {
      final tasima = etkinlikTasimasi({
        'POST $_katilYolu': (_) => _sonucJson(bekliyor: true, cevap: null),
      });
      final c = _kapsayici(tasima);
      await c
          .read(qrKatilimProvider.notifier)
          .kodOkundu('https://tayfam.app/q#$_token');
      final istek = tasima.giden('POST', _katilYolu).single;
      expect(istek.govde, {'token': _token});
      expect(istek.yolParametreleri, isEmpty);
      final durum = c.read(qrKatilimProvider);
      expect((durum as QrKatilimSonucu).sonuc.pending, isTrue);
    });

    test('invalid-join-qr hata durumuna düşer; bağlantı hatası aynı '
        'token\'la yeniden denenir', () async {
      var deneme = 0;
      final tasima = etkinlikTasimasi({
        'POST $_katilYolu': (_) => switch (deneme++) {
          0 => const ApiOffline(),
          1 => _sonucJson(katilim: 'attended'),
          _ => const ApiProblem(
            status: 400,
            type: ProblemType.invalidJoinQr,
          ),
        },
      });
      final c = _kapsayici(tasima);
      final n = c.read(qrKatilimProvider.notifier);
      await n.kodOkundu('https://tayfam.app/q#$_token');
      expect(c.read(qrKatilimProvider), isA<QrKatilimHatasi>());
      expect(n.tekrarDenenebilir, isTrue);

      await n.tekrarDene();
      final sonuc = c.read(qrKatilimProvider) as QrKatilimSonucu;
      expect(sonuc.sonuc.attendance, AttendanceStatus.attended);
      expect(tasima.giden('POST', _katilYolu), hasLength(2));
      expect(
        tasima.giden('POST', _katilYolu).map((i) => i.govde),
        everyElement({'token': _token}),
      );

      n.tekrarOkut();
      await n.kodOkundu('https://tayfam.app/q#$_token');
      final hata = c.read(qrKatilimProvider) as QrKatilimHatasi;
      expect(
        (hata.hata as ApiProblem).type,
        ProblemType.invalidJoinQr,
      );
      expect(hata.toString(), isNot(contains(_token)));
    });
  });

  group('QR ile katılım ekranı', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('okutma (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await widgetAc(
          tester,
          _gorunum(const QrOkutuluyor()),
          themeMode: tema,
          dur: false,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.text(arbMetni('simdi_qr_okut_talimat_baslik')),
          findsOneWidget,
        );
        expect(find.text(arbMetni('simdi_qr_kamera_gizlilik')), findsOneWidget);
      });

      testWidgets('sonuçlar (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final durumlar = {
          QrKatilimSonucu(JoinQrResult.fromJson(_sonucJson())):
              'simdi_qr_katildin_baslik',
          QrKatilimSonucu(JoinQrResult.fromJson(_sonucJson(cevap: 'waitlist'))):
              'simdi_qr_bekleme_baslik',
          QrKatilimSonucu(
            JoinQrResult.fromJson(_sonucJson(katilim: 'attended')),
          ): 'simdi_qr_dogrulandi_baslik',
          QrKatilimSonucu(
            JoinQrResult.fromJson(_sonucJson(bekliyor: true, cevap: null)),
          ): 'simdi_qr_istek_baslik',
          const QrTaninmadi(): 'simdi_qr_taninmadi',
          const QrKatilimKameraIzniYok(): 'simdi_qr_kamera_izin_baslik',
          const QrKatilimHatasi(
            ApiProblem(status: 400, type: ProblemType.invalidJoinQr),
          ): 'hata_invalid_join_qr',
        };
        for (final MapEntry(key: durum, value: anahtar) in durumlar.entries) {
          await widgetAc(tester, _gorunum(durum), themeMode: tema);
          expect(tester.takeException(), isNull);
          expect(find.text(arbMetni(anahtar)), findsOneWidget, reason: anahtar);
        }
      });
    }

    testWidgets('katıldın: "Etkinliğe git" etkinliğin adresini verir', (
      tester,
    ) async {
      (String, String)? gidilen;
      await widgetAc(
        tester,
        QrKatilimGorunumu(
          durum: QrKatilimSonucu(JoinQrResult.fromJson(_sonucJson())),
          ayarlar: _SahteAyarlar(),
          tekrarOkut: () {},
          kapat: () {},
          etkinligeGit: (t, e) => gidilen = (t, e),
        ),
      );
      await tester.tap(find.text(arbMetni('simdi_qr_etkinlige_git')));
      expect(gidilen, (ornekTayfaId, ornekEtkinlikId));
    });

    testWidgets('bağlantı hatasında "Tekrar dene", QR hatasında yok', (
      tester,
    ) async {
      await widgetAc(tester, _gorunum(const QrKatilimHatasi(ApiOffline())));
      expect(find.text(arbMetni('simdi_qr_tekrar_dene')), findsOneWidget);
      await widgetAc(
        tester,
        _gorunum(
          const QrKatilimHatasi(
            ApiProblem(status: 400, type: ProblemType.invalidJoinQr),
          ),
        ),
      );
      expect(find.text(arbMetni('simdi_qr_tekrar_dene')), findsNothing);
      expect(find.text(arbMetni('simdi_qr_tekrar_okut')), findsOneWidget);
    });
  });
}
