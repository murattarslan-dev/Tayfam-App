import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/duyuru/application/duyuru_formu_notifier.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/features/duyuru/application/duyuru_notifier.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

final class _Kurulum {
  _Kurulum([Map<String, TayfaYaniti>? yanitlar])
    : tasima = modulTasimasi(yanitlar) {
    kap = ProviderContainer.test(overrides: modulOverridelari(tasima));
  }

  final SahteTayfaTasima tasima;
  late final ProviderContainer kap;

  /// Duyuru listesini canlı tutar ve ilk sayfanın gelmesini bekler.
  Future<DuyuruListesiNotifier> liste() async {
    final saglayici = duyuruListesiProvider(ornekTayfaId);
    kap.listen(saglayici, (_, _) {});
    await kap.read(saglayici.future);
    return kap.read(saglayici.notifier);
  }

  List<Announcement> get duyurular =>
      kap.read(duyuruListesiProvider(ornekTayfaId)).requireValue.ogeler;
}

Announcement _duyuru(
  String id, {
  bool sabit = false,
  String zaman = '2026-11-10T10:00:00Z',
}) => Announcement.fromJson(duyuruJson(id, sabit: sabit, zaman: zaman));

DuyuruAnahtari _anahtar(String id) => (tayfaId: ornekTayfaId, duyuruId: id);

DuyuruFormuAnahtari _form(Announcement? duzenlenen) =>
    (tayfaId: ornekTayfaId, duzenlenen: duzenlenen);

ApiProblem _problem(ProblemType tur, [int durum = 400]) =>
    ApiProblem(type: tur, status: durum);

