import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik detayındaki "Etkinliğin anketleri" bağlantısı (ADR-0018 §5):
/// etkinliğe bağlı anketlerin listesini açar; orada etkinliğe bağlı anket
/// de açılabilir.
///
/// İstek göndermez. Tayfanın anket modülü kapalıysa hiç görünmez
/// (sunucunun `modules` alanı; yetki yine sunucudadır).
class EtkinlikAnketleriBaglantisi extends ConsumerWidget {
  const EtkinlikAnketleriBaglantisi({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
  });

  final String tayfaId;
  final String etkinlikId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acik = ref
        .watch(tayfaOzetiProvider(tayfaId))
        .acikModuller
        .contains(Module.polls.wire);
    if (!acik) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () =>
            context.go(Adresler.anketler(tayfaId, etkinlikId: etkinlikId)),
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        icon: const Icon(Icons.poll_outlined),
        label: Text(AppLocalizations.of(context).anket_etkinlik_liste_baslik),
      ),
    );
  }
}
