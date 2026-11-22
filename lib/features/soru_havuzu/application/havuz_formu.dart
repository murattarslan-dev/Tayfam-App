import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_listesi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Soru ve cevaptaki en çok fotoğraf sayısı (sözleşme: `maxItems: 2`).
const int havuzFotografEnCok = 2;

/// Formdaki fotoğraf yerleri: her yer boş (`null`) ya da hazır bir
/// `question_pool` yüklemesinin kimliğidir. Gönderilen liste boş
/// olmayanların sırasıdır.
List<String> fotografListesi(List<String?> yerler) => [
  for (final y in yerler) ?y,
];

/// [kimlikler]'i [havuzFotografEnCok] yerlik listeye açar.
List<String?> fotografYerleri(List<String> kimlikler) => [
  for (var i = 0; i < havuzFotografEnCok; i++)
    i < kimlikler.length ? kimlikler[i] : null,
];

/// Metnin geçerli olup olmadığı: boşluklar atıldıktan sonra en çok 10000
/// karakter.
bool havuzMetniGecerli(String metin) =>
    metin.trim().runes.length <= soruCevapGovdesiEnCok;

/// Havuzdaki bir soru ya da cevabın içeriği var mı: metin ve/veya en az
/// bir fotoğraf (Tayfam-Api ADR-0040 §2).
bool havuzIcerigiVar(String metin, List<String?> yerler) =>
    metin.trim().isNotEmpty || fotografListesi(yerler).isNotEmpty;

/// Formun ortak hataları.
enum HavuzFormHatasi {
  /// Ders seçilmedi ya da seçilen ders/konu artık seçilemiyor.
  ders,

  /// Ne metin ne fotoğraf var.
  icerikYok,

  /// Metin 10000 karakteri aşıyor.
  metinUzun,
}

/// Soru havuzu formunun (soru ya da cevap) durumu.
@immutable
final class HavuzFormuDurumu {
  const HavuzFormuDurumu({
    required this.istekKimligi,
    required this.fotograflar,
    this.secim,
    this.metin = '',
    this.hatalar = const {},
    this.gonderiliyor = false,
    this.hata,
    this.tamamlandi = false,
    this.soru,
  });

  /// Form açılınca bir kez üretilen `client_request_id`; tekrar
  /// gönderimde aynı id gider (ADR-0005).
  final String istekKimligi;

  /// Ders/konu seçimi (yalnızca soru formunda).
  final DersKonuSecimi? secim;

  final String metin;

  /// [havuzFotografEnCok] fotoğraf yeri.
  final List<String?> fotograflar;

  /// Son gönderim denemesinde bulunan hatalar.
  final Set<HavuzFormHatasi> hatalar;

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin sunucu hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıyla gönderildi (ya da değişiklik yoktu); form kapanır.
  final bool tamamlandi;

  /// Soru formunda başarıda sorulan ya da düzenlenen soru.
  final Question? soru;

  HavuzFormuDurumu _degistir({
    DersKonuSecimi? Function()? secim,
    String? metin,
    List<String?>? fotograflar,
    Set<HavuzFormHatasi>? hatalar,
    bool gonderiliyor = false,
    Object? hata,
    bool tamamlandi = false,
    Question? soru,
  }) => HavuzFormuDurumu(
    istekKimligi: istekKimligi,
    secim: secim == null ? this.secim : secim(),
    metin: metin ?? this.metin,
    fotograflar: fotograflar ?? this.fotograflar,
    hatalar: hatalar ?? this.hatalar,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlandi: tamamlandi,
    soru: soru,
  );
}

/// Formun ortak düzenleme adımları.
mixin _HavuzFormu on Notifier<HavuzFormuDurumu> {
  /// Metni günceller.
  void metinAyarla(String metin) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      metin: metin,
      hatalar: _hatalarDustu(metin: metin),
    );
  }

  /// [sira]'daki fotoğraf yerini [uploadId] yapar (`null`: kaldır).
  void fotografAyarla(int sira, String? uploadId) {
    if (state.gonderiliyor) return;
    final yerler = [...state.fotograflar];
    yerler[sira] = uploadId;
    state = state._degistir(
      fotograflar: List.unmodifiable(yerler),
      hatalar: _hatalarDustu(fotograflar: yerler),
    );
  }

  /// Giderilen hatalar listeden düşer; yenisi ancak gönderimde eklenir.
  Set<HavuzFormHatasi> _hatalarDustu({
    String? metin,
    List<String?>? fotograflar,
  }) {
    final m = metin ?? state.metin;
    final f = fotograflar ?? state.fotograflar;
    return {
      for (final h in state.hatalar)
        if (switch (h) {
          HavuzFormHatasi.icerikYok => !havuzIcerigiVar(m, f),
          HavuzFormHatasi.metinUzun => !havuzMetniGecerli(m),
          HavuzFormHatasi.ders => true,
        })
          h,
    };
  }

  /// Gönderimdeki ortak hatalar (ders hariç).
  Set<HavuzFormHatasi> _icerikHatalari() => {
    if (!havuzIcerigiVar(state.metin, state.fotograflar))
      HavuzFormHatasi.icerikYok,
    if (!havuzMetniGecerli(state.metin)) HavuzFormHatasi.metinUzun,
  };

  /// [istek]'i gönderir; oturum düştüyse girişe döner, hata formda kalır.
  Future<T?> _gonder<T>(Future<T> Function() istek) async {
    final mevcut = state;
    state = mevcut._degistir(gonderiliyor: true);
    try {
      return await istek();
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut._degistir(hata: hata);
      return null;
    }
  }
}

