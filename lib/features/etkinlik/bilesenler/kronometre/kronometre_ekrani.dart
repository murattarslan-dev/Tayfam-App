import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_uyarici.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kronometreyi tam ekran açar (gezinme çubuğunun da üstünde).
Future<void> kronometreAc(
  BuildContext context, {
  required String baslik,
  required KronometreTanimi tanim,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => KronometreEkrani(baslik: baslik, tanim: tanim),
  ),
);

/// Kronometre ekranı (ADR-0031 §3): tam ekran; geri sayım ve ileri sayımda
/// ortada büyük rakamlar ve altta düğmeler, satranç saatinde iki büyük
/// dokunma alanı (üstteki ters döner; tahtanın iki yanındaki oyuncu için).
///
/// - Süre başlangıç anından hesaplanır; ekran kapanıp açılınca ya da
///   uygulama öne gelince doğru değer gösterilir.
/// - Ekran açıkken cihaz ekranı kendiliğinden kapanmaz; ekrandan çıkınca bu
///   bırakılır.
/// - Sayım animasyonu yoktur, yalnızca rakam değişir (sabit genişlikli
///   rakamlar, kayma olmaz). Satranç saatinde sıranın geçişi
///   [TayfamMotion.kisa] süren renk geçişidir; "hareketi azalt" açıkken
///   anında değişir.
/// - Ekran okuyucu rakamları süre olarak okur ("Kalan süre 4 dakika 3
///   saniye") ama her saniye anons etmez; yalnızca süre dolunca "Süre
///   doldu." duyurulur. Durum renkle birlikte metinle de söylenir.
class KronometreEkrani extends ConsumerStatefulWidget {
  const KronometreEkrani({super.key, required this.baslik, required this.tanim});

  final String baslik;

  final KronometreTanimi tanim;

  @override
  ConsumerState<KronometreEkrani> createState() => _KronometreEkraniState();
}

class _KronometreEkraniState extends ConsumerState<KronometreEkrani> {
  late final KronometreUyarici _uyarici;
  late final AppLifecycleListener _yasam;

  KronometreAyari get _ayar =>
      (mod: widget.tanim.mod, ilkSure: widget.tanim.ilkSure);

  @override
  void initState() {
    super.initState();
    _uyarici = ref.read(kronometreUyariciProvider);
    unawaited(_uyarici.ekraniAcikTut(acik: true));
    _yasam = AppLifecycleListener(
      onResume: () => ref.read(kronometreProvider(_ayar).notifier).yenile(),
    );
  }

  @override
  void dispose() {
    _yasam.dispose();
    unawaited(_uyarici.ekraniAcikTut(acik: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(kronometreProvider(_ayar));
    final n = ref.read(kronometreProvider(_ayar).notifier);
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslik)),
      body: SafeArea(
        child: d.mod == KronometreModu.satrancSaati
            ? _SatrancSaati(d: d, n: n, ayar: _ayar, tanim: widget.tanim)
            : _TekSaat(d: d, n: n, ayar: _ayar, tanim: widget.tanim),
      ),
    );
  }
}

