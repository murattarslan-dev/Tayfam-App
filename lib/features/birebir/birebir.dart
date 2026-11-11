/// Birebir mesaj özelliğinin dışa açık dosyası (ADR-0002, ADR-0018 §9,
/// düz sürüm; uçtan uca şifreleme sonraki iştir): Sohbet sekmesindeki
/// konuşmalar ekranı ve bölümü, rotalar, kişi profilindeki "Mesaj gönder"
/// düğmesi ve eylemi ve Sohbet sekmesi rozeti için okunmamış sayısı.
library;

export 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart'
    show birebirOkunmamisSayisiProvider;
export 'package:tayfam/features/birebir/presentation/birebir_rotalari.dart'
    show birebirRotalari;
export 'package:tayfam/features/birebir/presentation/kisi_eylemi.dart'
    show mesajGonderEylemi;
export 'package:tayfam/features/birebir/presentation/kisi_konusmasi_ekrani.dart'
    show MesajGonderDugmesi;
export 'package:tayfam/features/birebir/presentation/konusmalar_ekrani.dart';
