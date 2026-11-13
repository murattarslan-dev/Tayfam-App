import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/olusturma_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/kuruldu_ekrani.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_avatari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa kurma sihirbazı (ADR-0014 §4 ve Notlar 2026-11-13; tasarım:
/// Tayfa-Kur-*): ad → ilgi alanları → katılım ve açıklama.
///
/// İskelet etkinlik sihirbazıyla aynıdır: üstte kapat (X), "Tayfa kur",
/// "Adım n / 3" ve ilerleme çubuğu; altta sabit Geri + İleri. Geri ve ileri
/// gezinmede girilenler korunur; Android geri tuşu ilk adıma kadar önceki
/// adıma döner. Bir şey girilmişse kapatırken vazgeç onayı sorulur.
///
/// Günlük sınır (`tayfa-create-limit`) ve hız sınırı (`rate-limited`) son
/// adımda tint-nar kutuda gösterilir; girilenler kalır. Başarıda sihirbazın
/// yerine "Tayfa kuruldu" ekranı ([TayfaKurulduEkrani]) açılır.
class OlusturmaEkrani extends ConsumerStatefulWidget {
  const OlusturmaEkrani({super.key});

  @override
  ConsumerState<OlusturmaEkrani> createState() => _OlusturmaEkraniState();
}

class _OlusturmaEkraniState extends ConsumerState<OlusturmaEkrani> {
  late final TextEditingController _ad;
  late final TextEditingController _aciklama;

  @override
  void initState() {
    super.initState();
    final durum = ref.read(olusturmaProvider);
    _ad = TextEditingController(text: durum.ad);
    _aciklama = TextEditingController(text: durum.aciklama);
  }

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  OlusturmaNotifier get _notifier => ref.read(olusturmaProvider.notifier);

  /// Kapat (X) ya da ilk adımda geri: girilen bir şey varsa onay sorulur.
  Future<void> _kapat() async {
    if (ref.read(olusturmaProvider).girdiVar) {
      final vazgec = await _vazgecOnayi(context);
      if (!vazgec || !mounted) return;
    }
    if (!mounted) return;
    // Navigator.pop, PopScope'u (girilen varken kapanmayı engeller) atlar;
    // onay yukarıda alındı.
    final gezinme = Navigator.of(context);
    if (gezinme.canPop()) {
      gezinme.pop();
      return;
    }
    context.go(Adresler.kok);
  }

  /// Örnek ad çipi: ad alana yazılır.
  void _ornekSec(String ad) {
    _ad.value = TextEditingValue(
      text: ad,
      selection: TextSelection.collapsed(offset: ad.length),
    );
    _notifier.adAyarla(ad);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(olusturmaProvider);
    final kurulan = durum.kurulan;
    if (kurulan != null) return TayfaKurulduEkrani(tayfa: kurulan);
    final sonAdim = durum.adim == olusturmaAdimSayisi - 1;
    final kilitli = durum.gonderiliyor;
    return PopScope(
      canPop: durum.adim == 0 && !durum.girdiVar,
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (geriDonuldu || kilitli) return;
        if (!_notifier.geri()) unawaited(_kapat());
      },
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SihirbazUstCubugu(
              baslik: m.olusturma_baslik,
              adimMetni: m.olusturma_adim(durum.adim + 1, olusturmaAdimSayisi),
              adim: durum.adim + 1,
              toplam: olusturmaAdimSayisi,
              onKapat: kilitli ? null : () => unawaited(_kapat()),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: TayfamSizes.okumaGenisligi,
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(durum.adim),
                    padding: const EdgeInsets.fromLTRB(
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s20,
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s32,
                    ),
                    child: switch (durum.adim) {
                      0 => _AdAdimi(
                        denetleyici: _ad,
                        durum: durum,
                        onChanged: _notifier.adAyarla,
                        onSubmitted: _notifier.ileri,
                        onOrnek: _ornekSec,
                      ),
                      1 => _IlgiAdimi(
                        durum: durum,
                        onDegisti: kilitli ? null : _notifier.ilgiDegistir,
                      ),
                      _ => _KatilimAdimi(
                        durum: durum,
                        aciklama: _aciklama,
                        onKatilim: _notifier.katilimAyarla,
                        onAciklama: _notifier.aciklamaAyarla,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SihirbazAltCubugu(
          geriEtiketi: m.olusturma_geri,
          onGeri: durum.adim > 0 && !kilitli ? () => _notifier.geri() : null,
          ileriEtiketi: sonAdim ? m.olusturma_gonder : m.olusturma_ileri,
          onIleri: kilitli
              ? null
              : sonAdim
              ? () => unawaited(_notifier.gonder())
              : _notifier.ileri,
        ),
      ),
    );
  }
}

/// 1 · Ad (tasarım: Tayfa-Kur-Ad): ad alanı, örnek ad çipleri ve tayfanın
/// listede nasıl görüneceğinin önizlemesi.
class _AdAdimi extends StatelessWidget {
  const _AdAdimi({
    required this.denetleyici,
    required this.durum,
    required this.onChanged,
    required this.onSubmitted,
    required this.onOrnek,
  });

  final TextEditingController denetleyici;
  final OlusturmaDurumu durum;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onOrnek;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ornekler = [
      m.olusturma_ornek_halisaha,
      m.olusturma_ornek_kamp,
      m.olusturma_ornek_yuruyus,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.olusturma_ad_baslik,
          aciklama: m.olusturma_ad_aciklama,
        ),
        const SizedBox(height: TayfamSpacing.s20),
        TextField(
          controller: denetleyici,
          autofocus: true,
          maxLength: tayfaAdiEnCok,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: m.olusturma_ad_etiketi,
            errorText: durum.adHatali ? m.olusturma_ad_hata : null,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Semantics(
          header: true,
          child: Text(
            m.olusturma_ornekler,
            style: context.yazi.labelMedium?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final ornek in ornekler)
              ActionChip(label: Text(ornek), onPressed: () => onOrnek(ornek)),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        _Onizleme(
          etiket: m.olusturma_onizleme_ad,
          ad: durum.ad,
          ilgiler: durum.ilgiler,
        ),
      ],
    );
  }
}

/// 2 · İlgi alanları (tasarım: Tayfa-Kur-Ilgi, Tayfa-Kur-Koyu): iki
/// sütunlu, onay kutulu kartlar. Adım geçilebilir; önizlemedeki avatarın
/// rengi ilk seçilen türden gelir.
class _IlgiAdimi extends StatelessWidget {
  const _IlgiAdimi({required this.durum, required this.onDegisti});

  final OlusturmaDurumu durum;
  final ValueChanged<EventType>? onDegisti;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final onDegisti = this.onDegisti;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.olusturma_ilgi_baslik,
          aciklama: m.olusturma_ilgi_aciklama,
        ),
        const SizedBox(height: TayfamSpacing.s20),
        IkiSutunluIzgara(
          children: [
            for (final tur in ilgiAlanlari)
              IlgiKarti(
                tur: tur,
                secili: durum.ilgiler.contains(tur),
                onDegisti: onDegisti == null ? null : () => onDegisti(tur),
              ),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s20),
        _Onizleme(
          etiket: m.olusturma_onizleme_ilgi,
          ad: durum.ad,
          ilgiler: durum.ilgiler,
        ),
      ],
    );
  }
}

