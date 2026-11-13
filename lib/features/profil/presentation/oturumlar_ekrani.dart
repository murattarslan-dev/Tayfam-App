import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/oturumlar_notifier.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açık oturumlar (ADR-0018 §2; 2026-11-13 tasarım: Profil-Oturumlar):
/// açıklama ve kartta cihaz başına bir satır; bu cihaz "Bu cihaz"
/// etiketiyle işaretlidir. Başka bir cihazın oturumu tek tek
/// kapatılabilir; "Diğer cihazlardan çık" bu cihaz dışındakilerin hepsini
/// kapatır. IP adresi ve token sunucudan gelmez, gösterilmez.
class OturumlarEkrani extends ConsumerWidget {
  const OturumlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final oturumlar = ref.watch(oturumlarProvider);

    final Widget govde;
    switch (oturumlar) {
      case AsyncData(:final value):
        govde = _Liste(oturumlar: value);
      case AsyncError(:final error):
        govde = Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HataSatiri(metin: profilHatasiMetni(metinler, error)),
                const SizedBox(height: TayfamSpacing.s16),
                BirincilEylem(
                  etiket: metinler.profil_tekrar_dene,
                  onPressed: () => ref.invalidate(oturumlarProvider),
                ),
              ],
            ),
          ),
        );
      case AsyncLoading():
        govde = Center(
          child: TayfamYukleniyor(
            boyut: TayfamSizes.yukleniyorTamEkran,
            etiket: metinler.profil_yukleniyor,
            gecikmeli: true,
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(title: Text(metinler.profil_oturumlar)),
      body: SafeArea(child: govde),
    );
  }
}

class _Liste extends ConsumerStatefulWidget {
  const _Liste({required this.oturumlar});

  final List<DeviceSession> oturumlar;

  @override
  ConsumerState<_Liste> createState() => _ListeState();
}

class _ListeState extends ConsumerState<_Liste> {
  bool _suruyor = false;

  Future<void> _kapat(DeviceSession oturum) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await profilOnayi(
      context,
      baslik: metinler.profil_oturum_kapat_onay_baslik,
      aciklama: metinler.profil_oturum_kapat_onay_aciklama,
      onay: metinler.profil_oturum_kapat,
    );
    if (!onay || !mounted) return;
    await _calistir(
      () => ref.read(oturumlarProvider.notifier).kapat(oturum.sessionId),
      bildirim,
      metinler.profil_oturum_kapatildi,
    );
  }

  Future<void> _digerleri() async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await profilOnayi(
      context,
      baslik: metinler.profil_diger_onay_baslik,
      aciklama: metinler.profil_diger_onay_aciklama,
      onay: metinler.profil_diger_cihazlardan_cik,
    );
    if (!onay || !mounted) return;
    await _calistir(
      () => ref.read(oturumlarProvider.notifier).digerleriniKapat(),
      bildirim,
      metinler.profil_diger_kapatildi,
    );
  }

  Future<void> _calistir(
    Future<Object?> Function() islem,
    ScaffoldMessengerState bildirim,
    String basari,
  ) async {
    final metinler = AppLocalizations.of(context);
    setState(() => _suruyor = true);
    final hata = await islem();
    if (!mounted) return;
    setState(() => _suruyor = false);
    profilBildirimi(
      bildirim,
      hata == null ? basari : profilHatasiMetni(metinler, hata),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final digerVar = widget.oturumlar.any((o) => !o.current);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s4,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s40,
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s4,
            0,
            TayfamSpacing.s4,
            TayfamSpacing.s16,
          ),
          child: Text(
            metinler.profil_oturumlar_sayfa_aciklama,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ),
        ListeKarti(
          children: [
            for (final oturum in widget.oturumlar)
              _OturumSatiri(
                oturum: oturum,
                onKapat: oturum.current || _suruyor
                    ? null
                    : () => unawaited(_kapat(oturum)),
              ),
          ],
        ),
        if (digerVar) ...[
          const SizedBox(height: TayfamSpacing.s20),
          // Tasarım: tint-nar zemin, nar-metin yazı (açıkta 5.7:1, koyuda
          // 7.4:1; ADR-0004 Notlar 2026-11-13).
          OdakCercevesi(
            koseler: TayfamRadii.hapKoseleri,
            child: FilledButton(
              onPressed: _suruyor ? null : () => unawaited(_digerleri()),
              style: FilledButton.styleFrom(
                backgroundColor: r.tintNar,
                foregroundColor: r.narMetin,
                disabledBackgroundColor: r.pasif,
                disabledForegroundColor: r.pasifUstu,
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s20,
                  vertical: TayfamSpacing.s12,
                ),
                shape: const StadiumBorder(),
                side: BorderSide.none,
                textStyle: context.yazi.labelLarge,
              ),
              child: EylemIcerigi(
                etiket: metinler.profil_diger_cihazlardan_cik,
                ikon: Icons.logout,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bir oturum (tasarım: Profil-Oturumlar): ikon kutusu, platform, son
/// kullanım; bu cihazda teal "Bu cihaz" etiketi, diğerlerinde çerçeveli
/// yıkıcı "Kapat" (ekran okuyucu: "Oturumu kapat").
class _OturumSatiri extends StatelessWidget {
  const _OturumSatiri({required this.oturum, required this.onKapat});

  final DeviceSession oturum;
  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final zaman = DateFormat.yMMMd(metinler.localeName)
        .add_Hm()
        .format(oturum.lastSeenAt.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s12,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: r.tintMarka,
                borderRadius: TayfamRadii.dugmeKoseleri,
              ),
              child: SizedBox.square(
                dimension: TayfamSizes.menuIkonKutusu,
                child: Icon(
                  switch (oturum.platform) {
                    DeviceSessionPlatform.android => Icons.phone_android,
                    DeviceSessionPlatform.ios => Icons.phone_iphone,
                    DeviceSessionPlatform.web => Icons.language,
                    DeviceSessionPlatform.unknown => Icons.devices_other,
                  },
                  size: TayfamSizes.ikon,
                  color: r.tintMarkaUstu,
                ),
              ),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (oturum.platform) {
                    DeviceSessionPlatform.android =>
                      metinler.profil_oturum_android,
                    DeviceSessionPlatform.ios => metinler.profil_oturum_ios,
                    DeviceSessionPlatform.web => metinler.profil_oturum_web,
                    DeviceSessionPlatform.unknown =>
                      metinler.profil_oturum_bilinmeyen,
                  }, style: context.yazi.titleMedium),
                  Text(
                    metinler.profil_oturum_son_kullanim(zaman),
                    style: context.yazi.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          // Büyük yazıda sağdaki öğe de sarar; satır taşmaz.
          Flexible(
            child: oturum.current
                ? Etiket(
                    metin: metinler.profil_oturum_bu_cihaz,
                    ton: EtiketTonu.teal,
                  )
                : YikiciEylem(
                    etiket: metinler.profil_oturum_kapat_kisa,
                    semantikEtiketi: metinler.profil_oturum_kapat,
                    onPressed: onKapat,
                  ),
          ),
        ],
      ),
    );
  }
}
