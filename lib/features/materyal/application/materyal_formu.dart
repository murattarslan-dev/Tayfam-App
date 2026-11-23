import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/data/materyal_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart'
    show istekKimligiUreticisiProvider;

/// Not fotoğrafında en çok fotoğraf sayısı (sözleşme: `maxItems: 3`).
const int materyalFotografEnCok = 3;

/// Başlığın en çok uzunluğu (sözleşme: 1–80 karakter, tek satır).
const int materyalBaslikEnCok = 80;

/// Başlığı sözleşmenin biçimine getirir: tek satır, boşluklar teke iner.
String baslikTemizle(String baslik) =>
    baslik.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Formdaki fotoğraf yerlerinden gönderilecek liste (boş yerler atlanır).
List<String> materyalFotograflari(List<String?> yerler) => [
  for (final y in yerler) ?y,
];

/// [kimlikler]'i [materyalFotografEnCok] yerlik listeye açar.
List<String?> materyalFotografYerleri(List<String> kimlikler) => [
  for (var i = 0; i < materyalFotografEnCok; i++)
    i < kimlikler.length ? kimlikler[i] : null,
];

/// Formun hataları.
enum MateryalFormHatasi {
  /// Başlık boş.
  baslikBos,

  /// Başlık 80 karakteri aşıyor.
  baslikUzun,

  /// Bağlantı türünde adres boş.
  baglantiBos,

  /// Adres `https` değil ya da biçimi uygun değil.
  baglantiGecersiz,

  /// Not fotoğrafı türünde fotoğraf yok.
  fotografYok,

  /// Ders seçilmedi ya da seçilen ders/konu artık seçilemiyor.
  ders,
}

/// Materyal formunun durumu.
@immutable
final class MateryalFormuDurumu {
  const MateryalFormuDurumu({
    required this.istekKimligi,
    required this.tur,
    required this.fotograflar,
    this.baslik = '',
    this.baglanti = '',
    this.secim,
    this.hatalar = const {},
    this.gonderiliyor = false,
    this.hata,
    this.tamamlandi = false,
    this.materyal,
  });

  /// Form açılınca bir kez üretilen `client_request_id`; tekrar
  /// gönderimde aynı id gider (ADR-0005).
  final String istekKimligi;

  /// `link` ya da `note_photo`; düzenlemede değişmez.
  final MaterialKind tur;

  final String baslik;

  /// Kullanıcının yazdığı adres (yalnızca bağlantıda).
  final String baglanti;

  /// [materyalFotografEnCok] fotoğraf yeri (yalnızca not fotoğrafında).
  final List<String?> fotograflar;

  /// Ders/konu seçimi.
  final DersKonuSecimi? secim;

  /// Son gönderim denemesinde bulunan hatalar.
  final Set<MateryalFormHatasi> hatalar;

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin sunucu hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıyla gönderildi; form kapanır.
  final bool tamamlandi;

  /// Başarıda eklenen ya da düzenlenen materyal.
  final Material? materyal;

  MateryalFormuDurumu _degistir({
    MaterialKind? tur,
    String? baslik,
    String? baglanti,
    List<String?>? fotograflar,
    DersKonuSecimi? Function()? secim,
    Set<MateryalFormHatasi>? hatalar,
    bool gonderiliyor = false,
    Object? hata,
    bool tamamlandi = false,
    Material? materyal,
  }) => MateryalFormuDurumu(
    istekKimligi: istekKimligi,
    tur: tur ?? this.tur,
    baslik: baslik ?? this.baslik,
    baglanti: baglanti ?? this.baglanti,
    fotograflar: fotograflar ?? this.fotograflar,
    secim: secim == null ? this.secim : secim(),
    hatalar: hatalar ?? this.hatalar,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlandi: tamamlandi,
    materyal: materyal,
  );
}

/// Formun anahtarı: tayfa ve düzenlenen materyal (yenide `null`).
typedef MateryalFormuAnahtari = ({String tayfaId, Material? duzenlenen});

/// Materyal ekleme (`POST …/materials`) ve düzenleme (`PUT …`) formu
/// (Tayfam-Api ADR-0040 §3): tür (bağlantı ya da not fotoğrafı; yalnızca
/// eklerken), başlık, `https` bağlantı ya da 1–3 not fotoğrafı, ders
/// (zorunlu) ve konu (isteğe bağlı). Düzenleme tam yazmadır: kalan
/// fotoğraflar yeniden gönderilir, listede olmayan sunucuda silinir.
/// İstemcideki doğrulama kolaylıktır; son söz sunucunundur.
class MateryalFormuNotifier extends Notifier<MateryalFormuDurumu> {
  MateryalFormuNotifier(this.anahtar);

  final MateryalFormuAnahtari anahtar;

  @override
  MateryalFormuDurumu build() {
    final d = anahtar.duzenlenen;
    return MateryalFormuDurumu(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      tur: d?.kind ?? MaterialKind.link,
      baslik: d?.title ?? '',
      baglanti: d?.url ?? '',
      fotograflar: List.unmodifiable(
        materyalFotografYerleri(d?.photoUploadIds ?? const []),
      ),
      secim: _eskiSecim,
    );
  }

