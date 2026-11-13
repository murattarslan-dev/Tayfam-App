import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/kurulum.dart';
import 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_avatari.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_degistirme_paneli.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa sekmesinin kökü: bir tayfanın ana sayfası (`/t/<tayfaId>`;
/// 2026-11-13 yeniden tasarım, ADR-0015 Notlar; tasarım: Ana-*).
///
/// [tayfaId] adresten gelir ve yalnızca biçimi doğrulanmıştır; tayfanın
/// içeriği varsayılmaz, sunucudan gelir (ADR-0003). Sayfa açılınca tayfa
/// `GET /v1/tayfas/{tayfa_id}` ile tazelenir (ADR-0014 §1).
///
/// Yukarıdan aşağıya:
/// - mor üst bölüm: tayfa avatarı ve adı (dokununca tayfa değiştirme
///   paneli), üye sayısı, davet (kişi+) ve tayfa menüsü (⋯), durum şeridi;
/// - mor bölüme taşan kartlar: yeni tayfada "Tayfanı birlikte kuralım",
///   açık modüllerin öne çıkan kartı ("Sıradaki" etkinlik);
/// - yöneticiye ve moderatöre bekleyen katılım isteği satırı;
/// - açık modüllerin bölümleri kayıt sırasıyla (etkinlikler, duyurular,
///   anketler, sorular); modüllere bölümlerin "Tümü" bağlantılarından
///   gidilir, ayrı modül gezinmesi yoktur;
/// - sağ altta "Oluştur" (seçenekleri sunucunun izinleri belirler; istemci
///   yalnızca sadeleştirir, kesin kural 5).
///
/// Kapalı modülün bölümü hiç görünmez; görünürlüğe sunucunun `modules`
/// alanı karar verir (ADR-0002). Aşağı çekince tayfa ve bölümler
/// yenilenir; veri yalnızca bellektedir (ADR-0006).
class TayfaAnaSayfa extends ConsumerWidget {
  const TayfaAnaSayfa({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final tayfa = ozet.tayfa;
    final ad = ozet.ad ?? metinler.tayfa_adi_bilinmiyor;
    final moduller = gorunurModuller(
      ref.watch(tayfaModulleriProvider),
      ozet.acikModuller,
    );
    final menu = ref.watch(tayfaUstMenusuProvider);
    final davet = ref.watch(tayfaDavetiProvider);
    final silmeIptali = ref.watch(tayfaSilmeIptaliProvider);
    final simdi = ref.watch(tayfaSaatiProvider)();
    final yeniOlusturuldu = ref.watch(davetKisayoluProvider) == tayfaId;
    final kurulum = kurulumGosterilsin(
      ozet,
      simdi: simdi,
      yeniOlusturuldu: yeniOlusturuldu,
    );
    final kural = kuralGosterilsin(ozet, simdi: simdi);
    final durum = tayfa == null ? null : tayfaDurumu(tayfa);
    final bekleyen = ozet.bekleyenIstekSayisi;
    final secenekler = [
      for (final modul in moduller)
        if (modul.olusturmaSecenegi case final secenek?)
          if (secenek.izinli(ozet.yetki)) secenek,
    ];
    final olusturVar = secenekler.isNotEmpty || davet != null;
    final oneCikanlar = [
      if (kurulum) TayfaKurulumKarti(tayfaId: tayfaId),
      for (final modul in moduller) ?modul.anaSayfaOneCikan(context, tayfaId),
    ];
    final iptalDugmesi =
        durum?.tur == TayfaDurumTuru.silinecek &&
            ozet.rol == Role.admin &&
            silmeIptali != null
        ? silmeIptali(context, tayfaId)
        : null;
    return Scaffold(
      floatingActionButton: olusturVar
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(
                _olusturmaSayfasiniAc(
                  context,
                  tayfaId: tayfaId,
                  secenekler: secenekler,
                  davet: davet,
                  kod: ozet.katilimKodu,
                ),
              ),
              backgroundColor: context.renkler.marka,
              foregroundColor: context.renkler.markaUstu,
              icon: const Icon(Icons.add),
              label: Text(metinler.tayfa_olustur_dugmesi),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _yenile(ref, moduller),
        // Üst bölüm içerikle birlikte kayar; büyük yazıda da taşmaz.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom: olusturVar ? TayfamSizes.olusturAlani : TayfamSpacing.s24,
          ),
          children: [
            TayfaUstBolumu(
              ad: ad,
              tayfa: tayfa,
              uyeSayisi: tayfa?.memberCount,
              durum: durum,
              durumEylemi: iptalDugmesi,
              menu: menu?.call(context, tayfaId),
              onDavet: davet == null
                  ? null
                  : () => unawaited(davet(context, tayfaId)),
            ),
            if (oneCikanlar.isNotEmpty) MorTasma(children: oneCikanlar),
            if (bekleyen != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s16,
                  TayfamSpacing.kenarMobil,
                  0,
                ),
                child: BekleyenIstekSatiri(
                  sayi: bekleyen,
                  onTap: () => context.go(Adresler.katilimIstekleri(tayfaId)),
                ),
              ),
            if (kural)
              const Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  TayfamSpacing.s20,
                  TayfamSpacing.s16,
                  TayfamSpacing.s20,
                  0,
                ),
                child: _KuralMetni(),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s24,
                TayfamSpacing.kenarMobil,
                0,
              ),
              child: moduller.isEmpty
                  ? Text(
                      metinler.tayfa_ana_sayfa_bos,
                      style: context.yazi.bodyLarge?.copyWith(
                        color: context.renkler.metinGovde,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (sira, modul) in moduller.indexed) ...[
                          if (sira > 0)
                            const SizedBox(height: TayfamSpacing.s32),
                          modul.anaSayfaKarti(context, tayfaId),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tayfayı ve görünen bölümleri birlikte yeniler; hepsi bitince döner.
  Future<void> _yenile(WidgetRef ref, List<TayfaModule> moduller) async {
    await Future.wait([
      ref.read(tayfaGorunumuProvider(tayfaId).notifier).yenile(),
      for (final modul in moduller) modul.anaSayfayiYenile(ref, tayfaId),
    ]);
  }
}

/// Tayfa ana sayfasının mor üst bölümü (ADR-0004 §2a, ADR-0014 §6;
/// tasarım: Ana-Ilk-Ekran): `brand` zemin üzerinde tayfa avatarı, beyaz
/// tayfa adı (dokununca alttan tayfa değiştirme paneli açılır) ve üye
/// sayısı; sağda davet (kişi+) ve tayfa menüsü (⋯); altta durum şeridi.
/// İki temada da aynıdır; odak çerçevesi mor yüzeyde mangodur.
class TayfaUstBolumu extends StatelessWidget {
  const TayfaUstBolumu({
    super.key,
    required this.ad,
    this.tayfa,
    this.uyeSayisi,
    this.durum,
    this.durumEylemi,
    this.menu,
    this.onDavet,
  });

  /// Gösterilecek tayfa adı.
  final String ad;

  /// Avatarın kapak ve ilgi alanı bilgisi; bilinmiyorsa `null`.
  final Tayfa? tayfa;

  /// Üye sayısı; bilinmiyorsa gösterilmez.
  final int? uyeSayisi;

  /// Durum şeridi; durum olağansa `null`.
  final TayfaDurumu? durum;

  /// Durum şeridindeki düğme ("Silmeyi iptal et"); yoksa `null`.
  final Widget? durumEylemi;

  /// Tayfa menüsü düğmesi (tayfa yönetimi kaydından; ADR-0018 §1); yoksa
  /// gösterilmez.
  final Widget? menu;

  /// Davet (kişi+) düğmesine dokununca; `null` ise düğme gösterilmez.
  final VoidCallback? onDavet;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final menu = this.menu;
    final durum = this.durum;
    final onDavet = this.onDavet;
    return MarkaYuzeyi(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            TayfamSpacing.s8,
            TayfamSpacing.s8,
            TayfamSpacing.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _TayfaAdiDugmesi(
                        ad: ad,
                        tayfa: tayfa,
                        uyeSayisi: uyeSayisi,
                        // Panel bu (MarkaYuzeyi dışındaki) bağlamla açılır;
                        // böylece panel mor yüzeyin temasını (mango odak)
                        // devralmaz.
                        onPressed: () =>
                            unawaited(tayfaDegistirmePaneliniAc(context)),
                      ),
                    ),
                  ),
                  if (onDavet != null)
                    IconButton(
                      onPressed: onDavet,
                      tooltip: metinler.tayfa_davet_et,
                      icon: Icon(
                        Icons.person_add_alt_outlined,
                        color: r.markaYuzeyUstu,
                      ),
                    ),
                  ?menu,
                ],
              ),
              if (durum != null) ...[
                const SizedBox(height: TayfamSpacing.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s8,
                  ),
                  child: TayfaDurumSeridi(durum: durum, eylem: durumEylemi),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mor üst bölümdeki durum şeridi (ADR-0014 §6; tasarım: Ayar-Silme):
/// ink kutu, beyaz ikon ve metin; silme planlanmışsa yöneticiye
/// "Silmeyi iptal et" ([eylem]). Şerit yalnızca bilgidir; düğmeler
/// sunucunun hatalarına göre davranır.
class TayfaDurumSeridi extends StatelessWidget {
  const TayfaDurumSeridi({super.key, required this.durum, this.eylem});

  final TayfaDurumu durum;

  /// Şeridin altındaki düğme; yoksa `null`.
  final Widget? eylem;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final renk = r.markaYuzeyUstu;
    final eylem = this.eylem;
    final (ikon, metin) = switch (durum.tur) {
      TayfaDurumTuru.askida => (Icons.block, metinler.tayfa_durum_askida),
      TayfaDurumTuru.silinecek => (
        Icons.delete_outline,
        _silinmeMetni(metinler, durum.zaman!.toLocal()),
      ),
      TayfaDurumTuru.arsiv => (
        Icons.inventory_2_outlined,
        metinler.tayfa_durum_arsiv,
      ),
      TayfaDurumTuru.uyari => (Icons.schedule, metinler.tayfa_durum_uyari),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.markaYuzeyKutusu,
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s16,
          vertical: TayfamSpacing.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(ikon, color: renk, size: TayfamSizes.ikon),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Text(
                      metin,
                      style: context.yazi.bodyMedium?.copyWith(color: renk),
                    ),
                  ),
                ],
              ),
            ),
            if (eylem != null) ...[
              const SizedBox(height: TayfamSpacing.s12),
              eylem,
            ],
          ],
        ),
      ),
    );
  }
}

