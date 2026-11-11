import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';

/// [kullaniciId]'nin profilini açar (sekmelerin üstünde; geri tuşu
/// önceki ekrana döner).
void kisiyiAc(BuildContext context, String kullaniciId) {
  unawaited(context.push(Adresler.kisi(kullaniciId)));
}

/// Bir alt ekrana giden satır: ikon, etiket, isteğe bağlı rozet ve ok.
class GirisSatiri extends StatelessWidget {
  const GirisSatiri({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.rozet = false,
    this.rozetEtiketi,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;

  /// Bekleyen bir şey var (ör. gelen istek).
  final bool rozet;

  /// Rozetin ekran okuyucu metni.
  final String? rozetEtiketi;

  @override
  Widget build(BuildContext context) {
    final etiketMetni = Text(etiket, style: context.yazi.bodyLarge);
    return Semantics(
      button: true,
      value: rozet ? rozetEtiketi : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: TayfamRadii.dugmeKoseleri,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Badge(
                    isLabelVisible: rozet,
                    smallSize: TayfamSizes.nokta,
                    child: Icon(
                      ikon,
                      size: TayfamSizes.ikon,
                      color: context.renkler.metinGovde,
                    ),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s16),
                Expanded(child: etiketMetni),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    size: TayfamSizes.ikon,
                    color: context.renkler.metinIkincil,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
