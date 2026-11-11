import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/core/cihaz/gecici_dosyalar.dart';
import 'package:tayfam/core/push/firebase_push_platformu.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/shell/kayitlar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Önceki oturumdan kalmış paylaşım dosyaları (ADR-0022).
  unawaited(artikGeciciDosyalariTemizle());
  runApp(
    ProviderScope(
      overrides: [
        ...kayitOverridelari,
        // Push yalnızca mobilde (istemci ADR-0019; ADR-0011): web
        // geliştirme derlemesinde Firebase başlatılmaz.
        if (!kIsWeb)
          pushPlatformuProvider.overrideWithValue(FirebasePushPlatformu()),
      ],
      child: const TayfamApp(),
    ),
  );
}
