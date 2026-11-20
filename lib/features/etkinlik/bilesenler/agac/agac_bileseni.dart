import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_ortak.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Eşleşme ağacı bileşeni (`bracket`; Tayfam-Api ADR-0025 §4–§6,
/// ADR-0037 §3, #251; App ADR-0024 §3): kuradan tohumlanan turnuva.
///
/// - Biçim (eleme, lig, İsviçre) ve maç başına oyun (tek oyun, BO3, BO5)
///   tanım bırakıyorsa sihirbazda seçilir ([formBolumu]).
/// - Kura çekilmeden ağaç başlamaz; bölüm bunu açıkça yazar. Skor kuralı
///   türün ilk yazboz bileşeninden gelir ve başlatınca sabitlenir; onay
///   penceresi bunu söyler.
/// - Ağaç dar ekranda ve büyük yazıda okunabilsin diye yatay kaydırma
///   yerine tur tur listelenir. Her maç ekran okuyucuda tek cümle okunur
///   (tur, taraflar, skor, kazanan); kazanan yalnızca renkle değil
///   "Kazanan" etiketiyle işaretlenir, çağıranın yeri "Sen" etiketiyle.
/// - Oyunu organizatör ve maçın hakemi girer (`caller_can_score`); turu
///   eşleme, son oyunu düzeltme/silme ve ağacı sıfırlama (kura kalır)
///   organizatördedir (`caller_can_manage`). Düğmeleri gizlemek
///   kolaylıktır; yetkiyi sunucu verir, hatası her durumda gösterilir
///   (kesin kural 5).
/// - Bölüm canlıdır: biri oyun girince ya da kura çekilince ağaç
///   REST'ten yeniden okunur. Oyun girişi çevrimdışı kuyruğa girmez.
///
/// Etkinlik kartındaki satır liste yanıtı bileşen verisi taşımadığı için
/// çizilmez (ADR-0024 Notlar).
final class AgacBileseni extends KayitliBilesen {
  const AgacBileseni() : super('bracket');

  @override
  String ad(AppLocalizations m) => m.bilesen_bracket_ad;

  @override
  Widget? formBolumu(BilesenBaglami b) => AgacSecimleri(baglam: b);

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return AgacBolumu(
      tayfaId: tayfaId,
      etkinlik: etkinlik,
      anahtar: b.anahtar,
      tanim: b.tanim,
    );
  }
}

/// Sihirbazda organizatöre bırakılan biçim ve maç başına oyun seçimi.
class AgacSecimleri extends StatelessWidget {
  const AgacSecimleri({super.key, required this.baglam});

  final BilesenBaglami baglam;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BilesenSecimAlani(
          baglam: baglam,
          param: 'format',
          baslik: m.bilesen_bracket_format_baslik,
          etiketler: {
            EventBracketFormat.elimination.wire:
                m.bilesen_bracket_format_elimination,
            EventBracketFormat.league.wire: m.bilesen_bracket_format_league,
            EventBracketFormat.swiss.wire: m.bilesen_bracket_format_swiss,
          },
        ),
        BilesenSecimAlani(
          baglam: baglam,
          param: 'best_of',
          baslik: m.bilesen_bracket_bo_baslik,
          etiketler: {
            '1': agacBoAdi(m, 1),
            '3': agacBoAdi(m, 3),
            '5': agacBoAdi(m, 5),
          },
        ),
      ],
    );
  }
}

/// Eşleşme ağacının detaydaki bölümü: başlık (sağda biçim), kurallar,
/// durum (kura bekleniyor, başlamadı, şampiyon), sıralama (lig ve
/// İsviçre), turlar ve yetkiliye eylemler. Okunurken yer tutmaz;
/// okunamazsa kısa hata ve "Tekrar dene".
class AgacBolumu extends ConsumerStatefulWidget {
  const AgacBolumu({
    super.key,
    required this.tayfaId,
    required this.etkinlik,
    required this.anahtar,
    required this.tanim,
  });

  final String tayfaId;

  /// Etkinlik: türündeki ilk kura bileşeni ağacın tohumudur.
  final Event etkinlik;

  /// Bileşenin anahtarı (`{component_key}`).
  final String anahtar;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  @override
  ConsumerState<AgacBolumu> createState() => _AgacBolumuState();
}

class _AgacBolumuState extends ConsumerState<AgacBolumu> {
  bool _mesgul = false;

  /// Kullanıcının açıp kapattığı turlar (tur → açık mı); verilmeyen tur
  /// varsayılanıyla ([_varsayilanAcik]) çizilir.
  final Map<int, bool> _turlar = {};

