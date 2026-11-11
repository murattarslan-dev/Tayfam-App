import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Cevap işlemleri menüsünün seçenekleri.
enum CevapIslemi { duzenle, sil }

/// Bir cevabın kartı (ADR-0004 soru-cevap kartı): yazar ve zaman, düz
/// metin gövde ve honey "faydalı" sayacı.
///
/// Sayaç başkasının cevabında dokunulabilir bir aç/kapa düğmesidir; kendi
/// cevabında yalnızca sayıyı gösterir. Kendi cevabına oyu sunucu da
/// reddeder (`own-answer-vote`); istemcinin gizlemesi yetki değildir (kesin
/// kural 5). Düzenleme ve silme menüsü yazar ile yönetime gösterilir.
class CevapKarti extends ConsumerWidget {
  const CevapKarti({
    super.key,
    required this.cevap,
    required this.yonetimde,
    required this.onOyla,
    required this.onIslem,
  });

  final Answer cevap;

  /// Kullanıcı moderatör ya da yönetici.
  final bool yonetimde;

  /// Faydalı oyu değiştirilince; yeni durumla (`true`: oy verildi).
  final ValueChanged<bool> onOyla;

  /// Menüden bir işlem seçilince.
  final ValueChanged<CevapIslemi> onIslem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazarId = cevap.authorUserId;
    final kendisi = yazarId != null && ref.watch(kendisiMiProvider(yazarId));
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YazarSatiri(yazarId: yazarId, zaman: cevap.createdAt),
          const SizedBox(height: TayfamSpacing.s8),
          // Düz metin: biçim ve bağlantı yorumlanmaz (ADR-0018 §4).
          SelectableText(
            cevap.body,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FaydaliSayaci(
                    sayi: cevap.voteCount,
                    isaretli: cevap.voted,
                    onPressed: kendisi ? null : () => onOyla(!cevap.voted),
                  ),
                ),
              ),
              if (kendisi || yonetimde)
                PopupMenuButton<CevapIslemi>(
                  tooltip: metinler.soru_cevap_islemler,
                  icon: const Icon(Icons.more_vert),
                  onSelected: onIslem,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: CevapIslemi.duzenle,
                      child: Text(metinler.soru_duzenle),
                    ),
                    PopupMenuItem(
                      value: CevapIslemi.sil,
                      child: Text(metinler.soru_sil),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
