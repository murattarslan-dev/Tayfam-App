/// Gelen adresi derin link olarak ayrıştırır (ADR-0018 §6, kesin kural 9).
///
/// Uygulama linkleri (Android App Links) yalnızca
/// `https://tayfam.app/davet#<token>` ve `https://tayfam.app/r/<KOD>`
/// biçimindedir. Platform adresi yönlendiriciye tam adres olarak verir
/// (Flutter Android gömücüsü `Intent.getData().toString()`); eski
/// sürümlerdeki gibi yalnızca yol + fragment olarak da gelebilir. İkisi de
/// kabul edilir. Adres girdi kabul edilir ve doğrulanır: yalnızca beklenen
/// şema, alan adı ve yol geçer.
///
/// Davet token'ı fragment'tadır; sunucuya URL ile gitmez, yalnızca istek
/// gövdesinde gider ve hiçbir yere yazılmaz, loglanmaz. Bu dosyadaki
/// türlerin `toString`'i token'ı ve kodu içermez.
library;

import 'package:flutter/foundation.dart';

/// Uygulama linklerinin alan adı.
const String uygulamaLinkiAlanAdi = 'tayfam.app';

/// Davet linkinin ve uygulama içindeki davet ekranının yolu.
const String davetYolu = '/davet';

/// Referans linkinin ilk yol parçası (`/r/<KOD>`).
const String referansOneki = 'r';

/// Davet token'ının biçimi: base64url (dolgusuz), en çok 64 karakter
/// (sözleşme: `InviteTokenRequest.token`, `maxLength: 64`). Tam doğrulama
/// sunucudadır.
final RegExp _tokenBicimi = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Referans kodunun biçimi: isteğe bağlı `TYF-` öneki ve 6 karakter
/// (karışan 0/O, 1/I/L yok). Büyük/küçük harf fark etmez; kod
/// dönüştürülmeden gönderilir, sunucu düzeltir.
final RegExp _referansBicimi = RegExp(
  r'^(TYF-)?[2-9A-HJ-NP-Z]{6}$',
  caseSensitive: false,
);

/// Ayrıştırılan gelen adres.
@immutable
sealed class GelenAdres {
  const GelenAdres();
}

/// Uygulama içi bir adres; derin link değil, olduğu gibi yönlendirilir.
final class IcAdres extends GelenAdres {
  const IcAdres();
}

/// Geçerli bir davet linki.
final class DavetLinki extends GelenAdres {
  const DavetLinki(this.token);

  /// Davet token'ı. Yalnızca istek gövdesine gider.
  final String token;

  @override
  bool operator ==(Object other) =>
      other is DavetLinki && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'DavetLinki';
}

/// Geçerli bir referans linki.
final class ReferansLinki extends GelenAdres {
  const ReferansLinki(this.kod);

  /// Referans kodu (linkte geldiği gibi).
  final String kod;

  @override
  bool operator ==(Object other) =>
      other is ReferansLinki && other.kod == kod;

  @override
  int get hashCode => kod.hashCode;

  @override
  String toString() => 'ReferansLinki';
}

/// Dışarıdan gelen ama beklenen biçimde olmayan adres (başka alan adı,
/// başka yol, bozuk token ya da kod). İşlenmez; ana adrese gidilir.
final class GecersizLink extends GelenAdres {
  const GecersizLink();
}

/// [konum]'u ayrıştırır.
///
/// - Şema ya da alan adı taşıyan adres yalnızca `https://tayfam.app`
///   (kullanıcı bilgisi ve başka port yok) ve `/davet` ya da `/r/<KOD>`
///   yoluyla kabul edilir; başka her şey [GecersizLink]'tir.
/// - Yalnızca yol olan adreste: fragment'lı `/davet` ve `/r/…` derin
///   linktir; fragment'sız `/davet` uygulamanın kendi davet ekranıdır
///   ([IcAdres]); diğer yollar [IcAdres]'tir.
GelenAdres gelenAdresiAyristir(Uri konum) {
  final dis = konum.hasScheme || konum.hasAuthority;
  if (dis &&
      (konum.scheme != 'https' ||
          konum.host != uygulamaLinkiAlanAdi ||
          konum.userInfo.isNotEmpty ||
          konum.port != 443)) {
    return const GecersizLink();
  }

  final parcalar = [
    for (final p in konum.pathSegments)
      if (p.isNotEmpty) p,
  ];
  final yol = '/${parcalar.join('/')}';

  if (yol == davetYolu) {
    if (!dis && !konum.hasFragment) return const IcAdres();
    final token = konum.fragment;
    return _tokenBicimi.hasMatch(token)
        ? DavetLinki(token)
        : const GecersizLink();
  }
  if (parcalar.isNotEmpty && parcalar.first == referansOneki) {
    if (parcalar.length == 2 && _referansBicimi.hasMatch(parcalar[1])) {
      return ReferansLinki(parcalar[1]);
    }
    return const GecersizLink();
  }
  return dis ? const GecersizLink() : const IcAdres();
}
