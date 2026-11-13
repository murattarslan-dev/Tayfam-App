import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/davetler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/yetki.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yeni davet linkinin seçimi: geçerlilik süresi ve kullanım sayısı.
typedef DavetSecimi = ({Duration sure, int kullanim});

/// Davet linkleri (`/t/<tayfaId>/ayarlar/davetler`; ADR-0018 §1; tasarım:
/// Ayar-Davetler): oluşturma, paylaşma, listeleme ve iptal. Tam ekran.
///
/// Link `https://tayfam.app/davet#<token>` biçimindedir; token yalnızca
/// oluşturma cevabında bir kez döner. Link yalnızca paylaşım sayfası
/// açıkken bellekte durur; diske, log'a ve duruma yazılmaz (kesin kural 3,
/// 9). Listede token yoktur.
class DavetlerEkrani extends ConsumerWidget {
  const DavetlerEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = davetlerProvider(tayfaId);
    final durum = ref.watch(saglayici);
    return Scaffold(
      appBar: AppBar(title: Text(m.yonetim_davetler)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(saglayici.notifier).yenile(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: m.yonetim_davet_olustur,
                ikon: Icons.add_link,
                onPressed: () => unawaited(
                  _davetAkisi(
                    context,
                    tayfaId: tayfaId,
                    olustur: (secim) => ref
                        .read(saglayici.notifier)
                        .olustur(sure: secim.sure, kullanim: secim.kullanim),
                  ),
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(saglayici),
              icerik: (davetler) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (davetler.isEmpty) BosMetin(m.yonetim_davetler_bos),
                  for (final (sira, davet) in davetler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    _DavetKarti(tayfaId: tayfaId, davet: davet),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tayfa ana sayfasından davet (kişi+ ikonu, "Oluştur" sayfasındaki
/// "Tayfaya davet et", kurulum kartındaki "Davet linkini paylaş";
/// `tayfaDavetiProvider`'a verilir). Her üye link açabilir; yetkiyi sunucu
/// verir. Link doğrudan depodan oluşturulur (ana sayfada davet listesi
/// açık değildir).
Future<void> tayfayaDavetEt(BuildContext context, String tayfaId) {
  final kap = ProviderScope.containerOf(context, listen: false);
  return _davetAkisi(
    context,
    tayfaId: tayfaId,
    olustur: (secim) async {
      try {
        final olusan = await kap
            .read(yonetimDeposuProvider)
            .davetOlustur(
              tayfaId,
              InviteCreateRequest(
                ttlSeconds: secim.sure.inSeconds,
                maxUses: secim.kullanim,
              ),
            );
        return (link: davetLinki(olusan.token), hata: null);
      } on Exception catch (hata) {
        return (link: null, hata: hata);
      }
    },
  );
}

/// Ortak davet akışı (tasarım: Ayar-Davetler): seçenekler alttan sayfada
/// (varsayılan 7 gün, 10 kişi) → "Oluştur ve paylaş" → link oluşturulur,
/// sistem paylaşım menüsü açılır ve link bir kez, kopyalanabilir olarak
/// gösterilir. Link yalnızca bu akışın ve paylaşım sayfasının belleğinde
/// yaşar (kesin kural 3, 9).
Future<void> _davetAkisi(
  BuildContext context, {
  required String tayfaId,
  required Future<DavetSonucu> Function(DavetSecimi secim) olustur,
}) async {
  final secim = await altSayfaAc<DavetSecimi>(
    context,
    builder: (_) => const DavetSecenekleri(),
  );
  if (secim == null || !context.mounted) return;
  final m = AppLocalizations.of(context);
  final kap = ProviderScope.containerOf(context, listen: false);
  final bildirici = SonucBildirici.al(context);
  final sonuc = await olustur(secim);
  final hata = sonuc.hata;
  if (hata != null) {
    bildirici.bildir(hata, '');
    return;
  }
  final link = sonuc.link;
  if (link == null || !context.mounted) return;
  final ad = kap.read(tayfaOzetiProvider(tayfaId)).ad ?? m.tayfa_adi_bilinmiyor;
  // "Oluştur ve paylaş": sistem paylaşım menüsü hemen açılır; ardından link
  // kopyalanabilsin diye bir kez gösterilir.
  try {
    await kap
        .read(paylasiciProvider)
        .paylas(m.yonetim_davet_paylasim_metni(ad, link));
  } on Exception {
    // Paylaşım menüsü açılamazsa link aşağıdaki sayfada yine gösterilir.
  }
  if (!context.mounted) return;
  await altSayfaAc<void>(
    context,
    builder: (_) => DavetLinkiPaylasimi(link: link, tayfaAdi: ad),
  );
}

/// Yeni davet linkinin seçenekleri (tasarım: Ayar-Davetler): geçerlilik
/// (1 / 7 / 30 gün) ve kullanım sayısı (1 / 10 / 100 kişi); varsayılan 7
/// gün, 10 kişi. "Oluştur ve paylaş"a basınca seçimle kapanır.
class DavetSecenekleri extends StatefulWidget {
  const DavetSecenekleri({super.key});

  @override
  State<DavetSecenekleri> createState() => _DavetSecenekleriState();
}

class _DavetSecenekleriState extends State<DavetSecenekleri> {
  Duration _sure = davetSureleri[1];
  int _kullanim = davetKullanimlari[1];

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return AltSayfaIcerigi(
      baslik: m.yonetim_davet_olustur,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
          child: Text(
            m.yonetim_davet_olustur_aciklama,
            style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        _SecimGrubu<Duration>(
          baslik: m.yonetim_davet_sure,
          secenekler: davetSureleri,
          secili: _sure,
          etiket: (sure) => m.yonetim_davet_sure_gun(sure.inDays),
          onSec: (sure) => setState(() => _sure = sure),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        _SecimGrubu<int>(
          baslik: m.yonetim_davet_kullanim,
          secenekler: davetKullanimlari,
          secili: _kullanim,
          etiket: m.yonetim_davet_kullanim_sayi,
          onSec: (sayi) => setState(() => _kullanim = sayi),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: r.tintMango,
            borderRadius: TayfamRadii.onizlemeKoseleri,
          ),
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.info_outline,
                    size: TayfamSizes.ikon,
                    color: r.tintMangoUstu,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
                Expanded(
                  child: Text(
                    m.yonetim_davet_bir_kez,
                    style: yazi.bodySmall?.copyWith(color: r.metin),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        BirincilEylem(
          etiket: m.yonetim_davet_olustur_paylas,
          ikon: Icons.share_outlined,
          onPressed: () => Navigator.of(
            context,
          ).pop<DavetSecimi>((sure: _sure, kullanim: _kullanim)),
        ),
      ],
    );
  }
}

/// Üç eşit seçenek düğmesi (tasarım: Ayar-Davetler, Ayar-Uyeler):
/// seçili olan brand kenarlı tint zemin, diğerleri çerçeveli.
class _SecimGrubu<T> extends StatelessWidget {
  const _SecimGrubu({
    required this.baslik,
    required this.secenekler,
    required this.secili,
    required this.etiket,
    required this.onSec,
  });

  final String baslik;
  final List<T> secenekler;
  final T secili;
  final String Function(T deger) etiket;
  final ValueChanged<T> onSec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: TayfamSpacing.s8,
            bottom: TayfamSpacing.s8,
          ),
          child: Semantics(
            header: true,
            child: Text(baslik, style: context.yazi.titleSmall),
          ),
        ),
        SecimDugmeleri<T>(
          secenekler: secenekler,
          secili: secili,
          etiket: etiket,
          onSec: onSec,
        ),
      ],
    );
  }
}

/// Yeni linkin paylaşımı: link bir daha gösterilemeyeceği için hemen
/// paylaşılır ya da kopyalanır. Link yalnızca bu sayfanın belleğindedir.
class DavetLinkiPaylasimi extends ConsumerWidget {
  const DavetLinkiPaylasimi({super.key, required this.link, this.tayfaAdi});

  final String link;
  final String? tayfaAdi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ad = tayfaAdi ?? m.tayfa_adi_bilinmiyor;
    return AltSayfaIcerigi(
      baslik: m.yonetim_davet_hazir_baslik,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.yonetim_davet_hazir_aciklama,
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s12),
              SelectableText(link, style: context.yazi.bodyMedium),
              const SizedBox(height: TayfamSpacing.s16),
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  Builder(
                    builder: (dugme) => BirincilEylem(
                      etiket: m.yonetim_davet_paylas,
                      ikon: Icons.share_outlined,
                      onPressed: () => unawaited(
                        _paylas(
                          dugme,
                          ref,
                          m.yonetim_davet_paylasim_metni(ad, link),
                        ),
                      ),
                    ),
                  ),
                  IkincilEylem(
                    etiket: m.yonetim_davet_kopyala,
                    ikon: Icons.copy_outlined,
                    onPressed: () => unawaited(_kopyala(context, ref)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _paylas(BuildContext dugme, WidgetRef ref, String metin) {
    final kutu = dugme.findRenderObject();
    final konum = kutu is RenderBox && kutu.hasSize
        ? kutu.localToGlobal(Offset.zero) & kutu.size
        : null;
    return ref.read(paylasiciProvider).paylas(metin, konum: konum);
  }

  Future<void> _kopyala(BuildContext context, WidgetRef ref) async {
    final bildirici = SonucBildirici.al(context);
    final metin = AppLocalizations.of(context).yonetim_davet_kopyalandi;
    await ref.read(paylasiciProvider).kopyala(link);
    bildirici.bildir(null, metin);
  }
}

class _DavetKarti extends ConsumerStatefulWidget {
  const _DavetKarti({required this.tayfaId, required this.davet});

  final String tayfaId;
  final Invite davet;

  @override
  ConsumerState<_DavetKarti> createState() => _DavetKartiState();
}

class _DavetKartiState extends ConsumerState<_DavetKarti> {
  bool _gonderiliyor = false;

  Future<void> _iptal() async {
    final m = AppLocalizations.of(context);
    final onay = await onayIste(
      context,
      baslik: m.yonetim_davet_iptal_baslik,
      aciklama: m.yonetim_davet_iptal_aciklama,
      onay: m.yonetim_davet_iptal_onayla,
      yikici: true,
    );
    if (!onay || !mounted) return;
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(davetlerProvider(widget.tayfaId).notifier)
        .iptal(widget.davet.id);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, m.yonetim_davet_iptal_edildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final davet = widget.davet;
    final bitis = davet.expiresAt.toLocal();
    final ikincil = context.yazi.bodySmall;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.yonetim_davet_kullanim_durumu(davet.useCount, davet.maxUses),
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(m.yonetim_davet_bitis(bitis, bitis), style: ikincil),
          Wrap(
            spacing: TayfamSpacing.s4,
            children: [
              Text(m.yonetim_davet_acan, style: ikincil),
              KullaniciAdiMetni(
                kullaniciId: davet.createdByUserId,
                style: ikincil,
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: YikiciEylem(
              etiket: m.yonetim_davet_iptal,
              ikon: Icons.link_off,
              onPressed: _gonderiliyor ? null : () => unawaited(_iptal()),
            ),
          ),
        ],
      ),
    );
  }
}
