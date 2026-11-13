import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';

/// Bir kullanıcının profili (`GET /v1/users/{user_id}/profile`; ADR-0018
/// §7): ad, arkadaşlık durumu, ortak tayfalar, katılım geçmişinin
/// görünürlüğü. Engel varsa (iki yönden biri) sunucu `user-not-found`
/// döner; ekran var olmayan kullanıcı gibi gösterir.
///
/// Kişiye bağlıdır: `family(kullaniciId)` + `autoDispose`. Yalnızca
/// bellektedir (ADR-0006). Arkadaşlık işlemleri buradan yapılır; karar
/// sunucudadır (kesin kural 5).
class KisiProfiliNotifier extends AsyncNotifier<UserProfile> {
  KisiProfiliNotifier(this.kullaniciId);

  /// Adresteki kullanıcı kimliği.
  final String kullaniciId;

  @override
  Future<UserProfile> build() {
    ref.watch(oturumDurumuProvider);
    return ref.watch(arkadasDeposuProvider).profil(kullaniciId);
  }

  /// Profili yeniden okur. Okunamazsa eldeki profil kalır.
  Future<void> yenile() async {
    try {
      final profil = await ref.read(arkadasDeposuProvider).profil(kullaniciId);
      if (ref.mounted) state = AsyncData(profil);
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
    }
  }

  /// Arkadaşlık isteği gönderir. Kişinin isteği zaten bekliyorsa sunucu
  /// arkadaşlığı hemen kurar.
  Future<Object?> istekGonder() => arkadasIslemi(ref, () async {
    final sonuc = await ref
        .read(arkadasDeposuProvider)
        .istekGonder(kullaniciId);
    _durumuYansit(arkadaslikDurumu(sonuc.state));
  });

  /// Kişinin gönderdiği isteği kabul eder.
  Future<Object?> kabulEt() => arkadasIslemi(ref, () async {
    final sonuc = await ref
        .read(arkadasDeposuProvider)
        .istegiKabulEt(kullaniciId);
    _durumuYansit(arkadaslikDurumu(sonuc.state));
  });

  /// Arkadaşlığı bitirir, gönderilen isteği geri çeker ya da gelen isteği
  /// reddeder; karşı tarafa bildirilmez.
  Future<Object?> kaldir() => arkadasIslemi(ref, () async {
    await ref.read(arkadasDeposuProvider).arkadasligiKaldir(kullaniciId);
    _durumuYansit(null);
  });

  /// Kişiyi engeller: arkadaşlık ve bekleyen istek silinir. Bundan sonra
  /// profil açılmaz (`user-not-found`); ekran kapanır.
  Future<Object?> engelle() => arkadasIslemi(ref, () async {
    await ref.read(arkadasDeposuProvider).engelle(kullaniciId);
    if (!ref.mounted) return;
    arkadaslikDegisti(ref);
    if (ref.read(engellenenlerProvider.exists)) {
      ref.invalidate(engellenenlerProvider);
    }
  });

  /// Kişiyi [tayfaId] tayfasına davet eder. Arkadaş olmayan, banlı ya da
  /// başvurusu bekleyen kişiyi sunucu reddeder.
  Future<Object?> tayfayaDavetEt(String tayfaId) =>
      arkadasIslemi(ref, () async {
        await ref
            .read(arkadasDeposuProvider)
            .tayfayaDavetEt(tayfaId, kullaniciId);
      });

  void _durumuYansit(UserProfileFriendState? durum) {
    if (!ref.mounted) return;
    final p = state.value;
    if (p != null) {
      state = AsyncData(
        UserProfile(
          userId: p.userId,
          displayName: p.displayName,
          avatarUploadId: p.avatarUploadId,
          self: p.self,
          friendState: durum,
          mutualTayfas: p.mutualTayfas,
          activityVisible: p.activityVisible,
          activityVisibility: p.activityVisibility,
        ),
      );
    }
    arkadaslikDegisti(ref);
    // Arkadaşlık katılım geçmişinin görünürlüğünü değiştirebilir.
    final gecmis = katilimGecmisiProvider(kullaniciId);
    if (ref.read(gecmis.exists)) ref.invalidate(gecmis);
    // Görünürlük alanları sunucudan tazelenir; durum zaten yansıdı.
    unawaited(yenile());
  }
}

