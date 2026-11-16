import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/moduller/kesfet_yuvalari.dart';
import 'package:tayfam/features/kesfet/kesfet.dart';
import 'package:tayfam/features/kesfet/presentation/guvenlik_paylasimlari_ekrani.dart';
import 'package:tayfam/features/kesfet/presentation/kesfet_ekrani.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart' show SahteTayfaTasima;
import 'sahteler.dart';

/// Etkinliğin başlangıcı (sahteler) ve kartların denendiği anlar.
final DateTime _bas = DateTime.utc(2026, 11, 16, 6);
final DateTime _once = _bas.subtract(const Duration(days: 1));
final DateTime _sirasinda = _bas.add(const Duration(hours: 1));
final DateTime _sonra = _bas.add(const Duration(hours: 5));

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: kesfetOverridelari(tasima),
);

Widget _kartlar(Event etkinlik, DateTime simdi) => Scaffold(
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: [EtkinlikGuvenlikKartlari(etkinlik: etkinlik, simdi: simdi)],
  ),
);

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

void main() {
  group('iki tema, 2× yazı, 320 dp', () {
    final ekranlar = <String, (Widget Function(), SahteTayfaTasima Function())>{
      'Keşfet akışı': (() => const KesfetEkrani(), kesfetTasimasi),
      'Keşfet boş': (
        () => const KesfetEkrani(),
        () => kesfetTasimasi({
          'GET $akisYolu': yanit({'items': <Object?>[]}),
        }),
      ),
      'Keşfet kapalı': (
        () => const KesfetEkrani(),
        () => kesfetTasimasi({'GET $akisYolu': yanit(ozellikKapaliHatasi)}),
      ),
      'paylaşımlar': (
        () => const GuvenlikPaylasimlariEkrani(),
        () => kesfetTasimasi({
          'GET $paylasimlarYolu': yanit({
            'shares': [
              paylasimJson('alert_sent'),
              paylasimJson('not_returned', id: mehmetId, ad: 'Mehmet'),
              paylasimJson('returned', id: elifId, ad: 'Elif'),
            ],
          }),
        }),
      ),
      'güvenlik kişisi seçili': (
        () => _kartlar(kesfetEtkinligi(), _sirasinda),
        () => kesfetTasimasi({'GET $guvenlikYolu': yanit(guvenlikJson())}),
      ),
      'geri bildirim': (
        () => _kartlar(
          kesfetEtkinligi(halkaAcik: true, katilim: 'attended'),
          _sonra,
        ),
        () => kesfetTasimasi({
          'GET $guvenlikYolu': yanit(
            guvenlikJson(alarm: '2026-11-16T10:00:00Z'),
          ),
          'GET $geriBildirimYolu': yanit({'answer': 'ok'}),
        }),
      ),
      'tayfa Keşfet bölümü': (
        () => const Scaffold(
          body: SingleChildScrollView(
            child: TayfaKesfetBolumu(tayfaId: kesfetTayfaId),
          ),
        ),
        () => kesfetTasimasi({
          'GET $tayfaKesfetYolu': yanit({
            'state': 'under_review',
            'enabled': true,
          }),
        }),
      ),
    };
    for (final MapEntry(key: ad, value: (ekran, tasima)) in ekranlar.entries) {
      for (final tema in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$ad (${tema.name}) taşmaz', (tester) async {
          ekranBoyutu(tester, genislik: 320);
          ikiKatYazi(tester);
          await _ac(tester, ekran(), tasima(), themeMode: tema);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Keşfet akışı', () {
    testWidgets('kart: arkadaşlar, etkinlik ve yalnızca olgular', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(tester, const KesfetEkrani(), kesfetTasimasi());
      expect(find.text('Ayşe ve 2 arkadaşın bu etkinlikte'), findsOneWidget);
      expect(find.text('Belgrad Ormanı sabah yürüyüşü'), findsOneWidget);
      expect(find.text('Pazar Yürüyüşçüleri'), findsOneWidget);
      expect(
        find.text('Kuruluş: Mart 2024 · 42 etkinlik · 318 doğrulanmış katılım'),
        findsOneWidget,
      );
      // İlke: güven vaadi yok.
      expect(find.textContaining('güvenilir'), findsNothing);
      expect(find.textContaining('onaylı'), findsNothing);
      expect(find.textContaining('kefil olmaz'), findsOneWidget);
    });

    testWidgets('tek arkadaş', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KesfetEkrani(),
        kesfetTasimasi({
          'GET $akisYolu': yanit({
            'items': [kesfetOgesiJson(arkadasSayisi: 1)],
          }),
        }),
      );
      expect(find.text('Ayşe bu etkinlikte'), findsOneWidget);
    });

    testWidgets('katılım onay sorar, sonra "İsteğin gönderildi"', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi({
        'POST $kesfetKatilYolu': yanit({
          'tayfa_id': kesfetTayfaId,
          'user_id': ayseId,
          'role': 'member',
          'status': 'pending',
        }),
      });
      await _ac(tester, const KesfetEkrani(), tasima);
      await _dokun(tester, find.text(arbMetni('kesfet_katil')));
      expect(find.text(arbMetni('kesfet_katil_baslik')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('kesfet_katil_onay')));
      expect(tasima.giden('POST', kesfetKatilYolu), hasLength(1));
      expect(find.text(arbMetni('kesfet_istek_gonderildi')), findsOneWidget);
      expect(find.text(arbMetni('kesfet_katil')), findsNothing);
    });

    testWidgets('bayrak kapalı: orta durum, kart yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KesfetEkrani(),
        kesfetTasimasi({'GET $akisYolu': yanit(ozellikKapaliHatasi)}),
      );
      expect(find.text(arbMetni('kesfet_kapali_baslik')), findsOneWidget);
      expect(find.text(arbMetni('kesfet_katil')), findsNothing);
    });
  });

  group('Keşfet girişi (bayrak)', () {
    Future<void> paneliAc(WidgetTester tester, Object? akis) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi({'GET $akisYolu': yanit(akis)});
      await widgetAc(
        tester,
        TayfaDegistirmePaneli(
          onTayfaSec: (_) {},
          onKodlaKatil: () {},
          onTayfaOlustur: () {},
          onKesfet: () {},
        ),
        tayfa: [
          ...kesfetOverridelari(tasima),
          kesfetGorunurProvider.overrideWith(
            (ref) => ref.watch(kesfetAcikProvider),
          ),
        ],
      );
    }

    testWidgets('açıkken panelde "Keşfet" satırı var', (tester) async {
      await paneliAc(tester, {'items': <Object?>[]});
      expect(find.text(arbMetni('kesfet_baslik')), findsOneWidget);
    });

    testWidgets('feature-disabled iken satır yok', (tester) async {
      await paneliAc(tester, ozellikKapaliHatasi);
      expect(find.text(arbMetni('kesfet_baslik')), findsNothing);
      expect(find.text(arbMetni('tayfa_olustur')), findsOneWidget);
    });

    testWidgets('kayıt yoksa (varsayılan) satır yok', (tester) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        TayfaDegistirmePaneli(
          onTayfaSec: (_) {},
          onKodlaKatil: () {},
          onTayfaOlustur: () {},
          onKesfet: () {},
        ),
        tayfa: kesfetOverridelari(kesfetTasimasi()),
      );
      expect(find.text(arbMetni('kesfet_baslik')), findsNothing);
    });
  });

  group('güvenlik kişisi kartı', () {
    testWidgets('seçilmemiş: açıklama ve "Güvenlik kişisi seç"', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(tester, _kartlar(kesfetEtkinligi(), _once), kesfetTasimasi());
      expect(find.text(arbMetni('guvenlik_kisisi_baslik')), findsOneWidget);
      expect(find.text(arbMetni('guvenlik_kisisi_sec')), findsOneWidget);
      // Başlamadan "Döndüm" yok.
      expect(find.text(arbMetni('guvenlik_dondum')), findsNothing);
    });

    testWidgets('seçme sayfası: arkadaş ve tolerans seçilir, PUT gider', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 900);
      final tasima = kesfetTasimasi({
        'PUT $guvenlikYolu': yanit(guvenlikJson(tolerans: 120)),
      });
      await _ac(tester, _kartlar(kesfetEtkinligi(), _once), tasima);
      await _dokun(tester, find.text(arbMetni('guvenlik_kisisi_sec')));
      // Yalnızca kabul edilmiş arkadaşlar.
      expect(find.text('Ayşe'), findsOneWidget);
      expect(find.text('Mehmet'), findsOneWidget);
      expect(find.text('Elif'), findsNothing);
      await _dokun(tester, find.text('Mehmet'));
      await _dokun(tester, find.text('2 saat'));
      await _dokun(tester, find.text(arbMetni('guvenlik_kaydet')));
      expect(tasima.giden('PUT', guvenlikYolu).single.govde, {
        'contact_user_id': mehmetId,
        'grace_minutes': 120,
      });
      expect(find.text('Güvenlik kişin: Ayşe'), findsOneWidget);
    });

    testWidgets('seçili ve başlamış: "Döndüm" POST eder', (tester) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi({
        'GET $guvenlikYolu': yanit(guvenlikJson()),
        'POST $dondumYolu': yanit(guvenlikJson(donus: '2026-11-16T07:30:00Z')),
      });
      await _ac(tester, _kartlar(kesfetEtkinligi(), _sirasinda), tasima);
      expect(find.text('Güvenlik kişin: Ayşe'), findsOneWidget);
      expect(find.text(arbMetni('guvenlik_kaldir')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('guvenlik_dondum')));
      expect(tasima.giden('POST', dondumYolu), hasLength(1));
      expect(find.textContaining('Döndüğünü işaretledin'), findsOneWidget);
      expect(find.text(arbMetni('guvenlik_dondum')), findsNothing);
    });

    testWidgets('kaldırma onay ister', (tester) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi({
        'GET $guvenlikYolu': yanit(guvenlikJson()),
        'DELETE $guvenlikYolu': yanit(null),
      });
      await _ac(tester, _kartlar(kesfetEtkinligi(), _once), tasima);
      await _dokun(tester, find.text(arbMetni('guvenlik_kaldir')));
      expect(find.text(arbMetni('guvenlik_kaldir_baslik')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('guvenlik_kaldir')).last);
      expect(tasima.giden('DELETE', guvenlikYolu), hasLength(1));
      expect(find.text(arbMetni('guvenlik_kisisi_sec')), findsOneWidget);
    });

    testWidgets('alarm gittiyse: haber verildi, "Döndüm" var, kaldırma yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(), _sonra),
        kesfetTasimasi({
          'GET $guvenlikYolu': yanit(
            guvenlikJson(alarm: '2026-11-16T10:00:00Z'),
          ),
        }),
      );
      expect(find.textContaining('haber verildi'), findsOneWidget);
      expect(find.text(arbMetni('guvenlik_dondum')), findsOneWidget);
      expect(find.text(arbMetni('guvenlik_kaldir')), findsNothing);
    });

    testWidgets('bayrak kapalı (feature-disabled): kart yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(), _once),
        kesfetTasimasi({'GET $guvenlikYolu': yanit(ozellikKapaliHatasi)}),
      );
      expect(find.text(arbMetni('guvenlik_kisisi_baslik')), findsNothing);
    });

    testWidgets('çevrim içi ya da "Geliyorum" yoksa istek bile atılmaz', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi();
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(mod: 'online'), _once),
        tasima,
      );
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(cevap: 'maybe'), _once),
        tasima,
      );
      expect(tasima.giden('GET', guvenlikYolu), isEmpty);
    });
  });

  group('"Her şey yolunda mıydı?"', () {
    testWidgets('serious: kaydedilir, tayfa şikâyeti önerilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi({
        'PUT $geriBildirimYolu': yanit({'answer': 'serious'}),
      });
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(halkaAcik: true, katilim: 'attended'), _sonra),
        tasima,
      );
      expect(find.text(arbMetni('geri_bildirim_soru')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('geri_bildirim_serious')));
      expect(tasima.giden('PUT', geriBildirimYolu).single.govde, {
        'answer': 'serious',
      });
      expect(
        find.text(arbMetni('geri_bildirim_sikayet_baslik')),
        findsOneWidget,
      );
    });

    testWidgets('halka açık değilse ya da bayrak kapalıysa kart yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(katilim: 'attended'), _sonra),
        kesfetTasimasi(),
      );
      expect(find.text(arbMetni('geri_bildirim_soru')), findsNothing);
      await _ac(
        tester,
        _kartlar(kesfetEtkinligi(halkaAcik: true, katilim: 'attended'), _sonra),
        kesfetTasimasi({'GET $geriBildirimYolu': yanit(ozellikKapaliHatasi)}),
      );
      expect(find.text(arbMetni('geri_bildirim_soru')), findsNothing);
    });
  });

  group('güvenlik kişisi olduğun etkinlikler', () {
    testWidgets('yalnızca kim, zaman ve durum', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const GuvenlikPaylasimlariEkrani(),
        kesfetTasimasi({
          'GET $paylasimlarYolu': yanit({
            'shares': [paylasimJson('alert_sent')],
          }),
        }),
      );
      expect(find.text('Ayşe'), findsOneWidget);
      expect(find.textContaining('Haber verildi'), findsOneWidget);
      expect(find.text(arbMetni('guvenlik_paylasim_ulas')), findsOneWidget);
    });

    testWidgets('bayrak kapalı: özellik kullanılamıyor', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const GuvenlikPaylasimlariEkrani(),
        kesfetTasimasi({'GET $paylasimlarYolu': yanit(ozellikKapaliHatasi)}),
      );
      expect(find.text(arbMetni('hata_feature_disabled')), findsOneWidget);
    });
  });

  group('tayfa ayarı', () {
    testWidgets('kapalı: açmak onay ister ve PUT gider', (tester) async {
      ekranBoyutu(tester);
      final tasima = kesfetTasimasi({
        'PUT $tayfaKesfetYolu': yanit({'state': 'pending', 'enabled': true}),
      });
      await _ac(
        tester,
        const Scaffold(body: TayfaKesfetBolumu(tayfaId: kesfetTayfaId)),
        tasima,
      );
      expect(find.text(arbMetni('yonetim_kesfet_off')), findsOneWidget);
      await _dokun(tester, find.byType(Switch));
      expect(find.text(arbMetni('yonetim_kesfet_ac_baslik')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('yonetim_kesfet_ac_onay')));
      expect(tasima.giden('PUT', tayfaKesfetYolu).single.govde, {
        'enabled': true,
      });
      expect(
        find.text(arbMetni('yonetim_kesfet_pending_etiket')),
        findsOneWidget,
      );
    });

    testWidgets('yönetici değilse (403) bölüm yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const Scaffold(body: TayfaKesfetBolumu(tayfaId: kesfetTayfaId)),
        kesfetTasimasi({
          'GET $tayfaKesfetYolu': yanit(
            problem(ProblemType.permissionDenied, status: 403),
          ),
        }),
      );
      expect(find.text(arbMetni('yonetim_kesfet_bolum')), findsNothing);
    });

    testWidgets('"onaylı" kelimesi hiçbir durumda yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const Scaffold(body: TayfaKesfetBolumu(tayfaId: kesfetTayfaId)),
        kesfetTasimasi({
          'GET $tayfaKesfetYolu': yanit({'state': 'listed', 'enabled': true}),
        }),
      );
      expect(
        find.text(arbMetni('yonetim_kesfet_listed_etiket')),
        findsOneWidget,
      );
      expect(find.textContaining('onay'), findsNothing);
    });
  });

  test('tolerans metni', () {
    // Ölçü olarak ARB biçimi: "30 dk", "1 saat".
    expect(arbMetni('guvenlik_sure_dakika'), '{sayi} dk');
    expect(arbMetni('guvenlik_sure_saat'), '{sayi} saat');
  });

  testWidgets('profil girişi yalnızca paylaşım varsa görünür', (tester) async {
    ekranBoyutu(tester);
    await _ac(
      tester,
      const Scaffold(body: GuvenlikPaylasimlariGirisi()),
      kesfetTasimasi(),
    );
    expect(find.text(arbMetni('guvenlik_paylasim_baslik')), findsNothing);
    await _ac(
      tester,
      Consumer(
        builder: (context, ref, _) =>
            const Scaffold(body: GuvenlikPaylasimlariGirisi()),
      ),
      kesfetTasimasi({
        'GET $paylasimlarYolu': yanit({
          'shares': [paylasimJson('not_returned')],
        }),
      }),
    );
    expect(find.text(arbMetni('guvenlik_paylasim_baslik')), findsOneWidget);
    expect(find.text('1 kişi'), findsOneWidget);
  });
}
