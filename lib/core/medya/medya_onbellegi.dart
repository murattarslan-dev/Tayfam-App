import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/media_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Bir dosyanın iki varyantından hangisi.
enum MedyaVaryanti { onizleme, tam }

/// `POST /v1/media/urls`'ten gelen linkler. Linkler taşıyıcı sırdır:
/// yalnızca bellekte tutulur, log'a yazılmaz; `toString` içermez.
@immutable
final class MedyaLinki {
  const MedyaLinki({
    required this.onizleme,
    required this.tam,
    required this.genislik,
    required this.yukseklik,
    required this.gecerlilik,
  });

  final Uri onizleme;
  final Uri tam;

  /// Tam varyantın ölçüleri.
  final int genislik;
  final int yukseklik;

  /// Linklerin geçerliliğinin sonu (`expires_at`).
  final DateTime gecerlilik;

  Uri adres(MedyaVaryanti v) => v == MedyaVaryanti.tam ? tam : onizleme;

  @override
  String toString() => 'MedyaLinki';
}

/// Sunucudan toplu link isteyen fonksiyon (testlerde sahtesi verilir).
typedef MedyaLinkIsteyici =
    Future<List<MediaUrls>> Function(List<String> uploadIdleri);

/// `POST /v1/media/urls` (1–100 kimlik).
final medyaLinkIsteyiciProvider = Provider<MedyaLinkIsteyici>((ref) {
  final api = MediaApi(ref.watch(apiClientProvider));
  return (idler) async {
    final yanit = await api.getMediaUrls(
      body: MediaUrlsRequest(uploadIds: idler),
    );
    return yanit.media;
  };
}, name: 'medyaLinkIsteyiciProvider');

/// Şimdiki zaman (testlerde sabitlenir).
final medyaSaatiProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'medyaSaatiProvider',
);

/// Dosya linkleri ve görüntü baytları için bellek önbelleği (ADR-0021 §5,
/// ADR-0006):
///
/// - **Linkler:** aynı olay döngüsü turunda istenen kimlikler tek
///   `POST /v1/media/urls` isteğinde birleşir (en çok [topluEnCok]); link
///   `expires_at`'tan [guvenlikPayi] önce, en geç 1 saatte düşer. Yanıtta
///   olmayan (görülemeyen) kimlik [gorulemezSure] boyunca "yok" sayılır.
/// - **Baytlar:** indirilen varyantlar en çok [baytEnCok] bayt tutulur, en
///   eski kullanılan önce atılır. Diske hiçbir şey yazılmaz.
/// - Oturum değişince (çıkış, başka hesap) her şey boşalır.
/// - Linkler ve içerik log'a yazılmaz.
final class MedyaOnbellegi {
  MedyaOnbellegi({
    required MedyaLinkIsteyici isteyici,
    required MedyaTasima tasima,
    required DateTime Function() saat,
  }) : _isteyici = isteyici,
       _tasima = tasima,
       _saat = saat;

  final MedyaLinkIsteyici _isteyici;
  final MedyaTasima _tasima;
  final DateTime Function() _saat;

  static const int topluEnCok = 100;
  static const Duration guvenlikPayi = Duration(minutes: 1);
  static const Duration enUzunSure = Duration(hours: 1);
  static const Duration gorulemezSure = Duration(minutes: 5);
  static const int baytEnCok = 32 * 1024 * 1024;

  final Map<String, ({MedyaLinki? link, DateTime son})> _linkler = {};
  final Map<String, Completer<MedyaLinki?>> _bekleyen = {};
  final List<String> _sira = [];
  bool _planlandi = false;
  bool _kapandi = false;

  /// Ekleme sırası korunur (Dart haritası): ilk anahtar en eski kullanılan.
  final Map<String, Uint8List> _baytlar = {};
  final Map<String, Future<Uint8List?>> _inenler = {};
  int _toplamBayt = 0;

  /// Önbellekteki bayt toplamı (testler için).
  @visibleForTesting
  int get toplamBayt => _toplamBayt;

  /// [uploadId]'nin linkleri; görülemiyorsa `null`. Ağ hatası fırlatılır
  /// (önbelleğe alınmaz).
  Future<MedyaLinki?> link(String uploadId) {
    final simdi = _saat();
    final kayit = _linkler[uploadId];
    if (kayit != null && simdi.isBefore(kayit.son)) {
      return Future.value(kayit.link);
    }
    final bekleyen = _bekleyen[uploadId];
    if (bekleyen != null) return bekleyen.future;
    final c = Completer<MedyaLinki?>();
    _bekleyen[uploadId] = c;
    _sira.add(uploadId);
    if (!_planlandi) {
      _planlandi = true;
      scheduleMicrotask(_gonder);
    }
    return c.future;
  }

