import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Fotoğrafın nereden alınacağı.
enum FotografKaynagi { galeri, kamera }

/// Galeriden ya da kameradan tek fotoğraf alır ve baytlarını döndürür;
/// kullanıcı vazgeçerse `null` (ADR-0021 §1).
abstract interface class FotografSecici {
  Future<Uint8List?> sec(FotografKaynagi kaynak);
}

/// `image_picker` ile:
///
/// - Galeri: Android'de sistemin fotoğraf seçicisi (Photo Picker; Android
///   13+ yerleşik, eski sürümlerde Google Play hizmetleriyle), iOS'ta
///   PHPicker. İkisi de **izin istemez**; uygulama yalnızca seçilen
///   fotoğrafı görür. `requestFullMetadata: false` iOS'ta fotoğraf
///   kitaplığı iznini istemez.
/// - Kamera: sistem kamera uygulaması. Android'de manifestte `CAMERA`
///   izni yoksa izin istenmez; varsa (ör. QR okuma için) eklenti çekimden
///   önce o izni ister. iOS'ta `NSCameraUsageDescription` metniyle sorulur.
/// - Seçici dosyayı uygulamanın geçici klasörüne kopyalar; baytlar
///   belleğe okunduktan hemen sonra o dosya silinir (ADR-0006, ADR-0021
///   §1). Görüntü işleme bellekte yapılır.
final class PlatformFotografSecici implements FotografSecici {
  PlatformFotografSecici() {
    final platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
  }

  final ImagePicker _secici = ImagePicker();

  @override
  Future<Uint8List?> sec(FotografKaynagi kaynak) async {
    final dosya = await _secici.pickImage(
      source: kaynak == FotografKaynagi.kamera
          ? ImageSource.camera
          : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (dosya == null) return null;
    try {
      return await dosya.readAsBytes();
    } finally {
      await _geciciDosyayiSil(dosya.path);
    }
  }

  static Future<void> _geciciDosyayiSil(String yol) async {
    if (kIsWeb || yol.isEmpty) return;
    try {
      // kural-istisnası: diske-yazma — ADR-0021 §1: seçicinin bıraktığı geçici kopya yalnızca silinir
      await File(yol).delete();
    } on FileSystemException {
      // Zaten yoksa ya da silinemiyorsa işletim sistemi önbelleği temizler.
    }
  }
}

/// Uygulamanın fotoğraf seçicisi; testlerde sahtesi verilir.
final fotografSeciciProvider = Provider<FotografSecici>(
  (ref) => PlatformFotografSecici(),
  name: 'fotografSeciciProvider',
);
