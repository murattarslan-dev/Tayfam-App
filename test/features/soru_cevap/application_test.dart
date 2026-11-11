import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/soru_cevap/application/cevap_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/cevap_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/etiketler_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_notifier.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

final class _Kurulum {
  _Kurulum([Map<String, TayfaYaniti>? yanitlar])
    : tasima = soruTasimasi(yanitlar) {
    kap = ProviderContainer.test(overrides: soruOverridelari(tasima));
  }

  final SahteTayfaTasima tasima;
  late final ProviderContainer kap;

  /// [anahtar] listesini canlı tutar ve ilk sayfanın gelmesini bekler.
  Future<SoruListesiNotifier> liste([SoruListesiAnahtari? anahtar]) async {
    final saglayici = soruListesiProvider(
      anahtar ?? anaSoruListesi(ornekTayfaId),
    );
    kap.listen(saglayici, (_, _) {});
    await kap.read(saglayici.future);
    return kap.read(saglayici.notifier);
  }

  List<Question> get sorular => kap
      .read(soruListesiProvider(anaSoruListesi(ornekTayfaId)))
      .requireValue
      .ogeler;

  /// Soruyu ve cevaplarını canlı tutar ve okunmalarını bekler.
  Future<void> soru([String id = soruId1]) async {
    final soru = soruProvider(_soru(id));
    final cevaplar = cevapListesiProvider(_soru(id));
    kap
      ..listen(soru, (_, _) {})
      ..listen(cevaplar, (_, _) {});
    await kap.read(soru.future);
    await kap.read(cevaplar.future);
  }

  Question get gosterilen =>
      kap.read(soruProvider(_soru(soruId1))).requireValue;

  List<Answer> get cevaplar =>
      kap.read(cevapListesiProvider(_soru(soruId1))).requireValue.ogeler;
}

SoruAnahtari _soru(String id) => (tayfaId: ornekTayfaId, soruId: id);

Question _soruModeli(String id, {List<Map<String, Object?>>? etiketler}) =>
    Question.fromJson(soruJson(id, etiketler: etiketler ?? const []));

Answer _cevap(String id, {int oy = 0, String zaman = '2026-11-10T12:00:00Z'}) =>
    Answer.fromJson(cevapJson(id, oy: oy, zaman: zaman));

