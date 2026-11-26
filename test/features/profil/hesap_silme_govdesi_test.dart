import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/profil/data/profil_deposu.dart';

import '../hesap/sahteler.dart';

void main() {
  test('hesap silme: Apple kodu yalnızca gövdede gider', () async {
    final tasima = SahteTasima({'DELETE /v1/me': () => null});
    await ProfilDeposu(tasima).hesabiSil(appleKodu: 'sahte-kod');
    expect(tasima.istekler.single.toString(), 'DELETE /v1/me');
    expect(tasima.istekler.single.govde, {
      'apple_authorization_code': 'sahte-kod',
    });
  });

  test('hesap silme: kod yoksa gövde gönderilmez', () async {
    final tasima = SahteTasima({'DELETE /v1/me': () => null});
    await ProfilDeposu(tasima).hesabiSil();
    expect(tasima.istekler.single.toString(), 'DELETE /v1/me');
    expect(tasima.istekler.single.govde, isNull);
  });
}
