import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/soru_cevap/application/etiketler_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_notifier.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Soru başlığının en az uzunluğu (sözleşme: boşluklar atıldıktan sonra
/// 10–150 karakter, tek satır).
const int soruBasligiEnAz = 10;

/// Soru başlığının en çok uzunluğu.
const int soruBasligiEnCok = 150;

/// Soru ve cevap gövdesinin en çok uzunluğu (sözleşme: 10000).
const int soruCevapGovdesiEnCok = 10000;

/// Bir sorudaki en çok etiket sayısı (sözleşme: `maxItems: 5`).
const int soruEtiketiEnCokSayi = 5;

/// Bir etiketin en çok uzunluğu (sözleşme: 1–30 karakter).
const int etiketEnCok = 30;

/// [baslik] boşluklar atıldıktan sonra 10–150 karakter ve tek satır mı.
bool soruBasligiGecerli(String baslik) {
  final kirpik = baslik.trim();
  final uzunluk = kirpik.runes.length;
  return uzunluk >= soruBasligiEnAz &&
      uzunluk <= soruBasligiEnCok &&
      !kirpik.contains('\n') &&
      !kirpik.contains('\r');
}

/// [govde] boşluklar atıldıktan sonra en çok 10000 karakter mi.
bool soruGovdesiGecerli(String govde) =>
    govde.trim().runes.length <= soruCevapGovdesiEnCok;

/// Etiket adını sözleşmenin biçimine getirir: baştaki ve sondaki boşluklar
/// atılır, içteki boşluklar (satır sonu dahil) teke iner.
String etiketiNormalle(String ad) => ad.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Etiket eklenemediğinde nedeni.
enum EtiketHatasi {
  /// 30 karakterden uzun.
  cokUzun,

  /// Soruda zaten beş etiket var.
  cokFazla,
}

/// Soru formunun anahtarı: tayfa ve düzenlenen soru (yeni soruda `null`).
typedef SoruFormuAnahtari = ({String tayfaId, Question? duzenlenen});

/// Soru sorma ve düzenleme formunun durumu (ADR-0018 §4).
@immutable
final class SoruFormuDurumu {
  const SoruFormuDurumu({
    required this.istekKimligi,
    this.baslik = '',
    this.govde = '',
    this.etiketler = const [],
    this.baslikHatali = false,
    this.govdeHatali = false,
    this.etiketHatasi,
    this.gonderiliyor = false,
    this.hata,
    this.tamamlanan,
  });

  /// Form açılınca bir kez üretilen `client_request_id`; aynı soru tekrar
  /// gönderilirken aynı id kullanılır (ADR-0005).
  final String istekKimligi;

  final String baslik;

  final String govde;

  /// Eklenen etiket adları, girildiği sırayla.
  final List<String> etiketler;

  /// Gönderimde başlık geçersizdi.
  final bool baslikHatali;

  /// Gönderimde gövde geçersizdi.
  final bool govdeHatali;

  /// Son etiket eklemesinin hatası.
  final EtiketHatasi? etiketHatasi;

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıda sorulan ya da düzenlenen soru.
  final Question? tamamlanan;

  /// Başka etiket eklenebilir mi.
  bool get etiketEklenebilir => etiketler.length < soruEtiketiEnCokSayi;

  SoruFormuDurumu _degistir({
    String? baslik,
    String? govde,
    List<String>? etiketler,
    bool? baslikHatali,
    bool? govdeHatali,
    EtiketHatasi? etiketHatasi,
    bool gonderiliyor = false,
    Object? hata,
    Question? tamamlanan,
  }) => SoruFormuDurumu(
    istekKimligi: istekKimligi,
    baslik: baslik ?? this.baslik,
    govde: govde ?? this.govde,
    etiketler: etiketler ?? this.etiketler,
    baslikHatali: baslikHatali ?? this.baslikHatali,
    govdeHatali: govdeHatali ?? this.govdeHatali,
    etiketHatasi: etiketHatasi,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlanan: tamamlanan,
  );
}

/// Soru sorma (`POST …/questions`) ve düzenleme (`PATCH …`) formu.
///
/// `client_request_id` form açılınca bir kez üretilir; gönderim tekrar
/// denenirse aynı id gider ve ikinci soru açılmaz. Bağlantı yoksa form açık
/// kalır, girilenler korunur. Etiketler adla gönderilir; aynı etiket (Türkçe
/// büyük-küçük harf farkı gözetilmeden) iki kez eklenmez.
class SoruFormuNotifier extends Notifier<SoruFormuDurumu> {
  SoruFormuNotifier(this.anahtar);

  /// Tayfa ve düzenlenen soru.
  final SoruFormuAnahtari anahtar;

  @override
  SoruFormuDurumu build() {
    final duzenlenen = anahtar.duzenlenen;
    return SoruFormuDurumu(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      baslik: duzenlenen?.title ?? '',
      govde: duzenlenen?.body ?? '',
      etiketler: [for (final e in duzenlenen?.tags ?? const <Tag>[]) e.name],
    );
  }

  /// Başlığı günceller; geçerli olunca başlık hatası kalkar.
  void baslikAyarla(String baslik) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      baslik: baslik,
      baslikHatali: state.baslikHatali && !soruBasligiGecerli(baslik),
      etiketHatasi: state.etiketHatasi,
    );
  }

  /// Gövdeyi günceller; geçerli olunca gövde hatası kalkar.
  void govdeAyarla(String govde) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      govde: govde,
      govdeHatali: state.govdeHatali && !soruGovdesiGecerli(govde),
      etiketHatasi: state.etiketHatasi,
    );
  }

  /// [ad]'ı etiket olarak ekler. Eklendiyse ya da zaten varsa `true` döner
  /// (giriş kutusu temizlenir); boşsa, çok uzunsa ya da beş etiket varsa
  /// `false` döner ve gerekirse [SoruFormuDurumu.etiketHatasi] dolar.
  bool etiketEkle(String ad) {
    if (state.gonderiliyor) return false;
    final etiket = etiketiNormalle(ad);
    if (etiket.isEmpty) return false;
    final anahtar = turkceKucukHarf(etiket);
    if (state.etiketler.any((e) => turkceKucukHarf(e) == anahtar)) {
      state = state._degistir();
      return true;
    }
    if (etiket.runes.length > etiketEnCok) {
      state = state._degistir(etiketHatasi: EtiketHatasi.cokUzun);
      return false;
    }
    if (!state.etiketEklenebilir) {
      state = state._degistir(etiketHatasi: EtiketHatasi.cokFazla);
      return false;
    }
    state = state._degistir(etiketler: [...state.etiketler, etiket]);
    return true;
  }

  /// [ad] etiketini kaldırır.
  void etiketCikar(String ad) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      etiketler: [
        for (final e in state.etiketler)
          if (e != ad) e,
      ],
    );
  }

  /// Soruyu sorar ya da değişiklikleri kaydeder. Sürerken ikinci çağrı yok
  /// sayılır. Düzenlemede yalnızca değişen alanlar gönderilir; değişiklik
  /// yoksa istek gitmez.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlanan != null) return;
    final baslikGecerli = soruBasligiGecerli(mevcut.baslik);
    final govdeGecerli = soruGovdesiGecerli(mevcut.govde);
    if (!baslikGecerli || !govdeGecerli) {
      state = mevcut._degistir(
        baslikHatali: !baslikGecerli,
        govdeHatali: !govdeGecerli,
      );
      return;
    }
    final baslik = mevcut.baslik.trim();
    final govde = mevcut.govde.trim();
    final etiketler = mevcut.etiketler;
    final duzenlenen = anahtar.duzenlenen;
    final eskiEtiketler = [
      for (final e in duzenlenen?.tags ?? const <Tag>[]) e.name,
    ];
    final etiketDegisti = !listEquals(etiketler, eskiEtiketler);
    if (duzenlenen != null &&
        baslik == duzenlenen.title &&
        govde == duzenlenen.body &&
        !etiketDegisti) {
      state = mevcut._degistir(tamamlanan: duzenlenen);
      return;
    }
    state = mevcut._degistir(gonderiliyor: true);
    final depo = ref.read(soruCevapDeposuProvider);
    final Question soru;
    try {
      soru = duzenlenen == null
          ? await depo.soruSor(
              anahtar.tayfaId,
              QuestionCreateRequest(
                title: baslik,
                body: govde.isEmpty ? null : govde,
                tags: etiketler.isEmpty ? null : etiketler,
                clientRequestId: mevcut.istekKimligi,
              ),
            )
          : await depo.soruDuzenle(
              anahtar.tayfaId,
              duzenlenen.id,
              QuestionUpdateRequest(
                title: baslik == duzenlenen.title ? null : baslik,
                body: govde == duzenlenen.body ? null : govde,
                tags: etiketDegisti ? etiketler : null,
              ),
            );
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut._degistir(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    if (duzenlenen == null) {
      soruyuEkle(ref, anahtar.tayfaId, soru);
    } else {
      soruyuYansit(ref, anahtar.tayfaId, soru);
    }
    // Yeni etiket açılmış ya da sayılar değişmiş olabilir.
    final etiketListesi = etiketlerProvider(anahtar.tayfaId);
    if (ref.read(etiketListesi.exists)) ref.invalidate(etiketListesi);
    state = mevcut._degistir(tamamlanan: soru);
  }
}

/// Soru formunun notifier'ı; form kapanınca bırakılır ve yeniden açılınca
/// yeni bir `client_request_id` üretilir.
final soruFormuProvider = NotifierProvider.autoDispose
    .family<SoruFormuNotifier, SoruFormuDurumu, SoruFormuAnahtari>(
      SoruFormuNotifier.new,
      name: 'soruFormuProvider',
    );
