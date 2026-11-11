import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/duyuru/duyuru.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';

/// Uygulamanın tayfa modülleri (ADR-0002). Koddaki sabit listedir;
/// çalışma zamanında dışarıdan modül yüklenmez. Modüller kendi
/// paketlerinde bu listeye bir satırla eklenir. Sıra, tayfa ana
/// sayfasındaki bölümlerin sırasıdır (ADR-0015 §1).
const List<TayfaModule> tayfaModulKaydi = [
  EtkinlikModulu(olustur: etkinlikOlusturmayiAc),
  DuyuruModulu(),
  // Anket modülü (ADR-0018 Genel: üçüncü bölüm) buraya, sorulardan önce.
  SoruCevapModulu(),
];

/// Uygulamanın etkinlik türleri (ADR-0002). Türler kendi paketlerinde bu
/// listeye bir satırla eklenir. Yalnızca türe özel aracı olan türler
/// kayıtlıdır (ADR-0015 §6); oyun, spor ve genel yalnızca bilgi alanları
/// gösterir.
const List<EtkinlikTuru> etkinlikTuruKaydi = [
  KonvoyTuru(),
  KampTuru(),
  YuruyusTuru(),
  BalikTuru(),
];

/// Kayıt listelerini `core/` ve özelliklerdeki provider'lara veren
/// override'lar; uygulamanın kökündeki `ProviderScope`'a verilir.
final List<Override> kayitOverridelari = [
  tayfaModulleriProvider.overrideWithValue(tayfaModulKaydi),
  etkinlikTurleriProvider.overrideWithValue(etkinlikTuruKaydi),
];