String _silinmeMetni(AppLocalizations metinler, DateTime zaman) =>
    metinler.tayfa_durum_silinecek(zaman, zaman);

/// Mor üst bölüme taşan kartlar (tasarım: Ana-Ilk-Ekran, kart −76 px):
/// kartların arkasında, üstten [TayfamSizes.morTasma] kadar mor yüzey
/// çizilir. Kartlar kendini boş çizerse (gösterecek etkinlik yok) mor
/// yüzey de çizilmez.
class MorTasma extends StatelessWidget {
  const MorTasma({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _UstMorBoyaci(renk: context.renkler.markaYuzey),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.kenarMobil,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (sira, kart) in children.indexed) ...[
              if (sira > 0) const SizedBox(height: TayfamSpacing.s16),
              kart,
            ],
          ],
        ),
      ),
    );
  }
}

class _UstMorBoyaci extends CustomPainter {
  const _UstMorBoyaci({required this.renk});

  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    final yukseklik = math.min(TayfamSizes.morTasma, size.height);
    if (yukseklik <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, yukseklik),
      Paint()..color = renk,
    );
  }

  @override
  bool shouldRepaint(_UstMorBoyaci oldDelegate) => oldDelegate.renk != renk;
}

/// Yöneticiye ve moderatöre bekleyen katılım isteği satırı (tasarım:
/// Ana-Yonetici): "3 kişi katılmak istiyor"; dokununca katılım istekleri
/// açılır. Sayı `pending_join_request_count`'tan gelir; alan yalnızca
/// onlara döner (kesin kural 5).
class BekleyenIstekSatiri extends StatelessWidget {
  const BekleyenIstekSatiri({
    super.key,
    required this.sayi,
    required this.onTap,
  });

