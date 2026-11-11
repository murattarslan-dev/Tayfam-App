import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/birebir/application/birebir_gonderici.dart';
import 'package:tayfam/features/birebir/application/birebir_islemi.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/application/mesaj_kurallari.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Kişiyle konuşmayı ararken okunan en çok sayfa (sayfa başına 100
/// konuşma). Sözleşmede kişiye göre konuşma bulan bir uç yoktur.
const int kisiAramaSayfaEnCok = 10;

/// Kişiyle konuşmayı ararken bir sayfadaki konuşma sayısı (sözleşmenin
/// en büyüğü).
const int kisiAramaSayfaBoyutu = 100;

/// Bir kişiyle var olan birebir konuşmanın kimliği; yoksa `null`
/// (kişi profilindeki "Mesaj gönder"; ADR-0018 §9).
///
/// Önce bellekteki konuşma listesine bakılır, bulunamazsa konuşmalar
/// sayfa sayfa taranır. Reddettiğiniz istek listede yoktur; o kişiye
/// yazarsanız konuşma aktif açılır (sözleşme).
class KisiKonusmasiNotifier extends AsyncNotifier<String?> {
  KisiKonusmasiNotifier(this.kullaniciId);

  /// Adresteki kullanıcı kimliği (biçimi yönlendiricide doğrulandı).
  final String kullaniciId;

  @override
  Future<String?> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(birebirDeposuProvider);
    final bilinen = ref
        .read(konusmaListesiProvider.notifier)
        .kisiyle(kullaniciId);
    if (bilinen != null) return bilinen.id;
    String? token;
    final gorulen = <String>{};
    for (var tur = 0; tur < kisiAramaSayfaEnCok; tur++) {
      final sayfa = await depo.konusmalar(
        sayfaToken: token,
        sayfaBoyutu: kisiAramaSayfaBoyutu,
      );
      for (final k in sayfa.ogeler) {
        if (k.otherUserId == kullaniciId) return k.id;
      }
      token = sayfa.sonraki;
      if (token == null || token.isEmpty || !gorulen.add(token)) break;
    }
    return null;
  }
}

/// Bir kişiyle var olan konuşmanın kimliği.
final kisiKonusmasiProvider = AsyncNotifierProvider.autoDispose
    .family<KisiKonusmasiNotifier, String?, String>(
      KisiKonusmasiNotifier.new,
      name: 'kisiKonusmasiProvider',
      retry: yenidenDenemeYok,
    );

/// Henüz konuşma olmayan kişiye ilk mesajın durumu.
@immutable
final class YeniMesajDurumu {
  const YeniMesajDurumu({this.giden, this.konusmaId});

  /// Gönderilen ya da gönderilemeyen ilk mesaj.
  final GidenMesaj? giden;

  /// İlk mesaj gidince açılan konuşmanın kimliği.
  final String? konusmaId;
}

/// Henüz konuşma olmayan kişiye ilk mesaj (`POST /v1/direct-messages`).
///
/// İlk mesaj konuşmayı açar; arkadaş ya da ortak etkinlik geçmişi yoksa
/// mesaj isteği olur. Kimin kime yazabileceğine sunucu karar verir
/// (kesin kural 5); ret, mesajın hatası olarak görünür. Mesaj gidince
/// ekran konuşmaya geçer.
class YeniMesajNotifier extends Notifier<YeniMesajDurumu> {
  YeniMesajNotifier(this.kullaniciId);

  /// Yazılacak kişi.
  final String kullaniciId;

  @override
  YeniMesajDurumu build() {
    ref.watch(oturumDurumuProvider);
    return const YeniMesajDurumu();
  }

  /// [ham] metni gönderir; geçerliyse `true`. Gönderim sürerken ya da
  /// gönderilemeyen mesaj dururken yeni mesaj alınmaz.
  bool gonder(String ham) {
    final metin = birebirMetniniHazirla(ham);
    if (state.giden != null || state.konusmaId != null) return false;
    if (!birebirMetniGecerli(metin)) return false;
    final giden = GidenMesaj(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      metin: metin,
    );
    state = YeniMesajDurumu(giden: giden);
    unawaited(_gonder(giden));
    return true;
  }

  /// Gönderilemeyen mesajı aynı `client_request_id` ile yeniden dener.
  void tekrarDene() {
    final giden = state.giden;
    if (giden == null || giden.durum != GidenDurumu.basarisiz) return;
    final yeni = giden.gonderiliyor();
    state = YeniMesajDurumu(giden: yeni);
    unawaited(_gonder(yeni));
  }

  /// Gönderilemeyen mesajı bellekten atar.
  void vazgec() {
    if (state.giden?.durum != GidenDurumu.basarisiz) return;
    state = const YeniMesajDurumu();
  }

  Future<void> _gonder(GidenMesaj giden) async {
    final DirectMessageSent sonuc;
    try {
      sonuc = await ref
          .read(birebirGondericiProvider)
          .gonder(
            aliciId: kullaniciId,
            metin: giden.metin,
            istekKimligi: giden.istekKimligi,
          );
    } on OturumYok catch (hata) {
      oturumKapandi(ref);
      if (ref.mounted) state = YeniMesajDurumu(giden: giden.basarisiz(hata));
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = YeniMesajDurumu(giden: giden.basarisiz(hata));
      return;
    }
    if (!ref.mounted) return;
    ref.read(konusmaListesiProvider.notifier).yansit(sonuc.conversation);
    state = YeniMesajDurumu(konusmaId: sonuc.conversation.id);
  }
}

/// Bir kişiye ilk mesaj; ekran kapanınca bırakılır.
final yeniMesajProvider = NotifierProvider.autoDispose
    .family<YeniMesajNotifier, YeniMesajDurumu, String>(
      YeniMesajNotifier.new,
      name: 'yeniMesajProvider',
    );
