import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/uploads_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';

/// Sunucu dosyayı denetleyip reddetti (`status: rejected`). Yeniden
/// gönderim aynı sonucu verir; kullanıcı başka fotoğraf seçer.
final class YuklemeReddedildi implements Exception {
  const YuklemeReddedildi(this.neden);

  final UploadRejectReason neden;

  @override
  String toString() => 'YuklemeReddedildi(${neden.name})';
}

/// Bekleme (testlerde anında).
typedef Bekleyici = Future<void> Function(Duration sure);

Future<void> _gercekBekle(Duration sure) => Future<void>.delayed(sure);

/// Yükleme akışı (Tayfam-Api ADR-0020 §4, ADR-0021 §4):
///
/// 1. `POST /v1/uploads` (her iş için bir kez üretilen `client_request_id`
///    ile; aynı iş her denemede aynı id'yle gider),
/// 2. her varyant sunucunun verdiği imzalı linke `PUT` edilir (başlıklar
///    aynen; [MedyaTasima] üzerinden, token gönderilmeden),
/// 3. `POST /v1/uploads/{id}/complete` (tam varyantın ölçüleri).
///
/// Sınırlı tekrar: `upload-not-received` (409) gelirse varyantlar yeniden
/// `PUT` edilip tamamlama tekrarlanır; tamamlamada `unavailable` (503,
/// depoya ulaşılamadı, yükleme `pending` kalır) ya da bağlantı hatası
/// gelirse beklenip tekrarlanır; `PUT` bağlantı hatasında tekrarlanır,
/// süresi dolmuş linkte (403) aynı `client_request_id` ile yeni linkler
/// istenir. Açılıştaki `unavailable` (R2 yapılandırılmamış) tekrarlanmaz.
/// Toplam deneme [enCokDeneme]'dir.
final class MedyaYukleyici {
  MedyaYukleyici({
    required this._uploads,
    required this._tasima,
    this._bekle = _gercekBekle,
  });

  final UploadsApi _uploads;
  final MedyaTasima _tasima;
  final Bekleyici _bekle;

  /// Bir adımın en çok deneme sayısı.
  static const int enCokDeneme = 3;

  /// [goruntu]'yü yükler ve hazır yüklemenin kimliğini döndürür.
  ///
  /// [tayfaId] kapak, av ve sohbet fotoğrafında zorunludur; avatarda ve
  /// şikâyet kanıtında verilmez.
  /// Hata: [ApiHatasi] (ör. `upload-rate-limited`, `upload-quota-exceeded`,
  /// `unavailable`), [MedyaTasimaHatasi] ya da [YuklemeReddedildi].
  Future<String> yukle({
    required UploadPurpose amac,
    required HazirGoruntu goruntu,
    required String istekKimligi,
    String? tayfaId,
  }) => _yukle(
    istek: UploadCreateRequest(
      purpose: amac,
      variants: [
        UploadVariant(
          kind: UploadVariantKind.preview,
          contentType: UploadVariantContentType.imageJpeg,
          sizeBytes: goruntu.onizleme.length,
        ),
        UploadVariant(
          kind: UploadVariantKind.full,
          contentType: UploadVariantContentType.imageJpeg,
          sizeBytes: goruntu.tam.length,
        ),
      ],
      tayfaId: _tayfasiz.contains(amac) ? null : tayfaId,
      clientRequestId: istekKimligi,
    ),
    govdeler: {
      UploadTargetKind.preview: goruntu.onizleme,
      UploadTargetKind.full: goruntu.tam,
    },
    tamamlama: UploadCompleteRequest(
      width: goruntu.tamOlcu.genislik,
      height: goruntu.tamOlcu.yukseklik,
    ),
  );

  /// Birebir mesajın şifreli ekini (`dm_attachment`, tek `blob`,
  /// `application/octet-stream`; Tayfam-Api ADR-0031 §3, istemci ADR-0028
  /// §4) yükler. Tamamlama gövdesi `{width: 0, height: 0}`'dır; sunucu
  /// yalnızca boyutu denetler. Hatalar [yukle] ile aynı.
  Future<String> sifreliEkYukle({
    required Uint8List blob,
    required String istekKimligi,
  }) => _yukle(
    istek: UploadCreateRequest(
      purpose: UploadPurpose.dmAttachment,
      variants: [
        UploadVariant(
          kind: UploadVariantKind.blob,
          contentType: UploadVariantContentType.applicationOctetStream,
          sizeBytes: blob.length,
        ),
      ],
      clientRequestId: istekKimligi,
    ),
    govdeler: {UploadTargetKind.blob: blob},
    tamamlama: const UploadCompleteRequest(width: 0, height: 0),
  );

