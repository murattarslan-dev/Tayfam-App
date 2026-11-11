import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/core/cihaz/gecici_dosyalar.dart';
import 'package:tayfam/shell/kayitlar.dart';

void main() {
  // Önceki oturumdan kalmış paylaşım dosyaları (ADR-0022).
  unawaited(artikGeciciDosyalariTemizle());
  runApp(ProviderScope(overrides: kayitOverridelari, child: const TayfamApp()));
}
