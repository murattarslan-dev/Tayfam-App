/// Geçmiş arşivi, QR eşleştirme ve anahtar yenilemenin E2E çekirdeğinden
/// (E2: `lib/core/e2e/depo/`, `cihaz/`, `mesaj/`) beklediği ince
/// arayüzler.
///
/// Bu dosyadaki soyut sınıflar çekirdeğin gerçek uygulamalarına
/// `e2_baglantisi.dart`'ta bağlanır; testler arayüzleri sahteler. E2E
/// hazır değilken (web, cihaz kaydı yok) cihaz durumu `null`'dır ve
/// geçmiş katmanı hiçbir şey yapmaz.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/e2_baglantisi.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/realtime/realtime.dart';

/// Bu oturumun E2E cihazı ve oturumdaki kullanıcı (geçmiş katmanının
/// gördüğü kadarı). E2'nin cihaz durumundan ve kimlik kaydından kurulur.
@immutable
final class GecmisCihazBilgisi {
  GecmisCihazBilgisi({
    required this.kullaniciId,
    required this.cihazId,
    required Uint8List kimlikAnahtari,
    required this.eslestirilmis,
    required this.baskaEslestirilmisVar,
    required this.gecmisSurumu,
    required this.yenilemeGerekli,
  }) : kimlikAnahtari = Uint8List.fromList(kimlikAnahtari);

  /// `GET /v1/me/e2e/device` cevabından.
  factory GecmisCihazBilgisi.sunucudan({
    required String kullaniciId,
    required E2EDeviceState durum,
  }) => GecmisCihazBilgisi(
    kullaniciId: kullaniciId,
    cihazId: durum.device.id,
    kimlikAnahtari: base64.decode(durum.device.identityKey),
    eslestirilmis: durum.device.paired,
    baskaEslestirilmisVar: durum.otherPairedDevice,
    gecmisSurumu: durum.historyKeyVersion,
    yenilemeGerekli: durum.rotationNeeded,
  );

  /// Oturumdaki kullanıcının kimliği (arşiv AAD'si ve kendi cihaz
  /// listesi için).
  final String kullaniciId;

  /// Bu cihazın sunucudaki kimliği (`device.id`).
  final String cihazId;

  /// Bu cihazın Signal kimlik açık anahtarı (33 bayt; QR'a yazılır).
  final Uint8List kimlikAnahtari;

  /// `device.paired`: bu cihaz geçmiş anahtarını biliyor.
  final bool eslestirilmis;

  /// `other_paired_device`: hesabın eşleştirilmiş başka cihazı var.
  final bool baskaEslestirilmisVar;

  /// `history_key_version` (0: henüz yok).
  final int gecmisSurumu;

  /// `rotation_needed`: eşleştirilmiş bir cihaz kaldırıldı.
  final bool yenilemeGerekli;
}

/// Cihaz durumunu yayınlayan kaynak (E2'nin cihaz kaydı katmanı).
abstract interface class E2eCihazDurumuKaynagi {
  /// Son bilinen durum; cihaz kayıtlı değilse ya da E2E yoksa `null`.
  GecmisCihazBilgisi? get guncel;

  /// Durum her değiştiğinde.
  Stream<GecmisCihazBilgisi?> get degisiklikler;

  /// `GET /v1/me/e2e/device` ile yeniden okur, yayınlar ve döner.
  Future<GecmisCihazBilgisi?> tazele();
}

/// E2E'nin güvenli deposu (E2: `flutter_secure_storage`, ayrı
/// `sharedPreferencesName`). Değerler bayttır; çıkışta ve hesap silmede
/// E2 hepsini siler.
abstract interface class E2eDepoErisimi {
  Future<Uint8List?> oku(String anahtar);

  Future<void> yaz(String anahtar, Uint8List deger);

  Future<void> sil(String anahtar);

  /// [onek] ile başlayan bütün kayıtlar (anahtar → değer).
  Future<Map<String, Uint8List>> onekliOku(String onek);
}

/// [KendiCihazOturumu.sifrele] sonucu: Signal mesaj türü (2 ya da 3) ve
/// şifreli metin.
@immutable
final class KendiCihazSifreli {
  const KendiCihazSifreli({required this.tur, required this.sifreli});

  /// [SignalMesajTuru.signal] ya da [SignalMesajTuru.onAnahtar].
  final int tur;

  final Uint8List sifreli;
}

/// Kullanıcının kendi diğer cihazlarıyla Signal oturumu (E2'nin mesaj
/// katmanı). Oturum yoksa ön anahtar paketini çekip kurar, adres kilidini
/// ve kalıcılık sırasını (ADR-0010) kendisi uygular.
abstract interface class KendiCihazOturumu {
  /// [duz]'ü kendi [cihazId]'li cihazına şifreler.
  ///
  /// [beklenenKimlik] verilirse (QR'dan okunan kimlik anahtarı) oturum
  /// yalnızca bu kimlik anahtarıyla kurulur; ön anahtar paketindeki ya da
  /// depodaki kimlik farklıysa [E2eKimlikUyusmazligi] fırlatılır ve hiçbir
  /// şey şifrelenmez.
  Future<KendiCihazSifreli> sifrele(
    String cihazId,
    Uint8List duz, {
    Uint8List? beklenenKimlik,
  });

