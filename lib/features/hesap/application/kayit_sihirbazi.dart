import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/application/kayit_notifier.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';

/// Kayıt sihirbazının adımları ("Tayfam'la tanışma"; ADR-0012 §3). Her
/// adım tek soru sorar; gönderim yalnızca son adımda yapılır.
enum KayitAdimi {
  /// Görünen ad (Google adıyla dolu).
  ad,

  /// Doğum tarihi (teyit penceresiyle).
  dogumTarihi,

  /// İsteğe bağlı referans kodu.
  referans,

  /// Aydınlatma metni ve kullanım koşulları onayları.
  onaylar,
}

/// Sihirbazdaki adım sayısı (ilerleme göstergesi: "Adım N / 4").
final int kayitAdimSayisi = KayitAdimi.values.length;

/// Sihirbazın taslağı: girilenler ve bulunulan adım. Yalnızca bellektedir;
/// `toString` içerik yazmaz (ad, doğum tarihi ve referans kodu kişisel
/// veridir; CLAUDE.md kesin kural 3).
@immutable
final class KayitTaslagi {
  const KayitTaslagi({
    this.adim = KayitAdimi.ad,
    this.ad = '',
    this.dogumTarihi,
    this.referansKodu = '',
    this.referansAtlandi = false,
    this.aydinlatma = false,
    this.kosullar = false,
    this.hatalar = const {},
  });

  /// Bulunulan adım.
  final KayitAdimi adim;

  /// Girilen ad (baştaki ve sondaki boşluklar gönderimde atılır).
  final String ad;

  /// Seçilen doğum tarihi (yalnızca gün); seçilmediyse `null`.
  final DateTime? dogumTarihi;

  /// Girilen referans kodu; boşsa gönderilmez.
  final String referansKodu;

  /// Kullanıcı "Kodum yok, geç" dedi (giden balon bunu söyler).
  final bool referansAtlandi;

  /// Aydınlatma metni "okudum" kutusu.
  final bool aydinlatma;

  /// Kullanım koşulları "kabul ediyorum" kutusu.
  final bool kosullar;

  /// Bulunulan adımın alan hataları.
  final Set<KayitFormHatasi> hatalar;

  /// İki onay kutusu da işaretli mi ("Tanışmayı tamamla" ancak o zaman
  /// açıktır).
  bool get onaylarTamam => aydinlatma && kosullar;

  KayitTaslagi copyWith({
    KayitAdimi? adim,
    String? ad,
    DateTime? dogumTarihi,
    String? referansKodu,
    bool? referansAtlandi,
    bool? aydinlatma,
    bool? kosullar,
    Set<KayitFormHatasi>? hatalar,
  }) {
    return KayitTaslagi(
      adim: adim ?? this.adim,
      ad: ad ?? this.ad,
      dogumTarihi: dogumTarihi ?? this.dogumTarihi,
      referansKodu: referansKodu ?? this.referansKodu,
      referansAtlandi: referansAtlandi ?? this.referansAtlandi,
      aydinlatma: aydinlatma ?? this.aydinlatma,
      kosullar: kosullar ?? this.kosullar,
      hatalar: hatalar ?? this.hatalar,
    );
  }

  @override
  String toString() => 'KayitTaslagi(${adim.name}, …)';
}

/// Kayıt sihirbazının adım ve alan durumu (ADR-0012 §3). Saf durum
/// geçişleridir; ağ isteği yapmaz. Gönderimi [KayitNotifier] yapar.
///
/// - İleri gitmeden önce yalnızca bulunulan adımın alanı denetlenir.
/// - Geri gezinmede girilenler korunur.
/// - Ad Google adıyla aynıysa gönderilmez ([kayitFormunuDenetle]).
class KayitSihirbaziNotifier extends Notifier<KayitTaslagi> {
  @override
  KayitTaslagi build() {
    return KayitTaslagi(ad: ref.read(googleAdiProvider) ?? '');
  }

  /// Ad alanı değişti.
  void adDegisti(String ad) {
    state = state.copyWith(
      ad: ad,
      hatalar: {...state.hatalar}..remove(KayitFormHatasi.ad),
    );
  }

  /// Referans kodu alanı değişti.
  void referansDegisti(String kod) {
    state = state.copyWith(
      referansKodu: kod,
      hatalar: {...state.hatalar}..remove(KayitFormHatasi.referansKodu),
    );
  }

  /// Referans linkinden gelen kod (`tayfam.app/r/<KOD>`, ADR-0018 §6):
  /// alan boşsa doldurur; kullanıcının yazdığının üstüne yazmaz.
  void referansOnerisi(String? kod) {
    if (kod == null || kod.isEmpty || state.referansKodu.isNotEmpty) return;
    state = state.copyWith(referansKodu: kod);
  }

  /// Doğum tarihi seçildi; yalnızca gün kullanılır.
  void dogumTarihiSecildi(DateTime tarih) {
    state = state.copyWith(
      dogumTarihi: DateTime(tarih.year, tarih.month, tarih.day),
      hatalar: {...state.hatalar}..remove(KayitFormHatasi.dogumTarihi),
    );
  }

  /// Aydınlatma metni kutusu.
  void aydinlatmaDegisti(bool deger) {
    state = state.copyWith(aydinlatma: deger);
  }

  /// Kullanım koşulları kutusu.
  void kosullarDegisti(bool deger) {
    state = state.copyWith(kosullar: deger);
  }

