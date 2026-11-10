import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';

/// Uygulamanın tayfa modülleri (ADR-0002). Koddaki sabit listedir;
/// çalışma zamanında dışarıdan modül yüklenmez. Modüller kendi
/// paketlerinde bu listeye bir satırla eklenir.
const List<TayfaModule> tayfaModulKaydi = [];

/// Uygulamanın etkinlik türleri (ADR-0002). Türler kendi paketlerinde bu
/// listeye bir satırla eklenir.
const List<EtkinlikTuru> etkinlikTuruKaydi = [];

/// Kayıt listelerini `core/` ve özelliklerdeki provider'lara veren
/// override'lar; uygulamanın kökündeki `ProviderScope`'a verilir.
final List<Override> kayitOverridelari = [
  tayfaModulleriProvider.overrideWithValue(tayfaModulKaydi),
  etkinlikTurleriProvider.overrideWithValue(etkinlikTuruKaydi),
];
