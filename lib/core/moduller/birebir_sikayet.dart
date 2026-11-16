import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Birebir mesajı şikâyet etme akışını açan işlev (ADR-0018 §8 ve §9).
///
/// Birebir mesaj şikâyeti yalnızca platforma gider ve mesajın metnini
/// şikâyet eden kişi kendi cihazından iletir (`evidence_text`). Bu yüzden
/// birebir mesaj ekranı mesajın kimliğiyle birlikte ekrandaki açık
/// metnini de verir; metin yalnızca şikâyet isteğinin gövdesine girer,
/// hiçbir yere yazılmaz ve loglanmaz (kesin kural 3).
///
/// Fotoğraf mesajında [fotograf] cihazda çözülmüş görüntüdür; şikâyet eden
/// onu kanıt olarak kendi cihazından yükler (`evidence_upload_id`;
/// Tayfam-Api ADR-0031 §6, istemci ADR-0028 §6). [metin] ya da [fotograf]
/// ten en az biri verilir. Yer mesajında metin, yerin adı ve
/// koordinatıdır (kullanıcı ekranda görür).
typedef BirebirMesajSikayeti = Future<void> Function(
  BuildContext context, {
  required String mesajId,
  String? metin,
  Uint8List? fotograf,
});

/// Uygulamaya kayıtlı birebir mesaj şikâyeti. Şikâyet özelliği
/// `shell/kayitlar.dart`'ta override eder; birebir özelliği onu import
/// etmez (ADR-0002). Varsayılanı `null`'dır; `null` iken mesajın işlem
/// menüsünde "Şikâyet et" gösterilmez.
final birebirMesajSikayetiProvider = Provider<BirebirMesajSikayeti?>(
  (ref) => null,
  name: 'birebirMesajSikayetiProvider',
);