/// Soru formunun anahtarı: tayfa ve düzenlenen soru (yeni soruda `null`).
typedef HavuzSoruFormuAnahtari = ({String tayfaId, Question? duzenlenen});

/// Soru havuzuna soru sorma (`POST …/questions`, `pool: question_pool`) ve
/// düzenleme (`PATCH …`) formu (Tayfam-Api ADR-0040 §2).
///
/// Başlık ve etiket yoktur; ders zorunlu, konu isteğe bağlıdır; metin
/// ve/veya en çok iki fotoğraf. Düzenlemede yalnızca değişen alanlar
/// gider: ders/konu birlikte, fotoğraflar listenin yeni haliyle. Ders/konu
/// doğrulaması istemcide kolaylıktır; son söz sunucunundur.
class HavuzSoruFormuNotifier extends Notifier<HavuzFormuDurumu>
    with _HavuzFormu {
  HavuzSoruFormuNotifier(this.anahtar);

  final HavuzSoruFormuAnahtari anahtar;

  @override
  HavuzFormuDurumu build() {
    final d = anahtar.duzenlenen;
    final ders = d?.subjectKey;
    return HavuzFormuDurumu(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      secim: ders == null
          ? null
          : DersKonuSecimi(ders: ders, konu: d?.topicKey),
      metin: d?.body ?? '',
      fotograflar: List.unmodifiable(
        fotografYerleri(d?.photoUploadIds ?? const []),
      ),
    );
  }

  /// Ders/konu seçimini günceller.
  void secimAyarla(DersKonuSecimi? secim) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      secim: () => secim,
      hatalar: {...state.hatalar}..remove(HavuzFormHatasi.ders),
    );
  }

  DersKonuSecimi? get _eskiSecim {
    final d = anahtar.duzenlenen;
    final ders = d?.subjectKey;
    return ders == null ? null : DersKonuSecimi(ders: ders, konu: d?.topicKey);
  }

  /// Soruyu sorar ya da değişiklikleri kaydeder. Sürerken ikinci çağrı yok
  /// sayılır; düzenlemede değişiklik yoksa istek gitmez. Başarıda soru
  /// açık listelere ve detaya yansır.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlandi) return;
    final secim = mevcut.secim;
    final secimDegisti = secim != _eskiSecim;
    // Değişmeyen (emekli olmuş olabilir) seçim yeniden doğrulanmaz;
    // katalog yoksa karar sunucunundur.
    final agac = ref.read(katalogProvider).value?.dersKonu;
    final dersGecerli =
        secim != null && (!secimDegisti || agac == null || agac.gecerli(secim));
    final hatalar = {
      ..._icerikHatalari(),
      if (!dersGecerli) HavuzFormHatasi.ders,
    };
    if (hatalar.isNotEmpty || secim == null) {
      state = mevcut._degistir(hatalar: hatalar);
      return;
    }
    final metin = mevcut.metin.trim();
    final fotograflar = fotografListesi(mevcut.fotograflar);
    final duzenlenen = anahtar.duzenlenen;
    final depo = ref.read(soruCevapDeposuProvider);
    if (duzenlenen == null) {
      final soru = await _gonder<Question>(
        () => depo.soruSor(
          anahtar.tayfaId,
          QuestionCreateRequest(
            pool: QuestionPool.questionPool,
            subjectKey: secim.ders,
            topicKey: secim.konu,
            body: metin.isEmpty ? null : metin,
            photoUploadIds: fotograflar.isEmpty ? null : fotograflar,
            clientRequestId: mevcut.istekKimligi,
          ),
        ),
      );
      if (soru == null || !ref.mounted) return;
      havuzSorusunuEkle(ref, soru);
      state = mevcut._degistir(tamamlandi: true, soru: soru);
      return;
    }
    final metinDegisti = metin != duzenlenen.body;
    final fotografDegisti = !listEquals(fotograflar, duzenlenen.photoUploadIds);
    if (!metinDegisti && !secimDegisti && !fotografDegisti) {
      state = mevcut._degistir(tamamlandi: true, soru: duzenlenen);
      return;
    }
    final soru = await _gonder<Question>(
      () => depo.soruDuzenle(
        anahtar.tayfaId,
        duzenlenen.id,
        QuestionUpdateRequest(
          body: metinDegisti ? metin : null,
          subjectKey: secimDegisti ? secim.ders : null,
          topicKey: secimDegisti ? secim.konu : null,
          photoUploadIds: fotografDegisti ? fotograflar : null,
        ),
      ),
    );
    if (soru == null || !ref.mounted) return;
    soruyuYansit(ref, anahtar.tayfaId, soru);
    havuzListelerineUygula(ref, anahtar.tayfaId, (l) => l.guncelle(soru));
    state = mevcut._degistir(tamamlandi: true, soru: soru);
  }
}

