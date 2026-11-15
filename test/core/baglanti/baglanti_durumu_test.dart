import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/api.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/baglanti/baglanti_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

import '../zaman_sahteleri.dart';

/// Elle sürülen canlı bağlantı durumu.
final class _SahteRealtimeDurumu extends RealtimeDurumuNotifier {
  @override
  RealtimeDurumu build() => RealtimeDurumu.kapali;

  void ayarla(RealtimeDurumu durum) => state = durum;
}

final class _Kurulum {
  _Kurulum() {
    final tasima = HttpTasima(
      istemci: MockClient((istek) async {
        if (cevrimdisi) throw http.ClientException('ağ yok');
        return http.Response(
          '{"status":"ok","version":"1","services":{},'
          '"checked_at":"2026-11-10T09:00:00Z"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      tabanAdres: Uri.parse('https://api.ornek.test'),
      istemciAdi: 'android',
      gunluk: gunluk.add,
    );
    final oturum = SessionStore(
      depo: BellekTokenDeposu(),
      yenileyici: (_, {butunlukTokeni}) => throw const ApiOffline(),
      yoklayici: () async {},
      gunluk: gunluk.add,
    );
    addTearDown(oturum.dispose);
    istemci = ApiClient(tasima: tasima, oturum: oturum);
    kap = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(istemci),
        realtimeDurumuProvider.overrideWith(_SahteRealtimeDurumu.new),
        zamanlayiciProvider.overrideWithValue(zaman.kur),
      ],
    );
    addTearDown(kap.dispose);
  }

  bool cevrimdisi = false;
  final List<String> gunluk = [];
  final SahteZamanlayici zaman = SahteZamanlayici();
  late final ApiClient istemci;
  late final ProviderContainer kap;

  void realtime(RealtimeDurumu durum) =>
      kap.read(realtimeDurumuProvider.notifier) as _SahteRealtimeDurumu
        ..ayarla(durum);

  Future<void> istek() async {
    try {
      await StatusApi(istemci).getStatus();
    } on ApiOffline {
      // Beklenen.
    }
    await pumpEventQueue();
  }
}

void main() {
  group('bağlantı yok bandı', () {
    test('bağlantı hatası açar, ilk başarılı istek kapatır', () async {
      final k = _Kurulum();
      expect(k.kap.read(baglantiYokProvider), isFalse);

      k.cevrimdisi = true;
      await k.istek();
      expect(k.kap.read(baglantiYokProvider), isTrue);

      k.cevrimdisi = false;
      await k.istek();
      expect(k.kap.read(baglantiYokProvider), isFalse);
    });

    test('canlı bağlantı kurulamazsa açılır, kurulunca kapanır', () {
      final k = _Kurulum();
      k.kap.read(baglantiYokProvider);
      k.realtime(RealtimeDurumu.baglaniyor);
      expect(k.kap.read(baglantiYokProvider), isFalse);
      k.realtime(RealtimeDurumu.kapali);
      expect(k.kap.read(baglantiYokProvider), isTrue);
      k.realtime(RealtimeDurumu.baglaniyor);
      k.realtime(RealtimeDurumu.acik);
      expect(k.kap.read(baglantiYokProvider), isFalse);
    });

    test('uygulamanın kapattığı bağlantı (açık → kapalı) bandı açmaz', () {
      final k = _Kurulum();
      k.kap.read(baglantiYokProvider);
      k
        ..realtime(RealtimeDurumu.acik)
        ..realtime(RealtimeDurumu.kapali);
      expect(k.kap.read(baglantiYokProvider), isFalse);
    });

    test('hiçbir hata ayrıntısı loglanmaz: bant yeni günlük satırı '
        'yazmaz', () async {
      final k = _Kurulum();
      k.kap.read(baglantiYokProvider);
      k.cevrimdisi = true;
      await k.istek();
      expect(k.kap.read(baglantiYokProvider), isTrue);
      // Yalnızca taşımanın kendi tek satırı; adres parametresi, gövde
      // ya da istisna metni yok.
      expect(k.gunluk, hasLength(1));
      expect(k.gunluk.single, isNot(contains('ağ yok')));
      expect(k.gunluk.single, isNot(contains('api.ornek.test')));
    });
  });

  group('sohbet "Bağlanıyor…"', () {
    test('gecikme dolmadan görünmez, dolunca görünür', () {
      final k = _Kurulum();
      expect(k.kap.read(sohbetBaglaniyorProvider), isFalse);
      final kurulan = k.zaman.etkin.single;
      expect(kurulan.sure, baglaniyorGecikmesi);
      k.zaman.calistir(baglaniyorGecikmesi);
      expect(k.kap.read(sohbetBaglaniyorProvider), isTrue);
    });

    test('bağlanınca hemen geri döner; kısa kopma titretmez', () {
      final k = _Kurulum();
      k.kap.read(sohbetBaglaniyorProvider);
      k.realtime(RealtimeDurumu.acik);
      expect(k.zaman.etkin, isEmpty);
      expect(k.kap.read(sohbetBaglaniyorProvider), isFalse);

      // Kopar ve gecikme dolmadan yeniden bağlanır: hiç görünmez.
      k.realtime(RealtimeDurumu.kapali);
      k.realtime(RealtimeDurumu.baglaniyor);
      expect(k.zaman.etkin, hasLength(1));
      k.realtime(RealtimeDurumu.acik);
      expect(k.zaman.etkin, isEmpty);
      expect(k.kap.read(sohbetBaglaniyorProvider), isFalse);

      // Uzun kopma: görünür, bağlanınca kaybolur.
      k.realtime(RealtimeDurumu.kapali);
      k.zaman.calistir(baglaniyorGecikmesi);
      expect(k.kap.read(sohbetBaglaniyorProvider), isTrue);
      k.realtime(RealtimeDurumu.acik);
      expect(k.kap.read(sohbetBaglaniyorProvider), isFalse);
    });
  });
}
