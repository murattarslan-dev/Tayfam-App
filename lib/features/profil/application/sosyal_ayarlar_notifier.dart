import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

/// "Profilleme" ve "Beni önerme" ayarları ile kaydın sürüp sürmediği.
@immutable
final class SosyalAyarlarDurumu {
  const SosyalAyarlarDurumu({required this.ayarlar, this.kaydediliyor = false});

  /// Sunucunun son döndürdüğü ayarlar.
  final SocialSettings ayarlar;

  /// Bir değişiklik kaydedilirken `true`; anahtarlar pasiftir.
  final bool kaydediliyor;
}

/// Profilleme ve "Beni önerme" (`GET` / `PATCH /v1/me/social-settings`;
/// Tayfam-Api ADR-0030 §5; 2026-11-16 tasarım: 27-arkadas-onerisi,
/// karar 5–8). Değişiklik hemen kaydedilir; durum her zaman sunucunun
/// döndürdüğü ayarlardır, hata olursa eski değer kalır.
///
/// Ayarların etkisini (puanın silinmesi, önerilerin geri çekilmesi)
/// sunucu uygular; istemci yalnızca değeri gönderir. Yalnızca bellektedir
/// (ADR-0006); oturum değişince sıfırlanır.
/// "Şimdi bildirimi kimden"in gösterilen değeri: sunucu tanınmayan bir
/// değer döndürürse (`unknown`) sözleşmenin varsayılanı `all` gösterilir.
/// En geniş seçenek gösterilir ki kullanıcı bildirim alacağını sansın ve
/// gerekirse daraltsın; daha kısıtlı görünüp açık kalmasın.
SocialSettingsUpdateNowFromFriends simdiKimdenGorunen(
  SocialSettings a,
) => switch (a.nowFromFriends) {
  SocialSettingsNowFromFriends.close =>
    SocialSettingsUpdateNowFromFriends.close,
  SocialSettingsNowFromFriends.off => SocialSettingsUpdateNowFromFriends.off,
  SocialSettingsNowFromFriends.all || SocialSettingsNowFromFriends.unknown =>
    SocialSettingsUpdateNowFromFriends.all,
};

class SosyalAyarlarNotifier extends AsyncNotifier<SosyalAyarlarDurumu> {
  @override
  Future<SosyalAyarlarDurumu> build() async {
    if (ref.watch(oturumDurumuProvider) != OturumDurumu.acik) {
      throw const OturumYok();
    }
    final ayarlar = await ref.watch(profilDeposuProvider).sosyalAyarlar();
    return SosyalAyarlarDurumu(ayarlar: ayarlar);
  }

  /// "Profilleme"yi [acik] yapar. Kapatma onayı ekranda sorulur. Başarıda
  /// `null`, aksi halde gösterilecek hata.
  Future<Object?> profillemeAyarla({required bool acik}) =>
      _degistir(SocialSettingsUpdate(profilingEnabled: acik));

  /// "Beni önerme"yi [acik] yapar. Başarıda `null`, aksi halde
  /// gösterilecek hata.
  Future<Object?> beniOnermeAyarla({required bool acik}) =>
      _degistir(SocialSettingsUpdate(hideFromSuggestions: acik));

  /// "Keşfet'te arkadaşlarım görebilsin"i [acik] yapar (Tayfam-Api
  /// ADR-0033 §4; 30-kesfet-ve-guvenlik, karar 27). Profillemeden
  /// bağımsızdır, onaysızdır. Başarıda `null`, aksi halde gösterilecek
  /// hata.
  Future<Object?> kesfetGorunurlukAyarla({required bool acik}) =>
      _degistir(SocialSettingsUpdate(discoverVisibleToFriends: acik));

  /// "Arkadaşlarımdan şimdi bildirimleri"ni [deger] yapar (Tayfam-Api
  /// ADR-0038 §4; App ADR-0032 §5). Onaysızdır. Başarıda `null`, aksi
  /// halde gösterilecek hata.
  Future<Object?> simdiKimdenAyarla(SocialSettingsUpdateNowFromFriends deger) =>
      _degistir(SocialSettingsUpdate(nowFromFriends: deger));

  Future<Object?> _degistir(SocialSettingsUpdate degisiklik) async {
    final simdiki = state.value;
    if (simdiki == null || simdiki.kaydediliyor) return null;
    state = AsyncData(
      SosyalAyarlarDurumu(ayarlar: simdiki.ayarlar, kaydediliyor: true),
    );
    try {
      final yeni = await ref
          .read(profilDeposuProvider)
          .sosyalAyarlariDegistir(degisiklik);
      if (ref.mounted) state = AsyncData(SosyalAyarlarDurumu(ayarlar: yeni));
      return null;
    } on Exception catch (hata) {
      if (ref.mounted) {
        state = AsyncData(SosyalAyarlarDurumu(ayarlar: simdiki.ayarlar));
        if (hata is OturumYok) {
          ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
        }
      }
      return hata;
    }
  }
}

/// Profil sekmesindeki profilleme ayarları. Hata otomatik yeniden
/// denenmez; ekran "Tekrar dene" sunar.
final sosyalAyarlarProvider =
    AsyncNotifierProvider.autoDispose<
      SosyalAyarlarNotifier,
      SosyalAyarlarDurumu
    >(
      SosyalAyarlarNotifier.new,
      name: 'sosyalAyarlarProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
