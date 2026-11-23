import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/garaj/data/garaj_deposu.dart';

/// Ana sayfadaki garaj kartında gösterilen araç sayısı.
const int kartAracSayisi = 3;

/// Garajdaki en çok araç sayısı (sözleşme: kişi başına 10).
const int garajEnCok = 10;

/// Kendi garajın (`GET /v1/me/garage`; Tayfam-Api ADR-0040 §4). Kullanıcıya
/// bağlıdır: oturum değişince yeniden kurulur; yalnızca bellektedir
/// (ADR-0006).
class GarajimNotifier extends AsyncNotifier<MemberGarage> {
  @override
  Future<MemberGarage> build() {
    ref.watch(oturumDurumuProvider);
    return ref.watch(garajDeposuProvider).garajim();
  }
}

/// Kendi garajın; profildeki Garajım ekranı ve araçlar bileşeninin
/// "Garajımdan seç" listesi paylaşır. Hata otomatik yeniden denenmez.
final garajimProvider =
    AsyncNotifierProvider.autoDispose<GarajimNotifier, MemberGarage>(
      GarajimNotifier.new,
      name: 'garajimProvider',
      retry: _yenidenDenemeYok,
    );

/// Bir tayfanın garajı (`GET /v1/tayfas/{tayfa_id}/garage`, sayfalı): bu
/// tayfada görünen araçlar, en yeni önce. Tayfaya bağlıdır: `family` +
/// `autoDispose`; oturum değişince yeniden kurulur.
class TayfaGarajiNotifier extends SayfaliListeNotifier<GarageVehicle> {
  TayfaGarajiNotifier(this.tayfaId);

  final String tayfaId;

  bool _gorunur = false;

  /// Sunucunun son ilk sayfada söylediği `caller_visible`: çağıranın
  /// garajı bu tayfada görünüyor mu. Liste durumu değişmeden önce yazılır.
  bool get gorunur => _gorunur;

  @override
  Future<SayfaliListe<GarageVehicle>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(garajDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<GarageVehicle>> sayfaGetir(String? sayfaToken) async {
    final sonuc = await ref
        .read(garajDeposuProvider)
        .tayfaGaraji(tayfaId, sayfaToken: sayfaToken);
    if (sayfaToken == null) _gorunur = sonuc.gorunur;
    return sonuc.sayfa;
  }

  @override
  String kimlik(GarageVehicle oge) => oge.id;
}

/// Bir tayfanın garajı; ana sayfa kartı ve liste ekranı paylaşır.
final tayfaGarajiProvider = AsyncNotifierProvider.autoDispose
    .family<TayfaGarajiNotifier, SayfaliListe<GarageVehicle>, String>(
      TayfaGarajiNotifier.new,
      name: 'tayfaGarajiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Yazma sonrasında garajlar sunucudan yeniden okunur: istemci yerel kopya
/// kurmaz (App ADR-0033 §4).
void garajlariTazele(Ref ref) => ref
  ..invalidate(garajimProvider)
  ..invalidate(tayfaGarajiProvider);

/// Garaj işlemleri; durum tutmaz. Yetkiyi sunucu verir (kesin kural 5).
final class GarajIslemleri {
  GarajIslemleri(this._ref);

  final Ref _ref;

  /// Kendi aracını siler; fotoğrafları da silinir, geri alınamaz.
  Future<void> sil(String aracId) async {
    await _ref.read(garajDeposuProvider).sil(aracId);
    garajlariTazele(_ref);
  }

  /// Aracı tayfanın garajından kaldırır (moderatör); geri alınamaz.
  Future<void> kaldir(String tayfaId, String aracId) async {
    await _ref.read(garajDeposuProvider).kaldir(tayfaId, aracId);
    _ref.invalidate(tayfaGarajiProvider(tayfaId));
  }

  /// Garajını [tayfaId]'de gösterir ya da gizler.
  Future<void> gorunurlukAyarla(String tayfaId, {required bool gorunur}) async {
    await _ref
        .read(garajDeposuProvider)
        .gorunurlukAyarla(tayfaId, gorunur: gorunur);
    _ref.invalidate(tayfaGarajiProvider(tayfaId));
  }
}

/// Garaj işlemleri.
final garajIslemleriProvider = Provider<GarajIslemleri>(
  GarajIslemleri.new,
  name: 'garajIslemleriProvider',
);

/// Aracın adı: marka ve (varsa) model.
String aracAdi(GarageVehicle arac) => [
  arac.make,
  if (arac.model case final model? when model.isNotEmpty) model,
].join(' ');
