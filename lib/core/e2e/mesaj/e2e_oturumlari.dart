import 'dart:convert';
import 'dart:typed_data';

import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/adres_kilidi.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Bu cihaz E2E için hazır değil (kimlik ya da sunucu kaydı yok).
final class E2eHazirDegil implements Exception {
  const E2eHazirDegil();

  @override
  String toString() => 'E2eHazirDegil';
}

/// Bir zarfın hedef cihazı: kullanıcı ve sunucudaki cihaz kaydı.
typedef ZarfHedefi = ({String kullaniciId, E2EPublicDevice cihaz});

/// Karşı cihazın güvenilen kimliği değişti (TOFU) ya da bir kullanıcının
/// cihaz kümesi değişti; "güvenlik kodu değişti" satırı için.
typedef GuvenlikDegisti = void Function(String kullaniciId, String kimlik);

/// Signal oturumları, cihaz listeleri ve adres başına sıra (ADR-0020
/// "Gönderim ve alım").
///
/// Her motor çağrısı ve ardından gelen depo yazmaları aynı adresin
/// kilidi altında yapılır. Durum depoya yazılamazsa [E2eDepoHatasi]
/// fırlatılır; iş tamamlanmış sayılmaz.
final class E2eOturumlari {
  E2eOturumlari({
    required this.motor,
    required this.depo,
    required ApiTransport api,
    AdresKilidi? kilit,
    this._guvenlikDegisti,
  }) : _users = UsersApi(api),
       kilit = kilit ?? AdresKilidi();

  final SignalMotoru motor;
  final E2eDeposu depo;
  final AdresKilidi kilit;
  final UsersApi _users;
  final GuvenlikDegisti? _guvenlikDegisti;

  /// Kullanıcı → sunucudaki cihaz listesi (yalnızca bellek).
  final Map<String, List<E2EPublicDevice>> _cihazlar = {};

  /// Kimlik ve kayıt; yoksa [E2eHazirDegil].
  DepoKimligi get kimlik => depo.kimlik ?? (throw const E2eHazirDegil());

  /// Bu cihazın Signal adresi (sunucudaki cihaz kimliği ve numarası);
  /// libsignal iki adresi mesaja bağlar. Kayıtlı değilse [E2eHazirDegil].
  SignalAdresi get yerelAdres {
    final c = depo.cihaz;
    if (c == null) throw const E2eHazirDegil();
    return SignalAdresi(ad: c.id, cihazNo: c.no);
  }

  /// [kullaniciId]'nin cihazları (önbellekten; [tazele] ya da önbellekte
  /// yoksa sunucudan). Tazelenen listede olmayan ya da kaydı değişen
  /// cihazların oturumu ve güvenilen kimliği silinir.
  Future<List<E2EPublicDevice>> cihazlar(
    String kullaniciId, {
    bool tazele = false,
  }) async {
    final onbellek = _cihazlar[kullaniciId];
    if (onbellek != null && !tazele) return onbellek;
    final liste = (await _users.listE2EDevices(userId: kullaniciId)).devices;
    _cihazlar[kullaniciId] = liste;
    await _eskileriTemizle(kullaniciId, liste);
    return liste;
  }

  /// Önbellekteki cihaz listesini bırakır.
  void unut(String kullaniciId) => _cihazlar.remove(kullaniciId);

  Future<void> _eskileriTemizle(
    String kullaniciId,
    List<E2EPublicDevice> liste,
  ) async {
    final guncel = {for (final c in liste) c.id: c};
    const onek = '${E2eDeposu.onek}kimlik_karsi.';
    for (final anahtar in depo.anahtarlar(onek)) {
      final cihazId = anahtar.substring(onek.length);
      final kayit = depo.karsiKimlik(cihazId);
      if (kayit == null || kayit.kullaniciId != kullaniciId) continue;
      final c = guncel[cihazId];
      final oturum = depo.oturum(cihazId);
      final degisti =
          c == null ||
          c.identityKey != base64.encode(kayit.acikAnahtar) ||
          (oturum != null &&
              (oturum.kayitKimligi != c.registrationId ||
                  oturum.cihazNo != c.deviceNumber));
      if (!degisti) continue;
      await kilit.altinda(cihazId, () => depo.karsiCihaziSil(cihazId));
    }
  }

