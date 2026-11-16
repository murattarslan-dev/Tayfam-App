import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/yer_arama.dart';
import 'package:tayfam/core/konum/konum_servisi.dart';

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
    this.konumAraniyor = false,
    this.konumEngeli,
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

  /// Bir arama sonucu seçildikçe ya da "Bulunduğum yer" okununca artar;
  /// harita o noktadan yeniden açılır.
  final int odak;

  /// "Bulunduğum yer" için konum okunuyor.
  final bool konumAraniyor;

  /// Son "Bulunduğum yer" denemesi neden konum vermedi (izin yok, servis
  /// kapalı, okunamadı); yoksa `null`.
  final KonumSonucu? konumEngeli;

  HaritaSecimi _ile({
    LatLng? nokta,
    YerSonucu? oneri,
    bool oneriSil = false,
    List<YerSonucu>? sonuclar,
    bool? araniyor,
    bool? arandi,
    bool? hata,
    int? odak,
    bool konumAraniyor = false,
    KonumSonucu? konumEngeli,
  }) => HaritaSecimi(
    nokta: nokta ?? this.nokta,
    oneri: oneriSil ? null : (oneri ?? this.oneri),
    sonuclar: sonuclar ?? this.sonuclar,
    araniyor: araniyor ?? this.araniyor,
    arandi: arandi ?? this.arandi,
    hata: hata ?? this.hata,
    odak: odak ?? this.odak,
    konumAraniyor: konumAraniyor,
    konumEngeli: konumEngeli,
  );
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

  /// "Bulunduğum yer" (yalnızca sohbetteki seçici; istemci ADR-0028 §5):
  /// konum izni **yalnızca burada** istenir ve konum bir kez okunur
  /// (yaklaşık konum da kabul). Okunursa iğne oraya bırakılır ve harita
  /// oraya gider; okunmazsa neden [HaritaSecimi.konumEngeli]'nde durur.
  /// Konum bu durumun dışında hiçbir yere yazılmaz ve loglanmaz.
  Future<void> konumaGit() async {
    if (state.konumAraniyor) return;
    state = state._ile(konumAraniyor: true);
    final sonuc = await ref
        .read(konumServisiProvider)
        .tekSeferlikKonum(hassas: false);
    if (!ref.mounted) return;
    switch (sonuc) {
      case KonumAlindi(:final nokta):
        state = HaritaSecimi(
          nokta: LatLng(
            lat: double.parse(nokta.lat.toStringAsFixed(6)),
            lng: double.parse(nokta.lng.toStringAsFixed(6)),
          ),
          arandi: state.arandi,
          odak: state.odak + 1,
        );
      default:
        state = state._ile(konumEngeli: sonuc);
    }
  }

  /// İzin ya da konum ayarlarını açar ([konumaGit]'in engeline göre).
  Future<bool> ayarlariAc() {
    final servis = ref.read(konumServisiProvider);
    return state.konumEngeli is KonumServisiKapali
        ? servis.konumAyarlariniAc()
        : servis.uygulamaAyarlariniAc();
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
