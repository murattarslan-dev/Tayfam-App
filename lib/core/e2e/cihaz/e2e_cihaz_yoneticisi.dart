import 'dart:convert';
import 'dart:typed_data';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Bu cihazın E2E durumu.
enum E2eCihazDurumu {
  /// Oturum yok ya da henüz başlamadı.
  kapali,

  /// Kayıt ya da durum okuması sürüyor.
  hazirlaniyor,

  /// Cihaz kayıtlı; şifreli mesaj gönderilip alınabilir.
  hazir,

  /// Hesabın E2E cihaz sınırı (5) dolu (`e2e-device-limit`): kullanıcı
  /// eski bir oturumu kapatmalı.
  sinirDolu,

  /// Kayıt ya da durum okuması başarısız (ağ, depo); yeniden denenir.
  hata,

  /// Web geliştirme derlemesi: E2E yok (ADR-0011).
  desteklenmiyor,
}

/// Cihazın yayımlanan E2E durumu (`GET /v1/me/e2e/device`).
///
/// Geçmiş arşivi ve QR eşleştirme (E3) [eslesmis], [digerEslesmisCihaz],
/// [gecmisAnahtariSurumu] ve [yenilemeGerekli]'yi dinler.
final class E2eCihazBilgisi {
  const E2eCihazBilgisi({
    required this.durum,
    this.cihazId,
    this.cihazNo,
    this.eslesmis = false,
    this.digerEslesmisCihaz = false,
    this.gecmisAnahtariSurumu = 0,
    this.yenilemeGerekli = false,
    this.hata,
  });

  const E2eCihazBilgisi.kapali() : this(durum: E2eCihazDurumu.kapali);

  /// Sunucu durumundan.
  factory E2eCihazBilgisi.sunucudan(E2EDeviceState s) => E2eCihazBilgisi(
    durum: E2eCihazDurumu.hazir,
    cihazId: s.device.id,
    cihazNo: s.device.deviceNumber,
    eslesmis: s.device.paired,
    digerEslesmisCihaz: s.otherPairedDevice,
    gecmisAnahtariSurumu: s.historyKeyVersion,
    yenilemeGerekli: s.rotationNeeded,
  );

  final E2eCihazDurumu durum;

  /// Sunucudaki cihaz kimliği (UUID).
  final String? cihazId;

  /// Signal cihaz numarası (1–127).
  final int? cihazNo;

  /// `device.paired`: bu cihaz geçmiş anahtarını taşıyor.
  final bool eslesmis;

  /// `other_paired_device`: hesabın eşleştirilmiş başka cihazı var.
  final bool digerEslesmisCihaz;

  /// `history_key_version` (0: hiç talep edilmedi).
  final int gecmisAnahtariSurumu;

  /// `rotation_needed`: geçmiş anahtarı yenilenmeli.
  final bool yenilemeGerekli;

  /// [E2eCihazDurumu.hata] ise son hata (metni ortak eşlemeden).
  final Object? hata;

  bool get hazir => durum == E2eCihazDurumu.hazir;

  @override
  bool operator ==(Object other) =>
      other is E2eCihazBilgisi &&
      other.durum == durum &&
      other.cihazId == cihazId &&
      other.cihazNo == cihazNo &&
      other.eslesmis == eslesmis &&
      other.digerEslesmisCihaz == digerEslesmisCihaz &&
      other.gecmisAnahtariSurumu == gecmisAnahtariSurumu &&
      other.yenilemeGerekli == yenilemeGerekli &&
      other.hata == hata;

  @override
  int get hashCode => Object.hash(
    durum,
    cihazId,
    cihazNo,
    eslesmis,
    digerEslesmisCihaz,
    gecmisAnahtariSurumu,
    yenilemeGerekli,
    hata,
  );
}

/// Cihaz kaydı ve ön anahtar bakımı (ADR-0020 "Cihaz").
///
/// - Kayıt: `GET /v1/me/e2e/device` → `e2e-device-not-registered` ise
///   anahtarlar üretilir, **önce depoya** yazılır, sonra
///   `POST /v1/me/e2e/device` (imzalı EC + son çare Kyber + 100 EC +
///   30 Kyber).
/// - Depoda anahtar yok ya da sunucudakinden farklıysa (ör. uygulama
///   yeniden kuruldu, depo çözülemedi) sunucudaki kayıt silinir ve
///   sıfırdan kaydolunur.
/// - Bakım: bir türden [esik]'ten az kaldıysa tamamlanır; imzalı ön anahtar
///   ve son çare Kyber [yenilemeAraligi]'nda bir yenilenir, eskiler
///   [eskiSaklama] sonra silinir (gecikmiş ilk mesajlar için).
final class E2eCihazYoneticisi {
  E2eCihazYoneticisi({
    required this.motor,
    required this.depo,
    required ApiTransport api,
    DateTime Function()? saat,
  }) : _me = MeApi(api),
       _users = UsersApi(api),
       _saat = saat ?? DateTime.now;

