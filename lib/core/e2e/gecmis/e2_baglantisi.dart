import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/cihaz/e2e_cihaz.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/realtime/realtime_olaylari.dart';

// Geçmiş katmanının ince arayüzlerinin E2E çekirdeğine (E2) bağlanması.
// `bagimliliklar.dart`'taki provider'lar bu sınıfları kurar; testler
// arayüzleri doğrudan sahteler.

/// E2'nin cihaz durumundan (`e2eCihazProvider`), kimlik kaydından ve
/// oturumun kullanıcı kimliğinden [GecmisCihazBilgisi] yayar. Cihaz hazır
/// değilse (kapalı, hazırlanıyor, hata, web) `null`.
final class E2CihazKaynagi implements E2eCihazDurumuKaynagi {
  E2CihazKaynagi({
    required this._depo,
    required this._kullaniciKimligi,
    required this._yenile,
  });

  final E2eDeposu _depo;
  final Future<String> Function() _kullaniciKimligi;
  final Future<void> Function() _yenile;

  final StreamController<GecmisCihazBilgisi?> _akis =
      StreamController.broadcast();
  GecmisCihazBilgisi? _guncel;
  String? _kullanici;
  int _nesil = 0;
  Future<void> _son = Future.value();

  @override
  GecmisCihazBilgisi? get guncel => _guncel;

  @override
  Stream<GecmisCihazBilgisi?> get degisiklikler => _akis.stream;

  @override
  Future<GecmisCihazBilgisi?> tazele() async {
    await _yenile();
    await _son;
    return _guncel;
  }

  /// E2'nin durumu değişti.
  void durumDegisti(E2eCihazBilgisi b) => _son = _guncelle(b, ++_nesil);

  Future<void> _guncelle(E2eCihazBilgisi b, int nesil) async {
    final cihazId = b.cihazId;
    if (!b.hazir || cihazId == null) {
      _yay(null, nesil);
      return;
    }
    try {
      await _depo.yukle();
      _kullanici ??= await _kullaniciKimligi();
    } on Exception {
      _yay(null, nesil);
      return;
    }
    final kimlik = _depo.kimlik;
    final kullanici = _kullanici;
    if (kimlik == null || kullanici == null) {
      _yay(null, nesil);
      return;
    }
    _yay(
      GecmisCihazBilgisi(
        kullaniciId: kullanici,
        cihazId: cihazId,
        kimlikAnahtari: kimlik.acikAnahtar,
        eslestirilmis: b.eslesmis,
        baskaEslestirilmisVar: b.digerEslesmisCihaz,
        gecmisSurumu: b.gecmisAnahtariSurumu,
        yenilemeGerekli: b.yenilemeGerekli,
      ),
      nesil,
    );
  }

  void _yay(GecmisCihazBilgisi? b, int nesil) {
    if (nesil != _nesil || _akis.isClosed) return;
    _guncel = b;
    _akis.add(b);
  }

  Future<void> kapat() => _akis.close();
}

/// E2'nin E2E deposu üzerinde bayt görünümü (`ham` kayıtlar base64).
final class E2DepoErisimi implements E2eDepoErisimi {
  const E2DepoErisimi(this._depo);

  final E2eDeposu _depo;

  @override
  Future<Uint8List?> oku(String anahtar) async {
    await _depo.yukle();
    return baytOku(_depo.ham(anahtar));
  }

  @override
  Future<void> yaz(String anahtar, Uint8List deger) async {
    await _depo.yukle();
    if (!await _depo.hamYaz(anahtar, base64.encode(deger))) {
      throw const E2eDepoHatasi();
    }
  }

  @override
  Future<void> sil(String anahtar) async {
    await _depo.yukle();
    if (!await _depo.hamSil(anahtar)) throw const E2eDepoHatasi();
  }

  @override
  Future<Map<String, Uint8List>> onekliOku(String onek) async {
    await _depo.yukle();
    return {
      for (final a in _depo.anahtarlar(onek))
        if (baytOku(_depo.ham(a)) case final deger?) a: deger,
    };
  }
}

/// Kullanıcının kendi diğer cihazlarıyla Signal oturumu: E2'nin
/// [E2eOturumlari]'yla (TOFU, adres kilidi, kalıcılık sırası).
final class E2KendiCihazOturumu implements KendiCihazOturumu {
  E2KendiCihazOturumu({
    required this._oturumlar,
    required this._kullaniciKimligi,
  });

  final E2eOturumlari _oturumlar;
  final Future<String> Function() _kullaniciKimligi;

  Future<ZarfHedefi> _hedef(String cihazId) async {
    final kullanici = await _kullaniciKimligi();
    var cihazlar = await _oturumlar.cihazlar(kullanici);
    if (!cihazlar.any((c) => c.id == cihazId)) {
      cihazlar = await _oturumlar.cihazlar(kullanici, tazele: true);
    }
    final cihaz = cihazlar.where((c) => c.id == cihazId).firstOrNull;
    if (cihaz == null) {
      throw const SignalHatasi(SignalHatasiTuru.oturumYok);
    }
    return (kullaniciId: kullanici, cihaz: cihaz);
  }

