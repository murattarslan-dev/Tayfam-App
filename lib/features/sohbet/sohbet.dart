/// Sohbet özelliğinin dışa açık dosyası (ADR-0002, ADR-0018 §9): Sohbet
/// sekmesi (Kanallar ve Birebir bölümleri), kanal ekranı, aktif tayfanın
/// okunmamış kanal mesajı sayısı (rozet), Birebir bölümünün yuvası ve
/// etkinlik detayındaki sohbet bölümü (Tayfam-Api #183).
library;

export 'package:tayfam/features/sohbet/application/kanallar_notifier.dart'
    show okunmamisKanalSayisiProvider;
export 'package:tayfam/features/sohbet/presentation/etkinlik_sohbeti.dart'
    show EtkinlikSohbeti;
export 'package:tayfam/features/sohbet/presentation/sohbet_ekrani.dart'
    show
        BirebirBolumu,
        SohbetEkrani,
        birebirBolumuProvider,
        birebirOkunmamisYuvasiProvider;
export 'package:tayfam/features/sohbet/presentation/sohbet_rotalari.dart';
