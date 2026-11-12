import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/hesap/application/kayit_karsilamasi.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/shell/derin_link/davet_deposu.dart';
import 'package:tayfam/shell/derin_link/derin_link_rotalari.dart';
import 'package:tayfam/shell/derin_link/kayit_davet.dart';

import '../../features/tayfa/sahteler.dart';
import '../../yardimcilar.dart';

/// Biçimi geçerli, açıkça sahte davet değeri (gerçek değil).
const String _token = 'sahte-davet-sahte-davet';

Map<String, Object?> _onizlemeJson() => {
  'tayfa_id': ornekTayfaId,
  'name': 'Ege Klasikleri',
  'member_count': 24,
  'already_member': false,
};

class _SabitKarsilama extends KayitKarsilamasiNotifier {
  @override
  KayitKarsilamasi? build() => const KayitKarsilamasi(ad: 'Deniz');
}

/// Kayıt az önce bitmiş (hoş geldin bayrağı açık) ve davet linkiyle
/// gelinmiş uygulamayı açar.
Future<SahteTayfaTasima> _ac(
  WidgetTester tester, {
  required TayfaYaniti katilim,
  String? link = 'https://tayfam.app/davet#$_token',
  TayfaYaniti? liste,
}) async {
  ekranBoyutu(tester);
  if (link != null) {
    tester.platformDispatcher.defaultRouteNameTestValue = link;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }
  final tasima = SahteTayfaTasima();
  tasima.yanitlar
    ..['POST /v1/invite-previews'] = (_) =>
        _onizlemeJson()..['POST /v1/invite-joins'] = katilim;
  if (liste != null) tasima.yanitlar['GET /v1/tayfas'] = liste;
  await uygulamayiAc(
    tester,
    tayfa: tayfaOverridelari(tasima: tasima),
    overrides: <Override>[
      davetDeposuProvider.overrideWithValue(DavetDeposu(tasima)),
      kayitKarsilamasiProvider.overrideWith(_SabitKarsilama.new),
      kayitDavetProvider.overrideWith(KabukKayitDavetNotifier.new),
    ],
  );
  return tasima;
}

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

/// Hata iletisinde davet işleminin durumu (teşhis için).
String _durum(WidgetTester tester) =>
    tester.container().read(kayitDavetProvider).toString();

void main() {
  testWidgets('linksiz: hoş geldin ekranı iki seçenekle', (tester) async {
    final tasima = await _ac(
      tester,
      link: null,
      katilim: (_) => uyelikJson(ornekTayfaId),
    );

    expect(find.byType(KayitHosGeldinEkrani), findsOneWidget);
    expect(_metin('hesap_kayit_tayfa_kodum_var'), findsOneWidget);
    expect(tasima.giden('POST', '/v1/invite-joins'), isEmpty);
  });

  testWidgets('davetle: istek mevcut akışla gönderiliyor, onay bekliyor', (
    tester,
  ) async {
    final tasima = await _ac(
      tester,
      katilim: (_) => uyelikJson(ornekTayfaId, durum: 'pending'),
    );

    expect(find.byType(KayitHosGeldinEkrani), findsOneWidget);
    expect(find.byType(DavetEkrani), findsNothing);
    expect(
      find.text('Ege Klasikleri'),
      findsOneWidget,
      reason: _durum(tester),
    );
    expect(_metin('hesap_kayit_davet_onay_bekliyor'), findsOneWidget);
    final govdeler = [
      for (final i in tasima.giden('POST', '/v1/invite-joins')) i.govde,
    ];
    expect(govdeler, [
      {'token': _token},
    ]);
    expect(
      tester.container().read(derinLinkKutusuProvider).davetBekliyor,
      isFalse,
    );

    await tester.tap(_metin('hesap_kayit_tamam'));
    await tester.pumpAndSettle();
    expect(find.byType(KayitHosGeldinEkrani), findsNothing);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
  });

  testWidgets('açık tayfada "Tayfaya git" ana sayfayı açıyor', (tester) async {
    await _ac(
      tester,
      katilim: (_) => uyelikJson(ornekTayfaId),
      liste: (_) => listeJson([etkinJson(ornekTayfaId, ad: 'Ege Klasikleri')]),
    );

    expect(
      _metin('hesap_kayit_davet_etkin_aciklama'),
      findsOneWidget,
      reason: _durum(tester),
    );
    expect(_metin('hesap_kayit_davet_onay_bekliyor'), findsNothing);

    await tester.tap(_metin('hesap_kayit_tayfaya_git'));
    await tester.pumpAndSettle();
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
  });

  testWidgets('katılım hata verirse davet ekranına geçiliyor', (tester) async {
    await _ac(
      tester,
      katilim: (_) => const ApiProblem(type: ProblemType.internal, status: 500),
    );

    expect(_metin('hesap_kayit_davet_hata_aciklama'), findsOneWidget);
    // Davet kutuda kalıyor; ayrıntıyı davet ekranı gösterir.
    expect(
      tester.container().read(derinLinkKutusuProvider).davetBekliyor,
      isTrue,
    );

    await tester.tap(_metin('hesap_kayit_daveti_gor'));
    await tester.pumpAndSettle();
    expect(find.byType(DavetEkrani), findsOneWidget);
  });
}
