import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

import '../../features/hesap/sahteler.dart';
import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _acYolu = 'POST /v1/uploads';
const String _tamamlaYolu = 'POST /v1/uploads/{upload_id}/complete';
const String _var = '44444444-4444-4444-8444-444444444444';

/// Fotoğraf alanını taşıyan küçük form; seçilen kimliği gösterir.
class _Form extends StatefulWidget {
  const _Form({this.ilk});

  final String? ilk;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late String? deger = widget.ilk;
  final List<String?> degisimler = [];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FotografAlani(
          amac: UploadPurpose.cover,
          tayfaId: ornekTayfaId,
          deger: deger,
          etiket: arbMetni('medya_kapak_etiketi'),
          onDegisti: (yeni) => setState(() {
            degisimler.add(yeni);
            deger = yeni;
          }),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            KullaniciAvatari(ad: 'Deniz'),
            KullaniciAvatari(avatarUploadId: _var),
          ],
        ),
      ],
    ),
  );
}

Future<SahteTasima> _ac(
  WidgetTester tester, {
  ThemeMode mod = ThemeMode.light,
  String? ilk,
  Map<String, Object? Function()>? yanitlar,
  List<http.Request>? depo,
}) async {
  final tasima = SahteTasima(
    yanitlar ??
        {
          _acYolu: () => yuklemeAcildiJson(onizlemeBoyutu: 0, tamBoyutu: 0),
          _tamamlaYolu: () => {'upload': yuklemeJson()},
        },
  );
  final k = ornekJpeg();
  await widgetAc(
    tester,
    _Form(ilk: ilk),
    themeMode: mod,
    overrides: [
      oturumDurumuProvider.overrideWith(
        () => SabitOturumDurumu(OturumDurumu.acik),
      ),
      ...medyaOverridelari(
      tasima: tasima,
      secici: SahteSecici([k]),
      kodlayici: SahteKodlayici(
        kaynak: k,
        kaynakOlcusu: const JpegOlculeri(4032, 3024),
      ),
      depo: sahteDepo(depo ?? []),
        linkIsteyici: (idler) async => [
          for (final id in idler) MediaUrls.fromJson(medyaLinkiJson(id)),
        ],
      ),
    ],
  );
  return tasima;
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

Finder _etiketli(String etiket) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == etiket,
);

Future<void> _galeridenSec(WidgetTester tester) async {
  await tester.tap(_metin('medya_fotograf_ekle'));
  await tester.pumpAndSettle();
  await tester.tap(_metin('medya_kaynak_galeri'));
  await tester.pumpAndSettle();
}

void main() {
  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} tema, 2× yazı, 320 dp: taşma yok', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, mod: mod, ilk: _var);
      expect(tester.takeException(), isNull);
      expect(_metin('medya_fotograf_degistir'), findsOneWidget);
      expect(_metin('medya_fotograf_kaldir'), findsOneWidget);
      expect(_etiketli(arbMetni('medya_kapak_etiketi')), findsWidgets);
      expect(_etiketli('Deniz profil fotoğrafı'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });
  }

  testWidgets('tutmayan link boyutu: istek gitmez, hata görünür', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final depo = <http.Request>[];
    final tasima = await _ac(
      tester,
      depo: depo,
      yanitlar: {
        _acYolu: () => yuklemeAcildiJson(onizlemeBoyutu: 0, tamBoyutu: 0),
        _tamamlaYolu: () => {'upload': yuklemeJson()},
      },
    );
    await _galeridenSec(tester);

    final durum = tester.state<_FormState>(find.byType(_Form));
    // Content-Length 0 tutmaz: link güvenilmez sayılır, hata gösterilir.
    expect(durum.degisimler, isEmpty);
    expect(_metin('medya_hata_baglanti'), findsOneWidget);
    expect(depo, isEmpty);
    expect(tasima.sayi('POST', '/v1/uploads'), 1);
  });

  testWidgets('yükleme başarılı: kimlik forma geçer', (tester) async {
    ekranBoyutu(tester);
    final depo = <http.Request>[];
    final tasima = await _ac(tester, depo: depo, yanitlar: {});
    yuklemeYanitlariEkle(tasima);
    await _galeridenSec(tester);

    final durum = tester.state<_FormState>(find.byType(_Form));
    expect(durum.degisimler, [ornekUploadId]);
    expect(depo, hasLength(2));
    expect(_metin('medya_fotograf_degistir'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(_metin('medya_fotograf_kaldir'));
    await tester.pumpAndSettle();
    expect(durum.degisimler, [ornekUploadId, null]);
    expect(_metin('medya_fotograf_ekle'), findsOneWidget);
  });

  testWidgets('medya kapalı (503): anlaşılır mesaj', (tester) async {
    ekranBoyutu(tester);
    await _ac(
      tester,
      yanitlar: {_acYolu: () => problem(ProblemType.unavailable, 503)},
    );
    await _galeridenSec(tester);
    expect(_metin('medya_hata_kapali'), findsOneWidget);
    expect(_metin('medya_tekrar_dene'), findsOneWidget);
  });

  testWidgets('yükleme sınırı: ortak hata metni', (tester) async {
    ekranBoyutu(tester);
    await _ac(
      tester,
      yanitlar: {_acYolu: () => problem(ProblemType.uploadRateLimited, 429)},
    );
    await _galeridenSec(tester);
    expect(_metin('hata_upload_rate_limited'), findsOneWidget);
  });
}
