import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/yonlendirici.dart';

/// Uygulamanın kökü.
///
/// Gezinme iskeleti (ADR-0003) `shell/yonlendirici.dart`'tan, tema
/// (ADR-0004) `core/tema/`'dan gelir.
class TayfamApp extends ConsumerWidget {
  const TayfamApp({super.key, this.themeMode});

  /// Açık / koyu tema seçimi. Verilmezse kullanıcının profildeki seçimi
  /// ([temaTercihiProvider]; varsayılanı sistemi izlemek) kullanılır;
  /// testler iki temayı da bu alanla dener.
  final ThemeMode? themeMode;

  /// Varsayılan ve şimdilik tek yerel ayar (ADR-0008). Cihaz başka bir
  /// dilde olsa da arayüz Türkçe gösterilir.
  static const Locale yerelAyar = Locale('tr', 'TR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Push (istemci ADR-0019): uygulama açılınca altyapı başlar, kanallar
    // kurulur ve token oturumla eşitlenir. Push'suz derlemede (web, test)
    // hiç kurulmaz.
    if (ref.watch(pushPlatformuProvider).etkin) ref.watch(pushKaydiProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).uygulama_adi,
      locale: yerelAyar,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: TayfamTheme.acik(),
      darkTheme: TayfamTheme.koyu(),
      themeMode: themeMode ?? ref.watch(temaTercihiProvider).themeMode,
      routerConfig: ref.watch(yonlendiriciProvider),
    );
  }
}
