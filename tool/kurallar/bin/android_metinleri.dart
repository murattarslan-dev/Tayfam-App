// Push bildirimlerinin Android string kaynağını ARB'den üretir (istemci
// ADR-0019 §4).
//
//   dart run tool/kurallar/bin/android_metinleri.dart [--kok <dizin>]
//
// lib/l10n/app_tr.arb'deki `push_<tür>_title|body` anahtarlarını
// android/app/src/main/res/values/strings.xml'e yazar. Kural betiği
// (`android-metinleri`) dosyanın güncel olduğunu denetler.

import 'dart:io';

import '../kurallar.dart';

void main(List<String> args) {
  var kok = Directory.current;
  if (args.length == 2 && args[0] == '--kok') {
    kok = Directory(args[1]);
  } else if (args.isNotEmpty) {
    stderr.writeln(
      'Kullanım: dart run tool/kurallar/bin/android_metinleri.dart '
      '[--kok <dizin>]',
    );
    exitCode = 64;
    return;
  }
  final arb = File('${kok.path}/$sablonArb').readAsStringSync();
  final hedef = File('${kok.path}/$androidMetinDosyasi');
  hedef.parent.createSync(recursive: true);
  hedef.writeAsStringSync(androidMetinleriniUret(arb));
  stdout.writeln(
    '$androidMetinDosyasi: ${androidMetinleri(arb).length} metin yazıldı.',
  );
}
