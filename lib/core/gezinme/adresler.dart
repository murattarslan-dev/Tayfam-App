/// Uygulama içi adresler (ADR-0003).
///
/// Yollar `core/`'dadır çünkü özellikler birbirine ve kabuğa bu adreslerle
/// gider; `shell/`'i import edemezler (ADR-0002). Yönlendirici
/// (`shell/yonlendirici.dart`) aynı sabitleri kullanır.
///
/// `/davet` ve `/r/<kod>` derin link adresleri derin link paketine aittir;
/// burada tanımlanmaz.
abstract final class Adresler {
  /// Kök adres; yönlendirme onu karşılamaya ya da aktif tayfaya çevirir.
  static const kok = '/';

  /// Tayfası olmayan kullanıcının Tayfa sekmesindeki karşılama ekranı.
  static const karsilama = '/karsilama';

  /// Tayfaya bağlı adreslerin ilk parçası (`/t/<tayfaId>/…`).
  static const tayfaOneki = 't';

  /// Tayfa rotasındaki kimlik parametresinin adı (`/t/:tayfaId`).
  /// Modül rotaları tayfa kimliğini bu adla okur.
  static const tayfaIdParametresi = 'tayfaId';

  /// Tayfa sekmesinin kökü: aktif tayfanın ana sayfası.
  static String tayfa(String tayfaId) => '/$tayfaOneki/$tayfaId';

  /// Duyuru modülünün `/t/<tayfaId>/` altındaki yolu (ADR-0015 §2).
  static const duyurularYolu = 'duyurular';

  /// Tayfanın duyuru listesi.
  static String duyurular(String tayfaId) => '${tayfa(tayfaId)}/$duyurularYolu';

  /// Tek bir duyurunun ekranı.
  static String duyuru(String tayfaId, String duyuruId) =>
      '${duyurular(tayfaId)}/$duyuruId';

  /// Soru-cevap modülünün `/t/<tayfaId>/` altındaki yolu (ADR-0018 §4).
  static const sorularYolu = 'sorular';

  /// Tayfanın soruları.
  static String sorular(String tayfaId) => '${tayfa(tayfaId)}/$sorularYolu';

  /// Tek bir sorunun ekranı ve cevapları.
  static String soru(String tayfaId, String soruId) =>
      '${sorular(tayfaId)}/$soruId';

  /// Etkinlik modülünün `/t/<tayfaId>/` altındaki yolu (ADR-0015 §3).
  static const etkinliklerYolu = 'etkinlikler';

  /// Tayfanın yaklaşan etkinlikleri.
  static String etkinlikler(String tayfaId) =>
      '${tayfa(tayfaId)}/$etkinliklerYolu';

  /// Anket modülünün `/t/<tayfaId>/` altındaki yolu (ADR-0018 §5).
  static const anketlerYolu = 'anketler';

  /// Anket listesinde etkinlik süzgecinin sorgu parametresi.
  static const anketEtkinlikParametresi = 'etkinlik';

  /// Tayfanın anketleri; [etkinlikId] verilirse yalnızca o etkinliğin
  /// anketleri.
  static String anketler(String tayfaId, {String? etkinlikId}) {
    final yol = '${tayfa(tayfaId)}/$anketlerYolu';
    if (etkinlikId == null) return yol;
    return Uri(
      path: yol,
      queryParameters: {anketEtkinlikParametresi: etkinlikId},
    ).toString();
  }

  /// Tek bir anketin ekranı.
  static String anket(String tayfaId, String anketId) =>
      '${anketler(tayfaId)}/$anketId';

  /// Sohbet sekmesi.
  static const sohbet = '/sohbet';

  /// Kanal ekranının Sohbet sekmesi altındaki yolu (ADR-0018 §9).
  static const sohbetKanalYolu = 'kanal';

  /// Bir kanalın mesaj akışı (`/sohbet/kanal/<tayfaId>/<kanalId>`).
  static String kanal(String tayfaId, String kanalId) =>
      '$sohbet/$sohbetKanalYolu/$tayfaId/$kanalId';

