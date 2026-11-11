import 'dart:typed_data';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';

/// `e2e-devices-changed` sonrası en çok tekrar.
const int yenilemeTekrarEnCok = 3;

/// [GecmisYenileyici.yenile] sonucu.
enum YenilemeSonucu {
  /// Yeni sürüm kabul edildi.
  yenilendi,

  /// Yenileme gerekmiyor ya da bu cihaz yenileyemez.
  gerekmedi,

  /// Başka bir eşleştirilmiş cihaz önce yeniledi; onun paylaşımı alındı.
  baskaCihazYeniledi,

  /// Kabul edilmedi (cihaz kümesi oturmadı ya da sunucu reddetti).
  basarisiz,
}

/// Geçmiş anahtarının yenilenmesi (Tayfam-Api ADR-0018 §6).
///
/// `rotation_needed` ise yeni 32 bayt üretilir ve aday sürümle depoya
/// yazılır; diğer eşleştirilmiş cihazlara kendi cihaz oturumuyla paylaşım
/// hazırlanır ve `POST …/history-key/rotate` çağrılır. Hangi cihazların
/// eşleştirilmiş olduğu yalnızca sunucuda bilindiği için ilk deneme boş
/// kümeyle yapılır; `e2e-devices-changed` cevabındaki eksik cihazlar
/// eklenir, fazlalar çıkarılır ve en çok [yenilemeTekrarEnCok] kez tekrar
/// denenir. `e2e-history-key-stale` (başka cihaz önce yeniledi) → aday
/// silinir, paylaşım çekilir, vazgeçilir.
///
/// İsteğin sonucu bilinmiyorsa (bağlantı koptu) aday silinmez: sunucu
/// kabul etmiş olabilir.
final class GecmisYenileyici {
  GecmisYenileyici({
    required this._api,
    required this._oturum,
    required this._anahtarlar,
    required this._kaynak,
    required this._paylasimAlici,
    required this._bicim,
  });

  final GecmisApi _api;
  final KendiCihazOturumu _oturum;
  final GecmisAnahtariDeposu _anahtarlar;
  final E2eCihazDurumuKaynagi _kaynak;
  final PaylasimAlici _paylasimAlici;
  final ArsivBicimi _bicim;

  Future<YenilemeSonucu>? _suren;

  /// Tek uçuşta çalışır.
  Future<YenilemeSonucu> yenile() =>
      _suren ??= _yenile().whenComplete(() => _suren = null);

  Future<YenilemeSonucu> _yenile() async {
    final bilgi = _kaynak.guncel;
    if (bilgi == null || !bilgi.eslestirilmis || !bilgi.yenilemeGerekli) {
      return YenilemeSonucu.gerekmedi;
    }
    final surum = bilgi.gecmisSurumu + 1;
    if (!gecerliGecmisSurumu(surum)) return YenilemeSonucu.basarisiz;

    final anahtar = yeniGecmisAnahtari();
    await _anahtarlar.yaz(surum, anahtar);
    final duz = paylasimDuzMetni({surum: anahtar});
    final paketler = <String, Uint8List>{};
    final hedefler = <String>{};
    var belirsiz = false;

    Future<YenilemeSonucu> vazgec(YenilemeSonucu sonuc) async {
      if (!belirsiz) {
        await _anahtarlar.sil(surum);
        _bicim.unut(surum);
      }
      return sonuc;
    }

    try {
      for (var deneme = 0; deneme <= yenilemeTekrarEnCok; deneme++) {
        for (final cihaz in hedefler) {
          if (paketler.containsKey(cihaz)) continue;
          paketler[cihaz] = kendiCihazPaketi(await _oturum.sifrele(cihaz, duz));
        }
        try {
          belirsiz = true;
          await _api.anahtariYenile(surum, [
            for (final cihaz in hedefler)
              (cihazId: cihaz, paket: paketler[cihaz]!),
          ]);
          await _kaynak.tazele();
          return YenilemeSonucu.yenilendi;
        } on ApiProblem catch (problem) {
          belirsiz = false;
          switch (problem.type) {
            case ProblemType.e2eDevicesChanged:
              final fark = problem.cihazFarki;
              if (fark == null || (fark.eksik.isEmpty && fark.eski.isEmpty)) {
                return await vazgec(YenilemeSonucu.basarisiz);
              }
              hedefler
                ..removeAll(fark.eski)
                ..addAll(fark.eksik);
            case ProblemType.e2eHistoryKeyStale:
              await vazgec(YenilemeSonucu.baskaCihazYeniledi);
              await _paylasimAlici.al();
              await _kaynak.tazele();
              return YenilemeSonucu.baskaCihazYeniledi;
            default:
              return await vazgec(YenilemeSonucu.basarisiz);
          }
        }
      }
      return await vazgec(YenilemeSonucu.basarisiz);
    } on Exception {
      // Bağlantı, şifreleme ya da depo hatası.
      return await vazgec(YenilemeSonucu.basarisiz);
    }
  }
}