/// [durum]'un profil karşılığı; tanınmayan durum "ilişki yok" sayılmaz,
/// bilinmeyen olarak kalır.
UserProfileFriendState arkadaslikDurumu(FriendState durum) => switch (durum) {
  FriendState.friends => UserProfileFriendState.friends,
  FriendState.incoming => UserProfileFriendState.incoming,
  FriendState.outgoing => UserProfileFriendState.outgoing,
  FriendState.unknown => UserProfileFriendState.unknown,
};

/// Bir kullanıcının profili.
final kisiProfiliProvider = AsyncNotifierProvider.autoDispose
    .family<KisiProfiliNotifier, UserProfile, String>(
      KisiProfiliNotifier.new,
      name: 'kisiProfiliProvider',
      retry: yenidenDenemeYok,
    );

/// Bir kullanıcının katılım geçmişi (`GET /v1/users/{user_id}/activity`,
/// yeniden eskiye, sayfalı). Görünürlüğe ve 14 gün kuralına sunucu karar
/// verir; görmeye yetki yoksa liste boştur. Tayfa, etkinlik ve süre
/// yalnızca o tayfanın etkin üyelerine doludur (sözleşme).
class KatilimGecmisiNotifier extends SayfaliListeNotifier<ActivityRecord> {
  KatilimGecmisiNotifier(this.kullaniciId);

  /// Adresteki kullanıcı kimliği.
  final String kullaniciId;

  @override
  Future<SayfaliListe<ActivityRecord>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(arkadasDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<ActivityRecord>> sayfaGetir(String? sayfaToken) => ref
      .read(arkadasDeposuProvider)
      .katilimGecmisi(kullaniciId, sayfaToken: sayfaToken);

  /// Kaydın kimliği yoktur; etkinlik, tayfa ve başlangıç birlikte ayırır.
  @override
  String kimlik(ActivityRecord oge) => [
    oge.eventId ?? '',
    oge.tayfaId ?? '',
    oge.eventType.name,
    oge.startedAt.toUtc().toIso8601String(),
  ].join('|');
}

/// Bir kullanıcının katılım geçmişi.
final katilimGecmisiProvider = AsyncNotifierProvider.autoDispose
    .family<KatilimGecmisiNotifier, SayfaliListe<ActivityRecord>, String>(
      KatilimGecmisiNotifier.new,
      name: 'katilimGecmisiProvider',
      retry: yenidenDenemeYok,
    );

/// Profil sekmesinde gösterilen son katılım sayısı (tasarım: Profil-Ana).
const int sonKatilimSayisi = 3;

/// Bir kullanıcının son [sonKatilimSayisi] katılımı ve devamı olup
/// olmadığı (`GET /v1/users/{user_id}/activity?page_size=3`; profil
/// sekmesi, 2026-11-13). Görünürlüğe sunucu karar verir. Yalnızca
/// bellektedir (ADR-0006).
class SonKatilimlarNotifier
    extends AsyncNotifier<({List<ActivityRecord> kayitlar, bool dahaVar})> {
  SonKatilimlarNotifier(this.kullaniciId);

  /// Kaydı istenen kullanıcının kimliği.
  final String kullaniciId;

  @override
  Future<({List<ActivityRecord> kayitlar, bool dahaVar})> build() async {
    ref.watch(oturumDurumuProvider);
    final sayfa = await ref
        .watch(arkadasDeposuProvider)
        .katilimGecmisi(kullaniciId, sayfaBoyutu: sonKatilimSayisi);
    return (
      kayitlar: List<ActivityRecord>.unmodifiable(
        sayfa.ogeler.take(sonKatilimSayisi),
      ),
      dahaVar: sayfa.sonraki != null,
    );
  }
}

/// Bir kullanıcının son katılımları.
final sonKatilimlarProvider = AsyncNotifierProvider.autoDispose
    .family<
      SonKatilimlarNotifier,
      ({List<ActivityRecord> kayitlar, bool dahaVar}),
      String
    >(
      SonKatilimlarNotifier.new,
      name: 'sonKatilimlarProvider',
      retry: yenidenDenemeYok,
    );
