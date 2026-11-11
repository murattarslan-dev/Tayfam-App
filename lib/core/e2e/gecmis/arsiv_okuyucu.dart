import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';

/// Arşivden çözülmüş bir mesaj. Yalnızca bellektedir; `toString` içerik
/// yazmaz.
@immutable
final class ArsivMesaji {
  const ArsivMesaji({
    required this.mesajId,
    required this.gonderenId,
    required this.olusturma,
    required this.govde,
  });

  final String mesajId;
  final String gonderenId;
  final DateTime olusturma;
  final String govde;

  @override
  String toString() => 'ArsivMesaji($mesajId)';
}

/// Konuşma arşivine bu cihazın erişimi.
enum ArsivErisimi {
  /// E2E yok (web geliştirme derlemesi ya da cihaz kaydı yok).
  yok,

  /// Bu cihaz eşleştirilmemiş: arşiv okunamaz (QR önerilir).
  eslestirilmemis,

  /// Arşiv okundu.
  okundu,
}

/// Bir konuşmanın bellekte çözülmüş arşivi.
@immutable
final class KonusmaArsivi {
  const KonusmaArsivi({
    required this.erisim,
    this.mesajlar = const {},
    this.okunamayan = 0,
    this.sonrakiSayfa,
  });

  const KonusmaArsivi.yok() : this(erisim: ArsivErisimi.yok);

  const KonusmaArsivi.eslestirilmemis()
    : this(erisim: ArsivErisimi.eslestirilmemis);

  final ArsivErisimi erisim;

  /// `message_id` → çözülmüş mesaj; birebir konuşma notifier'ı mesaj
  /// listesindeki `encryption: e2e` mesajlarının metnini buradan alır.
  final Map<String, ArsivMesaji> mesajlar;

  /// Anahtarı bu cihazda olmayan (önceki bir geçmiş anahtarıyla yazılmış)
  /// ya da çözülemeyen kayıt sayısı. 0'dan büyükse "eski mesajların bu
  /// cihazda okunamıyor" gösterilir.
  final int okunamayan;

  /// Daha eski kayıtların opak sayfa token'ı.
  final String? sonrakiSayfa;

  /// Eski mesajlar için "okunamıyor" boş durumu gösterilmeli mi.
  bool get eskiMesajlarOkunamiyor =>
      erisim == ArsivErisimi.eslestirilmemis || okunamayan > 0;

  /// Okunan sayfaların üstüne [sayfa]'yı ekler.
  KonusmaArsivi ekle(KonusmaArsivi sayfa) => KonusmaArsivi(
    erisim: sayfa.erisim,
    mesajlar: {...mesajlar, ...sayfa.mesajlar},
    okunamayan: okunamayan + sayfa.okunamayan,
    sonrakiSayfa: sayfa.sonrakiSayfa,
  );
}

/// Konuşma arşivini okur ve bellekte çözer (Tayfam-Api ADR-0018 §4).
/// Her konuşma açılışında yeniden indirilir; diske yazılmaz (ADR-0006).
final class ArsivOkuyucu {
  ArsivOkuyucu({
    required this._api,
    required this._bicim,
    required this._anahtarlar,
    required this._kaynak,
  });

  final GecmisApi _api;
  final ArsivBicimi _bicim;
  final GecmisAnahtariDeposu _anahtarlar;
  final E2eCihazDurumuKaynagi _kaynak;

  /// [konusmaId]'nin bir sayfa arşivi ([sayfa] verilmezse en yeniler).
  Future<KonusmaArsivi> oku(String konusmaId, {String? sayfa}) async {
    final bilgi = _kaynak.guncel;
    if (bilgi == null) return const KonusmaArsivi.yok();
    if (!bilgi.eslestirilmis) return const KonusmaArsivi.eslestirilmemis();

    final liste = await () async {
      try {
        return await _api.arsivSayfasi(konusmaId, sayfa: sayfa);
      } on ApiProblem catch (problem) {
        if (problem.type == ProblemType.e2eNotPaired) return null;
        rethrow;
      }
    }();
    if (liste == null) return const KonusmaArsivi.eslestirilmemis();

    final anahtarlar = await _anahtarlar.hepsi();
    final mesajlar = <String, ArsivMesaji>{};
    var okunamayan = 0;
    for (final kayit in liste.entries) {
      final anahtar = anahtarlar[kayit.keyVersion];
      if (kayit.conversationId != konusmaId || anahtar == null) {
        okunamayan++;
        continue;
      }
      final Uint8List icerik;
      try {
        icerik = base64.decode(kayit.content);
      } on FormatException {
        okunamayan++;
        continue;
      }
      final duz = await _bicim.coz(
        gecmisAnahtari: anahtar,
        surum: kayit.keyVersion,
        kullaniciId: bilgi.kullaniciId,
        mesajId: kayit.messageId,
        icerik: icerik,
      );
      if (duz == null) {
        okunamayan++;
        continue;
      }
      mesajlar[kayit.messageId] = ArsivMesaji(
        mesajId: kayit.messageId,
        gonderenId: duz.gonderenId,
        olusturma: duz.olusturma,
        govde: duz.govde,
      );
    }
    return KonusmaArsivi(
      erisim: ArsivErisimi.okundu,
      mesajlar: mesajlar,
      okunamayan: okunamayan,
      sonrakiSayfa: liste.nextPageToken,
    );
  }
}
