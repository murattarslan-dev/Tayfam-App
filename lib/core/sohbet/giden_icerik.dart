import 'package:flutter/foundation.dart';

import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';

/// Çevrimdışı kuyruktaki bir sohbet mesajının içeriği (kanal ve birebir;
/// ADR-0006, istemci ADR-0028 §1, §4). Yalnızca bellekte yaşar; hiçbir
/// yere yazılmaz ve loglanmaz. `toString` içerik yazmaz.
@immutable
sealed class GidenIcerik {
  const GidenIcerik();
}

/// Metin mesajı.
final class GidenMetin extends GidenIcerik {
  const GidenMetin(this.metin);

  final String metin;

  @override
  String toString() => 'GidenMetin(…)';
}

/// Fotoğraf: cihazda hazırlanmış (metadata'sı silinmiş) görüntü ve
/// yüklemenin işle birlikte bir kez üretilen `client_request_id`'si.
final class GidenFotograf extends GidenIcerik {
  const GidenFotograf({required this.goruntu, required this.yuklemeKimligi});

  final HazirGoruntu goruntu;

  /// Yükleme isteğinin kimliği; mesajın kimliğinden ayrıdır, her denemede
  /// aynıdır.
  final String yuklemeKimligi;

  @override
  String toString() => 'GidenFotograf(…)';
}

/// Haritadan seçilip onaylanmış yer.
final class GidenYer extends GidenIcerik {
  const GidenYer(this.yer);

  final PaylasilanYer yer;

  @override
  String toString() => 'GidenYer(…)';
}