  final int sayi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return OdakCercevesi(
      koseler: TayfamRadii.kartKoseleri,
      child: Material(
        color: r.tintMango,
        borderRadius: TayfamRadii.kartKoseleri,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.menuSatiri,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: r.mango,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: TayfamSizes.menuIkonKutusu,
                          child: Icon(
                            Icons.person_add_alt_outlined,
                            color: r.vurguUstu,
                            size: TayfamSizes.ikon,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.tayfa_ana_bekleyen_baslik(sayi),
                            style: yazi.titleMedium,
                          ),
                          Text(
                            m.tayfa_ana_bekleyen_aciklama,
                            style: yazi.bodySmall?.copyWith(
                              color: r.tintMangoUstu,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "7 günde 3 üye" kuralı (Notion: Proje Planı §7): yeni tayfanın
/// yöneticisine, üye sayısı eşiğin altındayken.
class _KuralMetni extends StatelessWidget {
  const _KuralMetni();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.info_outline,
            size: TayfamSizes.ikon,
            color: r.metinGovde,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s8),
        Expanded(
          child: Text(
            AppLocalizations.of(context).tayfa_kurulum_kural,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ),
      ],
    );
  }
}

/// Yeni kurulan tayfanın "Tayfanı birlikte kuralım" kartı (tasarım:
/// Ana-Yeni-Tayfa; ADR-0015 Notlar 2026-11-13). Adımlar:
///
/// 1. Tayfayı kurdun (her zaman tamam).
/// 2. Arkadaşlarını çağır: davet linkini paylaş ya da kodu kopyala; tayfada
///    kurucu dışında biri olunca tamam (`member_count > 1`).
/// 3. ve sonrası: açık modüllerin kurulum adımları ("İlk etkinliği aç",
///    "Bir duyuru sabitle"); tamamlanma modülün sunucudan okuduğu veriden.
///
/// Tamamlanma yalnızca sunucu verisinden hesaplanır ve diske yazılmaz.
/// Bütün adımlar tamamsa kart gösterilmez. Kartın görünüp görünmeyeceğine
/// [kurulumGosterilsin] karar verir.
class TayfaKurulumKarti extends ConsumerWidget {
  const TayfaKurulumKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final ozet = ref.watch(tayfaOzetiProvider(tayfaId));
    final tayfa = ozet.tayfa;
    if (tayfa == null) return const SizedBox.shrink();
    final davet = ref.watch(tayfaDavetiProvider);
    final moduller = gorunurModuller(
      ref.watch(tayfaModulleriProvider),
      ozet.acikModuller,
    );
    final modulAdimlari = [for (final modul in moduller) ?modul.kurulumAdimi];
    final tamamlar = [
      true,
      davetAdimiTamam(tayfa),
      for (final adim in modulAdimlari) adim.tamamMi(ref, tayfaId) ?? false,
    ];
    final tamamSayisi = tamamlar.where((t) => t).length;
    if (tamamSayisi == tamamlar.length) return const SizedBox.shrink();
    final aktif = tamamlar.indexOf(false);
    final kod = ozet.katilimKodu;

    Widget adim(
      int sira, {
      required String baslik,
      String? aciklama,
      VoidCallback? onTap,
      List<Widget> eylemler = const [],
    }) {
      return _KurulumAdimi(
        numara: sira + 1,
        baslik: baslik,
        aciklama: aciklama,
        tamam: tamamlar[sira],
        aktif: sira == aktif,
        onTap: onTap,
        eylemler: eylemler,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.kartKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
        boxShadow: r.oneCikanGolge,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.kartIci),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      m.tayfa_kurulum_baslik,
                      style: yazi.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Text(
                  m.tayfa_kurulum_ilerleme(tamamSayisi, tamamlar.length),
                  semanticsLabel: m.tayfa_kurulum_ilerleme_etiketi(
                    tamamSayisi,
                    tamamlar.length,
                  ),
                  style: yazi.labelMedium?.copyWith(color: r.metinIkincil),
                ),
              ],
            ),
            const SizedBox(height: TayfamSpacing.s12),
            adim(0, baslik: m.tayfa_kurulum_kuruldu),
            adim(
              1,
              baslik: m.tayfa_kurulum_davet_baslik,
              aciklama: m.tayfa_kurulum_davet_aciklama,
              onTap: davet == null
                  ? null
                  : () => unawaited(davet(context, tayfaId)),
              eylemler: [
                if (davet != null)
                  BirincilEylem(
                    etiket: m.tayfa_kurulum_davet_dugmesi,
                    ikon: Icons.share_outlined,
                    onPressed: () => unawaited(davet(context, tayfaId)),
                  ),
                if (kod != null)
                  OdakCercevesi(
                    koseler: TayfamRadii.hapKoseleri,
                    child: OutlinedButton(
                      onPressed: () =>
                          unawaited(koduKopyala(context, ref, kod: kod)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                        shape: const StadiumBorder(),
                        foregroundColor: r.marka,
                        side: BorderSide(
                          color: r.marka,
                          width: TayfamSizes.vurguKenari,
                        ),
                      ),
                      child: Text(
                        kod,
                        semanticsLabel: m.tayfa_kurulum_kod_kopyala(kod),
                      ),
                    ),
                  ),
              ],
            ),
            for (final (sira, kurulum) in modulAdimlari.indexed)
              adim(
                sira + 2,
                baslik: kurulum.baslik(context),
                aciklama: kurulum.aciklama(context),
                onTap: () => kurulum.ac(context, tayfaId),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kurulum kartında tek adım: tamamlanmışsa turkuaz onay dairesi ve soluk
/// başlık; aktifse tint zemin, dolu numara, açıklama ve eylemler; sonraki
/// adımlar çerçeveli numarayla, dokununca adımın akışı açılır.
class _KurulumAdimi extends StatelessWidget {
  const _KurulumAdimi({
    required this.numara,
    required this.baslik,
    required this.tamam,
    required this.aktif,
    this.aciklama,
    this.onTap,
    this.eylemler = const [],
  });

  final int numara;
  final String baslik;
  final String? aciklama;
  final bool tamam;
  final bool aktif;
  final VoidCallback? onTap;
  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final aciklama = this.aciklama;
    final Widget daire;
    if (tamam) {
      daire = DecoratedBox(
        decoration: BoxDecoration(color: r.tintTeal, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: TayfamSizes.adimDairesi,
          child: Icon(
            Icons.check,
            size: TayfamSizes.ikonKucuk,
            color: r.tintTealUstu,
          ),
        ),
      );
    } else {
      daire = DecoratedBox(
        decoration: BoxDecoration(
          color: aktif ? r.marka : null,
          shape: BoxShape.circle,
          border: aktif
              ? null
              : Border.all(
                  color: r.metinIkincil,
                  width: TayfamSizes.vurguKenari,
                ),
        ),
        child: SizedBox.square(
          dimension: TayfamSizes.adimDairesi,
          child: Center(
            child: Text(
              numara.toString(),
              textScaler: TextScaler.noScaling,
              style: yazi.labelMedium?.copyWith(
                color: aktif ? r.markaUstu : r.metinIkincil,
                fontWeight: TayfamTypography.buyukBaslikAgirligi,
              ),
            ),
          ),
        ),
      );
    }
    final icerik = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: daire),
        const SizedBox(width: TayfamSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                semanticsLabel: tamam
                    ? m.tayfa_kurulum_tamam_adim(baslik)
                    : null,
                style: tamam
                    ? yazi.bodyLarge?.copyWith(color: r.metinIkincil)
                    : yazi.titleMedium,
              ),
              if (!tamam && aciklama != null)
                Text(
                  aciklama,
                  style: yazi.bodySmall?.copyWith(
                    color: aktif ? r.metinGovde : r.metinIkincil,
                  ),
                ),
              if (aktif && eylemler.isNotEmpty) ...[
                const SizedBox(height: TayfamSpacing.s12),
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: eylemler,
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final onTap = this.onTap;
    final dokunulur = !tamam && onTap != null && eylemler.isEmpty;
    final kutu = Padding(
      padding: const EdgeInsets.all(TayfamSpacing.s12),
      child: icerik,
    );
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s4),
      child: OdakCercevesi(
        koseler: TayfamRadii.secimKoseleri,
        child: Material(
          type: aktif ? MaterialType.canvas : MaterialType.transparency,
          color: aktif ? r.tintMarka : null,
          borderRadius: TayfamRadii.secimKoseleri,
          clipBehavior: Clip.antiAlias,
          child: dokunulur
              ? Semantics(
                  button: true,
                  child: InkWell(onTap: onTap, child: kutu),
                )
              : kutu,
        ),
      ),
    );
  }
}

