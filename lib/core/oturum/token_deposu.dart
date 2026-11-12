import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tayfam/core/guvenli_depo/guvenli_okuma.dart';

/// Depoda tutulan oturum kaydı: token çifti, süreleri ve yönlendirmenin
/// ihtiyaç duyduğu iki bayrak (ADR-0005, ADR-0006) ve sunucunun bildirdiği
/// bir sonraki bütünlük denetimi zamanı (istemci ADR-0023 §4).
///
/// Kullanıcı içeriği taşımaz. `toString` token yazmaz.
@immutable
final class KayitliOturum {
  const KayitliOturum({
    required this.erisimTokeni,
    required this.erisimBitis,
    required this.yenilemeTokeni,
    required this.yenilemeBitis,
    required this.kayitBekliyor,
    required this.onayGerekli,
    this.kullaniciId,
    this.butunlukSonrasi,
  });

  final String erisimTokeni;
  final DateTime erisimBitis;
  final String yenilemeTokeni;
  final DateTime yenilemeBitis;

  /// `registration_pending`: kayıt tamamlanmadı.
  final bool kayitBekliyor;

  /// `consent_required`: güncel metinler onaylanmadı.
  final bool onayGerekli;

  /// Oturumun kullanıcısı (`Session.user_id`). Bu alan eklenmeden önce
  /// yazılmış kayıtta yoktur; ilk yenilemede gelir.
  final String? kullaniciId;

  /// `integrity_check_after`: bu zamandan sonraki ilk yenileme bütünlük
  /// kanıtı taşır. Bütünlük denetimi kapalıysa ya da kayıt bu alan
  /// eklenmeden önce yazıldıysa `null` (kanıt gönderilmez).
  final DateTime? butunlukSonrasi;

  /// Depodaki tek kayda yazılan biçim.
  String kodla() => jsonEncode({
    'v': 1,
    'erisim': erisimTokeni,
    'erisim_bitis': erisimBitis.toUtc().toIso8601String(),
    'yenileme': yenilemeTokeni,
    'yenileme_bitis': yenilemeBitis.toUtc().toIso8601String(),
    'kayit_bekliyor': kayitBekliyor,
    'onay_gerekli': onayGerekli,
    'kullanici': ?kullaniciId,
    'butunluk_sonra': ?butunlukSonrasi?.toUtc().toIso8601String(),
  });

  /// [kodla] çıktısını okur; bozuk ya da tanınmayan kayıtta `null` döner.
  static KayitliOturum? coz(String metin) {
    try {
      final json = jsonDecode(metin);
      if (json is! Map<String, Object?> || json['v'] != 1) return null;
      final erisim = json['erisim'];
      final erisimBitis = json['erisim_bitis'];
      final yenileme = json['yenileme'];
      final yenilemeBitis = json['yenileme_bitis'];
      final kayitBekliyor = json['kayit_bekliyor'];
      final onayGerekli = json['onay_gerekli'];
      final kullanici = json['kullanici'];
      final butunlukSonra = json['butunluk_sonra'];
      if (erisim is! String ||
          erisimBitis is! String ||
          yenileme is! String ||
          yenilemeBitis is! String ||
          kayitBekliyor is! bool ||
          onayGerekli is! bool ||
          erisim.isEmpty ||
          yenileme.isEmpty) {
        return null;
      }
      return KayitliOturum(
        erisimTokeni: erisim,
        erisimBitis: DateTime.parse(erisimBitis).toUtc(),
        yenilemeTokeni: yenileme,
        yenilemeBitis: DateTime.parse(yenilemeBitis).toUtc(),
        kayitBekliyor: kayitBekliyor,
        onayGerekli: onayGerekli,
        kullaniciId: kullanici is String && kullanici.isNotEmpty
            ? kullanici
            : null,
        butunlukSonrasi: butunlukSonra is String
            ? DateTime.tryParse(butunlukSonra)?.toUtc()
            : null,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'KayitliOturum(…)';
}

/// Oturum kaydının tek kalıcı yeri. Yalnızca `SessionStore` kullanır.
abstract interface class TokenDeposu {
  /// Kaydı okur; yoksa `null`.
  Future<String?> oku();

  /// Kaydı yazar (öncekinin yerine).
  Future<void> yaz(String kayit);

  /// Kaydı siler.
  Future<void> sil();
}

/// Mobil: Android Keystore / iOS Keychain (`flutter_secure_storage`).
/// Çözülemeyen kayıt okunurken silinir ve yok sayılır ([guvenliOku]).
///
/// iOS'ta `first_unlock_this_device`: cihaz ilk kez açıldıktan sonra arka
/// planda da okunabilir, yedeğe ve başka cihaza geçmez (ADR-0005).
final class GuvenliTokenDeposu implements TokenDeposu {
  GuvenliTokenDeposu([FlutterSecureStorage? depo])
    : _depo =
          depo ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _depo;

  static const String _anahtar = 'tayfam.oturum';

  @override
  Future<String?> oku() => guvenliOku(_depo, _anahtar);

  @override
  Future<void> yaz(String kayit) => _depo.write(key: _anahtar, value: kayit);

  @override
  Future<void> sil() => _depo.delete(key: _anahtar);
}

/// Web geliştirme derlemesi: yalnızca bellek; sayfa yenilenince oturum
/// gider, tarayıcı deposuna hiçbir şey yazılmaz (ADR-0011). Testlerde de
/// sahte depo olarak kullanılır.
final class BellekTokenDeposu implements TokenDeposu {
  String? _kayit;

  @override
  Future<String?> oku() async => _kayit;

  @override
  Future<void> yaz(String kayit) async {
    _kayit = kayit;
  }

  @override
  Future<void> sil() async {
    _kayit = null;
  }
}

/// Platforma göre token deposu: web'de bellek, mobilde güvenli depo.
final tokenDeposuProvider = Provider<TokenDeposu>(
  (ref) => kIsWeb ? BellekTokenDeposu() : GuvenliTokenDeposu(),
  name: 'tokenDeposuProvider',
);