  static const int ecAdedi = 100;
  static const int kyberAdedi = 30;
  static const int esik = 10;
  static const Duration yenilemeAraligi = Duration(days: 7);
  static const Duration eskiSaklama = Duration(days: 30);

  /// Ön anahtar kimliklerinin üst sınırı (24 bit).
  static const int enBuyukKimlik = 0xFFFFFF;

  final SignalMotoru motor;
  final E2eDeposu depo;
  final MeApi _me;
  final UsersApi _users;
  final DateTime Function() _saat;

  /// Cihazı hazırlar: gerekirse kaydeder, ön anahtar bakımını yapar ve
  /// güncel durumu döndürür. Ağ ya da depo hatası fırlatılır.
  Future<E2eCihazBilgisi> hazirla() async {
    await depo.yukle();
    E2EDeviceState durum;
    try {
      durum = await _me.getMyE2EDevice();
    } on ApiProblem catch (hata) {
      if (hata.type != ProblemType.e2eDeviceNotRegistered) rethrow;
      return _kaydol();
    }
    final yerel = depo.kimlik;
    if (yerel == null ||
        base64.encode(yerel.acikAnahtar) != durum.device.identityKey) {
      // Sunucu bu oturumun cihazını tanıyor ama anahtarları bizde yok:
      // kayıt silinir, sıfırdan kaydolunur.
      await _me.unregisterE2EDevice();
      return _kaydol();
    }
    final cihaz = depo.cihaz;
    if (cihaz == null || cihaz.id != durum.device.id) {
      await _yaz(
        depo.cihazYaz(
          DepoCihazi(id: durum.device.id, no: durum.device.deviceNumber),
        ),
      );
    }
    final sayilar = await bakim(durum.prekeyCounts);
    if (!identical(sayilar, durum.prekeyCounts)) {
      durum = await _me.getMyE2EDevice();
    }
    return E2eCihazBilgisi.sunucudan(durum);
  }

  /// Sunucudaki durumu yeniden okur (E3 geçmiş anahtarı talebinden
  /// sonra çağırır).
  Future<E2eCihazBilgisi> durumOku() async =>
      E2eCihazBilgisi.sunucudan(await _me.getMyE2EDevice());

  /// `e2e.prekeys_low` ya da açılış: sayıları okuyup bakım yapar.
  Future<void> onAnahtarlarAzaldi() async {
    final durum = await _me.getMyE2EDevice();
    await bakim(durum.prekeyCounts);
  }

  Future<E2eCihazBilgisi> _kaydol() async {
    // Eski oturumlar ve anahtarlar yeni kimlikle geçersizdir.
    await depo.temizle();
    final kimlik = await motor.kimlikUret();
    await _yaz(
      depo.kimlikYaz(
        DepoKimligi(
          kayit: kimlik.kayit,
          acikAnahtar: kimlik.acikAnahtar,
          kayitKimligi: kimlik.kayitKimligi,
        ),
      ),
    );
    final simdi = _saat().toUtc();
    final imzali = await motor.imzaliOnAnahtarUret(kimlik.kayit, 1);
    final sonCare = await motor.kyberOnAnahtarUret(kimlik.kayit, 1);
    final ecler = await motor.onAnahtarUret(1, ecAdedi);
    final kyberler = <KyberOnAnahtarKaydi>[
      for (var i = 0; i < kyberAdedi; i++)
        await motor.kyberOnAnahtarUret(kimlik.kayit, 2 + i),
    ];
    await _yaz(
      depo.imzaliYaz(
        DepoImzaliKayit(id: imzali.id, kayit: imzali.kayit, zaman: simdi),
      ),
    );
    await _yaz(
      depo.sonCareYaz(
        DepoImzaliKayit(id: sonCare.id, kayit: sonCare.kayit, zaman: simdi),
      ),
    );
    for (final e in ecler) {
      await _yaz(depo.onAnahtarYaz(e.id, e.kayit));
    }
    for (final k in kyberler) {
      await _yaz(depo.kyberYaz(k.id, k.kayit));
    }
    await _yaz(
      depo.sayacYaz(
        DepoSayaci(
          sonrakiOnAnahtar: _sonraki(ecler.isEmpty ? 0 : ecler.last.id),
          sonrakiKyber: _sonraki(1 + kyberAdedi),
          sonrakiImzali: 2,
          etkinImzali: imzali.id,
          etkinSonCare: sonCare.id,
        ),
      ),
    );
    final govde = E2EDeviceRegistration(
      registrationId: kimlik.kayitKimligi,
      identityKey: base64.encode(kimlik.acikAnahtar),
      signedPrekey: _imzaliJson(imzali.id, imzali.acikAnahtar, imzali.imza),
      kyberLastResortPrekey: _imzaliJson(
        sonCare.id,
        sonCare.acikAnahtar,
        sonCare.imza,
      ),
      oneTimePrekeys: [for (final e in ecler) _onAnahtarJson(e)],
      kyberPrekeys: [
        for (final k in kyberler) _imzaliJson(k.id, k.acikAnahtar, k.imza),
      ],
    );
    E2EDeviceRegistered kayit;
    try {
      kayit = await _me.registerE2EDevice(body: govde);
    } on ApiProblem catch (hata) {
      if (hata.type != ProblemType.e2eDeviceAlreadyRegistered) rethrow;
      // Bu oturumun eski anahtarlarla kaydı var: silinip yeniden denenir.
      await _me.unregisterE2EDevice();
      kayit = await _me.registerE2EDevice(body: govde);
    }
    await _yaz(
      depo.cihazYaz(
        DepoCihazi(id: kayit.device.id, no: kayit.device.deviceNumber),
      ),
    );
    return E2eCihazBilgisi.sunucudan(await _me.getMyE2EDevice());
  }

