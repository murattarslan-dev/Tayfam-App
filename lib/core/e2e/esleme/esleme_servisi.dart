import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Yeni cihazın açtığı eşleştirme isteği ve QR'ı.
@immutable
final class EslemeOturumu {
  const EslemeOturumu({required this.qr, required this.bitis});

  final EslemeQr qr;

  /// İsteğin sona erdiği an (sunucu: 10 dakika).
  final DateTime bitis;
}

/// QR eşleştirme (Tayfam-Api ADR-0018 §5; ADR-0020): cevap, kullanıcının
/// kendi cihazları arasındaki Signal oturumuyla şifrelenir.
final class EslemeServisi {
  EslemeServisi({
    required GecmisApi api,
    required KendiCihazOturumu oturum,
    required GecmisAnahtariDeposu anahtarlar,
    required E2eCihazDurumuKaynagi kaynak,
    required PaylasimAlici paylasimAlici,
  }) : _api = api,
       _oturum = oturum,
       _anahtarlar = anahtarlar,
       _kaynak = kaynak,
       _paylasimAlici = paylasimAlici;

  final GecmisApi _api;
  final KendiCihazOturumu _oturum;
  final GecmisAnahtariDeposu _anahtarlar;
  final E2eCihazDurumuKaynagi _kaynak;
  final PaylasimAlici _paylasimAlici;

  // ---------------------------------------------------------------------
  // Eşleştirilmiş cihaz: QR'ı okutup cevaplar
  // ---------------------------------------------------------------------

  /// Taranan [qrMetni]'ni doğrular ve geçmiş anahtarlarını yeni cihaza
  /// gönderir.
  ///
  /// QR'daki kimlik anahtarı sunucunun cihaz listesindeki o cihazın
  /// anahtarıyla birebir aynı değilse hiçbir şey şifrelenmeden
  /// [EslemeHataTuru.anahtarUyusmuyor] fırlatılır; oturum da yalnızca bu
  /// kimlikle kurulur (sunucu araya cihaz sokamaz).
  Future<void> cevapla(String qrMetni) async {
    final qr = EslemeQr.ayristir(qrMetni);
    final bilgi = _kaynak.guncel;
    if (bilgi == null || !bilgi.eslestirilmis) {
      throw const EslemeHatasi(EslemeHataTuru.eslestirilmemis);
    }
    if (qr.cihazId == bilgi.cihazId) {
      throw const EslemeHatasi(EslemeHataTuru.kendiCihazi);
    }
    final cihazlar = await _api.cihazlar(bilgi.kullaniciId);
    final cihaz = cihazlar.where((c) => c.id == qr.cihazId).firstOrNull;
    if (cihaz == null) {
      throw const EslemeHatasi(EslemeHataTuru.cihazBulunamadi);
    }
    final Uint8List sunucudaki;
    try {
      sunucudaki = base64.decode(cihaz.identityKey);
    } on FormatException {
      throw const EslemeHatasi(EslemeHataTuru.anahtarUyusmuyor);
    }
    if (!sabitZamanliEsit(sunucudaki, qr.kimlikAnahtari)) {
      throw const EslemeHatasi(EslemeHataTuru.anahtarUyusmuyor);
    }

    for (var deneme = 0; deneme < 2; deneme++) {
      final surum = _kaynak.guncel?.gecmisSurumu ?? bilgi.gecmisSurumu;
      final anahtarlar = await _anahtarlar.hepsi();
      if (!anahtarlar.containsKey(surum)) {
        // Güncel sürüm henüz alınmadı (yenileme paylaşımı bekliyor).
        await _paylasimAlici.al();
        anahtarlar.addAll(await _anahtarlar.hepsi());
        if (!anahtarlar.containsKey(surum)) {
          throw const EslemeHatasi(EslemeHataTuru.anahtarYenilendi);
        }
      }
      final duz = EslemeCevabi(
        kod: qr.kod,
        istekId: qr.istekId,
        anahtarlar: anahtarlar,
      ).kodla();
      final KendiCihazSifreli sifreli;
      try {
        sifreli = await _oturum.sifrele(
          qr.cihazId,
          duz,
          beklenenKimlik: qr.kimlikAnahtari,
        );
      } on E2eKimlikUyusmazligi {
        throw const EslemeHatasi(EslemeHataTuru.anahtarUyusmuyor);
      }
      final paket = kendiCihazPaketi(sifreli);
      if (paket.length > anahtarPaketiEnFazla) {
        throw const EslemeHatasi(EslemeHataTuru.cevapGecersiz);
      }
      try {
        await _api.eslemeyiCevapla(qr.istekId, surum, paket);
        return;
      } on ApiProblem catch (problem) {
        switch (problem.type) {
          case ProblemType.e2eLinkRequestNotFound:
            throw const EslemeHatasi(EslemeHataTuru.suresiDoldu);
          case ProblemType.e2eNotPaired:
            throw const EslemeHatasi(EslemeHataTuru.eslestirilmemis);
          case ProblemType.e2eHistoryKeyStale when deneme == 0:
            await _paylasimAlici.al();
            await _kaynak.tazele();
          default:
            rethrow;
        }
      }
    }
    throw const EslemeHatasi(EslemeHataTuru.anahtarYenilendi);
  }

