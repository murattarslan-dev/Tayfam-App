import 'dart:io';

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

  /// Galeriden en çok [enCok] fotoğraf seçtirir (kamerada tek fotoğraf);
  /// vazgeçilirse boş liste (istemci ADR-0025 §2). Baytlar hemen
  /// okunmaz: her tutamaç [SecilenFotograf.oku] ile sırayla okunur, böylece
  /// bellekte aynı anda tek ham fotoğraf bulunur.
  Future<List<SecilenFotograf>> secCoklu(FotografKaynagi kaynak, int enCok);
}

/// Seçilmiş, henüz okunmamış bir fotoğraf (istemci ADR-0025 §2).
///
/// Seçicinin geçici kopyası [oku] ile belleğe alınır alınmaz ya da
/// [birak] ile silinir (ADR-0006: diske içerik yok).
abstract interface class SecilenFotograf {
  /// Baytları okur ve geçici kopyayı siler. Bir kez çağrılır.
  Future<Uint8List> oku();

  /// Okunmayacaksa geçici kopyayı siler.
  Future<void> birak();
}

/// Bellekteki baytlarla hazır bir seçim (kamera ve testler).
final class BellekteSecilenFotograf implements SecilenFotograf {
  BellekteSecilenFotograf(this._baytlar);

  Uint8List? _baytlar;

  @override
  Future<Uint8List> oku() async {
    final b = _baytlar;
    _baytlar = null;
    if (b == null) throw StateError('okundu');
    return b;
  }

  @override
  Future<void> birak() async => _baytlar = null;
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

  @override
  Future<List<SecilenFotograf>> secCoklu(
    FotografKaynagi kaynak,
    int enCok,
  ) async {
    if (kaynak == FotografKaynagi.kamera || enCok <= 1) {
      final tek = await sec(kaynak);
      return tek == null ? const [] : [BellekteSecilenFotograf(tek)];
    }
    final dosyalar = await _secici.pickMultiImage(
      limit: enCok,
      requestFullMetadata: false,
    );
    final secilen = [for (final d in dosyalar) _PlatformSecilen(d)];
    // Sınırdan fazlası (eski Android seçicisi sınırı uygulamayabilir)
    // okunmadan silinir.
    for (final fazla in secilen.skip(enCok)) {
      await fazla.birak();
    }
    return secilen.take(enCok).toList(growable: false);
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

/// `image_picker`'ın geçici kopyası; okununca ya da bırakılınca silinir.
final class _PlatformSecilen implements SecilenFotograf {
  _PlatformSecilen(this._dosya);

  final XFile _dosya;
  bool _bitti = false;

  @override
  Future<Uint8List> oku() async {
    if (_bitti) throw StateError('okundu');
    _bitti = true;
    try {
      return await _dosya.readAsBytes();
    } finally {
      await PlatformFotografSecici._geciciDosyayiSil(_dosya.path);
    }
  }

  @override
  Future<void> birak() async {
    if (_bitti) return;
    _bitti = true;
    await PlatformFotografSecici._geciciDosyayiSil(_dosya.path);
  }
}
