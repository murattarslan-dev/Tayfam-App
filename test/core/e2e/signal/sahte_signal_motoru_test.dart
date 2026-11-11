import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

import 'sahte_signal_motoru.dart';

// SahteSignalMotoru'nun kendisi de arayüzün sözleşmesine uyar: E2E
// çekirdeği ve geçmiş testleri buna dayanır.
void main() {
  Uint8List u(String s) => Uint8List.fromList(utf8.encode(s));

  const a = SignalAdresi(ad: 'a', cihazNo: 1);
  const b = SignalAdresi(ad: 'b', cihazNo: 2);

  test('oturum kurma, tür 3 → tür 2, tekrar ve adres bağı', () async {
    final m = SahteSignalMotoru();
    final ka = await m.kimlikUret();
    final kb = await m.kimlikUret();
    final on = (await m.onAnahtarUret(100, 1)).single;
    final imzali = await m.imzaliOnAnahtarUret(kb.kayit, 7);
    final kyber = await m.kyberOnAnahtarUret(kb.kayit, 50);

    var oa = await m.paketIsle(
      kimlik: ka.kayit,
      kayitKimligi: ka.kayitKimligi,
      yerelAdres: a,
      adres: b,
      paket: OnAnahtarPaketi(
        kayitKimligi: kb.kayitKimligi,
        cihazNo: 2,
        onAnahtarId: on.id,
        onAnahtar: on.acikAnahtar,
        imzaliOnAnahtarId: imzali.id,
        imzaliOnAnahtar: imzali.acikAnahtar,
        imzaliOnAnahtarImzasi: imzali.imza,
        kimlikAnahtari: kb.acikAnahtar,
        kyberOnAnahtarId: kyber.id,
        kyberOnAnahtar: kyber.acikAnahtar,
        kyberOnAnahtarImzasi: kyber.imza,
      ),
    );

    final s1 = await m.sifrele(
      kimlik: ka.kayit,
      kayitKimligi: ka.kayitKimligi,
      yerelAdres: a,
      adres: b,
      oturum: oa,
      duz: u('merhaba'),
    );
    oa = s1.yeniOturum;
    expect(s1.tur, SignalMesajTuru.onAnahtar);
    final bilgi = await m.onAnahtarMesajiIncele(s1.sifreli);
    expect(bilgi.onAnahtarId, 100);
    expect(bilgi.gondericiKimligi, ka.acikAnahtar);

    final c1 = await m.coz(
      kimlik: kb.kayit,
      kayitKimligi: kb.kayitKimligi,
      yerelAdres: b,
      adres: a,
      tur: s1.tur,
      sifreli: s1.sifreli,
      onAnahtar: on.kayit,
      imzaliOnAnahtar: imzali.kayit,
      kyberOnAnahtarlari: [kyber.kayit],
    );
    expect(utf8.decode(c1.duz), 'merhaba');
    expect(c1.kullanilanOnAnahtarId, 100);
    expect(c1.kullanilanKyberId, 50);
    expect(c1.karsiKimlik, ka.acikAnahtar);
    final ob = c1.yeniOturum;

    await expectLater(
      m.coz(
        kimlik: kb.kayit,
        kayitKimligi: kb.kayitKimligi,
        yerelAdres: b,
        adres: a,
        tur: s1.tur,
        sifreli: s1.sifreli,
        oturum: ob,
        imzaliOnAnahtar: imzali.kayit,
        kyberOnAnahtarlari: [kyber.kayit],
      ),
      throwsA(
        isA<SignalHatasi>().having(
          (h) => h.tur,
          'tur',
          SignalHatasiTuru.eskiMesaj,
        ),
      ),
    );

    final r = await m.sifrele(
      kimlik: kb.kayit,
      kayitKimligi: kb.kayitKimligi,
      yerelAdres: b,
      adres: a,
      oturum: ob,
      duz: u('selam'),
    );
    expect(r.tur, SignalMesajTuru.signal);
    await expectLater(
      m.coz(
        kimlik: ka.kayit,
        kayitKimligi: ka.kayitKimligi,
        yerelAdres: const SignalAdresi(ad: 'baska', cihazNo: 1),
        adres: b,
        tur: r.tur,
        sifreli: r.sifreli,
        oturum: oa,
      ),
      throwsA(isA<SignalHatasi>()),
    );
    final cr = await m.coz(
      kimlik: ka.kayit,
      kayitKimligi: ka.kayitKimligi,
      yerelAdres: a,
      adres: b,
      tur: r.tur,
      sifreli: r.sifreli,
      oturum: oa,
    );
    expect(utf8.decode(cr.duz), 'selam');

    final s2 = await m.sifrele(
      kimlik: ka.kayit,
      kayitKimligi: ka.kayitKimligi,
      yerelAdres: a,
      adres: b,
      oturum: cr.yeniOturum,
      duz: u('x'),
    );
    expect(s2.tur, SignalMesajTuru.signal);
  });

  test('simetrik yapı taşları geri döner, bozulunca null', () async {
    final m = SahteSignalMotoru();
    final anahtar = Uint8List(32);
    final nonce = Uint8List(12);
    final aad = u('aad');
    final siv = await m.aesGcmSivSifrele(
      anahtar: anahtar,
      nonce: nonce,
      duz: u('gizli'),
      aad: aad,
    );
    expect(
      await m.aesGcmSivCoz(
        anahtar: anahtar,
        nonce: nonce,
        sifreli: siv,
        aad: aad,
      ),
      u('gizli'),
    );
    final bozuk = Uint8List.fromList(siv)..[0] ^= 1;
    expect(
      await m.aesGcmSivCoz(
        anahtar: anahtar,
        nonce: nonce,
        sifreli: bozuk,
        aad: aad,
      ),
      isNull,
    );
    final gcm = SahteSignalMotoru.sahteAes256GcmSifrele(
      anahtar: anahtar,
      nonce: nonce,
      duz: u('dışa aktarma'),
      aad: aad,
    );
    expect(
      await m.aes256GcmCoz(
        anahtar: anahtar,
        nonce: nonce,
        sifreliVeEtiket: gcm,
        aad: aad,
      ),
      u('dışa aktarma'),
    );
    final h1 = await m.hkdf(girdi: u('g'), bilgi: u('b'), uzunluk: 32);
    final h2 = await m.hkdf(girdi: u('g'), bilgi: u('b'), uzunluk: 32);
    expect(h1, h2);
    expect(h1, hasLength(32));
  });

  test('güvenlik kodu iki tarafta aynı; sonrakiHata bir kez fırlar', () async {
    final m = SahteSignalMotoru();
    final x = await m.guvenlikKodu(
      yerelKimlikAcik: u('A'),
      yerelTanimlayici: u('a'),
      karsiKimlikAcik: u('B'),
      karsiTanimlayici: u('b'),
    );
    final y = await m.guvenlikKodu(
      yerelKimlikAcik: u('B'),
      yerelTanimlayici: u('b'),
      karsiKimlikAcik: u('A'),
      karsiTanimlayici: u('a'),
    );
    expect(x, y);
    expect(x, hasLength(60));

    m.sonrakiHata = SignalHatasiTuru.oturumYok;
    await expectLater(m.kimlikUret(), throwsA(isA<SignalHatasi>()));
    await m.kimlikUret();
    expect(m.cagrilar.where((c) => c == 'kimlikUret'), hasLength(2));
  });
}
