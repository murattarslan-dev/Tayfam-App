import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Token'ın süresi dolmadan ne kadar önce yenisinin isteneceği.
const Duration qrYenilemePayi = Duration(seconds: 20);

/// Sözleşmedeki token ömrü (Tayfam-Api ADR-0038 §3: 2 dakika). Cihaz saati
/// sunucudan çok farklıysa `expires_at` yerine bununla hesaplanır.
const Duration qrTokenOmru = Duration(minutes: 2);

/// Yenileme ağ yüzünden olmazsa yeniden deneme aralığı (eldeki QR hâlâ
/// geçerliyken).
const Duration qrYenidenDenemeAraligi = Duration(seconds: 10);

/// Katılım QR'ı ekranının durumu.
@immutable
sealed class KatilimQruDurumu {
  const KatilimQruDurumu();
}

/// İlk token isteniyor.
final class KatilimQruHazirlaniyor extends KatilimQruDurumu {
  const KatilimQruHazirlaniyor();
}

/// QR gösteriliyor. [link] token'ı fragment'ta taşır
/// (`https://tayfam.app/q#<token>`); yalnızca bellektedir ve QR'a
/// çizilir. `toString` linki içermez.
final class KatilimQruHazir extends KatilimQruDurumu {
  const KatilimQruHazir({required this.link});

  final String link;

  @override
  String toString() => 'KatilimQruHazir';
}

/// QR alınamadı (bitmiş/iptal etkinlik, yetki, sınır ya da bağlantı).
final class KatilimQruHatasi extends KatilimQruDurumu {
  const KatilimQruHatasi(this.hata);

  final Object hata;

  @override
  String toString() => 'KatilimQruHatasi';
}

/// Etkinliğin katılım QR'ı (App ADR-0032 §3): ekran açılınca token ister,
/// süresi dolmadan ([qrYenilemePayi] önce) kendiliğinden yenisini ister.
/// Ekran kapanınca (provider bırakılınca) zamanlayıcı durur, yeni token
/// istenmez.
///
/// Token yalnızca bu durumun içinde, bellektedir: diske, log'a, adrese ya
/// da önbelleğe yazılmaz (kesin kural 3, 9). Yetki kararı sunucudadır
/// (organizatör ya da yönetici; kesin kural 5).
class KatilimQruNotifier extends Notifier<KatilimQruDurumu> {
  KatilimQruNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  Timer? _zamanlayici;

  /// Gösterilen token'ın bitişi (cihaz saatiyle).
  DateTime? _bitis;

  @override
  KatilimQruDurumu build() {
    ref.onDispose(_durdur);
    scheduleMicrotask(() => unawaited(_al()));
    return const KatilimQruHazirlaniyor();
  }

  void _durdur() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
  }

  /// Hata ekranındaki "Tekrar dene".
  Future<void> tekrarDene() async {
    _durdur();
    _bitis = null;
    state = const KatilimQruHazirlaniyor();
    await _al();
  }

  Future<void> _al() async {
    if (!ref.mounted) return;
    final simdi = ref.read(simdiProvider);
    try {
      final qr = await ref
          .read(etkinlikDeposuProvider)
          .katilimQruAl(anahtar.tayfaId, anahtar.etkinlikId);
      if (!ref.mounted) return;
      final alindi = simdi();
      final omur = qrOmru(alindi, qr.expiresAt);
      _bitis = alindi.add(omur);
      state = KatilimQruHazir(link: Adresler.qrKatilimLinki(qr.token));
      _kur(omur - qrYenilemePayi);
    } on Exception catch (hata) {
      if (!ref.mounted) return;
      final bitis = _bitis;
      final eldekiGecerli =
          state is KatilimQruHazir &&
          bitis != null &&
          simdi().add(qrYenidenDenemeAraligi).isBefore(bitis);
      if (eldekiGecerli && _geciciMi(hata)) {
        // Eldeki QR süresi dolana kadar gösterilir; kısa süre sonra yeniden
        // denenir.
        _kur(qrYenidenDenemeAraligi);
        return;
      }
      _bitis = null;
      state = KatilimQruHatasi(hata);
    }
  }

  void _kur(Duration sure) {
    _durdur();
    _zamanlayici = ref.read(zamanlayiciProvider)(sure, () => unawaited(_al()));
  }

  /// Bağlantı ya da sunucu kaynaklı, yeniden denenebilir hata mı.
  static bool _geciciMi(Object hata) => switch (hata) {
    ApiOffline() || ApiTimeout() => true,
    ApiProblem(:final status) => status >= 500 || status == 429,
    _ => false,
  };
}

/// Token'ın cihaz saatiyle ömrü: `expires_at - alindi`. Cihaz saati
/// sunucudan çok farklıysa (ömür sözleşmedeki 2 dakikadan uzun ya da
/// yenileme payından kısa çıkarsa) sözleşmedeki ömür kullanılır.
@visibleForTesting
Duration qrOmru(DateTime alindi, DateTime bitis) {
  final omur = bitis.difference(alindi);
  if (omur > qrTokenOmru || omur <= qrYenilemePayi) return qrTokenOmru;
  return omur;
}

/// Bir etkinliğin katılım QR'ı; QR ekranı açıkken yaşar.
final katilimQruProvider = NotifierProvider.autoDispose
    .family<KatilimQruNotifier, KatilimQruDurumu, EtkinlikAnahtari>(
      KatilimQruNotifier.new,
      name: 'katilimQruProvider',
    );