  DersKonuSecimi? get _eskiSecim {
    final d = anahtar.duzenlenen;
    return d == null
        ? null
        : DersKonuSecimi(ders: d.subjectKey, konu: d.topicKey);
  }

  /// Türü değiştirir (yalnızca yeni materyalde).
  void turAyarla(MaterialKind tur) {
    if (state.gonderiliyor || anahtar.duzenlenen != null) return;
    if (tur == MaterialKind.unknown) return;
    state = state._degistir(
      tur: tur,
      hatalar: {
        for (final h in state.hatalar)
          if (h != MateryalFormHatasi.baglantiBos &&
              h != MateryalFormHatasi.baglantiGecersiz &&
              h != MateryalFormHatasi.fotografYok)
            h,
      },
    );
  }

  void baslikAyarla(String baslik) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      baslik: baslik,
      hatalar: {...state.hatalar}
        ..remove(MateryalFormHatasi.baslikBos)
        ..remove(MateryalFormHatasi.baslikUzun),
    );
  }

  void baglantiAyarla(String baglanti) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      baglanti: baglanti,
      hatalar: {...state.hatalar}
        ..remove(MateryalFormHatasi.baglantiBos)
        ..remove(MateryalFormHatasi.baglantiGecersiz),
    );
  }

  /// [sira]'daki fotoğraf yerini [uploadId] yapar (`null`: kaldır).
  void fotografAyarla(int sira, String? uploadId) {
    if (state.gonderiliyor) return;
    final yerler = [...state.fotograflar];
    yerler[sira] = uploadId;
    state = state._degistir(
      fotograflar: List.unmodifiable(yerler),
      hatalar: {...state.hatalar}..remove(MateryalFormHatasi.fotografYok),
    );
  }

  void secimAyarla(DersKonuSecimi? secim) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      secim: () => secim,
      hatalar: {...state.hatalar}..remove(MateryalFormHatasi.ders),
    );
  }

  /// Formu gönderir. Sürerken ikinci çağrı yok sayılır. Başarıda listeler
  /// ve detay sunucudan yeniden okunur.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlandi) return;
    final baslik = baslikTemizle(mevcut.baslik);
    final baglanti = mevcut.tur == MaterialKind.link
        ? baglantiyiTemizle(mevcut.baglanti)
        : null;
    final fotograflar = mevcut.tur == MaterialKind.notePhoto
        ? materyalFotograflari(mevcut.fotograflar)
        : const <String>[];
    final secim = mevcut.secim;
    // Değişmeyen (emekli olmuş olabilir) seçim yeniden doğrulanmaz;
    // katalog yoksa karar sunucunundur.
    final secimDegisti = secim != _eskiSecim;
    final agac = ref.read(katalogProvider).value?.dersKonu;
    final dersGecerli =
        secim != null && (!secimDegisti || agac == null || agac.gecerli(secim));
    final hatalar = {
      if (baslik.isEmpty) MateryalFormHatasi.baslikBos,
      if (baslik.runes.length > materyalBaslikEnCok)
        MateryalFormHatasi.baslikUzun,
      if (mevcut.tur == MaterialKind.link && mevcut.baglanti.trim().isEmpty)
        MateryalFormHatasi.baglantiBos
      else if (mevcut.tur == MaterialKind.link && baglanti == null)
        MateryalFormHatasi.baglantiGecersiz,
      if (mevcut.tur == MaterialKind.notePhoto && fotograflar.isEmpty)
        MateryalFormHatasi.fotografYok,
      if (!dersGecerli) MateryalFormHatasi.ders,
    };
    if (hatalar.isNotEmpty ||
        secim == null ||
        mevcut.tur == MaterialKind.unknown) {
      state = mevcut._degistir(hatalar: hatalar);
      return;
    }
    final depo = ref.read(materyalDeposuProvider);
    final duzenlenen = anahtar.duzenlenen;
    state = mevcut._degistir(gonderiliyor: true);
    try {
      final Material sonuc;
      if (duzenlenen == null) {
        sonuc = await depo.ekle(
          anahtar.tayfaId,
          MaterialCreateRequest(
            kind: mevcut.tur == MaterialKind.link
                ? MaterialCreateRequestKind.link
                : MaterialCreateRequestKind.notePhoto,
            title: baslik,
            url: baglanti,
            photoUploadIds: fotograflar.isEmpty ? null : fotograflar,
            subjectKey: secim.ders,
            topicKey: secim.konu,
            clientRequestId: mevcut.istekKimligi,
          ),
        );
      } else {
        sonuc = await depo.duzenle(
          anahtar.tayfaId,
          duzenlenen.id,
          MaterialUpdateRequest(
            title: baslik,
            url: baglanti,
            photoUploadIds: mevcut.tur == MaterialKind.notePhoto
                ? fotograflar
                : null,
            subjectKey: secim.ders,
            topicKey: secim.konu,
          ),
        );
      }
      if (!ref.mounted) return;
      materyalleriTazele(ref);
      state = mevcut._degistir(tamamlandi: true, materyal: sonuc);
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
/// bir `client_request_id` üretilir.
final materyalFormuProvider = NotifierProvider.autoDispose
    .family<MateryalFormuNotifier, MateryalFormuDurumu, MateryalFormuAnahtari>(
      MateryalFormuNotifier.new,
      name: 'materyalFormuProvider',
    );
