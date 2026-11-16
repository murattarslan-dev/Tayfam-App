# Anlık (bireysel) etkinlik

Tayfaya bağlı olmadan arkadaşlarla tek seferlik etkinlik (issue #198;
Notion "Faz 2 (v2) — Medya ve Sosyal" §5; Tayfam-Api ADR-0032; istemci
ADR-0026). Sunucu arka planda gizli, tek etkinlikli bir tayfa açar
(`Tayfa.kind = instant`): organizatör yönetici, davetliler üye. Etkinlik
sayfası, katılım, varış bildirimi, sohbet ve albüm mevcut ekranlarla
çalışır; bu bölüm yalnızca yeni ve değişen yüzeyleri tanımlar.

Bu bölümde HTML çizim yoktur: ekranların hepsi mevcut bölümlerin
iskeletini ve bileşenlerini kullanır. Her ekran için dayandığı bölüm
yazılmıştır; ölçü, renk ve metin dili oradan gelir. Aşağıdaki çizimler
yalnızca yerleşimi gösterir.

## Kaynak ve kısıtlar

- **İskelet:** etkinlik sihirbazı ([12](../12-etkinlik-sihirbazi/README.md))
  ve tayfa kurma sihirbazı ([13](../13-tayfa-kurma-sihirbazi/README.md)):
  `SihirbazUstCubugu` (X, başlık, "Adım n / N", parçalı ilerleme),
  `SihirbazAltCubugu` (sabit Geri + İleri), `AdimBasligi`,
  `IkiSutunluIzgara`, `SihirbazBilgiKutusu`.
- **Başarı ekranı:** "Tayfa kuruldu" ([13](../13-tayfa-kurma-sihirbazi/README.md),
  Tayfa-Kur-Hazir): mor zemin, logo, birincil "Davet linkini paylaş",
  beyaz çerçeveli ikincil eylem.
- **Liste satırları:** `ListeKarti` + `MenuSatiri.kartta` +
  `KullaniciAvatari` (arkadaş listesi, [07](../07-profil/README.md));
  boş/yükleniyor/hata durumları [23](../23-hata-ve-baglanti-durumlari/README.md).
- **Etiket:** `Etiket` (tint-brand zemin, brand metin, 13 px/700).
- Renk, boşluk, yarıçap ve süre yalnızca `TayfamColors` / `TayfamSpacing` /
  `TayfamRadii` / `TayfamMotion` / `TayfamSizes` token'larıyla; metinler
  `app_tr.arb`'de.
- İkonlar Material Icons'tır (uygulamanın geri kalanı gibi). Skill'in
  Phosphor önerisi uygulanmadı (ADR-0004).

## Akış

```
Tayfa paneli "Anlık etkinlik aç"   ─┐
Karşılama "Anlık etkinlik aç"       ├─▶ /anlik-etkinlik ─▶ sihirbaz (6 adım)
Boşum rozeti "Bir şey yapalım" ─────┘     ?gun=YYYY-MM-DD&davetli=<id>
                                                 │ POST /v1/instant-events
                                                 ▼
                                   "Etkinlik açıldı" (mor) ─▶ etkinlik detayı
                                                              /t/<id>/etkinlikler/<eid>
Tayfa ana sayfası (anlık tayfa): "Anlık etkinlik" kartı
   ├─ Arkadaş davet et     (alttan sayfa, POST /v1/tayfas/{id}/invitations)
   ├─ Davet linkini paylaş (mevcut davet linki akışı)
   └─ Bu ekiple tayfa kur  ─▶ /tayfa-donustur/<id> (3 adım) ─▶ ana sayfa
                              POST /v1/tayfas/{id}/conversion
```

## 1. Giriş noktaları

- **Tayfa değiştirme paneli** ([05](../05-tayfa-ana-sayfa/README.md),
  Ana-Tayfa-Degistir): "Tayfa kodum var" ve "Tayfa kur" satırlarının
  altında üçüncü sade `MenuSatiri`: ikon `bolt_outlined`, "Anlık etkinlik
  aç", açıklama "Tayfasız, tek seferlik; arkadaşlarınla".
