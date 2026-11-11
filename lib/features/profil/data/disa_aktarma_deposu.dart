import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/cihaz/gecici_dosyalar.dart';

/// KVKK veri dışa aktarma uçları (Tayfam-Api ADR-0021; istemci ADR-0022).
/// Bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class DisaAktarmaDeposu {
  DisaAktarmaDeposu(ApiTransport istemci) : _me = MeApi(istemci);

  final MeApi _me;

  /// `POST /v1/me/data-exports`: talep açar. Aynı [istekKimligi] ile tekrar
  /// gönderim aynı talebi döner.
  Future<DataExport> talepAc(String istekKimligi) => _me.createDataExport(
    body: DataExportRequest(clientRequestId: istekKimligi),
  );

  /// `GET /v1/me/data-exports`: son 30 günün talepleri ve bir sonraki
  /// talep zamanı.
  Future<DataExportList> talepler() => _me.listDataExports();

  /// `POST /v1/me/data-exports/{data_export_id}/download`: 5 dakikalık
  /// link ve anahtar. Yanıt saklanmaz, log'lanmaz.
  Future<DataExportDownload> indirmeBilgisi(String talepId) =>
      _me.downloadDataExport(dataExportId: talepId);
}

/// Dışa aktarma deposu.
final disaAktarmaDeposuProvider = Provider<DisaAktarmaDeposu>(
  (ref) => DisaAktarmaDeposu(ref.watch(apiClientProvider)),
  name: 'disaAktarmaDeposuProvider',
);

/// Çözülmüş zip'i kullanıcıya sistem paylaşım sayfasıyla verir (ADR-0022).
/// Testlerde sahtesi verilir.
abstract interface class ZipPaylasici {
  /// [zip]'i [dosyaAdi] adıyla paylaşır. [konum], iPad'de menünün
  /// bağlanacağı düğmenin ekrandaki yeridir.
  Future<void> paylas(Uint8List zip, {required String dosyaAdi, Rect? konum});
}

/// `share_plus` ile paylaşım.
///
/// Paylaşım sayfası dosya yolu istediği için zip uygulamanın geçici
/// klasörüne yazılır ve paylaşım biter bitmez (başarısız olsa da) silinir
/// ([GeciciDosyalar]; ADR-0006'ya dar istisna). İçerik ve yol log'a
/// yazılmaz.
final class SistemZipPaylasici implements ZipPaylasici {
  const SistemZipPaylasici(this._dosyalar);

  final GeciciDosyalar _dosyalar;

  /// Zip'in MIME türü.
  static const String mimeTuru = 'application/zip';

  @override
  Future<void> paylas(
    Uint8List zip, {
    required String dosyaAdi,
    Rect? konum,
  }) async {
    try {
      final dosya = await _dosyalar.yaz(dosyaAdi, zip);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(dosya.path, mimeType: mimeTuru, name: dosyaAdi)],
          sharePositionOrigin: konum,
        ),
      );
    } finally {
      await _dosyalar.temizle();
    }
  }
}

/// Uygulamanın zip paylaşıcısı.
final zipPaylasiciProvider = Provider<ZipPaylasici>(
  (ref) => SistemZipPaylasici(ref.watch(geciciDosyalarProvider)),
  name: 'zipPaylasiciProvider',
);