/// "Tayfaya ne ekleyelim?" alttan sayfasını açar (tasarım: Ana-Yonetici).
/// [secenekler] kullanıcının izinlerine göre süzülmüştür; sayfa kapanınca
/// seçilen akış bu sayfanın bağlamıyla açılır.
Future<void> _olusturmaSayfasiniAc(
  BuildContext context, {
  required String tayfaId,
  required List<OlusturmaSecenegi> secenekler,
  required TayfaDaveti? davet,
  required String? kod,
}) async {
  final secim = await altSayfaAc<void Function(BuildContext, String)>(
    context,
    builder: (sayfa) => OlusturmaSayfasi(
      secenekler: secenekler,
      davetVar: davet != null,
      kod: kod,
      onSec: (eylem) => Navigator.of(sayfa).pop(eylem),
      onDavet: () => Navigator.of(sayfa).pop(_davetEt(davet)),
    ),
  );
  if (secim == null || !context.mounted) return;
  secim(context, tayfaId);
}

void Function(BuildContext, String) _davetEt(TayfaDaveti? davet) =>
    (context, tayfaId) {
      if (davet != null) unawaited(davet(context, tayfaId));
    };

/// "Oluştur" sayfasının içeriği: modül seçenekleri iki sütunlu kartlar
/// halinde ve altta "Tayfaya davet et".
class OlusturmaSayfasi extends StatelessWidget {
  const OlusturmaSayfasi({
    super.key,
    required this.secenekler,
    required this.davetVar,
    required this.onSec,
    required this.onDavet,
    this.kod,
  });