  AgacKimligi _kimlik() {
    final tur = turTaniminiIzle(
      ref,
      widget.etkinlik.type,
      surum: widget.etkinlik.typeVersion,
    );
    String? kura;
    for (final b in turBilesenleri(tur)) {
      if (b.kind == 'draw') {
        kura = bilesenAnahtari(b);
        break;
      }
    }
    return (
      tayfaId: widget.tayfaId,
      etkinlikId: widget.etkinlik.id,
      anahtar: widget.anahtar,
      kura: kura,
    );
  }

  /// [islem]'i çalıştırır; hatada kısa bildirim. Aynı anda tek işlem.
  Future<void> _calistir(Future<Object?> Function() islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem();
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _baslat(AgacNotifier notifier) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_bracket_baslat_onay,
      metin: m.bilesen_bracket_baslat_aciklama,
      eylem: m.bilesen_bracket_baslat,
    );
    if (!onay || !mounted) return;
    await _calistir(notifier.baslat);
  }

  Future<void> _sifirla(AgacNotifier notifier) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_bracket_sifirla_onay,
      metin: m.bilesen_bracket_sifirla_aciklama,
      eylem: m.bilesen_bracket_sifirla,
    );
    if (!onay || !mounted) return;
    await _calistir(notifier.sifirla);
  }

  /// Açık olan tur: sonuçlanmamış maçı olan tur, değilse son tur.
  bool _varsayilanAcik(AgacTuru tur, int sonTur) {
    if (tur.maclar.any((m) => !m.decided)) return true;
    return tur.no == sonTur;
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kimlik = _kimlik();
    final okunan = ref.watch(agacProvider(kimlik));
    final notifier = ref.read(agacProvider(kimlik).notifier);
    final agac = okunan.value;
    final bicim = agac == null ? null : agacBicimAdi(m, agac.format);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_bracket_ad,
      sag: bicim == null ? null : AracBasligiNotu(metin: bicim),
    );
    if (agac == null) {
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
              onPressed: () => unawaited(notifier.yenile()),
            ),
          ),
        ],
      );
    }
    final yazi = context.yazi;
    final r = context.renkler;
    final turlar = agacTurlari(agac);
    final sonTur = turlar.isEmpty ? 0 : turlar.last.no;
    final ozet = agacKuralOzeti(m, agac).join(' · ');
    final siralama = [...agac.standings]
      ..sort((a, b) {
        final fark = a.rank.compareTo(b.rank);
        return fark != 0 ? fark : a.position.compareTo(b.position);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        if (ozet.isNotEmpty)
          Text(ozet, style: yazi.bodySmall?.copyWith(color: r.metinGovde)),
        const SizedBox(height: TayfamSpacing.s8),
        if (!agac.started) ...[
          AracBilgisi(metin: _baslamadiMetni(m, agac)),
          if (agac.callerCanManage && agac.drawn) ...[
            const SizedBox(height: TayfamSpacing.s12),
            AracDugmesi(
              etiket: m.bilesen_bracket_baslat,
              ikon: Icons.account_tree_outlined,
              onPressed: _mesgul ? null : () => unawaited(_baslat(notifier)),
            ),
          ],
        ] else ...[
          if (agac.finished)
            AgacSampiyonu(kimlik: kimlik, agac: agac)
          else
            AracBilgisi(
              metin: m.bilesen_bracket_tur_durumu(
                agac.currentRound,
                agac.rounds,
              ),
            ),
          if (siralama.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Semantics(
              header: true,
              child: Text(
                m.bilesen_bracket_siralama,
                style: yazi.labelLarge?.copyWith(color: r.metinGovde),
              ),
            ),
            for (final s in siralama)
              AgacSiraSatiri(
                key: ValueKey('agac-sira-${s.position}'),
                kimlik: kimlik,
                agac: agac,
                sira: s,
              ),
          ],
          for (final tur in turlar) ...[
            const SizedBox(height: TayfamSpacing.s12),
            _TurBasligi(
              tur: tur,
              toplam: agac.rounds,
              acik: _turlar[tur.no] ?? _varsayilanAcik(tur, sonTur),
              onDegis: (acik) => setState(() => _turlar[tur.no] = acik),
            ),
            if (_turlar[tur.no] ?? _varsayilanAcik(tur, sonTur))
              for (final mac in tur.maclar)
                AgacMaci(
                  key: ValueKey('agac-mac-${mac.id}'),
                  kimlik: kimlik,
                  agac: agac,
                  mac: mac,
                ),
          ],
          if (agacSonrakiTurEslenebilir(agac)) ...[
            const SizedBox(height: TayfamSpacing.s12),
            AracDugmesi(
              etiket: m.bilesen_bracket_sonraki_tur,
              ikon: Icons.skip_next_outlined,
              onPressed: _mesgul
                  ? null
                  : () => unawaited(_calistir(notifier.sonrakiTur)),
            ),
          ],
          if (agac.callerCanManage) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CerceveliHapEylem(
                etiket: m.bilesen_bracket_sifirla,
                ikon: Icons.restart_alt,
                onPressed: _mesgul ? null : () => unawaited(_sifirla(notifier)),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Başlamamış ağacın durumu: türde kura yok, kura bekleniyor ya da
/// başlatılmayı bekliyor.
String _baslamadiMetni(AppLocalizations m, EventBracket agac) {
  if (agac.drawKey == null) return m.bilesen_bracket_kura_yok;
  if (!agac.drawn) return m.bilesen_bracket_kura_bekleniyor;
  return m.bilesen_bracket_baslamadi(agac.entrants.length);
}

/// Turun başlığı ("Tur 2/3", "3/4 maç sonuçlandı") ve turu gösterip
/// gizleyen bağlantı.
class _TurBasligi extends StatelessWidget {
  const _TurBasligi({
    required this.tur,
    required this.toplam,
    required this.acik,
    required this.onDegis,
  });

  final AgacTuru tur;
  final int toplam;
  final bool acik;
  final ValueChanged<bool> onDegis;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            toplam >= tur.no
                ? m.bilesen_bracket_tur_toplam(tur.no, toplam)
                : m.bilesen_bracket_tur(tur.no),
            style: yazi.titleSmall,
          ),
        ),
        Text(
          m.bilesen_bracket_biten_mac(agacBitenMaclar(tur), tur.maclar.length),
          style: yazi.bodySmall?.copyWith(color: r.metinGovde),
        ),
        BaglantiEylemi(
          etiket: acik
              ? m.bilesen_bracket_turu_gizle(tur.no)
              : m.bilesen_bracket_turu_goster(tur.no),
          onPressed: () => onDegis(!acik),
        ),
      ],
    );
  }
}

