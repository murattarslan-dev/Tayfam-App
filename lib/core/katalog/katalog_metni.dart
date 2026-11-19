import 'package:flutter/widgets.dart';

/// Katalog metinlerinin (tür, ilgi alanı, alan ve seçenek adları) en çok
/// uzunluğu (sözleşme: `CatalogLabels`, 1–60 karakter).
const int katalogMetniEnCok = 60;

/// Katalog metinlerinin her zaman bulunan dili (sözleşme).
const String katalogVarsayilanDil = 'tr';

final RegExp _bosluklar = RegExp(r'\s+');

/// Görünmeyen ve yön değiştiren karakterler: denetim karakterleri, sıfır
/// genişlikli boşluklar ve çift yönlü metin işaretleri. Katalog metni
/// arayüzde başka bir metin gibi görünemesin diye atılır.
final RegExp _gorunmeyenler = RegExp(
  r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F'
  r'\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
);

/// Katalog metnini gösterime hazırlar (ADR-0024 §2): içerik gibi işlenir.
/// Düz metindir (biçim ya da bağlantı yorumlanmaz; bunu gösteren `Text`
/// sağlar), tek satıra indirilir ve [enCok] karakterde kırpılır (kırpılan
/// metnin sonuna `…` gelir). Boş kalan metin `null` döner.
String? katalogDuzMetni(String? ham, {int enCok = katalogMetniEnCok}) {
  if (ham == null) return null;
  final tekSatir = ham
      .replaceAll(_gorunmeyenler, '')
      .replaceAll(_bosluklar, ' ')
      .trim();
  if (tekSatir.isEmpty) return null;
  final harfler = tekSatir.runes;
  if (harfler.length <= enCok) return tekSatir;
  return '${String.fromCharCodes(harfler.take(enCok)).trimRight()}…';
}

/// [adlar] (dil → metin) içinden [dil]'deki metin; yoksa `tr`
/// (ADR-0024 §2). İkisi de yoksa ya da boşsa `null`. Sonuç
/// [katalogDuzMetni]'nden geçer.
String? katalogAdi(Map<String, String>? adlar, String dil) {
  if (adlar == null) return null;
  return katalogDuzMetni(adlar[dil]) ??
      katalogDuzMetni(adlar[katalogVarsayilanDil]);
}

/// Uygulamanın yerel ayarının dil kodu (`tr`); katalog metni bununla
/// seçilir.
String katalogDili(BuildContext context) =>
    Localizations.localeOf(context).languageCode;
