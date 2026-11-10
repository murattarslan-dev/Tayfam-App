import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yönlendirme korumalarının baktığı oturum durumu (ADR-0003).
///
/// Bu durum yalnızca kullanıcıyı doğru ekrana götürmek içindir; yetki
/// kararı değildir, yetki sunucudadır (CLAUDE.md, kesin kural 5).
enum OturumDurumu {
  /// Oturum yok; giriş ekranına gidilir.
  girisYok,

  /// Google girişi yapıldı, kayıt tamamlanmadı (`registration_pending`).
  kayitBekliyor,

  /// Onay sürümleri değişti, yeniden onay gerekiyor (`consent_required`).
  onayGerekli,

  /// Oturum açık; uygulama kullanılabilir.
  acik,
}

/// Oturum durumunu tutan notifier.
///
/// GEÇİCİ: Gerçek oturum (SessionStore, token yenileme) ApiClient işiyle
/// (#7) gelir; o zamana kadar durum [OturumDurumu.acik] ile başlar ki
/// uygulama açılabilsin. #7 bu notifier'ı SessionStore'dan türetecek.
class OturumDurumuNotifier extends Notifier<OturumDurumu> {
  @override
  OturumDurumu build() => OturumDurumu.acik;

  /// Oturum durumunu değiştirir. Kullanıcıya bağlı provider'lar bu
  /// provider'ı izleyerek sıfırlanır (ADR-0001, kural 8).
  void ayarla(OturumDurumu yeni) => state = yeni;
}

/// Uygulama boyunca yaşayan oturum durumu (ADR-0001, kural 4: kalıcı;
/// Riverpod 3'te `autoDispose` olmayan provider kalıcıdır).
final oturumDurumuProvider =
    NotifierProvider<OturumDurumuNotifier, OturumDurumu>(
      OturumDurumuNotifier.new,
      name: 'oturumDurumuProvider',
    );