void main() {
  group('arama', () {
    test('metin tek satıra iniyor, kırpılıyor ve 100 karakterle sınırlı', () {
      expect(soruAramasiniNormalle('  çadır\nkamp \r\n'), 'çadır kamp');
      expect(soruAramasiniNormalle('   '), '');
      final uzun = 'ı' * 150;
      expect(soruAramasiniNormalle(uzun).runes.length, soruAramasiEnCok);
    });

    test(
      'arama ve etiket sunucuya gidiyor; harf dönüşümü yapılmıyor',
      () async {
        final k = _Kurulum();
        await k.liste((
          tayfaId: ornekTayfaId,
          arama: 'IŞIK',
          etiketId: etiketId1,
        ));
        final istek = k.tasima.giden('GET', sorularYolu).single;
        expect(istek.sorgu['q'], 'IŞIK');
        expect(istek.sorgu['tag_id'], etiketId1);
      },
    );

    test('süzgeçsiz listede q ve tag_id gönderilmiyor', () async {
      final k = _Kurulum();
      await k.liste();
      final istek = k.tasima.giden('GET', sorularYolu).single;
      expect(istek.sorgu.containsKey('q'), isFalse);
      expect(istek.sorgu.containsKey('tag_id'), isFalse);
    });

    test('süzgeç etiketi seçip kaldırıyor, aramayı normalliyor', () {
      final k = _Kurulum();
      final saglayici = soruSuzgeciProvider(ornekTayfaId);
      k.kap.listen(saglayici, (_, _) {});
      final n = k.kap.read(saglayici.notifier);
      expect(k.kap.read(saglayici).etkin, isFalse);
      n.etiketSec(etiketId1);
      expect(k.kap.read(saglayici).etiketId, etiketId1);
      n.etiketSec(etiketId1);
      expect(k.kap.read(saglayici).etiketId, isNull);
      n.aramaAyarla('  çadır ');
      expect(k.kap.read(saglayici).arama, 'çadır');
      expect(k.kap.read(saglayici).etkin, isTrue);
    });
  });

  group('sayfalama', () {
    test('sonraki sayfa opak token ile okunup ekleniyor', () async {
      final k = _Kurulum({
        'GET $sorularYolu': (i) => switch (i.sorgu['page_token']) {
          null => soruListesiJson([soruJson(soruId1)], sonraki: 'opak-1'),
          _ => soruListesiJson([soruJson(soruId2)]),
        },
      });
      final n = await k.liste();
      await n.dahaFazla();
      expect(k.sorular.map((s) => s.id), [soruId1, soruId2]);
      expect(
        k.tasima.giden('GET', sorularYolu).map((i) => i.sorgu['page_token']),
        [null, 'opak-1'],
      );
    });
  });

  group('soru formu', () {
    SoruFormuNotifier form(_Kurulum k, [Question? duzenlenen]) {
      final saglayici = soruFormuProvider((
        tayfaId: ornekTayfaId,
        duzenlenen: duzenlenen,
      ));
      k.kap.listen(saglayici, (_, _) {});
      return k.kap.read(saglayici.notifier);
    }

    SoruFormuDurumu durum(_Kurulum k, [Question? duzenlenen]) => k.kap.read(
      soruFormuProvider((tayfaId: ornekTayfaId, duzenlenen: duzenlenen)),
    );

    test('başlık 10–150 karakter ve tek satır', () {
      expect(soruBasligiGecerli('Kısa soru'), isFalse);
      expect(soruBasligiGecerli('  Çadır önerisi?  '), isTrue);
      expect(soruBasligiGecerli('Çadır önerisi\nvar mı?'), isFalse);
      expect(soruBasligiGecerli('a' * 151), isFalse);
    });

    test('geçersiz başlıkla istek gitmiyor', () async {
      final k = _Kurulum();
      final n = form(k)..baslikAyarla('Kısa');
      await n.gonder();
      expect(durum(k).baslikHatali, isTrue);
      expect(k.tasima.giden('POST', sorularYolu), isEmpty);
    });

    test('etiketler normalleniyor, Türkçe harfle tekilleşiyor, en çok 5', () {
      final k = _Kurulum();
      final n = form(k);
      expect(n.etiketEkle('  kamp   ateşi '), isTrue);
      expect(n.etiketEkle('IŞIK'), isTrue);
      // Aynı etiket (Türkçe küçük harfle) ikinci kez eklenmez.
      expect(n.etiketEkle('ışık'), isTrue);
      expect(n.etiketEkle('KAMP ATEŞİ'), isTrue);
      expect(durum(k).etiketler, ['kamp ateşi', 'IŞIK']);
      expect(n.etiketEkle('   '), isFalse);
      expect(n.etiketEkle('a' * 31), isFalse);
      expect(durum(k).etiketHatasi, EtiketHatasi.cokUzun);
      n
        ..etiketEkle('bir')
        ..etiketEkle('iki')
        ..etiketEkle('üç');
      expect(n.etiketEkle('dört'), isFalse);
      expect(durum(k).etiketHatasi, EtiketHatasi.cokFazla);
      n.etiketCikar('iki');
      expect(durum(k).etiketler, ['kamp ateşi', 'IŞIK', 'bir', 'üç']);
    });

    test(
      'soru sorulunca istek kimliği gidiyor, listenin başına ekleniyor',
      () async {
        final k = _Kurulum({
          'GET $sorularYolu': yanit(soruListesiJson([soruJson(soruId2)])),
          'POST $sorularYolu': yanit(soruJson(soruId1)),
        });
        await k.liste();
        final n = form(k)
          ..baslikAyarla('  Kamp için hangi çadırı alalım?  ')
          ..etiketEkle('kamp');
        await n.gonder();
        final govde =
            k.tasima.giden('POST', sorularYolu).single.govde!
                as Map<String, Object?>;
        expect(govde, {
          'title': 'Kamp için hangi çadırı alalım?',
          'tags': ['kamp'],
          'client_request_id': sahteIstekKimligi,
        });
        expect(durum(k).tamamlanan?.id, soruId1);
        expect(k.sorular.map((s) => s.id), [soruId1, soruId2]);
      },
    );

    test(
      'hata alınca form açık kalıyor; tekrarda aynı istek kimliği',
      () async {
        final k = _Kurulum({'POST $sorularYolu': yanit(const ApiOffline())});
        final n = form(k)..baslikAyarla('Kamp için hangi çadırı alalım?');
        await n.gonder();
        expect(durum(k).hata, isA<ApiOffline>());
        k.tasima.yanitlar['POST $sorularYolu'] = yanit(soruJson(soruId1));
        await n.gonder();
        final kimlikler = [
          for (final i in k.tasima.giden('POST', sorularYolu))
            (i.govde! as Map<String, Object?>)['client_request_id'],
        ];
        expect(kimlikler, [sahteIstekKimligi, sahteIstekKimligi]);
      },
    );

    test('düzenlemede yalnızca değişen alanlar gidiyor', () async {
      final eski = _soruModeli(
        soruId1,
        etiketler: [etiketJson(etiketId1, 'kamp')],
      );
      final k = _Kurulum({
        'PATCH $soruYolu': yanit(soruJson(soruId1, etiketler: const [])),
      });
      final n = form(k, eski);
      expect(durum(k, eski).etiketler, ['kamp']);

      // Değişiklik yoksa istek gitmez.
      await n.gonder();
      expect(k.tasima.giden('PATCH', soruYolu), isEmpty);
      expect(durum(k, eski).tamamlanan, eski);
    });

    test('etiket kaldırılınca etiketlerin tamamı gönderiliyor', () async {
      final eski = _soruModeli(
        soruId1,
        etiketler: [etiketJson(etiketId1, 'kamp')],
      );
      final k = _Kurulum({
        'PATCH $soruYolu': yanit(soruJson(soruId1, etiketler: const [])),
      });
      final n = form(k, eski)..etiketCikar('kamp');
      await n.gonder();
      final istek = k.tasima.giden('PATCH', soruYolu).single;
      expect(istek.govde, {'tags': <Object?>[]});
      expect(istek.yolParametreleri['question_id'], soruId1);
    });
  });

  group('cevaplar', () {
    test('sıra: faydalı oyu çoktan aza, eşitlikte eskiden yeniye', () {
      final sirali = cevapSirala([
        _cevap(cevapId1, oy: 1, zaman: '2026-11-10T10:00:00Z'),
        _cevap(cevapId2, oy: 3),
        _cevap(cevapId3, oy: 1, zaman: '2026-11-09T10:00:00Z'),
      ]);
      expect(sirali.map((c) => c.id), [cevapId2, cevapId3, cevapId1]);
    });

    test('cevap yazılınca listeye ve cevap sayısına yansıyor', () async {
      final k = _Kurulum({
        'GET $soruYolu': yanit(soruJson(soruId1, cevapSayisi: 1)),
        'GET $cevaplarYolu': yanit(
          cevapListesiJson([cevapJson(cevapId1, oy: 2)]),
        ),
        'POST $cevaplarYolu': yanit(cevapJson(cevapId2, yazar: benimId)),
      });
      await k.soru();
      final saglayici = cevapFormuProvider((
        tayfaId: ornekTayfaId,
        soruId: soruId1,
        duzenlenen: null,
      ));
      k.kap.listen(saglayici, (_, _) {});
      final n = k.kap.read(saglayici.notifier);

      await n.gonder();
      expect(k.kap.read(saglayici).govdeHatali, isTrue);
      expect(k.tasima.giden('POST', cevaplarYolu), isEmpty);

      n.govdeAyarla('  Hafif kubbe çadır al.  ');
      await n.gonder();
      final istek = k.tasima.giden('POST', cevaplarYolu).single;
      expect(istek.govde, {
        'body': 'Hafif kubbe çadır al.',
        'client_request_id': sahteIstekKimligi,
      });
      expect(k.cevaplar.map((c) => c.id), [cevapId1, cevapId2]);
      expect(k.gosterilen.answerCount, 2);
    });

    test('oy verme ve geri alma ilgili uçlara gidiyor', () async {
      final k = _Kurulum({
        'GET $soruYolu': yanit(soruJson(soruId1)),
        'GET $cevaplarYolu': yanit(cevapListesiJson([cevapJson(cevapId1)])),
        'PUT $oyYolu': yanit(cevapJson(cevapId1, oy: 1, oyladim: true)),
        'DELETE $oyYolu': yanit(cevapJson(cevapId1)),
      });
      await k.soru();
      final n = k.kap.read(cevapListesiProvider(_soru(soruId1)).notifier);

      expect(await n.oyla(cevapId1, oy: true), isNull);
      expect(k.cevaplar.single.voted, isTrue);
      expect(k.cevaplar.single.voteCount, 1);

      expect(await n.oyla(cevapId1, oy: false), isNull);
      expect(k.cevaplar.single.voted, isFalse);
      expect(
        k.tasima.giden('PUT', oyYolu).single.yolParametreleri['answer_id'],
        cevapId1,
      );
      expect(k.tasima.giden('DELETE', oyYolu), hasLength(1));
    });

    test('kendi cevabına oy hatası döndürülüyor, cevap değişmiyor', () async {
      final k = _Kurulum({
        'GET $soruYolu': yanit(soruJson(soruId1)),
        'GET $cevaplarYolu': yanit(cevapListesiJson([cevapJson(cevapId1)])),
        'PUT $oyYolu': yanit(
          const ApiProblem(type: ProblemType.ownAnswerVote, status: 403),
        ),
      });
      await k.soru();
      final n = k.kap.read(cevapListesiProvider(_soru(soruId1)).notifier);
      final hata = await n.oyla(cevapId1, oy: true);
      expect(hata, isA<ApiProblem>());
      expect((hata! as ApiProblem).type, ProblemType.ownAnswerVote);
      expect(k.cevaplar.single.voted, isFalse);
    });

    test('cevap silinince listeden çıkıyor ve sayı azalıyor', () async {
      final k = _Kurulum({
        'GET $soruYolu': yanit(soruJson(soruId1, cevapSayisi: 2)),
        'GET $cevaplarYolu': yanit(
          cevapListesiJson([cevapJson(cevapId1), cevapJson(cevapId2)]),
        ),
        'DELETE $cevapYolu': yanit(null),
      });
      await k.soru();
      final n = k.kap.read(cevapListesiProvider(_soru(soruId1)).notifier);
      expect(await n.sil(cevapId1), isNull);
      expect(k.cevaplar.map((c) => c.id), [cevapId2]);
      expect(k.gosterilen.answerCount, 1);
    });
  });

  group('soru', () {
    test('listede varsa sunucudan yeniden okunmuyor', () async {
      final k = _Kurulum({
        'GET $sorularYolu': yanit(soruListesiJson([soruJson(soruId1)])),
      });
      await k.liste();
      await k.soru();
      expect(k.tasima.giden('GET', soruYolu), isEmpty);
    });

    test('silinince listeden çıkıyor', () async {
      final k = _Kurulum({
        'GET $sorularYolu': yanit(
          soruListesiJson([soruJson(soruId1), soruJson(soruId2)]),
        ),
        'DELETE $soruYolu': yanit(null),
      });
      await k.liste();
      await k.soru();
      final hata = await k.kap
          .read(soruProvider(_soru(soruId1)).notifier)
          .sil();
      expect(hata, isNull);
      expect(k.sorular.map((s) => s.id), [soruId2]);
    });

    test('silme reddedilirse hata dönüyor, liste kalıyor', () async {
      final k = _Kurulum({
        'GET $sorularYolu': yanit(soruListesiJson([soruJson(soruId1)])),
        'DELETE $soruYolu': yanit(
          const ApiProblem(type: ProblemType.permissionDenied, status: 403),
        ),
      });
      await k.liste();
      await k.soru();
      final hata = await k.kap
          .read(soruProvider(_soru(soruId1)).notifier)
          .sil();
      expect(hata, isA<ApiProblem>());
      expect(k.sorular.map((s) => s.id), [soruId1]);
    });
  });

  group('geri alma (yalnızca depo)', () {
    test('soru ve cevap restoration uçlarına gidiyor', () async {
      final tasima = soruTasimasi({
        'POST $soruYolu/restoration': yanit(soruJson(soruId1)),
        'POST $cevapYolu/restoration': yanit(cevapJson(cevapId1)),
      });
      final depo = SoruCevapDeposu(tasima);
      expect((await depo.soruyuGeriAl(ornekTayfaId, soruId1)).id, soruId1);
      expect((await depo.cevabiGeriAl(ornekTayfaId, cevapId1)).id, cevapId1);
    });
  });

  group('etiket önerileri', () {
    final tumu = [
      Tag.fromJson(etiketJson(etiketId1, 'Işıklandırma')),
      Tag.fromJson(etiketJson(etiketId2, 'kamp')),
    ];

    test('Türkçe harfle eşleşiyor, eklenenler önerilmiyor', () {
      expect(etiketOnerileri(tumu, 'IŞIK', const []), ['Işıklandırma']);
      expect(etiketOnerileri(tumu, '', const ['KAMP']), ['Işıklandırma']);
      expect(etiketOnerileri(tumu, '', const []), ['Işıklandırma', 'kamp']);
    });
  });
}
