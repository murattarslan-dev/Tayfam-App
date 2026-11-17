import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Okunmamış bildirim sayısının yuvası (istemci ADR-0030). Sayı bildirim
/// özelliğinden gelir; tayfa ve Keşfet paketleri bildirim paketini import
/// etmez (ADR-0002). `shell/kayitlar.dart` override eder; varsayılanı 0'dır
/// ve 0 iken rozet gösterilmez.
final okunmamisBildirimYuvasiProvider = Provider<int>(
  (ref) => 0,
  name: 'okunmamisBildirimYuvasiProvider',
);

/// Rozette gösterilen en büyük sayı; üstü "99+" olur (ADR-0003).
const int rozetSiniri = 99;

/// Rozet metni: [sayi] ya da [rozetSiniri]'nın üstünde "99+".
String rozetMetni(AppLocalizations m, int sayi) =>
    sayi > rozetSiniri ? m.gezinme_rozet_cok : m.gezinme_rozet_sayi(sayi);

/// Üst çubuktaki bildirim zili (istemci ADR-0030): Tayfa sekmesinin
/// (tayfa ana sayfası, karşılama) ve Keşfet sekmesinin üst çubuğunda.
///
/// - Dokununca Bildirimler ekranı sekmelerin üstünde açılır
///   (`context.push`); geri tuşu açıldığı sekmeye döner.
/// - Okunmamış varsa ikonun üstünde sayı rozeti. Rozetteki sayı ekran
///   okuyucudan gizlenir; düğme "Bildirimler, 3 okunmamış bildirim" diye
///   okunur.
/// - Dokunma alanı en az 48 × 48 dp ([TayfamSizes.dokunmaMin]).
/// - İkon her zaman çizgi (outline) biçimindedir; okunmamış durumu
///   rozet taşır (aynı seviyede dolu/çizgi karışmaz).
/// - [markaYuzeyinde] mor üst bölüm içindir: ikon `markaYuzeyUstu`
///   (beyaz), rozet mango zemin + ink metin. Temanın nar rozeti mor
///   üzerinde 3:1'i tutmaz (2.1:1); mango 4.0:1, ink metin 9.8:1 (mor
///   yüzeyin odak rengiyle aynı token, ADR-0004 Notlar).
class BildirimZili extends ConsumerWidget {
  const BildirimZili({super.key, this.markaYuzeyinde = false});

  /// Mor marka yüzeyinde mi (tayfa ana sayfasının üst bölümü).
  final bool markaYuzeyinde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final sayi = ref.watch(okunmamisBildirimYuvasiProvider);
    final okunmamis = sayi > 0;
    final ikon = Icon(
      Icons.notifications_outlined,
      color: markaYuzeyinde ? r.markaYuzeyUstu : null,
    );
    final etiket = okunmamis
        ? m.bildirim_zili_okunmamis(sayi)
        : m.bildirimler_baslik;
    return Semantics(
      button: true,
      label: etiket,
      excludeSemantics: true,
      child: Tooltip(
        message: m.bildirimler_baslik,
        excludeFromSemantics: true,
        child: IconButton(
          key: const ValueKey('bildirim-zili'),
          constraints: const BoxConstraints(
            minWidth: TayfamSizes.dokunmaMin,
            minHeight: TayfamSizes.dokunmaMin,
          ),
          onPressed: () => unawaited(context.push(Adresler.bildirimler)),
          icon: okunmamis
              ? Badge(
                  backgroundColor: markaYuzeyinde ? r.mango : null,
                  textColor: markaYuzeyinde ? r.vurguUstu : null,
                  label: Text(rozetMetni(m, sayi)),
                  child: ikon,
                )
              : ikon,
        ),
      ),
    );
  }
}