  /// Tayfası olmayan amaçlar (sözleşme: `tayfa_id` verilmez).
  static const Set<UploadPurpose> _tayfasiz = {
    UploadPurpose.avatar,
    UploadPurpose.dmAttachment,
    UploadPurpose.reportEvidence,
  };

  Future<String> _yukle({
    required UploadCreateRequest istek,
    required Map<UploadTargetKind, Uint8List> govdeler,
    required UploadCompleteRequest tamamlama,
  }) async {
    for (var tur = 1; ; tur++) {
      final acilan = await _uploads.createUpload(body: istek);
      final upload = acilan.upload;
      if (upload.status != UploadStatus.pending) return _sonuc(upload);
      try {
        await _hedeflereYukle(acilan.targets, govdeler);
        return _sonuc(
          await _tamamla(upload.id, tamamlama, acilan.targets, govdeler),
        );
      } on MedyaDurumHatasi catch (hata) {
        // Linkin süresi dolmuş olabilir: aynı id ile yeni linkler.
        if (hata.durum != 403 || tur >= enCokDeneme) rethrow;
      }
    }
  }

  Future<void> _hedeflereYukle(
    List<UploadTarget> hedefler,
    Map<UploadTargetKind, Uint8List> govdeler,
  ) async {
    for (final MapEntry(key: tur, value: govde) in govdeler.entries) {
      await _put(_hedef(hedefler, tur), govde);
    }
  }

  static UploadTarget _hedef(
    List<UploadTarget> hedefler,
    UploadTargetKind tur,
  ) {
    final bulunan = [
      for (final h in hedefler)
        if (h.kind == tur) h,
    ];
    if (bulunan.length != 1 ||
        bulunan.single.method != UploadTargetMethod.pUT) {
      throw const GecersizMedyaLinki();
    }
    return bulunan.single;
  }

  Future<void> _put(UploadTarget hedef, Uint8List govde) async {
    final adres = Uri.tryParse(hedef.url);
    if (adres == null) throw const GecersizMedyaLinki();
    for (var deneme = 1; ; deneme++) {
      try {
        return await _tasima.yukle(adres, hedef.headers, govde);
      } on MedyaBaglantiHatasi {
        if (deneme >= enCokDeneme) rethrow;
        await _bekle(_aralik(deneme));
      }
    }
  }

  Future<Upload> _tamamla(
    String uploadId,
    UploadCompleteRequest govde,
    List<UploadTarget> hedefler,
    Map<UploadTargetKind, Uint8List> govdeler,
  ) async {
    for (var deneme = 1; ; deneme++) {
      try {
        final view = await _uploads.completeUpload(
          uploadId: uploadId,
          body: govde,
        );
        return view.upload;
      } on ApiProblem catch (p) {
        if (deneme >= enCokDeneme) rethrow;
        switch (p.type) {
          case ProblemType.uploadNotReceived:
            await _hedeflereYukle(hedefler, govdeler);
          case ProblemType.unavailable:
            await _bekle(p.retryAfter ?? _aralik(deneme));
          default:
            rethrow;
        }
      } on ApiOffline {
        if (deneme >= enCokDeneme) rethrow;
        await _bekle(_aralik(deneme));
      } on ApiTimeout {
        if (deneme >= enCokDeneme) rethrow;
        await _bekle(_aralik(deneme));
      }
    }
  }

  static String _sonuc(Upload upload) => switch (upload.status) {
    UploadStatus.ready => upload.id,
    UploadStatus.rejected => throw YuklemeReddedildi(
      upload.rejectReason ?? UploadRejectReason.unknown,
    ),
    // Beklenmeyen durum: hazır değil.
    _ => throw const ApiProblem(type: ProblemType.uploadNotReady, status: 409),
  };

  static Duration _aralik(int deneme) => Duration(seconds: 1 << deneme);
}

/// Uygulamanın yükleyicisi (istekler `ApiClient`'tan, `PUT`'lar
/// [MedyaTasima]'dan).
final medyaYukleyiciProvider = Provider<MedyaYukleyici>(
  (ref) => MedyaYukleyici(
    uploads: UploadsApi(ref.watch(apiClientProvider)),
    tasima: ref.watch(medyaTasimaProvider),
  ),
  name: 'medyaYukleyiciProvider',
);
