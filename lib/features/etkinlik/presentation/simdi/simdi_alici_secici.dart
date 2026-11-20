import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/takvim_gunu.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/simdi_alicilari.dart';
import 'package:tayfam/features/etkinlik/application/simdi_baslat.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Şimdi ekranındaki "Kimler duysun" bölümü (anlık etkinlik; App
/// ADR-0032 §4): kaç arkadaşa haber verileceği ve seçimi düzenleyen
/// "Arkadaşları seç". Seçim önceden dolu gelir; düzenleme
/// [SimdiAliciSayfasi]'nda yapılır.
class SimdiAlicilariBolumu extends ConsumerWidget {
  const SimdiAlicilariBolumu({
    super.key,
    required this.anahtar,
    required this.etkin,
  });

  final SimdiAnahtari anahtar;

  /// `false` iken düzenlenemez (gönderiliyor ya da gönderildi).
  final bool etkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final secili = ref.watch(simdiAlicilariProvider(anahtar)).secili;
    final String metin;
    if (secili.isNotEmpty) {
      metin = m.simdi_bildirim_haber(secili.length);
    } else if (anahtar.davetli != null) {
      metin = m.simdi_haber_davetli;
    } else {
      metin = m.simdi_haber_anlik;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: SihirbazBilgiKutusu(
            metin: metin,
            ikon: Icons.notifications_none,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CerceveliHapEylem(
            etiket: m.simdi_bildirim_sec,
            ikon: Icons.group_add_outlined,
            onPressed: etkin
                ? () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SimdiAliciSayfasi(anahtar: anahtar),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Arkadaş seçici sayfası (App ADR-0032 §4; tasarım: `docs/tasarim/29`
/// §2 "Kimleri çağıralım?" ile aynı satırlar):
///
/// - Önce bugün "Boşum" demiş arkadaşlar ("Bugün boş" etiketiyle), sonra
///   sunucunun sırası (arkadaşlık puanı).
/// - Arama yalnızca yüklü arkadaşlarda, `turkceKucukHarf` ile; istek
///   atmaz.
/// - "n / 30 kişi seçildi" sayacı ekran okuyucuya canlı bölge olarak
///   okunur; sınır dolunca seçili olmayan satırlar devre dışıdır.
/// - "Seçimi temizle" ile kimseye bildirim gitmez.
class SimdiAliciSayfasi extends ConsumerStatefulWidget {
  const SimdiAliciSayfasi({super.key, required this.anahtar});

  final SimdiAnahtari anahtar;

  @override
  ConsumerState<SimdiAliciSayfasi> createState() => _SimdiAliciSayfasiState();
}

class _SimdiAliciSayfasiState extends ConsumerState<SimdiAliciSayfasi> {
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
    final provider = simdiAlicilariProvider(widget.anahtar);
    final secili = ref.watch(provider).secili;
    final notifier = ref.read(provider.notifier);
    final durum = ref.watch(arkadaslarProvider);
    final liste = durum.value;
    final hata = durum.error;
    final bugun = istanbulBugunu(ref.watch(etkinlikSaatiProvider)());
    final dolu = secili.length >= simdiAliciEnCok;
    final ikincil = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metinIkincil,
    );

    final Widget govde;
    if (liste == null && hata != null) {
      govde = Padding(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataSatiri.hatadan(hata),
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => ref.invalidate(arkadaslarProvider),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.tayfa_tekrar_dene),
              ),
            ),
          ],
        ),
      );
    } else if (liste == null) {
      govde = const Center(child: TayfamYukleniyor(gecikmeli: true));
    } else {
      final sirali = simdiArkadasSirasi(
        liste.ogeler,
        bugun,
        haric: {?widget.anahtar.davetli},
      );
      final sorgu = turkceKucukHarf(_sorgu.trim());
      final gorunen = [
        for (final a in sirali)
          if (sorgu.isEmpty || turkceKucukHarf(a.displayName).contains(sorgu))
            a,
      ];
      final daha = liste.dahaVar || liste.dahaYukleniyor;
      if (sirali.isEmpty) {
        govde = Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.simdi_bildirim_arkadas_yok,
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
          ),
        );
      } else {
        govde = ListView.builder(
          padding: const EdgeInsets.only(bottom: TayfamSpacing.s16),
          itemCount: gorunen.length + 1 + (daha ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == 0) {
              return gorunen.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                      child: Text(
                        m.anlik_davet_sonuc_yok,
                        style: context.yazi.bodyMedium?.copyWith(
                          color: context.renkler.metinGovde,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            }
            final sira = i - 1;
            if (sira >= gorunen.length) {
              return Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s12),
                child: Center(
                  child: liste.dahaYukleniyor
                      ? const TayfamYukleniyor()
                      : TextButton(
                          onPressed: () => unawaited(
                            ref.read(arkadaslarProvider.notifier).dahaFazla(),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.square(
                              TayfamSizes.dokunmaMin,
                            ),
                          ),
                          child: Text(m.anlik_davet_daha),
                        ),
                ),
              );
            }
            final a = gorunen[sira];
            final secildi = secili.contains(a.userId);
            return _AliciSatiri(
              key: ValueKey(a.userId),
              arkadas: a,
              secili: secildi,
              bugunBos: bugunBos(a, bugun),
              onDegistir: !secildi && dolu
                  ? null
                  : () => notifier.degistir(a.userId),
            );
          },
        );
      }
    }

    final varArkadas = liste != null && liste.ogeler.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(m.simdi_bildirim_secici_baslik)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TayfamSizes.okumaGenisligi,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s8,
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(m.simdi_bildirim_secici_aciklama, style: ikincil),
                    if (varArkadas) ...[
                      const SizedBox(height: TayfamSpacing.s12),
                      TextField(
                        controller: _ara,
                        textInputAction: TextInputAction.search,
                        onChanged: (metin) => setState(() => _sorgu = metin),
                        decoration: InputDecoration(
                          labelText: m.anlik_davet_ara,
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ],
                    const SizedBox(height: TayfamSpacing.s12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s4,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            m.simdi_bildirim_secilen(
                              secili.length,
                              simdiAliciEnCok,
                            ),
                            style: context.yazi.labelLarge,
                          ),
                        ),
                        if (secili.isNotEmpty)
                          TextButton(
                            onPressed: notifier.temizle,
                            style: TextButton.styleFrom(
                              minimumSize: const Size.square(
                                TayfamSizes.dokunmaMin,
                              ),
                            ),
                            child: Text(m.simdi_bildirim_temizle),
                          ),
                      ],
                    ),
                    if (dolu)
                      Text(
                        m.simdi_bildirim_sinir(simdiAliciEnCok),
                        style: ikincil,
                      ),
                  ],
                ),
              ),
              Expanded(child: govde),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SihirbazAltCubugu(
        ileriEtiketi: m.simdi_bildirim_tamam,
        onIleri: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Seçim satırı: avatar, ad, varsa "Bugün boş" etiketi ve onay kutusu.
/// Ekran okuyucu satırı tek öğe olarak, işaretli durumuyla okur.
/// [onDegistir] `null` ise devre dışı.
class _AliciSatiri extends StatelessWidget {
  const _AliciSatiri({
    super.key,
    required this.arkadas,
    required this.secili,
    required this.bugunBos,
    required this.onDegistir,
  });

  final Friend arkadas;
  final bool secili;
  final bool bugunBos;
  final VoidCallback? onDegistir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final degistir = onDegistir;
    return MergeSemantics(
      child: MenuSatiri.kartta(
        baslik: arkadas.displayName,
        ikonKutusu: KullaniciAvatari(
          ad: arkadas.displayName,
          avatarUploadId: arkadas.avatarUploadId,
        ),
        altOge: bugunBos
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: Etiket(
                  metin: m.bosum_rozet_bugun,
                  ton: EtiketTonu.teal,
                  ikon: Icons.event_available_outlined,
                ),
              )
            : null,
        sag: Checkbox(
          value: secili,
          onChanged: degistir == null ? null : (_) => degistir(),
        ),
        onTap: degistir,
      ),
    );
  }
}
