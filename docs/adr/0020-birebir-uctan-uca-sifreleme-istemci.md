# ADR-0020: Birebir mesajda uçtan uca şifreleme (istemci)

- **Durum:** Kabul edildi (platform sahibi, 2026-11-12, sohbette)
- **Tarih:** 2026-11-11
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0002](0002-modul-yapisi.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md), [ADR-0007](0007-websocket.md), [ADR-0010](0010-signal-kutuphanesi.md), [ADR-0011](0011-yalnizca-mobil.md), [ADR-0018](0018-faz1-kalan-moduller.md); Tayfam-Api ADR-0005, ADR-0018; sözleşme 8ef8245, güncelleme 62feb2e (Tayfam-Api #151)

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
  ayrı iş); istemcide taşıma kodu yoktur.
- **Güncelleme 2026-11-12 (Tayfam-Api #151, sözleşme 62feb2e):** düz
  sürüm tamamen kalktı. `POST /v1/direct-messages` yalnızca `envelopes`
  alır (`body` → `invalid-request`), WebSocket `dm.send`/`dm.sent` yok,
  `DirectMessage`'ta `body` yok ve `encryption` yalnızca `e2e`, düz
  mesajlar sunucuda silindi, `e2e-required` artık dönmüyor. İstemciden
  `dm.send` yolu, `encryption == server` dalları, "Uçtan uca şifreli
  değil" etiketi ve açıklaması ve `e2e-required` işleme dalı kaldırıldı
  (Tayfam-App #112).

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

- ~~`encryption == server` mesajlara "Uçtan uca şifreli değil" etiketi~~
  (2026-11-12: düz mesaj kalmadı, etiket ve açıklama kaldırıldı).
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
"Şifreli mesaj" yer tutucusuyla görünür; şifreli mesaj içeren konuşmada
yazma alanı yerine "yalnızca mobil uygulamada" boş durumu gösterilir.
iOS köprüsü yazılana kadar iOS da aynı davranır.

**Güncelleme 2026-11-12 (Tayfam-Api #151):** düz sürüm burada da yoktur.
Gönderim her zaman E2E yolundan gider; cihaz kaydı olmadığı için
`e2e-device-not-registered` ile "gönderilemedi" olur (genel hata yolu,
ayrı platform uyarısı ya da yeni metin yok; platform sahibi kararı
2026-11-12 17:54). Düz metne sessizce geri düşülmez.

### Temizlik

- Oturum kapanınca (çıkış, hesap silme, sunucunun kapatması, yenileme
  hatası) ve açılışta oturum yoksa bütün E2E kayıtları güvenli depodan
  silinir; kullanıcıya bağlı E2E provider'ları oturum durumunu izleyerek
  sıfırlanır.
- Çıkışta ayrıca `DELETE /v1/me/e2e/device` çağrılmaz: sunucu cihazı
  oturumla birlikte siler (`session.revoked`, Tayfam-Api ADR-0018 §1).

### Geçmiş arşivi, eşleştirme ve yenileme

Katman `lib/core/e2e/gecmis/` (anahtar, arşiv, yenileme, paylaşım) ve
`lib/core/e2e/esleme/` (QR) ile `features/cihazlar/` ekranlarıdır. Çekirdeğe
ince arayüzlerle bağlıdır (`gecmis/bagimliliklar.dart`; bağlantı
`gecmis/e2_baglantisi.dart`): cihaz durumu `e2eCihazProvider` + E2E
deposundaki kimlik + oturumun kullanıcı kimliği; güvenli depo
`E2eDeposu.ham*` (`e2e.gecmis.<sürüm>`); kendi cihazlarla Signal oturumu
`E2eOturumlari`; arşive yazılacak mesajlar `e2eMesajYayini` (`kaynak:
arsiv` hariç); arşivden çözülenler `birebirIcerikProvider`'a `kaynak:
arsiv` ile verilir; canlı olaylar `E2eEslemeCevaplandi`,
`E2eGecmisAnahtariPaylasildi`, `Baglandi`. Yönetici kabukta
(`CanliOlaylar`) başlar.

#### 1. Geçmiş anahtarı

- Sürüm başına `Random.secure()` ile 32 bayt. Güvenli depoda
  `e2e.gecmis.<sürüm>` kayıtları; bütün sürümler tutulur (eski arşiv
  kayıtları kendi sürümleriyle okunur). Çıkışta ve hesap silmede E2E
  deposunun tamamıyla silinir.
- **İlk cihaz** (`device.paired == false`, `other_paired_device == false`):
  anahtar önce aday sürümle (`history_key_version + 1`) depoya yazılır,
  sonra `POST /v1/me/e2e/history-key`. Sunucu kesin olarak reddederse aday
  silinir; cevap kaybolursa (bağlantı) aday korunur, çünkü sunucu kabul
  etmiş olabilir. Sunucu başka sürüm dönerse anahtar o sürüme taşınır.
  Önceki sürüm > 0 ise kullanıcıya bir kez "eski şifreli mesajlar bu
  cihazda okunamaz" bilgisi gösterilir. `e2e-paired-device-exists` → QR.

#### 2. Arşiv kaydı biçimi

```
k       = HKDF-SHA256(geçmişAnahtarı, tuz = ∅, bilgi = "tayfam/arsiv/v1", 32)
içerik  = 0x01 ‖ nonce(12, Random.secure) ‖ AES-256-GCM-SIV(k, nonce, düz, aad)
aad     = "tayfam/arsiv/v1" ‖ user_id(16) ‖ message_id(16) ‖ key_version(u16 BE)
düz     = dolgu160(UTF-8 JSON {v:1, gonderen, created_at, t:"metin", govde})
dolgu160: veri ‖ 0x80 ‖ 0x00…, uzunluk 160'ın katı (ISO/IEC 7816-4;
          zarfla aynı yardımcı: lib/core/e2e/mesaj/dolgu.dart)
```

- HKDF ve AES-256-GCM-SIV Signal motorunun (libsignal) yapı taşlarıdır;
  istemcide yalnızca biçim vardır (kesin kural 4). GCM-SIV nonce'un
  yanlış kullanımına dayanıklıdır; rastgele 96 bit nonce güvenlidir.
- AAD kaydı kullanıcıya, mesaja ve sürüme bağlar: sunucu bir kaydı başka
  mesajın, kullanıcının ya da sürümün yerine koyamaz.
- Türetilen anahtar yalnızca bellekte, sürüm başına bir kez türetilir.

#### 3. Arşive yazma ve okuma

- **Yazma:** E2'nin gönderilen/çözülen mesaj kancası (`CozulmusMesajAkisi`)
  dinlenir; yalnızca eşleştirilmiş cihaz yazar. Mesajlar bellekte sıraya
  girer, aynı olay döngüsü turunda gelenler birleşir ve en çok 50'lik
  gruplarla `POST /v1/me/e2e/archive` yapılır (sıra en çok 500; fazlasında
  en eskiler düşer). `e2e-history-key-stale` → paylaşımlar çekilir, durum
  tazelenir, grup yeni sürümle bir kez daha şifrelenir. `e2e-not-paired` →
  sıra boşaltılır. Bağlantı ve geçici sunucu hatası → grup sıranın başına
  döner; sonraki mesajda, yeniden bağlanmada ya da paylaşım olayında
  tekrar denenir. Diske hiçbir şey yazılmaz (ADR-0006).
- **Okuma:** konuşma açılınca `GET …/conversations/{id}/archive` (100'lük
  sayfa) bellekte çözülür ve `message_id` ile birebir konuşma notifier'ına
  verilir (`konusmaArsiviProvider(konusmaId)`, `autoDispose`). Anahtarı bu
  cihazda olmayan sürüm, başka konuşmanın ya da doğrulanamayan kayıt
  "okunamayan" sayılır; varsa konuşmada "Eski mesajların bu cihazda
  okunamıyor" satırı gösterilir. Eşleştirilmemiş cihaz istek atmaz.
  Konuşmanın eski bir sayfası açıldıkça, o sayfadaki şifreli mesajlar
  okunan arşiv sayfalarında görülene ya da arşiv bitene kadar arşivin
  sonraki sayfaları (opak `page_token`) istenir (bir seferde en çok 5) ve
  `message_id` ile birleştirilir; aynı kayıt iki kez sayılmaz, bir sayfada
  çözülemeyip başka sayfada çözülen kayıt "okunamayan" değildir.

#### 4. QR eşleştirme

- **QR içeriği:** `tayfam-esle:v1:<link_request_id>:<device_id>:<kimlik>:<kod>`
  - `link_request_id`, `device_id`: yeni cihazın eşleştirme isteği ve
    sunucudaki cihaz kimliği (UUID).
  - `kimlik`: yeni cihazın Signal kimlik açık anahtarı (33 bayt, 0x05
    önekli), dolgusuz base64url.
  - `kod`: `Random.secure()` ile 16 bayt doğrulama kodu, dolgusuz
    base64url. Sunucuya hiç gitmez.
  - Ayrıştırma katıdır: önek ve sürüm, tam dört alan, UUID biçimi,
    yalnızca base64url karakterleri, uzunluklar, en çok 256 karakter.
- **Eşleştirilmiş cihaz** (Profil → "Cihaz bağla"): QR okutulur →
  ayrıştırılır → kendi QR'ı reddedilir → `GET /v1/users/{kendi}/e2e/devices`
  listesindeki o cihazın kimlik anahtarı QR'dakiyle sabit zamanlı
  karşılaştırılır; aynı değilse hiçbir şey şifrelenmez. Signal oturumu
  da yalnızca bu kimlikle kurulur (`KendiCihazOturumu.sifrele(…,
  beklenenKimlik)`; ön anahtar paketindeki kimlik farklıysa reddedilir).
  Cevap düz metni `dolgu160(JSON {kod, link_request_id, anahtarlar:
  [{surum, anahtar}]})` kullanıcının kendi cihazları arasındaki Signal
  oturumuyla şifrelenir; paket `tür(1) ‖ Signal şifreli metni` (en çok
  16 KiB) `POST …/link-requests/{id}/answer` ile güncel sürüm numarasıyla
  gider. `e2e-history-key-stale` → paylaşım çekilip bir kez tekrar.
- **Yeni cihaz** (Profil → "Bu cihazı bağla"): `POST /v1/me/e2e/link-requests`
  → QR ve 10 dakikalık geri sayım; süre dolunca "Yeni kod al". Cevap
  WebSocket `e2e.link_answered` ile ya da 5 saniyelik yoklamayla
  (`GET …/{id}`) beklenir → Signal ile çözülür → `link_request_id` ve
  doğrulama kodu (sabit zamanlı) denetlenir → bütün sürümler depoya
  yazılır → `POST …/complete`. Kod tutmazsa hiçbir anahtar yazılmaz.
  `e2e-history-key-stale` → kendiliğinden yeni istek.
- **QR çizimi:** `qr` paketi + `CustomPainter`; tema ne olursa olsun açık
  zemin (açık temanın kart token'ı) üzerinde koyu modüller, 4 modül sessiz
  bölge, hata düzeltme M.

#### 5. Geçmiş anahtarının yenilenmesi

- `rotation_needed` olan eşleştirilmiş cihaz yeni 32 baytı aday sürümle
  (`history_key_version + 1`) depoya yazar ve `POST …/history-key/rotate`
  çağırır. Hangi cihazların eşleştirilmiş olduğu yalnızca sunucuda
  bilindiği için ilk deneme boş paylaşım kümesiyle yapılır;
  `e2e-devices-changed` cevabındaki `missing_device_ids` için kendi cihaz
  oturumuyla paylaşım (`dolgu160(JSON {anahtarlar: [{surum, anahtar}]})`)
  hazırlanır, `stale_device_ids` çıkarılır; en çok 3 tekrar.
- `e2e-history-key-stale` (başka cihaz önce yeniledi): aday silinir,
  paylaşımlar çekilir, vazgeçilir. Sonucu bilinmeyen istekte aday silinmez.
- **Paylaşım alma:** WebSocket `e2e.history_key_shared`, yeniden bağlanma
  ve açılışta `GET …/history-key-shares` → çöz → yalnızca paylaşımın
  sürümündeki anahtar depoya yazılır → `…/ack` (100'lük gruplar).
  Çözülemeyen ya da bozuk paylaşım (kalıcı hata) da onaylanır; ağ
  hatasında hiçbiri onaylanmaz. Anahtar depoya yazılmadan onaylanmaz.

#### 6. Tek cihaz uyarıları (araştırma §3.11)

- Çıkış onayında `paired && !other_paired_device` ise ek uyarı: eski
  birebir mesajlar kalıcı olarak okunamaz; önce başka cihaz bağlanabilir.
  Uyarı gerekmiyorsa çıkış önceki gibi sorusuz.
- İlk E2E açılışında bir kez bilgi kartı (gösterildiği E2E deposunda
  `e2e.bilgi.tek_cihaz` ile tutulur; çıkışta silindiği için yeni girişte
  yeniden gösterilir).
- Yeni girişte eski arşiv için "Eski mesajların bu cihazda okunamıyor"
  satırı; cihaz QR ile eşleşebiliyorsa "Bu cihazı diğer telefonunla bağla".

#### 7. Paketler ve izin

| Paket | Sürüm | Yayıncı / lisans | Bakım | İzin | Platform |
|---|---|---|---|---|---|
| `qr` | 4.0.1 (tam sabit) | kevmoo.com (doğrulanmış), BSD-3 | Etkin (4.0.1: 2026-11) | Yok; saf Dart | Hepsi |
| `camera` | ^0.12.1 | flutter.dev (doğrulanmış), BSD-3 | Etkin (Flutter ekibi) | Android `CAMERA` (eklentinin `RECORD_AUDIO` ve `WRITE_EXTERNAL_STORAGE`'ı manifestte kaldırılır; `camera.any` zorunlu değil); iOS `NSCameraUsageDescription` | Android (CameraX), iOS (AVFoundation) |
| `zxing2` | 0.2.4 (tam sabit) | xaha.dev (doğrulanmış), BSD-3; ZXing kaynağı Apache-2.0 | Orta: son sürüm 2025-06, depo etkin (2026-11) | Yok; saf Dart (ağ, yerel kod, telemetri yok) | Hepsi |

- **ZXing tabanlı tarayıcı (#115, platform sahibi 2026-11-12):** Google ML
  Kit (`mobile_scanner`) kaldırıldı; ML Kit Google'a anonim kullanım ölçümü
  gönderiyordu. `camera` arka kameranın YUV 4:2:0 görüntü akışını verir
  (ses kapalı); ilk düzlem (parlaklık) `zxing2`'nin `QRCodeReader`'ıyla
  (`HybridBinarizer`) ayrı isolate'ta çözülür. Yalnızca QR biçimi aranır;
  aynı anda tek kare çözülür, ötekiler atlanır; kareler yalnızca bellekte
  tutulur. İlk okunan QR'da akış durur; metnin ayrıştırılması ve
  doğrulanması eşleştirme servisindedir. Uygulama arka plana geçince
  kamera kapanır. Play Hizmetleri gerektirmez (Huawei'de de çalışır).
- **Seçim gerekçesi:** Adaylar `flutter_zxing` (ZXing-C++ FFI, `camera` +
  `image` + `image_picker` ile) ve `camera` + `zxing2` idi. Saf Dart seçildi:
  kameradan gelen (saldırganın kontrol edebileceği) görüntü bellek güvenli
  kodda çözülür; yerel kod derlenmez (NDK/CMake yok, derleme süresi ve
  ikili tedarik zinciri yok); APK'ya yalnızca Dart kodu eklenir. Ekrandaki
  QR'ı okumak için Java ZXing'in portu yeterli; QR'ın içeriği ASCII
  olduğundan 0.2.4'teki ≥0x80 bayt karakter seti hatası bizi etkilemez.
  `zxing2`'nin `PlanarYUVLuminanceSource`'u 0.2.4'te dışa açık olmadığından
  satır dolgulu parlaklık kaynağı uygulamada yazıldı
  (`lib/features/cihazlar/data/qr_cozucu.dart`).
- Tarayıcı `qrTarayiciProvider` (`QrTarayiciKurucu`) arkasındadır; ekran
  testleri sahte tarayıcıyla, tarayıcının kendisi sahte `CameraPlatform`
  ile (`camera_platform_interface`, yalnızca geliştirme bağımlılığı) sınanır.
- **Kamera izni** yalnızca "Cihaz bağla" ekranı açılınca istenir; görüntü
  saklanmaz ve gönderilmez. Reddedilirse açıklama; iOS'ta "Ayarları aç"
  (`app-settings:`), Android'de `url_launcher` uygulama ayarlarını
  açamadığı için yol metinle anlatılır ve "Tekrar tara" sunulur.
  `android.hardware.camera` zorunlu değil.
- CI APK izin denetimine `CAMERA` eklendi; `ACCESS_NETWORK_STATE` FCM
  (ADR-0019) için listede kalır. CI ayrıca APK'da ML Kit sınıfı ve modeli
  olmadığını denetler.

#### Sapmalar ve açık konular

- **Tayfam-Api ADR-0018 §5 sapması:** ADR "yeni cihazın bu iş için
  ürettiği açık anahtar" der; istemci cihazın Signal kimlik anahtarını ve
  kendi cihazlar arası Signal oturumunu (PQXDH) kullanır (araştırma §2
  seçenek A; platform sahibi 2026-11-11). Sunucu değişmez; ADR-0018
  metnine not düşülmeli. Kendi bağlamamıza ya da HPKE'li bir sürüme
  geçilirse (seçenek B) QR biçimi `v2` olur.
- ~~ML Kit (gömülü) Google'a anonim kullanım ölçümü gönderir.~~
  Kapandı: **karar (platform sahibi, 2026-11-12)** ZXing tabanlı
  tarayıcı; ML Kit kullanılmaz. Paket seçimi ve gerekçesi §7'de (#115).
- Yenilemede boş kümeyle ilk deneme bir fazla istek demektir; sözleşme
  eşleştirilmiş cihaz listesini vermediği için bilinçli seçim.

### Platform sahibi kararları

- 2026-11-11 18:4x: kapsam tam; güvenlik kodu TOFU + uyarı, elle
  karşılaştırma sonra; düz DM'ler sunucuda silinir, istemcide taşıma yok.
- 2026-11-11 19:00: Signal'in resmi Android paketi + Kotlin köprüsü;
  `libsignal_dart`, FRB ve Rust kullanılmaz; iOS sonra; E2E dahili test
  sürümüne girer.
- 2026-11-12: QR tarayıcıda ML Kit kullanılmaz (Google'a kullanım ölçümü
  gitmez); ZXing tabanlı tarayıcı (#115).
- 2026-11-12 17:54: düz birebir yolu kaldırılırken E2E'nin olmadığı
  platformlar (web geliştirme derlemesi, iOS) için yeni bir platform
  uyarısı ya da çeviri anahtarı eklenmez; mevcut davranış en sade haliyle
  kalır ve gönderim genel hata yolunu kullanır (#112).
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
