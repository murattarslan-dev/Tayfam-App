import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/materyal/data/materyal_deposu.dart';

/// Ana sayfadaki materyal kartında gösterilen materyal sayısı.
const int kartMateryalSayisi = 3;

/// Liste süzgeci: tür, ders/konu ve "yalnızca benimkiler". Hepsi sunucuya
/// sorgu olarak gider.
typedef MateryalSuzgeci = ({
  MaterialKind? tur,
  DersKonuSecimi? dersKonu,
  bool benim,
});

/// Süzgeçsiz liste.
const MateryalSuzgeci suzgecYok = (tur: null, dersKonu: null, benim: false);

/// Süzgeç boş mu (her materyal).
bool suzgecBos(MateryalSuzgeci suzgec) =>
    suzgec.tur == null && suzgec.dersKonu == null && !suzgec.benim;

/// Bir materyal listesinin anahtarı. Sayfa token'ı yalnızca aynı süzgeçle
/// geçerli olduğu için her süzgeç kendi listesini tutar.
typedef MateryalSorgusu = ({String tayfaId, MateryalSuzgeci suzgec});

/// [tayfaId]'nin süzgeçsiz listesi; ana sayfa kartı ve liste ekranı bunu
/// paylaşır.
MateryalSorgusu anaMateryalListesi(String tayfaId) =>
    (tayfaId: tayfaId, suzgec: suzgecYok);

/// Bir materyalin anahtarı.
typedef MateryalAnahtari = ({String tayfaId, String materyalId});

/// Bir tayfanın materyal kütüphanesi (`GET …/materials`, sayfalı;
/// Tayfam-Api ADR-0040 §3). Tayfaya bağlıdır: `family` + `autoDispose`;
/// oturum değişince yeniden kurulur. Yalnızca bellektedir (ADR-0006).
class MateryalListesiNotifier extends SayfaliListeNotifier<Material> {
  MateryalListesiNotifier(this.sorgu);

  final MateryalSorgusu sorgu;

  bool _ekleyebilir = false;

  /// Sunucunun son ilk sayfada söylediği `caller_can_add`. Liste durumu
  /// değişmeden önce yazılır; ekran durumu izleyip bunu okur.
  bool get ekleyebilir => _ekleyebilir;

  @override
  Future<SayfaliListe<Material>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(materyalDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Material>> sayfaGetir(String? sayfaToken) async {
    final suzgec = sorgu.suzgec;
    final sonuc = await ref
        .read(materyalDeposuProvider)
        .materyaller(
          sorgu.tayfaId,
          tur: suzgec.tur,
          dersAnahtari: suzgec.dersKonu?.ders,
          konuAnahtari: suzgec.dersKonu?.konu,
          benim: suzgec.benim,
          sayfaToken: sayfaToken,
        );
    if (sayfaToken == null) _ekleyebilir = sonuc.ekleyebilir;
    return sonuc.sayfa;
  }

  @override
  String kimlik(Material oge) => oge.id;
}

/// Bir materyal listesi. Hata otomatik yeniden denenmez; ekranlar
/// "Tekrar dene" sunar, aşağı çekince yenilenir.
final materyalListesiProvider = AsyncNotifierProvider.autoDispose
    .family<MateryalListesiNotifier, SayfaliListe<Material>, MateryalSorgusu>(
      MateryalListesiNotifier.new,
      name: 'materyalListesiProvider',
      retry: _yenidenDenemeYok,
    );

/// Bir materyal (`GET …/materials/{id}`).
class MateryalNotifier extends AsyncNotifier<Material> {
  MateryalNotifier(this.anahtar);

  final MateryalAnahtari anahtar;

  @override
  Future<Material> build() => ref
      .read(materyalDeposuProvider)
      .materyal(anahtar.tayfaId, anahtar.materyalId);
}

/// Materyal detayı; ekrandan kalkınca bırakılır.
final materyalProvider = AsyncNotifierProvider.autoDispose
    .family<MateryalNotifier, Material, MateryalAnahtari>(
      MateryalNotifier.new,
      name: 'materyalProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Yazma sonrasında listeler ve detaylar sunucudan yeniden okunur: istemci
/// yerel kopya kurmaz (App ADR-0033 §4).
void materyalleriTazele(Ref ref) => ref
  ..invalidate(materyalListesiProvider)
  ..invalidate(materyalProvider);

/// Materyali siler (yazarı) ya da kaldırır (moderatör); geri alınamaz.
/// Yetkiyi sunucu verir (kesin kural 5).
final class MateryalIslemleri {
  MateryalIslemleri(this._ref);

  final Ref _ref;

  Future<void> sil(String tayfaId, String materyalId) async {
    await _ref.read(materyalDeposuProvider).sil(tayfaId, materyalId);
    _ref.invalidate(materyalListesiProvider);
  }
}

/// Materyal işlemleri; durum tutmaz.
final materyalIslemleriProvider = Provider<MateryalIslemleri>(
  MateryalIslemleri.new,
  name: 'materyalIslemleriProvider',
);

/// Kullanıcının yazdığı bağlantıyı sözleşmenin biçimine getirir: yalnızca
/// `https`; kullanıcı bilgisi, IP adresi, 443 dışı port, boşluk ve görünmez
/// karakter yok; en çok 500 karakter. Şemasız yazılan adresin başına
/// `https://` eklenir; başka şema (`http:`, `mailto:`, `javascript:` …)
/// reddedilir. Uygunsa gönderilecek adres, değilse `null`. Son kararı
/// sunucu verir (`blocked-link`).
String? baglantiyiTemizle(String girdi) {
  final metin = girdi.trim();
  if (metin.isEmpty || metin.length > baglantiEnCok) return null;
  if (_bosluk.hasMatch(metin)) return null;
  final String aday;
  if (metin.contains('://')) {
    aday = metin;
  } else {
    // Şemasız adreste ilk `/`'ten önce `:` yoksa alan adıdır.
    final ilkBolum = metin.split('/').first;
    if (ilkBolum.contains(':')) return null;
    aday = 'https://$metin';
  }
  final adres = Uri.tryParse(aday);
  if (adres == null || !guvenliBaglanti(adres)) return null;
  return aday;
}

/// En çok bağlantı uzunluğu (sözleşme: sunucu normalleştirince 500).
const int baglantiEnCok = 500;

final RegExp _bosluk = RegExp(
  r'[\s\u0000-\u001F\u007F­​-‏ -‮⁠-⁤﻿]',
);

final RegExp _ipv4 = RegExp(r'^[0-9]+(\.[0-9]+){3}$');

/// [adres] açılmaya ya da gönderilmeye uygun mu: `https`, alan adı (IP
/// değil), kullanıcı bilgisi yok, port yok ya da 443.
bool guvenliBaglanti(Uri adres) =>
    adres.scheme == 'https' &&
    adres.host.isNotEmpty &&
    adres.host.contains('.') &&
    !adres.host.contains(':') &&
    !_ipv4.hasMatch(adres.host) &&
    adres.userInfo.isEmpty &&
    adres.port == 443;

/// Sunucudan gelen materyal bağlantısı açılabilir mi; açılabilirse adresi.
/// Sunucu doğrulasa da istemci yeniden doğrular (girdi kabul edilir).
Uri? acilabilirBaglanti(String? url) {
  if (url == null || _bosluk.hasMatch(url)) return null;
  final adres = Uri.tryParse(url);
  if (adres == null || !guvenliBaglanti(adres)) return null;
  return adres;
}