/// Bitmiş ağacın şampiyonu (tam eşitlikte birden çok), kupa simgesi ve
/// yazıyla.
class AgacSampiyonu extends ConsumerWidget {
  const AgacSampiyonu({super.key, required this.kimlik, required this.agac});

  final AgacKimligi kimlik;
  final EventBracket agac;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final takimlar = agacTakimlari(kimlik, agac);
    final misafirler = agacMisafirleri(ref, kimlik);
    final adlar = [
      for (final sira in agac.winnerPositions)
        agacYerAdi(ref, m, agac, takimlar, sira, misafirler: misafirler),
    ];
    final metin = adlar.isEmpty
        ? m.bilesen_bracket_bitti
        : adlar.length == 1
        ? m.bilesen_bracket_sampiyon(adlar.single)
        : m.bilesen_bracket_sampiyonlar(adlar.join(', '));
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.emoji_events_outlined,
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lig ya da İsviçre sıralamasının bir satırı: sıra, ad, puan ve
/// galibiyet/beraberlik/mağlubiyet; Buchholz İsviçre'de. Satır ekran
/// okuyucuda tek öğe okunur.
class AgacSiraSatiri extends ConsumerWidget {
  const AgacSiraSatiri({
    super.key,
    required this.kimlik,
    required this.agac,
    required this.sira,
  });