  final List<OlusturmaSecenegi> secenekler;
  final bool davetVar;
  final String? kod;
  final ValueChanged<void Function(BuildContext, String)> onSec;
  final VoidCallback onDavet;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kod = this.kod;
    return AltSayfaIcerigi(
      baslik: m.tayfa_olustur_baslik,
      children: [
        for (var i = 0; i < secenekler.length; i += 2) ...[
          if (i > 0) const SizedBox(height: TayfamSpacing.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SecenekKarti(secenekler[i], onSec: onSec)),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: i + 1 < secenekler.length
                      ? _SecenekKarti(secenekler[i + 1], onSec: onSec)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
        if (davetVar) ...[
          if (secenekler.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s16),
            const Divider(),
          ],
          MenuSatiri(
            ikonKutusu: DecoratedBox(
              decoration: BoxDecoration(
                color: r.tintTeal,
                borderRadius: TayfamRadii.dugmeKoseleri,
              ),
              child: SizedBox.square(
                dimension: TayfamSizes.menuIkonKutusu,
                child: Icon(
                  Icons.person_add_alt_outlined,
                  color: r.tintTealUstu,
                  size: TayfamSizes.ikon,
                ),
              ),
            ),
            baslik: m.tayfa_davet_et,
            aciklama: kod == null
                ? m.tayfa_davet_link_aciklama
                : m.tayfa_davet_kod_satiri(kod),
            sag: ExcludeSemantics(child: Etiket(metin: m.tayfa_davet_paylas)),
            onTap: onDavet,
          ),
        ],
      ],
    );
  }
}

