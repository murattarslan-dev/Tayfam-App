/// Hesap özelliğinin dışa açık dosyası (ADR-0002): açılış, güncelleme
/// gerekli, giriş, kayıt ve yeniden onay ekranları (ADR-0012). Google
/// kimlik sağlayıcısı, giriş ucu, hukuki metin sürümleri ve dış bağlantı
/// açıcısı profildeki hesap silme ve hukuki bağlantılar için dışa açıktır
/// (ADR-0018 §2).
library;

export 'package:tayfam/features/hesap/data/dis_baglanti.dart'
    show DisBaglantiAcici, disBaglantiAciciProvider;
export 'package:tayfam/features/hesap/data/google_kimligi.dart'
    show
        GoogleGirisHatasi,
        GoogleKimligi,
        GoogleKimlikSaglayici,
        googleKimlikSaglayiciProvider;
export 'package:tayfam/features/hesap/data/hesap_deposu.dart'
    show HesapDeposu, hesapDeposuProvider, hesapPlatformuProvider;
export 'package:tayfam/features/hesap/data/hukuki_metinler.dart'
    show HukukiMetin, OnaySurumleri;
export 'package:tayfam/features/hesap/presentation/acilis_ekrani.dart';
export 'package:tayfam/features/hesap/presentation/giris_ekrani.dart';
export 'package:tayfam/features/hesap/presentation/guncelleme_ekrani.dart';
export 'package:tayfam/features/hesap/presentation/hesap_ortak.dart'
    show disBaglantiyiAc, hesapHatasiMetni;
export 'package:tayfam/features/hesap/presentation/kayit_ekrani.dart';
export 'package:tayfam/features/hesap/presentation/onay_ekrani.dart';