  /// [hedefler]'den oturumu olmayanlar için ön anahtar paketlerini çekip
  /// oturum kurar (kullanıcı başına tek istek).
  Future<void> oturumlariKur(List<ZarfHedefi> hedefler) async {
    final eksik = <String, List<String>>{};
    for (final h in hedefler) {
      if (depo.oturum(h.cihaz.id) == null) {
        (eksik[h.kullaniciId] ??= []).add(h.cihaz.id);
      }
    }
    for (final giris in eksik.entries) {
      final kullaniciId = giris.key;
      final cihazIdleri = giris.value;
      final paketler = await _users.claimE2EPreKeyBundles(
        userId: kullaniciId,
        body: E2EBundleRequest(deviceIds: cihazIdleri),
      );
      for (final p in paketler.bundles) {
        if (!cihazIdleri.contains(p.deviceId)) continue;
        await kilit.altinda(p.deviceId, () => _paketIsle(kullaniciId, p));
      }
    }
  }

  Future<void> _paketIsle(String kullaniciId, E2EPreKeyBundle p) async {
    final k = kimlik;
    final kimlikAnahtari = _bayt(p.identityKey);
    await _kimligiDenetle(kullaniciId, p.deviceId, kimlikAnahtari);
    final mevcut = depo.oturum(p.deviceId);
    final oturum = await motor.paketIsle(
      kimlik: k.kayit,
      kayitKimligi: k.kayitKimligi,
      yerelAdres: yerelAdres,
      adres: SignalAdresi(ad: p.deviceId, cihazNo: p.deviceNumber),
      mevcutOturum: mevcut?.kayit,
      paket: OnAnahtarPaketi(
        kayitKimligi: p.registrationId,
        cihazNo: p.deviceNumber,
        onAnahtarId: p.oneTimePrekey?.keyId,
        onAnahtar: switch (p.oneTimePrekey) {
          final o? => _bayt(o.publicKey),
          null => null,
        },
        imzaliOnAnahtarId: p.signedPrekey.keyId,
        imzaliOnAnahtar: _bayt(p.signedPrekey.publicKey),
        imzaliOnAnahtarImzasi: _bayt(p.signedPrekey.signature),
        kimlikAnahtari: kimlikAnahtari,
        kyberOnAnahtarId: p.kyberPrekey.keyId,
        kyberOnAnahtar: _bayt(p.kyberPrekey.publicKey),
        kyberOnAnahtarImzasi: _bayt(p.kyberPrekey.signature),
      ),
    );
    await _yaz(
      depo.oturumYaz(
        p.deviceId,
        DepoOturumu(
          cihazNo: p.deviceNumber,
          kayitKimligi: p.registrationId,
          kayit: oturum,
        ),
      ),
    );
    await _yaz(
      depo.karsiKimlikYaz(
        p.deviceId,
        DepoKarsiKimlik(acikAnahtar: kimlikAnahtari, kullaniciId: kullaniciId),
      ),
    );
  }

  /// TOFU: [cihazId] için güvenilen kimlik varsa ve [acik]'tan farklıysa
  /// eski oturum ve kimlik silinir, "güvenlik kodu değişti" bildirilir.
  /// Kilit altında çağrılır.
  Future<void> _kimligiDenetle(
    String kullaniciId,
    String cihazId,
    Uint8List acik,
  ) async {
    final guvenilen = depo.karsiKimlik(cihazId);
    if (guvenilen == null || _esit(guvenilen.acikAnahtar, acik)) return;
    await _yaz(depo.karsiCihaziSil(cihazId));
    _guvenlikDegisti?.call(kullaniciId, 'kimlik:$cihazId');
  }

  /// [duz]'ü [hedef] cihaz için şifreler ve yeni oturumu yazar.
  Future<OutgoingEnvelope> sifrele(ZarfHedefi hedef, Uint8List duz) =>
      kilit.altinda(hedef.cihaz.id, () async {
        final k = kimlik;
        final oturum = depo.oturum(hedef.cihaz.id);
        if (oturum == null) {
          throw const SignalHatasi(SignalHatasiTuru.oturumYok);
        }
        final s = await motor.sifrele(
          kimlik: k.kayit,
          kayitKimligi: k.kayitKimligi,
          yerelAdres: yerelAdres,
          adres: SignalAdresi(ad: hedef.cihaz.id, cihazNo: oturum.cihazNo),
          oturum: oturum.kayit,
          duz: duz,
        );
        await _yaz(
          depo.oturumYaz(
            hedef.cihaz.id,
            DepoOturumu(
              cihazNo: oturum.cihazNo,
              kayitKimligi: oturum.kayitKimligi,
              kayit: s.yeniOturum,
            ),
          ),
        );
        return OutgoingEnvelope(
          deviceId: hedef.cihaz.id,
          registrationId: oturum.kayitKimligi,
          type: s.tur == SignalMesajTuru.onAnahtar
              ? OutgoingEnvelopeType.prekey
              : OutgoingEnvelopeType.whisper,
          content: base64.encode(s.sifreli),
        );
      });

