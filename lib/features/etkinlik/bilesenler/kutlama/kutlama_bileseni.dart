import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kura/kura_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_ortak.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kutlama bileşeni (`celebration`; Tayfam-Api ADR-0025 §4, §5, #255; App
/// ADR-0024 §3): etkinliğin kazanan kartı ve kazananın tayfaya ilanı.
///
/// - **Kaynaklı** (`source`): kazananlar aynı türdeki yazboz, eşleşme
///   ağacı, derece ya da oylama bileşeninin kaydedilmiş sonucundan her
///   okumada hesaplanır (biten masaların kazananları, ağacın şampiyonları,
///   derecenin birincisi); kaynaktaki düzeltme hemen görünür.
/// - **Elle**: organizatör ilan ederken etkinliğe gelenlerden 1–10 kişi
///   seçer; yeniden ilan yalnızca seçimi değiştirir.
///
/// Kazanan kişi, takım ya da misafir oyuncu olabilir. İlanı organizatör,
/// moderatör ya da yönetici yapar (`caller_can_announce`); ilan geri
/// alınamaz, bu yüzden onay istenir. İlk ilan tayfaya uygulama içi
/// bildirim gönderir; bildirim kazananı adlandırmaz. Gizli kutlamada
/// (`hidden`) kazanan gösterilmez, nedeni yazılır.
///
/// Kazanan kartı ekran okuyucuda tek öğe okunur ("Kazanan, Ayşe, İlan
/// edildi: …"). Kartın girişi tek seferlik kısa bir geçiştir
/// ([TayfamMotion.uzun]); "hareketi azalt" açıkken kart doğrudan görünür.
/// Düğmeleri gizlemek kolaylıktır; yetkiyi sunucu verir (kesin kural 5).
final class KutlamaBileseni extends KayitliBilesen {
  const KutlamaBileseni() : super('celebration');

  @override
  String ad(AppLocalizations m) => m.bilesen_celebration_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return KutlamaBolumu(
      kimlik: (
        tayfaId: tayfaId,
        etkinlikId: etkinlik.id,
        anahtar: b.anahtar,
        kaynak: b.params.metin('source'),
      ),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Etkinliğin türündeki takım kurma bileşenleri (takım kazananının adı
/// bunlardan okunur). Tür ya da katalog henüz okunmadıysa boş.
List<TakimKimligi> kutlamaTakimBilesenleri(WidgetRef ref, KutlamaKimligi k) {
  final tur = etkinlikTuru(ref, (tayfaId: k.tayfaId, etkinlikId: k.etkinlikId));
  if (tur == null) return const [];
  final tanim = turTaniminiIzle(ref, tur.tur, surum: tur.surum);
  return [
    for (final b in turBilesenleri(tanim))
      if (b.kind == 'teams')
        (
          tayfaId: k.tayfaId,
          etkinlikId: k.etkinlikId,
          anahtar: bilesenAnahtari(b),
        ),
  ];
}

/// Kazananın metin olarak adı: kişinin adı (hesabını silmişse "Silinmiş
/// kullanıcı"), takımın adı ya da numarası, misafirin takma adı ("Deniz
/// (misafir)"). Takım bulunamazsa "Takım".
String kutlamaKazananAdi(
  WidgetRef ref,
  AppLocalizations m,
  EventCelebrationWinner kazanan, {
  required List<TakimKimligi> takimlar,
  MisafirKimligi? misafirler,
}) {
  final misafir = kazanan.guestId;
  if (misafir != null) return misafirAdiMetni(ref, m, misafirler, misafir);
  final kisi = kazanan.userId;
  if (kisi != null) {
    ref.read(kullaniciAdlariProvider.notifier).iste(kisi);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[kisi]),
    );
    return switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
  }
  final takimId = kazanan.teamId;
  if (takimId != null) {
    for (final kimlik in takimlar) {
      final liste =
          ref.watch(takimProvider(kimlik)).value?.teams ?? const <EventTeam>[];
      for (final t in liste) {
        if (t.id == takimId) return takimEtiketi(m, t.position, t.name);
      }
    }
  }
  return m.bilesen_celebration_takim;
}

/// Kutlama bileşeninin detaydaki bölümü: başlık, kazanan kartı ya da
/// durumu söyleyen metin ve yetkiliye ilan düğmesi. Okunurken yer tutmaz;
/// okunamazsa kısa hata ve "Tekrar dene".
class KutlamaBolumu extends ConsumerStatefulWidget {
  const KutlamaBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final KutlamaKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<KutlamaBolumu> createState() => _KutlamaBolumuState();
}

class _KutlamaBolumuState extends ConsumerState<KutlamaBolumu> {
  bool _mesgul = false;

  KutlamaNotifier get _notifier =>
      ref.read(kutlamaProvider(widget.kimlik).notifier);

  /// Kaynaklı kutlamada kazananı onayla ilan eder; hatada kısa bildirim.
  Future<void> _kaynaktanIlanEt() async {
    if (_mesgul) return;
    final onay = await kutlamaIlanOnayi(context);
    if (!onay || !mounted) return;
    setState(() => _mesgul = true);
    final hata = await _notifier.ilanEt();
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  /// Elle seçilen kutlamada kazanan seçme formunu açar. İlk ilanda form
  /// gönderirken onay ister; yeniden ilan yalnızca seçimi değiştirir.
  Future<void> _formuAc(EventCelebration kutlama) {
    final m = AppLocalizations.of(context);
    return aracFormuAc<void>(
      context,
      (_) => KutlamaFormu(
        baslik: kutlama.announced
            ? m.bilesen_celebration_degistir
            : m.bilesen_celebration_sec,
        katilimcilar: (
          tayfaId: widget.kimlik.tayfaId,
          etkinlikId: widget.kimlik.etkinlikId,
          durum: ListEventAttendeesStatus.going,
        ),
        ilkSecim: kutlamaKisileri(kutlama),
        onayGerekli: !kutlama.announced,
        gonder: _notifier.ilanEt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_celebration_ad,
    );
    final okunan = ref.watch(kutlamaProvider(widget.kimlik));
    final kutlama = okunan.value;
    if (kutlama == null) {
      if (!okunan.hasError) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          HataSatiri.hatadan(okunan.error!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.etkinlik_tekrar_dene,
              onPressed: () => unawaited(_notifier.yenile()),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [baslik, ..._icerik(kutlama)],
    );
  }

  List<Widget> _icerik(EventCelebration kutlama) {
    final m = AppLocalizations.of(context);
    if (!kutlamaKaynagiTanindi(kutlama)) {
      return [AracBilgisi(metin: m.bilesen_celebration_guncelle)];
    }
    if (kutlama.hidden) {
      return [AracBilgisi(metin: m.bilesen_celebration_gizli)];
    }
    final kaynakli = kutlamaKaynakli(kutlama);
    final etkinlik = widget.etkinlik;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final baslamadi =
        !iptalEdildi(etkinlik) && simdi.isBefore(etkinlik.startsAt);
    final ilanEdebilir = kutlama.callerCanAnnounce;
    final kazananVar = kutlama.winners.isNotEmpty;
    return [
      if (kazananVar)
        KutlamaKarti(kimlik: widget.kimlik, kutlama: kutlama)
      else
        AracBilgisi(
          metin: baslamadi
              ? m.bilesen_celebration_baslamadi
              : kaynakli
              ? m.bilesen_celebration_sonuc_bekleniyor
              : m.bilesen_celebration_ilan_bekleniyor,
        ),
      if (ilanEdebilir && !kutlama.announced && (kazananVar || !kaynakli)) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracBilgisi(metin: m.bilesen_celebration_ilan_notu),
      ],
      if (ilanEdebilir && kaynakli && kazananVar && !kutlama.announced) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: m.bilesen_celebration_ilan_et,
          ikon: Icons.emoji_events_outlined,
          onPressed: _mesgul ? null : () => unawaited(_kaynaktanIlanEt()),
        ),
      ],
      if (ilanEdebilir && !kaynakli) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: kutlama.announced
              ? m.bilesen_celebration_degistir
              : m.bilesen_celebration_sec,
          ikon: kutlama.announced
              ? Icons.edit_outlined
              : Icons.emoji_events_outlined,
          onPressed: _mesgul ? null : () => unawaited(_formuAc(kutlama)),
        ),
      ],
    ];
  }
}

