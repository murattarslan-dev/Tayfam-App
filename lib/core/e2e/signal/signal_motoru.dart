import 'dart:typed_data';

/// Signal protokolü motoru (ADR-0010, güncelleme 2026-11-11).
///
/// Android'de Signal'in resmi `org.signal:libsignal-android` paketinin
/// üzerindeki ince Kotlin köprüsüyle (`tayfam/e2e/signal` platform kanalı)
/// uygulanır; iOS sonra Signal'in Swift paketiyle aynı arayüzü uygular.
/// Web geliştirme derlemesinde E2E yoktur: her çağrı `UnsupportedError`.
///
/// **Durumsuz:** kalıcı durum Dart'tadır (güvenli depo). Her çağrı gereken
/// kayıtları alır, değişen kayıtları döner; motor hiçbir şey saklamaz ve
/// log'lamaz. Kayıtlar libsignal'in serileştirilmiş biçimidir (opak);
/// ayrıştırılmaz, üretilmez.
///
/// Kalıcılık sırası (ADR-0010): dönen yeni kayıtlar güvenli depoya
/// yazılmadan mesaj gönderilmiş ya da alınmış sayılmaz. Aynı
/// [SignalAdresi] için çağrılar çağıran tarafta sıraya sokulur.
///
/// Hata durumunda yalnızca [SignalHatasi] fırlatılır.
abstract interface class SignalMotoru {
  // ---------------------------------------------------------------------
  // Anahtar üretimi
  // ---------------------------------------------------------------------

  /// Yeni kimlik anahtar çifti ve kayıt kimliği (registrationId) üretir.
  Future<KimlikKaydi> kimlikUret();

  /// [baslangicId]'den başlayarak [adet] tek kullanımlık EC ön anahtar
  /// üretir. Kimlikler `baslangicId, baslangicId + 1, …`; 24 bitte
  /// (`0xFFFFFF`) sarar, 0 atlanır.
  Future<List<OnAnahtarKaydi>> onAnahtarUret(int baslangicId, int adet);

  /// [kimlik] (serileştirilmiş kimlik anahtar çifti) ile imzalanmış EC
  /// ön anahtar üretir.
  Future<ImzaliOnAnahtarKaydi> imzaliOnAnahtarUret(Uint8List kimlik, int id);

  /// [kimlik] ile imzalanmış Kyber-1024 ön anahtar üretir. Tek kullanımlık
  /// ve son çare (last resort) Kyber anahtarı aynı biçimdedir; hangisi
  /// olduğunu çağıran taraf bilir.
  Future<KyberOnAnahtarKaydi> kyberOnAnahtarUret(Uint8List kimlik, int id);

  // ---------------------------------------------------------------------
  // Oturum kurma
  // ---------------------------------------------------------------------

  /// Karşı cihazın sunucudan gelen ön anahtar paketini işleyip yeni oturum
  /// kaydını döner. [mevcutOturum] verilirse eski durumlar korunur (yeni
  /// oturum güncel olur).
  ///
  /// Kimlik TOFU denetimi çağıran taraftadır (paket.kimlikAnahtari depodaki
  /// ile karşılaştırılır); motor kimliği her zaman güvenilir sayar. Paket
  /// imzaları libsignal tarafından doğrulanır; geçersizse
  /// [SignalHatasiTuru.gecersizAnahtar].
  Future<Uint8List> paketIsle({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi adres,
    Uint8List? mevcutOturum,
    required OnAnahtarPaketi paket,
  });

  // ---------------------------------------------------------------------
  // Şifreleme ve çözme
  // ---------------------------------------------------------------------

  /// [duz]'ü [oturum] ile şifreler. Oturumda karşılık alınmamış bir ön
  /// anahtar kurulumu varsa sonuç tür 3 (PreKeySignalMessage), yoksa tür 2
  /// (SignalMessage) olur. Oturum yoksa [SignalHatasiTuru.oturumYok].
  Future<SifreliMesaj> sifrele({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi adres,
    required Uint8List oturum,
    required Uint8List duz,
  });

