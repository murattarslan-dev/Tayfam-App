import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';

/// Bir fotoğraf alanının anahtarı: alanın kendi kimliği (her form
/// açılışında bir kez), amaç ve (kapak ile av fotoğrafında) tayfa.
typedef FotografAlaniAnahtari = ({
  Object alan,
  UploadPurpose amac,
  String? tayfaId,
});

/// Fotoğraf alanının durumu.
@immutable
sealed class FotografYuklemeDurumu {
  const FotografYuklemeDurumu();
}

/// Bu alanda yeni fotoğraf seçilmedi.
final class FotografSecilmedi extends FotografYuklemeDurumu {
  const FotografSecilmedi();
}

/// Fotoğraf seçiliyor, hazırlanıyor ya da yükleniyor.
final class FotografIsleniyor extends FotografYuklemeDurumu {
  const FotografIsleniyor({required this.yukleniyor});

  /// `false`: seçim ya da hazırlama; `true`: yükleme.
  final bool yukleniyor;
}

/// Yükleme hazır; içeriğe bağlanmayı bekliyor.
final class FotografHazir extends FotografYuklemeDurumu {
  const FotografHazir({required this.uploadId, required this.onizleme});

  final String uploadId;

  /// Az önce hazırlanan önizleme (yalnızca bellekte).
  final Uint8List onizleme;
}

/// Seçim, hazırlama ya da yükleme başarısız oldu.
final class FotografYuklemeHatasi extends FotografYuklemeDurumu {
  const FotografYuklemeHatasi(this.hata, {required this.tekrarlanabilir});

  final Object hata;

  /// Aynı fotoğrafla tekrar denenebilir mi (ağ ya da sunucu hatası).
  final bool tekrarlanabilir;
}

/// Bir fotoğraf alanının işi (ADR-0021 §6): seç → hazırla → yükle.
///
/// Her seçilen fotoğraf yeni bir yükleme işidir ve bir kez
/// `client_request_id` alır; "Tekrar dene" aynı hazır görüntüyü aynı id ile
/// yeniden gönderir. Hazır görüntü yalnızca bellektedir ve alan
/// kapanınca bırakılır.
class FotografYuklemeNotifier extends Notifier<FotografYuklemeDurumu> {
  FotografYuklemeNotifier(this.anahtar);

  final FotografAlaniAnahtari anahtar;

  HazirGoruntu? _hazir;
  String? _istekKimligi;
  int _nesil = 0;

  @override
  FotografYuklemeDurumu build() => const FotografSecilmedi();

  bool get _mesgul => state is FotografIsleniyor;

  /// [kaynak]'tan fotoğraf alır, hazırlar ve yükler. Vazgeçilirse önceki
  /// durum kalır.
  Future<void> sec(FotografKaynagi kaynak) async {
    if (_mesgul) return;
    final onceki = state;
    final nesil = ++_nesil;
    state = const FotografIsleniyor(yukleniyor: false);
    final HazirGoruntu hazir;
    try {
      final ham = await ref.read(fotografSeciciProvider).sec(kaynak);
      if (!_gecerli(nesil)) return;
      if (ham == null) {
        state = onceki;
        return;
      }
      hazir = await ref.read(goruntuHazirlayiciProvider).hazirla(ham);
    } on Exception catch (hata) {
      if (_gecerli(nesil)) {
        state = FotografYuklemeHatasi(hata, tekrarlanabilir: false);
      }
      return;
    }
    if (!_gecerli(nesil)) return;
    _hazir = hazir;
    _istekKimligi = yeniIstekKimligi();
    await _yukle(nesil);
  }

  /// Son hazırlanan fotoğrafı aynı `client_request_id` ile yeniden
  /// yükler.
  Future<void> tekrarDene() async {
    if (_mesgul || _hazir == null) return;
    await _yukle(++_nesil);
  }

  /// Alanı başa döndürür (seçilen fotoğraf bırakılır; sunucudaki
  /// bağlanmamış yükleme 7 gün sonra silinir).
  void sifirla() {
    _nesil++;
    _hazir = null;
    _istekKimligi = null;
    state = const FotografSecilmedi();
  }

  Future<void> _yukle(int nesil) async {
    final hazir = _hazir;
    final kimlik = _istekKimligi;
    if (hazir == null || kimlik == null) return;
    state = const FotografIsleniyor(yukleniyor: true);
    try {
      final yukleyici = ref.read(medyaYukleyiciProvider);
      final uploadId = await yukleyici.yukle(
        amac: anahtar.amac,
        goruntu: hazir,
        istekKimligi: kimlik,
        tayfaId: anahtar.tayfaId,
      );
      if (!_gecerli(nesil)) return;
      ref.read(medyaOnbellegiProvider)
        ..yerelEkle(uploadId, MedyaVaryanti.onizleme, hazir.onizleme)
        ..yerelEkle(uploadId, MedyaVaryanti.tam, hazir.tam);
      state = FotografHazir(uploadId: uploadId, onizleme: hazir.onizleme);
    } on YuklemeReddedildi catch (hata) {
      if (_gecerli(nesil)) {
        state = FotografYuklemeHatasi(hata, tekrarlanabilir: false);
      }
    } on Exception catch (hata) {
      if (_gecerli(nesil)) {
        state = FotografYuklemeHatasi(hata, tekrarlanabilir: true);
      }
    }
  }

  bool _gecerli(int nesil) => ref.mounted && nesil == _nesil;
}

/// Bir fotoğraf alanının durumu; alan kapanınca bırakılır.
final fotografYuklemeProvider = NotifierProvider.autoDispose
    .family<
      FotografYuklemeNotifier,
      FotografYuklemeDurumu,
      FotografAlaniAnahtari
    >(FotografYuklemeNotifier.new, name: 'fotografYuklemeProvider');
