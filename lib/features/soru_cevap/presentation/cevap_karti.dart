import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Cevaplar kartındaki bir cevap (tasarım: Soru-Detay): yazar ve zaman,
/// gerekirse teal "En faydalı" etiketi, düz metin gövde, "Faydalı · N"
/// düğmesi ve cevap işlemleri (⋯).
///
/// Faydalı düğmesi kendi cevabında pasiftir; kendi cevabına oyu sunucu da
/// reddeder (`own-answer-vote`), istemcinin pasifleştirmesi yetki değildir
/// (kesin kural 5). ⋯ menüsünde yazar ile yönetime Düzenle ve Sil,
/// diğerlerine Şikâyet et gösterilir (ADR-0018 §8).
class CevapKarti extends ConsumerWidget {
  const CevapKarti({
    super.key,
    required this.cevap,
    required this.yonetimde,
    required this.onOyla,
    required this.onIslem,
    this.enFaydali = false,
  });

  final Answer cevap;

  /// Kullanıcı moderatör ya da yönetici.
  final bool yonetimde;

  /// "En faydalı" etiketi gösterilir ([enFaydaliCevapKimligi]).
  final bool enFaydali;

  /// Faydalı oyu değiştirilince; yeni durumla (`true`: oy verildi).
  final ValueChanged<bool> onOyla;

  /// Menüden bir işlem seçilince.
  final ValueChanged<IcerikIslemi> onIslem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazarId = cevap.authorUserId;
    final kendisi = yazarId != null && ref.watch(kendisiMiProvider(yazarId));
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s16,
          TayfamSpacing.s12,
          TayfamSpacing.s8,
          TayfamSpacing.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s8),
              child: YazarSatiri(
                yazarId: yazarId,
                zaman: cevap.createdAt,
                cevapta: true,
                sag: enFaydali
                    ? Etiket(
                        metin: metinler.soru_en_faydali,
                        ton: EtiketTonu.teal,
                        ikon: Icons.check,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s8),
              // Düz metin: biçim ve bağlantı yorumlanmaz (ADR-0018 §4).
              child: SelectableText(
                cevap.body,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metin,
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FaydaliDugmesi(
                      sayi: cevap.voteCount,
                      isaretli: cevap.voted,
                      onPressed: kendisi ? null : () => onOyla(!cevap.voted),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: metinler.soru_cevap_islemler,
                  icon: const Icon(Icons.more_horiz),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  onPressed: () async {
                    final islem = await icerikIslemiSec(
                      context,
                      baslik: metinler.soru_cevap_islemler,
                      yonetebilir: kendisi || yonetimde,
                    );
                    if (islem != null) onIslem(islem);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Faydalı · N" düğmesi (tasarım: Soru-Detay): hap, en az 48 px dokunma
/// alanı. Oy verildiyse ([isaretli]) tint-brand zemin ve dolu ikon; değilse
/// kart zemin ve çerçeve. Durum ekran okuyucuya aç/kapa olarak bildirilir,
/// yalnızca renkle değil ikonla da gösterilir. [onPressed] `null` ise
/// (kendi cevabı) pasiftir.
class FaydaliDugmesi extends StatelessWidget {
  const FaydaliDugmesi({
    super.key,
    required this.sayi,
    required this.isaretli,
    required this.onPressed,
  });

  final int sayi;
  final bool isaretli;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final sayiMetni = NumberFormat.decimalPattern(metinler.localeName)
        .format(sayi);
    final onPressed = this.onPressed;
    final pasif = onPressed == null;
    final (Color zemin, Color renk, Color? kenar) = isaretli
        ? (r.tintMarka, r.tintMarkaUstu, null)
        : (r.kart, pasif ? r.metinIkincil : r.metin, r.cizgi);
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: Semantics(
        container: true,
        button: true,
        enabled: !pasif,
        toggled: isaretli,
        label: metinler.bilesen_faydali_anlam(sayi),
        onTap: onPressed,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TayfamSizes.dokunmaMin,
            minHeight: TayfamSizes.dokunmaMin,
          ),
          child: Center(
            widthFactor: 1,
            child: Material(
              color: zemin,
              shape: StadiumBorder(
                side: kenar == null
                    ? BorderSide.none
                    : BorderSide(color: kenar, width: TayfamSizes.vurguKenari),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s12,
                    vertical: TayfamSpacing.s8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isaretli
                            ? Icons.thumb_up_alt
                            : Icons.thumb_up_alt_outlined,
                        size: TayfamSizes.ikonOrta,
                        color: renk,
                      ),
                      const SizedBox(width: TayfamSpacing.s8),
                      Flexible(
                        child: Text(
                          metinler.soru_faydali_dugme(sayiMetni),
                          style: context.yazi.labelLarge?.copyWith(color: renk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
