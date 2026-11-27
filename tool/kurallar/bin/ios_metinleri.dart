// Push bildirimlerinin iOS metin tablosunu ARB'den üretir (istemci
// ADR-0019, iOS notu).
//
//   dart run tool/kurallar/bin/ios_metinleri.dart [--kok <dizin>]
//
// lib/l10n/app_tr.arb'deki `push_<tür>_title|body` anahtarlarını
// ios/Runner/tr.lproj/Localizable.strings'e yazar. Kural betiği
// (`ios-metinleri`) dosyanın güncel olduğunu denetler.

import 'dart:io';

import '../kurallar.dart';

void main(List<String> args) {
  var kok = Directory.current;
  if (args.length == 2 && args[0] == '--kok') {
    kok = Directory(args[1]);
  } else if (args.isNotEmpty) {
    stderr.writeln(
      'Kullanım: dart run tool/kurallar/bin/ios_metinleri.dart '
      '[--kok <dizin>]',
    );
    exitCode = 64;
    return;
  }
  final arb = File('${kok.path}/$sablonArb').readAsStringSync();
  final hedef = File('${kok.path}/$iosMetinDosyasi');
  hedef.parent.createSync(recursive: true);
  hedef.writeAsStringSync(iosMetinleriniUret(arb));
  stdout.writeln(
    '$iosMetinDosyasi: ${androidMetinleri(arb).length} metin yazıldı.',
  );
}
