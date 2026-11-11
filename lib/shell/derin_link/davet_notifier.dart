import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/shell/derin_link/davet_deposu.dart';
import 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';

/// Bekleyen davet yok (link geçersizdi ya da zaten işlendi).
final class DavetYok implements Exception {
  const DavetYok();
}

/// Davetle katılımın sonucu.
enum DavetSonucu {
  /// Üyelik hemen etkin; tayfa aktif oldu.
  etkin,

  /// Katılım isteği yönetici onayını bekliyor.
  bekliyor,
}

/// Davet ekranının durumu.
@immutable
final class DavetDurumu {
  const DavetDurumu({
    required this.onizleme,
    this.gonderiliyor = false,
    this.hata,
    this.sonuc,
    this.tayfaId,
  });

  /// Tayfanın dar görünümü (ad, üye sayısı, zaten üye mi).
  final InvitePreview onizleme;

  /// Katılım isteği sürüyor.
  final bool gonderiliyor;

  /// Son katılım isteğinin hatası; yoksa `null`.
  final Object? hata;

  /// Katılım başarılıysa sonucu.
  final DavetSonucu? sonuc;

  /// [sonuc] [DavetSonucu.etkin] ise katılınan tayfa.
  final String? tayfaId;
}

/// Davet akışı (ADR-0018 §6): önizleme `POST /v1/invite-previews`,
/// katılım `POST /v1/invite-joins`.
///
/// Token kutudan ([derinLinkKutusuProvider]) okunur, yalnızca istek
/// gövdesine konur; bu durumda tutulmaz. Katılım başarılı olunca ya da
/// kullanıcı vazgeçince kutu boşaltılır. Önizleme hatasında (geçersiz,
/// süresi dolmuş, iptal edilmiş link…) ekran hatayı gösterir; kullanıcı
/// kapatınca davet bırakılır.
class DavetNotifier extends AsyncNotifier<DavetDurumu> {
  @override
  Future<DavetDurumu> build() async {
    final token = ref.read(derinLinkKutusuProvider).davetToken;
    if (token == null) throw const DavetYok();
    try {
      final onizleme = await ref.read(davetDeposuProvider).onizle(token);
      return DavetDurumu(onizleme: onizleme);
    } on OturumYok {
      _oturumKapandi();
      rethrow;
    }
  }

  /// Davetle katılır. Sürerken ikinci çağrı yok sayılır.
  Future<void> katil() async {
    final mevcut = state.value;
    final kutu = ref.read(derinLinkKutusuProvider);
    final token = kutu.davetToken;
    if (mevcut == null || mevcut.gonderiliyor || token == null) return;
    state = AsyncData(
      DavetDurumu(onizleme: mevcut.onizleme, gonderiliyor: true),
    );
    final Membership uyelik;
    try {
      uyelik = await ref.read(davetDeposuProvider).katil(token);
    } on OturumYok {
      _oturumKapandi();
      return;
    } on Exception catch (hata) {
      if (ref.mounted) {
        state = AsyncData(DavetDurumu(onizleme: mevcut.onizleme, hata: hata));
      }
      return;
    }
    kutu.davetiBirak();
    if (!ref.mounted) return;
    final liste = ref.read(tayfalarimProvider.notifier);
    final aktif = ref.read(aktifTayfaIdProvider.notifier);
    final etkin = uyelik.status == MembershipStatus.active;
    final yenilendi = await liste.yenile();
    if (!yenilendi) {
      // Liste alınamadı; sunucunun cevabı yine de görünsün.
      liste.ekle(
        MyTayfa(
          tayfaId: uyelik.tayfaId,
          name: mevcut.onizleme.name,
          role: uyelik.role,
          status: etkin ? MyTayfaStatus.active : MyTayfaStatus.pending,
        ),
      );
    }
    if (!ref.mounted) return;
    if (etkin && uuidBicimindeMi(uyelik.tayfaId)) {
      aktif.sec(uyelik.tayfaId);
      state = AsyncData(
        DavetDurumu(
          onizleme: mevcut.onizleme,
          sonuc: DavetSonucu.etkin,
          tayfaId: uyelik.tayfaId,
        ),
      );
    } else {
      state = AsyncData(
        DavetDurumu(onizleme: mevcut.onizleme, sonuc: DavetSonucu.bekliyor),
      );
    }
  }

  /// Daveti bırakır (vazgeçildi ya da ekran kapatıldı).
  void vazgec() => ref.read(derinLinkKutusuProvider).davetiBirak();

  void _oturumKapandi() {
    if (!ref.mounted) return;
    ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
  }
}

/// Davet ekranının notifier'ı; ekran kapanınca bırakılır. Hata otomatik
/// yeniden denenmez (önizleme IP başına sınırlıdır); ekran "Tekrar dene"
/// sunar.
final davetProvider =
    AsyncNotifierProvider.autoDispose<DavetNotifier, DavetDurumu>(
      DavetNotifier.new,
      name: 'davetProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
