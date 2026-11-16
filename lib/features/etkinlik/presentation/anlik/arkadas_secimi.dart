import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anlık etkinlikte doğrudan davet edilecek arkadaşların seçimi (ADR-0026;
/// tasarım: `docs/tasarim/29` §2 "Kimleri çağıralım?"). Sihirbazın arkadaş
/// adımında ve anlık tayfanın "Arkadaş davet et" sayfasında kullanılır.
///
/// - Üstte arama alanı: yalnızca yüklü arkadaşlarda, `turkceKucukHarf` ile
///   süzer; istek atmaz.
/// - "n / 10 kişi seçildi" sayacı ekran okuyucuya canlı bölge olarak
///   okunur. Sınıra ulaşınca seçili olmayan satırlar devre dışı kalır ve
///   davet linki önerilir.
/// - Satır: avatar, ad ve onay kutusu; bütün satır dokunulabilir.
/// - Boş, yükleniyor ve hata durumları ortak bileşenlerle.
///
/// Seçim çağıranın durumundadır ([secili], [onDegistir]); bu bileşen
/// yalnızca arama metnini tutar. [haric]'teki kişiler listelenmez.
class ArkadasSecimi extends ConsumerStatefulWidget {
  const ArkadasSecimi({
    super.key,
    required this.secili,
    required this.onDegistir,
    this.enCok = anlikDavetliEnCok,
    this.haric = const {},
  });

  /// Seçili arkadaşların kimlikleri.
  final List<String> secili;

  /// Bir arkadaşın seçimi değişince; `null` ise liste devre dışıdır.
  final ValueChanged<String>? onDegistir;

  /// En çok seçilebilecek kişi.
  final int enCok;

  /// Listede gösterilmeyecek kişiler.
  final Set<String> haric;

  @override
  ConsumerState<ArkadasSecimi> createState() => _ArkadasSecimiState();
}

class _ArkadasSecimiState extends ConsumerState<ArkadasSecimi> {
  final TextEditingController _ara = TextEditingController();
  String _sorgu = '';

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(arkadaslarProvider);
    final liste = durum.value;
    final hata = durum.error;
    final secili = widget.secili;
    final dolu = secili.length >= widget.enCok;
    final Widget govde;
    if (liste == null && hata != null) {
      govde = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HataSatiri.hatadan(hata),
          const SizedBox(height: TayfamSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(arkadaslarProvider),
              child: Text(m.tayfa_tekrar_dene),
            ),
          ),
        ],
      );
    } else if (liste == null) {
      govde = const Padding(
        padding: EdgeInsets.all(TayfamSpacing.s16),
        child: Center(child: TayfamYukleniyor(gecikmeli: true)),
      );
    } else {
      final arkadaslar = [
        for (final a in liste.ogeler)
          if (!widget.haric.contains(a.userId)) a,
      ];
      if (arkadaslar.isEmpty) {
        govde = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              m.anlik_davet_bos,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CerceveliHapEylem(
                etiket: m.arkadas_ekle,
                ikon: Icons.person_add_alt_outlined,
                onPressed: () => unawaited(arkadasEkleSayfasiniAc(context)),
              ),
            ),
          ],
        );
      } else {
        final sorgu = turkceKucukHarf(_sorgu.trim());
        final gorunen = [
          for (final a in arkadaslar)
            if (sorgu.isEmpty || turkceKucukHarf(a.displayName).contains(sorgu))
              a,
        ];
        govde = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (gorunen.isEmpty)
              Text(
                m.anlik_davet_sonuc_yok,
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              )
            else
              ListeKarti(
                children: [
                  for (final a in gorunen)
                    _ArkadasSatiri(
                      arkadas: a,
                      secili: secili.contains(a.userId),
                      onDegistir: widget.onDegistir == null
                          ? null
                          : (!secili.contains(a.userId) && dolu)
                          ? null
                          : () => widget.onDegistir!(a.userId),
                    ),
                ],
              ),
            if (liste.dahaYukleniyor)
              const Padding(
                padding: EdgeInsets.all(TayfamSpacing.s12),
                child: Center(child: TayfamYukleniyor()),
              )
            else if (liste.dahaVar)
              Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s8),
                child: Center(
                  child: TextButton(
                    onPressed: () => unawaited(
                      ref.read(arkadaslarProvider.notifier).dahaFazla(),
                    ),
                    child: Text(m.anlik_davet_daha),
                  ),
                ),
              ),
          ],
        );
      }
    }
    final varArkadas = liste != null && liste.ogeler.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (varArkadas) ...[
          TextField(
            controller: _ara,
            textInputAction: TextInputAction.search,
            onChanged: (metin) => setState(() => _sorgu = metin),
            decoration: InputDecoration(
              labelText: m.anlik_davet_ara,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ],
        Semantics(
          liveRegion: true,
          child: Text(
            m.anlik_davet_secilen(secili.length, widget.enCok),
            style: context.yazi.labelLarge,
          ),
        ),
        if (dolu) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.anlik_davet_sinir(widget.enCok),
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        govde,
      ],
    );
  }
}

/// Seçim satırı: avatar, ad, onay kutusu. Ekran okuyucu satırı tek öğe
/// olarak, işaretli durumuyla okur. [onDegistir] `null` ise devre dışı.
class _ArkadasSatiri extends StatelessWidget {
  const _ArkadasSatiri({
    required this.arkadas,
    required this.secili,
    required this.onDegistir,
  });

  final Friend arkadas;
  final bool secili;
  final VoidCallback? onDegistir;

  @override
  Widget build(BuildContext context) {
    final degistir = onDegistir;
    return MergeSemantics(
      child: MenuSatiri.kartta(
        baslik: arkadas.displayName,
        ikonKutusu: KullaniciAvatari(
          ad: arkadas.displayName,
          avatarUploadId: arkadas.avatarUploadId,
        ),
        sag: Checkbox(
          value: secili,
          onChanged: degistir == null ? null : (_) => degistir(),
        ),
        onTap: degistir,
      ),
    );
  }
}