  /// Birebir konuşmanın Sohbet sekmesi altındaki yolu (ADR-0018 §9).
  static const birebirYolu = 'birebir';

  /// Bir kişiyle konuşmanın (varsa açılır, yoksa ilk mesaj yazılır)
  /// Sohbet sekmesi altındaki yolu; kişi profilindeki "Mesaj gönder".
  static const birebirKisiYolu = 'kisi';

  /// Mesaj isteklerinin Sohbet sekmesi altındaki yolu.
  static const mesajIstekleriYolu = 'istekler';

  /// Reddedilen isteklerin mesaj istekleri altındaki yolu.
  static const reddedilenlerYolu = 'reddedilenler';

  /// Bir birebir konuşma.
  static String birebirKonusma(String konusmaId) =>
      '$sohbet/$birebirYolu/$konusmaId';

  /// Bir kişiyle birebir konuşma.
  static String birebirKisi(String kullaniciId) =>
      '$sohbet/$birebirKisiYolu/$kullaniciId';

  /// Mesaj istekleri.
  static const mesajIstekleri = '$sohbet/$mesajIstekleriYolu';

  /// Reddedilen mesaj istekleri.
  static const reddedilenler = '$mesajIstekleri/$reddedilenlerYolu';

  /// Bildirimler ekranı (istemci ADR-0030): sekme değildir; Tayfa ve
  /// Keşfet sekmelerinin üst çubuğundaki zilden sekmelerin üstünde açılır.
  static const bildirimler = '/bildirimler';

  /// Profil sekmesi.
  static const profil = '/profil';

  /// Oturum korumalarının gönderdiği ekranlar (ADR-0012).
  static const giris = '/giris';
  static const kayit = '/kayit';
  static const onay = '/onay';

  /// Kayıt bitince bir kez gösterilen hoş geldin ekranı ("Tanışma tamam";
  /// ADR-0012 §3). Yalnızca kayıttan sonra yönlendirmeyle açılır.
  static const tanismaTamam = '/tanisma-tamam';

  /// Kayıtta `age-blocked` dönünce gösterilen sade bilgi ekranı (ADR-0012
  /// §3); yeniden deneme yolu yoktur.
  static const hesapAcilamadi = '/hesap-acilamadi';

  /// Açılışta oturum kaydı okunurken gösterilen ekran (ADR-0012 §1).
  static const acilis = '/acilis';

  /// "Güncelleme gerekli" ekranı (ADR-0012 §1.1).
  static const guncelleme = '/guncelleme';

  /// İlk açılıştaki hoş geldin tanıtımı (ADR-0017).
  static const hosGeldin = '/hos-geldin';

  /// Tanıtım bitince gidilecek adresin sorgu parametresi (ADR-0017 §1:
  /// davet ve referans linki tanıtımdan sonra işlenir). Yalnızca yol taşır;
  /// sorgu ve fragment (davet token'ı) hiçbir zaman buraya yazılmaz.
  static const hedefParametresi = 'hedef';

  /// Tanıtım adresi; [hedef] verilirse tanıtımdan sonra gidilecek yol.
  static String hosGeldinAdresi([String? hedef]) {
    if (hedef == null) return hosGeldin;
    final sorgu = {hedefParametresi: hedef};
    return Uri(path: hosGeldin, queryParameters: sorgu).toString();
  }

  /// Keşfet sekmesi (istemci ADR-0030; akış ADR-0027).
  static const kesfet = '/kesfet';

  /// Güvenlik kişisi olduğun etkinliklerin `/profil` altındaki yolu
  /// (ADR-0027 §1).
  static const guvenlikPaylasimlariYolu = 'guvenlik';

  /// Güvenlik kişisi olduğun etkinlikler (`safety_alert` buraya açılır).
  static const guvenlikPaylasimlari = '$profil/$guvenlikPaylasimlariYolu';

