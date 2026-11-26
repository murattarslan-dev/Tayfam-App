import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/hesap/application/giris_notifier.dart';
import 'package:tayfam/features/hesap/presentation/apple_dugmesi.dart';

/// "Apple ile devam et" (Design: Giriş iOS; ADR-0034 §5, Tayfam-Api
/// ADR-0045).
///
/// Giriş ekranı iOS'ta Apple düğmesini Google'ın üstünde gösterir
/// ([appleGirisiGorunur]); başka platformda düğme yoktur. Düğme Apple'ın
/// yerel düğmesidir ([AppleIleDevamDugmesi]).

/// Apple ile giriş düğmesini çizen fonksiyon: dokununca Apple ile girişi
/// başlatır ([GirisNotifier.appleIleGirisYap]).
final appleGirisDugmesiProvider = Provider<WidgetBuilder?>(
  (ref) =>
      (context) => AppleIleDevamDugmesi(
        onPressed: () =>
            unawaited(ref.read(girisProvider.notifier).appleIleGirisYap()),
      ),
  name: 'appleGirisDugmesiProvider',
);

/// Apple düğmesi gösterilsin mi: yalnızca iOS'ta ve düğme verilmişse.
bool appleGirisiGorunur({
  required TargetPlatform platform,
  required WidgetBuilder? dugme,
}) {
  return platform == TargetPlatform.iOS && dugme != null;
}