- **Karşılama** ([16](../16-karsilama-ve-davet/README.md)): iki büyük
  seçim kartı aynen kalır. Altındaki davet linki ipucundan önce sade bir
  `MenuSatiri` (aynı metin ve ikon). Tayfası olmayan kullanıcı da
  arkadaşlarıyla buluşabilsin diye.
- **Boşum rozeti** (Tayfam-App #203'ün alttan sayfası, `docs/tasarim/26`):
  gün listesinin altında, "Mesaj gönder"in üstünde "Bir şey yapalım"
  birincil düğmesi (ilk boş gün); bir güne dokunmak da o gün için açar. Sihirbaz o gün seçili (başlangıç o gün 19:00, geçmişse
  bir saat sonrası; bitiş +2 saat) ve o arkadaş davetli seçili açılır.
  Adresteki gün ve kimlik girdi kabul edilir: gün bugünden önce ya da 30
  günden ileri ise, kimlik UUID değilse yok sayılır.

## 2. Sihirbaz (`/anlik-etkinlik`)

Etkinlik sihirbazının kendisidir; başlık **"Anlık etkinlik"**, 6 adım:

| # | Adım | Fark |
| --- | --- | --- |
| 1 | Ne tür bir etkinlik? | "Tayfanın ilgi alanları" grubu yok; yedi tür tek ızgarada |
| 2 | Ne zaman, ne yapıyoruz? | Kapak fotoğrafı bölümü yok (sözleşme: `cover_upload_id` verilemez; kapak sonra düzenlemeyle) |
| 3 | Nerede? | Aynı |
| 4 | Son ayrıntılar | Tekrar satırı yok (sözleşme: `recurrence` verilemez) |
| 5 | **Kimleri çağıralım?** (yeni) | Arkadaş seçimi |
| 6 | Her şey doğru mu? | "Davetliler" satırı + bilgi kutusu |

### 5 · Kimleri çağıralım?

```
┌───────────────────────────────────────┐
│ X  Anlık etkinlik         Adım 5 / 6  │
│ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ ░░░ │
│ Kimleri çağıralım?                     │
│ En fazla 10 arkadaşını doğrudan davet │
│ et. Açtıktan sonra davet linkini de   │
│ paylaşabilirsin.                       │
│ [ 🔍 Arkadaşlarında ara             ] │
│ 2 / 10 kişi seçildi                    │
│ ┌───────────────────────────────────┐ │
│ │ (A) Ayşe K.                   [✓] │ │
│ │ (M) Mert Y.                   [✓] │ │
│ │ (S) Selin T.                  [ ] │ │
│ └───────────────────────────────────┘ │
│          Daha fazla göster             │
├───────────────────────────────────────┤
│  [ Geri ]                [ İleri ]    │
└───────────────────────────────────────┘
```

- Satır: `MenuSatiri.kartta`, solda `KullaniciAvatari`, sağda onay kutusu.
  Bütün satır dokunulabilir (≥ 48 dp); ekran okuyucu satırı onay kutusu
  olarak, seçili durumuyla okur.
- Sayaç ("n / 10 kişi seçildi") ekran okuyucuya canlı bölge olarak okunur;
  tek başına sayı okunmaz.
- 10 kişi seçilince seçili olmayan satırlar devre dışı kalır ve sayacın
  altında "En fazla 10 kişi davet edebilirsin. Fazlası için davet linkini
  paylaş." yazar.
- Arama yalnızca yüklü arkadaşlarda, `turkceKucukHarf` ile süzer; istek
  atmaz. Sonuç yoksa "Bu adla arkadaş yok".
- Seçilenler aramadan bağımsız korunur; Geri/İleri'de girilenler kalır.
- Adım geçilebilir (kimse seçilmeden link yoluyla çağrılabilir).
- **Boş:** "Henüz arkadaşın yok. Etkinliği açıp davet linkini
  paylaşabilirsin." + çerçeveli "Arkadaş ekle" (mevcut alttan sayfa).
- **Yükleniyor:** `TayfamYukleniyor` (1 sn'den kısa beklemede görünmez).
- **Hata:** `HataSatiri` + "Tekrar dene"; adım yine geçilebilir.

### 6 · Her şey doğru mu?

Mevcut özet kartı. Tekrar satırı yerine **"Davetliler"** satırı: "Ayşe K.,
Mert Y." / "Ayşe K., Mert Y. ve 3 kişi" / "Kimse seçilmedi"; "Değiştir" 5.
adıma götürür. Kartın altında `SihirbazBilgiKutusu` (ikon `info_outline`):
"Etkinlik bittikten 7 gün sonra arşivlenir. Davet linkiyle gelenler
katılım isteği gönderir; sen onaylarsın."

Gönder düğmesi "Etkinliği aç".

- `instant-event-limit` → önizlemede tint-nar kutu (Tayfa-Kur-Limit gibi):
  **"Şu an daha fazla anlık etkinlik açamazsın."** + "Girdiklerin duruyor."
  Hangi sınırın (3 açık / günde 5) aşıldığı sunucudan gelmez; metin sayı
  söylemez.
- `not-friends` (seçilen biri artık arkadaş değil) → mevcut hata metni;
  5. adımdaki liste yenilenir.
- `rate-limited` → bekleme metni. Diğer hatalar ortak hata satırı.

## 3. "Etkinlik açıldı"

Tayfa-Kur-Hazir'in aynısı; mor zemin, logo, etkinlik türü çipi (avatar
yerine), başlık **"`<başlık>` hazır!"**, açıklama:

- davetli varsa "`n` arkadaşına davet gitti. Kabul edenler etkinliğe
  katılır."
- yoksa "Davet linkini paylaş; gelenler katılım isteği gönderir."

Birincil (mango) **"Davet linkini paylaş"** (mevcut davet linki akışı;
varsayılan 7 gün / 10 kişi, link bir kez gösterilir). İkincil beyaz
çerçeveli **"Etkinliğe git"**. Sistem geri tuşu etkinliğe gider; sihirbaza
dönülmez. Ekran yalnızca oluşturma yanıtıyla çizilir. Tayfa kodu
gösterilmez (anlık tayfada kodla katılım yok).

## 4. Tayfa paneli: ayrı işaret

Etkin tayfalar iki grupta: önce kalıcı tayfalar, sonra `BolumEtiketi`
**"Anlık etkinlikler"** altında anlık olanlar. Anlık satırında avatar
yerine aynı boyutta etkinlik ikonu kutusu (`bolt`, tint-brand zemin,
`secimKoseleri`) ve açıklamada "Anlık etkinlik · `n` kişi". Panelin en
altında, "Tayfa kur"un altında "Anlık etkinlik aç" satırı. Bekleyen katılım isteği anlık tayfaya aitse
"Onay bekliyor" etiketinin yanında aynı "Anlık" etiketi bulunur. Renk tek
başına bilgi taşımaz; grup başlığı ve metin vardır.

## 5. Anlık tayfanın ana sayfası

Mor üst bölüm aynıdır (ad = etkinlik başlığı); arşiv/askı durum şeridi
mevcut kuralla gösterilir. Anlık olduğu, aşağıdaki kartın başlığında
yazar. Farklar:

- "Tayfanı birlikte kuralım" kurulum kartı ve "7 günde 3 üye" kural metni
  gösterilmez (ADR-0032 §6: bu kurallar anlık tayfaya uygulanmaz).
- "Oluştur" düğmesi gösterilmez (tek etkinlik; duyuru/anket/soru modülleri
  kapalı). Kişi+ davet ikonu yalnızca yöneticide (organizatör).
- Mor bölüme taşan kartlarda "Sıradaki" etkinlik kartının üstünde
  **"Anlık etkinlik" kartı** (`TayfamKart`):
  - "Etkinlik bittikten 7 gün sonra arşivlenir." (her üyeye)
  - Yalnızca yöneticiye (organizatör; arayüz sadeleştirmesi, karar
    sunucuda): `MenuSatiri` listesi — "Arkadaş davet et"
    (`person_add_alt_outlined`), "Davet linkini paylaş" (`link`),
    "Bu ekiple tayfa kur" (`groups_outlined`, açıklama "Bu ekip kalıcı
    tayfa olsun; üyeler ve etkinlik kalır").
  - Arşivlenmiş/askıdaki tayfada eylemler gösterilmez.

### Arkadaş davet et (alttan sayfa)

`AltSayfaIcerigi`, başlık "Arkadaşlarını davet et"; 5. adımdaki seçim
listesinin aynısı, altta birincil "Davet et (`n`)". Her kişi için
`POST /v1/tayfas/{id}/invitations`; sonuç kısa bildirimle ("`n` kişiye
davet gitti"). Bir kısmı başarısızsa başarılı olanlar sayılır ve ilk hata
metni gösterilir.

## 6. "Bu ekiple tayfa kur" (`/tayfa-donustur/<id>`)

Tayfa kurma sihirbazının kısa hali: aynı üç adım (Ad · İlgi alanları ·
Katılım ve açıklama), başlık **"Bu ekiple tayfa kur"**. Farklar:

- 1. adımın üstünde `SihirbazBilgiKutusu`: "Üyeler, etkinlik ve sohbet
  olduğu gibi kalır."
- Ad alanı boş başlar (etkinlik başlığı 1–120, tayfa adı 3–50).
- Gönder "Tayfayı kur". "Tayfa kuruldu" ekranı yok: başarıda tayfanın ana
  sayfası açılır ve "Tayfan kuruldu" bildirimi gösterilir (üyeler zaten
  var; kurulum kartı ve 7 günde 3 üye kuralı dönüşüm anından işler).
- `tayfa-create-limit` / `rate-limited` → Tayfa-Kur-Limit kutusu.
- Kapat ve ilk adımda geri, tayfanın ana sayfasına döner.

## 7. Davet linkiyle gelen

Davet ekranı ([16](../16-karsilama-ve-davet/README.md)) aynıdır. Anlık
tayfada katılım her zaman isteğe düşer; "İsteğin gönderildi" sonucu
"Organizatör onaylayınca etkinliği görürsün." der (tür, katılımdan sonra
yenilenen tayfa listesinden okunur; bilinmiyorsa mevcut metin).

## Durumlar, tema ve yazı ölçeği

- Bütün yeni yüzeyler açık ve koyu temada token'larla çizilir; mor yüzeyli
  ekran iki temada aynıdır (ADR-0004 §2a).
- 2× yazı ölçeğinde: sayaç ve uyarı satırları kayar, çok satırlı kalır;
  satırlardaki onay kutusu metnin altına inmez, ad iki satıra kırılır;
  "Etkinlik açıldı" ekranı kaydırılabilir, eylemler altta sabit.
- Hareket: yalnızca mevcut sihirbaz geçişleri; yeni animasyon yok.
- Konum: anlık etkinlikte de cihaz konumu yalnızca varış bildiriminde.

## Gizlilik

- Davetli kimlikleri yalnızca istek gövdesinde ve sihirbazın belleğinde;
  log'a, diske ya da analitiğe yazılmaz. Boşum'dan gelen arkadaş kimliği
  adreste durur (uygulama içi adres; tam URL loglanmaz, kesin kural 3).
- Davet token'ı mevcut akıştaki gibi yalnızca bir kez gösterilir.
- Anlık tayfanın içeriği üye olmayana görünmez; bekleyen istekte yalnızca
  ad görünür (mevcut kural).

## Kararlar ve notlar

Platform sahibi (2026-11-15): tayfaya bağlı olmadan tek seferlik etkinlik;
arkadaşlara doğrudan davet + davet linki (link sahibi istek gönderir,
organizatör onaylar); en fazla 3 açık ve günde 5 anlık etkinlik (sunucu
söyler); bitince 7 gün sonra arşiv; organizatörde "Bu ekiple tayfa kur";
panelde ayrı işaret; moderatör yok; Boşum rozetinde "Bir şey yapalım".

Platform sahibi (2026-11-16, mimari oturumu aracılığıyla; ADR-0026 Notlar):
karşılamadaki ikinci giriş, "Bir şey yapalım"ın varsayılan saati (19:00, 2
saat) ve dönüşümde "Tayfa kuruldu" ekranının atlanması onaylandı.