  /// Gelen zarfı çözer, oturumu ve ön anahtar tüketimini yazar; düz
  /// baytları döndürür. Çağıran zarfın gönderen cihazının kilidini
  /// tutar ([kilit]).
  ///
  /// Çözülemezse [SignalHatasi]; depoya yazılamazsa [E2eDepoHatasi].
  Future<Uint8List> coz(E2EEnvelope z) async {
    final k = kimlik;
    final yerel = yerelAdres;
    final cihazId = z.senderDeviceId;
    final adres = SignalAdresi(ad: cihazId, cihazNo: z.senderDeviceNumber);
    final sifreli = _bayt(z.content);
    var oturum = depo.oturum(cihazId);
    if (oturum != null && oturum.cihazNo != z.senderDeviceNumber) {
      oturum = null;
    }
    if (z.type == E2EEnvelopeType.prekey) {
      final bilgi = await motor.onAnahtarMesajiIncele(sifreli);
      await _kimligiDenetle(z.senderUserId, cihazId, bilgi.gondericiKimligi);
      if (depo.karsiKimlik(cihazId) == null) oturum = null;
      final opId = bilgi.onAnahtarId;
      final sonuc = await motor.coz(
        kimlik: k.kayit,
        kayitKimligi: k.kayitKimligi,
        yerelAdres: yerel,
        adres: adres,
        tur: SignalMesajTuru.onAnahtar,
        sifreli: sifreli,
        oturum: oturum?.kayit,
        onAnahtar: opId == null ? null : depo.onAnahtar(opId),
        imzaliOnAnahtar: depo.imzali(bilgi.imzaliOnAnahtarId)?.kayit,
        kyberOnAnahtarlari: depo.kyberAdaylari,
      );
      await _sonCareDenetle(sonuc);
      await _yaz(
        depo.oturumYaz(
          cihazId,
          DepoOturumu(
            cihazNo: z.senderDeviceNumber,
            kayitKimligi: bilgi.kayitKimligi,
            kayit: sonuc.yeniOturum,
          ),
        ),
      );
      await _yaz(
        depo.karsiKimlikYaz(
          cihazId,
          DepoKarsiKimlik(
            acikAnahtar: sonuc.karsiKimlik,
            kullaniciId: z.senderUserId,
          ),
        ),
      );
      // Tek kullanımlık anahtarlar silinir (tutulmayan anahtar çalınamaz).
      if (sonuc.kullanilanOnAnahtarId case final id?) {
        await depo.hamSil(E2eDeposu.onAnahtarAnahtari(id));
      }
      if (sonuc.kullanilanKyberId case final id?
          when depo.kyberKimlikleri.contains(id)) {
        await depo.hamSil(E2eDeposu.kyberAnahtari(id));
      }
      return sonuc.duz;
    }
    if (oturum == null) {
      throw const SignalHatasi(SignalHatasiTuru.oturumYok);
    }
    final sonuc = await motor.coz(
      kimlik: k.kayit,
      kayitKimligi: k.kayitKimligi,
      yerelAdres: yerel,
      adres: adres,
      tur: SignalMesajTuru.signal,
      sifreli: sifreli,
      oturum: oturum.kayit,
    );
    await _yaz(
      depo.oturumYaz(
        cihazId,
        DepoOturumu(
          cihazNo: oturum.cihazNo,
          kayitKimligi: oturum.kayitKimligi,
          kayit: sonuc.yeniOturum,
        ),
      ),
    );
    return sonuc.duz;
  }

  /// Son çare Kyber anahtarı tekrar saldırısı denetimi: aynı
  /// `(kyberId, imzalıId, tabanAnahtar)` ikinci kez görülürse mesaj
  /// reddedilir (oturum yazılmaz).
  Future<void> _sonCareDenetle(CozulmusMesaj sonuc) async {
    final kyberId = sonuc.kullanilanKyberId;
    final taban = sonuc.kyberTabanAnahtari;
    if (kyberId == null || taban == null) return;
    if (depo.kyberKimlikleri.contains(kyberId)) return;
    final cift = '${sonuc.kullanilanImzaliId}:${base64.encode(taban)}';
    final gorulen = depo.kyberKullanilanlar(kyberId);
    if (gorulen.contains(cift)) {
      throw const SignalHatasi(SignalHatasiTuru.eskiMesaj);
    }
    await _yaz(depo.kyberKullanilanYaz(kyberId, {...gorulen, cift}));
  }

  static Future<void> _yaz(Future<bool> yazma) async {
    if (!await yazma) throw const E2eDepoHatasi();
  }

  static Uint8List _bayt(String b64) {
    final b = baytOku(b64);
    if (b == null) throw const SignalHatasi(SignalHatasiTuru.gecersizAnahtar);
    return b;
  }

  static bool _esit(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var fark = 0;
    for (var i = 0; i < a.length; i++) {
      fark |= a[i] ^ b[i];
    }
    return fark == 0;
  }
}
