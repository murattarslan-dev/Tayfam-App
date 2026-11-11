# ADR-0020: Birebir mesajda uçtan uca şifreleme (istemci)

- **Durum:** Önerildi
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0002](0002-modul-yapisi.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0007](0007-websocket.md), [ADR-0010](0010-signal-kutuphanesi.md), [ADR-0011](0011-yalnizca-mobil.md), [ADR-0018](0018-faz1-kalan-moduller.md); Tayfam-Api ADR-0005, ADR-0018; sözleşme 8ef8245

## Bağlam

Birebir mesajlar düz sürümle çalışıyor (ADR-0018 §9). Sunucu tarafı
uçtan uca şifrelemeyi tamamladı (Tayfam-Api ADR-0018: cihaz = oturum,
X3DH + PQXDH ön anahtarları, zarflar, geçmiş arşivi, QR eşleştirme,
anahtar yenileme). Platform sahibi 2026-11-11'de şunlara karar verdi:

- Kapsam tam: cihaz kaydı, gönderim/alım, arşiv, QR eşleştirme, geçmiş
  anahtarı yenileme, uyarılar. E2E dahili test sürümüne girer.
- Signal için Signal'in resmi Android paketi `org.signal:libsignal-android`
  ve ince bir Kotlin köprüsü (ADR-0010 güncellemesi); iOS sonra.
- Güvenlik kodu: TOFU + "güvenlik kodu değişti" uyarısı; elle
  karşılaştırma ekranı sonra.
- Düz sürümde yazılmış birebir mesajlar sunucuda silinir (Tayfam-Api'de
  ayrı iş); istemci düz mesajlara yalnızca "uçtan uca şifreli değil"
  etiketi gösterir, taşıma kodu yoktur.

Bu ADR istemcinin nasıl yaptığını karara bağlar.

## Karar

### Katmanlar

- `lib/core/e2e/signal/`: Signal motoru arayüzü (`SignalMotoru`) ve
  platform kanalı uygulaması. Motor **durumsuzdur**: kalıcı durum Dart'ta,
  her çağrı gereken kayıtları alır, değişenleri döner.
- `lib/core/e2e/depo/`: güvenli depo.
- `lib/core/e2e/cihaz/`: cihaz kaydı ve ön anahtar bakımı.
- `lib/core/e2e/mesaj/`: oturumlar, gönderim, alım, uyarılar ve
  bellekteki içerik.
- `features/birebir/` E2E'yi `core/e2e`'nin kapısından (`E2eBirebir`)
  kullanır; özellik kriptoya ya da depoya doğrudan dokunmaz.

### Depo

- `flutter_secure_storage`, token deposundan **ayrı ad alanı**: Android'de
  `storageNamespace: tayfam_e2e` (paketin 11. sürümünde
  `sharedPreferencesName` kaldırıldı; `storageNamespace` veri, yapılandırma
  ve Keystore anahtarını birlikte ayırır), iOS'ta `accountName: tayfam_e2e`
  ve `first_unlock_this_device`. Büyük E2E verisi token okumasını
  yavaşlatmaz; temizlik yalnızca bu ad alanını siler.
- Anahtar düzeni (`e2e.` önekli): `kimlik`, `cihaz`, `sayac`,
  `imzali.<id>`, `kyber_son_care.<id>`, `onk.<id>`, `kyber.<id>`,
  `kyber_kullanilan.<id>`, `oturum.<cihazId>`, `kimlik_karsi.<cihazId>`,
  `gorulen`, `anahtar_olayi.<kullanıcıId>`, `karsi_cihazlar.<kullanıcıId>`;
  `gecmis.<sürüm>` geçmiş arşivine ayrılır.
- Açılışta bütün kayıtlar bir kez okunur ve bellekte tutulur; yazmalar
  önce güvenli depoya, başarılıysa belleğe gider.
- **Hiçbir okuma ya da yazma istisna sızdırmaz.** Depo çözülemiyorsa
  (`readAll` hata verirse) bütün E2E kayıtları silinir ve cihaz sıfırdan
  kaydolur (`guvenliOku` deseni). Yazma başarısızsa iş tamamlanmış sayılmaz.
- **Kalıcılık sırası (ADR-0010):** durum depoya yazılmadan mesaj
  gönderilmiş ya da alınmış sayılmaz. Depo atomik değildir; sıra
  oturum → tek kullanımlık ön anahtarın silinmesi → "görüldü" → onaydır.

### Cihaz

