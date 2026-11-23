import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yazboz bileşeni (`scoreboard`; Tayfam-Api ADR-0025 §4–§6, #250; App
/// ADR-0024 §3): oyunların el el (ya da tek maç, hedefe ilk ulaşana kadar)
/// skorlandığı masalar.
///
/// - Bileşen en fazla `max_tables` masa taşır; masayı organizatör,
///   moderatör ve yönetici açar (`caller_can_manage`), bileşen ön ayar
///   sunuyorsa (Batak, 101 Okey …) masa birini seçer. Masanın kuralları
///   masada saklanır ve kartında yazıyla özetlenir.
/// - Eli organizatör ve masaya atanmış hakem girer, masayı bitirebilir
///   (`caller_can_score`). Yeniden açma, yerleri değiştirme, son eli
///   düzeltme ve silme, hakem atama ve masayı silme organizatördedir.
///   Düğmeleri gizlemek kolaylıktır; yetkiyi sunucu verir, hatası her
///   durumda gösterilir (kesin kural 5).
/// - Sıralama her satırda sıra numarası, ad ve toplamla yazılır; kazanan
///   "Kazanan" etiketiyle (yalnızca renkle değil), çağıranın yeri "Sen"
///   etiketiyle işaretlenir. Satır ekran okuyucuda tek öğe okunur.
/// - Bölüm canlıdır: biri el girince tablo REST'ten yeniden okunur. Skor
///   girişi çevrimdışı kuyruğa girmez.
///
/// Etkinlik kartındaki satır liste yanıtı bileşen verisi taşımadığı için
/// çizilmez (ADR-0024 Notlar).
final class YazbozBileseni extends KayitliBilesen {
  const YazbozBileseni() : super('scoreboard');

  @override
  String ad(AppLocalizations m) => m.bilesen_scoreboard_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return YazbozBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Yazboz bileşeninin detaydaki bölümü: başlık (sağda masa sayısı),
/// masalar ve yetkiliye "Masa aç". Okunurken yer tutmaz; okunamazsa kısa
/// hata ve "Tekrar dene".
class YazbozBolumu extends ConsumerStatefulWidget {
  const YazbozBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final YazbozKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  /// Etkinlik: türündeki takım kurma bileşenleri takım masası için.
  final Event etkinlik;

  @override
  ConsumerState<YazbozBolumu> createState() => _YazbozBolumuState();
}

class _YazbozBolumuState extends ConsumerState<YazbozBolumu> {
  YazbozNotifier get _notifier =>
      ref.read(yazbozProvider(widget.kimlik).notifier);

  /// Bileşen misafir alıyorsa misafirlerin okunduğu yer: kendisi.
  MisafirKimligi? get _misafirler =>
      misafirAlir(widget.tanim) ? widget.kimlik : null;

  Future<void> _masaAc(EventScoreboard yazboz, List<String> takimlar) =>
      aracFormuAc<void>(
        context,
        (_) => YazbozMasaFormu(
          kimlik: widget.kimlik,
          yazboz: yazboz,
          takimAnahtarlari: takimlar,
          misafirler: _misafirler,
          gonder: (istek) => _notifier.masaKur(istek),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(yazbozProvider(widget.kimlik));
    final yazboz = okunan.value;
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_scoreboard_ad,
      sag: yazboz == null || yazboz.tables.isEmpty
          ? null
          : AracBasligiNotu(
              metin: m.bilesen_scoreboard_masa_sayisi(
                yazboz.tables.length,
                yazboz.maxTables,
              ),
            ),
    );
    if (yazboz == null) {
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
    final tur = turTaniminiIzle(
      ref,
      widget.etkinlik.type,
      surum: widget.etkinlik.typeVersion,
    );
    final takimlar = [
      for (final b in turBilesenleri(tur))
        if (b.kind == 'teams') bilesenAnahtari(b),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(
          bos: m.bilesen_scoreboard_yok,
          satirlar: [
            for (final masa in yazboz.tables)
              YazbozMasasi(
                key: ValueKey('yazboz-masa-${masa.id}'),
                kimlik: widget.kimlik,
                yazboz: yazboz,
                masa: masa,
                misafirler: _misafirler,
              ),
          ],
        ),
        if (yazbozMasaAcilabilir(yazboz)) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracDugmesi(
            etiket: m.bilesen_scoreboard_masa_ac,
            ikon: Icons.add,
            onPressed: () => unawaited(_masaAc(yazboz, takimlar)),
          ),
        ],
      ],
    );
  }
}

/// Masa işlemleri menüsünün seçenekleri.
enum _MasaIslemi {
  yerler,
  duzelt,
  sonEliSil,
  yenidenAc,
  adlandir,
  hakemler,
  sil,
}

/// Bir masa: adı, durumu ("Sürüyor" / "Bitti"), oyunu ve kuralları,
/// sıralama, eller (açılır) ve yetkiliye göre işlemler.
class YazbozMasasi extends ConsumerStatefulWidget {
  const YazbozMasasi({
    super.key,
    required this.kimlik,
    required this.yazboz,
    required this.masa,
    this.misafirler,
  });

  final YazbozKimligi kimlik;
  final EventScoreboard yazboz;
  final EventScoreTable masa;

  /// Bileşen misafir alıyorsa misafirlerin okunduğu yer; değilse `null`.
  final MisafirKimligi? misafirler;

  @override
  ConsumerState<YazbozMasasi> createState() => _YazbozMasasiState();
}

class _YazbozMasasiState extends ConsumerState<YazbozMasasi> {
  bool _eller = false;
  bool _mesgul = false;

  YazbozNotifier get _notifier =>
      ref.read(yazbozProvider(widget.kimlik).notifier);

  EventScoreTable get _masa => widget.masa;

  /// [islem]'i çalıştırır; hatada kısa bildirim. Aynı anda tek işlem.
  Future<void> _calistir(Future<Object?> Function() islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem();
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _elGir() => aracFormuAc<void>(
    context,
    (_) => YazbozElFormu(
      kimlik: widget.kimlik,
      masa: _masa,
      misafirler: widget.misafirler,
      el: (yazbozSonEl(_masa)?.number ?? 0) + 1,
      gonder: (istek) => _notifier.elGir(_masa.id, istek),
    ),
  );

  Future<void> _bitir() async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_scoreboard_bitir_onay,
      metin: m.bilesen_scoreboard_bitir_aciklama,
      eylem: m.bilesen_scoreboard_bitir,
    );
    if (!onay || !mounted) return;
    await _calistir(() => _notifier.masayiBitir(_masa.id));
  }

  Future<void> _islem(_MasaIslemi islem) async {
    final m = AppLocalizations.of(context);
    final masa = _masa;
    switch (islem) {
      case _MasaIslemi.yerler:
        await aracFormuAc<void>(
          context,
          (_) => YazbozMasaFormu(
            kimlik: widget.kimlik,
            yazboz: widget.yazboz,
            masa: masa,
            takimAnahtarlari: [?masa.teamsKey],
            misafirler: widget.misafirler,
            yerleriGonder: (yerler) =>
                _notifier.yerleriBelirle(masa.id, yerler),
          ),
        );
      case _MasaIslemi.duzelt:
        final son = yazbozSonEl(masa);
        if (son == null) return;
        await aracFormuAc<void>(
          context,
          (_) => YazbozElFormu(
            kimlik: widget.kimlik,
            masa: masa,
            misafirler: widget.misafirler,
            el: son.number,
            duzeltilen: son,
            gonder: (istek) => _notifier.eliDuzelt(masa.id, son.number, istek),
          ),
        );
      case _MasaIslemi.sonEliSil:
        final silinen = yazbozSonEl(masa);
        if (silinen == null) return;
        final silinsin = await cikarmaOnayi(
          context,
          baslik: m.bilesen_scoreboard_son_eli_sil_onay(silinen.number),
          metin: m.bilesen_scoreboard_son_eli_sil_aciklama,
          eylem: m.bilesen_scoreboard_sil,
        );
        if (!silinsin || !mounted) return;
        await _calistir(() => _notifier.sonEliSil(masa.id, silinen.number));
      case _MasaIslemi.yenidenAc:
        await _calistir(
          () => _notifier.masayiGuncelle(
            masa.id,
            const EventScoreTableUpdate(
              status: EventScoreTableUpdateStatus.open,
            ),
          ),
        );
      case _MasaIslemi.adlandir:
        await aracFormuAc<void>(
          context,
          (_) => YazbozAdFormu(
            ad: masa.label,
            gonder: (ad) => _notifier.masayiGuncelle(
              masa.id,
              EventScoreTableUpdate(label: ad),
            ),
          ),
        );
      case _MasaIslemi.hakemler:
        await aracFormuAc<void>(
          context,
          (_) => YazbozHakemFormu(kimlik: widget.kimlik, masa: masa),
        );
      case _MasaIslemi.sil:
        final onay = await cikarmaOnayi(
          context,
          baslik: m.bilesen_scoreboard_masayi_sil_onay,
          metin: m.bilesen_scoreboard_masayi_sil_aciklama,
          eylem: m.bilesen_scoreboard_sil,
        );
        if (!onay || !mounted) return;
        await _calistir(() => _notifier.masayiSil(masa.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final masa = _masa;
    final bitti = masa.status == EventScoreTableStatus.finished;
    final acik = masa.status == EventScoreTableStatus.open;
    final on = yazbozOnAyari(widget.yazboz, masa.presetKey);
    final oyun = on == null
        ? null
        : katalogAdi(on.labels, katalogDili(context));
    final ozet = [?oyun, ...yazbozKuralOzeti(m, masa.rules)].join(' · ');
    final eller = yazbozElleri(masa);
    final yonetebilir = widget.yazboz.callerCanManage;
    final siralama = yazbozSiralamasi(masa);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                container: true,
                child: Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(masa.label, style: yazi.titleSmall),
                    ),
                    Etiket(
                      metin: bitti
                          ? m.bilesen_scoreboard_durum_finished
                          : m.bilesen_scoreboard_durum_open,
                      ton: bitti ? EtiketTonu.notr : EtiketTonu.teal,
                      ikon: bitti ? Icons.flag_outlined : null,
                    ),
                  ],
                ),
              ),
            ),
            if (yonetebilir)
              PopupMenuButton<_MasaIslemi>(
                key: ValueKey('yazboz-islemler-${masa.id}'),
                tooltip: m.bilesen_scoreboard_islemler(masa.label),
                enabled: !_mesgul,
                onSelected: (islem) => unawaited(_islem(islem)),
                itemBuilder: (_) => [
                  if (eller.isEmpty)
                    PopupMenuItem(
                      value: _MasaIslemi.yerler,
                      child: Text(m.bilesen_scoreboard_yerler),
                    ),
                  if (eller.isNotEmpty) ...[
                    PopupMenuItem(
                      value: _MasaIslemi.duzelt,
                      child: Text(m.bilesen_scoreboard_son_eli_duzelt),
                    ),
                    PopupMenuItem(
                      value: _MasaIslemi.sonEliSil,
                      child: Text(m.bilesen_scoreboard_son_eli_sil),
                    ),
                  ],
                  if (bitti)
                    PopupMenuItem(
                      value: _MasaIslemi.yenidenAc,
                      child: Text(m.bilesen_scoreboard_yeniden_ac),
                    ),
                  PopupMenuItem(
                    value: _MasaIslemi.adlandir,
                    child: Text(m.bilesen_scoreboard_adlandir),
                  ),
                  PopupMenuItem(
                    value: _MasaIslemi.hakemler,
                    child: Text(m.bilesen_scoreboard_hakemler),
                  ),
                  PopupMenuItem(
                    value: _MasaIslemi.sil,
                    child: Text(m.bilesen_scoreboard_masayi_sil),
                  ),
                ],
              ),
          ],
        ),
        if (ozet.isNotEmpty)
          Text(ozet, style: yazi.bodySmall?.copyWith(color: r.metinGovde)),
        const SizedBox(height: TayfamSpacing.s8),
        if (masa.players.isEmpty)
          AracBilgisi(metin: m.bilesen_scoreboard_oyuncu_yok)
        else ...[
          Semantics(
            header: true,
            child: Text(
              m.bilesen_scoreboard_siralama,
              style: yazi.labelLarge?.copyWith(color: r.metinGovde),
            ),
          ),
          for (final satir in siralama)
            YazbozSiraSatiri(
              key: ValueKey('yazboz-sira-${satir.sira.playerId}'),
              satir: satir,
              kural: masa.rules,
              takimlar: _takimKimligi(widget.kimlik, masa),
              misafirler: widget.misafirler,
            ),
        ],
        if (eller.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: _eller
                  ? m.bilesen_scoreboard_elleri_gizle
                  : m.bilesen_scoreboard_elleri_goster(eller.length),
              onPressed: () => setState(() => _eller = !_eller),
            ),
          ),
        if (_eller)
          for (final el in eller.reversed)
            YazbozElSatiri(
              key: ValueKey('yazboz-el-${masa.id}-${el.number}'),
              el: el,
              masa: masa,
              takimlar: _takimKimligi(widget.kimlik, masa),
              misafirler: widget.misafirler,
            ),
        if (masa.callerCanScore && acik) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              if (masa.players.isNotEmpty)
                CerceveliHapEylem(
                  etiket: m.bilesen_scoreboard_el_gir,
                  ikon: Icons.add,
                  onPressed: _mesgul ? null : () => unawaited(_elGir()),
                ),
              CerceveliHapEylem(
                etiket: m.bilesen_scoreboard_bitir,
                ikon: Icons.flag_outlined,
                onPressed: _mesgul ? null : () => unawaited(_bitir()),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Takım masasında takımların okunduğu bileşen; oyuncu masasında `null`.
TakimKimligi? _takimKimligi(YazbozKimligi kimlik, EventScoreTable masa) {
  final anahtar = masa.teamsKey;
  if (anahtar == null) return null;
  return (
    tayfaId: kimlik.tayfaId,
    etkinlikId: kimlik.etkinlikId,
    anahtar: anahtar,
  );
}

/// Yer çağıranın mı (kişi masasında kendisi, takım masasında takımı).
bool _benimYerim(WidgetRef ref, EventScorePlayer? yer, TakimKimligi? t) {
  final kisi = yer?.userId;
  if (kisi != null) return ref.watch(kendisiMiProvider(kisi));
  final takim = yazbozTakimi(ref, t, yer?.teamId);
  if (takim == null) return false;
  var benim = false;
  for (final uye in takim.memberIds) {
    if (ref.watch(kendisiMiProvider(uye))) benim = true;
  }
  return benim;
}

/// Sıralamanın bir satırı: sıra numarası, ad, toplam (BO maçında
/// kazanılan el) ve etiketler. Satır ekran okuyucuda tek öğe okunur
/// ("1., Ayşe, 120 puan, Kazanan").
class YazbozSiraSatiri extends ConsumerWidget {
  const YazbozSiraSatiri({
    super.key,
    required this.satir,
    required this.kural,
    required this.takimlar,
    this.misafirler,
  });

  final YazbozSirasi satir;
  final EventScoreRules kural;
  final TakimKimligi? takimlar;
  final MisafirKimligi? misafirler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    final sira = satir.sira;
    final benim = _benimYerim(ref, satir.yer, takimlar);
    final rakam = yazi.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final bo = kural.bestOf;
    final toplam = [
      m.bilesen_scoreboard_puan(yazbozSayisi(m, sira.total)),
      if (bo != null && bo > 1) m.bilesen_scoreboard_el_kazandi(sira.roundsWon),
    ].join(' · ');
    // Dar ekranda ve büyük yazıda taşmasın diye toplam adın altındadır.
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.bilesen_scoreboard_sira(sira.rank),
              style: rakam?.copyWith(color: r.metinGovde),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: TayfamSpacing.s8,
                    runSpacing: TayfamSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      YazbozYerAdi(
                        yer: satir.yer,
                        takimlar: takimlar,
                        misafirler: misafirler,
                        style: satir.kazanan
                            ? yazi.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              )
                            : yazi.bodyMedium,
                      ),
                      if (satir.kazanan)
                        Etiket(
                          metin: m.bilesen_scoreboard_kazanan,
                          ton: EtiketTonu.mango,
                          ikon: Icons.emoji_events_outlined,
                        ),
                      if (benim) Etiket(metin: m.bilesen_scoreboard_sen),
                    ],
                  ),
                  Text(toplam, style: rakam?.copyWith(color: r.metinGovde)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir el: başlık ("El 3") ve her yerin skoru, yer sırasıyla. El ekran
/// okuyucuda tek öğe okunur ("El 3, Ayşe, 120, Can, 80").
class YazbozElSatiri extends StatelessWidget {
  const YazbozElSatiri({
    super.key,
    required this.el,
    required this.masa,
    required this.takimlar,
    this.misafirler,
  });

  final EventScoreRound el;
  final EventScoreTable masa;
  final TakimKimligi? takimlar;
  final MisafirKimligi? misafirler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final skorlar = {for (final s in el.scores) s.playerId: s};
    return Padding(
      padding: const EdgeInsets.only(bottom: TayfamSpacing.s8),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m.bilesen_scoreboard_el(el.number), style: yazi.labelLarge),
            for (final yer in yazbozYerleri(masa))
              Row(
                children: [
                  Expanded(
                    child: YazbozYerAdi(
                      yer: yer,
                      takimlar: takimlar,
                      misafirler: misafirler,
                      style: yazi.bodySmall,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Text(
                    yazbozSkorMetni(m, skorlar[yer.id]),
                    style: yazi.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
