/// Geçmiş arşivi, QR eşleştirme ve anahtar yenilemenin E2E çekirdeğinden
/// (E2: `lib/core/e2e/depo/`, `cihaz/`, `mesaj/`) beklediği ince
/// arayüzler.
///
/// Bu dosyadaki soyut sınıflar çekirdeğin gerçek uygulamalarına mimari
/// birleştirmede bağlanır (provider override'ı ya da provider gövdesinin
/// değişmesi). Bağlanana kadar varsayılanlar "E2E yok" davranır: cihaz
/// durumu `null`, akışlar boş; geçmiş katmanı hiçbir şey yapmaz.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Bu oturumun E2E cihazı ve oturumdaki kullanıcı.
@immutable
final class E2eCihazBilgisi {
  const E2eCihazBilgisi({required this.kullaniciId, required this.durum});

  /// Oturumdaki kullanıcının kimliği (arşiv AAD'si ve kendi cihaz
  /// listesi için).
  final String kullaniciId;

  /// `GET /v1/me/e2e/device` cevabı.
  final E2EDeviceState durum;

  /// Bu cihazın sunucudaki kimliği.
  String get cihazId => durum.device.id;

  /// Bu cihaz geçmiş anahtarını biliyor (arşive yazar ve okur).
  bool get eslestirilmis => durum.device.paired;

  /// Hesabın eşleştirilmiş başka cihazı var.
  bool get baskaEslestirilmisVar => durum.otherPairedDevice;

  /// Hesabın güncel geçmiş anahtarı sürümü (0: henüz yok).
  int get gecmisSurumu => durum.historyKeyVersion;

  /// Eşleştirilmiş bir cihaz kaldırıldı; anahtar yenilenmeli.
  bool get yenilemeGerekli => durum.rotationNeeded;
}

/// Cihaz durumunu yayınlayan kaynak (E2'nin cihaz kaydı katmanı).
abstract interface class E2eCihazDurumuKaynagi {
  /// Son bilinen durum; cihaz kayıtlı değilse ya da E2E yoksa `null`.
  E2eCihazBilgisi? get guncel;

  /// Durum her değiştiğinde.
  Stream<E2eCihazBilgisi?> get degisiklikler;

  /// `GET /v1/me/e2e/device` ile yeniden okur, yayınlar ve döner.
  Future<E2eCihazBilgisi?> tazele();
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
  E2eCihazBilgisi? get guncel => null;

  @override
  Stream<E2eCihazBilgisi?> get degisiklikler => const Stream.empty();

  @override
  Future<E2eCihazBilgisi?> tazele() async => null;

  @override
  Stream<ArsivlenecekMesaj> get mesajlar => const Stream.empty();

  @override
  Stream<E2eSinyali> get sinyaller => const Stream.empty();
}

/// Bağlanmamış depo, oturum ve motor: her çağrı [UnsupportedError].
/// Cihaz durumu `null` olduğu sürece geçmiş katmanı bunları çağırmaz.
final class _Baglanmamis implements E2eDepoErisimi, KendiCihazOturumu {
  const _Baglanmamis();

  static Never _yok() => throw UnsupportedError('E2E bağlanmadı');

  @override
  Future<Uint8List?> oku(String anahtar) async => _yok();

  @override
  Future<void> yaz(String anahtar, Uint8List deger) async => _yok();

  @override
  Future<void> sil(String anahtar) async => _yok();

  @override
  Future<Map<String, Uint8List>> onekliOku(String onek) async => _yok();

  @override
  Future<KendiCihazSifreli> sifrele(
    String cihazId,
    Uint8List duz, {
    Uint8List? beklenenKimlik,
  }) async => _yok();

  @override
  Future<Uint8List> coz(String cihazId, int tur, Uint8List sifreli) async =>
      _yok();
}

/// Cihaz durumu (E2 bağlar).
final e2eCihazDurumuKaynagiProvider = Provider<E2eCihazDurumuKaynagi>(
  (ref) => const E2eYok(),
  name: 'e2eCihazDurumuKaynagiProvider',
);

/// E2E güvenli deposu (E2 bağlar).
final e2eDepoErisimiProvider = Provider<E2eDepoErisimi>(
  (ref) => const _Baglanmamis(),
  name: 'e2eDepoErisimiProvider',
);

/// Kendi cihazlarıyla Signal oturumu (E2 bağlar).
final kendiCihazOturumuProvider = Provider<KendiCihazOturumu>(
  (ref) => const _Baglanmamis(),
  name: 'kendiCihazOturumuProvider',
);

/// Gönderilen ve çözülen birebir mesajlar (E2 bağlar).
final cozulmusMesajAkisiProvider = Provider<CozulmusMesajAkisi>(
  (ref) => const E2eYok(),
  name: 'cozulmusMesajAkisiProvider',
);

/// Canlı E2E olayları (realtime bağlar).
final e2eSinyalleriProvider = Provider<E2eSinyalleri>(
  (ref) => const E2eYok(),
  name: 'e2eSinyalleriProvider',
);

/// Arşiv biçiminin kullandığı Signal motoru (yalnızca `hkdf` ve
/// `aesGcmSiv*`). E1'in kanal uygulamasına bağlanır.
final gecmisMotoruProvider = Provider<SignalMotoru>(
  (ref) => throw UnsupportedError('Signal motoru bağlanmadı'),
  name: 'gecmisMotoruProvider',
);