  /// Tür 3 (ön anahtar) mesajının üst bilgisini çözmeden okur: çağıran
  /// taraf hangi ön anahtar kayıtlarını [coz]'a vereceğini buradan bilir.
  /// Tür 3 değilse ya da ayrıştırılamazsa
  /// [SignalHatasiTuru.gecersizMesaj].
  ///
  /// libsignal'in Java API'si mesajdaki Kyber ön anahtar kimliğini
  /// açmaz; bu yüzden [coz]'a aday Kyber kayıtlarının hepsi verilir
  /// ([CozulmusMesaj.kullanilanKyberId] hangisinin kullanıldığını söyler).
  Future<OnAnahtarBilgisi> onAnahtarMesajiIncele(Uint8List sifreli);

  /// [tur] 2 ya da 3 olan [sifreli]'yi çözer.
  ///
  /// - Tür 2: [oturum] zorunludur; yoksa [SignalHatasiTuru.oturumYok].
  /// - Tür 3: [imzaliOnAnahtar] (mesajdaki imzalı ön anahtar kimliğiyle),
  ///   [onAnahtar] (mesajda tek kullanımlık ön anahtar kimliği varsa) ve
  ///   [kyberOnAnahtarlari] (aday Kyber kayıtlarının hepsi: tek
  ///   kullanımlıklar ve son çare) verilir. [oturum] varsa (karşı cihazla
  ///   önceki oturum) korunur.
  ///
  /// Daha önce çözülmüş mesaj [SignalHatasiTuru.eskiMesaj]; bozuk ya da
  /// doğrulanamayan mesaj [SignalHatasiTuru.gecersizMesaj]; mesajın
  /// istediği ön anahtar verilmemişse [SignalHatasiTuru.gecersizAnahtar].
  ///
  /// Son çare Kyber anahtarı tekrar saldırısı denetimi çağıran taraftadır:
  /// dönüşteki `(kullanilanKyberId, kullanilanImzaliId, tabanAnahtar)`
  /// üçlüsü daha önce görüldüyse sonuç atılır (yeni oturum yazılmaz).
  Future<CozulmusMesaj> coz({
    required Uint8List kimlik,
    required int kayitKimligi,
    required SignalAdresi adres,
    required int tur,
    required Uint8List sifreli,
    Uint8List? oturum,
    Uint8List? onAnahtar,
    Uint8List? imzaliOnAnahtar,
    List<Uint8List> kyberOnAnahtarlari = const [],
  });

  // ---------------------------------------------------------------------
  // Simetrik yapı taşları (libsignal'in kendi uygulamaları)
  // ---------------------------------------------------------------------

  /// HKDF-SHA256 (RFC 5869). [tuz] yoksa boş tuz.
  Future<Uint8List> hkdf({
    required Uint8List girdi,
    Uint8List? tuz,
    required Uint8List bilgi,
    required int uzunluk,
  });

  /// AES-256-GCM-SIV (RFC 8452). [anahtar] 32, [nonce] 12 bayt. Dönüş:
  /// şifreli metin ‖ 16 bayt etiket.
  Future<Uint8List> aesGcmSivSifrele({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List duz,
    required Uint8List aad,
  });

  /// [aesGcmSivSifrele]'nin tersi; doğrulanamazsa `null`.
  Future<Uint8List?> aesGcmSivCoz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreli,
    required Uint8List aad,
  });

  // ---------------------------------------------------------------------
  // Güvenlik kodu
  // ---------------------------------------------------------------------

  /// Signal'in sayısal güvenlik kodu (60 rakam, sürüm 2, 5200 yineleme).
  /// İki tarafta aynı sonucu verir. Tanımlayıcılar kullanıcıya özgü,
  /// sabit baytlardır (ör. kullanıcı UUID'sinin 16 baytı).
  Future<String> guvenlikKodu({
    required Uint8List yerelKimlikAcik,
    required Uint8List yerelTanimlayici,
    required Uint8List karsiKimlikAcik,
    required Uint8List karsiTanimlayici,
  });
}