  /// Ad adımını denetler; geçerliyse doğum tarihi adımına geçer.
  void adiOnayla() {
    final hatalar = _adimHatalari(KayitAdimi.ad);
    if (hatalar.isNotEmpty) {
      state = state.copyWith(hatalar: hatalar);
      return;
    }
    state = state.copyWith(adim: KayitAdimi.dogumTarihi, hatalar: const {});
  }

  /// Doğum tarihi seçilmiş ve bugünden ileri değil mi. Değilse alan
  /// hatası gösterilir; teyit penceresi yalnızca `true`'da açılır.
  bool dogumTarihiGecerliMi(DateTime bugun) {
    final hatalar = _adimHatalari(KayitAdimi.dogumTarihi, bugun: bugun);
    if (hatalar.isEmpty) return true;
    state = state.copyWith(hatalar: hatalar);
    return false;
  }

  /// Teyit penceresinde "Doğru, devam et" dendi: referans adımına geçer.
  void dogumTarihiTeyitEdildi() {
    state = state.copyWith(adim: KayitAdimi.referans, hatalar: const {});
  }

  /// Referans adımını denetler; geçerliyse onay adımına geçer.
  void referansiOnayla() {
    final hatalar = _adimHatalari(KayitAdimi.referans);
    if (hatalar.isNotEmpty) {
      state = state.copyWith(hatalar: hatalar);
      return;
    }
    state = state.copyWith(
      adim: KayitAdimi.onaylar,
      referansAtlandi: state.referansKodu.trim().isEmpty,
      hatalar: const {},
    );
  }

  /// "Kodum yok, geç": kod boşaltılır ve onay adımına geçilir.
  void referansiGec() {
    state = state.copyWith(
      adim: KayitAdimi.onaylar,
      referansKodu: '',
      referansAtlandi: true,
      hatalar: const {},
    );
  }

  /// Önceki adıma döner; girilenler korunur. İlk adımda `false` döner
  /// (geri gidilecek adım yok).
  bool geri() {
    final sira = state.adim.index;
    if (sira == 0) return false;
    state = state.copyWith(
      adim: KayitAdimi.values[sira - 1],
      hatalar: const {},
    );
    return true;
  }

  /// Metin sürümleri değişti (`consent-outdated`): kutular boşaltılır ve
  /// onay adımına dönülür; kullanıcı yeni metinleri yeniden onaylar.
  void onaylariYenile() {
    state = state.copyWith(
      adim: KayitAdimi.onaylar,
      aydinlatma: false,
      kosullar: false,
    );
  }

  /// Gönderilecek değerler; bir alan geçersizse `null` ve o alanın adımına
  /// dönülür. Yaş sınırı istemcide denetlenmez, sunucunun kararıdır.
  KayitBilgisi? bilgi({
    required OnaySurumleri surumler,
    required DateTime bugun,
  }) {
    final sonuc = _denetle(surumler: surumler, bugun: bugun);
    final bilgi = sonuc.bilgi;
    if (bilgi != null) return bilgi;
    final ilk = KayitAdimi.values.firstWhere(
      (adim) => sonuc.hatalar.any((h) => _hataninAdimi(h) == adim),
      orElse: () => KayitAdimi.onaylar,
    );
    state = state.copyWith(
      adim: ilk,
      hatalar: {
        for (final h in sonuc.hatalar)
          if (_hataninAdimi(h) == ilk) h,
      },
    );
    return null;
  }

  Set<KayitFormHatasi> _adimHatalari(KayitAdimi adim, {DateTime? bugun}) {
    final sonuc = _denetle(surumler: null, bugun: bugun ?? DateTime.now());
    return {
      for (final h in sonuc.hatalar)
        if (_hataninAdimi(h) == adim) h,
    };
  }

  KayitFormSonucu _denetle({
    required OnaySurumleri? surumler,
    required DateTime bugun,
  }) {
    final t = state;
    return kayitFormunuDenetle(
      ad: t.ad,
      googleAdi: ref.read(googleAdiProvider),
      dogumTarihi: t.dogumTarihi,
      aydinlatmaOnayi: t.aydinlatma,
      kosullarOnayi: t.kosullar,
      referansKodu: t.referansKodu,
      // Adım denetiminde sürüm gerekmez; yalnızca gönderimde verilir.
      surumler: surumler ?? _yerTutucuSurumler,
      bugun: bugun,
    );
  }
}

/// Adım denetiminde kullanılan, hiçbir yere gönderilmeyen sürüm.
final OnaySurumleri _yerTutucuSurumler = OnaySurumleri.olustur(
  aydinlatma: '0',
  kosullar: '0',
);

KayitAdimi _hataninAdimi(KayitFormHatasi hata) => switch (hata) {
  KayitFormHatasi.ad => KayitAdimi.ad,
  KayitFormHatasi.dogumTarihi => KayitAdimi.dogumTarihi,
  KayitFormHatasi.referansKodu => KayitAdimi.referans,
  KayitFormHatasi.aydinlatma || KayitFormHatasi.kosullar => KayitAdimi.onaylar,
};

/// Sihirbazın durumu; kayıt ekranı kapanınca bırakılır (girilenler
/// bellekte bile kalmaz).
final kayitSihirbaziProvider =
    NotifierProvider.autoDispose<KayitSihirbaziNotifier, KayitTaslagi>(
      KayitSihirbaziNotifier.new,
      name: 'kayitSihirbaziProvider',
    );
