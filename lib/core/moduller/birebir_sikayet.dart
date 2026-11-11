import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Birebir mesajı şikâyet etme akışını açan işlev (ADR-0018 §8 ve §9).
///
/// Birebir mesaj şikâyeti yalnızca platforma gider ve mesajın metnini
/// şikâyet eden kişi kendi cihazından iletir (`evidence_text`). Bu yüzden
/// birebir mesaj ekranı mesajın kimliğiyle birlikte ekrandaki açık
/// metnini de verir; metin yalnızca şikâyet isteğinin gövdesine girer,
/// hiçbir yere yazılmaz ve loglanmaz (kesin kural 3).
typedef BirebirMesajSikayeti = Future<void> Function(
  BuildContext context, {
  required String mesajId,
  required String metin,
});

/// Uygulamaya kayıtlı birebir mesaj şikâyeti. Şikâyet özelliği
/// `shell/kayitlar.dart`'ta override eder; birebir özelliği onu import
/// etmez (ADR-0002). Varsayılanı `null`'dır; `null` iken mesajın işlem
/// menüsünde "Şikâyet et" gösterilmez.
final birebirMesajSikayetiProvider = Provider<BirebirMesajSikayeti?>(
  (ref) => null,
  name: 'birebirMesajSikayetiProvider',
);
