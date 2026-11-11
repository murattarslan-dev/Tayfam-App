import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/realtime/realtime_istemcisi.dart';
import 'package:tayfam/core/realtime/realtime_soketi.dart';
import 'package:tayfam/core/surum/uygulama_surumu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

export 'package:tayfam/core/realtime/realtime_istemcisi.dart'
    show RealtimeDurumu, RealtimeIstemcisi, RealtimeKapali;
export 'package:tayfam/core/realtime/realtime_olaylari.dart';
export 'package:tayfam/core/realtime/realtime_soketi.dart'
    show RealtimeBaglayici, RealtimeSoketi;

/// `GET /v1/realtime` adresi: API taban adresinin `wss` karşılığı.
Uri realtimeAdresi(Uri tabanAdres) => tabanAdres.replace(
  scheme: 'wss',
  pathSegments: [
    ...tabanAdres.pathSegments.where((p) => p.isNotEmpty),
    'v1',
    'realtime',
  ],
);

/// Bağlantıyı açan fonksiyon; testlerde sahtesi verilir.
final realtimeBaglayiciProvider = Provider<RealtimeBaglayici>(
  (ref) => ioSoketiAc,
  name: 'realtimeBaglayiciProvider',
);

/// Uygulamanın tek WebSocket bağlantısı (ADR-0007; kalıcı provider,
/// ADR-0001 kural 4).
///
/// Bağlantı yalnızca oturum açıkken ve kayıt tamamlanmışken
/// ([OturumDurumu.acik]) kurulur; oturum başka bir duruma geçince kapanır,
/// abonelikler ve bekleyen istekler bırakılır. Web geliştirme derlemesinde
/// hiç kurulmaz (tarayıcı `Authorization` başlığı ekleyemez; ADR-0011).
final realtimeIstemcisiProvider = Provider<RealtimeIstemcisi>((ref) {
  final oturum = ref.watch(sessionStoreProvider);
  final ad = istemciAdi(web: kIsWeb, platform: defaultTargetPlatform);
  final surum = surumBasligi(istemciAdi: ad, surum: uygulamaSurumu);
  final istemci = RealtimeIstemcisi(
    adres: realtimeAdresi(Uri.parse(apiTabanAdresi)),
    baglayici: ref.watch(realtimeBaglayiciProvider),
    tokenAl: oturum.erisimTokeni,
    reddedildi: oturum.reddedildi,
    oturumuKapat: () =>
        oturum.kapat(OturumKapanisNedeni.sunucuSonlandirdi),
    zamanlayici: ref.watch(zamanlayiciProvider),
    basliklar: {'X-Tayfam-Client-Version': ?surum},
  );
  ref.listen(oturumDurumuProvider, (_, durum) {
    if (durum == OturumDurumu.acik && !kIsWeb) {
      istemci.baslat();
    } else {
      istemci.durdur();
    }
  }, fireImmediately: true);
  ref.onDispose(() => unawaited(istemci.dispose()));
  return istemci;
}, name: 'realtimeIstemcisiProvider');

/// Bağlantının durumu (arayüz ve yenileme tetikleri için).
class RealtimeDurumuNotifier extends Notifier<RealtimeDurumu> {
  @override
  RealtimeDurumu build() {
    final istemci = ref.watch(realtimeIstemcisiProvider);
    final abonelik = istemci.durumlar.listen((d) => state = d);
    ref.onDispose(abonelik.cancel);
    return istemci.durum;
  }
}

/// Bağlantının durumu.
final realtimeDurumuProvider =
    NotifierProvider<RealtimeDurumuNotifier, RealtimeDurumu>(
      RealtimeDurumuNotifier.new,
      name: 'realtimeDurumuProvider',
    );

/// Kabuğun çevresine bir kez konur: bağlantıyı başlatır, uygulamanın ön
/// plan / arka plan geçişlerini bağlantıya iletir (arka planda 30 saniye
/// sonra kapanır) ve bağlantı kurulunca ya da uygulama ön plana dönünce
/// çevrimdışı kuyruktaki bekleyen işleri hemen dener (ADR-0006).
/// Kendisi bir şey çizmez.
class RealtimeBaglantisi extends ConsumerStatefulWidget {
  const RealtimeBaglantisi({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RealtimeBaglantisi> createState() => _RealtimeBaglantisiState();
}

class _RealtimeBaglantisiState extends ConsumerState<RealtimeBaglantisi> {
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    _dinleyici = AppLifecycleListener(
      onShow: () {
        ref.read(realtimeIstemcisiProvider).onPlana();
        ref.read(cevrimdisiKuyrukProvider.notifier).simdiDene();
      },
      onHide: () => ref.read(realtimeIstemcisiProvider).arkaPlana(),
    );
  }

  @override
  void dispose() {
    _dinleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(realtimeDurumuProvider, (_, durum) {
      if (durum == RealtimeDurumu.acik) {
        ref.read(cevrimdisiKuyrukProvider.notifier).simdiDene();
      }
    });
    return widget.child;
  }
}