  /// Tayfa oluşturma sihirbazı (ADR-0014 §4). Kodla katılım alttan açılan
  /// bir sayfadır; adresi yoktur.
  static const tayfaOlustur = '/tayfa-olustur';

  /// Anlık (bireysel) etkinlik sihirbazı (ADR-0026). Kabuğun üstünde tam
  /// ekran açılır; tayfa yoktur.
  static const anlikEtkinlikYolu = '/anlik-etkinlik';

  /// Anlık etkinlik sihirbazının açılış gününün sorgu parametresi
  /// (`YYYY-MM-DD`, yerel takvim günü). Girdi kabul edilir ve doğrulanır.
  static const anlikGunParametresi = 'gun';

  /// Anlık etkinlikte önceden seçili arkadaşın sorgu parametresi (UUID).
  static const anlikDavetliParametresi = 'davetli';

  /// Anlık etkinlik sihirbazının adresi; "Boşum" rozetindeki "Bir şey
  /// yapalım" [gun] ve [davetli] verir.
  static String anlikEtkinlik({DateTime? gun, String? davetli}) {
    final sorgu = <String, String>{
      if (gun != null) anlikGunParametresi: _gunMetni(gun),
      anlikDavetliParametresi: ?davetli,
    };
    return Uri(
      path: anlikEtkinlikYolu,
      queryParameters: sorgu.isEmpty ? null : sorgu,
    ).toString();
  }

  static String _gunMetni(DateTime gun) {
    String iki(int sayi) => sayi.toString().padLeft(2, '0');
    return '${gun.year.toString().padLeft(4, '0')}-${iki(gun.month)}-'
        '${iki(gun.day)}';
  }

  /// Şimdi başlat ekranı (App ADR-0032 §2): kabuğun üstünde tam ekran.
  /// `tayfa` yoksa anlık etkinlik açılır.
  static const simdiYolu = '/simdi';

  /// Şimdi ekranının tayfa sorgu parametresi (UUID; girdi kabul edilir).
  static const simdiTayfaParametresi = 'tayfa';

  /// Şimdi ekranının adresi: [tayfaId] verilirse o tayfada; verilmezse
  /// anlık etkinlik ("Boşum" rozetinden [davetli] ile).
  static String simdi({String? tayfaId, String? davetli}) {
    final sorgu = <String, String>{
      simdiTayfaParametresi: ?tayfaId,
      anlikDavetliParametresi: ?davetli,
    };
    return Uri(
      path: simdiYolu,
      queryParameters: sorgu.isEmpty ? null : sorgu,
    ).toString();
  }

  /// Anlık tayfayı kalıcı tayfaya dönüştürme sihirbazının yolu
  /// ("Bu ekiple tayfa kur"; ADR-0026). Tam ekran; kimlik girdi kabul
  /// edilir.
  static const tayfaDonusturOneki = '/tayfa-donustur';

  /// Dönüştürme sihirbazının adresi.
  static String tayfaDonustur(String tayfaId) => '$tayfaDonusturOneki/$tayfaId';

  /// Etkinlik oluşturma sihirbazının etkinlik listesi altındaki yolu.
  static const etkinlikOlusturYolu = 'yeni';

  /// Etkinlik düzenleme ekranının etkinlik detayı altındaki yolu.
  static const etkinlikDuzenleYolu = 'duzenle';

  /// Bir etkinliğin detayı.
  static String etkinlik(String tayfaId, String etkinlikId) =>
      '${etkinlikler(tayfaId)}/$etkinlikId';

  /// Etkinlik oluşturma sihirbazı.
  static String etkinlikOlustur(String tayfaId) =>
      '${etkinlikler(tayfaId)}/$etkinlikOlusturYolu';

  /// Etkinlik düzenleme.
  static String etkinlikDuzenle(String tayfaId, String etkinlikId) =>
      '${etkinlik(tayfaId, etkinlikId)}/$etkinlikDuzenleYolu';

