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
    Bekleyici bekle = _gercekBekle,
  }) : _bekle = bekle;

  final UploadsApi _uploads;
  final MedyaTasima _tasima;
  final Bekleyici _bekle;

  /// Bir adımın en çok deneme sayısı.
  static const int enCokDeneme = 3;

  /// [goruntu]'yü yükler ve hazır yüklemenin kimliğini döndürür.
  ///
  /// [tayfaId] kapak ve av fotoğrafında zorunludur, avatarda verilmez.
  /// Hata: [ApiHatasi] (ör. `upload-rate-limited`, `upload-quota-exceeded`,
  /// `unavailable`), [MedyaTasimaHatasi] ya da [YuklemeReddedildi].
  Future<String> yukle({
    required UploadPurpose amac,
    required HazirGoruntu goruntu,
    required String istekKimligi,
    String? tayfaId,
  }) async {
    final istek = UploadCreateRequest(
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
      tayfaId: amac == UploadPurpose.avatar ? null : tayfaId,
      clientRequestId: istekKimligi,
    );

    for (var tur = 1; ; tur++) {
      final acilan = await _uploads.createUpload(body: istek);
      final upload = acilan.upload;
      if (upload.status != UploadStatus.pending) return _sonuc(upload);
      try {
        await _hedeflereYukle(acilan.targets, goruntu);
        return _sonuc(await _tamamla(upload.id, goruntu, acilan.targets));
      } on MedyaDurumHatasi catch (hata) {
        // Linkin süresi dolmuş olabilir: aynı id ile yeni linkler.
        if (hata.durum != 403 || tur >= enCokDeneme) rethrow;
      }
    }
  }

  Future<void> _hedeflereYukle(
    List<UploadTarget> hedefler,
    HazirGoruntu goruntu,
  ) async {
    final onizleme = _hedef(hedefler, UploadTargetKind.preview);
    final tam = _hedef(hedefler, UploadTargetKind.full);
    await _put(onizleme, goruntu.onizleme);
    await _put(tam, goruntu.tam);
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
    HazirGoruntu goruntu,
    List<UploadTarget> hedefler,
  ) async {
    final govde = UploadCompleteRequest(
      width: goruntu.tamOlcu.genislik,
      height: goruntu.tamOlcu.yukseklik,
    );
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
            await _hedeflereYukle(hedefler, goruntu);
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