/// Soru formunun notifier'ı; form kapanınca bırakılır ve yeniden açılınca
/// yeni bir `client_request_id` üretilir.
final havuzSoruFormuProvider = NotifierProvider.autoDispose
    .family<HavuzSoruFormuNotifier, HavuzFormuDurumu, HavuzSoruFormuAnahtari>(
      HavuzSoruFormuNotifier.new,
      name: 'havuzSoruFormuProvider',
    );

/// Cevap formunun anahtarı: tayfa, soru ve düzenlenen cevap.
typedef HavuzCevapFormuAnahtari = ({
  String tayfaId,
  String soruId,
  Answer? duzenlenen,
});

/// Havuz sorusuna cevap yazma (`POST …/answers`) ve düzenleme (`PATCH
/// …/answers/{id}`) formu: metin ve/veya en çok iki fotoğraf.
///
/// Düzenleme isteği cevabın yeni halidir: fotoğraf alanı verilmezse
/// sunucu fotoğrafları kaldırır, bu yüzden kalan fotoğraflar her zaman
/// yeniden gönderilir.
class HavuzCevapFormuNotifier extends Notifier<HavuzFormuDurumu>
    with _HavuzFormu {
  HavuzCevapFormuNotifier(this.anahtar);

  final HavuzCevapFormuAnahtari anahtar;

  @override
  HavuzFormuDurumu build() {
    final d = anahtar.duzenlenen;
    return HavuzFormuDurumu(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      metin: d?.body ?? '',
      fotograflar: List.unmodifiable(
        fotografYerleri(d?.photoUploadIds ?? const []),
      ),
    );
  }

  /// Cevabı gönderir ya da değişikliği kaydeder.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlandi) return;
    final hatalar = _icerikHatalari();
    if (hatalar.isNotEmpty) {
      state = mevcut._degistir(hatalar: hatalar);
      return;
    }
    final metin = mevcut.metin.trim();
    final fotograflar = fotografListesi(mevcut.fotograflar);
    final duzenlenen = anahtar.duzenlenen;
    if (duzenlenen != null &&
        metin == duzenlenen.body &&
        listEquals(fotograflar, duzenlenen.photoUploadIds)) {
      state = mevcut._degistir(tamamlandi: true);
      return;
    }
    final depo = ref.read(soruCevapDeposuProvider);
    final cevap = await _gonder<Answer>(
      () => duzenlenen == null
          ? depo.cevapla(
              anahtar.tayfaId,
              anahtar.soruId,
              AnswerCreateRequest(
                body: metin,
                clientRequestId: mevcut.istekKimligi,
                photoUploadIds: fotograflar.isEmpty ? null : fotograflar,
              ),
            )
          : depo.cevapDuzenle(
              anahtar.tayfaId,
              duzenlenen.id,
              AnswerUpdateRequest(body: metin, photoUploadIds: fotograflar),
            ),
    );
    if (cevap == null || !ref.mounted) return;
    cevabiYansit(
      ref,
      (tayfaId: anahtar.tayfaId, soruId: anahtar.soruId),
      cevap,
      yeni: duzenlenen == null,
    );
    state = mevcut._degistir(tamamlandi: true);
  }
}

/// Cevap formunun notifier'ı; form kapanınca bırakılır.
final havuzCevapFormuProvider = NotifierProvider.autoDispose
    .family<HavuzCevapFormuNotifier, HavuzFormuDurumu, HavuzCevapFormuAnahtari>(
      HavuzCevapFormuNotifier.new,
      name: 'havuzCevapFormuProvider',
    );
