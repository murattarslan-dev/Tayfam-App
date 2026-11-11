import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_okuyucu.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_yazici.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yenileme.dart';
import 'package:tayfam/core/e2e/gecmis/ilk_cihaz.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Geçmiş katmanının servisleri; bağımlılıklar bir kez bağlanır.
final class GecmisServisleri {
  GecmisServisleri({
    required this.api,
    required this.kaynak,
    required this.oturum,
    required E2eDepoErisimi depo,
    required this._motor,
  }) : anahtarlar = GecmisAnahtariDeposu(depo);

  final GecmisApi api;
  final E2eCihazDurumuKaynagi kaynak;
  final KendiCihazOturumu oturum;
  final GecmisAnahtariDeposu anahtarlar;
  final SignalMotoru Function() _motor;

  late final ArsivBicimi bicim = ArsivBicimi(_motor());

  late final PaylasimAlici paylasimAlici = PaylasimAlici(
    api: api,
    oturum: oturum,
    anahtarlar: anahtarlar,
  );

  late final IlkCihazKurulumu ilkCihaz = IlkCihazKurulumu(
    api: api,
    anahtarlar: anahtarlar,
    kaynak: kaynak,
  );

  late final GecmisYenileyici yenileyici = GecmisYenileyici(
    api: api,
    oturum: oturum,
    anahtarlar: anahtarlar,
    kaynak: kaynak,
    paylasimAlici: paylasimAlici,
    bicim: bicim,
  );

  late final ArsivYazici yazici = ArsivYazici(
    api: api,
    bicim: bicim,
    anahtarlar: anahtarlar,
    kaynak: kaynak,
    paylasimAlici: paylasimAlici,
  );

  late final ArsivOkuyucu okuyucu = ArsivOkuyucu(
    api: api,
    bicim: bicim,
    anahtarlar: anahtarlar,
    kaynak: kaynak,
  );
}

/// Geçmiş katmanının servisleri. Oturum değişince yeniden kurulur
/// (bellekteki kuyruk ve türetilmiş anahtarlar sıfırlanır).
final gecmisServisleriProvider = Provider<GecmisServisleri>((ref) {
  ref.watch(oturumDurumuProvider);
  return GecmisServisleri(
    api: ref.watch(gecmisApiProvider),
    kaynak: ref.watch(e2eCihazDurumuKaynagiProvider),
    oturum: ref.watch(kendiCihazOturumuProvider),
    depo: ref.watch(e2eDepoErisimiProvider),
    // Motor yalnızca ilk kripto işleminde okunur: E2E bağlı değilken
    // (web, cihaz kaydı yok) motor gerekmez.
    motor: () => ref.read(gecmisMotoruProvider),
  );
}, name: 'gecmisServisleriProvider');

/// Cihaz durumunun Riverpod yansıması (arayüz ve uyarılar için).
final class GecmisCihazBilgisiNotifier extends Notifier<GecmisCihazBilgisi?> {
  @override
  GecmisCihazBilgisi? build() {
    ref.watch(oturumDurumuProvider);
    final kaynak = ref.watch(e2eCihazDurumuKaynagiProvider);
    final abonelik = kaynak.degisiklikler.listen((b) => state = b);
    ref.onDispose(abonelik.cancel);
    return kaynak.guncel;
  }
}

/// Bu cihazın E2E durumu; E2E yoksa `null`.
final gecmisCihazBilgisiProvider =
    NotifierProvider<GecmisCihazBilgisiNotifier, GecmisCihazBilgisi?>(
      GecmisCihazBilgisiNotifier.new,
      name: 'gecmisCihazBilgisiProvider',
    );

/// Bu telefon geçmiş anahtarını taşıyan tek cihaz mı (`paired &&
/// !other_paired_device`): çıkış onayında ek uyarı ve ilk E2E açılışında
/// bir kez bilgi gösterilir (araştırma §3.11).
final tekCihazUyarisiProvider = Provider<bool>((ref) {
  final bilgi = ref.watch(gecmisCihazBilgisiProvider);
  return bilgi != null && bilgi.eslestirilmis && !bilgi.baskaEslestirilmisVar;
}, name: 'tekCihazUyarisiProvider');

/// Bu cihaz eşleştirilmemiş ve hesabın eşleştirilmiş başka cihazı var:
/// "Bu cihazı bağla" (QR göster) önerilir.
final qrOnerisiProvider = Provider<bool>((ref) {
  final bilgi = ref.watch(gecmisCihazBilgisiProvider);
  return bilgi != null && !bilgi.eslestirilmis && bilgi.baskaEslestirilmisVar;
}, name: 'qrOnerisiProvider');

