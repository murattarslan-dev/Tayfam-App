import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart' hide Notification;
import 'package:tayfam/core/api/gen/models.dart' as api show Notification;
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/imzali_indirme.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/profil/application/veri_disa_aktarma_notifier.dart';
import 'package:tayfam/features/profil/application/yeniden_giris.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_bicimi.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_cozucu.dart';

import 'disa_aktarma_sahteleri.dart';

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

Matcher _hata(DisaAktarmaHataTuru tur) =>
    isA<DisaAktarmaHatasi>().having((h) => h.tur, 'tur', tur);

Matcher _problem(ProblemType tur) =>
    isA<ApiProblem>().having((p) => p.type, 'type', tur);

final class _Kurulum {
  _Kurulum({
    Map<String, Object? Function()> yanitlar = const {},
    SahteGoogle? google,
    SahteIndirici? indirici,
  }) : tasima = SahteTasima(
         profilYanitlari({
           taleplerYolu: () => listeJson([talepJson()]),
           talepAcYolu: () => talepJson(durum: 'pending'),
           indirmeYolu: indirmeJson,
           ...yanitlar,
         }),
       ),
       google = google ?? SahteGoogle(sonuc: ornekKimlik),
       indirici = indirici ?? SahteIndirici() {
    kap = ProviderContainer.test(
      overrides: disaAktarmaOverridelari(
        tasima: tasima,
        oturum: oturum,
        google: this.google,
        indirici: this.indirici,
        paylasici: paylasici,
        motor: motor,
        zamanlayici: zamanlayici,
      ),
    );
  }

  final SahteTasima tasima;
  final SahteGoogle google;
  final SahteIndirici indirici;
  final SahteOturum oturum = _yenilenenOturum();
  final SahteZipPaylasici paylasici = SahteZipPaylasici();
  final SahteSignalMotoru motor = SahteSignalMotoru();
  final SahteZamanlayici zamanlayici = SahteZamanlayici();
  late final ProviderContainer kap;

  Future<void> oturumuAc() => oturum.store.oturumAc(_ornekOturum());

  DisaAktarmaEylemNotifier get eylem =>
      kap.read(disaAktarmaEylemProvider.notifier);

  DisaAktarmaEylemDurumu get durum => kap.read(disaAktarmaEylemProvider);

  /// Eylem provider'ını açık tutar (ekran gibi).
  void dinle() {
    final sub = kap.listen(disaAktarmaEylemProvider, (_, _) {});
    addTearDown(sub.close);
  }

  List<String> get yollar => [
    for (final i in tasima.istekler) '${i.method} ${i.yol}',
  ];
}

/// Her yenilemede yeni yenileme token'ı veren sahte oturum (aynı token
/// ikinci kez gönderilirse `SessionStore` oturumu kapatır).
SahteOturum _yenilenenOturum() {
  var n = 1;
  return SahteOturum(yenileme: () => oturum(n: ++n));
}

/// İlk girişin oturumu (sahteler: `oturum(n: 1)`).
Session _ornekOturum() => oturum();

DataExport _talep({String id = ornekTalepId}) =>
    DataExport.fromJson(talepJson(id: id));

