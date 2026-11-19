import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_deposu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sözlüklerin tayfa ayarları altındaki yolu
/// (`/t/<tayfaId>/ayarlar/sozlukler`).
const String sozluklerYolu = 'sozlukler';

/// Bir sözlüğün adresindeki ad alanı parametresi.
const String sozlukAdAlaniParametresi = 'adAlani';

/// Sözlüklerin [tayfaId] tayfasındaki adresi.
String sozluklerAdresi(String tayfaId) =>
    '${Adresler.tayfaAyarlari(tayfaId)}/$sozluklerYolu';

/// [adAlani] sözlüğünün [tayfaId] tayfasındaki adresi.
String sozlukAdresi(String tayfaId, String adAlani) =>
    '${sozluklerAdresi(tayfaId)}/$adAlani';

/// Sözlüklerin `ayarlar/` altındaki rotaları
/// (`tayfaYonetimRotalari(ekRotalar:)`'a verilir).
final List<RouteBase> sozlukRotalari = [
  GoRoute(
    path: sozluklerYolu,
    builder: (context, state) => SozluklerEkrani(
      tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
    ),
    routes: [
      GoRoute(
        path: ':$sozlukAdAlaniParametresi',
        builder: (context, state) => SozlukEkrani(
          tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
          adAlani: state.pathParameters[sozlukAdAlaniParametresi]!,
        ),
      ),
    ],
  ),
];

/// Ayarlar ekranındaki "Sözlükler" girişinin ikonu.
const IconData sozlukGirisIkonu = Icons.menu_book_outlined;

/// Ayarlar ekranındaki "Sözlükler" girişinin etiketi.
String sozlukGirisEtiketi(BuildContext context) =>
    AppLocalizations.of(context).bilesen_vocab_baslik;