  final AgacKimligi kimlik;
  final EventBracket agac;
  final EventBracketStanding sira;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    final takimlar = agacTakimlari(kimlik, agac);
    final ad = agacYerAdi(
      ref,
      m,
      agac,
      takimlar,
      sira.position,
      misafirler: agacMisafirleri(ref, kimlik),
    );
    final benim = agacBenimYerim(ref, agac, takimlar, sira.position);
    final sampiyon = agacSampiyonuMu(agac, sira.position);
    final rakam = yazi.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final ayrinti = [
      m.bilesen_bracket_puan(agacSayisi(m, sira.points)),
      m.bilesen_bracket_gbm(sira.won, sira.drawn, sira.lost),
      if (agac.format == EventBracketFormat.swiss)
        m.bilesen_bracket_buchholz(agacSayisi(m, sira.buchholz)),
    ].join(' · ');
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.bilesen_bracket_sira(sira.rank),
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
                      Text(
                        ad,
                        style: sampiyon
                            ? yazi.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              )
                            : yazi.bodyMedium,
                      ),
                      if (sampiyon)
                        Etiket(
                          metin: m.bilesen_bracket_sampiyon_etiketi,
                          ton: EtiketTonu.mango,
                          ikon: Icons.emoji_events_outlined,
                        ),
                      if (benim) Etiket(metin: m.bilesen_bracket_sen),
                    ],
                  ),
                  Text(ayrinti, style: rakam?.copyWith(color: r.metinGovde)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maç işlemleri menüsünün seçenekleri.
enum _MacIslemi { duzelt, sil }

/// Bir maç: başlık ("Maç 2"), iki taraf (sıra, ad, skor; kazanan
/// "Kazanan", bay "Bay" yazısıyla), oyunlar ve yetkiliye göre "Oyun gir"
/// ve son oyun işlemleri. Maçın özeti ekran okuyucuda tek cümledir:
/// tur, taraflar, skor, kazanan.
class AgacMaci extends ConsumerStatefulWidget {
  const AgacMaci({
    super.key,
    required this.kimlik,
    required this.agac,
    required this.mac,
  });

  final AgacKimligi kimlik;
  final EventBracket agac;
  final EventBracketMatch mac;

  @override
  ConsumerState<AgacMaci> createState() => _AgacMaciState();
}

class _AgacMaciState extends ConsumerState<AgacMaci> {
  bool _mesgul = false;

  AgacNotifier get _notifier => ref.read(agacProvider(widget.kimlik).notifier);

  EventBracketMatch get _mac => widget.mac;

  Future<void> _calistir(Future<Object?> Function() islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem();
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _oyunGir() => aracFormuAc<void>(
    context,
    (_) => AgacOyunFormu(
      kimlik: widget.kimlik,
      agac: widget.agac,
      mac: _mac,
      oyun: (agacSonOyun(_mac)?.number ?? 0) + 1,
      gonder: (istek) => _notifier.oyunGir(_mac.id, istek),
    ),
  );

  Future<void> _islem(_MacIslemi islem) async {
    final m = AppLocalizations.of(context);
    final son = agacSonOyun(_mac);
    if (son == null) return;
    switch (islem) {
      case _MacIslemi.duzelt:
        await aracFormuAc<void>(
          context,
          (_) => AgacOyunFormu(
            kimlik: widget.kimlik,
            agac: widget.agac,
            mac: _mac,
            oyun: son.number,
            duzeltilen: son,
            gonder: (istek) =>
                _notifier.oyunuDuzelt(_mac.id, son.number, istek),
          ),
        );
      case _MacIslemi.sil:
        final onay = await cikarmaOnayi(
          context,
          baslik: m.bilesen_bracket_son_oyunu_sil_onay(son.number),
          metin: m.bilesen_bracket_son_oyunu_sil_aciklama,
          eylem: m.bilesen_bracket_sil,
        );
        if (!onay || !mounted) return;
        await _calistir(() => _notifier.sonOyunuSil(_mac.id, son.number));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    final agac = widget.agac;
    final mac = _mac;
    final takimlar = agacTakimlari(widget.kimlik, agac);
    final misafirler = agacMisafirleri(ref, widget.kimlik);
    final aAd = agacYerAdi(
      ref,
      m,
      agac,
      takimlar,
      mac.aPosition,
      misafirler: misafirler,
    );
    final bAd = agacYerAdi(
      ref,
      m,
      agac,
      takimlar,
      mac.bPosition,
      misafirler: misafirler,
    );
    final aSkor = agacSkorMetni(m, agac, mac, a: true);
    final bSkor = agacSkorMetni(m, agac, mac, a: false);
    final kazanan = mac.winnerPosition;
    // Bayda kazanan etiketi yok: "Bay" satırı tur atladığını söyler.
    final aKazandi = !mac.bye && kazanan != null && kazanan == mac.aPosition;
    final bKazandi = !mac.bye && kazanan != null && kazanan == mac.bPosition;
    final sonuc = switch (mac) {
      EventBracketMatch(bye: true) => m.bilesen_bracket_ozet_bay(
        mac.aPosition == null ? bAd : aAd,
      ),
      EventBracketMatch(decided: true) when kazanan != null =>
        m.bilesen_bracket_ozet_kazanan(aKazandi ? aAd : bAd),
      EventBracketMatch(decided: true) => m.bilesen_bracket_ozet_berabere,
      _ => m.bilesen_bracket_ozet_suruyor,
    };
    final oyunlar = agacOyunlarMetni(m, mac);
    final ozet = [
      m.bilesen_bracket_ozet(mac.round, mac.slot),
      if (mac.bye)
        mac.aPosition == null ? bAd : aAd
      else
        m.bilesen_bracket_ozet_taraflar(aAd, aSkor, bAd, bSkor),
      sonuc,
      ?oyunlar,
    ].join(', ');
    final yonetebilir = agac.callerCanManage && mac.games.isNotEmpty;
    final girebilir = mac.callerCanScore && !mac.decided && !mac.bye;
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: ozet,
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        m.bilesen_bracket_mac(mac.slot),
                        style: yazi.labelLarge?.copyWith(color: r.metinGovde),
                      ),
                      if (mac.aPosition != null)
                        _TarafSatiri(
                          sira: mac.aPosition,
                          ad: aAd,
                          skor: mac.bye ? null : aSkor,
                          kazanan: aKazandi,
                          benim: agacBenimYerim(
                            ref,
                            agac,
                            takimlar,
                            mac.aPosition,
                          ),
                        ),
                      if (mac.bPosition != null)
                        _TarafSatiri(
                          sira: mac.bPosition,
                          ad: bAd,
                          skor: mac.bye ? null : bSkor,
                          kazanan: bKazandi,
                          benim: agacBenimYerim(
                            ref,
                            agac,
                            takimlar,
                            mac.bPosition,
                          ),
                        ),
                      if (mac.bye) const _BaySatiri(),
                      if (oyunlar != null)
                        Text(
                          oyunlar,
                          style: yazi.bodySmall?.copyWith(
                            color: r.metinGovde,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (yonetebilir)
                PopupMenuButton<_MacIslemi>(
                  key: ValueKey('agac-islemler-${mac.id}'),
                  tooltip: m.bilesen_bracket_islemler(mac.round, mac.slot),
                  enabled: !_mesgul,
                  onSelected: (islem) => unawaited(_islem(islem)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _MacIslemi.duzelt,
                      child: Text(m.bilesen_bracket_son_oyunu_duzelt),
                    ),
                    PopupMenuItem(
                      value: _MacIslemi.sil,
                      child: Text(m.bilesen_bracket_son_oyunu_sil),
                    ),
                  ],
                ),
            ],
          ),
          if (girebilir) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CerceveliHapEylem(
                etiket: m.bilesen_bracket_oyun_gir,
                ikon: Icons.add,
                onPressed: _mesgul ? null : () => unawaited(_oyunGir()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Maçın bir tarafı: kuradaki sıra, ad (kazanan kalın ve "Kazanan"
/// etiketli, çağıranınki "Sen" etiketli) ve skor. Dar ekranda ve büyük
/// yazıda ad sarar, skor sağda kalır.
class _TarafSatiri extends StatelessWidget {
  const _TarafSatiri({
    required this.sira,
    required this.ad,
    required this.skor,
    required this.kazanan,
    required this.benim,
  });

  final int? sira;
  final String ad;

  /// Bayda `null`.
  final String? skor;
  final bool kazanan;
  final bool benim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    final rakam = yazi.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final skor = this.skor;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          if (sira case final no?) ...[
            Text(
              m.bilesen_bracket_sira(no),
              style: rakam?.copyWith(color: r.metinGovde),
            ),
            const SizedBox(width: TayfamSpacing.s8),
          ],
          Expanded(
            child: Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  ad,
                  style: kazanan
                      ? yazi.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                      : yazi.bodyMedium,
                ),
                if (kazanan)
                  Etiket(
                    metin: m.bilesen_bracket_kazanan,
                    ton: EtiketTonu.mango,
                    ikon: Icons.emoji_events_outlined,
                  ),
                if (benim) Etiket(metin: m.bilesen_bracket_sen),
              ],
            ),
          ),
          if (skor != null) ...[
            const SizedBox(width: TayfamSpacing.s8),
            Text(
              skor,
              style: kazanan
                  ? rakam?.copyWith(fontWeight: FontWeight.w700)
                  : rakam,
            ),
          ],
        ],
      ),
    );
  }
}

/// Rakipsiz taraf: "Bay" (karşısındaki tur atlar).
class _BaySatiri extends StatelessWidget {
  const _BaySatiri();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          m.bilesen_bracket_bay_gecer,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinGovde,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
