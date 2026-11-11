import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/anket.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/presentation/degerlendirme_firsati.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/iptal_diyalogu.dart';
import 'package:tayfam/features/etkinlik/presentation/katilimcilar_bolumu.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/features/etkinlik/presentation/varis_bolumu.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Detaydaki harita önizlemesinin yüksekliği.
const double haritaOnizlemeYuksekligi = 180;

/// Önizlemenin yakınlığı.
const double haritaOnizlemeYakinligi = 15;

/// Etkinlik detayı (`/t/<tayfaId>/etkinlikler/<etkinlikId>`, ADR-0015 §3):
/// açıklama, yer (harita önizlemesi; dokununca sistemin harita uygulaması),
/// çevrimiçi bağlantı, organizatör, katılım ve sayılar, varış bildirimi
/// (ADR-0015 §5), türe özel bilgiler ve araçlar (§6) ve katılımcılar
/// (organizatör düzeltmesiyle). Takvime ekleme her zaman; düzenleme ve iptal
/// `caller_can_manage` ise görünür; başkasının etkinliğinde menüde "Şikâyet
/// et" vardır (ADR-0018 §8). Bitmiş ve cevabı "Geliyorum" olan
/// etkinlikte uygulama değerlendirme penceresi için fırsat denetlenir
/// (ADR-0016).
///
/// Adresteki kimlikler girdi kabul edilir: biçimi bozuk etkinlik kimliği
/// için istek gönderilmez.
class EtkinlikDetayEkrani extends ConsumerWidget {
  const EtkinlikDetayEkrani({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
  });

