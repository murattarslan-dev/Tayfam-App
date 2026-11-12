import 'dart:async';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/features/cihazlar/data/qr_cozucu.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_tarayici.dart';

import '../../core/e2e/gecmis/sahteler.dart';
import '../../yardimcilar.dart';
import 'qr_karesi.dart';

const CameraDescription _arka = CameraDescription(
  name: 'arka',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

const CameraDescription _on = CameraDescription(
  name: 'on',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

/// Kamerasız `camera` platformu: izin hatası, kamera listesi ve kare
/// akışı testten verilir.
final class _SahteKamera extends CameraPlatform {
  _SahteKamera({this.kameralar = const [_on, _arka], this.hata});

  final List<CameraDescription> kameralar;
  final CameraException? hata;
  final StreamController<CameraImageData> kareler =
      StreamController<CameraImageData>.broadcast();
  final StreamController<CameraErrorEvent> hatalar =
      StreamController<CameraErrorEvent>.broadcast();
  CameraDescription? secilen;
  MediaSettings? ayarlar;
  ImageFormatGroup? bicim;
  int kapatma = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => kameralar;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    secilen = cameraDescription;
    ayarlar = mediaSettings;
    final h = hata;
    if (h != null) throw h;
    return 7;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    bicim = imageFormatGroup;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => hatalar.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => kareler.stream;

  @override
  Widget buildPreview(int cameraId) => const Placeholder();

  @override
  Future<void> dispose(int cameraId) async => kapatma++;
}

CameraImageData _kare(String metin) {
  final d = qrParlaklikDuzlemi(metin);
  return CameraImageData(
    format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
    planes: [CameraImagePlane(bytes: d.baytlar, bytesPerRow: d.satirBaytlari)],
    width: d.genislik,
    height: d.yukseklik,
  );
}

CameraImageData _bosKare() => CameraImageData(
  format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
  planes: [
    CameraImagePlane(
      bytes: Uint8List(64 * 48)..fillRange(0, 64 * 48, 0xF0),
      bytesPerRow: 64,
    ),
  ],
  width: 64,
  height: 48,
);

/// Tarayıcının geri çağrılarını sayar.
final class _Kayit {
  final List<String> okunan = [];
  int izinYok = 0;
  int acilamadi = 0;
  int cozulen = 0;

  /// İsolate'sız çözücü (testte gerçek isolate beklenmez).
  Future<String?> coz(ParlaklikKaresi kare) async {
    cozulen++;
    return qrMetniCoz(kare);
  }
}

Future<_Kayit> _ac(
  WidgetTester tester,
  _SahteKamera kamera, {
  ThemeMode tema = ThemeMode.light,
}) async {
  final eski = CameraPlatform.instance;
  CameraPlatform.instance = kamera;
  addTearDown(() => CameraPlatform.instance = eski);
  final k = _Kayit();
  await widgetAc(
    tester,
    Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 240,
          child: KameraTarayici(
            kodOkundu: k.okunan.add,
            izinReddedildi: () => k.izinYok++,
            acilamadi: () => k.acilamadi++,
            coz: k.coz,
          ),
        ),
      ),
    ),
    themeMode: tema,
  );
  await tester.pumpAndSettle();
  return k;
}

void main() {
  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} tema, 2× yazı: arka kamera, yalnızca QR; ilk '
        'okumada tarama durur', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final kamera = _SahteKamera();
      final k = await _ac(tester, kamera, tema: mod);

      expect(tester.takeException(), isNull);
      expect(find.byType(Placeholder), findsOneWidget);
      expect(kamera.secilen, _arka);
      expect(kamera.ayarlar?.enableAudio, isFalse);
      expect(kamera.bicim, ImageFormatGroup.yuv420);
      expect(kamera.kareler.hasListener, isTrue);

      // QR'sız kare: okuma yok, tarama sürer.
      kamera.kareler.add(_bosKare());
      await tester.pumpAndSettle();
      expect(k.okunan, isEmpty);
      expect(kamera.kareler.hasListener, isTrue);

      final metin = EslemeQr(
        istekId: istekId,
        cihazId: cihazB,
        kimlikAnahtari: kimlik(2),
        kod: Uint8List(16),
      ).kodla();
      kamera.kareler.add(_kare(metin));
      await tester.pumpAndSettle();
      expect(k.okunan, [metin]);
      expect(kamera.kareler.hasListener, isFalse);

      // Akış durduktan sonra gelen kare çözülmez, ikinci kez bildirilmez.
      final cozulen = k.cozulen;
      kamera.kareler.add(_kare(metin));
      await tester.pumpAndSettle();
      expect(k.okunan, hasLength(1));
      expect(k.cozulen, cozulen);
      expect(k.izinYok + k.acilamadi, 0);
    });
  }

  for (final kod in [
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  ]) {
    testWidgets('izin reddi ($kod) bir kez bildirilir', (tester) async {
      final kamera = _SahteKamera(hata: CameraException(kod, null));
      final k = await _ac(tester, kamera);
      expect(tester.takeException(), isNull);
      expect(k.izinYok, 1);
      expect(k.acilamadi, 0);
      expect(find.byType(Placeholder), findsNothing);
    });
  }

  testWidgets('izin dışı kamera hatası "açılamadı" olur', (tester) async {
    final kamera = _SahteKamera(hata: CameraException('CameraBusy', null));
    final k = await _ac(tester, kamera);
    expect(k.izinYok, 0);
    expect(k.acilamadi, 1);
  });

  testWidgets('kamerası olmayan cihaz "açılamadı" olur', (tester) async {
    final kamera = _SahteKamera(kameralar: const []);
    final k = await _ac(tester, kamera);
    expect(k.acilamadi, 1);
    expect(kamera.secilen, isNull);
  });

  testWidgets('ekrandan çıkınca kamera kapanır', (tester) async {
    final kamera = _SahteKamera();
    await _ac(tester, kamera);
    expect(kamera.kapatma, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(kamera.kapatma, 1);
    expect(kamera.kareler.hasListener, isFalse);
  });
}
