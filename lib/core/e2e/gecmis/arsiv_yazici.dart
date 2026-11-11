import 'dart:async';
import 'dart:collection';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';

/// Bir arşiv yazma çağrısındaki en çok kayıt (sözleşme: 1–50).
const int arsivGrupBoyu = 50;

/// Bellekte bekleyen en çok mesaj; fazlasında en eskiler düşer.
const int arsivKuyrukSiniri = 500;

/// Eşleştirilmiş cihazın gönderdiği ve aldığı mesajları geçmiş arşivine
/// yazar (Tayfam-Api ADR-0018 §4).
///
/// Mesajlar yalnızca bellekte sıraya girer ve [arsivGrupBoyu]'luk gruplarla
/// gönderilir: bir istek sürerken gelenler sonraki gruba birikir.
/// - `e2e-history-key-stale` → paylaşımlar çekilir, durum tazelenir, grup
///   yeni sürümle bir kez daha şifrelenip gönderilir.
/// - `e2e-not-paired` → kuyruk boşaltılır, yazılmaz.
/// - Bağlantı hatası → grup kuyruğun başına döner; bir sonraki mesajda ya
///   da [bosalt] çağrısında yeniden denenir.
/// Diske hiçbir şey yazılmaz.
final class ArsivYazici {
  ArsivYazici({
    required this._api,
    required this._bicim,
    required this._anahtarlar,
    required this._kaynak,
    required this._paylasimAlici,
  });

  final GecmisApi _api;
  final ArsivBicimi _bicim;
  final GecmisAnahtariDeposu _anahtarlar;
  final E2eCihazDurumuKaynagi _kaynak;
  final PaylasimAlici _paylasimAlici;

  final Queue<ArsivlenecekMesaj> _kuyruk = Queue();
  Future<void>? _suren;
  bool _planli = false;

  /// Bekleyen mesaj sayısı.
  int get bekleyen => _kuyruk.length;

  /// [mesaj]'ı sıraya ekler ve gönderimi başlatır. Cihaz eşleştirilmemişse
  /// yok sayılır.
  void ekle(ArsivlenecekMesaj mesaj) {
    if (_kaynak.guncel?.eslestirilmis != true) return;
    _kuyruk.add(mesaj);
    while (_kuyruk.length > arsivKuyrukSiniri) {
      _kuyruk.removeFirst();
    }
    // Aynı anda gelen mesajlar (açılışta çekilen zarflar) tek gruba
    // girsin diye gönderim bir sonraki olay döngüsü turunda başlar.
    if (_planli) return;
    _planli = true;
    Timer.run(() {
      _planli = false;
      unawaited(bosalt());
    });
  }

  /// Kuyruğu gönderir; sürüyorsa aynı işi bekler.
  Future<void> bosalt() =>
      _suren ??= _bosalt().whenComplete(() => _suren = null);

  Future<void> _bosalt() async {
    while (_kuyruk.isNotEmpty) {
      final bilgi = _kaynak.guncel;
      if (bilgi == null || !bilgi.eslestirilmis) {
        _kuyruk.clear();
        return;
      }
      final grup = <ArsivlenecekMesaj>[];
      while (grup.length < arsivGrupBoyu && _kuyruk.isNotEmpty) {
        grup.add(_kuyruk.removeFirst());
      }
      try {
        await _yaz(bilgi.kullaniciId, grup, tekrar: true);
      } on ApiProblem catch (problem) {
        if (problem.type == ProblemType.e2eNotPaired) {
          _kuyruk.clear();
          await _kaynak.tazele();
          return;
        }
        if (_gecici(problem)) {
          _geriKoy(grup);
          return;
        }
        // Kalıcı hata (ör. geçersiz istek): grup düşer.
      } on ApiHatasi {
        _geriKoy(grup);
        return;
      }
    }
  }

  static bool _gecici(ApiProblem problem) =>
      problem.type == ProblemType.rateLimited ||
      problem.type == ProblemType.unavailable ||
      problem.type == ProblemType.internal ||
      problem.status >= 500;

  void _geriKoy(List<ArsivlenecekMesaj> grup) {
    for (final m in grup.reversed) {
      _kuyruk.addFirst(m);
    }
  }

  Future<void> _yaz(
    String kullaniciId,
    List<ArsivlenecekMesaj> grup, {
    required bool tekrar,
  }) async {
    final surum = await _anahtarlar.enYeni();
    if (surum == null) return;
    final anahtar = (await _anahtarlar.oku(surum))!;
    final kayitlar = <ArsivYazimi>[
      for (final m in grup)
        (
          mesajId: m.mesajId,
          icerik: await _bicim.sifrele(
            gecmisAnahtari: anahtar,
            surum: surum,
            kullaniciId: kullaniciId,
            mesajId: m.mesajId,
            duz: ArsivDuzMetni(
              gonderenId: m.gonderenId,
              olusturma: m.olusturma,
              govde: m.govde,
            ),
          ),
        ),
    ];
    try {
      await _api.arsiveYaz(surum, kayitlar);
    } on ApiProblem catch (problem) {
      if (!tekrar || problem.type != ProblemType.e2eHistoryKeyStale) rethrow;
      await _paylasimAlici.al();
      await _kaynak.tazele();
      final yeni = await _anahtarlar.enYeni();
      if (yeni == null || yeni == surum) rethrow;
      await _yaz(kullaniciId, grup, tekrar: false);
    }
  }
}
