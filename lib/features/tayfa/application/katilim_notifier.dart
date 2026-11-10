import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/data/tayfa_deposu.dart';

/// Katılım kodunun en çok uzunluğu (sözleşme: `maxLength: 32`).
const int katilimKoduEnCok = 32;

/// Girilen kodu gönderilecek biçime getirir: baştaki ve sondaki boşluklar
/// atılır (ADR-0014 §3). Boşsa ya da [katilimKoduEnCok]'tan uzunsa `null`.
///
/// Büyük/küçük harf dönüştürülmez: sunucu harf duyarsızdır (sözleşme) ve
/// arayüzde harf dönüşümü yapılmaz (ADR-0008).
String? katilimKoduDuzenle(String girilen) {
  final kod = girilen.trim();
  if (kod.isEmpty || kod.runes.length > katilimKoduEnCok) return null;
  return kod;
}

/// Kodla katılımın sonucu.
enum KatilimSonucu {
  /// Açık tayfa: üyelik hemen etkin; tayfa aktif oldu.
  etkin,

  /// Onaylı tayfa: istek yönetici onayını bekliyor.
  bekliyor,
}

/// Kodla katılım sayfasının durumu.
@immutable
final class KatilimDurumu {
  const KatilimDurumu({
    this.gonderiliyor = false,
    this.kodHatali = false,
    this.hata,
    this.sonuc,
    this.tayfaId,
  });

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Girilen kod boş ya da çok uzun (istek gönderilmedi).
  final bool kodHatali;

  /// Son isteğin hatası; yoksa `null`. Metni ortak eşlemeden gelir
  /// (`invalid-join-code` tek ve genel metin, `rate-limited` bekleme
  /// metni; ADR-0005 §4).
  final Object? hata;

  /// İstek başarılıysa sonucu.
  final KatilimSonucu? sonuc;

  /// [sonuc] [KatilimSonucu.etkin] ise katılınan tayfa.
  final String? tayfaId;
}

/// Kodla katılım (ADR-0014 §3): `POST /v1/tayfa-joins`.
///
/// - Etkin üyelik → tayfa listesi yenilenir, tayfa aktif olur; sayfa
///   kapanıp tayfanın ana sayfası açılır.
/// - Bekleyen üyelik → liste yenilenir, "İsteğin gönderildi" gösterilir.
/// - `invalid-join-code` tek ve genel bir metindir; deneme sınırı bekleme
///   metnidir.
///
/// Kod yalnızca istek gövdesine gider; durumda, log'da ya da diskte
/// tutulmaz.
class KatilimNotifier extends Notifier<KatilimDurumu> {
  @override
  KatilimDurumu build() => const KatilimDurumu();

  /// [girilen] kodla katılır. Sürerken ikinci çağrı yok sayılır.
  Future<void> katil(String girilen) async {
    if (state.gonderiliyor) return;
    final kod = katilimKoduDuzenle(girilen);
    if (kod == null) {
      state = const KatilimDurumu(kodHatali: true);
      return;
    }
    state = const KatilimDurumu(gonderiliyor: true);
    final Membership uyelik;
    try {
      uyelik = await ref.read(tayfaDeposuProvider).kodlaKatil(kod);
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = KatilimDurumu(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    final liste = ref.read(tayfalarimProvider.notifier);
    final aktif = ref.read(aktifTayfaIdProvider.notifier);
    final etkin = uyelik.status == MembershipStatus.active;
    final yenilendi = await liste.yenile();
    if (!yenilendi) {
      // Liste alınamadı; sunucunun cevabı yine de görünsün. Ad bir
      // sonraki yenilemede gelir.
      liste.ekle(
        MyTayfa(
          tayfaId: uyelik.tayfaId,
          name: '',
          role: uyelik.role,
          status: etkin ? MyTayfaStatus.active : MyTayfaStatus.pending,
        ),
      );
    }
    if (!ref.mounted) return;
    if (etkin && uuidBicimindeMi(uyelik.tayfaId)) {
      aktif.sec(uyelik.tayfaId);
      state = KatilimDurumu(
        sonuc: KatilimSonucu.etkin,
        tayfaId: uyelik.tayfaId,
      );
    } else {
      state = const KatilimDurumu(sonuc: KatilimSonucu.bekliyor);
    }
  }
}

/// Kodla katılım sayfasının notifier'ı; sayfa kapanınca bırakılır.
final katilimProvider =
    NotifierProvider.autoDispose<KatilimNotifier, KatilimDurumu>(
      KatilimNotifier.new,
      name: 'katilimProvider',
    );
