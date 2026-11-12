import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/application/kayit_notifier.dart';
import 'package:tayfam/features/hesap/application/kayit_sihirbazi.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/features/hesap/presentation/kayit_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Doğum tarihi seçici: seçilen tarihi ya da vazgeçilirse `null` döndürür.
typedef DogumTarihiSecici =
    Future<DateTime?> Function(BuildContext context, DateTime? secili);

/// Sistem tarih seçicisi (ADR-0012 §3): `tr_TR`, ön seçili tarih yok,
/// bugünden ileri seçilemez, yıl görünümüyle açılır.
Future<DateTime?> sistemTarihSecicisi(BuildContext context, DateTime? secili) {
  final bugun = DateUtils.dateOnly(DateTime.now());
  return showDatePicker(
    context: context,
    initialDate: secili,
    firstDate: DateTime(1900),
    lastDate: bugun,
    initialDatePickerMode: DatePickerMode.year,
  );
}

/// Kayıt sihirbazı: "Tayfam'la tanışma" (ADR-0012 §3; tasarım
/// Kayit-Ad / Dogum / Teyit / Referans / Onay).
///
/// Her adım tek soru sorar; Tayfam rozet avatarlı gelen balonlarda
/// konuşur, kullanıcının bir önceki cevabı sağda giden balon olarak
/// görünür. Üstte logonun dört bloğuyla ilerleme göstergesi vardır.
///
/// 1. Ad: Google adıyla dolu, 1–40 karakter; değişmediyse gönderilmez.
/// 2. Doğum tarihi: ön seçili tarih yok, bugünden ileri seçilemez; "Devam
///    et"te teyit penceresi açılır (yaş sınırından söz edilmez).
/// 3. Referans kodu: isteğe bağlı, en çok 32 karakter; "Kodum yok, geç".
/// 4. İki ayrı onay kutusu; ikisi işaretlenmeden "Tanışmayı tamamla"
///    kapalıdır. Gönderim yalnızca burada, tek istekle yapılır.
///
/// Geri düğmesi (ve Android geri tuşu) önceki adıma döner; girilenler
/// korunur. Eylem düğmeleri klavye açıkken klavyenin üstünde kalır.
///
/// Referans linkiyle (`tayfam.app/r/<KOD>`) gelindiyse kod alanı
/// [referansKodu] ile dolu açılır (ADR-0018 §6); kullanıcı değiştirebilir.
///
/// Ad, doğum tarihi ve referans kodu yalnızca bellektedir; log'a, diske ya
/// da analitiğe yazılmaz (CLAUDE.md kesin kural 3, ADR-0006).
class KayitEkrani extends ConsumerStatefulWidget {
  const KayitEkrani({
    super.key,
    this.tarihSecici = sistemTarihSecicisi,
    this.referansKodu,
  });

  /// Testlerde sahte seçici verilir.
  final DogumTarihiSecici tarihSecici;

  /// Referans linkinden gelen kod; yoksa `null`.
  final String? referansKodu;

