import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/moduller/birebir_sikayet.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/moduller/uye_islemleri.dart';
import 'package:tayfam/features/anket/anket.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/duyuru/duyuru.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/profil.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/sohbet/sohbet.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/shell/derin_link/kayit_davet.dart';

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
  // Ana sayfadan davet linki ve "Silmeyi iptal et" (2026-11-13).
  tayfaDavetiProvider.overrideWithValue(tayfayaDavetEt),
  tayfaSilmeIptaliProvider.overrideWithValue(silmeIptalDugmesi),
  // Tayfa ayarlarındaki ek girişler: moderasyon kuyruğu (ADR-0018 §8).
  yonetimEkGirisleriProvider.overrideWithValue(yonetimEkGirisleri),
  // Moderasyon kuyruğundaki "Üye işlemleri" (2026-11-13).
  uyeIslemleriProvider.overrideWithValue(uyeIslemleriniAc),
  // Kişi profilinde "Mesaj gönder" (ADR-0018 §9).
  kisiProfiliEylemleriProvider.overrideWithValue(const [mesajGonderEylemi]),
  // Arkadaşlar ekranında "Kodumu paylaş" (2026-11-13).
  referansPaylasimiProvider.overrideWithValue(kendiKodunuPaylas),
  // Katılım geçmişin ekranında görünürlük satırı (2026-11-13).
  katilimGorunurlukSatiriProvider.overrideWithValue(katilimGorunurlukSatiri),
  // Sohbet sekmesinin Birebir bölümü (ADR-0018 §9).
  birebirBolumuProvider.overrideWithValue(_birebirBolumu),
  // Sohbet sekmesindeki parça seçicinin Birebir sayısı (2026-11-13).
  birebirOkunmamisYuvasiProvider.overrideWith(
    (ref) => ref.watch(birebirOkunmamisBilinenProvider),
  ),
  // Birebir mesaj şikâyeti: mesajın açık metni cihazdan (ADR-0018 §8).
  birebirMesajSikayetiProvider.overrideWithValue(_birebirMesajSikayeti),
  // Kayıttan sonra bekleyen davet mevcut davet akışıyla işlenir
  // (ADR-0012 §3, ADR-0018 §6).
  kayitDavetProvider.overrideWith(KabukKayitDavetNotifier.new),
];

/// Tayfa ayarları ekranına başka paketlerin eklediği girişler; rotaları
/// `shell/yonlendirici.dart`'ta `tayfaYonetimRotalari(ekRotalar:)` ile
/// eklenir.
const List<YonetimEkGirisi> yonetimEkGirisleri = [
  YonetimEkGirisi(
    ikon: moderasyonGirisIkonu,
    etiket: moderasyonGirisEtiketi,
    adres: moderasyonAdresi,
    // Açık şikâyet sayısı ve "Seni bekleyenler" satırı (2026-11-13).
    sayi: moderasyonSayisi,
    ozet: moderasyonOzeti,
    bekleyenMetni: moderasyonBekleyenMetni,
    bekleyenEtiketi: moderasyonBekleyenEtiketi,
  ),
];

Widget _birebirBolumu(BuildContext context) => const BirebirSekmesi();

Future<void> _birebirMesajSikayeti(
  BuildContext context, {
  required String mesajId,
  required String metin,
}) => birebirMesajiSikayetEt(context, mesajId: mesajId, mesajMetni: metin);
