import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';

/// Hoş geldin tanıtımının bu cihazdaki durumu (ADR-0017 §1).
enum TanitimDurumu {
  /// Güvenli depodaki bayrak henüz okunmadı; açılış ekranı.
  yukleniyor,

  /// Tanıtım bu cihazda gösterilmedi; oturum yoksa gösterilir.
  gosterilmedi,

  /// Tanıtım gösterildi (atlandı ya da tamamlandı); bir daha gösterilmez.
  gosterildi,
}

/// Tanıtım durumunu tutan notifier (ADR-0017 §1).
///
/// Bayrak cihaza aittir ([CihazBayragi.tanitimGosterildi]): oturum durumunu
/// izlemez, oturum kapanınca sıfırlanmaz ve depodaki kayıt silinmez.
///
/// Depo okunamazsa tanıtım gösterilmiş sayılır: tanıtım girişin önünde
/// durmamalı; en kötü durumda kullanıcı onu görmeden girişe geçer.
class TanitimNotifier extends Notifier<TanitimDurumu> {
  @override
  TanitimDurumu build() {
    unawaited(_oku());
    return TanitimDurumu.yukleniyor;
  }

  CihazAyarlariDeposu get _depo => ref.read(cihazAyarlariDeposuProvider);

  Future<void> _oku() async {
    final gosterildi = await _gosterildiMi();
    // Beklerken tanıtım tamamlandıysa o daha yenidir.
    if (!ref.mounted || state != TanitimDurumu.yukleniyor) return;
    state = gosterildi ? TanitimDurumu.gosterildi : TanitimDurumu.gosterilmedi;
  }

  Future<bool> _gosterildiMi() async {
    try {
      return await _depo.bayrakOku(CihazBayragi.tanitimGosterildi);
    } on Exception {
      return true;
    }
  }

  /// Tanıtım atlandı ya da "Başlayalım"a dokunuldu: bayrak konur ve
  /// yönlendirme girişe geçer. Bayrak yazılamazsa bu çalışmada yine
  /// gösterilmiş sayılır; sonraki açılışta tanıtım bir kez daha görünür.
  void tamamla() {
    state = TanitimDurumu.gosterildi;
    unawaited(_koySessiz());
  }

  Future<void> _koySessiz() async {
    try {
      await _depo.bayrakKoy(CihazBayragi.tanitimGosterildi);
    } on Exception {
      // Bkz. [tamamla].
    }
  }
}

/// Uygulama boyunca yaşayan tanıtım durumu (kalıcı; `autoDispose` değil).
final tanitimProvider = NotifierProvider<TanitimNotifier, TanitimDurumu>(
  TanitimNotifier.new,
  name: 'tanitimProvider',
);