/// Signal mesaj türleri (libsignal `CiphertextMessage`).
abstract final class SignalMesajTuru {
  /// SignalMessage (oturum kurulmuş).
  static const int signal = 2;

  /// PreKeySignalMessage (oturum kuran ilk mesajlar).
  static const int onAnahtar = 3;
}

/// Karşı cihazın Signal adresi.
final class SignalAdresi {
  const SignalAdresi({required this.ad, required this.cihazNo});

  /// Sunucudaki cihaz UUID'si.
  final String ad;

  /// Signal cihaz numarası (1–127).
  final int cihazNo;

  @override
  bool operator ==(Object other) =>
      other is SignalAdresi && other.ad == ad && other.cihazNo == cihazNo;

  @override
  int get hashCode => Object.hash(ad, cihazNo);
}

/// Kimlik anahtar çifti ve kayıt kimliği.
final class KimlikKaydi {
  const KimlikKaydi({
    required this.kayit,
    required this.acikAnahtar,
    required this.kayitKimligi,
  });

  /// Serileştirilmiş `IdentityKeyPair` (gizli anahtar içerir).
  final Uint8List kayit;

  /// Kimlik açık anahtarı (33 bayt, tür önekli).
  final Uint8List acikAnahtar;

  /// registrationId (1–16380).
  final int kayitKimligi;
}

/// Tek kullanımlık EC ön anahtar.
final class OnAnahtarKaydi {
  const OnAnahtarKaydi({
    required this.id,
    required this.kayit,
    required this.acikAnahtar,
  });

  final int id;

  /// Serileştirilmiş `PreKeyRecord` (gizli anahtar içerir).
  final Uint8List kayit;

  /// Açık anahtar (33 bayt).
  final Uint8List acikAnahtar;
}

/// İmzalı EC ön anahtar.
final class ImzaliOnAnahtarKaydi {
  const ImzaliOnAnahtarKaydi({
    required this.id,
    required this.kayit,
    required this.acikAnahtar,
    required this.imza,
    required this.zaman,
  });

  final int id;

  /// Serileştirilmiş `SignedPreKeyRecord` (gizli anahtar içerir).
  final Uint8List kayit;

  /// Açık anahtar (33 bayt).
  final Uint8List acikAnahtar;

  /// Kimlik anahtarıyla imza (64 bayt).
  final Uint8List imza;

  /// Üretim zamanı (Unix milisaniye).
  final int zaman;
}

/// İmzalı Kyber-1024 ön anahtar.
final class KyberOnAnahtarKaydi {
  const KyberOnAnahtarKaydi({
    required this.id,
    required this.kayit,
    required this.acikAnahtar,
    required this.imza,
  });

  final int id;

  /// Serileştirilmiş `KyberPreKeyRecord` (gizli anahtar içerir).
  final Uint8List kayit;

  /// Açık anahtar (1569 bayt, tür önekli).
  final Uint8List acikAnahtar;

  /// Kimlik anahtarıyla imza (64 bayt).
  final Uint8List imza;
}

/// Karşı cihazın sunucudan gelen ön anahtar paketi. Kyber zorunludur.
final class OnAnahtarPaketi {
  const OnAnahtarPaketi({
    required this.kayitKimligi,
    required this.cihazNo,
    this.onAnahtarId,
    this.onAnahtar,
    required this.imzaliOnAnahtarId,
    required this.imzaliOnAnahtar,
    required this.imzaliOnAnahtarImzasi,
    required this.kimlikAnahtari,
    required this.kyberOnAnahtarId,
    required this.kyberOnAnahtar,
    required this.kyberOnAnahtarImzasi,
  }) : assert(
         (onAnahtarId == null) == (onAnahtar == null),
         'onAnahtarId ve onAnahtar birlikte verilir',
       );

  final int kayitKimligi;
  final int cihazNo;

  /// Tek kullanımlık ön anahtar (sunucuda kalmadıysa yok).
  final int? onAnahtarId;
  final Uint8List? onAnahtar;

