import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/e2e/esleme/esleme_servisi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';

/// Yeni cihazın cevabı yoklama aralığı (WebSocket `e2e.link_answered`
/// gelmezse).
const Duration qrYoklamaAraligi = Duration(seconds: 5);

/// Geri sayımın adımı.
const Duration qrSayacAdimi = Duration(seconds: 1);

/// "Bu cihazı bağla" ekranının durumu.
sealed class QrGosterimDurumu {
  const QrGosterimDurumu();
}

/// İstek açılıyor.
final class QrHazirlaniyor extends QrGosterimDurumu {
  const QrHazirlaniyor();
}

/// QR gösteriliyor; [kalan] saniye sonra süresi dolar.
@immutable
final class QrGosteriliyor extends QrGosterimDurumu {
  const QrGosteriliyor({required this.metin, required this.kalan});

  /// QR'a yazılan metin (ekranda yalnızca QR olarak çizilir).
  final String metin;

  final Duration kalan;
}

/// Süre doldu; kullanıcı yeni kod alabilir.
final class QrSuresiDoldu extends QrGosterimDurumu {
  const QrSuresiDoldu();
}

/// Eşleştirme tamamlandı: geçmiş anahtarları bu cihazda.
final class QrTamamlandi extends QrGosterimDurumu {
  const QrTamamlandi();
}

/// İstek açılamadı ya da cevap doğrulanamadı.
final class QrGosterimHatasi extends QrGosterimDurumu {
  const QrGosterimHatasi(this.hata);

  final Object hata;
}

/// Yeni cihaz: eşleştirme isteği açar, QR'ı ve geri sayımı yayınlar,
/// cevabı WebSocket'ten ya da [qrYoklamaAraligi] yoklamayla bekler.
/// Arada anahtar yenilenirse kendiliğinden yeni istek açar.
final class QrGosterimNotifier extends Notifier<QrGosterimDurumu> {
  EslemeOturumu? _oturum;
  Timer? _sayac;
  Timer? _yoklama;
  bool _bakiliyor = false;

  @override
  QrGosterimDurumu build() {
    final abonelik = ref.watch(e2eSinyalleriProvider).sinyaller.listen((
      sinyal,
    ) {
      if (sinyal is EslemeCevaplandi &&
          sinyal.eslemeIstegiId == _oturum?.qr.istekId) {
        unawaited(_cevabaBak());
      }
    });
    ref.onDispose(() {
      unawaited(abonelik.cancel());
      _durdur();
    });
    scheduleMicrotask(() => unawaited(yenile()));
    return const QrHazirlaniyor();
  }

  void _durdur() {
    _sayac?.cancel();
    _yoklama?.cancel();
    _sayac = null;
    _yoklama = null;
  }

  /// Yeni istek açar ve QR'ı gösterir.
  Future<void> yenile() async {
    _durdur();
    _oturum = null;
    state = const QrHazirlaniyor();
    try {
      final oturum = await ref.read(eslemeServisiProvider).baslat();
      if (!ref.mounted) return;
      _oturum = oturum;
      _tik();
      _yoklamaKur();
    } on Exception catch (hata) {
      if (ref.mounted) state = QrGosterimHatasi(hata);
    }
  }

  void _tik() {
    final oturum = _oturum;
    if (oturum == null || !ref.mounted) return;
    final kalan = oturum.bitis.difference(ref.read(simdiProvider)());
    if (kalan <= Duration.zero) {
      _durdur();
      state = const QrSuresiDoldu();
      return;
    }
    state = QrGosteriliyor(metin: oturum.qr.kodla(), kalan: kalan);
    _sayac = ref.read(zamanlayiciProvider)(qrSayacAdimi, _tik);
  }

  void _yoklamaKur() {
    _yoklama = ref.read(zamanlayiciProvider)(qrYoklamaAraligi, () {
      unawaited(
        _cevabaBak().whenComplete(() {
          if (ref.mounted && _oturum != null && state is QrGosteriliyor) {
            _yoklamaKur();
          }
        }),
      );
    });
  }

  Future<void> _cevabaBak() async {
    final oturum = _oturum;
    if (oturum == null || _bakiliyor) return;
    _bakiliyor = true;
    try {
      final tamam = await ref.read(eslemeServisiProvider).cevabiAl(oturum);
      if (!ref.mounted || !tamam) return;
      _durdur();
      _oturum = null;
      state = const QrTamamlandi();
    } on EslemeHatasi catch (hata) {
      if (!ref.mounted) return;
      switch (hata.tur) {
        case EslemeHataTuru.anahtarYenilendi:
          _bakiliyor = false;
          await yenile();
        case EslemeHataTuru.suresiDoldu:
          _durdur();
          state = const QrSuresiDoldu();
        default:
          _durdur();
          state = QrGosterimHatasi(hata);
      }
    } on ApiHatasi {
      // Bağlantı ya da geçici hata: bir sonraki yoklamada tekrar denenir.
    } finally {
      _bakiliyor = false;
    }
  }
}

/// "Bu cihazı bağla" ekranının durumu; ekran kapanınca istek bırakılır.
final qrGosterimProvider =
    NotifierProvider.autoDispose<QrGosterimNotifier, QrGosterimDurumu>(
      QrGosterimNotifier.new,
      name: 'qrGosterimProvider',
    );
