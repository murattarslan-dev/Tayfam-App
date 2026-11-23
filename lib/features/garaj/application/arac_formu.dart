import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/data/garaj_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart'
    show istekKimligiUreticisiProvider;

/// Sözleşmedeki sınırlar (`GarageVehicleRequest`; Tayfam-Api ADR-0040 §4).
const int garajMarkaEnCok = 40;
const int garajModelEnCok = 40;
const int garajRenkEnCok = 30;
const int garajNotEnCok = 200;
const int garajYiliEnAz = 1900;

/// Araçtaki en çok fotoğraf sayısı (sözleşme: `maxItems: 3`).
const int garajFotografEnCok = 3;

/// Metni sözleşmenin biçimine getirir: tek satır, boşluklar teke iner.
String garajMetniTemizle(String metin) =>
    metin.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Formdaki fotoğraf yerlerinden gönderilecek liste (boş yerler atlanır).
List<String> garajFotograflari(List<String?> yerler) => [
  for (final y in yerler) ?y,
];

/// [kimlikler]'i [garajFotografEnCok] yerlik listeye açar.
List<String?> garajFotografYerleri(List<String> kimlikler) => [
  for (var i = 0; i < garajFotografEnCok; i++)
    i < kimlikler.length ? kimlikler[i] : null,
];

/// Araç formunun hataları.
enum GarajFormHatasi {
  /// Marka boş ya da 40 karakteri aşıyor.
  marka,

  /// Model 40 karakteri aşıyor.
  model,

  /// Yıl sayı değil ya da 1900 – gelecek yıl dışında.
  yil,

  /// Renk 30 karakteri aşıyor.
  renk,

  /// Not 200 karakteri aşıyor.
  not,
}

/// Formun yazılı alanları (ekranın metin denetleyicilerinden).
typedef GarajFormAlanlari = ({
  String marka,
  String model,
  String yil,
  String renk,
  String not,
});

/// Doğrulanmış alanlar ya da hatalar. [buYil] yerel takvimdeki yıl; model
/// yılı en çok gelecek yıl olabilir. Boş isteğe bağlı alan `null` olur.
({
  ({String marka, String? model, int? yil, String? renk, String? not})? deger,
  Set<GarajFormHatasi> hatalar,
})
garajAlanlariniDogrula(GarajFormAlanlari alanlar, {required int buYil}) {
  final marka = garajMetniTemizle(alanlar.marka);
  final model = garajMetniTemizle(alanlar.model);
  final renk = garajMetniTemizle(alanlar.renk);
  final not = garajMetniTemizle(alanlar.not);
  final yilMetni = alanlar.yil.trim();
  final yil = yilMetni.isEmpty ? null : int.tryParse(yilMetni);
  final hatalar = {
    if (marka.isEmpty || marka.runes.length > garajMarkaEnCok)
      GarajFormHatasi.marka,
    if (model.runes.length > garajModelEnCok) GarajFormHatasi.model,
    if (yilMetni.isNotEmpty &&
        (yil == null || yil < garajYiliEnAz || yil > buYil + 1))
      GarajFormHatasi.yil,
    if (renk.runes.length > garajRenkEnCok) GarajFormHatasi.renk,
    if (not.runes.length > garajNotEnCok) GarajFormHatasi.not,
  };
  if (hatalar.isNotEmpty) return (deger: null, hatalar: hatalar);
  return (
    deger: (
      marka: marka,
      model: model.isEmpty ? null : model,
      yil: yil,
      renk: renk.isEmpty ? null : renk,
      not: not.isEmpty ? null : not,
    ),
    hatalar: const {},
  );
}

/// Araç formunun durumu.
@immutable
final class GarajFormuDurumu {
  const GarajFormuDurumu({
    required this.istekKimligi,
    required this.fotograflar,
    this.hatalar = const {},
    this.gonderiliyor = false,
    this.hata,
    this.tamamlandi = false,
    this.arac,
  });

  /// Form açılınca bir kez üretilen `client_request_id`; tekrar
  /// gönderimde aynı id gider (ADR-0005).
  final String istekKimligi;

  /// [garajFotografEnCok] fotoğraf yeri; boş yer `null`.
  final List<String?> fotograflar;