class _SecenekKarti extends StatelessWidget {
  const _SecenekKarti(this.secenek, {required this.onSec});

  final OlusturmaSecenegi secenek;
  final ValueChanged<void Function(BuildContext, String)> onSec;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: () => onSec(secenek.ac),
            child: Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          secenek.ikon,
                          color: r.tintMarkaUstu,
                          size: TayfamSizes.ikon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(secenek.baslik(context), style: yazi.titleMedium),
                  Text(
                    secenek.aciklama(context),
                    style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Kodu paylaş" ve "Kodu kopyala" (ADR-0014 §5). Mor yüzeyde paylaşım
/// mango zemin + ink, kopyalama beyaz metinli düğmedir.
class KodDugmeleri extends ConsumerWidget {
  const KodDugmeleri({
    super.key,
    required this.ad,
    required this.kod,
    this.markaYuzeyinde = false,
  });

  final String ad;
  final String kod;
  final bool markaYuzeyinde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Builder(
          builder: (dugme) => BirincilEylem(
            etiket: metinler.tayfa_kodu_paylas,
            ikon: Icons.share_outlined,
            markaYuzeyinde: markaYuzeyinde,
            onPressed: () =>
                unawaited(koduPaylas(dugme, ref, ad: ad, kod: kod)),
          ),
        ),
        OdakCercevesi(
          koseler: TayfamRadii.dugmeKoseleri,
          child: TextButton.icon(
            onPressed: () => unawaited(koduKopyala(context, ref, kod: kod)),
            icon: const Icon(Icons.copy_outlined, size: TayfamSizes.ikon),
            label: Text(metinler.tayfa_kodu_kopyala),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              foregroundColor: markaYuzeyinde
                  ? context.renkler.markaYuzeyUstu
                  : null,
              // Odak çerçevesini OdakCercevesi çizer.
              side: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _TayfaAdiDugmesi extends StatelessWidget {
  const _TayfaAdiDugmesi({
    required this.ad,
    required this.onPressed,
    this.tayfa,
    this.uyeSayisi,
  });

  final String ad;
  final Tayfa? tayfa;
  final int? uyeSayisi;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final uyeSayisi = this.uyeSayisi;
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: r.markaYuzeyUstu,
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s8,
            vertical: TayfamSpacing.s4,
          ),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
        ),
        child: Semantics(
          hint: metinler.tayfa_degistir_ipucu,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TayfaAvatari.tayfadan(tayfa, ad: ad),
              const SizedBox(width: TayfamSpacing.s12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            ad,
                            style: context.yazi.headlineSmall?.copyWith(
                              color: r.markaYuzeyUstu,
                            ),
                          ),
                        ),
                        const SizedBox(width: TayfamSpacing.s4),
                        const ExcludeSemantics(child: Icon(Icons.expand_more)),
                      ],
                    ),
                    if (uyeSayisi != null)
                      Text(
                        metinler.tayfa_uye_sayisi(uyeSayisi),
                        style: context.yazi.bodySmall?.copyWith(
                          color: r.markaYuzeyUstu,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
