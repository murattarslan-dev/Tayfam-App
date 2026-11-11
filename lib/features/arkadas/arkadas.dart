/// Arkadaşlık özelliğinin dışa açık dosyası (ADR-0002, ADR-0018 §7):
/// referans koduyla arkadaş bulma, istekler, arkadaş listesi, engelleme,
/// doğrudan tayfa daveti ve gelen davetler, kişi profili ve katılım
/// geçmişi.
///
/// - [arkadasRotalari] `/profil` rotasının altına, [kisiProfiliRotasi]
///   üst düzeye eklenir.
/// - [ArkadaslikGirisleri] profil sekmesindeki giriş kartıdır.
/// - [kisiProfiliEylemleriProvider] kişi profiline başka paketlerin düğme
///   eklediği kancadır (ör. birebir mesajın "Mesaj gönder"i).
library;

export 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart'
    show KisiProfiliBilgisi, KisiProfiliEylemi, kisiProfiliEylemleriProvider;
export 'package:tayfam/features/arkadas/presentation/arkadas_rotalari.dart'
    show arkadasRotalari, kisiProfiliRotasi;
export 'package:tayfam/features/arkadas/presentation/arkadaslar_ekrani.dart'
    show ArkadaslikGirisleri;