/// Kazanan kartı: kupa simgesi, "Kazanan" / "Kazananlar", her kazananın
/// adı (yazboz kaynağında kazanılan masa da) ve ilan edildiyse ilan
/// zamanı. Kart ekran okuyucuda tek öğe okunur; simge süstür.
///
/// Kart ilk göründüğünde [TayfamMotion.uzun] süren tek seferlik bir
/// geçişle (saydamlık ve hafif büyüme) gelir; döngü yoktur. "Hareketi
/// azalt" açıkken geçiş oynamaz.
class KutlamaKarti extends ConsumerWidget {
  const KutlamaKarti({super.key, required this.kimlik, required this.kutlama});

  final KutlamaKimligi kimlik;
  final EventCelebration kutlama;

  /// Geçişin başındaki ölçek (sonda 1).
  static const double _ilkOlcek = .94;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final takimVar = kutlama.winners.any((k) => k.teamId != null);
    final takimlar = takimVar
        ? kutlamaTakimBilesenleri(ref, kimlik)
        : const <TakimKimligi>[];
    final misafirVar = kutlama.winners.any((k) => k.guestId != null);
    final misafirler = misafirVar
        ? etkinlikMisafirleri(ref, kimlik.tayfaId, kimlik.etkinlikId)
        : null;
    final masalar = _masaAdlari(ref);
    final adlar = [
      for (final k in kutlama.winners)
        _satir(
          m,
          kutlamaKazananAdi(
            ref,
            m,
            k,
            takimlar: takimlar,
            misafirler: misafirler,
          ),
          masalar[k.tableId],
        ),
    ];
    final ilanZamani = kutlama.announcedAt;
    final hareketsiz = MediaQuery.disableAnimationsOf(context);
    final kart = MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMango,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.emoji_events, color: r.tintMangoUstu),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adlar.length == 1
                          ? m.bilesen_celebration_kazanan
                          : m.bilesen_celebration_kazananlar,
                      style: yazi.labelLarge?.copyWith(color: r.tintMangoUstu),
                    ),
                    const SizedBox(height: TayfamSpacing.s4),
                    for (final ad in adlar)
                      Text(
                        ad,
                        style: yazi.titleMedium?.copyWith(
                          color: r.metin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (kutlama.announced && ilanZamani != null) ...[
                      const SizedBox(height: TayfamSpacing.s8),
                      Text(
                        m.bilesen_celebration_ilan_edildi(
                          kuraZamani(m, ilanZamani),
                        ),
                        style: yazi.bodySmall?.copyWith(color: r.metin),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: hareketsiz ? 1 : 0, end: 1),
      duration: hareketsiz ? Duration.zero : TayfamMotion.uzun,
      curve: TayfamMotion.egri,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: _ilkOlcek + (1 - _ilkOlcek) * t,
          child: child,
        ),
      ),
      child: RepaintBoundary(child: kart),
    );
  }

  String _satir(AppLocalizations m, String ad, String? masa) =>
      masa == null ? ad : m.bilesen_celebration_masada(ad, masa);

  /// Yazboz kaynağında kazanılan masaların adları (masa kimliği → ad).
  /// Kaynak yazboz değilse ya da masa yoksa boş; yazboz yalnızca o zaman
  /// okunur.
  Map<String?, String> _masaAdlari(WidgetRef ref) {
    final kaynak = kutlama.source;
    if (kaynak == null ||
        kutlama.sourceKind != EventCelebrationSourceKind.scoreboard ||
        !kutlama.winners.any((k) => k.tableId != null)) {
      return const {};
    }
    final yazboz = ref
        .watch(
          yazbozProvider((
            tayfaId: kimlik.tayfaId,
            etkinlikId: kimlik.etkinlikId,
            anahtar: kaynak,
          )),
        )
        .value;
    return {
      for (final t in yazboz?.tables ?? const <EventScoreTable>[])
        t.id: t.label,
    };
  }
}