void main() {
  group('sıra', () {
    test('sabitlenenler önce, sonra yeniden eskiye', () {
      final sirali = duyuruSirala([
        _duyuru(duyuruId1, zaman: '2026-11-01T10:00:00Z'),
        _duyuru(duyuruId2, sabit: true, zaman: '2026-10-01T10:00:00Z'),
        _duyuru(duyuruId3, zaman: '2026-11-05T10:00:00Z'),
      ]);
      expect(sirali.map((d) => d.id), [duyuruId2, duyuruId3, duyuruId1]);
    });

    test('ana sayfada bütün sabitlenenler ve son iki duyuru', () {
      final liste = duyuruSirala([
        _duyuru(duyuruId1, sabit: true, zaman: '2026-11-01T10:00:00Z'),
        _duyuru(duyuruId2, sabit: true, zaman: '2026-11-02T10:00:00Z'),
        _duyuru(duyuruId3, zaman: '2026-11-03T10:00:00Z'),
        _duyuru(duyuruId4, zaman: '2026-11-04T10:00:00Z'),
        _duyuru(duyuruId5, zaman: '2026-11-05T10:00:00Z'),
        _duyuru(
          '1a2b3c4d-0000-4000-8000-000000000006',
          zaman: '2026-11-06T10:00:00Z',
        ),
      ]);
      expect(anaSayfaDuyurulari(liste).map((d) => d.id), [
        duyuruId2,
        duyuruId1,
        '1a2b3c4d-0000-4000-8000-000000000006',
        duyuruId5,
      ]);
    });
  });

  group('sayfalama', () {
    test('sonraki sayfa opak token ile okunup ekleniyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': (i) => switch (i.sorgu['page_token']) {
          null => duyuruListesiJson([duyuruJson(duyuruId1)], sonraki: 'opak-1'),
          _ => duyuruListesiJson([duyuruJson(duyuruId2)]),
        },
      });
      final n = await k.liste();
      expect(k.duyurular.map((d) => d.id), [duyuruId1]);
      expect(
        k.kap.read(duyuruListesiProvider(ornekTayfaId)).requireValue.dahaVar,
        isTrue,
      );

      await n.dahaFazla();

      expect(k.duyurular.map((d) => d.id), [duyuruId1, duyuruId2]);
      final istekler = k.tasima.giden('GET', duyurularYolu);
      expect(istekler.map((i) => i.sorgu['page_token']), [null, 'opak-1']);
      expect(istekler.first.yolParametreleri['tayfa_id'], ornekTayfaId);
      expect(
        k.kap.read(duyuruListesiProvider(ornekTayfaId)).requireValue.dahaVar,
        isFalse,
      );

      // Son sayfada başka istek gitmez.
      await n.dahaFazla();
      expect(k.tasima.giden('GET', duyurularYolu), hasLength(2));
    });

    test('aynı token tekrar gelirse son sayfa sayılıyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': (i) => switch (i.sorgu['page_token']) {
          null => duyuruListesiJson([duyuruJson(duyuruId1)], sonraki: 'opak-1'),
          _ => duyuruListesiJson([
            duyuruJson(duyuruId1),
            duyuruJson(duyuruId2),
          ], sonraki: 'opak-1'),
        },
      });
      final n = await k.liste();
      await n.dahaFazla();

      // Yinelenen duyuru bir kez gösterilir; döngü yok.
      expect(k.duyurular.map((d) => d.id), [duyuruId1, duyuruId2]);
      expect(
        k.kap.read(duyuruListesiProvider(ornekTayfaId)).requireValue.dahaVar,
        isFalse,
      );
    });

    test('sonraki sayfa okunamazsa liste kalıyor ve hata doluyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': (i) => switch (i.sorgu['page_token']) {
          null => duyuruListesiJson([duyuruJson(duyuruId1)], sonraki: 'opak-1'),
          _ => const ApiOffline(),
        },
      });
      final n = await k.liste();
      await n.dahaFazla();

      final durum = k.kap.read(duyuruListesiProvider(ornekTayfaId));
      expect(durum.requireValue.ogeler.map((d) => d.id), [duyuruId1]);
      expect(durum.requireValue.dahaHatasi, isA<ApiOffline>());
      expect(durum.requireValue.dahaVar, isTrue);
    });

    test('yenileme başarısızsa eldeki liste kalıyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': yanit(duyuruListesiJson([duyuruJson(duyuruId1)])),
      });
      final n = await k.liste();
      k.tasima.yanitlar['GET $duyurularYolu'] = yanit(const ApiOffline());

      final hata = await n.yenile();

      expect(hata, isA<ApiOffline>());
      expect(k.duyurular.map((d) => d.id), [duyuruId1]);
    });

    test('modül kapalıysa liste hatası module-disabled', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': yanit(_problem(ProblemType.moduleDisabled, 403)),
      });
      final saglayici = duyuruListesiProvider(ornekTayfaId);
      k.kap.listen(saglayici, (_, _) {});
      await expectLater(
        k.kap.read(saglayici.future),
        throwsA(isA<ApiProblem>()),
      );
      expect(
        (k.kap.read(saglayici).error! as ApiProblem).type,
        ProblemType.moduleDisabled,
      );
    });
  });

  group('duyuru', () {
    test('listede olan duyuru istek gönderilmeden gösteriliyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': yanit(duyuruListesiJson([duyuruJson(duyuruId1)])),
      });
      await k.liste();
      final saglayici = duyuruProvider(_anahtar(duyuruId1));
      k.kap.listen(saglayici, (_, _) {});

      final duyuru = await k.kap.read(saglayici.future);

      expect(duyuru.id, duyuruId1);
      expect(k.tasima.giden('GET', duyuruYolu), isEmpty);
    });

    test('listede olmayan duyuru sunucudan okunuyor', () async {
      final k = _Kurulum({'GET $duyuruYolu': yanit(duyuruJson(duyuruId2))});
      final saglayici = duyuruProvider(_anahtar(duyuruId2));
      k.kap.listen(saglayici, (_, _) {});

      final duyuru = await k.kap.read(saglayici.future);

      expect(duyuru.id, duyuruId2);
      final istek = k.tasima.giden('GET', duyuruYolu).single;
      expect(istek.yolParametreleri['announcement_id'], duyuruId2);
      // Liste sağlayıcısı kendiliğinden kurulmaz.
      expect(k.tasima.giden('GET', duyurularYolu), isEmpty);
    });

    test('sabitleme listeye yansıyor ve sıra güncelleniyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': yanit(
          duyuruListesiJson([
            duyuruJson(duyuruId1, zaman: '2026-11-05T10:00:00Z'),
            duyuruJson(duyuruId2, zaman: '2026-11-01T10:00:00Z'),
          ]),
        ),
        'PUT $sabitlemeYolu': yanit(
          duyuruJson(duyuruId2, sabit: true, zaman: '2026-11-01T10:00:00Z'),
        ),
      });
      await k.liste();
      final saglayici = duyuruProvider(_anahtar(duyuruId2));
      k.kap.listen(saglayici, (_, _) {});
      await k.kap.read(saglayici.future);

      final hata = await k.kap.read(saglayici.notifier).sabitle(sabit: true);

      expect(hata, isNull);
      expect(k.duyurular.map((d) => d.id), [duyuruId2, duyuruId1]);
      expect(k.kap.read(saglayici).requireValue.pinned, isTrue);
    });

    test('sabitleme kaldırılınca DELETE …/pin gidiyor', () async {
      final k = _Kurulum({
        'GET $duyuruYolu': yanit(duyuruJson(duyuruId1, sabit: true)),
        'DELETE $sabitlemeYolu': yanit(duyuruJson(duyuruId1)),
      });
      final saglayici = duyuruProvider(_anahtar(duyuruId1));
      k.kap.listen(saglayici, (_, _) {});
      await k.kap.read(saglayici.future);

      await k.kap.read(saglayici.notifier).sabitle(sabit: false);

      expect(k.tasima.giden('DELETE', sabitlemeYolu), hasLength(1));
      expect(k.kap.read(saglayici).requireValue.pinned, isFalse);
    });

    test('silinen duyuru listeden çıkıyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': yanit(
          duyuruListesiJson([duyuruJson(duyuruId1), duyuruJson(duyuruId2)]),
        ),
        'DELETE $duyuruYolu': yanit(null),
      });
      await k.liste();
      final saglayici = duyuruProvider(_anahtar(duyuruId1));
      k.kap.listen(saglayici, (_, _) {});
      await k.kap.read(saglayici.future);

      final hata = await k.kap.read(saglayici.notifier).sil();

      expect(hata, isNull);
      expect(k.duyurular.map((d) => d.id), [duyuruId2]);
    });

    test('yetki hatası döndürülüyor, liste değişmiyor', () async {
      final k = _Kurulum({
        'GET $duyurularYolu': yanit(duyuruListesiJson([duyuruJson(duyuruId1)])),
        'DELETE $duyuruYolu': yanit(_problem(ProblemType.roleHierarchy, 403)),
      });
      await k.liste();
      final saglayici = duyuruProvider(_anahtar(duyuruId1));
      k.kap.listen(saglayici, (_, _) {});
      await k.kap.read(saglayici.future);

      final hata = await k.kap.read(saglayici.notifier).sil();

      expect((hata! as ApiProblem).type, ProblemType.roleHierarchy);
      expect(k.duyurular.map((d) => d.id), [duyuruId1]);
    });
  });

  group('form', () {
    test('başlık doğrulaması', () {
      expect(duyuruBasligiGecerli('  '), isFalse);
      expect(duyuruBasligiGecerli('Toplantı'), isTrue);
      expect(duyuruBasligiGecerli('a' * 120), isTrue);
      expect(duyuruBasligiGecerli('a' * 121), isFalse);
      expect(duyuruBasligiGecerli('İki\nsatır'), isFalse);
      expect(duyuruGovdesiGecerli('a' * 5000), isTrue);
      expect(duyuruGovdesiGecerli('a' * 5001), isFalse);
    });

    test('geçersiz başlıkta istek gitmiyor, hata gösteriliyor', () async {
      final k = _Kurulum();
      final saglayici = duyuruFormuProvider(_form(null));
      k.kap.listen(saglayici, (_, _) {});

      await k.kap.read(saglayici.notifier).gonder();

      expect(k.kap.read(saglayici).baslikHatali, isTrue);
      expect(k.tasima.giden('POST', duyurularYolu), isEmpty);

      k.kap.read(saglayici.notifier).baslikAyarla('Toplantı');
      expect(k.kap.read(saglayici).baslikHatali, isFalse);
    });

    test('tekrar denemede aynı client_request_id gidiyor', () async {
      var deneme = 0;
      final k = _Kurulum({
        'POST $duyurularYolu': (_) {
          if (deneme++ == 0) return const ApiOffline();
          return duyuruJson(duyuruId3, baslik: 'Toplantı', govde: 'Saat 9');
        },
      });
      await k.liste();
      final saglayici = duyuruFormuProvider(_form(null));
      k.kap.listen(saglayici, (_, _) {});
      final n = k.kap.read(saglayici.notifier);
      n.baslikAyarla('  Toplantı ');
      n.govdeAyarla('Saat 9\n');

      await n.gonder();
      expect(k.kap.read(saglayici).hata, isA<ApiOffline>());
      // Girilenler korunur.
      expect(k.kap.read(saglayici).baslik, '  Toplantı ');

      await n.gonder();

      final istekler = k.tasima.giden('POST', duyurularYolu);
      expect(istekler, hasLength(2));
      for (final istek in istekler) {
        final govde = istek.govde! as Map<String, Object?>;
        expect(govde['client_request_id'], sahteIstekKimligi);
        expect(govde['title'], 'Toplantı');
        expect(govde['body'], 'Saat 9');
      }
      expect(k.kap.read(saglayici).tamamlanan?.id, duyuruId3);
      // Yeni duyuru listeye yansır.
      expect(k.duyurular.map((d) => d.id), [duyuruId3]);
    });

    test('düzenlemede yalnızca değişen alan gidiyor', () async {
      final eski = _duyuru(duyuruId1);
      final k = _Kurulum({
        'PATCH $duyuruYolu': yanit(
          duyuruJson(duyuruId1, baslik: 'Yeni başlık'),
        ),
      });
      final saglayici = duyuruFormuProvider(_form(eski));
      k.kap.listen(saglayici, (_, _) {});
      expect(k.kap.read(saglayici).baslik, eski.title);
      expect(k.kap.read(saglayici).govde, eski.body);

      final n = k.kap.read(saglayici.notifier);
      n.baslikAyarla('Yeni başlık');
      await n.gonder();

      final istek = k.tasima.giden('PATCH', duyuruYolu).single;
      expect(istek.govde, {'title': 'Yeni başlık'});
      expect(istek.yolParametreleri['announcement_id'], duyuruId1);
      expect(k.kap.read(saglayici).tamamlanan?.title, 'Yeni başlık');
    });

    test('"Yayınlayınca sabitle": oluşturma, sonra PUT …/pin', () async {
      final k = _Kurulum({
        'POST $duyurularYolu': yanit(duyuruJson(duyuruId3, baslik: 'Kurallar')),
        'PUT $sabitlemeYolu': yanit(
          duyuruJson(duyuruId3, baslik: 'Kurallar', sabit: true),
        ),
      });
      await k.liste();
      final saglayici = duyuruFormuProvider(_form(null));
      k.kap.listen(saglayici, (_, _) {});
      final n = k.kap.read(saglayici.notifier);
      n.baslikAyarla('Kurallar');
      n.sabitlemeyiAyarla(sabitle: true);
      expect(k.kap.read(saglayici).sabitle, isTrue);

      await n.gonder();

      expect(k.tasima.giden('POST', duyurularYolu), hasLength(1));
      final sabitleme = k.tasima.giden('PUT', sabitlemeYolu).single;
      expect(sabitleme.yolParametreleri['announcement_id'], duyuruId3);
      final durum = k.kap.read(saglayici);
      expect(durum.tamamlanan?.pinned, isTrue);
      expect(durum.sabitlenemedi, isFalse);
      expect(k.duyurular.single.pinned, isTrue);
    });

    test('sabitleme başarısızsa duyuru yine yayınlanmış sayılıyor', () async {
      final k = _Kurulum({
        'POST $duyurularYolu': yanit(duyuruJson(duyuruId3)),
        'PUT $sabitlemeYolu': yanit(
          _problem(ProblemType.permissionDenied, 403),
        ),
      });
      final saglayici = duyuruFormuProvider(_form(null));
      k.kap.listen(saglayici, (_, _) {});
      final n = k.kap.read(saglayici.notifier)
        ..baslikAyarla('Pazar buluşması')
        ..sabitlemeyiAyarla(sabitle: true);

      await n.gonder();

      final durum = k.kap.read(saglayici);
      expect(durum.tamamlanan?.id, duyuruId3);
      expect(durum.tamamlanan?.pinned, isFalse);
      expect(durum.sabitlenemedi, isTrue);
      expect(durum.hata, isNull);
      // Form tamamlandı; ikinci gönderim yeni duyuru açmaz.
      await n.gonder();
      expect(k.tasima.giden('POST', duyurularYolu), hasLength(1));
    });

    test('anahtar kapalıyken sabitleme isteği gitmiyor', () async {
      final k = _Kurulum({'POST $duyurularYolu': yanit(duyuruJson(duyuruId3))});
      final saglayici = duyuruFormuProvider(_form(null));
      k.kap.listen(saglayici, (_, _) {});
      final n = k.kap.read(saglayici.notifier)..baslikAyarla('Pazar');

      await n.gonder();

      expect(k.tasima.giden('PUT', sabitlemeYolu), isEmpty);
      expect(k.kap.read(saglayici).tamamlanan?.id, duyuruId3);
    });

    test('düzenlemede sabitleme anahtarı yok sayılıyor', () {
      final k = _Kurulum();
      final saglayici = duyuruFormuProvider(_form(_duyuru(duyuruId1)));
      k.kap.listen(saglayici, (_, _) {});
      k.kap.read(saglayici.notifier).sabitlemeyiAyarla(sabitle: true);
      expect(k.kap.read(saglayici).sabitle, isFalse);
    });

    test('değişiklik yoksa istek gitmeden kapanıyor', () async {
      final eski = _duyuru(duyuruId1);
      final k = _Kurulum();
      final saglayici = duyuruFormuProvider(_form(eski));
      k.kap.listen(saglayici, (_, _) {});

      await k.kap.read(saglayici.notifier).gonder();

      expect(k.tasima.istekler.where((i) => i.method == 'PATCH'), isEmpty);
      expect(k.kap.read(saglayici).tamamlanan, eski);
    });
  });
}