  /// Ön anahtar bakımı. Bir şey yüklendiyse yeni sayıları, yoksa
  /// [sayilar]'ı aynen döndürür.
  Future<E2EPreKeyCounts> bakim(E2EPreKeyCounts sayilar) async {
    final kimlik = depo.kimlik;
    if (kimlik == null) return sayilar;
    final simdi = _saat().toUtc();
    var sayac = depo.sayac;
    await _eskileriSil(simdi, sayac);

    final ecEksik = _eksik(sayilar.ec, ecAdedi, sayilar.low);
    final yeniEc = ecEksik > 0
        ? await motor.onAnahtarUret(sayac.sonrakiOnAnahtar, ecEksik)
        : const <OnAnahtarKaydi>[];
    final kyberEksik = _eksik(sayilar.kyber, kyberAdedi, sayilar.low);
    var kyberId = sayac.sonrakiKyber;
    final yeniKyber = <KyberOnAnahtarKaydi>[];
    for (var i = 0; i < kyberEksik; i++) {
      yeniKyber.add(await motor.kyberOnAnahtarUret(kimlik.kayit, kyberId));
      kyberId = _sonraki(kyberId);
    }

    final etkinId = sayac.etkinImzali;
    final etkin = etkinId == null ? null : depo.imzali(etkinId);
    final yenile =
        etkin == null || simdi.difference(etkin.zaman) >= yenilemeAraligi;
    ImzaliOnAnahtarKaydi? yeniImzali;
    KyberOnAnahtarKaydi? yeniSonCare;
    if (yenile) {
      yeniImzali = await motor.imzaliOnAnahtarUret(
        kimlik.kayit,
        sayac.sonrakiImzali,
      );
      yeniSonCare = await motor.kyberOnAnahtarUret(kimlik.kayit, kyberId);
      kyberId = _sonraki(kyberId);
    }
    if (yeniEc.isEmpty && yeniKyber.isEmpty && !yenile) return sayilar;

    for (final e in yeniEc) {
      await _yaz(depo.onAnahtarYaz(e.id, e.kayit));
    }
    for (final k in yeniKyber) {
      await _yaz(depo.kyberYaz(k.id, k.kayit));
    }
    if (yeniImzali != null && yeniSonCare != null) {
      await _yaz(
        depo.imzaliYaz(
          DepoImzaliKayit(
            id: yeniImzali.id,
            kayit: yeniImzali.kayit,
            zaman: simdi,
          ),
        ),
      );
      await _yaz(
        depo.sonCareYaz(
          DepoImzaliKayit(
            id: yeniSonCare.id,
            kayit: yeniSonCare.kayit,
            zaman: simdi,
          ),
        ),
      );
    }
    sayac = sayac.ile(
      sonrakiOnAnahtar: yeniEc.isEmpty ? null : _sonraki(yeniEc.last.id),
      sonrakiKyber: kyberId,
      sonrakiImzali: yeniImzali == null ? null : _sonraki(yeniImzali.id),
    );
    await _yaz(depo.sayacYaz(sayac));

    final yeni = await _me.uploadE2EPreKeys(
      body: E2EPreKeyUpload(
        signedPrekey: yeniImzali == null
            ? null
            : _imzaliJson(
                yeniImzali.id,
                yeniImzali.acikAnahtar,
                yeniImzali.imza,
              ),
        kyberLastResortPrekey: yeniSonCare == null
            ? null
            : _imzaliJson(
                yeniSonCare.id,
                yeniSonCare.acikAnahtar,
                yeniSonCare.imza,
              ),
        oneTimePrekeys: yeniEc.isEmpty
            ? null
            : [for (final e in yeniEc) _onAnahtarJson(e)],
        kyberPrekeys: yeniKyber.isEmpty
            ? null
            : [
                for (final k in yeniKyber)
                  _imzaliJson(k.id, k.acikAnahtar, k.imza),
              ],
      ),
    );

    // Sunucu yeni imzalı anahtarları kabul etti: eskiler emekliye ayrılır
    // (gecikmiş ilk mesajlar için 30 gün tutulur).
    if (yeniImzali != null && yeniSonCare != null) {
      for (final eski in depo.imzalilar) {
        if (eski.id != yeniImzali.id && eski.emekli == null) {
          await depo.imzaliYaz(_emekli(eski, simdi));
        }
      }
      for (final eski in depo.sonCareler) {
        if (eski.id != yeniSonCare.id && eski.emekli == null) {
          await depo.sonCareYaz(_emekli(eski, simdi));
        }
      }
      await _yaz(
        depo.sayacYaz(
          depo.sayac.ile(
            etkinImzali: yeniImzali.id,
            etkinSonCare: yeniSonCare.id,
          ),
        ),
      );
    }
    return yeni;
  }