/// İlgi alanı kartı (tasarım: Tayfa-Kur-Ilgi): türün renginde ikon kutusu,
/// türün adı ve onay kutusu; seçiliyken marka kenar ve tint zemin. Renk
/// tek başına bilgi taşımaz: seçim onay kutusunda ve ekran okuyucuda da
/// bildirilir. Renk, ikon ve ad etkinlik türü kaydından gelir.
class IlgiKarti extends StatelessWidget {
  const IlgiKarti({
    super.key,
    required this.tur,
    required this.secili,
    required this.onDegisti,
  });

  final EventType tur;
  final bool secili;
  final VoidCallback? onDegisti;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final girdi = etkinlikTuruGirdisi(tur);
    final cift = context.turRenkleri.cift(girdi.renk);
    final onDegisti = this.onDegisti;
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: secili ? r.tintMarka : r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: BorderSide(
            color: secili ? r.marka : r.cizgi,
            width: secili
                ? TayfamSizes.alanOdakKenari
                : TayfamSizes.vurguKenari,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          checked: secili,
          child: InkWell(
            onTap: onDegisti,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.menuSatiri,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TayfamSpacing.s12,
                  TayfamSpacing.s8,
                  TayfamSpacing.s4,
                  TayfamSpacing.s8,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cift.dolgu,
                          borderRadius: TayfamRadii.dugmeKoseleri,
                        ),
                        child: SizedBox.square(
                          dimension: TayfamSizes.maddeKutusu,
                          child: Icon(
                            girdi.ikon,
                            size: TayfamSizes.ikon,
                            color: cift.ustu,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Expanded(
                      child: Text(girdi.ad(m), style: context.yazi.titleSmall),
                    ),
                    // Dokunma alanı bütün karttır; kutu yalnızca gösterir.
                    ExcludeSemantics(
                      child: Checkbox(
                        value: secili,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: onDegisti == null
                            ? null
                            : (_) => onDegisti(),
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

/// İlgi alanı çipi (ADR-0004 Notlar, 2026-11-10): türün ikonu ve adı her
/// zaman görünür. Seçiliyken türün kendi dolgusu, üstünde türün metin
/// rengi ve onay işareti; seçili değilken kenarlı hap. Renk, ikon ve ad
/// etkinlik türü kaydından gelir. Tayfa bilgileri ekranında kullanılır.
class IlgiCipi extends StatelessWidget {
  const IlgiCipi({
    super.key,
    required this.tur,
    required this.secili,
    required this.onDegisti,
  });

  final EventType tur;
  final bool secili;
  final VoidCallback? onDegisti;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final girdi = etkinlikTuruGirdisi(tur);
    final cift = context.turRenkleri.cift(girdi.renk);
    final yaziRengi = secili ? cift.ustu : r.metin;
    final onDegisti = this.onDegisti;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              girdi.ikon,
              size: TayfamSizes.ikonKucuk,
              color: yaziRengi,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s4),
          Flexible(child: Text(girdi.ad(AppLocalizations.of(context)))),
        ],
      ),
      selected: secili,
      onSelected: onDegisti == null ? null : (_) => onDegisti(),
      showCheckmark: true,
      checkmarkColor: cift.ustu,
      selectedColor: cift.dolgu,
      labelStyle: context.yazi.labelLarge?.copyWith(color: yaziRengi),
      side: secili
          ? BorderSide.none
          : BorderSide(color: r.girisKenari, width: TayfamSizes.kenar),
      shape: const StadiumBorder(),
    );
  }
}

/// 3 · Katılım ve açıklama (tasarım: Tayfa-Kur-Katilim, Tayfa-Kur-Limit):
/// Onaylı ("Önerilen", varsayılan) ve Açık radyo kartları, sayaçlı
/// açıklama, gönderim hatası ve en altta 7 günde 3 üye ile 24 saatte bir
/// tayfa bilgisi.
class _KatilimAdimi extends StatelessWidget {
  const _KatilimAdimi({
    required this.durum,
    required this.aciklama,
    required this.onKatilim,
    required this.onAciklama,
  });

