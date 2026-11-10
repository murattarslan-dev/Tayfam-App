import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/http_tasima.dart';

/// API taban adresi: derleme zamanında `--dart-define=TAYFAM_API=...`
/// (ADR-0005). Verilmezse dev ortamı. Yalnızca `https` kabul edilir
/// ([HttpTasima] doğrular). İstemciye gömülen adres public sayılır.
const String apiTabanAdresi = String.fromEnvironment(
  'TAYFAM_API',
  defaultValue: 'https://api-dev.tayfam.app',
);

/// `X-Tayfam-Client` değeri: web geliştirme derlemesinde `web`
/// (ADR-0011), iOS'ta `ios`, diğer her yerde `android`.
String istemciAdi({required bool web, required TargetPlatform platform}) {
  if (web) return 'web';
  return platform == TargetPlatform.iOS ? 'ios' : 'android';
}

/// Uygulamanın tek `http.Client`'ı; provider bırakılınca kapanır.
final httpClientProvider = Provider<http.Client>(
  _httpClientOlustur,
  name: 'httpClientProvider',
);

http.Client _httpClientOlustur(Ref ref) {
  final istemci = http.Client();
  ref.onDispose(istemci.close);
  return istemci;
}

/// Ham HTTP katmanı. Özellikler bunu değil `apiClientProvider`'ı kullanır.
final httpTasimaProvider = Provider<HttpTasima>(
  (ref) => HttpTasima(
    istemci: ref.watch(httpClientProvider),
    tabanAdres: Uri.parse(apiTabanAdresi),
    istemciAdi: istemciAdi(web: kIsWeb, platform: defaultTargetPlatform),
  ),
  name: 'httpTasimaProvider',
);
