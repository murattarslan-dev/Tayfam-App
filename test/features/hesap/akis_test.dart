import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

/// Uygulamanın tamamıyla açılış → giriş → kayıt akışı
/// (ADR-0012 §1–§3). Oturum durumu gerçek `SessionStore`'dan (bellek
/// deposu) beslenir; Google ve API sahtedir.
void main() {
  testWidgets('kayıt yoksa açılıştan girişe', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(
      tester,
      oturum: null,
      overrides: hesapOverridelari(
        tasima: SahteTasima(),
        oturum: SahteOturum(),
      ),
    );

    expect(find.byType(GirisEkrani), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('girişten sonra kayıt ekranı', (tester) async {
    ekranBoyutu(tester);
    final tasima = SahteTasima({
      'POST /v1/auth/sign-in': () => oturum(kayitBekliyor: true).toJson(),
      'GET /v1/registration/requirements': surumGovdesi,
      'POST /v1/registration': () => null,
    });
    await uygulamayiAc(
      tester,
      oturum: null,
      overrides: hesapOverridelari(
        tasima: tasima,
        oturum: SahteOturum(),
        google: SahteGoogle(sonuc: ornekKimlik),
      ),
    );

    await tester.tap(find.text(arbMetni('hesap_google_ile_devam')));
    await tester.pumpAndSettle();
    expect(find.byType(KayitEkrani), findsOneWidget);

    // Ad Google adıyla dolu.
    expect(find.widgetWithText(TextField, 'Deniz Örnek'), findsOneWidget);
  });

  testWidgets('güncelleme gerekiyorsa yalnızca güncelleme ekranı', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(
      tester,
      surumDenetleyici: SahteSurumDenetleyici(gerekli: true),
    );

    expect(find.byType(GuncellemeEkrani), findsOneWidget);
    expect(find.byType(KarsilamaEkrani), findsNothing);

    yonlendiriciyiAl(tester).go('/profil');
    await tester.pumpAndSettle();
    expect(find.byType(GuncellemeEkrani), findsOneWidget);
  });
}