  /// Kendi [cihazId]'li cihazından gelen [tur] türündeki [sifreli]'yi
  /// çözer. Çözülemezse [SignalHatasi] fırlatır.
  Future<Uint8List> coz(String cihazId, int tur, Uint8List sifreli);
}

/// Oturum kurulacak cihazın kimlik anahtarı beklenenle aynı değil.
final class E2eKimlikUyusmazligi implements Exception {
  const E2eKimlikUyusmazligi();

  @override
  String toString() => 'E2eKimlikUyusmazligi';
}

/// Arşive yazılacak, çözülmüş (ya da gönderilmiş) bir birebir mesaj.
///
/// İçerik yalnızca bellektedir; `toString` içerik yazmaz.
@immutable
final class ArsivlenecekMesaj {
  const ArsivlenecekMesaj({
    required this.mesajId,
    required this.konusmaId,
    required this.gonderenId,
    required this.olusturma,
    required this.govde,
  });

  final String mesajId;
  final String konusmaId;
  final String gonderenId;
  final DateTime olusturma;
  final String govde;

  @override
  String toString() => 'ArsivlenecekMesaj($mesajId)';
}

/// Bu cihazın gönderdiği ve çözdüğü birebir mesajlar (E2'nin
/// gönderim/alım kancası). Her mesaj bir kez yayınlanır.
abstract interface class CozulmusMesajAkisi {
  Stream<ArsivlenecekMesaj> get mesajlar;
}

/// Geçmiş katmanını ilgilendiren canlı E2E olayları (WebSocket).
sealed class E2eSinyali {
  const E2eSinyali();
}

/// `e2e.link_answered`: bu cihazın eşleştirme isteği cevaplandı.
final class EslemeCevaplandi extends E2eSinyali {
  const EslemeCevaplandi(this.eslemeIstegiId);

  final String eslemeIstegiId;
}

/// `e2e.history_key_shared`: bu cihaz için yeni geçmiş anahtarı paylaşımı
/// var.
final class GecmisAnahtariPaylasildi extends E2eSinyali {
  const GecmisAnahtariPaylasildi();
}

/// Bağlantı yeniden kuruldu (`ready`): kaçırılan paylaşımlar çekilir.
final class E2eYenidenBaglandi extends E2eSinyali {
  const E2eYenidenBaglandi();
}

/// Canlı E2E olaylarının kaynağı (realtime katmanı).
abstract interface class E2eSinyalleri {
  Stream<E2eSinyali> get sinyaller;
}

/// E2 bağlanana kadarki varsayılan: E2E yok.
final class E2eYok
    implements E2eCihazDurumuKaynagi, CozulmusMesajAkisi, E2eSinyalleri {
  const E2eYok();

  @override
  GecmisCihazBilgisi? get guncel => null;

  @override
  Stream<GecmisCihazBilgisi?> get degisiklikler => const Stream.empty();

  @override
  Future<GecmisCihazBilgisi?> tazele() async => null;

  @override
  Stream<ArsivlenecekMesaj> get mesajlar => const Stream.empty();

  @override
  Stream<E2eSinyali> get sinyaller => const Stream.empty();
}

/// Cihaz durumu (E2'nin `e2eCihazProvider`'ı).
final e2eCihazDurumuKaynagiProvider = Provider<E2eCihazDurumuKaynagi>(
  e2CihazKaynagiKur,
  name: 'e2eCihazDurumuKaynagiProvider',
);

/// E2E güvenli deposu (E2'nin `e2eDeposuProvider`'ı).
final e2eDepoErisimiProvider = Provider<E2eDepoErisimi>(
  (ref) => E2DepoErisimi(ref.watch(e2eDeposuProvider)),
  name: 'e2eDepoErisimiProvider',
);

/// Kendi cihazlarıyla Signal oturumu (E2'nin `e2eOturumlariProvider`'ı).
final kendiCihazOturumuProvider = Provider<KendiCihazOturumu>(
  (ref) => E2KendiCihazOturumu(
    oturumlar: ref.watch(e2eOturumlariProvider),
    kullaniciKimligi: ref.watch(sessionStoreProvider).kullaniciKimligi,
  ),
  name: 'kendiCihazOturumuProvider',
);

/// Gönderilen ve çözülen birebir mesajlar (E2'nin mesaj yayını).
final cozulmusMesajAkisiProvider = Provider<CozulmusMesajAkisi>(
  (ref) => E2MesajAkisi(ref.watch(e2eMesajYayiniProvider).akis),
  name: 'cozulmusMesajAkisiProvider',
);

/// Canlı E2E olayları (realtime).
final e2eSinyalleriProvider = Provider<E2eSinyalleri>(
  (ref) => E2Sinyalleri(ref.watch(realtimeIstemcisiProvider).olaylar),
  name: 'e2eSinyalleriProvider',
);

/// Arşiv biçiminin kullandığı Signal motoru (yalnızca `hkdf` ve
/// `aesGcmSiv*`): E2'nin `e2eMotoruProvider`'ı.
final gecmisMotoruProvider = Provider<SignalMotoru>(
  (ref) => ref.watch(e2eMotoruProvider),
  name: 'gecmisMotoruProvider',
);
