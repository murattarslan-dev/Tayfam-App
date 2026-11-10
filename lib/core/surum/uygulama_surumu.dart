import 'package:tayfam/core/surum/surum.dart';

/// Uygulamanın sürümü: derleme sırasında
/// `--dart-define=TAYFAM_SURUM=<pubspec sürümü>` (ADR-0012 §1.3). CI bu
/// değeri `pubspec.yaml`'dan okur. Verilmezse boştur: sürüm başlığı
/// gönderilmez ve açılıştaki sürüm denetimi atlanır (yerel geliştirme).
const String uygulamaSurumu = String.fromEnvironment('TAYFAM_SURUM');

/// Sözleşmedeki `X-Tayfam-Client-Version` biçimi (`ClientVersionHeader`).
final RegExp surumBasligiBicimi = RegExp(
  r'^(android|ios|web)/(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
  r'(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$',
);

/// `X-Tayfam-Client-Version: <platform>/<sürüm>` değeri (Tayfam-Api
/// ADR-0016). [surum] boşsa, SemVer değilse ya da başlık sözleşmenin
/// biçimine (en fazla 80 karakter) uymuyorsa `null`: başlık gönderilmez.
String? surumBasligi({required String istemciAdi, required String surum}) {
  if (Surum.coz(surum) == null) return null;
  final baslik = '$istemciAdi/$surum';
  if (baslik.length > 80 || !surumBasligiBicimi.hasMatch(baslik)) return null;
  return baslik;
}
