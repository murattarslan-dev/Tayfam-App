import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/application/cikis_notifier.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/application/hukuki_baglantilar.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil sekmesi (ADR-0018 §2): referans kodu, arkadaşlık girişleri
/// (ADR-0018 §7), katılım geçmişi
/// görünürlüğü, tema, bildirimler (istemci ADR-0019), oturumlar, hukuki
/// metinler, çıkış ve hesap silme.
///
/// Hesap ayarları okunamazsa yalnızca o bölüm hata gösterir; tema, çıkış
/// ve öteki satırlar yine kullanılabilir.
class ProfilEkrani extends StatelessWidget {
  const ProfilEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(metinler.gezinme_sekme_profil)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReferansBolumu(),
                  SizedBox(height: TayfamSpacing.s24),
                  // Arkadaşlar ve tayfa davetleri (ADR-0018 §7).
                  ArkadaslikGirisleri(),
                  SizedBox(height: TayfamSpacing.s24),
                  _GorunurlukBolumu(),
                  SizedBox(height: TayfamSpacing.s24),
                  _TemaBolumu(),
                  SizedBox(height: TayfamSpacing.s24),
                  _HesapBolumu(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Referans kodu: kopyala, paylaş, yeni kod al.
class _ReferansBolumu extends ConsumerWidget {
  const _ReferansBolumu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final hesap = ref.watch(hesapAyarlariProvider);

    final Widget icerik;
    switch (hesap) {
      case AsyncData(:final value):
        icerik = _ReferansKodu(kod: value.referralCode);
      case AsyncError(:final error):
        icerik = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataSatiri(metin: profilHatasiMetni(metinler, error)),
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => ref.invalidate(hesapAyarlariProvider),
                child: Text(metinler.profil_tekrar_dene),
              ),
            ),
          ],
        );
      case AsyncLoading():
        icerik = Center(
          child: CircularProgressIndicator(
            semanticsLabel: metinler.profil_yukleniyor,
          ),
        );
    }

    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BolumBasligi(baslik: metinler.profil_referans_baslik),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            metinler.profil_referans_aciklama,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          icerik,
        ],
      ),
    );
  }
}

class _ReferansKodu extends ConsumerWidget {
  const _ReferansKodu({required this.kod});

  final String kod;

  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await profilOnayi(
      context,
      baslik: metinler.profil_referans_yenile_onay_baslik,
      aciklama: metinler.profil_referans_yenile_onay_aciklama,
      onay: metinler.profil_referans_yenile,
    );
    if (!onay) return;
    final hata = await ref.read(hesapAyarlariProvider.notifier).koduYenile();
    if (!context.mounted) return;
    if (hata == null) {
      profilBildirimi(bildirim, metinler.profil_referans_yenilendi);
    } else {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kod,
          style: context.yazi.headlineSmall,
          semanticsLabel: metinler.profil_referans_kod_etiketi(kod),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            Builder(
              builder: (dugme) => BirincilEylem(
                etiket: metinler.profil_referans_paylas,
                ikon: Icons.share_outlined,
                onPressed: () => unawaited(referansiPaylas(dugme, ref, kod)),
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(referansiKopyala(context, ref, kod)),
              icon: const Icon(Icons.copy_outlined, size: TayfamSizes.ikon),
              label: Text(metinler.profil_referans_kopyala),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_yenile(context, ref)),
              icon: const Icon(Icons.autorenew, size: TayfamSizes.ikon),
              label: Text(metinler.profil_referans_yenile),
            ),
          ],
        ),
      ],
    );
  }
}

/// Katılım geçmişinin görünürlüğü (`activity_visibility`).
class _GorunurlukBolumu extends ConsumerStatefulWidget {
  const _GorunurlukBolumu();

  @override
  ConsumerState<_GorunurlukBolumu> createState() => _GorunurlukBolumuState();
}

class _GorunurlukBolumuState extends ConsumerState<_GorunurlukBolumu> {
  /// Kaydedilmekte olan seçim; kayıt bitene kadar seçili gösterilir.
  ActivityVisibility? _bekleyen;

