import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/imzali_indirme.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru_provider.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_bicimi.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_deposu.dart';

import '../../core/e2e/signal/sahte_signal_motoru.dart';
import '../../core/zaman_sahteleri.dart';
import 'sahteler.dart';

export '../../core/e2e/signal/sahte_signal_motoru.dart';
export '../../core/zaman_sahteleri.dart';
export 'sahteler.dart';

/// Dışa aktarma uçlarının yol şablonları (sahte taşımanın anahtarları).
const String talepAcYolu = 'POST /v1/me/data-exports';
const String taleplerYolu = 'GET /v1/me/data-exports';
const String indirmeYolu = 'POST /v1/me/data-exports/{data_export_id}/download';

/// Testlerde kullanılan, biçimi geçerli örnek talep kimlikleri.
const String ornekTalepId = '0190f3a2-7b1c-7d4e-8f00-0123456789ab';
const String eskiTalepId = '0190f3a2-7b1c-7d4e-8f00-0000000000aa';

/// Sahte imzalı link (gerçek değil).
const String sahteLink =
    'https://depo.ornek.test/exports/sahte?X-Amz-Signature=sahte-imza';

/// Sahte 32 baytlık anahtar (gerçek değil).
Uint8List sahteAnahtar() => Uint8List.fromList(List.filled(32, 7));

/// Sahte nonce.
Uint8List sahteNonce() => Uint8List.fromList(List.generate(12, (i) => i));

/// Zip imzasıyla başlayan örnek içerik (gerçek arşiv değil).
Uint8List ornekZip() =>
    Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, ...List.filled(60, 0x2a)]);

/// [zip]'i SAHTE motorun şifrelemesiyle biçime uygun dosyaya çevirir
/// (gerçek kripto değil; yalnızca biçim ve AAD bağı taklit edilir).
Uint8List sifreliDosya({
  Uint8List? anahtar,
  String talepId = ornekTalepId,
  Uint8List? zip,
  int surum = DisaAktarmaBicimi.surum,
}) {
  final nonce = sahteNonce();
  return Uint8List.fromList([
    surum,
    ...nonce,
    ...SahteSignalMotoru.sahteAes256GcmSifrele(
      anahtar: anahtar ?? sahteAnahtar(),
      nonce: nonce,
      duz: zip ?? ornekZip(),
      aad: DisaAktarmaBicimi.aad(talepId),
    ),
  ]);
}

/// `DataExport` JSON'u.
Map<String, Object?> talepJson({
  String id = ornekTalepId,
  String durum = 'ready',
  String? sebep,
  int? boyut = 1500000,
  bool indirildi = false,
}) => {
  'id': id,
  'status': durum,
  'failure_reason': ?sebep,
  'requested_at': '2026-11-10T09:00:00Z',
  if (durum == 'ready' || durum == 'expired') ...{
    'ready_at': '2026-11-10T09:02:00Z',
    'expires_at': '2026-11-17T09:02:00Z',
  },
  if (indirildi) 'downloaded_at': '2026-11-10T10:00:00Z',
  if (durum == 'ready') 'size_bytes': ?boyut,
};

/// `DataExportList` JSON'u.
Map<String, Object?> listeJson(
  List<Map<String, Object?>> talepler, {
  String? sonraki,
}) => {'data_exports': talepler, 'next_request_at': ?sonraki};

/// `DataExportDownload` JSON'u; [dosya] verilirse boyutu ondan.
Map<String, Object?> indirmeJson({
  Uint8List? dosya,
  Uint8List? anahtar,
  String bicim = 'aes-256-gcm-v1',
  String link = sahteLink,
  int? boyut,
}) => {
  'url': link,
  'expires_at': '2026-11-10T10:05:00Z',
  'key': base64.encode(anahtar ?? sahteAnahtar()),
  'size_bytes': boyut ?? (dosya ?? sifreliDosya()).length,
  'format': bicim,
};

/// Sahte imzalı link indiricisi: [dosya]'yı döner ya da [hata] fırlatır.
final class SahteIndirici implements ImzaliIndirici {
  SahteIndirici({this.dosya, this.hata});

  Uint8List? dosya;
  ImzaliIndirmeHatasi? hata;
  final List<Uri> adresler = [];
  final List<int> beklenenler = [];

  @override
  Future<Uint8List> indir(
    Uri adres, {
    required int beklenenBoyut,
    required int enCok,
  }) async {
    adresler.add(adres);
    beklenenler.add(beklenenBoyut);
    final h = hata;
    if (h != null) throw h;
    return Uint8List.fromList(dosya ?? sifreliDosya());
  }
}

/// Paylaşılan zip'leri kaydeden sahte paylaşıcı. [kopyalar] paylaşım
/// anındaki içeriktir; [tamponlar] verilen tamponun kendisidir (sonradan
/// sıfırlandığını görmek için).
final class SahteZipPaylasici implements ZipPaylasici {
  final List<Uint8List> kopyalar = [];
  final List<Uint8List> tamponlar = [];
  final List<String> adlar = [];
  Exception? hata;

  @override
  Future<void> paylas(
    Uint8List zip, {
    required String dosyaAdi,
    Rect? konum,
  }) async {
    kopyalar.add(Uint8List.fromList(zip));
    tamponlar.add(zip);
    adlar.add(dosyaAdi);
    final h = hata;
    if (h != null) throw h;
  }
}

/// Dışa aktarmanın sahte bağımlılıkları (profil override'larının üstüne).
/// Gerçek ağ, disk ve kripto yoktur.
List<Override> disaAktarmaOverridelari({
  required SahteTasima tasima,
  required SahteOturum oturum,
  SahteGoogle? google,
  SahteIndirici? indirici,
  SahteZipPaylasici? paylasici,
  SignalMotoru? motor,
  SahteZamanlayici? zamanlayici,
}) => [
  ...profilOverridelari(tasima: tasima, oturum: oturum, google: google),
  disaAktarmaDeposuProvider.overrideWithValue(DisaAktarmaDeposu(tasima)),
  imzaliIndiriciProvider.overrideWithValue(indirici ?? SahteIndirici()),
  // Çözücü gerçek bağlantıyla (signalDestekleniyorProvider) motordan gelir.
  signalMotoruProvider.overrideWithValue(motor ?? SahteSignalMotoru()),
  zipPaylasiciProvider.overrideWithValue(paylasici ?? SahteZipPaylasici()),
  zamanlayiciProvider.overrideWithValue(
    (zamanlayici ?? SahteZamanlayici()).kur,
  ),
];
