import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

import '../../yardimcilar.dart';
import '../zaman_sahteleri.dart';

/// Her denemede sıradaki sonucu veren sahte iş; gönderilen istek
/// kimliklerini kaydeder.
final class _SahteIs extends KuyrukIsi {
  _SahteIs(this.istekKimligi, {this.grup = 'kanal:a', List<Object?>? sonuclar})
    : sonuclar = sonuclar ?? ['tamam'];

  @override
  final String istekKimligi;

  @override
  final String grup;

  final List<Object?> sonuclar;
  final List<String> gonderilen = [];
  Completer<void>? bekle;

  @override
  Future<Object?> gonder() async {
    gonderilen.add(istekKimligi);
    final b = bekle;
    if (b != null) await b.future;
    final sonuc = sonuclar.length > 1 ? sonuclar.removeAt(0) : sonuclar.first;
    if (sonuc is Exception) throw sonuc;
    return sonuc;
  }
}

final class _Kurulum {
  _Kurulum() {
    kap = ProviderContainer.test(
      overrides: [
        oturumDurumuProvider.overrideWith(
          () => SabitOturumDurumu(OturumDurumu.acik),
        ),
        zamanlayiciProvider.overrideWithValue(zaman.kur),
        simdiProvider.overrideWithValue(() => simdi),
      ],
    );
    kap.listen(cevrimdisiKuyrukProvider, (_, _) {});
    kuyruk.olaylar.listen(olaylar.add);
  }

  late final ProviderContainer kap;
  final SahteZamanlayici zaman = SahteZamanlayici();
  final List<KuyrukOlayi> olaylar = [];
  DateTime simdi = DateTime.utc(2026, 11, 11, 10);

  CevrimdisiKuyruk get kuyruk => kap.read(cevrimdisiKuyrukProvider.notifier);
  List<KuyrukOgesi> get ogeler => kap.read(cevrimdisiKuyrukProvider);
}