/// Geçmiş yöneticisinin arayüze bildirdikleri.
@immutable
final class GecmisDurumu {
  const GecmisDurumu({this.eskiArsivOkunamaz = false});

  /// Bu cihaz yeni geçmiş anahtarı aldı ama hesabın daha önce bir anahtarı
  /// vardı: eski mesajlar bu cihazda okunamaz (bir kez gösterilir).
  final bool eskiArsivOkunamaz;
}

/// Geçmiş katmanını çalıştırır (keepAlive): cihaz durumu değiştikçe ilk
/// cihaz anahtarı, paylaşım alma ve yenileme; çözülen mesajları arşive
/// yazma. E2'nin cihaz kaydı tamamlanınca okunmaya başlanır (mimari
/// birleştirmede kabukta `ref.watch(gecmisYoneticisiProvider)`).
///
/// Arka plandaki hatalar yutulur (bir sonraki durum değişikliğinde ya da
/// yeniden bağlanmada tekrar denenir); log'a içerik yazılmaz.
final class GecmisYoneticisi extends Notifier<GecmisDurumu> {
  GecmisServisleri get _servisler => ref.read(gecmisServisleriProvider);

  @override
  GecmisDurumu build() {
    ref.watch(oturumDurumuProvider);
    final kaynak = ref.watch(e2eCihazDurumuKaynagiProvider);
    final aboneler = <StreamSubscription<Object?>>[
      kaynak.degisiklikler.listen(_durumDegisti),
      ref.watch(e2eSinyalleriProvider).sinyaller.listen(_sinyal),
      ref
          .watch(cozulmusMesajAkisiProvider)
          .mesajlar
          .listen((m) => _servisler.yazici.ekle(m)),
    ];
    ref.onDispose(() {
      for (final a in aboneler) {
        unawaited(a.cancel());
      }
    });
    final ilk = kaynak.guncel;
    if (ilk != null) scheduleMicrotask(() => _durumDegisti(ilk));
    return const GecmisDurumu();
  }

  /// "Eski mesajlar okunamaz" bilgisi gösterildi.
  void eskiArsivBilgisiGoruldu() => state = const GecmisDurumu();

  void _durumDegisti(GecmisCihazBilgisi? bilgi) {
    if (bilgi == null) return;
    if (!bilgi.eslestirilmis) {
      if (!bilgi.baskaEslestirilmisVar) unawaited(_guvenli(_ilkCihaz));
      return;
    }
    unawaited(
      _guvenli(() async {
        await _servisler.paylasimAlici.al();
        if (bilgi.yenilemeGerekli) await _servisler.yenileyici.yenile();
        await _servisler.yazici.bosalt();
      }),
    );
  }

  void _sinyal(E2eSinyali sinyal) {
    switch (sinyal) {
      case GecmisAnahtariPaylasildi() || E2eYenidenBaglandi():
        if (ref.read(e2eCihazDurumuKaynagiProvider).guncel == null) return;
        unawaited(
          _guvenli(() async {
            await _servisler.paylasimAlici.al();
            await _servisler.yazici.bosalt();
          }),
        );
      case EslemeCevaplandi():
        // Eşleştirme ekranı kendisi dinler.
        break;
    }
  }

  Future<void> _ilkCihaz() async {
    final sonuc = await _servisler.ilkCihaz.kur();
    if (sonuc case IlkCihazAnahtarAldi(eskiArsivOkunamaz: true)) {
      state = const GecmisDurumu(eskiArsivOkunamaz: true);
    }
  }

  static Future<void> _guvenli(Future<void> Function() gorev) async {
    try {
      await gorev();
    } on Exception {
      // Bir sonraki durum değişikliğinde ya da bağlantıda tekrar denenir.
    }
  }
}

/// Geçmiş katmanının yöneticisi.
final gecmisYoneticisiProvider =
    NotifierProvider<GecmisYoneticisi, GecmisDurumu>(
      GecmisYoneticisi.new,
      name: 'gecmisYoneticisiProvider',
    );

/// Bir birebir konuşmanın çözülmüş arşivi (konuşma açılınca indirilir,
/// bellekte çözülür). Birebir konuşma notifier'ı `encryption: e2e`
/// mesajların metnini [KonusmaArsivi.mesajlar]'dan `message_id` ile alır.
final class KonusmaArsiviNotifier extends AsyncNotifier<KonusmaArsivi> {
  KonusmaArsiviNotifier(this.konusmaId);

