// Push bildirimlerinin Android string kaynakları (istemci ADR-0019 §4).
//
// FCM bildirimi uygulama kapalıyken Android gösterir; başlık ve gövde
// sunucunun gönderdiği `title_loc_key` / `body_loc_key` adlarıyla
// (`push_<tür>_title`, `push_<tür>_body`) uygulamanın string
// kaynaklarından okunur (Tayfam-Api ADR-0019 §4). Metinlerin tek kaynağı
// ARB'dir: bu anahtarlar `android/app/src/main/res/values/strings.xml`'e
// buradaki üreticiyle yazılır ve kural betiği dosyanın güncel olduğunu
// denetler.
//
//   dart run tool/kurallar/bin/android_metinleri.dart

import 'dart:convert';

import 'bulgu.dart';

/// Üretilen Android string kaynağı.
const String androidMetinDosyasi =
    'android/app/src/main/res/values/strings.xml';

/// ARB'de Android'e giden anahtarlar: `push_<tür>_title|body`.
final RegExp androidMetinAnahtari = RegExp(r'^push_[a-z0-9_]+_(?:title|body)$');

/// [arbMetni]'ndeki (kaynak ARB) push anahtarlarından `strings.xml`'i
/// üretir. Anahtarlar ada göre sıralıdır; metinler Android kaynak
/// biçimine göre kaçırılır.
String androidMetinleriniUret(String arbMetni) {
  final metinler = androidMetinleri(arbMetni);
  final adlar = metinler.keys.toList()..sort();
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
      '<!-- ÜRETİLMİŞ: lib/l10n/app_tr.arb\'den '
      'tool/kurallar/bin/android_metinleri.dart yazar; elle düzenleme. -->',
    )
    ..writeln(
      '<!-- Push bildirimi metinleri (Tayfam-Api ADR-0019 §4): FCM, '
      'title_loc_key / body_loc_key ile bu adları okur. -->',
    )
    ..writeln('<resources>');
  for (final ad in adlar) {
    final metin = androidKacir(metinler[ad]!);
    b.writeln('    <string name="$ad">$metin</string>');
  }
  b.writeln('</resources>');
  return b.toString();
}

/// [arbMetni]'ndeki Android'e giden anahtarlar ve metinleri. ARB
/// okunamazsa boş.
Map<String, String> androidMetinleri(String arbMetni) {
  final Object? belge;
  try {
    belge = jsonDecode(arbMetni);
  } on FormatException {
    return const {};
  }
  return {
    if (belge is Map<String, Object?>)
      for (final MapEntry(:key, :value) in belge.entries)
        if (androidMetinAnahtari.hasMatch(key) && value is String) key: value,
  };
}

/// Android string kaynağı kaçırması: XML karakterleri, tırnaklar, ters
/// eğik çizgi ve baştaki `@` / `?`.
String androidKacir(String metin) {
  final b = StringBuffer();
  for (var i = 0; i < metin.length; i++) {
    final c = metin[i];
    b.write(switch (c) {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '\\' => r'\\',
      "'" => r"\'",
      '"' => r'\"',
      '\n' => r'\n',
      '@' || '?' when i == 0 => '\\$c',
      _ => c,
    });
  }
  return b.toString();
}

/// `strings.xml` ARB'den üretilenle aynı mı. [mevcut] dosyanın içeriğidir
/// (yoksa `null`).
List<Bulgu> androidMetinKurallari({
  required String arbMetni,
  required String? mevcut,
}) {
  if (mevcut == null && androidMetinleri(arbMetni).isEmpty) {
    return const [];
  }
  final beklenen = androidMetinleriniUret(arbMetni);
  if (mevcut == beklenen) {
    return const [];
  }
  return [
    Bulgu(
      kural: Kurallar.androidMetinleri,
      yol: androidMetinDosyasi,
      satir: 1,
      mesaj: mevcut == null
          ? 'Dosya yok; "dart run tool/kurallar/bin/android_metinleri.dart" '
                'ile üret.'
          : 'ARB\'deki push metinleriyle aynı değil; '
                '"dart run tool/kurallar/bin/android_metinleri.dart" ile '
                'yeniden üret.',
    ),
  ];
}