  Future<void> _gonder() async {
    _planlandi = false;
    while (_sira.isNotEmpty) {
      final parca = _sira.take(topluEnCok).toList();
      _sira.removeRange(0, parca.length);
      try {
        final gelen = await _isteyici(parca);
        if (_kapandi) return;
        final simdi = _saat();
        final bulunan = <String, MedyaLinki>{};
        for (final m in gelen) {
          final link = _cevir(m);
          if (link != null && parca.contains(m.uploadId)) {
            bulunan[m.uploadId] = link;
          }
        }
        for (final id in parca) {
          final link = bulunan[id];
          final DateTime son;
          if (link == null) {
            son = simdi.add(gorulemezSure);
          } else {
            final enGec = simdi.add(enUzunSure);
            final sunucu = link.gecerlilik.subtract(guvenlikPayi);
            son = sunucu.isBefore(enGec) ? sunucu : enGec;
          }
          _linkler[id] = (link: link, son: son);
          _bekleyen.remove(id)?.complete(link);
        }
      } on Exception catch (hata, iz) {
        for (final id in parca) {
          _bekleyen.remove(id)?.completeError(hata, iz);
        }
      }
    }
  }

  /// Sunucudan gelen linkleri doğrular; biri geçersizse dosya
  /// görülemiyor sayılır.
  static MedyaLinki? _cevir(MediaUrls m) {
    final onizleme = Uri.tryParse(m.previewUrl);
    final tam = Uri.tryParse(m.fullUrl);
    if (onizleme == null ||
        tam == null ||
        !medyaLinkiGecerli(onizleme) ||
        !medyaLinkiGecerli(tam) ||
        m.width < 1 ||
        m.height < 1) {
      return null;
    }
    return MedyaLinki(
      onizleme: onizleme,
      tam: tam,
      genislik: m.width,
      yukseklik: m.height,
      gecerlilik: m.expiresAt,
    );
  }

  /// [uploadId]'nin [varyant] baytları; görülemiyorsa `null`.
  ///
  /// Süresi dolmuş linkte (403) link bir kez yenilenip tekrar denenir.
  Future<Uint8List?> bayt(String uploadId, MedyaVaryanti varyant) {
    final anahtar = '$uploadId/${varyant.name}';
    final onceki = _baytlar.remove(anahtar);
    if (onceki != null) {
      _baytlar[anahtar] = onceki; // En son kullanılan sona.
      return Future.value(onceki);
    }
    return _inenler[anahtar] ??= _indir(uploadId, varyant, anahtar)
        .whenComplete(() => _inenler.remove(anahtar));
  }

  Future<Uint8List?> _indir(
    String uploadId,
    MedyaVaryanti varyant,
    String anahtar,
  ) async {
    for (var deneme = 1; ; deneme++) {
      final l = await link(uploadId);
      if (l == null) return null;
      try {
        final veri = await _tasima.indir(l.adres(varyant));
        if (!_kapandi) _sakla(anahtar, veri);
        return veri;
      } on MedyaDurumHatasi catch (h) {
        if (h.durum != 403 || deneme >= 2) rethrow;
        _linkler.remove(uploadId);
      }
    }
  }

  void _sakla(String anahtar, Uint8List veri) {
    if (veri.length > baytEnCok) return;
    final eski = _baytlar.remove(anahtar);
    if (eski != null) _toplamBayt -= eski.length;
    _baytlar[anahtar] = veri;
    _toplamBayt += veri.length;
    while (_toplamBayt > baytEnCok && _baytlar.isNotEmpty) {
      final ilk = _baytlar.keys.first;
      _toplamBayt -= _baytlar.remove(ilk)!.length;
    }
  }

  /// Yeni yüklenen [uploadId] için elde olan baytları önbelleğe koyar
  /// (ağdan yeniden indirmemek için).
  void yerelEkle(String uploadId, MedyaVaryanti varyant, Uint8List veri) =>
      _sakla('$uploadId/${varyant.name}', veri);

  /// Her şeyi bırakır.
  void kapat() {
    _kapandi = true;
    _linkler.clear();
    _baytlar.clear();
    _toplamBayt = 0;
    _sira.clear();
    for (final c in _bekleyen.values) {
      c.complete(null);
    }
    _bekleyen.clear();
  }
}

/// Oturum boyunca yaşayan medya önbelleği (kalıcı; ADR-0001 kural 4).
/// Oturum durumu değişince yeniden kurulur, eskisi boşaltılır.
final medyaOnbellegiProvider = Provider<MedyaOnbellegi>((ref) {
  ref.watch(oturumDurumuProvider);
  final onbellek = MedyaOnbellegi(
    isteyici: ref.watch(medyaLinkIsteyiciProvider),
    tasima: ref.watch(medyaTasimaProvider),
    saat: ref.watch(medyaSaatiProvider),
  );
  ref.onDispose(onbellek.kapat);
  return onbellek;
}, name: 'medyaOnbellegiProvider');