void main() {
  test('başarılı iş kuyruktan çıkar ve sonucu yayılır', () async {
    final k = _Kurulum();
    k.kuyruk.ekle(_SahteIs('id-1'));
    await pumpEventQueue();
    expect(k.ogeler, isEmpty);
    final olay = k.olaylar.single as KuyrukGonderildi;
    expect(olay.sonuc, 'tamam');
  });

  test('geçici hatada aynı id ile 2, 4 … sn sonra yeniden denenir', () async {
    final k = _Kurulum();
    final gorev = _SahteIs(
      'id-1',
      sonuclar: [const ApiOffline(), const ApiTimeout(), 'tamam'],
    );
    k.kuyruk.ekle(gorev);
    await pumpEventQueue();
    expect(k.ogeler.single.durum, KuyrukDurumu.bekliyor);
    expect(k.zaman.etkin.single.sure, const Duration(seconds: 2));
    k.simdi = k.simdi.add(const Duration(seconds: 2));
    k.zaman.calistir();
    await pumpEventQueue();
    expect(k.zaman.etkin.single.sure, const Duration(seconds: 4));
    k.simdi = k.simdi.add(const Duration(seconds: 4));
    k.zaman.calistir();
    await pumpEventQueue();
    expect(gorev.gonderilen, ['id-1', 'id-1', 'id-1']);
    expect(k.ogeler, isEmpty);
  });

  test('kalıcı hatada gönderilemedi olur; tekrar dene ve sil', () async {
    final k = _Kurulum();
    final gorev = _SahteIs(
      'id-1',
      sonuclar: [
        const ApiProblem(type: ProblemType.channelArchived, status: 409),
        'tamam',
      ],
    );
    k.kuyruk.ekle(gorev);
    await pumpEventQueue();
    expect(k.ogeler.single.durum, KuyrukDurumu.gonderilemedi);
    expect(k.olaylar.single, isA<KuyrukGonderilemedi>());
    expect(k.zaman.etkin, isEmpty);

    k.kuyruk.tekrarDene('id-1');
    await pumpEventQueue();
    expect(k.ogeler, isEmpty);
    expect(gorev.gonderilen, ['id-1', 'id-1']);

    final ikinci = _SahteIs(
      'id-2',
      sonuclar: [const ApiProblem(type: ProblemType.muted, status: 403)],
    );
    k.kuyruk.ekle(ikinci);
    await pumpEventQueue();
    k.kuyruk.sil('id-2');
    expect(k.ogeler, isEmpty);
  });

  test('rate-limited sunucunun verdiği süre kadar bekler', () async {
    final k = _Kurulum();
    k.kuyruk.ekle(
      _SahteIs(
        'id-1',
        sonuclar: [
          const ApiProblem(
            type: ProblemType.rateLimited,
            status: 429,
            retryAfter: Duration(seconds: 17),
          ),
          'tamam',
        ],
      ),
    );
    await pumpEventQueue();
    expect(k.zaman.etkin.single.sure, const Duration(seconds: 17));
  });

  test('bekleme 60 sn\'yi geçmez', () {
    expect(beklemeSuresi(1, const ApiOffline()), const Duration(seconds: 2));
    expect(beklemeSuresi(3, const ApiOffline()), const Duration(seconds: 8));
    expect(beklemeSuresi(20, const ApiOffline()), const Duration(seconds: 60));
  });

  test('aynı gruptaki işler sırayla, gruplar birbirini beklemeden', () async {
    final k = _Kurulum();
    final birinci = _SahteIs('id-1')..bekle = Completer<void>();
    final ikinci = _SahteIs('id-2');
    final baska = _SahteIs('id-3', grup: 'kanal:b');
    k.kuyruk
      ..ekle(birinci)
      ..ekle(ikinci)
      ..ekle(baska);
    await pumpEventQueue();
    expect(birinci.gonderilen, ['id-1']);
    expect(ikinci.gonderilen, isEmpty);
    expect(baska.gonderilen, ['id-3']);
    birinci.bekle!.complete();
    await pumpEventQueue();
    expect(ikinci.gonderilen, ['id-2']);
    expect(k.ogeler, isEmpty);
  });

  test('simdiDene bekleyenleri hemen dener', () async {
    final k = _Kurulum();
    final gorev = _SahteIs('id-1', sonuclar: [const ApiOffline(), 'tamam']);
    k.kuyruk.ekle(gorev);
    await pumpEventQueue();
    k.kuyruk.simdiDene();
    await pumpEventQueue();
    expect(gorev.gonderilen, hasLength(2));
    expect(k.ogeler, isEmpty);
  });

  test('aynı istek kimliği iki kez eklenmez', () async {
    final k = _Kurulum();
    final gorev = _SahteIs('id-1')..bekle = Completer<void>();
    k.kuyruk
      ..ekle(gorev)
      ..ekle(_SahteIs('id-1'));
    expect(k.ogeler, hasLength(1));
    gorev.bekle!.complete();
    await pumpEventQueue();
  });

  test('oturum değişince kuyruk temizlenir', () async {
    final k = _Kurulum();
    k.kuyruk.ekle(_SahteIs('id-1', sonuclar: [const ApiOffline()]));
    await pumpEventQueue();
    expect(k.ogeler, hasLength(1));
    k.kap.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    expect(k.ogeler, isEmpty);
    expect(k.zaman.etkin, isEmpty);
  });

  test('geçici ve kalıcı hata ayrımı', () {
    expect(geciciHataMi(const ApiOffline()), isTrue);
    expect(
      geciciHataMi(const ApiProblem(type: ProblemType.slowMode, status: 429)),
      isTrue,
    );
    expect(
      geciciHataMi(const ApiProblem(type: ProblemType.unknown, status: 503)),
      isTrue,
    );
    for (final tur in [
      ProblemType.invalidRequest,
      ProblemType.permissionDenied,
      ProblemType.notFound,
    ]) {
      expect(geciciHataMi(ApiProblem(type: tur, status: 400)), isFalse);
    }
  });
}