  @override
  ConsumerState<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends ConsumerState<KayitEkrani> {
  late final TextEditingController _ad;
  late final TextEditingController _referans;

  KayitSihirbaziNotifier get _sihirbaz =>
      ref.read(kayitSihirbaziProvider.notifier);

  @override
  void initState() {
    super.initState();
    final taslak = ref.read(kayitSihirbaziProvider);
    _ad = TextEditingController(text: taslak.ad);
    _referans = TextEditingController(
      text: taslak.referansKodu.isNotEmpty
          ? taslak.referansKodu
          : widget.referansKodu ?? '',
    );
  }

  @override
  void didUpdateWidget(KayitEkrani eski) {
    super.didUpdateWidget(eski);
    // Ekran açıkken referans linki gelirse boş alan doldurulur; kullanıcının
    // yazdığı kodun üstüne yazılmaz.
    final kod = widget.referansKodu;
    if (kod != null && kod != eski.referansKodu && _referans.text.isEmpty) {
      _referans.text = kod;
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _referans.dispose();
    super.dispose();
  }

  void _geri() {
    FocusScope.of(context).unfocus();
    _sihirbaz.geri();
  }

  void _adiOnayla() {
    _sihirbaz
      ..adDegisti(_ad.text)
      ..adiOnayla();
  }

  Future<void> _tarihSec() async {
    final secili = ref.read(kayitSihirbaziProvider).dogumTarihi;
    final secilen = await widget.tarihSecici(context, secili);
    if (secilen == null || !mounted) return;
    _sihirbaz.dogumTarihiSecildi(secilen);
  }

  Future<void> _dogumTarihiniOnayla() async {
    if (!_sihirbaz.dogumTarihiGecerliMi(DateTime.now())) return;
    final tarih = ref.read(kayitSihirbaziProvider).dogumTarihi;
    if (tarih == null) return;
    final dogru = await showDialog<bool>(
      context: context,
      builder: (context) => DogumTarihiTeyidi(tarih: tarih),
    );
    if (dogru != true || !mounted) return;
    _sihirbaz.dogumTarihiTeyitEdildi();
  }

  void _referansiOnayla() {
    FocusScope.of(context).unfocus();
    _sihirbaz
      ..referansDegisti(_referans.text)
      ..referansiOnayla();
  }

  void _referansiGec() {
    FocusScope.of(context).unfocus();
    _referans.clear();
    _sihirbaz.referansiGec();
  }

  Future<void> _gonder(OnaySurumleri surumler) async {
    final bilgi = _sihirbaz.bilgi(surumler: surumler, bugun: DateTime.now());
    if (bilgi == null) return;
    await ref.read(kayitProvider.notifier).gonder(bilgi);
  }

  @override
  Widget build(BuildContext context) {
    // Sürümler değişince (consent-outdated) kutular boşalır ve onay
    // adımına dönülür; kullanıcı yeni metinleri yeniden onaylar.
    ref.listen(kayitProvider, (onceki, sonraki) {
      final eski = onceki?.value?.surumler;
      final yeni = sonraki.value?.surumler;
      if (eski != null && yeni != null && eski != yeni) {
        _sihirbaz.onaylariYenile();
      }
    });
    final durum = ref.watch(kayitProvider);
    final taslak = ref.watch(kayitSihirbaziProvider);
    final deger = durum.value;
    final ilkAdim = taslak.adim == KayitAdimi.ad;
    return PopScope(
      canPop: ilkAdim,
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (!geriDonuldu) _geri();
      },
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: deger != null
                  ? _sihirbazGovdesi(context, taslak, deger)
                  : YuklemeDurumu(
                      yukleniyor: durum.isLoading,
                      hata: durum.error,
                      tekrarDene: () => ref.invalidate(kayitProvider),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sihirbazGovdesi(
    BuildContext context,
    KayitTaslagi taslak,
    KayitDurumu durum,
  ) {
    final metinler = AppLocalizations.of(context);
    final hareketsiz = MediaQuery.disableAnimationsOf(context);
    final ilkAdim = taslak.adim == KayitAdimi.ad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s4,
            vertical: TayfamSpacing.s4,
          ),
          child: Row(
            children: [
              SizedBox(
                width: TayfamSizes.dokunmaMin,
                child: ilkAdim
                    ? null
                    : IconButton(
                        onPressed: durum.gonderiliyor ? null : _geri,
                        tooltip: metinler.hesap_kayit_geri,
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
              ),
              Expanded(
                child: Center(
                  child: KayitIlerlemesi(
                    adim: taslak.adim.index + 1,
                    toplam: kayitAdimSayisi,
                  ),
                ),
              ),
              if (ilkAdim)
                TextButton(
                  onPressed: () =>
                      unawaited(ref.read(kayitProvider.notifier).cikisYap()),
                  child: Text(metinler.hesap_cikis_yap),
                )
              else
                const SizedBox(width: TayfamSizes.dokunmaMin),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s24,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s16,
            ),
            child: AnimatedSwitcher(
              duration: hareketsiz ? Duration.zero : TayfamMotion.orta,
              child: KeyedSubtree(
                key: ValueKey(taslak.adim),
                child: _adimIcerigi(context, taslak, durum),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            0,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s16,
          ),
          child: _eylemler(metinler, taslak, durum),
        ),
      ],
    );
  }

  Widget _adimIcerigi(
    BuildContext context,
    KayitTaslagi taslak,
    KayitDurumu durum,
  ) {
    final metinler = AppLocalizations.of(context);
    final hatalar = taslak.hatalar;
    final ad = taslak.ad.trim();
    switch (taslak.adim) {
      case KayitAdimi.ad:
        final googleAdi = ref.watch(googleAdiProvider);
        return _AdAdimi(
          denetleyici: _ad,
          googleAdiyla: googleAdi != null && googleAdi.trim().isNotEmpty,
          hatali: hatalar.contains(KayitFormHatasi.ad),
          onChanged: _sihirbaz.adDegisti,
          onSubmitted: _adiOnayla,
        );
      case KayitAdimi.dogumTarihi:
        return _DogumTarihiAdimi(
          ad: ad,
          tarih: taslak.dogumTarihi,
          hatali: hatalar.contains(KayitFormHatasi.dogumTarihi),
          onSec: durum.gonderiliyor ? null : () => unawaited(_tarihSec()),
        );
      case KayitAdimi.referans:
        return _ReferansAdimi(
          tarih: taslak.dogumTarihi,
          denetleyici: _referans,
          hatali: hatalar.contains(KayitFormHatasi.referansKodu),
          onChanged: _sihirbaz.referansDegisti,
          onSubmitted: _referansiOnayla,
        );
      case KayitAdimi.onaylar:
        final hata = durum.hata;
        return _OnayAdimi(
          cevap: taslak.referansAtlandi
              ? metinler.hesap_kayit_kodum_yok
              : taslak.referansKodu.trim(),
          kodVar: !taslak.referansAtlandi,
          surumler: durum.surumler,
          aydinlatma: taslak.aydinlatma,
          kosullar: taslak.kosullar,
          kilitli: durum.gonderiliyor,
          onAydinlatma: _sihirbaz.aydinlatmaDegisti,
          onKosullar: _sihirbaz.kosullarDegisti,
          hata: hata == null ? null : hesapHatasiMetni(metinler, hata),
        );
    }
  }

  Widget _eylemler(
    AppLocalizations metinler,
    KayitTaslagi taslak,
    KayitDurumu durum,
  ) {
    final kilitli = durum.gonderiliyor;
    switch (taslak.adim) {
      case KayitAdimi.ad:
        return BirincilEylem(
          etiket: metinler.hesap_kayit_gonder,
          onPressed: _adiOnayla,
        );
      case KayitAdimi.dogumTarihi:
        return BirincilEylem(
          etiket: metinler.hesap_kayit_gonder,
          onPressed: () => unawaited(_dogumTarihiniOnayla()),
        );
      case KayitAdimi.referans:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BirincilEylem(
              etiket: metinler.hesap_kayit_gonder,
              onPressed: _referansiOnayla,
            ),
            const SizedBox(height: TayfamSpacing.s8),
            TextButton(
              onPressed: _referansiGec,
              style: TextButton.styleFrom(shape: const StadiumBorder()),
              child: Text(metinler.hesap_kayit_referans_gec),
            ),
          ],
        );
      case KayitAdimi.onaylar:
        return BirincilEylem(
          etiket: metinler.hesap_kayit_tamamla,
          onPressed: kilitli || !taslak.onaylarTamam
              ? null
              : () => unawaited(_gonder(durum.surumler)),
        );
    }
  }
}

class _AdAdimi extends StatelessWidget {
  const _AdAdimi({
    required this.denetleyici,
    required this.googleAdiyla,
    required this.hatali,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController denetleyici;
  final bool googleAdiyla;
  final bool hatali;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TayfamKonusuyor(
          balonlar: [metinler.hesap_kayit_selam, metinler.hesap_kayit_ad_soru],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AlanEtiketi(metin: metinler.hesap_kayit_ad),
              const SizedBox(height: TayfamSpacing.s8),
              TextField(
                controller: denetleyici,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted(),
                style: context.yazi.titleMedium,
                decoration: kayitAlanGorunumu(
                  context,
                  yardim: googleAdiyla
                      ? metinler.hesap_kayit_ad_yardim_google
                      : metinler.hesap_kayit_ad_yardim,
                  hata: hatali ? metinler.hesap_kayit_ad_hata : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DogumTarihiAdimi extends StatelessWidget {
  const _DogumTarihiAdimi({
    required this.ad,
    required this.tarih,
    required this.hatali,
    required this.onSec,
  });

  final String ad;
  final DateTime? tarih;
  final bool hatali;
  final VoidCallback? onSec;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final tarih = this.tarih;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GidenCevap(metin: ad),
        const SizedBox(height: TayfamSpacing.s20),
        TayfamKonusuyor(
          balonlar: [
            metinler.hesap_kayit_tanistik(ad),
            metinler.hesap_kayit_dogum_soru,
          ],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AlanEtiketi(metin: metinler.hesap_kayit_dogum_tarihi),
              const SizedBox(height: TayfamSpacing.s8),
              _TarihDugmesi(
                metin: tarih == null
                    ? metinler.hesap_kayit_dogum_tarihi_bos
                    : metinler.hesap_kayit_dogum_tarihi_deger(tarih),
                secili: tarih != null,
                hatali: hatali,
                onTap: onSec,
              ),
            ],
          ),
        ),
        if (hatali) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: metinler.hesap_kayit_dogum_tarihi_hata),
        ],
        const SizedBox(height: TayfamSpacing.s20),
        DecoratedBox(
          decoration: BoxDecoration(
            color: r.kart,
            border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
            borderRadius: TayfamRadii.onizlemeKoseleri,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.lock_outline,
                    color: r.marka,
                    size: TayfamSizes.ikon,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  child: Text(
                    metinler.hesap_kayit_dogum_gizlilik,
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinGovde,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Doğum tarihi alanı: dokununca tarih seçici açılır.
class _TarihDugmesi extends StatelessWidget {
  const _TarihDugmesi({
    required this.metin,
    required this.secili,
    required this.hatali,
    required this.onTap,
  });

  final String metin;
  final bool secili;
  final bool hatali;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final koseler = RoundedRectangleBorder(
      borderRadius: TayfamRadii.dugmeKoseleri,
      side: BorderSide(
        color: hatali ? r.nar : r.girisKenari,
        width: hatali ? TayfamSizes.alanOdakKenari : TayfamSizes.vurguKenari,
      ),
    );
    return Material(
      color: r.kart,
      shape: koseler,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: koseler,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    metin,
                    style: context.yazi.titleMedium?.copyWith(
                      color: secili ? r.metin : r.metinIkincil,
                    ),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
                ExcludeSemantics(
                  child: Icon(
                    Icons.calendar_today_outlined,
                    color: r.marka,
                    size: TayfamSizes.ikon,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferansAdimi extends StatelessWidget {
  const _ReferansAdimi({
    required this.tarih,
    required this.denetleyici,
    required this.hatali,
    required this.onChanged,
    required this.onSubmitted,
  });

  final DateTime? tarih;
  final TextEditingController denetleyici;
  final bool hatali;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final tarih = this.tarih;
    final yazi = context.yazi.titleMedium;
    final punto = yazi?.fontSize ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tarih != null) ...[
          GidenCevap(metin: metinler.hesap_kayit_dogum_tarihi_deger(tarih)),
          const SizedBox(height: TayfamSpacing.s20),
        ],
        TayfamKonusuyor(
          balonlar: [
            metinler.hesap_kayit_not_ettim,
            metinler.hesap_kayit_referans_soru,
          ],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AlanEtiketi(metin: metinler.hesap_kayit_referans),
              const SizedBox(height: TayfamSpacing.s8),
              TextField(
                controller: denetleyici,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(referansEnUzun),
                ],
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted(),
                style: yazi?.copyWith(
                  letterSpacing: punto * TayfamSizes.kodHarfAraligiOrani,
                ),
                decoration: kayitAlanGorunumu(
                  context,
                  ipucu: metinler.hesap_kayit_referans_ornek,
                  hata: hatali ? metinler.hesap_kayit_referans_hata : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnayAdimi extends ConsumerWidget {
  const _OnayAdimi({
    required this.cevap,
    required this.kodVar,
    required this.surumler,
    required this.aydinlatma,
    required this.kosullar,
    required this.kilitli,
    required this.onAydinlatma,
    required this.onKosullar,
    required this.hata,
  });

  /// Referans adımındaki cevap (kod ya da "Kodum yok").
  final String cevap;
  final bool kodVar;
  final OnaySurumleri surumler;
  final bool aydinlatma;
  final bool kosullar;
  final bool kilitli;
  final ValueChanged<bool> onAydinlatma;
  final ValueChanged<bool> onKosullar;
  final String? hata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final hata = this.hata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cevap.isNotEmpty) ...[
          GidenCevap(metin: cevap),
          const SizedBox(height: TayfamSpacing.s20),
        ],
        TayfamKonusuyor(
          balonlar: [
            if (kodVar)
              metinler.hesap_kayit_tesekkurler
            else
              metinler.hesap_kayit_sorun_degil,
            metinler.hesap_kayit_onay_soru,
          ],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        _OnayKarti(
          etiket: metinler.hesap_aydinlatma_onay,
          isaretli: aydinlatma,
          degisti: kilitli ? null : onAydinlatma,
          baglantiOkunusu: metinler.hesap_aydinlatma_ac,
          onAc: () => disBaglantiyiAc(
            context,
            ref,
            surumler.adres(HukukiMetin.aydinlatma),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        _OnayKarti(
          etiket: metinler.hesap_kosullar_onay,
          isaretli: kosullar,
          degisti: kilitli ? null : onKosullar,
          baglantiOkunusu: metinler.hesap_kosullar_ac,
          onAc: () => disBaglantiyiAc(
            context,
            ref,
            surumler.adres(HukukiMetin.kosullar),
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s16),
          HataSatiri(metin: hata),
        ],
      ],
    );
  }
}

/// Onay kartı: onay kutusu ve etiketi (tek parça okunur), altında metnin
/// sürümlü sayfasını açan "Metni aç" bağlantısı (ADR-0012 §4).
class _OnayKarti extends StatelessWidget {
  const _OnayKarti({
    required this.etiket,
    required this.isaretli,
    required this.degisti,
    required this.baglantiOkunusu,
    required this.onAc,
  });

  final String etiket;
  final bool isaretli;

  /// `null` ise kutu devre dışıdır (gönderim sürerken).
  final ValueChanged<bool>? degisti;

  /// Bağlantının ekran okuyucudaki adı (hangi metin olduğu).
  final String baglantiOkunusu;
  final VoidCallback onAc;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final degisti = this.degisti;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        border: Border.all(
          color: isaretli ? r.marka : r.cizgi,
          width: isaretli ? TayfamSizes.vurguKenari : TayfamSizes.kenar,
        ),
        borderRadius: TayfamRadii.onizlemeKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s8,
          vertical: TayfamSpacing.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  Checkbox(
                    value: isaretli,
                    onChanged: degisti == null
                        ? null
                        : (deger) => degisti(deger ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: degisti == null ? null : () => degisti(!isaretli),
                      child: Text(etiket, style: context.yazi.titleMedium),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: TayfamSizes.dokunmaMin - TayfamSpacing.s20,
              ),
              child: TextButton.icon(
                onPressed: onAc,
                iconAlignment: IconAlignment.end,
                icon: const Icon(
                  Icons.open_in_new,
                  size: TayfamSizes.ikonKucuk,
                ),
                label: Text(
                  metinler.hesap_kayit_metni_ac,
                  semanticsLabel: baglantiOkunusu,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Doğum tarihi teyidi (ADR-0012 §3; tasarım Kayit-Teyit): "Doğum tarihin
/// 12 Mart 2009. Doğru mu?" — "Düzelt" (`false`) / "Doğru, devam et"
/// (`true`). Yaş sınırı ya da sonucu söylenmez.
class DogumTarihiTeyidi extends StatelessWidget {
  const DogumTarihiTeyidi({super.key, required this.tarih});

  final DateTime tarih;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    return Dialog(
      backgroundColor: r.kart,
      shape: const RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
      ),
      insetPadding: const EdgeInsets.all(TayfamSpacing.s24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TayfamSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IkonKutusu(
                ikon: Icons.event_available_outlined,
                zemin: r.tintMango,
                renk: r.tintMangoUstu,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            Semantics(
              header: true,
              child: Text(
                metinler.hesap_teyit_metin(tarih),
                style: context.yazi.headlineSmall,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              metinler.hesap_kayit_teyit_aciklama,
              style: context.yazi.bodySmall?.copyWith(color: r.metinGovde),
            ),
            const SizedBox(height: TayfamSpacing.s20),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: CerceveliEylem(
                    etiket: metinler.hesap_teyit_duzelt,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s12),
                Expanded(
                  flex: 7,
                  child: BirincilEylem(
                    etiket: metinler.hesap_teyit_devam,
                    onPressed: () => Navigator.of(context).pop(true),
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
