/// Etkinlik özelliğinin dışa açık dosyası (ADR-0002): bileşen kaydı
/// (ADR-0024 §3; her bileşen buraya kendi `export` satırını ekler), etkinlik
/// türü kaydı ve türe özel araçları olan türler, etkinlik modülü, yaklaşan
/// etkinlikler listesi ve etkinlik kartı (ADR-0015 §1, §3, §6). Detaydaki
/// sohbet bölümünün yuvası kabukta doldurulur (Tayfam-Api #183).
///
/// Anlık (bireysel) etkinlik (ADR-0026): [anlikEtkinlikRotasi] üst düzeye
/// eklenir; [anlikArkadasDavetEt] `arkadasDavetiProvider`'a verilir.
library;

export 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart'
    show
        EtkinlikListesiNotifier,
        anaSayfaEtkinlikSayisi,
        etkinlikListesiProvider,
        etkinlikSirala;
export 'package:tayfam/features/etkinlik/bilesenler/araclar/araclar_bileseni.dart'
    show AraclarBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart'
    show EtkinlikBileseni, TemelBilesen, etkinlikBilesenKaydiProvider;
export 'package:tayfam/features/etkinlik/bilesenler/rota/rota_bileseni.dart'
    show RotaBileseni;
export 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart'
    show EtkinlikDeposu, etkinlikDeposuProvider;
export 'package:tayfam/features/etkinlik/presentation/anlik/anlik_davet_sayfasi.dart'
    show anlikArkadasDavetEt;
export 'package:tayfam/features/etkinlik/presentation/anlik/anlik_rotasi.dart'
    show anlikEtkinlikRotasi;
export 'package:tayfam/features/etkinlik/presentation/etkinlik_bolumu.dart';
export 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
export 'package:tayfam/features/etkinlik/presentation/etkinlik_modulu.dart';
export 'package:tayfam/features/etkinlik/presentation/etkinlik_sohbeti_yuvasi.dart';
export 'package:tayfam/features/etkinlik/presentation/etkinlikler_ekrani.dart';
export 'package:tayfam/features/etkinlik/turler/balik/balik_turu.dart'
    show BalikTuru;
export 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
export 'package:tayfam/features/etkinlik/turler/kamp/kamp_turu.dart'
    show KampTuru;
export 'package:tayfam/features/etkinlik/turler/yuruyus/yuruyus_turu.dart'
    show YuruyusTuru;
