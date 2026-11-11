import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/features/anket/anket.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/duyuru/duyuru.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/sohbet/sohbet.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';

/// Uygulamanın tayfa modülleri (ADR-0002). Koddaki sabit listedir;
/// çalışma zamanında dışarıdan modül yüklenmez. Modüller kendi
/// paketlerinde bu listeye bir satırla eklenir. Sıra, tayfa ana
/// sayfasındaki bölümlerin sırasıdır (ADR-0015 §1).
const List<TayfaModule> tayfaModulKaydi = [
  EtkinlikModulu(olustur: etkinlikOlusturmayiAc),
  DuyuruModulu(),
  AnketModulu(),
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
  // Tayfa üst menüsü: ayarlar, sessize alma, ayrılma (ADR-0018 §1).
  tayfaUstMenusuProvider.overrideWithValue(tayfaUstMenusu),
  // Kişi profilinde "Mesaj gönder" (ADR-0018 §9).
  kisiProfiliEylemleriProvider.overrideWithValue(const [mesajGonderEylemi]),
  // Sohbet sekmesinin Birebir bölümü (ADR-0018 §9).
  birebirBolumuProvider.overrideWithValue(_birebirBolumu),
];

Widget _birebirBolumu(BuildContext context) => const BirebirSekmesi();