  /// Katılımcılar ekranının etkinlik detayı altındaki yolu (2026-11-13
  /// yeniden tasarım; ADR-0015 Notlar).
  static const etkinlikKatilimcilariYolu = 'katilimcilar';

  /// Bir etkinliğin katılımcıları.
  static String etkinlikKatilimcilari(String tayfaId, String etkinlikId) =>
      '${etkinlik(tayfaId, etkinlikId)}/$etkinlikKatilimcilariYolu';

  /// Albüm ekranının etkinlik detayı altındaki yolu (istemci ADR-0025).
  static const etkinlikAlbumuYolu = 'album';

  /// Etkinliğin fotoğraf albümü.
  static String etkinlikAlbumu(String tayfaId, String etkinlikId) =>
      '${etkinlik(tayfaId, etkinlikId)}/$etkinlikAlbumuYolu';

  /// Profil sekmesindeki oturumlar ekranının profil altındaki yolu
  /// (ADR-0018 §2).
  static const oturumlarYolu = 'oturumlar';

  /// Açık oturumların listesi.
  static const oturumlar = '$profil/$oturumlarYolu';

  /// Hesap silme ekranının profil altındaki yolu (ADR-0018 §2).
  static const hesabiSilYolu = 'hesabi-sil';

  /// Hesap silme açıklaması ve akışı.
  static const hesabiSil = '$profil/$hesabiSilYolu';

  /// Bildirim ayarlarının profil altındaki yolu (istemci ADR-0019 §3).
  static const bildirimAyarlariYolu = 'bildirimler';

  /// Cihazdaki bildirim izni ve sistem ayarı.
  static const bildirimAyarlari = '$profil/$bildirimAyarlariYolu';

  /// KVKK veri dışa aktarma ekranının profil altındaki yolu (ADR-0022).
  static const veriDisaAktarmaYolu = 'verilerim';

  /// "Verilerimi indir": talep, durum ve indirme.
  static const veriDisaAktarma = '$profil/$veriDisaAktarmaYolu';

  /// Tanıtım bilgileri ekranının profil altındaki yolu (issue #186).
  static const tanitimBilgileriYolu = 'tanitim';

  /// "Tanıtım bilgilerin": profil tamamlama alanları, "Kim görür" ve doğum
  /// günü görünürlüğü.
  static const tanitimBilgileri = '$profil/$tanitimBilgileriYolu';

  /// Profil tamamlama formunun tek bir adımı (`/profil/tanitim/<adım>`);
  /// [adim] formdaki adımın sabit yol adıdır.
  static String tanitimAdimi(String adim) => '$tanitimBilgileri/$adim';

  /// Girişten sonra açılan profil tamamlama formu (issue #186); kabuğun
  /// üstünde tam ekran.
  static const profilTamamla = '/profil-tamamla';

  /// Tayfa yönetiminin `/t/<tayfaId>/` altındaki yolu (ADR-0018 §1). Alt
  /// ekranlar (istekler, üyeler, bilgiler, davetler) bunun altındadır.
  static const tayfaAyarlariYolu = 'ayarlar';

  /// Tayfa ayarları ekranı.
  static String tayfaAyarlari(String tayfaId) =>
      '${tayfa(tayfaId)}/$tayfaAyarlariYolu';

  /// Katılım isteklerinin ayarlar altındaki yolu.
  static const katilimIstekleriYolu = 'istekler';

  /// Katılım istekleri ekranı (ana sayfadaki bekleyen istek satırı).
  static String katilimIstekleri(String tayfaId) =>
      '${tayfaAyarlari(tayfaId)}/$katilimIstekleriYolu';

  /// QR ile cihaz bağlamanın (eşleştirilmiş cihaz QR okutur) profil
  /// altındaki yolu (ADR-0020).
  static const cihazBaglaYolu = 'cihaz-bagla';