  final OlusturmaDurumu durum;
  final TextEditingController aciklama;
  final ValueChanged<JoinPolicy> onKatilim;
  final ValueChanged<String> onAciklama;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kilitli = durum.gonderiliyor;
    final hata = durum.hata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(baslik: m.olusturma_katilim_baslik),
        const SizedBox(height: TayfamSpacing.s16),
        RadioGroup<JoinPolicy>(
          groupValue: durum.katilim,
          onChanged: (secim) {
            if (secim != null && !kilitli) onKatilim(secim);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KatilimKarti(
                deger: JoinPolicy.approval,
                secili: durum.katilim == JoinPolicy.approval,
                baslik: m.olusturma_onayli,
                aciklama: m.olusturma_onayli_aciklama,
                etiket: m.olusturma_onerilen,
                onSec: kilitli ? null : () => onKatilim(JoinPolicy.approval),
              ),
              const SizedBox(height: TayfamSpacing.s8),
              _KatilimKarti(
                deger: JoinPolicy.open,
                secili: durum.katilim == JoinPolicy.open,
                baslik: m.olusturma_acik,
                aciklama: m.olusturma_acik_aciklama,
                onSec: kilitli ? null : () => onKatilim(JoinPolicy.open),
              ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s20),
        TextField(
          controller: aciklama,
          enabled: !kilitli,
          maxLength: tayfaAciklamasiEnCok,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onAciklama,
          decoration: InputDecoration(
            labelText: m.olusturma_aciklama_etiketi,
            alignLabelWithHint: true,
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s12),
          _GonderimHatasi(hata: hata),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        Text(
          m.olusturma_kurallar,
          style: context.yazi.bodySmall?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
      ],
    );
  }
}

/// Katılım seçeneği kartı (tasarım: Tayfa-Kur-Katilim): radyo düğmesi,
/// başlık, isteğe bağlı etiket ("Önerilen") ve ne anlama geldiğini söyleyen
/// cümle; seçiliyken marka kenar ve tint zemin.
class _KatilimKarti extends StatelessWidget {
  const _KatilimKarti({
    required this.deger,
    required this.secili,
    required this.baslik,
    required this.aciklama,
    required this.onSec,
    this.etiket,
  });

