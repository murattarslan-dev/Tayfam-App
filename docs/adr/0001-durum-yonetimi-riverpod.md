# ADR-0001: Durum yönetimi ve bağımlılık enjeksiyonu: Riverpod

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** Tayfam-Api ADR-0011 (güvenlik ilkesi), ADR-0014 (WebSocket)

## Bağlam

İstemcinin durum yönetimi; tayfa kapsamını, WebSocket akışını, modül
kaydını, token yenilemeyi ve çevrimdışı kuyruğu taşıyacak. Bu ihtiyaçlar:

- Kullanıcı birden çok tayfaya üyedir ve aralarında geçiş yapar. Etkinlik,
  duyuru, kanal gibi durumlar aktif tayfaya bağlıdır; tayfa değişince temiz
  sıfırlanmalıdır.
- Tek WebSocket bağlantısından gelen olaylar birçok ekranı besler.
- Tayfa ilgi alanlarına göre açılan modüller kendi durumlarını getirir.
- Token yenileme ve çevrimdışı kuyruk her yerden erişilen tekil servislerdir.
- Kod birbirinden habersiz alt oturumlarca yazılacak; tek tip kod incelemeyi
  belirler.

## Karar

Durum yönetimi ve bağımlılık enjeksiyonu için **Riverpod 3.x**
(`flutter_riverpod`) kullanılır. Ayrı bir DI kütüphanesi (get_it vb.)
eklenmez.

Tutarlılık için şu kurallar geçerlidir:

1. **Yalnızca güncel API.** Durum `Notifier` / `AsyncNotifier` (ve
   `StreamNotifier`) ile yazılır; salt değer ve servisler `Provider` ile
   verilir. `StateNotifier`, `ChangeNotifierProvider`, `StateProvider`,
   `FutureProvider`, `StreamProvider` ve Riverpod'un eski (legacy) API'leri
   kullanılmaz; tek seferlik veya akış durumu `AsyncNotifier` /
   `StreamNotifier` ile yazılır (CLAUDE.md ile aynı; 2026-11-10).
2. **Elle tanım, kod üretimi yok.** Provider'lar `riverpod_generator` ile
   değil elle tanımlanır. API istemcisi kararı `build_runner` getirirse bu
   madde o ADR'de yeniden değerlendirilir.
3. **Tayfa kapsamı `family` ile.** Tayfaya bağlı her durum `tayfaId`
   parametresiyle tanımlanır; aktif tayfa tek bir provider'dadır. Tayfa
   değişince eski tayfanın durumu `autoDispose` ile bırakılır.
4. **Kalıcılık gerektiren durum `keepAlive` ile açıkça işaretlenir**
   (oturum, WebSocket bağlantısı, çevrimdışı kuyruk). Varsayılan `autoDispose`.
5. **Widget'lar iş mantığı içermez.** Widget yalnızca `ref.watch` ile okur ve
   notifier metodlarını çağırır; API çağrısı, token işi veya veri dönüştürme
   notifier ya da servis katmanındadır.
6. **Gözlemci kişisel veri loglamaz.** `ProviderObserver` yalnızca provider
   adını ve hata türünü loglar; durum değeri, hata mesajı veya yığın
   içindeki veri loglanmaz (CLAUDE.md, kesin kural 3).
7. **Testte sahte bağımlılık override ile.** Testler `ProviderContainer` ve
   `overrides` ile kurulur; global durum veya tekil (singleton) nesne
   kullanılmaz.
8. **Oturum kapanınca durum sıfırlanır.** Çıkış, `session_ended` veya hesap
   silmede kullanıcıya bağlı tüm provider'lar geçersiz kılınır; önceki
   kullanıcının durumu bellekte kalmaz.

Dosya şablonu ve lint kuralları (ör. `riverpod_lint`), modül yapısı ADR'siyle
birlikte belirlenir.

## Gerekçe

- Tayfa kapsamı `family` + `autoDispose` ile doğal kuruluyor; Bloc'ta alt
  ağaçlarda bloc oluşturup kapatmayı elle yönetmek gerekirdi.
- WebSocket akışı `StreamNotifier`/`StreamProvider` ile doğrudan birden çok
  ekrana bağlanıyor.
- Durum ve DI tek sistemde; Bloc'ta get_it ile ikinci bir sistem gerekirdi.
- Testte bağımlılığı değiştirmek tek satır override.
- Riverpod'un zayıf yanı olan çok yazım biçimi yukarıdaki kurallarla ve
  lint ile kapatılıyor.

## Sonuçlar

- Bağımlılıklar: `flutter_riverpod` (ve lint için geliştirme bağımlılığı).
- Riverpod'da neyin neyi dinlediği örtüktür; incelemede provider
  bağımlılıkları özellikle kontrol edilir.
- Kural 8, oturum kapanışı ve hesap silme akışlarında testle sabitlenir.

## Değerlendirilen alternatifler

- **Bloc / Cubit (+ get_it):** Olay → durum akışı katı ve tek tip; ajan
  çıktısı tutarlı olurdu. Ama daha çok tekrar eden kod, ikinci bir DI sistemi
  ve tayfa kapsamı ile çoklu WebSocket aboneliği için ek yapı gerektiriyor.
- **Riverpod + kod üretimi:** Tanımlar daha kısa ve tutarlı; ama
  `build_runner` bağımlılığı ve üretim adımı getiriyor. API istemcisi
  kararına kadar ertelendi.
- **Provider / setState:** Bu ölçekte tayfa kapsamı ve servis yönetimi için
  yetersiz.

## Notlar

- **2026-11-10 (platform sahibi):** Kural 1, CLAUDE.md "Durum ve DI" ile
  aynı olacak biçimde daraltıldı: `FutureProvider` ve `StreamProvider` de
  kullanılmaz. Kural betiği (`tool/kurallar`, `riverpod-api`) bunu denetler.
