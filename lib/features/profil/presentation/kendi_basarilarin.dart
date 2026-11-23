import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/istatistik/istatistik.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/rozet/rozet.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil sekmesinde kendi rozetlerin ve kişisel istatistiklerin (issue
/// #300; platform sahibi, 2026-11-23): "Başkaları nasıl görüyor"daki
/// bölümlerin aynısı ([RozetBolumu], [IstatistikBolumu]).
///
/// Veri kendi kişi profilinden okunur (`GET /v1/users/{kendi id}/profile`,
/// `self: true`). Sözleşmeye göre sunucu kendi profilinde `badges` ve
/// `stats` alanlarını görünürlük ayarından bağımsız her zaman döndürür
/// (yoksa boş liste); istemci görünürlüğe bakmaz. Boş listede sakin not
/// gösterilir. Profil "Başkaları nasıl görüyor" ekranıyla aynı
/// sağlayıcıdan okunur; yalnızca bellektedir (ADR-0006).
///
/// Okunurken yer kaplamaz; okunamazsa hata satırı ve "Tekrar dene".
/// Yanıt kendi profili değilse (`self: false`) hiçbir şey çizilmez.
class KendiBasarilarin extends ConsumerWidget {
  const KendiBasarilarin({super.key, required this.kendiId});

  /// Oturumdaki kullanıcının kimliği (hesaptan).
  final String kendiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = kisiProfiliProvider(kendiId);
    final durum = ref.watch(saglayici);
    final profil = durum.value;
    if (profil != null) {
      if (!profil.self) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RozetBolumu(
            rozetler: profil.badges ?? const [],
            bosMetin: m.rozet_bos_kendi,
            not: m.rozet_gorunurluk_notu,
          ),
          IstatistikBolumu(
            statlar: profil.stats ?? const [],
            bosMetin: m.istatistik_profil_bos_kendi,
            not: m.istatistik_profil_notu,
          ),
        ],
      );
    }
    final hata = durum.error;
    if (hata == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HataSatiri(metin: profilHatasiMetni(m, hata)),
          const SizedBox(height: TayfamSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              child: Text(m.profil_tekrar_dene),
            ),
          ),
        ],
      ),
    );
  }
}
