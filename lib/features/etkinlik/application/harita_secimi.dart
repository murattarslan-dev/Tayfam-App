import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/yer_arama.dart';

/// Seçicinin varsayılan merkezi: Türkiye (ADR-0015 §4: cihaz konumu
/// istenmez; harita ülke düzeyinde bir varsayılanla açılır).
const LatLng turkiyeMerkezi = LatLng(lat: 39.0, lng: 35.0);

/// Varsayılan merkezin yakınlığı (bütün Türkiye görünür).
const double turkiyeYakinligi = 5;

/// Bir nokta seçilince ya da arama sonucuna gidilince kullanılan yakınlık.
const double noktaYakinligi = 15;

/// Seçicinin durumu: arama sonuçları ve seçilen nokta. Yalnızca bellekte;
/// aranan metin, sonuçlar ve nokta log'a yazılmaz.
@immutable
final class HaritaSecimi {
  const HaritaSecimi({
    this.nokta,
    this.oneri,
    this.sonuclar = const [],
    this.araniyor = false,
    this.arandi = false,
    this.hata = false,
    this.odak = 0,
  });

  /// Bırakılan iğnenin yeri; yoksa `null`.
  final LatLng? nokta;

  /// Noktanın seçildiği arama sonucu (ad, il, ilçe önerisi); iğne elle
  /// bırakıldıysa `null`.
  final YerSonucu? oneri;

  final List<YerSonucu> sonuclar;
  final bool araniyor;

  /// En az bir arama tamamlandı (boş sonuç mesajı için).
  final bool arandi;

  /// Son arama başarısız oldu.
  final bool hata;

  /// Bir arama sonucu seçildikçe artar; harita o noktadan yeniden açılır.
  final int odak;
}

/// Harita seçicisi (ADR-0015 §4): haritada iğne bırakma ve "Ara" ile ad
/// araması. Arama yalnızca [ara] çağrılınca (düğmeyle) yapılır; anlık
/// otomatik tamamlama yoktur. Aynı anda tek arama sürer; saniyede bir
/// istek sınırını arayıcı uygular.
class HaritaSecimiNotifier extends Notifier<HaritaSecimi> {
  HaritaSecimiNotifier(this.baslangic);

  /// Seçici açılırken taslaktaki nokta.
  final LatLng? baslangic;

  @override
  HaritaSecimi build() => HaritaSecimi(nokta: baslangic);

  /// İğneyi [nokta]'ya bırakır.
  void noktaBirak(LatLng nokta) {
    state = HaritaSecimi(
      nokta: nokta,
      sonuclar: state.sonuclar,
      araniyor: state.araniyor,
      arandi: state.arandi,
      hata: state.hata,
      odak: state.odak,
    );
  }

  /// Arama sonucunu seçer: iğne oraya gider, ad önerisi tutulur, sonuç
  /// listesi kapanır.
  void sonucSec(YerSonucu sonuc) {
    state = HaritaSecimi(
      nokta: LatLng(lat: sonuc.enlem, lng: sonuc.boylam),
      oneri: sonuc,
      arandi: state.arandi,
      odak: state.odak + 1,
    );
  }

  /// [metin]'i arar. Boş metin ya da süren arama varken bir şey yapmaz.
  Future<void> ara(String metin) async {
    if (state.araniyor || metin.trim().isEmpty) return;
    state = HaritaSecimi(
      nokta: state.nokta,
      oneri: state.oneri,
      sonuclar: state.sonuclar,
      araniyor: true,
      arandi: state.arandi,
      odak: state.odak,
    );
    try {
      final sonuclar = await ref.read(yerArayiciProvider).ara(metin);
      if (!ref.mounted) return;
      state = HaritaSecimi(
        nokta: state.nokta,
        oneri: state.oneri,
        sonuclar: sonuclar,
        arandi: true,
        odak: state.odak,
      );
    } on Exception {
      if (!ref.mounted) return;
      state = HaritaSecimi(
        nokta: state.nokta,
        oneri: state.oneri,
        arandi: true,
        hata: true,
        odak: state.odak,
      );
    }
  }
}

/// Seçicinin notifier'ı; seçici kapanınca bırakılır.
final haritaSecimiProvider = NotifierProvider.autoDispose
    .family<HaritaSecimiNotifier, HaritaSecimi, LatLng?>(
      HaritaSecimiNotifier.new,
      name: 'haritaSecimiProvider',
    );
