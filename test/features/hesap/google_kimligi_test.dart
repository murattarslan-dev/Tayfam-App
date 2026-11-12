import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:tayfam/core/butunluk/butunluk_baglama.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';

/// `GoogleSignIn`'in sahtesi: `initialize`'a verilen nonce'ları kaydeder.
final class _SahteGoogleSignIn extends Fake implements GoogleSignIn {
  final List<String?> nonceler = [];
  int cikis = 0;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    nonceler.add(nonce);
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    return _SahteHesap();
  }

  @override
  Future<void> signOut() async {
    cikis++;
  }
}

final class _SahteHesap extends Fake implements GoogleSignInAccount {
  @override
  String? get displayName => 'Deniz';

  @override
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: 'sahte-id-token');
}

void main() {
  test('her giriş yeni nonce ve yeni bağlama değeri kullanır', () async {
    // Hata (#80): nonce süreç başına bir kez üretiliyordu; aynı süreçteki
    // ikinci giriş (ör. hesap silmedeki yeniden giriş) aynı nonce'u ve aynı
    // bütünlük bağlamasını kullanıyordu.
    final google = _SahteGoogleSignIn();
    final saglayici = GoogleSignInSaglayici(google: google);

    final ilk = await saglayici.girisYap();
    final ikinci = await saglayici.girisYap();

    expect(ilk, isNotNull);
    expect(ikinci, isNotNull);
    expect(ilk!.nonce, isNot(ikinci!.nonce));
    expect(girisBaglamasi(ilk.nonce), isNot(girisBaglamasi(ikinci.nonce)));
    // Google'a verilen nonce, aynı denemenin giriş isteğindeki nonce'tur.
    expect(google.nonceler, [ilk.nonce, ikinci.nonce]);
    expect(google.cikis, 2);
  });

  test('nonce verilen üreteçten gelir (Random.secure varsayılanı)', () async {
    var sayac = 0;
    final google = _SahteGoogleSignIn();
    final saglayici = GoogleSignInSaglayici(
      google: google,
      nonce: () => 'nonce-${sayac++}-0123456789abcdef',
    );
    expect((await saglayici.girisYap())!.nonce, 'nonce-0-0123456789abcdef');
    expect((await saglayici.girisYap())!.nonce, 'nonce-1-0123456789abcdef');
    expect(google.nonceler, [
      'nonce-0-0123456789abcdef',
      'nonce-1-0123456789abcdef',
    ]);
  });

  test('kimlik toString nonce ve token yazmaz', () async {
    final saglayici = GoogleSignInSaglayici(google: _SahteGoogleSignIn());
    final kimlik = await saglayici.girisYap();
    expect(kimlik.toString(), isNot(contains(kimlik!.nonce)));
    expect(kimlik.toString(), isNot(contains('sahte-id-token')));
  });
}
