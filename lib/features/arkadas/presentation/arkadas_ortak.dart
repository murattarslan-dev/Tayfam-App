import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';

/// [kullaniciId]'nin profilini açar (sekmelerin üstünde; geri tuşu
/// önceki ekrana döner).
void kisiyiAc(BuildContext context, String kullaniciId) {
  unawaited(context.push(Adresler.kisi(kullaniciId)));
}

/// Üst üste binen küçük avatarlar (tasarım: Profil-Ana "Arkadaşların",
/// Profil-Arkadaslar istek kartı): her biri kart renginde ince halkalı,
/// bir öncekinin üstüne 8 px biner. Süstür; ekran okuyucudan gizlenir
/// (kişiler satırın metninde ya da bağlandığı ekranda yazar).
class AvatarYigini extends StatelessWidget {
  const AvatarYigini({
    super.key,
    required this.kisiler,
    this.cap = TayfamSizes.avatarYigini,
  });

  /// Gösterilecek kişilerin adı ve avatar yüklemesi, soldan sağa.
  final List<({String ad, String? avatarUploadId})> kisiler;

  final double cap;

  @override
  Widget build(BuildContext context) {
    if (kisiler.isEmpty) return const SizedBox.shrink();
    final r = context.renkler;
    const binme = TayfamSpacing.s8;
    final adim = cap - binme;
    return ExcludeSemantics(
      child: SizedBox(
        width: cap + adim * (kisiler.length - 1),
        height: cap,
        child: Stack(
          children: [
            for (final (sira, kisi) in kisiler.indexed)
              PositionedDirectional(
                start: adim * sira,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: r.kart,
                      width: TayfamSizes.alanOdakKenari,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: KullaniciAvatari(
                    ad: kisi.ad,
                    avatarUploadId: kisi.avatarUploadId,
                    cap: cap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
