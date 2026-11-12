import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadas_bulma_notifier.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_ortak.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Referans koduyla arkadaş bulma (`/profil/arkadaslar/bul`; ADR-0018 §7).
/// Kod girilir, sahibi gösterilir, arkadaşlık isteği gönderilir. Kod
/// yalnızca istek gövdesinde gider; saklanmaz.
class ArkadasBulEkrani extends ConsumerStatefulWidget {
  const ArkadasBulEkrani({super.key});

  @override
  ConsumerState<ArkadasBulEkrani> createState() => _ArkadasBulEkraniState();
}

class _ArkadasBulEkraniState extends ConsumerState<ArkadasBulEkrani> {
  final TextEditingController _kod = TextEditingController();

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  void _ara() {
    FocusScope.of(context).unfocus();
    unawaited(ref.read(arkadasBulmaProvider.notifier).ara(_kod.text));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(arkadasBulmaProvider);
    final araniyor = durum.isLoading;
    final bulunan = durum.value;
    final hata = durum.hasError ? durum.error : null;
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_bul_baslik)),
      body: ListView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        children: [
          Text(
            m.arkadas_bul_aciklama,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          TextField(
            controller: _kod,
            enabled: !araniyor,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              LengthLimitingTextInputFormatter(referansKoduEnFazla),
            ],
            decoration: InputDecoration(
              labelText: m.arkadas_bul_kod_etiketi,
              hintText: m.arkadas_bul_kod_ornek,
            ),
            onSubmitted: (_) => _ara(),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BirincilEylem(
              etiket: m.arkadas_bul_ara,
              ikon: Icons.search,
              onPressed: araniyor ? null : _ara,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s24),
          if (araniyor)
            Center(child: TayfamYukleniyor(etiket: m.arkadas_yukleniyor))
          else if (hata != null)
            HataSatiri.hatadan(hata)
          else if (bulunan != null)
            _BulunanKarti(bulunan: bulunan),
        ],
      ),
    );
  }
}

class _BulunanKarti extends ConsumerStatefulWidget {
  const _BulunanKarti({required this.bulunan});

  final BulunanKisi bulunan;

  @override
  ConsumerState<_BulunanKarti> createState() => _BulunanKartiState();
}

class _BulunanKartiState extends ConsumerState<_BulunanKarti> {
  bool _gonderiliyor = false;

  Future<void> _gonder() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref.read(arkadasBulmaProvider.notifier).istekGonder();
    if (mounted) setState(() => _gonderiliyor = false);
    final durum = ref.read(arkadasBulmaProvider).value?.durum;
    bildirici.bildir(
      hata,
      durum == FriendState.friends
          ? m.arkadas_artik_arkadassiniz
          : m.arkadas_istek_gonderildi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kisi = widget.bulunan.kisi;
    final kendisi = ref.watch(kendisiMiProvider(kisi.userId));
    final durumMetni = switch (widget.bulunan.durum) {
      FriendState.friends => m.arkadas_durum_arkadas,
      FriendState.outgoing => m.arkadas_durum_giden,
      FriendState.incoming => m.arkadas_durum_gelen,
      FriendState.unknown || null => null,
    };
    return TayfamKart(
      onTap: () => kisiyiAc(context, kisi.userId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kisi.displayName, style: context.yazi.titleMedium),
          if (kendisi) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              m.arkadas_bul_kendi_kodun,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ] else if (durumMetni != null) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              durumMetni,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ] else ...[
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: m.arkadas_istek_gonder,
                ikon: Icons.person_add_alt,
                onPressed: _gonderiliyor ? null : () => unawaited(_gonder()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