/// Tayfa ayarları → Sözlükler (App ADR-0031 §5): katalogda tayfa sözlüğü
/// kullanan günlük alanları (ad alanları). Her satır alanın adı ve onu
/// kullanan türlerle sözlüğün ekranını açar. Ekrana rol bakılmadan
/// gidilebilir; birleştirme yetkisini sunucu verir (kesin kural 5).
class SozluklerEkrani extends StatelessWidget {
  const SozluklerEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(m.bilesen_vocab_baslik)),
      body: ListView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        children: [
          Text(
            m.bilesen_vocab_aciklama,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          KatalogBekleyici(
            builder: (context, katalog) {
              final dil = katalogDili(context);
              final adAlanlari = sozlukAdAlanlari(katalog);
              if (adAlanlari.isEmpty) {
                return _BosMetin(m.bilesen_vocab_sozluk_yok);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in adAlanlari)
                    MenuSatiri(
                      ikon: sozlukGirisIkonu,
                      baslik: katalogAlanAdi(a.alan, dil),
                      aciklama: [
                        for (final t in a.turler)
                          katalogAdi(t.labels, dil) ?? t.key,
                      ].join(', '),
                      onTap: () =>
                          context.go(sozlukAdresi(tayfaId, a.adAlani)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bir sözlüğün değerleri (Tayfa ayarları → Sözlükler → ad alanı; App
/// ADR-0031 §5). "Değerler" ve "Birleştirilenler" seçicisi, arama ve
/// liste.
///
/// - Değerler: değere "Birleştir" → hedef seçimi (alttan sayfa, arama) →
///   istatistiğin yeniden hesaplanacağını söyleyen onay →
///   `POST …/merge`. Birleştirme tek düzeydir; hedef listesinde yalnızca
///   birleştirilmemiş değerler vardır.
/// - Birleştirilenler: "<değer>" ve "“<hedef>” olarak görünüyor"; "Geri al"
///   onayla `DELETE …/merge`.
///
/// Düğmeler yalnızca `caller_can_merge` ise görünür; yetkiyi yine sunucu
/// verir ve hatası gösterilir (kesin kural 5). Liste yalnızca bellektedir.
class SozlukEkrani extends ConsumerStatefulWidget {
  const SozlukEkrani({super.key, required this.tayfaId, required this.adAlani});

  final String tayfaId;

  /// Adresteki ad alanı; girdidir, biçimi burada doğrulanır.
  final String adAlani;

  @override
  ConsumerState<SozlukEkrani> createState() => _SozlukEkraniState();
}

class _SozlukEkraniState extends ConsumerState<SozlukEkrani> {
  final TextEditingController _arama = TextEditingController();
  Timer? _zamanlayici;
  bool _birlesmis = false;
  String _sorgu = '';
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    // Başlık için katalog; durum derleme sırasında değiştirilmez.
    final katalog = ref.read(katalogProvider.notifier);
    unawaited(Future<void>.microtask(katalog.gerekli));
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _arama.dispose();
    super.dispose();
  }

  SozlukSorgusu get _anahtar => (
    tayfaId: widget.tayfaId,
    adAlani: widget.adAlani,
    birlesmis: _birlesmis,
    arama: _sorgu,
  );

  void _aramaDegisti(String metin) {
    _zamanlayici?.cancel();
    _zamanlayici = Timer(sozlukAramaGecikmesi, () {
      if (!mounted) return;
      setState(() => _sorgu = _aramaMetni(metin));
    });
  }

  Future<void> _birlestir(TayfaVocabularyValue kaynak) async {
    final m = AppLocalizations.of(context);
    final hedef = await aracFormuAc<TayfaVocabularyValue>(
      context,
      (_) => HedefSecici(
        tayfaId: widget.tayfaId,
        adAlani: widget.adAlani,
        kaynak: kaynak,
      ),
    );
    if (hedef == null || !mounted) return;
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_vocab_onay_baslik,
      metin: m.bilesen_vocab_onay_aciklama(kaynak.value, hedef.value),
      eylem: m.bilesen_vocab_birlestir,
    );
    if (!onay || !mounted) return;
    await _islem(
      () => ref
          .read(sozlukDeposuProvider)
          .birlestir(widget.tayfaId, widget.adAlani, kaynak.id, hedef.id),
      m.bilesen_vocab_birlestirildi,
    );
  }

  Future<void> _geriAl(TayfaVocabularyValue deger) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_vocab_geri_al_onay_baslik,
      metin: m.bilesen_vocab_geri_al_onay_aciklama(deger.value),
      eylem: m.bilesen_vocab_geri_al,
    );
    if (!onay || !mounted) return;
    await _islem(
      () => ref
          .read(sozlukDeposuProvider)
          .geriAl(widget.tayfaId, widget.adAlani, deger.id),
      m.bilesen_vocab_geri_alindi,
    );
  }

  /// İşlemi yapar, sonucu bildirir ve sözlük listelerini yeniden okutur
  /// (hata da listeyi bayatlatmış olabilir: değer başkasınca
  /// birleştirilmiş ya da geri alınmış).
  Future<void> _islem(Future<void> Function() islem, String basari) async {
    final m = AppLocalizations.of(context);
    setState(() => _mesgul = true);
    Object? hata;
    try {
      await islem();
    } on Exception catch (e) {
      hata = e;
    }
    if (!mounted) return;
    setState(() => _mesgul = false);
    ref.invalidate(sozlukListesiProvider);
    aracBildir(context, hata == null ? basari : hataMetni(m, hata));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final gecerli = katalogAnahtariMi(widget.adAlani);
    final katalog = ref.watch(katalogProvider).value;
    String? baslik;
    if (katalog != null && gecerli) {
      for (final a in sozlukAdAlanlari(katalog)) {
        if (a.adAlani == widget.adAlani) {
          baslik = katalogAlanAdi(a.alan, katalogDili(context));
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik ?? m.bilesen_vocab_baslik),
            if (baslik != null)
              Text(m.bilesen_vocab_baslik, style: context.yazi.bodySmall),
          ],
        ),
      ),
      body: !gecerli
          ? Padding(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: _BosMetin(m.bilesen_vocab_gecersiz),
            )
          : ListView(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              children: [
                SecimCipleri<bool>(
                  secenekler: [
                    (false, m.bilesen_vocab_degerler),
                    (true, m.bilesen_vocab_birlesenler),
                  ],
                  secili: _birlesmis,
                  onSecildi: (b) => setState(() => _birlesmis = b),
                ),
                const SizedBox(height: TayfamSpacing.s12),
                _AramaAlani(denetleyici: _arama, onDegisti: _aramaDegisti),
                const SizedBox(height: TayfamSpacing.s12),
                _Liste(
                  durum: ref.watch(sozlukListesiProvider(_anahtar)),
                  birlesmis: _birlesmis,
                  mesgul: _mesgul,
                  onTekrar: () =>
                      ref.invalidate(sozlukListesiProvider(_anahtar)),
                  onBirlestir: (d) => unawaited(_birlestir(d)),
                  onGeriAl: (d) => unawaited(_geriAl(d)),
                ),
              ],
            ),
    );
  }
}

/// Arama metninin sözleşmedeki sınırı (`q`, en fazla 60 karakter).
String _aramaMetni(String metin) =>
    String.fromCharCodes(metin.trim().runes.take(sozlukAramaEnCok));

class _AramaAlani extends StatelessWidget {
  const _AramaAlani({required this.denetleyici, required this.onDegisti});

  final TextEditingController denetleyici;
  final ValueChanged<String> onDegisti;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: denetleyici,
      onChanged: onDegisti,
      maxLength: sozlukAramaEnCok,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).bilesen_vocab_ara,
        prefixIcon: const ExcludeSemantics(child: Icon(Icons.search)),
        counterText: '',
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.durum,
    required this.birlesmis,
    required this.mesgul,
    required this.onTekrar,
    required this.onBirlestir,
    required this.onGeriAl,
  });

  final AsyncValue<TayfaVocabularyList> durum;
  final bool birlesmis;
  final bool mesgul;
  final VoidCallback onTekrar;
  final ValueChanged<TayfaVocabularyValue> onBirlestir;
  final ValueChanged<TayfaVocabularyValue> onGeriAl;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final liste = durum.value;
    final hata = durum.error;
    if (liste == null) {
      if (hata != null) return YuklemeHatasi(hata: hata, onTekrarDene: onTekrar);
      return Center(
        child: TayfamYukleniyor(etiket: m.bilesen_vocab_yukleniyor),
      );
    }
    final degerler = [
      for (final d in liste.values)
        if ((d.mergedIntoId != null) == birlesmis) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!liste.callerCanMerge) ...[
          SihirbazBilgiKutusu(metin: m.bilesen_vocab_yetki_yok),
          const SizedBox(height: TayfamSpacing.s12),
        ],
        if (degerler.isEmpty)
          _BosMetin(
            birlesmis ? m.bilesen_vocab_birlesen_yok : m.bilesen_vocab_deger_yok,
          ),
        for (final (sira, d) in degerler.indexed) ...[
          if (sira > 0) Divider(height: TayfamSizes.kenar, color: context.renkler.cizgi),
          _DegerSatiri(
            deger: d,
            eylem: !liste.callerCanMerge
                ? null
                : birlesmis
                ? (
                    m.bilesen_vocab_geri_al,
                    m.bilesen_vocab_geri_al_etiketi(d.value),
                    mesgul ? null : () => onGeriAl(d),
                  )
                : (
                    m.bilesen_vocab_birlestir,
                    m.bilesen_vocab_birlestir_etiketi(d.value),
                    mesgul ? null : () => onBirlestir(d),
                  ),
          ),
        ],
      ],
    );
  }
}