  final String konusmaId;
  bool _eskiOkunuyor = false;

  @override
  Future<KonusmaArsivi> build() async {
    final bilgi = ref.watch(gecmisCihazBilgisiProvider);
    if (bilgi == null) return const KonusmaArsivi.yok();
    final arsiv = await ref
        .read(gecmisServisleriProvider)
        .okuyucu
        .oku(konusmaId);
    _icerigeEkle(arsiv);
    return arsiv;
  }

  /// Çözülen kayıtları E2'nin bellekteki içeriğine verir; konuşma ekranı
  /// `encryption: e2e` mesajların metnini oradan gösterir. Arşiv kaynaklı
  /// mesajlar yeniden yayılmaz (arşive tekrar yazılmaz).
  void _icerigeEkle(KonusmaArsivi arsiv) {
    if (arsiv.mesajlar.isEmpty || !ref.mounted) return;
    ref.read(birebirIcerikProvider.notifier).ekle([
      for (final m in arsiv.mesajlar.values)
        CozulmusBirebirMesaj(
          mesajId: m.mesajId,
          konusmaId: konusmaId,
          gonderenKullaniciId: m.gonderenId,
          metin: m.govde,
          olusturma: m.olusturma,
          kaynak: CozulmusMesajKaynagi.arsiv,
        ),
    ]);
  }

  /// Daha eski bir sayfa okur ve ekler.
  Future<void> dahaEski() async {
    final mevcut = state.value;
    final sayfa = mevcut?.sonrakiSayfa;
    if (mevcut == null || sayfa == null || _eskiOkunuyor) return;
    _eskiOkunuyor = true;
    try {
      final yeni = await ref
          .read(gecmisServisleriProvider)
          .okuyucu
          .oku(konusmaId, sayfa: sayfa);
      if (!ref.mounted) return;
      _icerigeEkle(yeni);
      state = AsyncData(mevcut.ekle(yeni));
    } finally {
      _eskiOkunuyor = false;
    }
  }

  /// Bu cihazda gönderilen ya da çözülen mesajı belleğe ekler (konuşma
  /// açıkken arşivi yeniden indirmeden).
  void bellegeEkle(ArsivMesaji mesaj) {
    final mevcut = state.value;
    if (mevcut == null || mevcut.erisim != ArsivErisimi.okundu) return;
    state = AsyncData(
      KonusmaArsivi(
        erisim: mevcut.erisim,
        mesajlar: {...mevcut.mesajlar, mesaj.mesajId: mesaj},
        okunamayan: mevcut.okunamayan,
        sonrakiSayfa: mevcut.sonrakiSayfa,
      ),
    );
  }
}

/// Konuşma kimliğine göre arşiv; konuşma ekranı kapanınca bellekten
/// atılır.
final konusmaArsiviProvider = AsyncNotifierProvider.autoDispose
    .family<KonusmaArsiviNotifier, KonusmaArsivi, String>(
      KonusmaArsiviNotifier.new,
      name: 'konusmaArsiviProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// İlk E2E açılışındaki "tek cihaz" bilgisinin gösterildiğini tutan
/// güvenli depo anahtarı (E2 çıkışta bütün E2E kayıtlarıyla siler).
const String tekCihazBilgisiAnahtari = 'e2e.bilgi.tek_cihaz';

/// İlk E2E açılışında bir kez gösterilen "bu telefon geçmiş anahtarını
/// taşıyan tek cihaz" bilgisi gösterilmeli mi.
final class TekCihazBilgisiNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    if (!ref.watch(tekCihazUyarisiProvider)) return false;
    final kayit = await ref
        .read(e2eDepoErisimiProvider)
        .oku(tekCihazBilgisiAnahtari);
    return kayit == null;
  }

  /// Kullanıcı bilgiyi kapattı; bir daha gösterilmez.
  Future<void> goruldu() async {
    state = const AsyncData(false);
    await ref
        .read(e2eDepoErisimiProvider)
        .yaz(tekCihazBilgisiAnahtari, Uint8List.fromList(const [1]));
  }
}

/// İlk E2E açılışındaki tek cihaz bilgisi.
final tekCihazBilgisiProvider =
    AsyncNotifierProvider<TekCihazBilgisiNotifier, bool>(
      TekCihazBilgisiNotifier.new,
      name: 'tekCihazBilgisiProvider',
      retry: _yenidenDenemeYok,
    );