  final JoinPolicy deger;
  final bool secili;
  final String baslik;
  final String aciklama;
  final String? etiket;
  final VoidCallback? onSec;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final etiket = this.etiket;
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: secili ? r.tintMarka : r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: BorderSide(
            color: secili ? r.marka : r.cizgi,
            width: secili
                ? TayfamSizes.alanOdakKenari
                : TayfamSizes.vurguKenari,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          checked: secili,
          inMutuallyExclusiveGroup: true,
          child: InkWell(
            onTap: onSec,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.s4,
                TayfamSpacing.s4,
                TayfamSpacing.s16,
                TayfamSpacing.s12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Radio<JoinPolicy>(value: deger)),
                  const SizedBox(width: TayfamSpacing.s4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: TayfamSpacing.s12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: TayfamSpacing.s8,
                            runSpacing: TayfamSpacing.s4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(baslik, style: context.yazi.titleMedium),
                              if (etiket != null)
                                Etiket(metin: etiket, ton: EtiketTonu.teal),
                            ],
                          ),
                          const SizedBox(height: TayfamSpacing.s4),
                          Text(
                            aciklama,
                            style: context.yazi.bodyMedium?.copyWith(
                              color: r.metinGovde,
                            ),
                          ),
                        ],
                      ),
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
}

/// Gönderim hatası. Günlük sınır (`tayfa-create-limit`) ve hız sınırı
/// (`rate-limited`) tint-nar kutuda, girilenlerin durduğunu söyleyerek
/// gösterilir (tasarım: Tayfa-Kur-Limit); diğer hatalar ortak hata
/// satırıyla. Metin ortak eşlemeden ya da sihirbazın kendi metninden
/// gelir; sunucunun `title` / `detail` metni gösterilmez.
class _GonderimHatasi extends StatelessWidget {
  const _GonderimHatasi({required this.hata});

  final Object hata;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final tur = switch (hata) {
      ApiProblem(:final type) => type,
      _ => null,
    };
    final (String baslik, String metin) = switch (tur) {
      ProblemType.tayfaCreateLimit => (
        m.olusturma_sinir_baslik,
        m.olusturma_sinir_metni,
      ),
      ProblemType.rateLimited => (
        m.hata_rate_limited,
        m.olusturma_girilenler_duruyor,
      ),
      _ => ('', ''),
    };
    if (baslik.isEmpty) return HataSatiri.hatadan(hata);
    final yazi = context.yazi.bodyMedium?.copyWith(color: r.metin);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintNar,
          borderRadius: TayfamRadii.secimKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: TayfamSizes.ikon,
                  color: r.narMetin,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: baslik,
                        style: TextStyle(
                          color: r.narMetin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(text: metin),
                    ],
                  ),
                  style: yazi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tayfanın listede nasıl görüneceğinin önizlemesi (tasarım: Tayfa-Kur-Ad,
/// Tayfa-Kur-Ilgi): tint-brand kartta [TayfaAvatari] (rengi ilk seçilen
/// ilgi alanından) ve ad.
class _Onizleme extends StatelessWidget {
  const _Onizleme({
    required this.etiket,
    required this.ad,
    required this.ilgiler,
  });

  final String etiket;
  final String ad;
  final List<EventType> ilgiler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final temiz = ad.trim();
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.secimKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s12),
          child: Row(
            children: [
              TayfaAvatari(ad: temiz, ilgiAlanlari: ilgiler),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiket,
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinIkincil,
                      ),
                    ),
                    if (temiz.isNotEmpty)
                      Text(
                        temiz,
                        style: context.yazi.titleMedium?.copyWith(
                          color: r.metin,
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

/// "Tayfa kurmaktan vazgeçilsin mi?" onayı (tasarım: Tayfa-Kur-Vazgec);
/// vazgeçilirse `true`.
Future<bool> _vazgecOnayi(BuildContext context) async {
  final m = AppLocalizations.of(context);
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(m.olusturma_vazgec_baslik),
      scrollable: true,
      content: Text(m.olusturma_vazgec_metni),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.olusturma_vazgec_devam),
        ),
        YikiciEylem(
          etiket: m.olusturma_vazgec,
          dolu: true,
          onPressed: () => Navigator.of(pencere).pop(true),
        ),
      ],
    ),
  );
  return sonuc ?? false;
}