  final int imzaliOnAnahtarId;
  final Uint8List imzaliOnAnahtar;
  final Uint8List imzaliOnAnahtarImzasi;

  /// Karşı cihazın kimlik açık anahtarı (33 bayt).
  final Uint8List kimlikAnahtari;

  final int kyberOnAnahtarId;

  /// Kyber açık anahtarı (1569 bayt).
  final Uint8List kyberOnAnahtar;
  final Uint8List kyberOnAnahtarImzasi;
}

/// [SignalMotoru.sifrele] sonucu.
final class SifreliMesaj {
  const SifreliMesaj({
    required this.tur,
    required this.sifreli,
    required this.yeniOturum,
  });

  /// [SignalMesajTuru.signal] ya da [SignalMesajTuru.onAnahtar].
  final int tur;
  final Uint8List sifreli;

  /// Güvenli depoya yazılacak yeni oturum kaydı.
  final Uint8List yeniOturum;
}

/// Tür 3 mesajının çözülmeden okunan üst bilgisi.
final class OnAnahtarBilgisi {
  const OnAnahtarBilgisi({
    this.onAnahtarId,
    required this.imzaliOnAnahtarId,
    required this.gondericiKimligi,
    required this.kayitKimligi,
    required this.tabanAnahtar,
  });

  /// Kullanılan tek kullanımlık ön anahtar (yoksa `null`).
  final int? onAnahtarId;
  final int imzaliOnAnahtarId;

  /// Gönderen cihazın kimlik açık anahtarı (33 bayt; TOFU denetimi için).
  final Uint8List gondericiKimligi;

  /// Gönderen cihazın registrationId'si.
  final int kayitKimligi;

  /// Gönderenin bu oturuma özgü taban anahtarı (33 bayt).
  final Uint8List tabanAnahtar;
}

/// [SignalMotoru.coz] sonucu.
final class CozulmusMesaj {
  const CozulmusMesaj({
    required this.duz,
    required this.yeniOturum,
    this.kullanilanOnAnahtarId,
    this.kullanilanImzaliId,
    this.kullanilanKyberId,
    this.kyberTabanAnahtari,
    required this.karsiKimlik,
  });

  final Uint8List duz;

  /// Güvenli depoya yazılacak yeni oturum kaydı.
  final Uint8List yeniOturum;

  /// Tür 3: tüketilen tek kullanımlık EC ön anahtar (silinmeli).
  final int? kullanilanOnAnahtarId;

  /// Tür 3: Kyber ile birlikte kullanılan imzalı ön anahtar.
  final int? kullanilanImzaliId;

  /// Tür 3: kullanılan Kyber ön anahtar. Tek kullanımlıksa silinmeli; son
  /// çareyse `(kullanilanKyberId, kullanilanImzaliId, kyberTabanAnahtari)`
  /// üçlüsü tekrar saldırısı için kaydedilir.
  final int? kullanilanKyberId;

  /// Tür 3: libsignal'in `markKyberPreKeyUsed`'a verdiği taban anahtar
  /// (33 bayt).
  final Uint8List? kyberTabanAnahtari;

  /// Karşı cihazın kimlik açık anahtarı (33 bayt; oturumdan).
  final Uint8List karsiKimlik;
}

/// [SignalHatasi] türleri.
enum SignalHatasiTuru {
  /// Bozuk, doğrulanamayan ya da ayrıştırılamayan mesaj.
  gecersizMesaj,

  /// Daha önce çözülmüş mesaj (DuplicateMessageException).
  eskiMesaj,

  /// Oturum yok ya da kullanılamaz.
  oturumYok,

  /// Geçersiz anahtar, imza ya da eksik ön anahtar kaydı.
  gecersizAnahtar,

  /// Diğer her şey.
  bilinmeyen,
}

/// Motorun tek hata türü. Mesajda anahtar ya da içerik yoktur.
final class SignalHatasi implements Exception {
  const SignalHatasi(this.tur);

  final SignalHatasiTuru tur;

  @override
  String toString() => 'SignalHatasi(${tur.name})';
}
