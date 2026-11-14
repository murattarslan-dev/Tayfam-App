import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dört sekmeli kabuğun çevresine eklenen katman: kabuk açıkken (oturum
/// açık) yaşayan ve kabuğun gezinme bağlamını kullanan bir widget (ör.
/// girişten sonra profil tamamlama formunu açan istem; issue #186).
typedef KabukKatmani = Widget Function(Widget kabuk);

/// Uygulamaya kayıtlı kabuk katmanları. Özellikler `shell/kayitlar.dart`'ta
/// override eder; kabuk onları import etmez (ADR-0002). Varsayılanı boştur
/// (testlerde katman yok).
final kabukKatmanlariProvider = Provider<List<KabukKatmani>>(
  (ref) => const [],
  name: 'kabukKatmanlariProvider',
);
