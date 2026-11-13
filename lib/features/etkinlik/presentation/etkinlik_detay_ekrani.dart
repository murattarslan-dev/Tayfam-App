import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/features/anket/anket.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/degerlendirme_firsati.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/iptal_diyalogu.dart';
import 'package:tayfam/features/etkinlik/presentation/katilim_dugmeleri.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/features/etkinlik/presentation/varis_bolumu.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Detaydaki harita önizlemesinin yüksekliği (tasarım: 150 px).
const double haritaOnizlemeYuksekligi = 150;

/// Önizlemenin yakınlığı.
const double haritaOnizlemeYakinligi = 15;

/// Üst bölümdeki yuvarlak düğmelerin ve geri sayım çipinin zemini: üst
/// bölümün metin renginin bu saydamlıkta hali (tasarım: ink %12).
const double ustBolumKatmanSaydamligi = .12;

/// Kapak görselinin üstündeki koyu perdenin saydamlığı; beyaz başlık
/// görselin her yerinde okunur kalsın diye.
const double kapakPerdesiSaydamligi = .6;

/// Özet kartının üst bölüme taşan yüksekliği (tasarım: 48 px).
const double ozetKartiTasmasi = TayfamSpacing.s40 + TayfamSpacing.s8;

/// Katılımcı özetinde gösterilen en çok avatar.
const int ozetAvatarSayisi = 5;

/// Özet satırlarındaki parçaların ayracı ("24/40 kişi geliyor · 3 belki").
const String ozetAyraci = ' · ';