  Future<void> _sec(ActivityVisibility? secim) async {
    if (secim == null || _bekleyen != null) return;
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _bekleyen = secim);
    final hata = await ref
        .read(hesapAyarlariProvider.notifier)
        .gorunurlukDegistir(secim);
    if (!mounted) return;
    setState(() => _bekleyen = null);
    if (hata != null) {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
    }
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final hesap = ref.watch(hesapAyarlariProvider).value;
    if (hesap == null) return const SizedBox.shrink();
    final secili = _bekleyen ?? hesap.activityVisibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(baslik: metinler.profil_gorunurluk_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          metinler.profil_gorunurluk_aciklama,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        RadioGroup<ActivityVisibility>(
          groupValue: secili,
          onChanged: (secim) => unawaited(_sec(secim)),
          child: Column(
            children: [
              for (final g in const [
                ActivityVisibility.private,
                ActivityVisibility.tayfa,
                ActivityVisibility.public,
              ])
                RadioListTile<ActivityVisibility>(
                  value: g,
                  enabled: _bekleyen == null,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_gorunurlukAdi(metinler, g)),
                  subtitle: Text(_gorunurlukAciklamasi(metinler, g)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _gorunurlukAdi(AppLocalizations m, ActivityVisibility g) => switch (g) {
  ActivityVisibility.private => m.profil_gorunurluk_ozel,
  ActivityVisibility.tayfa => m.profil_gorunurluk_tayfa,
  ActivityVisibility.public ||
  ActivityVisibility.unknown => m.profil_gorunurluk_herkes,
};

String _gorunurlukAciklamasi(AppLocalizations m, ActivityVisibility g) =>
    switch (g) {
      ActivityVisibility.private => m.profil_gorunurluk_ozel_aciklama,
      ActivityVisibility.tayfa => m.profil_gorunurluk_tayfa_aciklama,
      ActivityVisibility.public ||
      ActivityVisibility.unknown => m.profil_gorunurluk_herkes_aciklama,
    };

/// Tema: cihaz ayarı, açık, koyu. Seçim güvenli depoda tutulur.
class _TemaBolumu extends ConsumerWidget {
  const _TemaBolumu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final tercih = ref.watch(temaTercihiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(baslik: metinler.profil_tema_baslik),
        RadioGroup<TemaTercihi>(
          groupValue: tercih,
          onChanged: (secim) {
            if (secim != null) {
              unawaited(ref.read(temaTercihiProvider.notifier).sec(secim));
            }
          },
          child: Column(
            children: [
              for (final t in TemaTercihi.values)
                RadioListTile<TemaTercihi>(
                  value: t,
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (t) {
                    TemaTercihi.sistem => metinler.profil_tema_sistem,
                    TemaTercihi.acik => metinler.profil_tema_acik,
                    TemaTercihi.koyu => metinler.profil_tema_koyu,
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bildirimler, oturumlar, hukuki metinler, çıkış ve hesap silme.
class _HesapBolumu extends ConsumerWidget {
  const _HesapBolumu();

  Future<void> _hukukiMetniAc(
    BuildContext context,
    WidgetRef ref,
    HukukiMetin metin,
  ) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final Uri adres;
    try {
      adres = await ref.read(hukukiAdresBulucuProvider)(metin);
    } on Exception catch (hata) {
      profilBildirimi(bildirim, profilHatasiMetni(metinler, hata));
      return;
    }
    if (!context.mounted) return;
    await disBaglantiyiAc(context, ref, adres);
  }

  /// Çıkış. Bu telefon şifreli mesaj geçmişinin anahtarını taşıyan tek
  /// cihazsa önce uyarıyla onay istenir (ADR-0020).
  Future<void> _cikisYap(BuildContext context, WidgetRef ref) async {
    if (!await tekCihazCikisOnayi(context, ref)) return;
    await ref.read(cikisProvider.notifier).cikisYap();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final cikiyor = ref.watch(cikisProvider);
    final bildirimIzni = ref.watch(pushPlatformuProvider).etkin
        ? ref.watch(bildirimIzniProvider.select((d) => d.izin))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(baslik: metinler.profil_hesap_baslik),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(metinler.profil_bildirimler),
          subtitle: switch (bildirimIzni) {
            null => null,
            BildirimIzni.verildi => Text(metinler.profil_bildirimler_acik),
            _ => Text(metinler.profil_bildirimler_kapali),
          },
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Adresler.bildirimAyarlari),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.devices_outlined),
          title: Text(metinler.profil_oturumlar),
          subtitle: Text(metinler.profil_oturumlar_aciklama),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Adresler.oturumlar),
        ),
        // QR ile cihaz bağlama; E2E yoksa görünmez (ADR-0020).
        const CihazBaglamaGirisi(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(metinler.profil_aydinlatma),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              unawaited(_hukukiMetniAc(context, ref, HukukiMetin.aydinlatma)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(metinler.profil_kosullar),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              unawaited(_hukukiMetniAc(context, ref, HukukiMetin.kosullar)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text(metinler.profil_cikis),
          trailing: cikiyor
              ? SizedBox.square(
                  dimension: TayfamSizes.ikon,
                  child: CircularProgressIndicator(
                    semanticsLabel: metinler.profil_cikis_suruyor,
                  ),
                )
              : null,
          onTap: cikiyor ? null : () => unawaited(_cikisYap(context, ref)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline),
          title: Text(metinler.profil_hesabi_sil),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Adresler.hesabiSil),
        ),
      ],
    );
  }
}
