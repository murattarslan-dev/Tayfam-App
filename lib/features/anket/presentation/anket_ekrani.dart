import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/features/anket/presentation/anket_sonuclari.dart';
import 'package:tayfam/features/anket/presentation/oy_verenler_sayfasi.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tek bir anket (`/t/<tayfaId>/anketler/<anketId>`; tasarım: Anket-Oy,
/// Anket-Sonuc, Anket-Gizli; ADR-0018 §5): durum çipi ve kapanış, soru,
/// oy verme (tek seçimde radyo, çoklu seçimde onay kutusu; her zaman
/// alttaki "Oyu gönder" düğmesiyle), oy değiştirme ve geri çekme, sonuçlar
/// ve ⋯ menüsünde kapatma ile şikâyet.
///
/// Adresteki [anketId] girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez, "bulunamadı" gösterilir. Kapatma anketi açana ve yönetime
/// gösterilir; kararı sunucu verir (kesin kural 5). Gizlilik vaatleri
/// [AnketSonuclari]'ndadır (kesin kural 7).
class AnketEkrani extends ConsumerWidget {
  const AnketEkrani({super.key, required this.tayfaId, required this.anketId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  /// Adresteki anket kimliği; biçimi burada doğrulanır.
  final String anketId;

  AnketAnahtari get _anahtar => (tayfaId: tayfaId, anketId: anketId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    if (!uuidBicimindeMi(anketId)) {
      return Scaffold(
        appBar: AppBar(title: Text(m.anket_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: m.hata_poll_not_found),
        ),
      );
    }
    final saglayici = anketProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final anket = durum.value;
    final hata = durum.error;
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final oylama = ref.watch(oylamaProvider(_anahtar));
    final kapali = anket != null && anketKapali(anket, simdi);
    final kapatabilir = anket != null && !kapali && _yonetebilir(ref, anket);
    final acan = anket?.createdByUserId;
    // Başkasının anketi şikâyet edilebilir (ADR-0018 §8).
    final sikayetEdilebilir =
        anket != null && (acan == null || !ref.watch(kendisiMiProvider(acan)));
    final secim = anket != null && secimGosterilir(anket, oylama, simdi);
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (kapatabilir || sikayetEdilebilir)
            IconButton(
              tooltip: m.anket_islemler,
              icon: const Icon(Icons.more_horiz),
              onPressed: () => unawaited(
                _menuyuAc(
                  context,
                  ref,
                  kapatabilir: kapatabilir,
                  sikayetEdilebilir: sikayetEdilebilir,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: anket != null && secim
          ? _OyCubugu(anahtar: _anahtar, anket: anket, durum: oylama)
          : null,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: RefreshIndicator(
              onRefresh: () => _yenile(context, ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TayfamSpacing.s20,
                  TayfamSpacing.s4,
                  TayfamSpacing.s20,
                  TayfamSpacing.s40,
                ),
                children: [
                  if (anket != null)
                    _AnketIcerigi(
                      anahtar: _anahtar,
                      anket: anket,
                      kapali: kapali,
                      secim: secim,
                      durum: oylama,
                    )
                  else if (hata != null) ...[
                    HataSatiri.hatadan(hata),
                    AnketTekrarDene(onPressed: () => ref.invalidate(saglayici)),
                  ] else
                    Center(
                      child: TayfamYukleniyor(
                        boyut: TayfamSizes.yukleniyorTamEkran,
                        etiket: m.anket_yukleniyor,
                        gecikmeli: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Anketi sunucudan yeniden okur. Okunamazsa eldeki anket kalır ve hata
  /// kısa bildirimle gösterilir.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = anketProvider(_anahtar);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) anketHatasiniBildir(context, hata);
  }

  /// Kapatma satırı gösterilsin mi: yönetim ya da anketi açan. Yalnızca
  /// kolaylıktır; kararı sunucu verir (kesin kural 5).
  bool _yonetebilir(WidgetRef ref, Poll anket) {
    if (ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde) return true;
    final acan = anket.createdByUserId;
    return acan != null && ref.watch(kendisiMiProvider(acan));
  }

  /// ⋯ menüsü (alttan sayfa): "Anketi kapat" ve "Şikâyet et". Sayfa
  /// kapanır, işlem ekranın bağlamıyla sürer (onay penceresi, bildirim).
  Future<void> _menuyuAc(
    BuildContext context,
    WidgetRef ref, {
    required bool kapatabilir,
    required bool sikayetEdilebilir,
  }) {
    final m = AppLocalizations.of(context);
    return altSayfaAc<void>(
      context,
      builder: (sayfa) {
        void sec(Future<void> Function() islem) {
          Navigator.of(sayfa).pop();
          unawaited(islem());
        }

        return AltSayfaIcerigi(
          baslik: m.anket_islemler,
          children: [
            if (kapatabilir)
              MenuSatiri(
                ikon: Icons.lock_outline,
                baslik: m.anket_kapat,
                onTap: () => sec(() => _kapat(context, ref)),
              ),
            if (sikayetEdilebilir)
              MenuSatiri(
                ikon: Icons.flag_outlined,
                baslik: m.sikayet_et,
                onTap: () => sec(
                  () => sikayetSayfasiniAc(
                    context,
                    SikayetHedefi.tayfada(
                      tayfaId: tayfaId,
                      tur: ReportTargetType.poll,
                      id: anketId,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _kapat(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (pencere) => AlertDialog(
        title: Text(m.anket_kapat_onay_baslik),
        content: Text(m.anket_kapat_onay_aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            child: Text(m.anket_vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(true),
            child: Text(m.anket_kapat),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final hata = await ref.read(anketProvider(_anahtar).notifier).kapat();
    if (!context.mounted) return;
    if (hata != null) {
      anketHatasiniBildir(context, hata);
      return;
    }
    anketBildirimi(bildirim, m.anket_kapatildi);
  }
}

/// Anketi açanın görünen adı; ad önbellekten istenir. Bilinmiyorsa genel
/// metin, kullanıcı silinmişse "Silinmiş kullanıcı".
String _acanAdi(WidgetRef ref, AppLocalizations m, String? kimlik) {
  if (kimlik == null) return m.kullanici_silinmis;
  ref.read(kullaniciAdlariProvider.notifier).iste(kimlik);
  final bilinen = ref.watch(
    kullaniciAdlariProvider.select((adlar) => adlar[kimlik]),
  );
  return switch (bilinen) {
    null => m.kullanici_genel,
    KullaniciAdi(:final ad?) => ad,
    KullaniciAdi() => m.kullanici_silinmis,
  };
}

class _AnketIcerigi extends ConsumerWidget {
  const _AnketIcerigi({
    required this.anahtar,
    required this.anket,
    required this.kapali,
    required this.secim,
    required this.durum,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final bool kapali;

  /// Oy verme seçimi mi gösteriliyor (değilse sonuçlar).
  final bool secim;
  final OylamaDurumu durum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final etkinlikId = anket.eventId;
    final kucuk = context.yazi.labelSmall?.copyWith(
      color: r.metinIkincil,
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AnketDurumCipi(kapali: kapali),
            AnketKapanisMetni(anket: anket, kapali: kapali),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Semantics(
          header: true,
          child: Text(anket.question, style: context.yazi.headlineMedium),
        ),
        if (anket.anonymous) ...[
          const SizedBox(height: TayfamSpacing.s12),
          const _GizliBilgiKutusu(),
        ],
        if (etkinlikId != null && uuidBicimindeMi(etkinlikId)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.anket_etkinlige_git,
              ikon: Icons.event_outlined,
              onPressed: () =>
                  context.go(Adresler.etkinlik(anahtar.tayfaId, etkinlikId)),
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s16),
        if (secim)
          _Secim(anahtar: anahtar, anket: anket, durum: durum)
        else ...[
          AnketSonuclari(
            anket: anket,
            onSecenek: (secenek) => unawaited(
              oyVerenleriGoster(
                context,
                tayfaId: anahtar.tayfaId,
                anket: anket,
                secenek: secenek,
              ),
            ),
          ),
          if (!kapali) ...[
            const SizedBox(height: TayfamSpacing.s16),
            _SonucEylemleri(anahtar: anahtar, anket: anket, durum: durum),
          ],
          if (anket.multipleChoice && secenekSayilariGorunur(anket)) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Text(m.anket_coklu_yuzde_notu, style: kucuk),
          ],
          const SizedBox(height: TayfamSpacing.s12),
          Text(
            m.anket_acan_satiri(_acanAdi(ref, m, anket.createdByUserId)),
            style: kucuk,
          ),
        ],
      ],
    );
  }
}

/// Gizli anketin bilgi kutusu (tasarım: Anket-Gizli): tint-brand zemin,
/// kilit ikonu, "Gizli anket." ve kimsenin oyları göremeyeceği.
class _GizliBilgiKutusu extends StatelessWidget {
  const _GizliBilgiKutusu();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.onizlemeKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.lock_outline,
                size: TayfamSizes.ikonOrta,
                color: r.tintMarkaUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: m.anket_gizli_kutu_baslik,
                      style: TextStyle(
                        color: r.metin,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(text: m.anket_gizli_aciklama),
                  ],
                ),
                style: context.yazi.labelSmall?.copyWith(
                  color: r.metinGovde,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oy verme seçimi (tasarım: Anket-Oy): üstte kural ("Birden çok seçenek
/// seçebilirsin"), seçenek kutuları, altta "Sonuçları gör" ya da oyunu
/// değiştirirken "Vazgeç". Sayılar burada gösterilmez.
class _Secim extends ConsumerWidget {
  const _Secim({
    required this.anahtar,
    required this.anket,
    required this.durum,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final OylamaDurumu durum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final notifier = ref.read(oylamaProvider(anahtar).notifier);
    final kilitli = durum.gonderiliyor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          anket.multipleChoice ? m.anket_coklu_secim : m.anket_tek_secim,
          style: context.yazi.titleSmall?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        for (final (sira, s) in siraliSecenekler(anket).indexed) ...[
          if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
          OySecenegi(
            metin: s.text,
            secili: durum.secim.contains(s.id),
            coklu: anket.multipleChoice,
            onTap: kilitli ? null : () => notifier.sec(anket, s.id),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: durum.duzenleniyor
              ? BaglantiEylemi(
                  etiket: m.anket_vazgec,
                  onPressed: kilitli ? null : notifier.vazgec,
                )
              : BaglantiEylemi(
                  etiket: m.anket_sonuclari_gor,
                  onPressed: kilitli
                      ? null
                      : () => notifier.sonuclaraGec(sonuclarda: true),
                ),
        ),
      ],
    );
  }
}

/// Oy verme ekranındaki seçenek kutusu (tasarım: Anket-Oy): en az 56 px,
/// solda tek seçimde radyo, çoklu seçimde onay kutusu işareti. Seçiliyken
/// 2 px marka kenar ve tint-brand zemin. Seçim ekran okuyucuda da
/// bildirilir; renk tek başına bilgi taşımaz.
class OySecenegi extends StatelessWidget {
  const OySecenegi({
    super.key,
    required this.metin,
    required this.secili,
    required this.coklu,
    required this.onTap,
  });

  final String metin;
  final bool secili;

  /// Çoklu seçim (onay kutusu); değilse radyo.
  final bool coklu;

  /// `null` ise devre dışı (oy gönderiliyor).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final isaret = switch ((coklu, secili)) {
      (true, true) => Icons.check_box_rounded,
      (true, false) => Icons.check_box_outline_blank_rounded,
      (false, true) => Icons.radio_button_checked,
      (false, false) => Icons.radio_button_unchecked,
    };
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: secili ? r.tintMarka : r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: secili
              ? BorderSide(color: r.marka, width: TayfamSizes.alanOdakKenari)
              : BorderSide(color: r.cizgi, width: TayfamSizes.vurguKenari),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          checked: secili,
          inMutuallyExclusiveGroup: coklu ? null : true,
          enabled: onTap != null,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TayfamSpacing.s56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        isaret,
                        size: TayfamSizes.seciliIsareti,
                        color: secili ? r.marka : r.girisKenari,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Text(
                        metin,
                        style: context.yazi.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

/// Oy verme ekranının altındaki sabit çubuk (tasarım: Anket-Oy): oy veren
/// sayısı ve anketi açan; "Oyu gönder" (çoklu seçimde seçilen sayısıyla).
/// Oy her zaman bu düğmeyle gönderilir (platform sahibi kararı).
class _OyCubugu extends ConsumerWidget {
  const _OyCubugu({
    required this.anahtar,
    required this.anket,
    required this.durum,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final OylamaDurumu durum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final notifier = ref.read(oylamaProvider(anahtar).notifier);
    final ozet = m.anket_alt_ozet(
      m.anket_oy_veren_sayisi(anket.voterCount),
      _acanAdi(ref, m, anket.createdByUserId),
    );
    final gecerli = !durum.gonderiliyor && secimGecerli(anket, durum.secim);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
            vertical: TayfamSpacing.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ozet,
                textAlign: TextAlign.center,
                style: context.yazi.labelSmall?.copyWith(
                  color: r.metinIkincil,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s8),
              BirincilEylem(
                etiket: m.anket_oyu_gonder(
                  anket.multipleChoice ? durum.secim.length : 0,
                ),
                onPressed: gecerli
                    ? () => unawaited(_oyVer(context, notifier))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _oyVer(BuildContext context, OylamaNotifier notifier) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await notifier.gonder(anket);
    if (!context.mounted) return;
    if (hata != null) {
      anketHatasiniBildir(context, hata);
      return;
    }
    anketBildirimi(bildirim, m.anket_oy_kaydedildi);
  }
}

/// Açık anketin sonuçlarındaki düğmeler (tasarım: Anket-Sonuc): oy
/// verdiysen "Oyunu değiştir" ve "Oyunu geri çek", vermediysen "Oy
/// vermeye dön".
class _SonucEylemleri extends ConsumerWidget {
  const _SonucEylemleri({
    required this.anahtar,
    required this.anket,
    required this.durum,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final OylamaDurumu durum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final notifier = ref.read(oylamaProvider(anahtar).notifier);
    final kilitli = durum.gonderiliyor;
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (oyVerdi(anket)) ...[
          CerceveliHapEylem(
            etiket: m.anket_oyu_degistir,
            onPressed: kilitli ? null : () => notifier.degistir(anket),
          ),
          BaglantiEylemi(
            etiket: m.anket_oyu_geri_cek,
            renk: context.renkler.metinGovde,
            onPressed: kilitli
                ? null
                : () => unawaited(_geriCek(context, notifier)),
          ),
        ] else
          CerceveliHapEylem(
            etiket: m.anket_oy_vermeye_don,
            onPressed: kilitli
                ? null
                : () => notifier.sonuclaraGec(sonuclarda: false),
          ),
      ],
    );
  }

  Future<void> _geriCek(BuildContext context, OylamaNotifier notifier) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await notifier.geriCek();
    if (!context.mounted) return;
    if (hata != null) {
      anketHatasiniBildir(context, hata);
      return;
    }
    anketBildirimi(bildirim, m.anket_oy_geri_cekildi);
  }
}