/// Büyük rakamlar: alana sığacak kadar büyür, hiç taşmaz.
class _Rakamlar extends StatelessWidget {
  const _Rakamlar({required this.metin, required this.renk});

  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Text(
        metin,
        maxLines: 1,
        style: context.yazi.displayLarge?.copyWith(
          color: renk,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Saniyenin rakamla yazımı (`4:03`, `1:02:03`).
String _rakam(AppLocalizations m, int saniye) =>
    sureMetni(m, saniye.toDouble());

/// Saniyenin ekran okuyucu metni ("4 dakika 3 saniye").
String _okunus(AppLocalizations m, int saniye) =>
    sureOkunusu(m, saniye.toDouble());

/// Geri sayım ve ileri sayım.
class _TekSaat extends StatelessWidget {
  const _TekSaat({
    required this.d,
    required this.n,
    required this.ayar,
    required this.tanim,
  });

  final KronometreDurumu d;
  final KronometreNotifier n;
  final KronometreAyari ayar;
  final KronometreTanimi tanim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saniye = d.gosterilenSaniye();
    final geriSayim = d.mod == KronometreModu.geriSayim;
    final okunus = geriSayim
        ? m.bilesen_timer_kalan(_okunus(m, saniye))
        : m.bilesen_timer_gecen(_okunus(m, saniye));
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Semantics(
                    key: const ValueKey('kronometre-rakamlar'),
                    container: true,
                    label: okunus,
                    excludeSemantics: true,
                    child: Center(
                      child: _Rakamlar(
                        metin: _rakam(m, saniye),
                        renk: d.bitti ? r.narMetin : r.metin,
                      ),
                    ),
                  ),
                ),
                if (d.bitti)
                  Semantics(
                    container: true,
                    liveRegion: true,
                    child: Text(
                      m.bilesen_timer_bitti,
                      textAlign: TextAlign.center,
                      style: context.yazi.titleLarge?.copyWith(
                        color: r.narMetin,
                      ),
                    ),
                  ),
                if (geriSayim && !d.baslatildi)
                  _SureSecimi(ayar: ayar, tanim: tanim),
                const SizedBox(height: TayfamSpacing.s16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    if (!d.bitti)
                      BirincilEylem(
                        etiket: d.calisiyor
                            ? m.bilesen_timer_duraklat
                            : d.duraklatildi
                            ? m.bilesen_timer_devam
                            : m.bilesen_timer_baslat,
                        ikon: d.calisiyor ? Icons.pause : Icons.play_arrow,
                        onPressed: d.calisiyor ? n.duraklat : n.baslat,
                      ),
                    if (d.baslatildi)
                      CerceveliHapEylem(
                        etiket: m.bilesen_timer_sifirla,
                        ikon: Icons.replay,
                        notr: true,
                        onPressed: n.sifirla,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Süre seçimi: tanımdaki ön ayarlar (ve elle girilmiş süre) çip olarak,
/// altında "Süreyi elle gir". Durumu kendisi izler (alttan sayfada da
/// güncel kalsın diye).
class _SureSecimi extends ConsumerWidget {
  const _SureSecimi({required this.ayar, required this.tanim});

  final KronometreAyari ayar;
  final KronometreTanimi tanim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final sure = ref.watch(kronometreProvider(ayar).select((d) => d.sure));
    final n = ref.read(kronometreProvider(ayar).notifier);
    final secenekler = [
      ...tanim.onAyarlar,
      if (!tanim.onAyarlar.contains(sure.inSeconds)) sure.inSeconds,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BolumEtiketi(baslik: m.bilesen_timer_sure),
        SecimCipleri<int>(
          secenekler: [for (final s in secenekler) (s, _rakam(m, s))],
          secili: sure.inSeconds,
          onSecildi: (s) => n.sureSec(Duration(seconds: s)),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BaglantiEylemi(
            etiket: m.bilesen_timer_elle,
            onPressed: () => unawaited(_elleGir(context, n)),
          ),
        ),
      ],
    );
  }

  Future<void> _elleGir(BuildContext context, KronometreNotifier n) async {
    final sure = await altSayfaAc<Duration>(
      context,
      builder: (_) => const KronometreSureFormu(),
    );
    if (sure != null) n.sureSec(sure);
  }
}

/// Elle süre girme formu (alttan sayfa): `1:30` ya da `90`. Geçerli süre
/// sayfayı kapatıp döndürülür; geçersizse alanın altında hata yazılır.
class KronometreSureFormu extends StatefulWidget {
  const KronometreSureFormu({super.key});

  @override
  State<KronometreSureFormu> createState() => _KronometreSureFormuState();
}

class _KronometreSureFormuState extends State<KronometreSureFormu> {
  final TextEditingController _metin = TextEditingController();
  bool _hatali = false;

  /// Alanın en çok karakteri (`86400` ya da `24:00:00`).
  static const int _uzunluk = 8;

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  void _kaydet() {
    final sure = kronometreSuresiniOku(_metin.text);
    if (sure == null) {
      setState(() => _hatali = true);
      return;
    }
    Navigator.of(context).pop(sure);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    // Hata metni ana metin rengindedir (ADR-0004); hatayı kenar rengi ve
    // metin taşır.
    final hataStili = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metin,
    );
    return AracFormSayfasi(
      baslik: m.bilesen_timer_elle,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _kaydet,
      alanlar: [
        TextField(
          key: const ValueKey('kronometre-sure'),
          controller: _metin,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
            LengthLimitingTextInputFormatter(_uzunluk),
          ],
          onChanged: (_) {
            if (_hatali) setState(() => _hatali = false);
          },
          onSubmitted: (_) => _kaydet(),
          decoration: InputDecoration(
            labelText: m.bilesen_timer_elle_alani,
            helperText: m.bilesen_timer_elle_ornek,
            errorText: _hatali ? m.bilesen_timer_elle_hata : null,
            errorStyle: hataStili,
            errorMaxLines: 3,
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// Satranç saati: üstte ters dönen oyuncu (0), ortada denetimler, altta
/// oyuncu (1).
class _SatrancSaati extends StatelessWidget {
  const _SatrancSaati({
    required this.d,
    required this.n,
    required this.ayar,
    required this.tanim,
  });

  final KronometreDurumu d;
  final KronometreNotifier n;
  final KronometreAyari ayar;
  final KronometreTanimi tanim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(TayfamSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RotatedBox(
              quarterTurns: 2,
              child: _Taraf(d: d, n: n, taraf: 0),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: TayfamSpacing.s8,
            children: [
              if (!d.baslatildi)
                IconButton(
                  key: const ValueKey('kronometre-sure-degistir'),
                  tooltip: m.bilesen_timer_sure_degistir,
                  icon: const Icon(Icons.timer_outlined),
                  onPressed: () => unawaited(
                    altSayfaAc<void>(
                      context,
                      builder: (_) => AltSayfaIcerigi(
                        baslik: m.bilesen_timer_sure,
                        children: [_SureSecimi(ayar: ayar, tanim: tanim)],
                      ),
                    ),
                  ),
                ),
              if (d.baslatildi && !d.bitti)
                IconButton(
                  tooltip: d.calisiyor
                      ? m.bilesen_timer_duraklat
                      : m.bilesen_timer_devam,
                  icon: Icon(d.calisiyor ? Icons.pause : Icons.play_arrow),
                  onPressed: d.calisiyor ? n.duraklat : n.baslat,
                ),
              if (d.baslatildi)
                IconButton(
                  tooltip: m.bilesen_timer_sifirla,
                  icon: const Icon(Icons.replay),
                  onPressed: n.sifirla,
                ),
            ],
          ),
          Expanded(child: _Taraf(d: d, n: n, taraf: 1)),
        ],
      ),
    );
  }
}

/// Satranç saatinde bir oyuncunun dokunma alanı: kalan süresi ve durumu
/// ("Sıra sende", "Süre doldu."). Sırası gelen taraf marka renginde, süresi
/// dolan taraf nar tonundadır; durum metinle de yazılır.
class _Taraf extends StatelessWidget {
  const _Taraf({required this.d, required this.n, required this.taraf});

  final KronometreDurumu d;
  final KronometreNotifier n;
  final int taraf;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saniye = d.gosterilenSaniye(taraf);
    final sirasi = d.calisiyor && d.sira == taraf;
    final bitti = d.bitenTaraf == taraf;
    final dokunabilir =
        !d.bitti && (d.sira == null || (d.calisiyor && d.sira == taraf));
    final zemin = bitti
        ? r.tintNar
        : sirasi
        ? r.marka
        : r.kart;
    final yazi = bitti
        ? r.narMetin
        : sirasi
        ? r.markaUstu
        : r.metin;
    final durum = bitti
        ? m.bilesen_timer_bitti
        : sirasi
        ? m.bilesen_timer_sira_sende
        : d.sira == null
        ? m.bilesen_timer_hamle_ipucu
        : null;
    final oyuncu = taraf == 0
        ? m.bilesen_timer_ust_oyuncu
        : m.bilesen_timer_alt_oyuncu;
    final hareketsiz = MediaQuery.disableAnimationsOf(context);
    const koseler = BorderRadius.all(Radius.circular(TayfamRadii.kart));
    return Semantics(
      key: ValueKey('kronometre-taraf-$taraf'),
      container: true,
      button: true,
      enabled: dokunabilir,
      label: m.bilesen_timer_taraf_okunusu(oyuncu, _okunus(m, saniye)),
      value: durum,
      liveRegion: bitti,
      onTap: dokunabilir ? () => n.hamle(taraf) : null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: hareketsiz ? Duration.zero : TayfamMotion.kisa,
        curve: TayfamMotion.egri,
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: koseler,
          border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: koseler,
            onTap: dokunabilir ? () => n.hamle(taraf) : null,
            child: Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: _Rakamlar(metin: _rakam(m, saniye), renk: yazi),
                    ),
                  ),
                  if (durum != null)
                    Text(
                      durum,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.yazi.titleMedium?.copyWith(color: yazi),
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