void main() {
  group('biçim', () {
    test('geçerli dosya parçalanıyor', () {
      final dosya = sifreliDosya();
      final p = DisaAktarmaBicimi.ayristir(dosya);
      expect(p.nonce, sahteNonce());
      expect(p.sifreliVeEtiket.length, dosya.length - 13);
    });

    test('yanlış sürüm baytı reddediliyor', () {
      expect(
        () => DisaAktarmaBicimi.ayristir(sifreliDosya(surum: 0x02)),
        throwsA(_hata(DisaAktarmaHataTuru.bicim)),
      );
    });

    test('başlık + etiketten kısa dosya reddediliyor', () {
      for (final uzunluk in [0, 1, 13, 28, 29]) {
        final dosya = Uint8List(uzunluk);
        if (uzunluk > 0) dosya[0] = 0x01;
        expect(
          () => DisaAktarmaBicimi.ayristir(dosya),
          throwsA(_hata(DisaAktarmaHataTuru.bicim)),
          reason: '$uzunluk bayt',
        );
      }
    });

    test('16 MiB + 29 bayttan büyük dosya reddediliyor', () {
      final dosya = Uint8List(DisaAktarmaBicimi.dosyaEnCok + 1)..[0] = 1;
      expect(
        () => DisaAktarmaBicimi.ayristir(dosya),
        throwsA(_hata(DisaAktarmaHataTuru.bicim)),
      );
      expect(DisaAktarmaBicimi.dosyaEnCok, 16 * 1024 * 1024 + 29);
    });

    test('AAD: ASCII önek + UUID\'nin 16 baytı', () {
      final aad = DisaAktarmaBicimi.aad(ornekTalepId);
      expect(aad.length, 22 + 16);
      expect(ascii.decode(aad.sublist(0, 22)), 'tayfam/data-export/v1/');
      expect(aad.sublist(22, 26), [0x01, 0x90, 0xf3, 0xa2]);
      expect(aad.last, 0xab);
      // Büyük harfli yazım aynı baytları verir.
      expect(DisaAktarmaBicimi.aad(ornekTalepId.toUpperCase()), aad);
      expect(
        () => DisaAktarmaBicimi.aad('talep-1'),
        throwsA(_hata(DisaAktarmaHataTuru.bicim)),
      );
    });

    test('anahtar 32 bayt değilse reddediliyor', () {
      expect(DisaAktarmaBicimi.anahtar(base64.encode(sahteAnahtar())), [
        ...sahteAnahtar(),
      ]);
      for (final yanlis in [
        base64.encode(List.filled(16, 1)),
        base64.encode(List.filled(33, 1)),
        'base64-değil!',
      ]) {
        expect(
          () => DisaAktarmaBicimi.anahtar(yanlis),
          throwsA(_hata(DisaAktarmaHataTuru.bicim)),
        );
      }
    });

    test('zip imzası', () {
      expect(DisaAktarmaBicimi.zipMi(ornekZip()), isTrue);
      final json = Uint8List.fromList('{}'.codeUnits);
      expect(DisaAktarmaBicimi.zipMi(json), isFalse);
      expect(DisaAktarmaBicimi.zipMi(Uint8List(40)), isFalse);
    });

    test('dosya adı tarih taşır, kimlik taşımaz', () {
      final ad = disaAktarmaDosyaAdi(_talep());
      expect(ad, 'tayfam-verilerim-2026-11-10.zip');
      expect(ad, isNot(contains('0190')));
    });
  });

  group('Signal köprüsüyle çözme', () {
    Future<Uint8List?> coz(Uint8List dosya, String talepId, {Uint8List? a}) {
      final p = DisaAktarmaBicimi.ayristir(dosya);
      return SignalDisaAktarmaCozucu(SahteSignalMotoru()).coz(
        anahtar: a ?? sahteAnahtar(),
        nonce: p.nonce,
        sifreliVeEtiket: p.sifreliVeEtiket,
        aad: DisaAktarmaBicimi.aad(talepId),
      );
    }

    test('doğru anahtar ve AAD ile çözülüyor', () async {
      expect(await coz(sifreliDosya(), ornekTalepId), ornekZip());
    });

    test('yanlış AAD (başka talep) ile çözülmüyor', () async {
      expect(await coz(sifreliDosya(), eskiTalepId), isNull);
    });

    test('yanlış anahtarla çözülmüyor', () async {
      final baska = Uint8List.fromList(List.filled(32, 9));
      expect(await coz(sifreliDosya(), ornekTalepId, a: baska), isNull);
    });

    test('köprü hatası doğrulanamamış sayılıyor', () async {
      final motor = SahteSignalMotoru()
        ..sonrakiHata = SignalHatasiTuru.values.first;
      final p = DisaAktarmaBicimi.ayristir(sifreliDosya());
      final sonuc = await SignalDisaAktarmaCozucu(motor).coz(
        anahtar: sahteAnahtar(),
        nonce: p.nonce,
        sifreliVeEtiket: p.sifreliVeEtiket,
        aad: DisaAktarmaBicimi.aad(ornekTalepId),
      );
      expect(sonuc, isNull);
    });

    test('köprü yokken "desteklenmiyor"', () async {
      await expectLater(
        const OlmayanDisaAktarmaCozucu().coz(
          anahtar: sahteAnahtar(),
          nonce: sahteNonce(),
          sifreliVeEtiket: Uint8List(16),
          aad: Uint8List(38),
        ),
        throwsA(_hata(DisaAktarmaHataTuru.desteklenmiyor)),
      );
    });
  });

  group('liste', () {
    test('talepler ve bir sonraki talep zamanı okunuyor', () async {
      final k = _Kurulum(
        yanitlar: {
          taleplerYolu: () =>
              listeJson([talepJson()], sonraki: '2026-12-10T09:00:00Z'),
        },
      );
      final sub = k.kap.listen(disaAktarmaListesiProvider, (_, _) {});
      addTearDown(sub.close);

      final liste = await k.kap.read(disaAktarmaListesiProvider.future);
      expect(liste.talepler.single.status, DataExportStatus.ready);
      expect(liste.sonrakiTalep, DateTime.utc(2026, 12, 10, 9));
      expect(liste.suruyor, isFalse);
      expect(k.zamanlayici.etkin, isEmpty);
    });

    test('süren talep varken yoklanıyor, hazır olunca duruyor', () async {
      var durum = 'processing';
      final k = _Kurulum(
        yanitlar: {
          taleplerYolu: () => listeJson([talepJson(durum: durum)]),
        },
      );
      final sub = k.kap.listen(disaAktarmaListesiProvider, (_, _) {});
      addTearDown(sub.close);

      final ilk = await k.kap.read(disaAktarmaListesiProvider.future);
      expect(ilk.suruyor, isTrue);
      expect(k.zamanlayici.etkin.single.sure, disaAktarmaYoklamaAraligi);

      durum = 'ready';
      k.zamanlayici.calistir();
      await _bekle();
      expect(k.tasima.sayi('GET', '/v1/me/data-exports'), 2);
      expect(k.kap.read(disaAktarmaListesiProvider).value?.suruyor, isFalse);
      expect(k.zamanlayici.etkin, isEmpty);
    });

    test('yoklama hatasında eski liste kalıyor, yoklama sürüyor', () async {
      var hata = false;
      final k = _Kurulum(
        yanitlar: {
          taleplerYolu: () => hata
              ? const ApiOffline()
              : listeJson([talepJson(durum: 'pending')]),
        },
      );
      final sub = k.kap.listen(disaAktarmaListesiProvider, (_, _) {});
      addTearDown(sub.close);
      await k.kap.read(disaAktarmaListesiProvider.future);

      hata = true;
      k.zamanlayici.calistir();
      await _bekle();
      expect(k.kap.read(disaAktarmaListesiProvider).hasError, isFalse);
      expect(k.kap.read(disaAktarmaListesiProvider).value?.suruyor, isTrue);
      expect(k.zamanlayici.etkin, hasLength(1));
    });

    test('ekran kapanınca yoklama duruyor', () async {
      final k = _Kurulum(
        yanitlar: {
          taleplerYolu: () => listeJson([talepJson(durum: 'processing')]),
        },
      );
      final sub = k.kap.listen(disaAktarmaListesiProvider, (_, _) {});
      await k.kap.read(disaAktarmaListesiProvider.future);
      expect(k.zamanlayici.etkin, hasLength(1));

      sub.close();
      await _bekle();
      expect(k.zamanlayici.etkin, isEmpty);
    });
  });

  group('talep', () {
    test('önce token yenileniyor, sonra POST client_request_id ile', () async {
      final k = _Kurulum();
      await k.oturumuAc();
      k.dinle();

      await k.eylem.talepAc();

      expect(k.oturum.yenilemeSayisi, 1);
      expect(k.yollar, [talepAcYolu]);
      final govde = k.tasima.istekler.single.govde! as Map<String, Object?>;
      expect(govde.keys, ['client_request_id']);
      expect(govde['client_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(k.durum, const DisaAktarmaEylemDurumu());
    });

    test('bağlantı hatasında tekrar aynı client_request_id gidiyor', () async {
      var cevrimdisi = true;
      final k = _Kurulum(
        yanitlar: {
          talepAcYolu: () =>
              cevrimdisi ? const ApiOffline() : talepJson(durum: 'pending'),
        },
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.talepAc();
      expect(k.durum.hata, isA<ApiOffline>());

      cevrimdisi = false;
      await k.eylem.talepAc();
      expect(k.durum.hata, isNull);

      final kimlikler = [
        for (final i in k.tasima.istekler)
          if (i.yol == '/v1/me/data-exports')
            (i.govde! as Map<String, Object?>)['client_request_id'],
      ];
      expect(kimlikler, hasLength(2));
      expect(kimlikler.first, kimlikler.last);

      // Sonuçlanan talepten sonra yeni iş yeni kimlik alır.
      await k.eylem.talepAc();
      final son = k.tasima.istekler.last.govde! as Map<String, Object?>;
      expect(son['client_request_id'], isNot(kimlikler.first));
    });

    for (final (tur, durum) in [
      (ProblemType.dataExportLimit, 429),
      (ProblemType.dataExportInProgress, 409),
      (ProblemType.unavailable, 503),
    ]) {
      test('${tur.name} hatası gösteriliyor', () async {
        final k = _Kurulum(yanitlar: {talepAcYolu: () => problem(tur, durum)});
        await k.oturumuAc();
        k.dinle();

        await k.eylem.talepAc();

        expect(k.durum.hata, _problem(tur));
        expect(k.durum.suruyor, isFalse);
      });
    }
  });

  group('indirme', () {
    test('yeniden giriş gerekmezse doğrudan indirilip paylaşılıyor', () async {
      final k = _Kurulum();
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.google.cagri, 0);
      expect(k.yollar, [indirmeYolu]);
      expect(k.indirici.adresler.single, Uri.parse(sahteLink));
      expect(k.indirici.beklenenler.single, sifreliDosya().length);
      expect(k.paylasici.kopyalar.single, ornekZip());
      expect(k.paylasici.adlar.single, 'tayfam-verilerim-2026-11-10.zip');
      // İçerik tamponu paylaşımdan sonra sıfırlanıyor.
      expect(k.paylasici.tamponlar.single.every((b) => b == 0), isTrue);
      expect(k.durum, const DisaAktarmaEylemDurumu());
    });

    test('reauthentication-required → Google → tekrar', () async {
      var ilk = true;
      final k = _Kurulum(
        yanitlar: {
          indirmeYolu: () {
            if (ilk) {
              ilk = false;
              return problem(ProblemType.reauthenticationRequired, 403);
            }
            return indirmeJson();
          },
        },
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.google.cagri, 1);
      expect(k.yollar, [indirmeYolu, girisYolu, profilYolu, indirmeYolu]);
      expect(k.paylasici.kopyalar.single, ornekZip());
      expect(k.durum.hata, isNull);
    });

    test('Google penceresi kapatılırsa sessizce bitiyor', () async {
      final k = _Kurulum(
        google: SahteGoogle(),
        yanitlar: {
          indirmeYolu: () => problem(ProblemType.reauthenticationRequired, 403),
        },
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.yollar, [indirmeYolu]);
      expect(k.indirici.adresler, isEmpty);
      expect(k.durum, const DisaAktarmaEylemDurumu());
    });

    test('başka Google hesabı seçilirse indirilmiyor', () async {
      final k = _Kurulum(
        yanitlar: {
          indirmeYolu: () => problem(ProblemType.reauthenticationRequired, 403),
          profilYolu: () => profilJson(ben: false),
        },
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.durum.hata, isA<FarkliHesapHatasi>());
      expect(k.yollar, [indirmeYolu, girisYolu, profilYolu]);
      expect(k.indirici.adresler, isEmpty);
      expect(await k.oturum.store.durum(), isA<OturumAcik>());
    });

    test('yeniden girişten sonra yine reauthentication: hata', () async {
      final k = _Kurulum(
        yanitlar: {
          indirmeYolu: () => problem(ProblemType.reauthenticationRequired, 403),
        },
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.google.cagri, 1);
      expect(k.durum.hata, _problem(ProblemType.reauthenticationRequired));
      expect(k.indirici.adresler, isEmpty);

      // Tekrar: akış yeniden başlar.
      await k.eylem.indir(_talep());
      expect(k.google.cagri, 2);
    });

    for (final (tur, durum) in [
      (ProblemType.dataExportExpired, 410),
      (ProblemType.dataExportNotReady, 409),
      (ProblemType.dataExportNotFound, 404),
      (ProblemType.unavailable, 503),
    ]) {
      test('${tur.name}: hata ve liste yenileniyor', () async {
        final k = _Kurulum(yanitlar: {indirmeYolu: () => problem(tur, durum)});
        await k.oturumuAc();
        k.dinle();
        final sub = k.kap.listen(disaAktarmaListesiProvider, (_, _) {});
        addTearDown(sub.close);
        await k.kap.read(disaAktarmaListesiProvider.future);

        await k.eylem.indir(_talep());
        await k.kap.read(disaAktarmaListesiProvider.future);

        expect(k.durum.hata, _problem(tur));
        expect(k.tasima.sayi('GET', '/v1/me/data-exports'), 2);
        expect(k.paylasici.kopyalar, isEmpty);
      });
    }

    test('yanlış AAD (başka talebin dosyası) çözülmüyor', () async {
      final dosya = sifreliDosya(talepId: eskiTalepId);
      final k = _Kurulum(
        indirici: SahteIndirici(dosya: dosya),
        yanitlar: {indirmeYolu: () => indirmeJson(dosya: dosya)},
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.durum.hata, _hata(DisaAktarmaHataTuru.cozulemedi));
      expect(k.paylasici.kopyalar, isEmpty);
    });

    test('bozuk başlıklı dosya çözülmeye verilmiyor', () async {
      final dosya = sifreliDosya(surum: 0x02);
      final k = _Kurulum(
        indirici: SahteIndirici(dosya: dosya),
        yanitlar: {indirmeYolu: () => indirmeJson(dosya: dosya)},
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.durum.hata, _hata(DisaAktarmaHataTuru.bicim));
      expect(k.motor.cagrilar, isNot(contains('aes256GcmCoz')));
      expect(k.paylasici.kopyalar, isEmpty);
    });

    test('çözülen içerik zip değilse paylaşılmıyor', () async {
      final dosya = sifreliDosya(zip: Uint8List.fromList(List.filled(40, 1)));
      final k = _Kurulum(
        indirici: SahteIndirici(dosya: dosya),
        yanitlar: {indirmeYolu: () => indirmeJson(dosya: dosya)},
      );
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.durum.hata, _hata(DisaAktarmaHataTuru.bicim));
      expect(k.paylasici.kopyalar, isEmpty);
    });

    test('bilinmeyen biçim ya da yanlış anahtar indirilmiyor', () async {
      for (final yanit in [
        () => indirmeJson(bicim: 'aes-256-gcm-v2'),
        () => indirmeJson(anahtar: Uint8List(16)),
      ]) {
        final k = _Kurulum(yanitlar: {indirmeYolu: yanit});
        await k.oturumuAc();
        k.dinle();

        await k.eylem.indir(_talep());

        expect(k.durum.hata, _hata(DisaAktarmaHataTuru.bicim));
        expect(k.indirici.adresler, isEmpty);
      }
    });

    for (final (tur, beklenen) in [
      (ImzaliIndirmeHataTuru.baglanti, DisaAktarmaHataTuru.indirilemedi),
      (ImzaliIndirmeHataTuru.zamanAsimi, DisaAktarmaHataTuru.indirilemedi),
      (ImzaliIndirmeHataTuru.durum, DisaAktarmaHataTuru.indirilemedi),
      (ImzaliIndirmeHataTuru.boyut, DisaAktarmaHataTuru.bicim),
      (ImzaliIndirmeHataTuru.gecersizAdres, DisaAktarmaHataTuru.bicim),
    ]) {
      test('indirme hatası ${tur.name} → ${beklenen.name}', () async {
        final k = _Kurulum(
          indirici: SahteIndirici(hata: ImzaliIndirmeHatasi(tur)),
        );
        await k.oturumuAc();
        k.dinle();

        await k.eylem.indir(_talep());

        expect(k.durum.hata, _hata(beklenen));
        expect(k.paylasici.kopyalar, isEmpty);
      });
    }

    test('paylaşım hatası gösteriliyor, tampon sıfırlanıyor', () async {
      final k = _Kurulum();
      k.paylasici.hata = Exception('paylaşım');
      await k.oturumuAc();
      k.dinle();

      await k.eylem.indir(_talep());

      expect(k.durum.hata, isA<Exception>());
      expect(k.paylasici.tamponlar.single.every((b) => b == 0), isTrue);
    });

    test('sürerken ikinci çağrı yok sayılıyor', () async {
      final k = _Kurulum();
      await k.oturumuAc();
      k.dinle();

      final ilk = k.eylem.indir(_talep());
      expect(k.durum.islem, DisaAktarmaIslemi.indirme);
      expect(k.durum.talepId, ornekTalepId);
      await k.eylem.talepAc();
      await ilk;

      expect(k.yollar, [indirmeYolu]);
    });

    test('hata metninde link ve anahtar yok', () {
      for (final tur in DisaAktarmaHataTuru.values) {
        final metin = DisaAktarmaHatasi(tur).toString();
        expect(metin, isNot(contains('https')));
        expect(metin, isNot(contains(base64.encode(sahteAnahtar()))));
      }
    });
  });

  group('bildirim hedefi', () {
    test('data_export_ready "Verilerimi indir" ekranını açıyor', () {
      final bildirim = api.Notification.fromJson({
        'id': '7a6b5c4d-0000-4000-8000-000000000001',
        'type': 'data_export_ready',
        'target_type': 'data_export',
        'target_id': ornekTalepId,
        'read': false,
        'created_at': '2026-11-10T09:02:00Z',
      });
      expect(bildirimAdresi(bildirim), Adresler.veriDisaAktarma);
    });

    test('kimlik UUID değilse adres yok', () {
      final bildirim = api.Notification.fromJson({
        'id': '7a6b5c4d-0000-4000-8000-000000000001',
        'type': 'data_export_ready',
        'target_type': 'data_export',
        'target_id': '../hesabi-sil',
        'read': false,
        'created_at': '2026-11-10T09:02:00Z',
      });
      expect(bildirimAdresi(bildirim), isNull);
    });
  });
}