  Future<void> _eskileriSil(DateTime simdi, DepoSayaci sayac) async {
    for (final k in depo.imzalilar) {
      final emekli = k.emekli;
      if (k.id != sayac.etkinImzali &&
          emekli != null &&
          simdi.difference(emekli) >= eskiSaklama) {
        await depo.hamSil(E2eDeposu.imzaliAnahtari(k.id));
      }
    }
    for (final k in depo.sonCareler) {
      final emekli = k.emekli;
      if (k.id != sayac.etkinSonCare &&
          emekli != null &&
          simdi.difference(emekli) >= eskiSaklama) {
        await depo.hamSil(E2eDeposu.sonCareAnahtari(k.id));
        await depo.hamSil(E2eDeposu.kyberKullanilanAnahtari(k.id));
      }
    }
  }

  /// Kendi hesabına (bu cihaz dışında) son bakıştan sonra eklenen cihaz
  /// olayları. İlk bakışta yalnızca en yeni olay işaretlenir.
  Future<List<E2EKeyEvent>> yeniKendiCihazlari(String benId) async {
    final cihaz = depo.cihaz;
    final yanit = await _users.listE2EKeyEvents(
      userId: benId,
      pageSize: 50,
    );
    final liste = yanit.events;
    if (liste.isEmpty) return const [];
    final son = depo.sonAnahtarOlayi(benId);
    await depo.sonAnahtarOlayiYaz(benId, liste.first.id);
    if (son == null) return const [];
    final yeniler = <E2EKeyEvent>[];
    for (final o in liste) {
      if (o.id == son) break;
      if (o.type == E2EKeyEventType.deviceAdded && o.deviceId != cihaz?.id) {
        yeniler.add(o);
      }
    }
    return yeniler;
  }

  static DepoImzaliKayit _emekli(DepoImzaliKayit k, DateTime simdi) =>
      DepoImzaliKayit(id: k.id, kayit: k.kayit, zaman: k.zaman, emekli: simdi);

  /// Bir türün tamamlanacak adedi: [esik]'in altına düştüyse ya da sunucu
  /// azaldı dediyse [hedef]'e kadar.
  static int _eksik(int sayi, int hedef, bool azaldi) =>
      (sayi < esik || azaldi) && sayi < hedef ? hedef - sayi : 0;

  static int _sonraki(int id) => id >= enBuyukKimlik ? 1 : id + 1;

  static E2ESignedPreKey _imzaliJson(int id, Uint8List acik, Uint8List imza) =>
      E2ESignedPreKey(
        keyId: id,
        publicKey: base64.encode(acik),
        signature: base64.encode(imza),
      );

  static E2EPreKey _onAnahtarJson(OnAnahtarKaydi e) =>
      E2EPreKey(keyId: e.id, publicKey: base64.encode(e.acikAnahtar));

  static Future<void> _yaz(Future<bool> yazma) async {
    if (!await yazma) throw const E2eDepoHatasi();
  }
}