/// Bir sözlük değerinin satırı: metni, birleştirilmişse hedefi ve
/// isteğe bağlı eylem (etiket, ekran okuyucu etiketi, dokunma).
class _DegerSatiri extends StatelessWidget {
  const _DegerSatiri({required this.deger, required this.eylem});

  final TayfaVocabularyValue deger;
  final (String, String, VoidCallback?)? eylem;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final hedef = deger.mergedIntoValue;
    final eylem = this.eylem;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deger.value,
                    style: context.yazi.bodyLarge?.copyWith(color: r.metin),
                  ),
                  if (hedef != null)
                    Text(
                      m.bilesen_vocab_hedefi(hedef),
                      style: context.yazi.bodyMedium?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                ],
              ),
            ),
            if (eylem != null) ...[
              const SizedBox(width: TayfamSpacing.s8),
              TextButton(
                onPressed: eylem.$3,
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(eylem.$1, semanticsLabel: eylem.$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Birleştirme hedefinin seçimi (alttan sayfa): arama ve birleştirilmemiş
/// değerler; [kaynak] listede yoktur. Seçilen değerle kapanır.
class HedefSecici extends ConsumerStatefulWidget {
  const HedefSecici({
    super.key,
    required this.tayfaId,
    required this.adAlani,
    required this.kaynak,
  });

  final String tayfaId;
  final String adAlani;
  final TayfaVocabularyValue kaynak;

  @override
  ConsumerState<HedefSecici> createState() => _HedefSeciciState();
}

class _HedefSeciciState extends ConsumerState<HedefSecici> {
  final TextEditingController _arama = TextEditingController();
  Timer? _zamanlayici;
  String _sorgu = '';

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _arama.dispose();
    super.dispose();
  }

  void _aramaDegisti(String metin) {
    _zamanlayici?.cancel();
    _zamanlayici = Timer(sozlukAramaGecikmesi, () {
      if (!mounted) return;
      setState(() => _sorgu = _aramaMetni(metin));
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final anahtar = (
      tayfaId: widget.tayfaId,
      adAlani: widget.adAlani,
      birlesmis: false,
      arama: _sorgu,
    );
    final durum = ref.watch(sozlukListesiProvider(anahtar));
    final liste = durum.value;
    final hata = durum.error;
    final Widget icerik;
    if (liste == null) {
      icerik = hata != null
          ? YuklemeHatasi(
              hata: hata,
              onTekrarDene: () =>
                  ref.invalidate(sozlukListesiProvider(anahtar)),
            )
          : Center(child: TayfamYukleniyor(etiket: m.bilesen_vocab_yukleniyor));
    } else {
      final hedefler = [
        for (final d in liste.values)
          if (d.id != widget.kaynak.id && d.mergedIntoId == null) d,
      ];
      icerik = hedefler.isEmpty
          ? _BosMetin(m.bilesen_vocab_deger_yok)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (sira, d) in hedefler.indexed) ...[
                  if (sira > 0) Divider(height: TayfamSizes.kenar, color: r.cizgi),
                  MergeSemantics(
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(d),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: TayfamSizes.dokunmaMin,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TayfamSpacing.s8,
                              vertical: TayfamSpacing.s12,
                            ),
                            child: Text(
                              d.value,
                              style: context.yazi.bodyLarge?.copyWith(
                                color: r.metin,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AltSayfaIcerigi(
        baslik: m.bilesen_vocab_hedef_baslik(widget.kaynak.value),
        children: [
          _AramaAlani(denetleyici: _arama, onDegisti: _aramaDegisti),
          const SizedBox(height: TayfamSpacing.s12),
          icerik,
        ],
      ),
    );
  }
}

class _BosMetin extends StatelessWidget {
  const _BosMetin(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      style: context.yazi.bodyLarge?.copyWith(
        color: context.renkler.metinGovde,
      ),
    );
  }
}
