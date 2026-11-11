import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';

/// [IlkCihazKurulumu.kur] sonucu.
sealed class IlkCihazSonucu {
  const IlkCihazSonucu();
}

/// Bu cihaz zaten eşleştirilmiş ya da E2E yok; bir şey yapılmadı.
final class IlkCihazGerekmedi extends IlkCihazSonucu {
  const IlkCihazGerekmedi();
}

/// Bu cihaz yeni geçmiş anahtarını aldı ve eşleştirilmiş oldu.
final class IlkCihazAnahtarAldi extends IlkCihazSonucu {
  const IlkCihazAnahtarAldi({required this.oncekiSurum, required this.surum});

  /// Önceki sürüm; 0'dan büyükse eski arşiv bu cihazda okunamaz
  /// (kullanıcıya söylenir).
  final int oncekiSurum;

  final int surum;

  bool get eskiArsivOkunamaz => oncekiSurum > 0;
}

/// Hesabın eşleştirilmiş başka cihazı var: bu cihaz QR ile eşleşmeli.
final class IlkCihazQrGerekli extends IlkCihazSonucu {
  const IlkCihazQrGerekli();
}

/// İlk cihazın geçmiş anahtarı (Tayfam-Api ADR-0018 §4): eşleştirilmiş
/// cihaz yoksa 32 bayt üret, depoya yaz, `ClaimHistoryKey`.
///
/// Anahtar sunucuya bildirilmeden önce aday sürümle depoya yazılır; böylece
/// cevap kaybolsa da anahtar cihazda kalır. Sunucu kesin olarak reddederse
/// aday silinir.
final class IlkCihazKurulumu {
  IlkCihazKurulumu({
    required GecmisApi api,
    required GecmisAnahtariDeposu anahtarlar,
    required E2eCihazDurumuKaynagi kaynak,
  }) : _api = api,
       _anahtarlar = anahtarlar,
       _kaynak = kaynak;

  final GecmisApi _api;
  final GecmisAnahtariDeposu _anahtarlar;
  final E2eCihazDurumuKaynagi _kaynak;

  Future<IlkCihazSonucu>? _suren;

  /// Tek uçuşta çalışır.
  Future<IlkCihazSonucu> kur() =>
      _suren ??= _kur().whenComplete(() => _suren = null);

  Future<IlkCihazSonucu> _kur() async {
    final bilgi = _kaynak.guncel;
    if (bilgi == null || bilgi.eslestirilmis) return const IlkCihazGerekmedi();
    if (bilgi.baskaEslestirilmisVar) return const IlkCihazQrGerekli();

    final onceki = bilgi.gecmisSurumu;
    final aday = onceki + 1;
    final anahtar = yeniGecmisAnahtari();
    await _anahtarlar.yaz(aday, anahtar);
    final int surum;
    try {
      surum = await _api.gecmisAnahtariAl();
    } on ApiProblem catch (problem) {
      // Sunucu kesin olarak reddetti: aday hiçbir yerde kullanılmadı.
      await _anahtarlar.sil(aday);
      if (problem.type == ProblemType.e2ePairedDeviceExists) {
        await _kaynak.tazele();
        return const IlkCihazQrGerekli();
      }
      rethrow;
    }
    if (surum != aday) {
      // Arada sürüm değişti: anahtar sunucunun verdiği sürümdür. O sürüm
      // zaten depodaysa (bu cihaz eşleştirilmişti) üzerine yazılmaz.
      if (await _anahtarlar.oku(surum) == null) {
        await _anahtarlar.yaz(surum, anahtar);
      }
      await _anahtarlar.sil(aday);
    }
    await _kaynak.tazele();
    return IlkCihazAnahtarAldi(oncekiSurum: onceki, surum: surum);
  }
}