  // ---------------------------------------------------------------------
  // Yeni cihaz: QR'ı gösterir, cevabı alır
  // ---------------------------------------------------------------------

  /// Eşleştirme isteği açar ve QR içeriğini üretir.
  Future<EslemeOturumu> baslat() async {
    final bilgi = _kaynak.guncel;
    if (bilgi == null) {
      throw const EslemeHatasi(EslemeHataTuru.eslestirilmemis);
    }
    final istek = await _api.eslemeIstegiAc();
    final rastgele = Random.secure();
    final qr = EslemeQr(
      istekId: istek.linkRequestId,
      cihazId: bilgi.cihazId,
      kimlikAnahtari: base64.decode(bilgi.durum.device.identityKey),
      kod: Uint8List.fromList([
        for (var i = 0; i < dogrulamaKoduUzunlugu; i++) rastgele.nextInt(256),
      ]),
    );
    return EslemeOturumu(qr: qr, bitis: istek.expiresAt);
  }

  /// İsteğe cevap geldiyse çözer, doğrular, anahtarları depoya yazar ve
  /// eşleştirmeyi tamamlar (`true`). Cevap yoksa `false`.
  ///
  /// - Süresi dolmuşsa [EslemeHataTuru.suresiDoldu].
  /// - Cevap çözülemez, istek kimliği ya da doğrulama kodu tutmazsa
  ///   [EslemeHataTuru.cevapGecersiz]; hiçbir anahtar yazılmaz.
  /// - Arada anahtar yenilendiyse [EslemeHataTuru.anahtarYenilendi]:
  ///   yeni istek açılmalı.
  Future<bool> cevabiAl(EslemeOturumu oturum) async {
    final istekId = oturum.qr.istekId;
    final istek = await _bulunamazsa(() => _api.eslemeIstegi(istekId));
    if (!istek.answered) return false;
    final cevap = istek.answer;
    final gonderen = istek.answeredByDeviceId;
    const gecersiz = EslemeHatasi(EslemeHataTuru.cevapGecersiz);
    if (cevap == null || gonderen == null) throw gecersiz;

    final Uint8List bayt;
    try {
      bayt = base64.decode(cevap);
    } on FormatException {
      throw gecersiz;
    }
    final acik = kendiCihazPaketiniAc(bayt);
    if (acik == null) throw gecersiz;
    final Uint8List duz;
    try {
      duz = await _oturum.coz(gonderen, acik.tur, acik.sifreli);
    } on SignalHatasi {
      throw gecersiz;
    }
    final cozulen = EslemeCevabi.coz(duz);
    if (cozulen == null ||
        cozulen.istekId != istekId ||
        !sabitZamanliEsit(cozulen.kod, oturum.qr.kod)) {
      throw gecersiz;
    }
    final surum = istek.historyKeyVersion;
    if (surum != null && !cozulen.anahtarlar.containsKey(surum)) {
      throw gecersiz;
    }

    for (final MapEntry(:key, :value) in cozulen.anahtarlar.entries) {
      await _anahtarlar.yaz(key, value);
    }
    try {
      await _bulunamazsa(() => _api.eslemeyiTamamla(istekId));
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.e2eHistoryKeyStale) {
        throw const EslemeHatasi(EslemeHataTuru.anahtarYenilendi);
      }
      rethrow;
    }
    await _kaynak.tazele();
    return true;
  }

  static Future<T> _bulunamazsa<T>(Future<T> Function() istek) async {
    try {
      return await istek();
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.e2eLinkRequestNotFound) {
        throw const EslemeHatasi(EslemeHataTuru.suresiDoldu);
      }
      rethrow;
    }
  }
}

/// QR eşleştirme servisi.
final eslemeServisiProvider = Provider<EslemeServisi>((ref) {
  final s = ref.watch(gecmisServisleriProvider);
  return EslemeServisi(
    api: s.api,
    oturum: s.oturum,
    anahtarlar: s.anahtarlar,
    kaynak: s.kaynak,
    paylasimAlici: s.paylasimAlici,
  );
}, name: 'eslemeServisiProvider');
