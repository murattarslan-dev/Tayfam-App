import 'package:flutter/material.dart';

import 'package:tayfam/l10n/app_localizations.dart';

/// Uygulamanın kökü.
///
/// Tema (#6) ve gezinme iskeleti (ADR-0003) ayrı iş paketlerinde gelir;
/// şimdilik yalnızca çeviri altyapısını (ADR-0008) ve tek bir karşılama
/// ekranını taşır.
class TayfamApp extends StatelessWidget {
  const TayfamApp({super.key, this.themeMode = ThemeMode.system});

  /// Açık / koyu tema seçimi. Kullanıcı ayarı gelene kadar sistemi izler;
  /// testler iki temayı da bu alanla dener.
  final ThemeMode themeMode;

  /// Varsayılan ve şimdilik tek yerel ayar (ADR-0008). Cihaz başka bir
  /// dilde olsa da arayüz Türkçe gösterilir.
  static const Locale yerelAyar = Locale('tr', 'TR');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).uygulama_adi,
      locale: yerelAyar,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      home: const _KarsilamaEkrani(),
    );
  }
}

class _KarsilamaEkrani extends StatelessWidget {
  const _KarsilamaEkrani();

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            metinler.karsilama_metni,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