/// Etkinlik detayı (`/t/<tayfaId>/etkinlikler/<etkinlikId>`; ADR-0015 §3,
/// 2026-11-13 yeniden tasarım, ADR-0015 Notlar).
///
/// - **Üst bölüm** etkinlik türünün renginde (kapak görseli varsa kapak):
///   geri ve ⋯ düğmeleri, tür çipi, geri sayım ("2 gün sonra", "Bugün ·
///   25 dk sonra"), başlık ve tayfa adı. İptal edilmişse nötr zemin ve
///   "İptal edildi" çipi.
/// - **Özet kartı** üst bölüme taşar: tarih ve saat ("Takvime ekle" simge
///   düğmesi bu satırda), buluşma noktası ya da "Çevrimiçi", organizatör
///   ve katılım (Geliyorum / Belki / Gelmiyorum, gelen/kontenjan çubuğu).
///   İptalde gerekçe kartın altında tint-nar kutudadır.
/// - Varış penceresi açıkken "Geldim" kartı (ADR-0015 §5), buluşma noktası
///   haritası ya da çevrimiçi bağlantı, açıklama, türe özel bilgiler ve
///   araçlar (§6), etkinliğin anketleri ve katılımcı özeti (dokununca
///   ayrı Katılımcılar ekranı). Seri ise en altta seri notu.
/// - ⋯ alttan sayfa açar: yönetebilen kullanıcıya Düzenle ve Etkinliği
///   iptal et, başkasına Şikâyet et (ADR-0018 §8).
///
/// Bitmiş ve cevabı "Geliyorum" olan etkinlikte uygulama değerlendirme
/// penceresi için fırsat denetlenir (ADR-0016). Adresteki kimlikler girdi
/// kabul edilir: biçimi bozuk etkinlik kimliği için istek gönderilmez.
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
    final notifier = ref.read(etkinlikDetayProvider(anahtar).notifier);
    final etkinlik = detay.value;
    if (etkinlik != null) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: notifier.yenile,
          child: DegerlendirmeFirsati(
            etkinlikler: [etkinlik],
            child: _Detay(anahtar: anahtar, etkinlik: etkinlik),
          ),
        ),
      );
    }
    final hata = detay.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_detay_baslik)),
      body: hata == null
          ? const Center(
              child: TayfamYukleniyor(
                boyut: TayfamSizes.yukleniyorTamEkran,
                gecikmeli: true,
              ),
            )
          : RefreshIndicator(
              onRefresh: notifier.yenile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                children: [
                  HataSatiri.hatadan(hata),
                  const SizedBox(height: TayfamSpacing.s16),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CerceveliHapEylem(
                      etiket: m.etkinlik_tekrar_dene,
                      onPressed: () => unawaited(notifier.yenile()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

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
    final gerekce = etkinlik.cancelReason?.trim();
    final aciklama = etkinlik.description.trim();
    final turler = ref.watch(etkinlikTurleriProvider);
    final arac = etkinlik.type == EventType.unknown
        ? null
        : etkinlikTuruBul(
            turler,
            etkinlik.type.wire,
          )?.aracBolumu(context, etkinlik);
    final ayrintilar = _ayrintiSatirlari(m, etkinlik);
    final cevrimici = etkinlik.mode == EventMode.online;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _UstBolum(anahtar: anahtar, etkinlik: etkinlik),
        // Özet kartı üst bölüme taşar (tasarım: −48 px). Kaydırma, boşluğu
        // sayfanın sonunda bırakır.
        Transform.translate(
          offset: const Offset(0, -ozetKartiTasmasi),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OzetKarti(anahtar: anahtar, etkinlik: etkinlik),
                if (iptal && gerekce != null && gerekce.isNotEmpty) ...[
                  const SizedBox(height: TayfamSpacing.s16),
                  _IptalKutusu(gerekce: gerekce),
                ],
                VarisBolumu(anahtar: anahtar, etkinlik: etkinlik),
                if (cevrimici)
                  _CevrimiciBolumu(etkinlik: etkinlik)
                else if (etkinlik.meetingPoint != null)
                  _YerBolumu(etkinlik: etkinlik),
                if (aciklama.isNotEmpty) ...[
                  AracBasligi(metin: m.etkinlik_aciklama_baslik),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s4,
                    ),
                    // Düz metin: markdown ya da bağlantı yorumlanmaz.
                    child: Text(
                      aciklama,
                      style: context.yazi.bodyLarge?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  ),
                ],
                if (ayrintilar.isNotEmpty) ...[
                  AracBasligi(
                    metin: etkinlik.type == EventType.camp
                        ? m.etkinlik_kamp_yeri
                        : m.etkinlik_tur_bilgileri,
                  ),
                  BilgiIzgarasi(bilgiler: ayrintilar),
                ],
                ?arac,
                const SizedBox(height: TayfamSpacing.s16),
                EtkinlikAnketleriBaglantisi(
                  tayfaId: anahtar.tayfaId,
                  etkinlikId: anahtar.etkinlikId,
                ),
                AracBasligi(metin: m.etkinlik_katilimcilar_baslik),
                _KatilimciOzeti(anahtar: anahtar, etkinlik: etkinlik),
                if (etkinlik.seriesId != null) ...[
                  const SizedBox(height: TayfamSpacing.s20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s8,
                    ),
                    child: Text(
                      m.etkinlik_seri_notu,
                      style: context.yazi.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: TayfamSpacing.s24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Üst bölüm ---------------------------------------------------------------

enum _Yonetim { duzenle, iptal, sikayet }

/// Türün renginde üst bölüm (tasarım: Etkinlik-Detay; kapak varsa kapak,
/// iptalde nötr). Üstündeki metin ve ikonlar zeminin "üstü" rengindedir;
/// odak çerçevesi de bu renkle çizilir (tür renginde marka ya da mango
/// çerçeve görünmeyebilir).
class _UstBolum extends ConsumerWidget {
  const _UstBolum({required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final tema = Theme.of(context);
    final iptal = iptalEdildi(etkinlik);
    final girdi = etkinlikTuruGirdisi(etkinlik.type);
    final cift = context.turRenkleri.cift(girdi.renk);
    final yukleme = etkinlik.coverUploadId;
    final kapak = !iptal && yukleme != null && yukleme.isNotEmpty
        ? yukleme
        : null;
    final (zemin, ust) = iptal
        ? (r.cizgi, r.metin)
        : kapak != null
        ? (r.markaYuzeyKutusu, r.markaYuzeyUstu)
        : (cift.dolgu, cift.ustu);
    final tayfaAdi = ref.watch(tayfaOzetiProvider(anahtar.tayfaId)).ad;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final eylem = ref.watch(etkinlikEylemProvider(anahtar));
    final yonetebilir = etkinlik.callerCanManage && !iptal;
    final organizator = etkinlik.createdByUserId;
    final sikayetEdilebilir =
        !yonetebilir &&
        (organizator == null || !ref.watch(kendisiMiProvider(organizator)));
    final menuVar = yonetebilir || sikayetEdilebilir;
    final katman = ust.withValues(alpha: ustBolumKatmanSaydamligi);
    final icerik = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s12,
          TayfamSpacing.s4,
          TayfamSpacing.s12,
          TayfamSpacing.s64,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _YuvarlakDugme(
                  ikon: Icons.arrow_back,
                  ipucu: MaterialLocalizations.of(context).backButtonTooltip,
                  zemin: katman,
                  renk: ust,
                  onPressed: () => _geri(context),
                ),
                const Spacer(),
                if (menuVar)
                  _YuvarlakDugme(
                    ikon: Icons.more_horiz,
                    ipucu: m.etkinlik_islemler,
                    zemin: katman,
                    renk: ust,
                    onPressed: eylem != null
                        ? null
                        : () => unawaited(
                            _menuyuAc(
                              context,
                              ref,
                              yonetebilir: yonetebilir,
                              sikayetEdilebilir: sikayetEdilebilir,
                            ),
                          ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.s8,
                TayfamSpacing.s8,
                TayfamSpacing.s8,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: TayfamSpacing.s8,
                    runSpacing: TayfamSpacing.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _UstCip(
                        ikon: girdi.ikon,
                        metin: girdi.ad(m),
                        zemin: r.markaYuzeyKutusu,
                        renk: r.markaYuzeyUstu,
                      ),
                      if (iptal)
                        Etiket(
                          metin: m.etkinlik_karti_iptal,
                          ton: EtiketTonu.nar,
                        )
                      else
                        _UstCip(
                          metin: detayGeriSayimi(
                            m,
                            etkinlik.startsAt,
                            simdi,
                            bitis: etkinlik.endsAt,
                          ),
                          zemin: katman,
                          renk: ust,
                        ),
                    ],
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  Semantics(
                    header: true,
                    child: Text(
                      etkinlik.title,
                      style: context.yazi.headlineMedium?.copyWith(color: ust),
                    ),
                  ),
                  if (tayfaAdi != null && tayfaAdi.isNotEmpty) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    Text(
                      tayfaAdi,
                      style: context.yazi.titleSmall?.copyWith(color: ust),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final Widget kutu = kapak != null
        ? Stack(
            children: [
              Positioned.fill(
                child: MedyaGorseli(
                  uploadId: kapak,
                  varyant: MedyaVaryanti.tam,
                  etiket: m.medya_kapak_etiketi,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: r.markaYuzeyKutusu.withValues(
                    alpha: kapakPerdesiSaydamligi,
                  ),
                ),
              ),
              icerik,
            ],
          )
        : ColoredBox(color: zemin, child: icerik);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeData.estimateBrightnessForColor(zemin) == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Theme(
        data: tema.copyWith(
          extensions: [
            r.copyWith(odak: ust),
            context.turRenkleri,
          ],
        ),
        child: kutu,
      ),
    );
  }

  void _geri(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Adresler.etkinlikler(anahtar.tayfaId));
    }
  }

  Future<void> _menuyuAc(
    BuildContext context,
    WidgetRef ref, {
    required bool yonetebilir,
    required bool sikayetEdilebilir,
  }) async {
    final m = AppLocalizations.of(context);
    final seri = etkinlik.seriesId != null;
    final secim = await altSayfaAc<_Yonetim>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: etkinlik.title,
        children: [
          if (yonetebilir) ...[
            MenuSatiri(
              baslik: m.etkinlik_duzenle,
              aciklama: seri ? m.etkinlik_menu_seri_notu : null,
              ikon: Icons.edit_outlined,
              onTap: () => Navigator.of(sayfa).pop(_Yonetim.duzenle),
            ),
            MenuSatiri(
              baslik: m.etkinlik_iptal_baslik,
              aciklama: m.etkinlik_menu_iptal_aciklama,
              ikon: Icons.event_busy_outlined,
              tur: MenuSatiriTuru.yikici,
              onTap: () => Navigator.of(sayfa).pop(_Yonetim.iptal),
            ),
          ],
          if (sikayetEdilebilir)
            MenuSatiri(
              baslik: m.sikayet_et,
              ikon: Icons.flag_outlined,
              onTap: () => Navigator.of(sayfa).pop(_Yonetim.sikayet),
            ),
        ],
      ),
    );
    if (secim == null || !context.mounted) return;
    switch (secim) {
      case _Yonetim.duzenle:
        context.go(Adresler.etkinlikDuzenle(anahtar.tayfaId, etkinlik.id));
      case _Yonetim.iptal:
        await _iptalEt(context, ref);
      case _Yonetim.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: anahtar.tayfaId,
            tur: ReportTargetType.event,
            id: etkinlik.id,
          ),
        );
    }
  }

  Future<void> _iptalEt(BuildContext context, WidgetRef ref) async {
    final gerekce = await iptalGerekcesiSor(context);
    if (gerekce == null || !context.mounted) return;
    final hata = await ref
        .read(etkinlikEylemProvider(anahtar).notifier)
        .iptalEt(gerekce);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

/// Üst bölümdeki yuvarlak simge düğmesi (geri, ⋯): 48 px, yarı saydam zemin.
class _YuvarlakDugme extends StatelessWidget {
  const _YuvarlakDugme({
    required this.ikon,
    required this.ipucu,
    required this.zemin,
    required this.renk,
    required this.onPressed,
  });

  final IconData ikon;
  final String ipucu;
  final Color zemin;
  final Color renk;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: IconButton(
        tooltip: ipucu,
        onPressed: onPressed,
        icon: Icon(ikon),
        style: IconButton.styleFrom(
          backgroundColor: zemin,
          foregroundColor: renk,
          disabledBackgroundColor: zemin,
          disabledForegroundColor: renk,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// Üst bölümdeki hap çip (tür: ink zemin; geri sayım: yarı saydam).
class _UstCip extends StatelessWidget {
  const _UstCip({
    required this.metin,
    required this.zemin,
    required this.renk,
    this.ikon,
  });

  final String metin;
  final Color zemin;
  final Color renk;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final ikon = this.ikon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              ExcludeSemantics(
                child: Icon(ikon, size: TayfamSizes.ikonKucuk, color: renk),
              ),
              const SizedBox(width: TayfamSpacing.s4),
            ],
            Flexible(
              child: Text(
                metin,
                style: context.yazi.labelLarge?.copyWith(color: renk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Özet kartı --------------------------------------------------------------

/// Üst bölüme taşan özet kartı (tasarım: Etkinlik-Detay): ne zaman,
/// nerede, kim ve katılım.
class _OzetKarti extends ConsumerWidget {
  const _OzetKarti({required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final eylem = ref.watch(etkinlikEylemProvider(anahtar));
    final (gun, saat) = etkinlikOzetZamani(
      m,
      etkinlik.startsAt,
      etkinlik.endsAt,
    );
    final (yer, bolge) = _yerSatiri(m, etkinlik);
    final organizator = etkinlik.createdByUserId;
    final ayirici = Divider(
      height: TayfamSizes.kenar,
      thickness: TayfamSizes.kenar,
      color: r.cizgi,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: TayfamRadii.kartKoseleri,
        boxShadow: r.oneCikanGolge,
      ),
      child: Material(
        color: r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.kartKoseleri,
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OzetSatiri(
              kutu: const _IkonKutusu(ikon: Icons.calendar_today_outlined),
              baslik: Text(gun, style: context.yazi.titleMedium),
              alt: saat,
              sag: Builder(
                builder: (context) => OdakCercevesi(
                  koseler: TayfamRadii.hapKoseleri,
                  child: IconButton(
                    tooltip: m.etkinlik_takvime_ekle,
                    onPressed: eylem != null
                        ? null
                        : () => unawaited(_takvimeEkle(context, ref)),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    style: IconButton.styleFrom(
                      foregroundColor: r.tintMarkaUstu,
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      shape: const CircleBorder(),
                      side: BorderSide(
                        color: r.cizgi,
                        width: TayfamSizes.vurguKenari,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ayirici,
            _OzetSatiri(
              kutu: _IkonKutusu(
                ikon: etkinlik.mode == EventMode.online
                    ? Icons.videocam_outlined
                    : Icons.place_outlined,
              ),
              baslik: Text(yer, style: context.yazi.titleMedium),
              alt: bolge,
            ),
            ayirici,
            _OzetSatiri(
              kutu: KimlikAvatari(
                kullaniciId: organizator,
                cap: TayfamSizes.menuIkonKutusu,
              ),
              baslik: organizator == null
                  ? Text(
                      m.etkinlik_organizator_yok,
                      style: context.yazi.titleMedium,
                    )
                  : KullaniciAdiMetni(
                      kullaniciId: organizator,
                      style: context.yazi.titleMedium,
                    ),
              alt: m.etkinlik_organizator,
            ),
            ayirici,
            _KatilimBolumu(anahtar: anahtar, etkinlik: etkinlik),
          ],
        ),
      ),
    );
  }

  Future<void> _takvimeEkle(BuildContext context, WidgetRef ref) async {
    final hata = await ref
        .read(etkinlikEylemProvider(anahtar).notifier)
        .takvimeEkle(konum: _konum(context));
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

/// Özet kartındaki yer satırının başlığı ve alt metni: yüz yüzede yer adı
/// ve "ilçe, il" (ad yoksa başlık "ilçe, il"), çevrimiçide "Çevrimiçi";
/// yer gizliyse "Yer bilgisi yok".
(String, String?) _yerSatiri(AppLocalizations m, Event e) {
  if (e.mode == EventMode.online) return (m.etkinlik_karti_cevrimici, null);
  final ad = e.meetingPointName?.trim();
  final bolge = [
    e.district,
    e.city,
  ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
  if (ad != null && ad.isNotEmpty) {
    return (ad, bolge.isEmpty ? null : bolge);
  }
  if (bolge.isNotEmpty) return (bolge, null);
  return (m.etkinlik_yer_gizli, null);
}

/// Özet kartının satırı (tasarım: 64 px, 40 px kutu, başlık ve ikincil alt
/// metin, sağda isteğe bağlı öğe). Ekran okuyucu başlık ve alt metni
/// birlikte okur.
class _OzetSatiri extends StatelessWidget {
  const _OzetSatiri({
    required this.kutu,
    required this.baslik,
    this.alt,
    this.sag,
  });

  final Widget kutu;
  final Widget baslik;
  final String? alt;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final alt = this.alt;
    final sag = this.sag;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.menuSatiri),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s16,
          vertical: TayfamSpacing.s8,
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: kutu),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    baslik,
                    if (alt != null) Text(alt, style: context.yazi.bodySmall),
                  ],
                ),
              ),
            ),
            if (sag != null) ...[const SizedBox(width: TayfamSpacing.s8), sag],
          ],
        ),
      ),
    );
  }
}

/// Tint-brand zeminli 40 px ikon kutusu.
class _IkonKutusu extends StatelessWidget {
  const _IkonKutusu({required this.ikon});

  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.dugmeKoseleri,
      ),
      child: SizedBox.square(
        dimension: TayfamSizes.menuIkonKutusu,
        child: Icon(ikon, size: TayfamSizes.ikon, color: r.tintMarkaUstu),
      ),
    );
  }
}

/// Özet kartının katılım bölümü: "Katılımın" (bekleme listesindeyse
/// "Sırada" etiketi), Geliyorum / Belki / Gelmiyorum, gelen/kontenjan
/// çubuğu ve "N/M kişi geliyor · K belki". İptal edilmiş ya da bitmiş
/// etkinlikte düğmeler yerine "artık cevap verilemez".
class _KatilimBolumu extends ConsumerWidget {
  const _KatilimBolumu({required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final eylem = ref.watch(etkinlikEylemProvider(anahtar));
    final acik = katilimAcik(etkinlik, simdi);
    final cevap = etkinlik.callerRsvp;
    final kontenjan = etkinlik.capacity;
    final gelen = etkinlik.goingCount;
    final bilgi = !acik
        ? m.etkinlik_katilim_kapali
        : cevap == RsvpStatus.waitlist
        ? m.etkinlik_bekleme_listesindesin
        : kontenjanDolu(etkinlik) && cevap != RsvpStatus.going
        ? m.etkinlik_kontenjan_dolu
        : null;
    return Padding(
      padding: const EdgeInsets.all(TayfamSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s4,
            children: [
              Text(
                m.etkinlik_ana_katilim_grubu,
                style: yazi.titleSmall?.copyWith(color: r.metinIkincil),
              ),
              if (acik && cevap == RsvpStatus.waitlist)
                Etiket(metin: m.etkinlik_rozet_bekleme, ton: EtiketTonu.mango),
            ],
          ),
          if (acik) ...[
            const SizedBox(height: TayfamSpacing.s12),
            KatilimDugmeleri(
              cevap: cevap,
              onSecildi: eylem != null
                  ? null
                  : (durum) => unawaited(_katil(context, ref, durum)),
            ),
          ],
          if (kontenjan > 0) ...[
            const SizedBox(height: TayfamSpacing.s12),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: TayfamRadii.hapKoseleri,
                child: LinearProgressIndicator(
                  value: (gelen / kontenjan).clamp(0, 1).toDouble(),
                  minHeight: TayfamSizes.dolulukCubugu,
                  color: r.marka,
                  backgroundColor: r.cizgi,
                ),
              ),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: kontenjan > 0
                      ? m.etkinlik_karti_gelen_kontenjan(gelen, kontenjan)
                      : m.etkinlik_karti_gelen(gelen),
                  style: yazi.titleSmall,
                ),
                if (etkinlik.maybeCount > 0) ...[
                  const TextSpan(text: ozetAyraci),
                  TextSpan(text: m.etkinlik_ozet_belki(etkinlik.maybeCount)),
                ],
              ],
            ),
            style: yazi.bodySmall,
          ),
          if (bilgi != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(bilgi, style: yazi.bodyMedium?.copyWith(color: r.metinGovde)),
          ],
        ],
      ),
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

/// İptal gerekçesi (tasarım: Etkinlik-Iptal): tint-nar kutu.
class _IptalKutusu extends StatelessWidget {
  const _IptalKutusu({required this.gerekce});

  final String gerekce;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintNar,
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.event_busy_outlined,
                  size: TayfamSizes.ikon,
                  color: r.narMetin,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.etkinlik_iptal_edildi_baslik,
                      style: context.yazi.titleMedium?.copyWith(
                        color: r.narMetin,
                      ),
                    ),
                    const SizedBox(height: TayfamSpacing.s4),
                    Text(
                      m.etkinlik_iptal_gerekcesi(gerekce),
                      style: context.yazi.bodyMedium?.copyWith(color: r.metin),
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

// --- Yer ve bağlantı ---------------------------------------------------------

/// Buluşma noktası (tasarım: Etkinlik-Detay): harita önizlemesi (dokununca
/// sistemin harita uygulaması) ve yer adıyla "Harita uygulamasında aç".
class _YerBolumu extends ConsumerWidget {
  const _YerBolumu({required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final nokta = etkinlik.meetingPoint;
    if (nokta == null) return const SizedBox.shrink();
    final (yer, _) = _yerSatiri(m, etkinlik);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(metin: m.etkinlik_yer_baslik),
        Material(
          color: r.kart,
          shape: RoundedRectangleBorder(
            borderRadius: TayfamRadii.kartKoseleri,
            side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
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
                    // Önizlemenin tamamı harita uygulamasını açar; aynı iş
                    // aşağıdaki düğmede de olduğu için ekran okuyucudan
                    // gizlidir.
                    Positioned.fill(
                      child: ExcludeSemantics(
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TayfamSpacing.s12,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    Text(yer, style: context.yazi.titleSmall),
                    CerceveliHapEylem(
                      etiket: m.etkinlik_haritada_ac,
                      ikon: Icons.map_outlined,
                      onPressed: () => unawaited(_haritadaAc(context, ref)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      aracBildir(
        context,
        AppLocalizations.of(context).etkinlik_harita_acilamadi,
      );
    }
  }
}

/// Çevrimiçi bağlantı (yalnızca üyelere gelir; tasarım: Etkinlik-Turler
/// "Çevrimiçi bağlantı"). Yalnızca güvenli (`https`) bağlantı açılır.
class _CevrimiciBolumu extends ConsumerWidget {
  const _CevrimiciBolumu({required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final baglanti = etkinlik.onlineUrl?.trim();
    if (baglanti == null || baglanti.isEmpty) return const SizedBox.shrink();
    final adres = Uri.tryParse(baglanti);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(metin: m.etkinlik_baglanti_baslik),
        TayfamKart(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.lock_outline,
                      size: TayfamSizes.ikonKucuk,
                      color: r.metinIkincil,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Text(
                      m.etkinlik_baglanti_uyelere,
                      style: context.yazi.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TayfamSpacing.s8),
              SelectableText(
                baglanti,
                style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
              if (adres != null && guvenliBaglantiMi(adres)) ...[
                const SizedBox(height: TayfamSpacing.s12),
                CerceveliHapEylem(
                  etiket: m.etkinlik_baglantiyi_ac,
                  ikon: Icons.open_in_new,
                  onPressed: () => unawaited(_ac(context, ref, adres)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _ac(BuildContext context, WidgetRef ref, Uri adres) async {
    final acildi = await ref
        .read(etkinlikBaglantiAciciProvider)
        .baglantiAc(adres);
    if (!acildi && context.mounted) {
      aracBildir(
        context,
        AppLocalizations.of(context).etkinlik_baglanti_acilamadi,
      );
    }
  }
}

// --- Türe özel bilgiler ------------------------------------------------------

/// Türe özel bilgiler (yalnızca okunur; ADR-0015 §3). Bilgi ızgarasında
/// gösterilir (tasarım: Etkinlik-Turler).
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

// --- Katılımcı özeti ---------------------------------------------------------

/// Katılımcıların özeti (tasarım: Etkinlik-Detay "Katılımcılar"): gelenlerin
/// ilk beşinin avatarı, "N kişi geliyor" ve "K belki · W bekleme
/// listesinde"; dokununca Katılımcılar ekranı açılır.
class _KatilimciOzeti extends ConsumerWidget {
  const _KatilimciOzeti({required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final gelenler =
        ref
            .watch(
              katilimcilarProvider((
                tayfaId: anahtar.tayfaId,
                etkinlikId: anahtar.etkinlikId,
                durum: ListEventAttendeesStatus.going,
              )),
            )
            .value
            ?.ogeler ??
        const <Attendee>[];
    final alt = [
      if (etkinlik.maybeCount > 0) m.etkinlik_ozet_belki(etkinlik.maybeCount),
      if (etkinlik.waitlistCount > 0)
        m.etkinlik_ozet_bekleme(etkinlik.waitlistCount),
    ].join(ozetAyraci);
    return ListeKarti(
      children: [
        ListeKartiSatiri(
          onTap: () => context.go(
            Adresler.etkinlikKatilimcilari(anahtar.tayfaId, anahtar.etkinlikId),
          ),
          child: Row(
            children: [
              if (gelenler.isNotEmpty) ...[
                _AvatarYigini(
                  kimlikler: [
                    for (final k in gelenler.take(ozetAvatarSayisi)) k.userId,
                  ],
                ),
                const SizedBox(width: TayfamSpacing.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.etkinlik_karti_gelen(etkinlik.goingCount),
                      style: context.yazi.titleMedium,
                    ),
                    if (alt.isNotEmpty)
                      Text(alt, style: context.yazi.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              const SatirOku(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Üst üste binen avatarlar: her biri kart renginde ince halkalı, bir
/// öncekinin üstüne biner. Süstür; ekran okuyucudan gizlenir (sayılar
/// satırın metninde).
class _AvatarYigini extends StatelessWidget {
  const _AvatarYigini({required this.kimlikler});

  final List<String> kimlikler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    const cap = TayfamSizes.avatarYigini;
    const adim = cap - TayfamSpacing.s8;
    return ExcludeSemantics(
      child: SizedBox(
        width: cap + adim * (kimlikler.length - 1),
        height: cap,
        child: Stack(
          children: [
            for (final (sira, kimlik) in kimlikler.indexed)
              PositionedDirectional(
                start: adim * sira,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: r.kart,
                      width: TayfamSizes.alanOdakKenari,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: KimlikAvatari(kullaniciId: kimlik, cap: cap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
