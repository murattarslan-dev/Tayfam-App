// ARB (ADR-0008) ve pubspec.yaml (ADR-0001, 0004, 0005, 0006, 0008)
// kuralları.

import 'dart:convert';

import 'package:yaml/yaml.dart';

import 'android_metinleri.dart';
import 'bulgu.dart';

/// Kaynak (şablon) ARB dosyası (l10n.yaml: template-arb-file).
const String sablonArb = 'lib/l10n/app_tr.arb';

final RegExp _snakeCase = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$');

/// ARB kuralları. [kullanilanAdlar], lib/ altındaki koddaki (üretilmiş
/// dahil) `.ad` erişimlerindeki adlardır.
List<Bulgu> arbKurallari({
  required Map<String, String> arbDosyalari,
  required Set<String> kullanilanAdlar,
}) {
  final bulgular = <Bulgu>[];
  final yollar = arbDosyalari.keys.toList()..sort();
  for (final yol in yollar) {
    final metin = arbDosyalari[yol]!;
    final Object? belge;
    try {
      belge = jsonDecode(metin);
    } on FormatException catch (e) {
      bulgular.add(
        Bulgu(
          kural: Kurallar.arbAciklama,
          yol: yol,
          satir: 1,
          mesaj: 'ARB JSON olarak okunamadı: ${e.message}',
        ),
      );
      continue;
    }
    if (belge is! Map<String, Object?>) {
      continue;
    }
    for (final anahtar in belge.keys) {
      if (anahtar.startsWith('@')) {
        continue;
      }
      final satir = _anahtarSatiri(metin, anahtar);
      if (!_snakeCase.hasMatch(anahtar)) {
        bulgular.add(
          Bulgu(
            kural: Kurallar.arbAnahtarAdi,
            yol: yol,
            satir: satir,
            mesaj: "'$anahtar' snake_case değil (ör. etkinlik_katilim_sayisi).",
          ),
        );
      }
      if (yol != sablonArb) {
        continue;
      }
      final ek = belge['@$anahtar'];
      final aciklama = ek is Map<String, Object?> ? ek['description'] : null;
      if (aciklama is! String || aciklama.trim().isEmpty) {
        bulgular.add(
          Bulgu(
            kural: Kurallar.arbAciklama,
            yol: yol,
            satir: satir,
            mesaj:
                "'$anahtar' için @$anahtar.description yok; çevirmen için "
                'metnin ne zaman ve nerede görüldüğünü yaz.',
          ),
        );
      }
      // Push metinleri kodda değil Android string kaynağında kullanılır;
      // güncelliğini android-metinleri kuralı denetler.
      if (!kullanilanAdlar.contains(anahtar) &&
          !androidMetinAnahtari.hasMatch(anahtar)) {
        bulgular.add(
          Bulgu(
            kural: Kurallar.arbKullanilmayan,
            yol: yol,
            satir: satir,
            mesaj: "'$anahtar' kodda kullanılmıyor.",
          ),
        );
      }
    }
  }
  return bulgular;
}

int _anahtarSatiri(String metin, String anahtar) {
  final i = metin.indexOf('"$anahtar"');
  if (i < 0) {
    return 1;
  }
  return '\n'.allMatches(metin.substring(0, i)).length + 1;
}

/// pubspec.yaml'da bulunmaması gereken paketler.
const Map<String, (KuralTanimi, String)> yasakPaketler = {
  'google_fonts': (Kurallar.googleFonts, 'ADR-0004 §1: font gömülüdür'),
  'shared_preferences': (Kurallar.diskeYazma, 'ADR-0006: diske içerik yok'),
  'path_provider': (Kurallar.diskeYazma, 'ADR-0006: diske içerik yok'),
  'sqflite': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'hive': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'hive_flutter': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'isar': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'drift': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'sembast': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'get_storage': (Kurallar.diskeYazma, 'ADR-0006: disk önbelleği yok'),
  'riverpod_generator': (Kurallar.kodUretimi, 'ADR-0001 kural 2'),
  'riverpod_annotation': (Kurallar.kodUretimi, 'ADR-0001 kural 2'),
  'build_runner': (Kurallar.kodUretimi, 'ADR-0005 §1'),
  'freezed': (Kurallar.kodUretimi, 'ADR-0005 §1'),
  'freezed_annotation': (Kurallar.kodUretimi, 'ADR-0005 §1'),
  'json_serializable': (Kurallar.kodUretimi, 'ADR-0005 §1'),
  'json_annotation': (Kurallar.kodUretimi, 'ADR-0005 §1'),
  'get_it': (Kurallar.yasakPaket, 'ADR-0001: DI Riverpod ile'),
  'provider': (Kurallar.yasakPaket, 'ADR-0001: durum Riverpod ile'),
  'bloc': (Kurallar.yasakPaket, 'ADR-0001: durum Riverpod ile'),
  'flutter_bloc': (Kurallar.yasakPaket, 'ADR-0001: durum Riverpod ile'),
  'dio': (Kurallar.yasakPaket, 'ADR-0005 §2: http paketi seçildi'),
  'easy_localization': (Kurallar.yasakPaket, 'ADR-0008: gen_l10n seçildi'),
};

const List<String> _bolumler = [
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// pubspec.yaml kuralları.
List<Bulgu> pubspecKurallari(String metin, {String yol = 'pubspec.yaml'}) {
  final bulgular = <Bulgu>[];
  final Object? belge;
  try {
    belge = loadYaml(metin);
  } on YamlException {
    return bulgular;
  }
  if (belge is! Map<Object?, Object?>) {
    return bulgular;
  }
  for (final bolum in _bolumler) {
    final paketler = belge[bolum];
    if (paketler is! Map<Object?, Object?>) {
      continue;
    }
    for (final ad in paketler.keys.whereType<String>()) {
      final yasak = yasakPaketler[ad];
      if (yasak == null) {
        continue;
      }
      final (kural, gerekce) = yasak;
      bulgular.add(
        Bulgu(
          kural: kural,
          yol: yol,
          satir: _paketSatiri(metin, ad),
          mesaj: "'$ad' ($bolum) kullanılmaz: $gerekce.",
        ),
      );
    }
  }
  return bulgular;
}

int _paketSatiri(String metin, String ad) {
  final satirlar = metin.split('\n');
  final kalip = RegExp('^\\s+${RegExp.escape(ad)}\\s*:');
  for (var i = 0; i < satirlar.length; i++) {
    if (kalip.hasMatch(satirlar[i])) {
      return i + 1;
    }
  }
  return 1;
}