  @override
  Future<KendiCihazSifreli> sifrele(
    String cihazId,
    Uint8List duz, {
    Uint8List? beklenenKimlik,
  }) async {
    final ZarfHedefi hedef;
    if (beklenenKimlik != null) {
      // QR'daki kimlik: güncel listeyle karşılaştır; değişmiş oturumlar
      // E2'nin liste tazelemesinde silinir.
      final kullanici = await _kullaniciKimligi();
      final cihazlar = await _oturumlar.cihazlar(kullanici, tazele: true);
      final cihaz = cihazlar.where((c) => c.id == cihazId).firstOrNull;
      if (cihaz == null ||
          !sabitZamanliEsit(_bayt(cihaz.identityKey), beklenenKimlik)) {
        throw const E2eKimlikUyusmazligi();
      }
      hedef = (kullaniciId: kullanici, cihaz: cihaz);
    } else {
      hedef = await _hedef(cihazId);
    }
    await _oturumlar.oturumlariKur([hedef]);
    if (beklenenKimlik != null) {
      final guvenilen = _oturumlar.depo.karsiKimlik(cihazId);
      if (guvenilen == null ||
          !sabitZamanliEsit(guvenilen.acikAnahtar, beklenenKimlik)) {
        throw const E2eKimlikUyusmazligi();
      }
    }
    final zarf = await _oturumlar.sifrele(hedef, duz);
    return KendiCihazSifreli(
      tur: zarf.type == OutgoingEnvelopeType.prekey
          ? SignalMesajTuru.onAnahtar
          : SignalMesajTuru.signal,
      sifreli: _bayt(zarf.content),
    );
  }

  @override
  Future<Uint8List> coz(String cihazId, int tur, Uint8List sifreli) async {
    final hedef = await _hedef(cihazId);
    final zarf = E2EEnvelope(
      // Zarf değil, kendi cihazlar arası paket: kimlikler yalnızca adres
      // için; mesaj ve konuşma kimliği kullanılmaz.
      id: cihazId,
      messageId: cihazId,
      conversationId: cihazId,
      senderUserId: hedef.kullaniciId,
      senderDeviceId: cihazId,
      senderDeviceNumber: hedef.cihaz.deviceNumber,
      type: tur == SignalMesajTuru.onAnahtar
          ? E2EEnvelopeType.prekey
          : E2EEnvelopeType.whisper,
      content: base64.encode(sifreli),
      createdAt: DateTime.now().toUtc(),
    );
    return _oturumlar.kilit.altinda(cihazId, () => _oturumlar.coz(zarf));
  }

  static Uint8List _bayt(String b64) {
    try {
      return base64.decode(b64);
    } on FormatException {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
  }
}

/// E2'nin mesaj yayınından arşive yazılacaklar: gönderilen ve zarftan
/// çözülen mesajlar (arşivden okunanlar yeniden yazılmaz).
final class E2MesajAkisi implements CozulmusMesajAkisi {
  const E2MesajAkisi(this._akis);

  final Stream<CozulmusBirebirMesaj> _akis;

  @override
  Stream<ArsivlenecekMesaj> get mesajlar => _akis
      .where((m) => m.kaynak != CozulmusMesajKaynagi.arsiv)
      .map(
        (m) => ArsivlenecekMesaj(
          mesajId: m.mesajId,
          konusmaId: m.konusmaId,
          gonderenId: m.gonderenKullaniciId,
          olusturma: m.olusturma,
          govde: m.metin,
        ),
      );
}

/// Realtime olaylarından geçmiş katmanının sinyalleri.
final class E2Sinyalleri implements E2eSinyalleri {
  const E2Sinyalleri(this._olaylar);

  final Stream<RealtimeOlayi> _olaylar;

  @override
  Stream<E2eSinyali> get sinyaller => _olaylar
      .map<E2eSinyali?>(
        (o) => switch (o) {
          E2eEslemeCevaplandi(:final eslemeIstegiId) => EslemeCevaplandi(
            eslemeIstegiId,
          ),
          E2eGecmisAnahtariPaylasildi() => const GecmisAnahtariPaylasildi(),
          Baglandi() => const E2eYenidenBaglandi(),
          _ => null,
        },
      )
      .where((s) => s != null)
      .cast<E2eSinyali>();
}

/// [E2CihazKaynagi]'nı kurar ve E2'nin cihaz durumuna bağlar.
E2CihazKaynagi e2CihazKaynagiKur(Ref ref) {
  final store = ref.watch(sessionStoreProvider);
  final kaynak = E2CihazKaynagi(
    depo: ref.watch(e2eDeposuProvider),
    kullaniciKimligi: store.kullaniciKimligi,
    yenile: () => ref.read(e2eCihazProvider.notifier).yenile(),
  );
  ref
    ..listen(
      e2eCihazProvider,
      (_, b) => kaynak.durumDegisti(b),
      fireImmediately: true,
    )
    ..onDispose(() => unawaited(kaynak.kapat()));
  return kaynak;
}
