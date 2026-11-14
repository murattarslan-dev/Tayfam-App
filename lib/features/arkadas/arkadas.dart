/// Arkadaşlık özelliğinin dışa açık dosyası (ADR-0002, ADR-0018 §7):
/// referans koduyla arkadaş bulma, istekler, arkadaş listesi, engelleme,
/// doğrudan tayfa daveti ve gelen davetler, kişi profili ve katılım
/// geçmişi.
///
/// - [arkadasRotalari] `/profil` rotasının altına, [kisiProfiliRotasi]
///   üst düzeye eklenir.
/// - [ArkadaslikGirisleri] profil sekmesindeki "Arkadaşlar" bölümüdür;
///   [KatilimOzeti] profildeki son katılımlar, [arkadasEkleSayfasiniAc]
///   "Arkadaş ekle" alttan sayfasıdır.
/// - [kisiProfiliEylemleriProvider] kişi profiline başka paketlerin düğme
///   eklediği kancadır (ör. birebir mesajın "Mesaj gönder"i);
///   [referansPaylasimiProvider] Arkadaşlar ekranındaki "Kodumu paylaş",
///   [katilimGorunurlukSatiriProvider] Katılım geçmişin ekranındaki
///   görünürlük satırı kancasıdır (ikisini de profil paketi verir).
library;

export 'package:tayfam/features/arkadas/application/bildirim_yanitlari.dart'
    show BildirimYanitlari, DavetYaniti, bildirimYanitlariProvider;
export 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart'
    show
        KisiProfiliBilgisi,
        KisiProfiliEylemi,
        ReferansPaylasimi,
        katilimGorunurlukSatiriProvider,
        kisiProfiliEylemleriProvider,
        referansPaylasimiProvider;
export 'package:tayfam/features/arkadas/application/kisi_profili_notifier.dart'
    show sonKatilimlarProvider;
export 'package:tayfam/features/arkadas/presentation/arkadas_bul_ekrani.dart'
    show arkadasEkleSayfasiniAc;
export 'package:tayfam/features/arkadas/presentation/arkadas_rotalari.dart'
    show arkadasRotalari, kisiProfiliRotasi;
export 'package:tayfam/features/arkadas/presentation/arkadaslar_ekrani.dart'
    show ArkadaslikGirisleri;
export 'package:tayfam/features/arkadas/presentation/katilim_gecmisi.dart'
    show KatilimOzeti;