  /// Eşleştirilmiş cihazda "Cihaz bağla" (QR okutma).
  static const cihazBagla = '$profil/$cihazBaglaYolu';

  /// Bu cihazı bağlamanın (yeni cihaz QR gösterir) profil altındaki yolu.
  static const buCihaziBaglaYolu = 'bu-cihazi-bagla';

  /// Eşleştirilmemiş cihazda "Bu cihazı bağla" (QR gösterme).
  static const buCihaziBagla = '$profil/$buCihaziBaglaYolu';

  /// Arkadaşlar ekranının profil altındaki yolu (ADR-0018 §7). Arkadaş
  /// bulma, istekler ve engellenenler bunun altındadır.
  static const arkadaslarYolu = 'arkadaslar';

  /// Arkadaş listesi.
  static const arkadaslar = '$profil/$arkadaslarYolu';

  /// Referans koduyla arkadaş bulmanın arkadaşlar altındaki yolu.
  static const arkadasBulYolu = 'bul';

  /// Referans koduyla arkadaş bulma.
  static const arkadasBul = '$arkadaslar/$arkadasBulYolu';

  /// Arkadaşlık isteklerinin arkadaşlar altındaki yolu.
  static const arkadasIstekleriYolu = 'istekler';

  /// Gelen ve gönderilen arkadaşlık istekleri.
  static const arkadasIstekleri = '$arkadaslar/$arkadasIstekleriYolu';

  /// Engellenenlerin arkadaşlar altındaki yolu.
  static const engellenenlerYolu = 'engellenenler';

  /// Engellenen kullanıcılar.
  static const engellenenler = '$arkadaslar/$engellenenlerYolu';

  /// "Boşum" (kendi boş günlerin) ekranının arkadaşlar altındaki yolu
  /// (Tayfam-Api ADR-0029; tasarım 26-bosum).
  static const bosVakitYolu = 'bos-vakit';

  /// Kendi boş günlerin.
  static const bosVakit = '$arkadaslar/$bosVakitYolu';

  /// Boş gün eklemenin "Boşum" altındaki yolu.
  static const bosGunEkleYolu = 'ekle';

  /// Boş gün ekleme.
  static const bosGunEkle = '$bosVakit/$bosGunEkleYolu';

  /// Kendi katılım geçmişinin tamamının profil altındaki yolu (profil
  /// sekmesindeki "Tümünü gör"; 2026-11-13).
  static const katilimlarimYolu = 'katilimlarim';

  /// Kendi katılım geçmişinin tamamı.
  static const katilimlarim = '$profil/$katilimlarimYolu';

  /// Gelen doğrudan tayfa davetlerinin profil altındaki yolu (ADR-0018 §7).
  static const tayfaDavetleriYolu = 'tayfa-davetleri';

  /// Gelen doğrudan tayfa davetleri.
  static const tayfaDavetleri = '$profil/$tayfaDavetleriYolu';

  /// Kişi profilinin ilk parçası (`/kisi/<kullaniciId>`). Kişi profili
  /// sekmelerin üstünde açılır; her sekmeden gidilebilir.
  static const kisiOneki = '/kisi';

  /// Kişi profili rotasındaki kimlik parametresinin adı.
  static const kisiIdParametresi = 'kullaniciId';

  /// [kullaniciId]'nin profili (ad, ortak tayfalar, katılım geçmişi).
  static String kisi(String kullaniciId) => '$kisiOneki/$kullaniciId';

  /// [adres] sekmelerin üstünde açılan bir ekran mı (kişi profili,
  /// Bildirimler). Bu adreslere `push` ile gidilir: geri tuşu önceki
  /// ekrana döner ve kabuk (WebSocket, push dinleyicisi) yığında kalır.
  /// Sekme adreslerine `go` ile gidilir.
  static bool sekmelerinUstundeMi(String adres) {
    final yol = Uri.tryParse(adres)?.path ?? adres;
    return yol == bildirimler || yol.startsWith('$kisiOneki/');
  }
}