  /// Son gönderim denemesinde bulunan hatalar.
  final Set<GarajFormHatasi> hatalar;

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin sunucu hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıyla gönderildi; form kapanır.
  final bool tamamlandi;

  /// Başarıda eklenen ya da düzenlenen araç.
  final GarageVehicle? arac;

  GarajFormuDurumu _degistir({
    List<String?>? fotograflar,
    Set<GarajFormHatasi>? hatalar,
    bool gonderiliyor = false,
    Object? hata,
    bool tamamlandi = false,
    GarageVehicle? arac,
  }) => GarajFormuDurumu(
    istekKimligi: istekKimligi,
    fotograflar: fotograflar ?? this.fotograflar,
    hatalar: hatalar ?? this.hatalar,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlandi: tamamlandi,
    arac: arac,
  );
}

/// Garaj aracı ekleme (`POST /v1/me/garage`) ve düzenleme (`PUT …`) formu
/// (Tayfam-Api ADR-0040 §4): marka (zorunlu), model, yıl, renk, kısa not ve
/// 0–3 fotoğraf. Plaka alanı yoktur. Düzenleme tam yazmadır: kalan
/// fotoğraflar yeniden gönderilir, listede olmayan sunucuda silinir.
/// İstemcideki doğrulama kolaylıktır; son söz sunucunundur.
class GarajFormuNotifier extends Notifier<GarajFormuDurumu> {
  GarajFormuNotifier(this.duzenlenen);

  /// Düzenlenen araç; yenide `null`.
  final GarageVehicle? duzenlenen;

  @override
  GarajFormuDurumu build() => GarajFormuDurumu(
    istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
    fotograflar: List.unmodifiable(
      garajFotografYerleri(duzenlenen?.photoUploadIds ?? const []),
    ),
  );

  /// [sira]'daki fotoğraf yerini [uploadId] yapar (`null`: kaldır).
  void fotografAyarla(int sira, String? uploadId) {
    if (state.gonderiliyor) return;
    final yerler = [...state.fotograflar];
    yerler[sira] = uploadId;
    state = state._degistir(fotograflar: List.unmodifiable(yerler));
  }

  /// Formu gönderir. Sürerken ikinci çağrı yok sayılır. Başarıda garajlar
  /// sunucudan yeniden okunur.
  Future<void> gonder(GarajFormAlanlari alanlar) async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlandi) return;
    final buYil = ref.read(simdiProvider)().toLocal().year;
    final sonuc = garajAlanlariniDogrula(alanlar, buYil: buYil);
    final deger = sonuc.deger;
    if (deger == null) {
      state = mevcut._degistir(hatalar: sonuc.hatalar);
      return;
    }
    final fotograflar = garajFotograflari(mevcut.fotograflar);
    final depo = ref.read(garajDeposuProvider);
    final duzenlenen = this.duzenlenen;
    state = mevcut._degistir(gonderiliyor: true);
    try {
      final GarageVehicle arac;
      if (duzenlenen == null) {
        arac = await depo.ekle(
          GarageVehicleCreateRequest(
            make: deger.marka,
            model: deger.model,
            modelYear: deger.yil,
            color: deger.renk,
            note: deger.not,
            photoUploadIds: fotograflar.isEmpty ? null : fotograflar,
            clientRequestId: mevcut.istekKimligi,
          ),
        );
      } else {
        arac = await depo.duzenle(
          duzenlenen.id,
          GarageVehicleRequest(
            make: deger.marka,
            model: deger.model,
            modelYear: deger.yil,
            color: deger.renk,
            note: deger.not,
            photoUploadIds: fotograflar,
          ),
        );
      }
      if (!ref.mounted) return;
      garajlariTazele(ref);
      state = mevcut._degistir(tamamlandi: true, arac: arac);
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut._degistir(hata: hata);
    }
  }
}

/// Formun notifier'ı; form kapanınca bırakılır ve yeniden açılınca yeni
/// bir `client_request_id` üretilir. Anahtar düzenlenen araçtır (yenide
/// `null`).
final garajFormuProvider = NotifierProvider.autoDispose
    .family<GarajFormuNotifier, GarajFormuDurumu, GarageVehicle?>(
      GarajFormuNotifier.new,
      name: 'garajFormuProvider',
    );