- Oturum açılınca ve kayıt tamamlanmışsa (yalnızca mobilde)
  `GET /v1/me/e2e/device`.
  - `e2e-device-not-registered`: depo temizlenir, kimlik, imzalı EC ön
    anahtar, son çare Kyber ön anahtarı, **100 EC + 30 Kyber** tek
    kullanımlık ön anahtar üretilir, **önce depoya** yazılır, sonra
    `POST /v1/me/e2e/device`.
  - Sunucu kayıtlı diyor ama depoda kimlik yoksa ya da açık anahtar
    farklıysa (uygulama yeniden kuruldu, depo çözülemedi): kayıt
    `DELETE` ile silinir ve sıfırdan kaydolunur.
  - `e2e-device-limit` (hesap başına 5): birebir ekranlarında açıklama ve
    "Oturumları aç" (Profil → Oturumlar) ile "Tekrar dene".
- Ön anahtar bakımı (açılışta ve WebSocket `e2e.prekeys_low`'da): bir
  türden 10'dan az kaldıysa ya da sunucu `low` diyorsa 100 EC / 30 Kyber'e
  tamamlanır. İmzalı EC ve son çare Kyber **7 günde bir** yenilenir;
  eskileri gecikmiş ilk mesajlar için **30 gün** tutulup silinir. Son çare
  Kyber anahtarının tekrar saldırısı denetimi için `(imzalıId,
  tabanAnahtar)` çiftleri anahtar silinene kadar tutulur.
- Cihaz durumu (`paired`, `other_paired_device`, `history_key_version`,
  `rotation_needed`) bir provider'da yayınlanır; geçmiş arşivi ve
  eşleştirme bunu dinler.

### Gönderim ve alım

- **Signal adresi:** `(sunucudaki cihaz kimliği, cihaz numarası)`. Güven
  ve oturum cihaz kimliğine bağlıdır; numara yeniden kullanılırsa eski
  oturum geçersiz sayılır. libsignal iki tarafın adresini mesaja bağlar;
  yerel adres bu cihazın sunucu kimliğidir.
- **Adres başına sıra:** aynı karşı cihaz için motor çağrıları ve
  ardından gelen depo yazmaları küçük bir async kilitle sıraya sokulur
  (ek paket yok).
- **Gönderim** (yalnızca REST; WebSocket'ten zarflı gönderim yoktur):
  1. Alıcının ve kendi diğer cihazlarımızın listesi (bellek önbelleği).
  2. Oturumu olmayan cihazlar için ön anahtar paketi; paketteki kimlik
     depodaki güvenilen kimlikten farklıysa eski oturum silinir ve
     "güvenlik kodu değişti" satırı düşer (TOFU).
  3. Her cihaz için şifrele, oturumu yaz.
  4. `POST /v1/direct-messages` (`envelopes`).
  5. `e2e-devices-changed`: iki liste sunucudan tazelenir; listede
     olmayan ya da kaydı değişen cihazların oturumu ve güvenilen kimliği
     silinir, eksikler için paket çekilir; **aynı `client_request_id`**
     ile en çok 3 kez yeniden denenir. Problem gövdesindeki
     `missing/stale_device_ids` kullanılmaz (ApiClient problem gövdesinden
     yalnızca `type` okur); tazelenen liste aynı bilgiyi verir.
  6. Alıcının cihazı yoksa `e2e-recipient-unavailable`; düz metne geri
     düşülmez.
- Düz metin `{v:1, t:"metin", govde}` UTF-8, Signal gibi **160 bayt**
  bloklara dolgulu (ISO/IEC 7816-4). Çevrimdışı kuyruk düz metni yalnızca
  bellekte tutar; şifreleme gönderim anında yapılır.
- **Alım:** WebSocket `dm.envelope` ve açılışta / her yeniden bağlanmada
  `GET /v1/me/e2e/envelopes` (onaydan sonra baştan). Zarf kimliğiyle
  tekrar ayıklanır (bellek kümesi + depoda son 500 kimlik). Gönderen
  cihazın kilidi altında çözülür, durum yazılır, **sonra** onaylanır
  (`dm.envelope_ack`; bağlantı yoksa ya da cevap gelmezse REST).
  Depoya yazılamazsa onaylanmaz, sunucu yeniden teslim eder.
- Çözülemeyen zarf düşürülür ve onaylanır, oturum sıfırlanmaz;
  konuşmada "Bir mesaj çözülemedi" satırı görünür.
- Çözülmüş içerik yalnızca bellektedir (ADR-0006); oturum değişince
  sıfırlanır. Gönderilen ve çözülen her mesaj bir yayın akışına düşer
  (geçmiş arşivi buna abone olur).

### Uyarılar ve etiketler

- `encryption == server` mesajlara balon altında "Uçtan uca şifreli
  değil" etiketi ve konuşma başında açıklama.
- Konuşma açılınca karşı tarafın anahtar olayları (son görülen olaydan
  sonrası) ve cihaz listesinin son bilinen kümeyle farkı denetlenir; yeni
  olay ya da fark "Güvenlik kodu değişti" satırı olur. Kişiye ilk bakışta
  yalnızca taban kaydedilir (TOFU).
- Kendi hesabına yeni cihaz eklenince (cihaz hazırlandığında kendi anahtar
  olaylarına bakılır) konuşmalarda "Hesabına yeni bir cihaz eklendi" bilgi
  satırı.
- İçeriği bu cihazda çözülmemiş şifreli mesaj "Bu şifreli mesaj bu
  cihazda okunamıyor" yer tutucusuyla görünür.
- Push bildirimi içeriksizdir; ek iş yoktur.

### Web geliştirme derlemesi

E2E yoktur (ADR-0011): cihaz kaydedilmez, zarf alınmaz. Şifreli mesajlar
"Şifreli mesaj" yer tutucusuyla görünür; şifreli mesaj içeren ya da
`e2e-required` alan konuşmada yazma alanı yerine "yalnızca mobil
uygulamada" boş durumu gösterilir. Düz sürüm (WebSocket `dm.send`, REST)
yalnızca burada kalır.

### Temizlik

- Oturum kapanınca (çıkış, hesap silme, sunucunun kapatması, yenileme
  hatası) ve açılışta oturum yoksa bütün E2E kayıtları güvenli depodan
  silinir; kullanıcıya bağlı E2E provider'ları oturum durumunu izleyerek
  sıfırlanır.
- Çıkışta ayrıca `DELETE /v1/me/e2e/device` çağrılmaz: sunucu cihazı
  oturumla birlikte siler (`session.revoked`, Tayfam-Api ADR-0018 §1).

### Geçmiş arşivi, eşleştirme ve yenileme

### Platform sahibi kararları

- 2026-11-11 18:4x: kapsam tam; güvenlik kodu TOFU + uyarı, elle
  karşılaştırma sonra; düz DM'ler sunucuda silinir, istemcide taşıma yok.
- 2026-11-11 19:00: Signal'in resmi Android paketi + Kotlin köprüsü;
  `libsignal_dart`, FRB ve Rust kullanılmaz; iOS sonra; E2E dahili test
  sürümüne girer.
- Açık: tek telefonlu kullanıcıya çıkışta "geçmiş okunamaz olur" uyarısı
  ve kurtarma kodu (Tayfam-Api ADR-0005, sonra).

## Gerekçe

- Motoru durumsuz tutmak, kalıcılık sırasını ve temizliği tek yerde
  (Dart) toplar; köprü hiçbir şey saklamaz ve loglamaz.
- Anahtarları önce depoya yazıp sonra sunucuya bildirmek, sunucuda
  bilinip cihazda bulunmayan anahtar bırakmaz.
- Tazelenen cihaz listesiyle kendi kendini onaran gönderim, sunucunun bir
  cihazı sessizce dışarıda bırakmasını değil, istemcinin fark etmesini
  sağlar.
- Ayrı ad alanı, çıkışta tek çağrıyla temizliği ve token deposunun
  küçük kalmasını sağlar.

## Sonuçlar

- `SessionStore` oturumun kullanıcı kimliğini (`Session.user_id`) de
  saklar; eski kayıtta yoksa ilk yenilemede gelir.
- WebSocket istemcisi `dm.envelope`, `e2e.prekeys_low`,
  `e2e.link_answered`, `e2e.history_key_shared` olaylarını ve
  `dm.envelope_ack` gönderimini tanır.
- Yeni paket yoktur.

## Değerlendirilen alternatifler

- **Zarflı gönderimi WebSocket'ten yapmak:** çerçeve sınırı (64 KiB) ve
  sunucu kararı (Tayfam-Api ADR-0018 §3) nedeniyle yok.
- **Çözülemeyen zarfta oturumu sıfırlamak:** saldırgana oturumu
  düşürtme imkânı verir; libsignal önerisine uygun olarak yapılmaz.
- **Problem gövdesindeki cihaz listelerini okumak:** `ApiClient`'ı
  genişletmek gerekirdi; listeleri tazelemek aynı sonucu verir.
