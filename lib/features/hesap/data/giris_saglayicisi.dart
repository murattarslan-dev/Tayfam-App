import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';

/// Giriş sağlayıcısı.
enum GirisSaglayicisi { google, apple }

/// Bu cihazdaki son girişin hangi sağlayıcıyla yapıldığı (platform sahibi
/// kararı, 2026-11-24; ADR-0034 §5).
///
/// iOS'ta bir hesap Google ile de Apple ile de açılmış olabilir. Hesap silme
/// ve veri indirme öncesindeki yeniden giriş aynı sağlayıcıyla yapılmak
/// zorundadır; kullanıcıya sormamak için son girişin sağlayıcısı cihazda
/// tek bir bayrak olarak tutulur ([CihazBayragi.appleIleGirildi]).
///
/// Bu cihazdaki her oturum bir girişle açıldığı için bayrak açık oturumun
/// sağlayıcısını gösterir; her girişte yeniden yazılır. Okuma ya da yazma
/// başarısız olursa giriş engellenmez ve varsayılan Google'dır. Hiçbir şey
/// loglanmaz.
final class GirisSaglayicisiHafizasi {
  GirisSaglayicisiHafizasi(this._depo);

  final CihazAyarlariDeposu _depo;

  /// Son girişin sağlayıcısı; kayıt yoksa ya da okunamıyorsa Google.
  Future<GirisSaglayicisi> oku() async {
    try {
      return await _depo.bayrakOku(CihazBayragi.appleIleGirildi)
          ? GirisSaglayicisi.apple
          : GirisSaglayicisi.google;
    } on Exception {
      return GirisSaglayicisi.google;
    }
  }

  /// Girişten sonra sağlayıcıyı yazar.
  Future<void> yaz(GirisSaglayicisi saglayici) async {
    try {
      if (saglayici == GirisSaglayicisi.apple) {
        await _depo.bayrakKoy(CihazBayragi.appleIleGirildi);
      } else {
        await _depo.bayrakKaldir(CihazBayragi.appleIleGirildi);
      }
    } on Exception {
      // Yazılamazsa giriş yine tamamlanır; yeniden giriş Google'ı açar ve
      // yanlış hesap "farklı hesap" hatasıyla durur.
    }
  }
}

/// Son girişin sağlayıcısı.
final girisSaglayicisiHafizasiProvider = Provider<GirisSaglayicisiHafizasi>(
  (ref) => GirisSaglayicisiHafizasi(ref.watch(cihazAyarlariDeposuProvider)),
  name: 'girisSaglayicisiHafizasiProvider',
);
