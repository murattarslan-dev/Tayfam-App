// Push bildirimlerinin iOS metin tablosu (istemci ADR-0019, iOS notu).
//
// Uygulama kapalıyken bildirimi iOS gösterir; başlık ve gövde sunucunun
// APNs yükündeki `title-loc-key` / `loc-key` adlarıyla (`push_<tür>_title`,
// `push_<tür>_body`) uygulama paketindeki `Localizable.strings`'ten okunur
// (Tayfam-Api ADR-0019 §4). Metinlerin tek kaynağı ARB'dir: Android'deki
// gibi (`android_metinleri.dart`) bu anahtarlar
// `ios/Runner/tr.lproj/Localizable.strings`'e buradaki üreticiyle yazılır
// ve kural betiği dosyanın güncel olduğunu denetler.
//
//   dart run tool/kurallar/bin/ios_metinleri.dart

import 'android_metinleri.dart';
import 'bulgu.dart';

/// Üretilen iOS metin tablosu.
const String iosMetinDosyasi = 'ios/Runner/tr.lproj/Localizable.strings';

/// [arbMetni]'ndeki (kaynak ARB) push anahtarlarından `Localizable.strings`'i
/// üretir. Anahtarlar Android'dekilerle aynıdır ([androidMetinleri]) ve ada
/// göre sıralıdır; metinler `.strings` biçimine göre kaçırılır.
String iosMetinleriniUret(String arbMetni) {
  final metinler = androidMetinleri(arbMetni);
  final adlar = metinler.keys.toList()..sort();
  final b = StringBuffer()
    ..writeln(
      '/* ÜRETİLMİŞ: lib/l10n/app_tr.arb\'den '
      'tool/kurallar/bin/ios_metinleri.dart yazar; elle düzenleme. */',
    )
    ..writeln(
      '/* Push bildirimi metinleri (Tayfam-Api ADR-0019 §4): APNs, '
      'title-loc-key / loc-key ile bu adları okur. */',
    );
  for (final ad in adlar) {
    b.writeln('"$ad" = "${iosKacir(metinler[ad]!)}";');
  }
  return b.toString();
}

/// `.strings` kaçırması: ters eğik çizgi, çift tırnak ve satır sonu.
String iosKacir(String metin) {
  final b = StringBuffer();
  for (var i = 0; i < metin.length; i++) {
    final c = metin[i];
    b.write(switch (c) {
      '\\' => r'\\',
      '"' => r'\"',
      '\n' => r'\n',
      _ => c,
    });
  }
  return b.toString();
}

/// `Localizable.strings` ARB'den üretilenle aynı mı. [mevcut] dosyanın
/// içeriğidir (yoksa `null`).
List<Bulgu> iosMetinKurallari({
  required String arbMetni,
  required String? mevcut,
}) {
  if (mevcut == null && androidMetinleri(arbMetni).isEmpty) {
    return const [];
  }
  final beklenen = iosMetinleriniUret(arbMetni);
  if (mevcut == beklenen) {
    return const [];
  }
  return [
    Bulgu(
      kural: Kurallar.iosMetinleri,
      yol: iosMetinDosyasi,
      satir: 1,
      mesaj: mevcut == null
          ? 'Dosya yok; "dart run tool/kurallar/bin/ios_metinleri.dart" '
                'ile üret.'
          : 'ARB\'deki push metinleriyle aynı değil; '
                '"dart run tool/kurallar/bin/ios_metinleri.dart" ile '
                'yeniden üret.',
    ),
  ];
}
