import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kaynak ARB (lib/l10n/app_tr.arb).
Map<String, Object?> _arb() {
  final kaynak = File('lib/l10n/app_tr.arb').readAsStringSync();
  return jsonDecode(kaynak) as Map<String, Object?>;
}

/// Sözleşmedeki koda karşılık gelen ARB anahtarı (ADR-0008).
String _anahtar(ProblemType type) => 'hata_${type.wire.replaceAll('-', '_')}';

void main() {
  final arb = _arb();
  final tr = lookupAppLocalizations(const Locale('tr'));
  final kodlar = ProblemType.values.where((t) => t != ProblemType.unknown);

  test('sözleşmedeki 122 kodun hepsi var', () {
    expect(kodlar, hasLength(122));
  });

  group('her kodun anahtarı', () {
    for (final type in kodlar) {
      test('${type.wire} → ${_anahtar(type)}', () {
        final anahtar = _anahtar(type);
        final metin = arb[anahtar];
        expect(metin, isA<String>(), reason: '$anahtar ARB\'de yok');
        expect((metin! as String).trim(), isNotEmpty);

        final ek = arb['@$anahtar'];
        expect(ek, isA<Map<String, Object?>>());
        final aciklama = (ek! as Map<String, Object?>)['description'];
        expect(aciklama, isA<String>());
        expect(aciklama! as String, contains('`${type.wire}`'));

        // Eşleme kodu kendi anahtarına götürüyor.
        expect(problemMetni(tr, type), metin);
      });
    }
  });

  test('ARB\'de sözleşmede olmayan hata anahtarı yok', () {
    final beklenen = {
      for (final type in kodlar) _anahtar(type),
      'hata_genel',
      'hata_baglanti_yok',
      'hata_zaman_asimi',
      'hata_sunucu_ulasilamiyor',
    };
    final hataAnahtarlari = arb.keys.where((k) => k.startsWith('hata_'));
    expect(hataAnahtarlari.toSet(), beklenen);
  });

  test('metinler kullanıcıya teknik kod göstermiyor', () {
    final durumKodu = RegExp(r'\b[45]\d\d\b');
    for (final type in kodlar) {
      final metin = problemMetni(tr, type);
      for (final kod in kodlar) {
        expect(metin, isNot(contains(kod.wire)), reason: metin);
      }
      expect(durumKodu.hasMatch(metin), isFalse, reason: metin);
    }
  });

  test('problem gövdesiz ağ geçidi hatası sunucu metnine düşüyor', () {
    for (final status in [502, 503, 504, 520, 530]) {
      expect(
        hataMetni(tr, ApiProblem(type: ProblemType.unknown, status: status)),
        arb['hata_sunucu_ulasilamiyor'],
        reason: '$status',
      );
    }
    // Sunucunun kendi problem cevabı kendi metnini alır.
    expect(
      hataMetni(
        tr,
        const ApiProblem(type: ProblemType.unavailable, status: 503),
      ),
      arb['hata_unavailable'],
    );
    expect(sunucuUlasilamiyorMu(500), isFalse);
    expect(sunucuUlasilamiyorMu(531), isFalse);
  });

  test('bilinmeyen kod genel metne düşüyor', () {
    expect(problemMetni(tr, ProblemType.unknown), arb['hata_genel']);
    expect(
      hataMetni(tr, const ApiProblem(type: ProblemType.unknown, status: 500)),
      arb['hata_genel'],
    );
    expect(
      hataMetni(tr, ApiProblem(type: problemTypeOku('baska'), status: 418)),
      arb['hata_genel'],
    );
  });

  test('ağ hataları kendi metinlerini alıyor', () {
    expect(hataMetni(tr, const ApiOffline()), arb['hata_baglanti_yok']);
    expect(hataMetni(tr, const ApiTimeout()), arb['hata_zaman_asimi']);
  });

  test('problem kendi koduyla gösteriliyor', () {
    const problem = ApiProblem(type: ProblemType.rateLimited, status: 429);
    expect(hataMetni(tr, problem), arb['hata_rate_limited']);
  });

  test('beklenmeyen hata genel metne düşüyor', () {
    expect(hataMetni(tr, const FormatException('x')), arb['hata_genel']);
    expect(hataMetni(tr, StateError('x')), arb['hata_genel']);
  });
}
