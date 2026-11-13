/// Tayfa özelliğinin dışa açık dosyası (ADR-0002): tayfa listesi ve aktif
/// tayfa uzlaştırması, ana sayfa, değiştirme paneli, karşılama, kodla
/// katılım ve oluşturma sihirbazı (ADR-0014). Tayfa özeti (rol, açık
/// modüller) ve `client_request_id` üreticisi modüllerin kullanımı için
/// dışa açıktır (ADR-0015). Tayfa yönetimi (ADR-0018 §1) görünümü
/// tazelemek için görünüm sağlayıcısını, ilgi alanı listesini,
/// ilgi alanı çipini ve paylaşıcıyı kullanır.
library;

export 'package:tayfam/features/tayfa/application/kurulum.dart'
    show kuralGosterilsin, kurulumGosterilsin, tayfaSaatiProvider;
export 'package:tayfam/features/tayfa/application/olusturma_notifier.dart'
    show ilgiAlanlari, istekKimligiUreticisiProvider;
export 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart'
    show TayfaOzeti, tayfaGorunumuProvider, tayfaOzetiProvider;
export 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart'
    show
        davetKisayoluProvider,
        etkinTayfaIdleriProvider,
        tayfaAdiProvider,
        tayfalarYukleniyorProvider,
        tayfalarimProvider;
export 'package:tayfam/features/tayfa/data/paylasim.dart'
    show Paylasici, paylasiciProvider;
export 'package:tayfam/features/tayfa/data/tayfa_deposu.dart'
    show TayfaDeposu, tayfaDeposuProvider;
export 'package:tayfam/features/tayfa/presentation/karsilama_ekrani.dart';
export 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart'
    show kodlaKatilmaSayfasiniAc;
export 'package:tayfam/features/tayfa/presentation/olusturma_ekrani.dart'
    show IlgiCipi, OlusturmaEkrani;
export 'package:tayfam/features/tayfa/presentation/tayfa_ana_sayfa.dart';
export 'package:tayfam/features/tayfa/presentation/tayfa_avatari.dart';
export 'package:tayfam/features/tayfa/presentation/tayfa_degistirme_paneli.dart';
export 'package:tayfam/features/tayfa/presentation/tayfa_ortak.dart'
    show bekleyenRozetMetni;
export 'package:tayfam/features/tayfa/presentation/tayfa_yenileyici.dart';