  final String tayfaId;
  final String etkinlikId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    if (!uuidBicimindeMi(etkinlikId)) {
      return Scaffold(
        appBar: AppBar(title: Text(m.etkinlik_detay_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: m.hata_event_not_found),
        ),
      );
    }
    final anahtar = (tayfaId: tayfaId, etkinlikId: etkinlikId);
    final detay = ref.watch(etkinlikDetayProvider(anahtar));
    final eylem = ref.watch(etkinlikEylemProvider(anahtar));
    final etkinlik = detay.value;
    final notifier = ref.read(etkinlikDetayProvider(anahtar).notifier);
    final yonetebilir =
        etkinlik != null && etkinlik.callerCanManage && !iptalEdildi(etkinlik);
    final organizator = etkinlik?.createdByUserId;
    final sikayetEdilebilir =
        etkinlik != null &&
        (organizator == null || !ref.watch(kendisiMiProvider(organizator)));
    return Scaffold(
      appBar: AppBar(
        title: Text(m.etkinlik_detay_baslik),
        actions: [
          if (etkinlik != null)
            Builder(
              builder: (context) => IconButton(
                tooltip: m.etkinlik_takvime_ekle,
                icon: const Icon(Icons.event_available),
                onPressed: eylem != null
                    ? null
                    : () => unawaited(_takvimeEkle(context, ref, anahtar)),
              ),
            ),
          if (yonetebilir || sikayetEdilebilir)
            PopupMenuButton<_Yonetim>(
              tooltip: m.etkinlik_islemler,
              enabled: eylem == null,
              onSelected: (secim) {
                switch (secim) {
                  case _Yonetim.duzenle:
                    context.go(Adresler.etkinlikDuzenle(tayfaId, etkinlikId));
                  case _Yonetim.iptal:
                    unawaited(_iptalEt(context, ref, anahtar));
                  case _Yonetim.sikayet:
                    unawaited(
                      sikayetSayfasiniAc(
                        context,
                        SikayetHedefi.tayfada(
                          tayfaId: tayfaId,
                          tur: ReportTargetType.event,
                          id: etkinlikId,
                        ),
                      ),
                    );
                }
              },
              itemBuilder: (context) => [
                if (yonetebilir) ...[
                  PopupMenuItem(
                    value: _Yonetim.duzenle,
                    child: Text(m.etkinlik_duzenle),
                  ),
                  PopupMenuItem(
                    value: _Yonetim.iptal,
                    child: Text(m.etkinlik_iptal_et),
                  ),
                ],
                if (sikayetEdilebilir)
                  PopupMenuItem(
                    value: _Yonetim.sikayet,
                    child: Text(m.sikayet_et),
                  ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.yenile,
        child: detay.when(
          data: (etkinlik) => DegerlendirmeFirsati(
            etkinlikler: [etkinlik],
            child: _Detay(anahtar: anahtar, etkinlik: etkinlik),
          ),
          error: (hata, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            children: [
              HataSatiri.hatadan(hata),
              const SizedBox(height: TayfamSpacing.s16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: () => unawaited(notifier.yenile()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.etkinlik_tekrar_dene),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _takvimeEkle(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
  ) async {
    final hata = await ref
        .read(etkinlikEylemProvider(anahtar).notifier)
        .takvimeEkle(konum: _konum(context));
    if (hata != null && context.mounted) hataBildir(context, hata);
  }

  Future<void> _iptalEt(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
  ) async {
    final gerekce = await iptalGerekcesiSor(context);
    if (gerekce == null || !context.mounted) return;
    final hata = await ref
        .read(etkinlikEylemProvider(anahtar).notifier)
        .iptalEt(gerekce);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

enum _Yonetim { duzenle, iptal, sikayet }

/// [context]'teki öğenin ekrandaki yeri (iPad paylaşım menüsü için).
Rect? _konum(BuildContext context) {
  final kutu = context.findRenderObject();
  if (kutu is RenderBox && kutu.hasSize) {
    return kutu.localToGlobal(Offset.zero) & kutu.size;
  }
  return null;
}

class _Detay extends ConsumerWidget {
  const _Detay({required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final iptal = iptalEdildi(etkinlik);
    final gerekce = etkinlik.cancelReason;
    final aciklama = etkinlik.description.trim();
    final turler = ref.watch(etkinlikTurleriProvider);
    final arac = etkinlik.type == EventType.unknown
        ? null
        : etkinlikTuruBul(
            turler,
            etkinlik.type.wire,
          )?.aracBolumu(context, etkinlik);
    final ayrintilar = _ayrintiSatirlari(m, etkinlik);
    final kapak = etkinlik.coverUploadId;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [
        if (kapak != null && kapak.isNotEmpty) ...[
          ClipRRect(
            borderRadius: TayfamRadii.onizlemeKoseleri,
            child: AspectRatio(
              aspectRatio: TayfamSizes.kapakOrani,
              child: MedyaGorseli(
                uploadId: kapak,
                varyant: MedyaVaryanti.tam,
                etiket: m.medya_kapak_etiketi,
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ],
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtkinlikTuruCipi(tur: etkinlik.type),
            if (iptal) Etiket(metin: m.etkinlik_karti_iptal),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Semantics(
          header: true,
          child: Text(etkinlik.title, style: context.yazi.headlineSmall),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          etkinlikZamanAraligi(m, etkinlik.startsAt, etkinlik.endsAt),
          style: context.yazi.bodyLarge,
        ),
        if (iptal && gerekce != null && gerekce.trim().isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.etkinlik_iptal_gerekcesi(gerekce.trim()),
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ],
        if (etkinlik.seriesId != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.etkinlik_seri_notu,
            style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s24),
        _KatilimBolumu(anahtar: anahtar, etkinlik: etkinlik),
        VarisBolumu(anahtar: anahtar, etkinlik: etkinlik),
        const SizedBox(height: TayfamSpacing.s24),
        if (etkinlik.mode == EventMode.online)
          _CevrimiciBolumu(etkinlik: etkinlik)
        else
          _YerBolumu(etkinlik: etkinlik),
        const SizedBox(height: TayfamSpacing.s24),
        _Baslik(metin: m.etkinlik_organizator),
        const SizedBox(height: TayfamSpacing.s4),
        _Organizator(kullaniciId: etkinlik.createdByUserId),
        if (aciklama.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s24),
          _Baslik(metin: m.etkinlik_aciklama_baslik),
          const SizedBox(height: TayfamSpacing.s4),
          // Düz metin: markdown ya da bağlantı yorumlanmaz.
          Text(
            aciklama,
            style: context.yazi.bodyLarge?.copyWith(color: r.metinGovde),
          ),
        ],
        if (ayrintilar.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s24),
          _Baslik(metin: m.etkinlik_tur_bilgileri),
          const SizedBox(height: TayfamSpacing.s4),
          for (final (etiket, deger) in ayrintilar)
            _BilgiSatiri(etiket: etiket, deger: deger),
        ],
        if (arac != null) ...[const SizedBox(height: TayfamSpacing.s24), arac],
        const SizedBox(height: TayfamSpacing.s16),
        EtkinlikAnketleriBaglantisi(
          tayfaId: anahtar.tayfaId,
          etkinlikId: anahtar.etkinlikId,
        ),
        const SizedBox(height: TayfamSpacing.s24),
        KatilimcilarBolumu(
          tayfaId: anahtar.tayfaId,
          etkinlikId: anahtar.etkinlikId,
          duzeltme: katilimDuzeltmeAcik(
            etkinlik,
            ref.watch(etkinlikSaatiProvider)(),
          ),
        ),
      ],
    );
  }
}

/// Türe özel bilgiler (yalnızca okunur; ADR-0015 §3).
List<(String, String)> _ayrintiSatirlari(AppLocalizations m, Event e) {
  final satirlar = <(String, String)>[];
  void ekle(String etiket, String? deger) {
    if (deger != null && deger.trim().isNotEmpty) {
      satirlar.add((etiket, deger.trim()));
    }
  }

  final camp = e.camp;
  if (camp != null) {
    ekle(m.etkinlik_kamp_yeri, camp.siteName);
    ekle(m.etkinlik_kamp_su, varYok(m, camp.hasWater));
    ekle(m.etkinlik_kamp_tuvalet, varYok(m, camp.hasToilet));
    ekle(m.etkinlik_kamp_notu, camp.notes);
  }
  final hike = e.hike;
  if (hike != null) {
    final zorluk = hike.difficulty;
    if (zorluk != null && zorluk > 0) {
      ekle(m.etkinlik_yuruyus_zorluk, m.etkinlik_zorluk_degeri(zorluk));
    }
    final mesafe = hike.distanceKm;
    if (mesafe != null && mesafe > 0) {
      ekle(m.etkinlik_yuruyus_mesafe, m.etkinlik_km(etkinlikSayi(m, mesafe)));
    }
    final yukselti = hike.elevationM;
    if (yukselti != null && yukselti > 0) {
      ekle(
        m.etkinlik_yuruyus_yukselti,
        m.etkinlik_metre(etkinlikSayi(m, yukselti)),
      );
    }
    final donus = hike.expectedReturnAt;
    if (donus != null) {
      ekle(m.etkinlik_yuruyus_donus, etkinlikZamani(m, donus));
    }
    final tolerans = hike.returnGraceMinutes;
    if (tolerans != null && tolerans > 0) {
      ekle(
        m.etkinlik_yuruyus_tolerans,
        m.etkinlik_dakika(etkinlikSayi(m, tolerans)),
      );
    }
  }
  final fishing = e.fishing;
  if (fishing != null) {
    ekle(
      m.etkinlik_balik_gizlilik,
      balikGizliligiAdi(
        m,
        fishing.spotVisibility ?? FishingDetailsSpotVisibility.tayfa,
      ),
    );
  }
  final gaming = e.gaming;
  if (gaming != null) {
    ekle(m.etkinlik_oyun, gaming.game);
    ekle(m.etkinlik_oyun_platform, platformAdi(m, gaming.platform));
  }
  final sports = e.sports;
  if (sports != null) {
    ekle(m.etkinlik_spor, sporAdi(m, sports.sport));
    ekle(m.etkinlik_spor_saha, sports.venueName);
  }
  return satirlar;
}

class _Baslik extends StatelessWidget {
  const _Baslik({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(metin, style: context.yazi.titleMedium),
    );
  }
}

class _BilgiSatiri extends StatelessWidget {
  const _BilgiSatiri({required this.etiket, required this.deger});

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiket,
              style: context.yazi.labelMedium?.copyWith(
                color: context.renkler.metinIkincil,
              ),
            ),
            Text(deger, style: context.yazi.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _Organizator extends StatelessWidget {
  const _Organizator({required this.kullaniciId});

  final String? kullaniciId;

  @override
  Widget build(BuildContext context) {
    final id = kullaniciId;
    if (id == null) {
      return Text(
        AppLocalizations.of(context).etkinlik_organizator_yok,
        style: context.yazi.bodyLarge,
      );
    }
    return KullaniciAdiMetni(kullaniciId: id, style: context.yazi.bodyLarge);
  }
}

class _KatilimBolumu extends ConsumerWidget {
  const _KatilimBolumu({required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final eylem = ref.watch(etkinlikEylemProvider(anahtar));
    final acik = katilimAcik(etkinlik, simdi);
    final cevap = etkinlik.callerRsvp;
    final secili = switch (cevap) {
      RsvpStatus.going || RsvpStatus.waitlist => RsvpRequestStatus.going,
      RsvpStatus.maybe => RsvpRequestStatus.maybe,
      RsvpStatus.notGoing => RsvpRequestStatus.notGoing,
      RsvpStatus.unknown || null => null,
    };
    final bilgi = !acik
        ? m.etkinlik_katilim_kapali
        : cevap == RsvpStatus.waitlist
        ? m.etkinlik_bekleme_listesindesin
        : kontenjanDolu(etkinlik) && cevap != RsvpStatus.going
        ? m.etkinlik_kontenjan_dolu
        : null;
    final ikincil = context.yazi.bodyMedium?.copyWith(color: r.metinGovde);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Baslik(metin: m.etkinlik_katilim_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final (durum, etiket) in [
              (RsvpRequestStatus.going, m.etkinlik_cevap_going),
              (RsvpRequestStatus.maybe, m.etkinlik_cevap_maybe),
              (RsvpRequestStatus.notGoing, m.etkinlik_cevap_not_going),
            ])
              ChoiceChip(
                label: Text(etiket),
                selected: secili == durum,
                onSelected: !acik || eylem != null
                    ? null
                    : (_) => unawaited(_katil(context, ref, durum)),
              ),
          ],
        ),
        if (bilgi != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(bilgi, style: ikincil),
        ],
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          m.etkinlik_katilim_sayilari(
            etkinlikSayi(m, etkinlik.goingCount),
            etkinlikSayi(m, etkinlik.maybeCount),
          ),
          style: context.yazi.bodyMedium,
        ),
        if (etkinlik.capacity > 0)
          Text(
            m.etkinlik_kontenjan_bilgi(etkinlikSayi(m, etkinlik.capacity)),
            style: ikincil,
          ),
        if (etkinlik.waitlistCount > 0)
          Text(
            m.etkinlik_bekleyen_sayisi(etkinlikSayi(m, etkinlik.waitlistCount)),
            style: ikincil,
          ),
      ],
    );
  }

  Future<void> _katil(
    BuildContext context,
    WidgetRef ref,
    RsvpRequestStatus durum,
  ) async {
    final hata = await ref
        .read(etkinlikEylemProvider(anahtar).notifier)
        .katil(durum);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

class _YerBolumu extends ConsumerWidget {
  const _YerBolumu({required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final nokta = etkinlik.meetingPoint;
    final ad = etkinlik.meetingPointName?.trim();
    final bolge = [
      etkinlik.district,
      etkinlik.city,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Baslik(metin: m.etkinlik_yer_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        if (ad != null && ad.isNotEmpty)
          Text(ad, style: context.yazi.bodyLarge),
        if (bolge.isNotEmpty)
          Text(
            bolge,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        if (nokta == null && (ad == null || ad.isEmpty) && bolge.isEmpty)
          Text(m.etkinlik_yer_gizli, style: context.yazi.bodyMedium),
        if (nokta != null) ...[
          const SizedBox(height: TayfamSpacing.s12),
          ClipRRect(
            borderRadius: TayfamRadii.onizlemeKoseleri,
            child: SizedBox(
              height: haritaOnizlemeYuksekligi,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: OsmHarita(
                      merkez: nokta,
                      yakinlik: haritaOnizlemeYakinligi,
                      isaret: nokta,
                      etkilesimli: false,
                    ),
                  ),
                  // Önizlemenin tamamı harita uygulamasını açar; atıf
                  // görünür kalır.
                  Positioned.fill(
                    child: Semantics(
                      button: true,
                      label: m.etkinlik_haritada_ac,
                      excludeSemantics: true,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () => unawaited(_haritadaAc(context, ref)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => unawaited(_haritadaAc(context, ref)),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(m.etkinlik_haritada_ac),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _haritadaAc(BuildContext context, WidgetRef ref) async {
    final nokta = etkinlik.meetingPoint;
    if (nokta == null) return;
    final acildi = await ref
        .read(etkinlikBaglantiAciciProvider)
        .haritadaAc(nokta.lat, nokta.lng);
    if (!acildi && context.mounted) {
      _bildir(context, AppLocalizations.of(context).etkinlik_harita_acilamadi);
    }
  }
}

class _CevrimiciBolumu extends ConsumerWidget {
  const _CevrimiciBolumu({required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final baglanti = etkinlik.onlineUrl?.trim();
    final adres = baglanti == null ? null : Uri.tryParse(baglanti);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Baslik(metin: m.etkinlik_baglanti_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        Text(m.etkinlik_karti_cevrimici, style: context.yazi.bodyLarge),
        if (baglanti != null && baglanti.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s4),
          SelectableText(
            baglanti,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          if (adres != null && guvenliBaglantiMi(adres))
            TextButton.icon(
              onPressed: () => unawaited(_ac(context, ref, adres)),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(m.etkinlik_baglantiyi_ac),
            ),
        ],
      ],
    );
  }

  Future<void> _ac(BuildContext context, WidgetRef ref, Uri adres) async {
    final acildi = await ref
        .read(etkinlikBaglantiAciciProvider)
        .baglantiAc(adres);
    if (!acildi && context.mounted) {
      _bildir(
        context,
        AppLocalizations.of(context).etkinlik_baglanti_acilamadi,
      );
    }
  }
}

void _bildir(BuildContext context, String metin) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}
