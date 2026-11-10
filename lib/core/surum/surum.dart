import 'package:flutter/foundation.dart';

/// Semantic Versioning 2.0.0 sürümü (`v` öneki yok), sözleşmedeki
/// `X-Tayfam-Client-Version` ve `client-config` kurallarıyla (Tayfam-Api
/// ADR-0016): ön sürüm, sürümün kendisinden düşüktür (`1.2.0-rc.1` <
/// `1.2.0`); derleme bilgisi (`+...`) karşılaştırmada sayılmaz.
///
/// Sayısal parçalar sayıya çevrilmeden (uzunluk, sonra harf sırası)
/// karşılaştırılır; böylece çok büyük değerlerde taşma olmaz.
@immutable
final class Surum implements Comparable<Surum> {
  const Surum._(this._cekirdek, this._onSurum);

  /// Sunucudan gelen değer girdi kabul edilir; makul bir üst sınır.
  static const int enUzun = 64;

  static final RegExp _bicim = RegExp(
    r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
    r'(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  static final RegExp _sayisal = RegExp(r'^[0-9]+$');

  /// Ana, ara ve yama parçaları (öndeki sıfır yok).
  final List<String> _cekirdek;

  /// Ön sürüm parçaları; yoksa boş.
  final List<String> _onSurum;

  /// Ön sürüm mü (`1.2.0-rc.1`).
  bool get onSurumMu => _onSurum.isNotEmpty;

  /// [metin]'i okur; SemVer 2.0.0 değilse `null`.
  static Surum? coz(String metin) {
    if (metin.isEmpty || metin.length > enUzun) return null;
    final eslesme = _bicim.firstMatch(metin);
    if (eslesme == null) return null;
    final onSurum = eslesme[4];
    return Surum._(
      [eslesme[1]!, eslesme[2]!, eslesme[3]!],
      onSurum == null ? const [] : onSurum.split('.'),
    );
  }

  @override
  int compareTo(Surum other) {
    for (var i = 0; i < 3; i++) {
      final fark = _sayiKarsilastir(_cekirdek[i], other._cekirdek[i]);
      if (fark != 0) return fark;
    }
    // Ön sürümü olmayan, olandan büyüktür.
    if (_onSurum.isEmpty && other._onSurum.isEmpty) return 0;
    if (_onSurum.isEmpty) return 1;
    if (other._onSurum.isEmpty) return -1;
    final ortak = _onSurum.length < other._onSurum.length
        ? _onSurum.length
        : other._onSurum.length;
    for (var i = 0; i < ortak; i++) {
      final fark = _parcaKarsilastir(_onSurum[i], other._onSurum[i]);
      if (fark != 0) return fark;
    }
    return _onSurum.length.compareTo(other._onSurum.length);
  }

  /// Bu sürüm [other]'dan düşük mü.
  bool operator <(Surum other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is Surum && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(_cekirdek), Object.hashAll(_onSurum));

  @override
  String toString() => [
    _cekirdek.join('.'),
    if (_onSurum.isNotEmpty) _onSurum.join('.'),
  ].join('-');

  static int _sayiKarsilastir(String a, String b) {
    if (a.length != b.length) return a.length.compareTo(b.length);
    return a.compareTo(b);
  }

  /// Ön sürüm parçası: sayısal olanlar sayı olarak, diğerleri ASCII
  /// sırasıyla; sayısal parça sayısal olmayandan küçüktür.
  static int _parcaKarsilastir(String a, String b) {
    final aSayi = _sayisal.hasMatch(a);
    final bSayi = _sayisal.hasMatch(b);
    if (aSayi && bSayi) return _sayiKarsilastir(a, b);
    if (aSayi) return -1;
    if (bSayi) return 1;
    return a.compareTo(b);
  }
}
