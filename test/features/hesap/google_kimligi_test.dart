import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:tayfam/core/butunluk/butunluk_baglama.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';

/// `GoogleSignIn`'in sahtesi: `initialize`'a verilen nonce'ları kaydeder.
final class _SahteGoogleSignIn extends Fake implements GoogleSignIn {
  final List<String?> nonceler = [];
  final List<String?> istemciler = [];
  final List<String?> sunucuIstemciler = [];
  int cikis = 0;
  Object? cikisHatasi;

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    nonceler.add(nonce);
    istemciler.add(clientId);
    sunucuIstemciler.add(serverClientId);
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
    final h = cikisHatasi;
    if (h != null) throw h;
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

  test('istemci kimliği yalnızca iOS için verilir', () async {
    // google_sign_in_ios, clientId verilmezse serverClientId'yi de uygulamaz
    // (ADR-0034 §5); ID token'ın aud'u sunucu istemcisi olmazdı.
    final ios = _SahteGoogleSignIn();
    await GoogleSignInSaglayici(
      google: ios,
      platform: TargetPlatform.iOS,
    ).girisYap();
    expect(ios.istemciler, [googleIosIstemciKimligi]);
    expect(ios.sunucuIstemciler, [googleSunucuIstemciKimligi]);

    final android = _SahteGoogleSignIn();
    await GoogleSignInSaglayici(
      google: android,
      platform: TargetPlatform.android,
    ).girisYap();
    expect(android.istemciler, [null]);
    expect(android.sunucuIstemciler, [googleSunucuIstemciKimligi]);
  });

  test('Info.plist geri dönüş şeması iOS istemci kimliğinin tersidir', () {
    // İkisi ayrı dosyalarda durur; biri değişip öbürü unutulursa Google
    // girişi iOS'ta uygulamaya geri dönemez.
    const sonEk = '.apps.googleusercontent.com';
    expect(googleIosIstemciKimligi.endsWith(sonEk), isTrue);
    final govde = googleIosIstemciKimligi.substring(
      0,
      googleIosIstemciKimligi.length - sonEk.length,
    );
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      plist.contains('<string>com.googleusercontent.apps.$govde</string>'),
      isTrue,
    );
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

  test('çıkış yalnızca Google çıkışını çağırır; hata dışarı taşmaz', () async {
    final google = _SahteGoogleSignIn();
    final saglayici = GoogleSignInSaglayici(google: google);

    await saglayici.cikisYap();
    expect(google.cikis, 1);
    expect(google.nonceler, isEmpty);

    google.cikisHatasi = const GoogleSignInException(
      code: GoogleSignInExceptionCode.unknownError,
    );
    await saglayici.cikisYap();
    expect(google.cikis, 2);
  });
}
