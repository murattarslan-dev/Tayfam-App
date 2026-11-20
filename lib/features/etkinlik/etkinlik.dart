/// Etkinlik özelliğinin dışa açık dosyası (ADR-0002): bileşen kaydı
/// (ADR-0024 §3; her bileşen buraya kendi `export` satırını ekler),
/// etkinlik modülü, yaklaşan etkinlikler listesi ve etkinlik kartı
/// (ADR-0015 §1, §3). Faz 1 tür kaydı kalktı: türe özel araçlar
/// bileşenlerdedir (#231). Detaydaki
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
export 'package:tayfam/features/etkinlik/bilesenler/gunluk/gunluk_bileseni.dart'
    show GunlukBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_bileseni.dart'
    show HedefBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/kura/kura_bileseni.dart'
    show KuraBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/liste/liste_bileseni.dart'
    show ListeBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_bileseni.dart'
    show OlcumBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/program/program_bileseni.dart'
    show ProgramBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/rota/rota_bileseni.dart'
    show RotaBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_ekranlari.dart'
    show sozlukGirisEtiketi, sozlukGirisIkonu, sozlukRotalari, sozluklerAdresi;
export 'package:tayfam/features/etkinlik/bilesenler/takim/takim_bileseni.dart'
    show TakimBileseni;
export 'package:tayfam/features/etkinlik/bilesenler/yoklama/yoklama_bileseni.dart'
    show YoklamaBileseni;
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
