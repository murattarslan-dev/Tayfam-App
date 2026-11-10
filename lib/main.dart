import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/shell/kayitlar.dart';

void main() {
  runApp(ProviderScope(overrides: kayitOverridelari, child: const TayfamApp()));
}
