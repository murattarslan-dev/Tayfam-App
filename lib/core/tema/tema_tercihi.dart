import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tayfam/core/guvenli_depo/guvenli_okuma.dart';

/// Kullanıcının tema seçimi (ADR-0018 §2): sistemi izle, açık ya da koyu.
enum TemaTercihi {
  /// Cihazın açık / koyu ayarını izler (varsayılan).
  sistem('sistem', ThemeMode.system),

  /// Her zaman açık tema.
  acik('acik', ThemeMode.light),

  /// Her zaman koyu tema.
  koyu('koyu', ThemeMode.dark);

  const TemaTercihi(this.kayit, this.themeMode);

  /// Depoya yazılan değer.
  final String kayit;

  /// `MaterialApp.themeMode` karşılığı.
  final ThemeMode themeMode;

  /// Depodaki [metin]'i okur; yoksa ya da tanınmıyorsa [sistem].
  static TemaTercihi coz(String? metin) {
    for (final tercih in values) {
      if (tercih.kayit == metin) return tercih;
    }
    return sistem;
  }
}

/// Tema seçiminin tek kalıcı yeri.
///
/// Yalnızca üç değerden biri tutulur; ADR-0006'nın "kullanıcı ayarları"
/// istisnasıdır. Seçim cihaza aittir: kişisel veri değildir, oturum
/// kapanınca silinmez.
abstract interface class TemaTercihiDeposu {
  /// Kayıtlı değeri okur; yoksa `null`.
  Future<String?> oku();

  /// Değeri yazar (öncekinin yerine).
  Future<void> yaz(String deger);
}

/// Mobil: Android Keystore / iOS Keychain (`flutter_secure_storage`).
/// Çözülemeyen kayıt okunurken silinir ve yok sayılır ([guvenliOku]).
///
/// iOS'ta öteki kayıtlarla aynı erişim sınıfı (`first_unlock_this_device`):
/// yedeğe ve başka cihaza geçmez.
final class GuvenliTemaTercihiDeposu implements TemaTercihiDeposu {
  GuvenliTemaTercihiDeposu([FlutterSecureStorage? depo])
    : _depo =
          depo ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _depo;

  static const String _anahtar = 'tayfam.tema';

  @override
  Future<String?> oku() => guvenliOku(_depo, _anahtar);

  @override
  Future<void> yaz(String deger) => _depo.write(key: _anahtar, value: deger);
}

/// Web geliştirme derlemesi ve testler: yalnızca bellek; tarayıcı deposuna
/// hiçbir şey yazılmaz (ADR-0011).
final class BellekTemaTercihiDeposu implements TemaTercihiDeposu {
  BellekTemaTercihiDeposu([this._kayit]);

  String? _kayit;

  /// Testlerde kaydı görmek için.
  String? get kayit => _kayit;

  @override
  Future<String?> oku() async => _kayit;

  @override
  Future<void> yaz(String deger) async {
    _kayit = deger;
  }
}

/// Platforma göre depo: web'de bellek, mobilde güvenli depo.
final temaTercihiDeposuProvider = Provider<TemaTercihiDeposu>(
  (ref) => kIsWeb ? BellekTemaTercihiDeposu() : GuvenliTemaTercihiDeposu(),
  name: 'temaTercihiDeposuProvider',
);

/// Uygulamanın tema seçimi.
///
/// İlk değer [TemaTercihi.sistem]'dir; depodaki kayıt okununca ona geçer.
/// Depo okunamazsa ya da yazılamazsa seçim bu çalışmada bellekte geçerli
/// kalır; hata gösterilmez (tema içerik değildir).
class TemaTercihiNotifier extends Notifier<TemaTercihi> {
  bool _secildi = false;

  @override
  TemaTercihi build() {
    unawaited(_yukle(ref.watch(temaTercihiDeposuProvider)));
    return TemaTercihi.sistem;
  }

  Future<void> _yukle(TemaTercihiDeposu depo) async {
    TemaTercihi kayitli;
    try {
      kayitli = TemaTercihi.coz(await depo.oku());
    } on Exception {
      return;
    }
    // Okuma sürerken kullanıcı seçtiyse onun seçimi daha yenidir.
    if (ref.mounted && !_secildi) state = kayitli;
  }

  /// Temayı [tercih] yapar ve kaydeder.
  Future<void> sec(TemaTercihi tercih) async {
    _secildi = true;
    state = tercih;
    try {
      await ref.read(temaTercihiDeposuProvider).yaz(tercih.kayit);
    } on Exception {
      // Bu çalışmada bellekteki seçim geçerli kalır.
    }
  }
}

/// Uygulama boyunca yaşayan tema seçimi (kalıcı; ADR-0001 kural 4).
final temaTercihiProvider = NotifierProvider<TemaTercihiNotifier, TemaTercihi>(
  TemaTercihiNotifier.new,
  name: 'temaTercihiProvider',
);
