/// Süre yazımı (#278'de derece bileşeninde doğdu; istatistik de kullanır,
/// #250): Türkçe biçimli `1:02:03,45` ve ekran okuyucu metni.
library;

import 'package:tayfam/l10n/app_localizations.dart';

/// Santisaniye: saniyenin yüzde biri.
const int _santi = 100;

/// Sürenin parçaları (santisaniyeye yuvarlanmış).
({int saat, int dakika, int saniye, int santi}) _sureParcalari(double sn) {
  final toplam = (sn * _santi).round();
  return (
    saat: toplam ~/ (3600 * _santi),
    dakika: (toplam ~/ (60 * _santi)) % 60,
    saniye: (toplam ~/ _santi) % 60,
    santi: toplam % _santi,
  );
}

String _ikiHane(int sayi) => sayi.toString().padLeft(2, '0');

/// Sürenin Türkçe yazımı: bir saatten uzunsa `1:02:03,45`, değilse
/// `2:03,45`; salise yoksa ondalık kısım yazılmaz (`45:00`).
String sureMetni(AppLocalizations m, double saniye) {
  if (!saniye.isFinite) return '';
  final p = _sureParcalari(saniye);
  final ana = p.saat > 0
      ? '${p.saat}:${_ikiHane(p.dakika)}:${_ikiHane(p.saniye)}'
      : '${p.dakika}:${_ikiHane(p.saniye)}';
  return p.santi == 0
      ? ana
      : '$ana${m.katalog_ondalik_ayraci}${_ikiHane(p.santi)}';
}

/// Sürenin ekran okuyucu metni: "1 saat 2 dakika 3,45 saniye".
String sureOkunusu(AppLocalizations m, double saniye) {
  if (!saniye.isFinite) return '';
  final p = _sureParcalari(saniye);
  final sn = p.santi == 0
      ? '${p.saniye}'
      : '${p.saniye}${m.katalog_ondalik_ayraci}${_ikiHane(p.santi)}';
  return [
    if (p.saat > 0) m.bilesen_ranking_saat(p.saat),
    if (p.dakika > 0) m.bilesen_ranking_dakika(p.dakika),
    if (p.saniye > 0 || p.santi > 0 || (p.saat == 0 && p.dakika == 0))
      m.bilesen_ranking_saniye(sn),
  ].join(' ');
}
