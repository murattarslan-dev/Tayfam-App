import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/harita/harita_secici_ekrani.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/gunluk_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_deposu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kayıt ekleme formu (alttan sayfa): günlüğün alanları tek alan
/// çiziciyle, isteğe bağlı fotoğraf (mevcut medya akışı: yüklemeden önce
/// cihazda işlenir, konum bilgisi silinir) ve günlükte konum açıksa
/// isteğe bağlı yer ile yerin kime görüneceği.
///
/// Yer, kişinin haritada bilerek işaretlediği noktadır (içerik); cihazın
/// anlık konumu kullanılmaz (kesin kural 3). Görünürlüğün varsayılanı
/// günlüğün `location_default`'udur (yoksa "Yalnızca ben").
///
/// Tayfa sözlüğüne bağlı metin alanı otomatik tamamlamalıdır
/// ([SozlukGirisi]; App ADR-0031 §5): seçilen değer kimliğiyle, yeni metin
/// metin olarak gider. Öneriler yalnızca form açıkken bellektedir.
///
/// `client_request_id` form açılınca bir kez üretilir; gönderim başarısız
/// olursa form açık kalır, hatayı gösterir ve tekrar denemede aynı id
/// gönderilir (ADR-0005).
class KayitFormu extends ConsumerStatefulWidget {
  const KayitFormu({
    super.key,
    required this.tayfaId,
    required this.alanlar,
    required this.konumAcik,
    required this.gonder,
    this.varsayilanGorunurluk,
    this.merkez,
  });

  /// Fotoğraf yüklemesinin tayfası (`log_photo`).
  final String tayfaId;

  /// Kaydın alanları (bileşenin `fields` parametresi).
  final List<CatalogField> alanlar;

  /// Günlükte konum açık mı (`location_enabled`).
  final bool konumAcik;

  /// Yeni kaydın konum görünürlüğünün varsayılanı (`location_default`).
  final LogLocationVisibility? varsayilanGorunurluk;

  /// Harita seçicinin açılacağı nokta (buluşma noktası); yoksa Türkiye.
  final LatLng? merkez;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventLogEntryCreateRequest istek) gonder;

  @override
  ConsumerState<KayitFormu> createState() => _KayitFormuState();
}

/// Formda seçilebilen konum görünürlükleri, sözleşmedeki sırayla.
const List<LogLocationVisibility> _gorunurlukler = [
  LogLocationVisibility.self,
  LogLocationVisibility.participants,
  LogLocationVisibility.tayfa,
];

class _KayitFormuState extends ConsumerState<KayitFormu> {
  late final String _istekKimligi = ref.read(etkinlikIstekKimligiProvider)();
  AlanDegerleri _degerler = const {};

  /// Sözlükten seçilen değerler: alan anahtarı → değerin kimliği.
  Map<String, String> _sozlukKimlikleri = const {};
  LatLng? _yer;
  late LogLocationVisibility _gorunurluk =
      _gorunurlukler.contains(widget.varsayilanGorunurluk)
      ? widget.varsayilanGorunurluk!
      : LogLocationVisibility.self;
  String? _fotograf;
  Map<String, AlanHatasi> _alanHatalari = const {};
  bool _bos = false;
  bool _mesgul = false;
  Object? _hata;

  Future<void> _yerSec() async {
    final secim = await haritaSeciciAc(
      context,
      baslangic: _yer ?? widget.merkez,
    );
    if (secim == null || !mounted) return;
    setState(() => _yer = secim.nokta);
  }

  Future<void> _ekle() async {
    if (_mesgul) return;
    final sonuc = gunlukIstegi(
      alanlar: widget.alanlar,
      degerler: _degerler,
      yer: widget.konumAcik ? _yer : null,
      gorunurluk: _gorunurluk,
      fotograf: _fotograf,
      sozlukKimlikleri: _sozlukKimlikleri,
      istekKimligi: _istekKimligi,
    );
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() {
        _alanHatalari = sonuc.alanHatalari;
        _bos = sonuc.hatalar.contains(GunlukHatasi.bos);
      });
      return;
    }
    setState(() {
      _alanHatalari = const {};
      _bos = false;
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(istek);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _mesgul = false;
        _hata = hata;
      });
    }
  }

  void _sozlukDegisti(String anahtar, String metin, String? kimlik) {
    setState(() {
      final degerler = {..._degerler};
      if (metin.isEmpty) {
        degerler.remove(anahtar);
      } else {
        degerler[anahtar] = metin;
      }
      _degerler = Map.unmodifiable(degerler);
      final kimlikler = {..._sozlukKimlikleri};
      if (kimlik == null) {
        kimlikler.remove(anahtar);
      } else {
        kimlikler[anahtar] = kimlik;
      }
      _sozlukKimlikleri = Map.unmodifiable(kimlikler);
      _bos = false;
    });
  }

  Widget _sozlukAlani(
    CatalogField alan,
    String etiket,
    String? hataMetni,
    TextStyle? hataStili,
  ) {
    final deger = _degerler[alan.key];
    final adAlani = alan.vocabulary!.namespace;
    return SozlukGirisi(
      key: ValueKey('katalog-alan-${alan.key}'),
      etiket: etiket,
      metin: deger is String ? deger : '',
      kimlik: _sozlukKimlikleri[alan.key],
      enCokUzunluk: alanMetinSiniri(alan),
      hataMetni: hataMetni,
      hataStili: hataStili,
      // Ad alanı katalogdan gelen girdidir; biçimi bozuksa öneri yok.
      ara: (arama) => katalogAnahtariMi(adAlani)
          ? ref
                .read(sozlukDeposuProvider)
                .oneriler(widget.tayfaId, adAlani, arama)
          : Future.value(const <SozlukOnerisi>[]),
      onDegisti: _mesgul
          ? null
          : (metin, kimlik) => _sozlukDegisti(alan.key, metin, kimlik),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yer = _yer;
    final hata = _hata;
    return AracFormSayfasi(
      baslik: m.bilesen_log_ekle,
      onayEtiketi: m.etkinlik_ekle,
      onOnay: _mesgul ? null : () => unawaited(_ekle()),
      alanlar: [
        KatalogAlanlari(
          alanlar: widget.alanlar,
          degerler: _degerler,
          hatalar: _alanHatalari,
          sozlukAlani: _sozlukAlani,
          onDegisti: _mesgul
              ? null
              : (yeni) => setState(() {
                  _degerler = yeni;
                  _bos = false;
                }),
        ),
        if (_bos) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: m.bilesen_log_bos_hata),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        Text(m.bilesen_log_fotograf, style: context.yazi.titleSmall),
        const SizedBox(height: TayfamSpacing.s8),
        FotografAlani(
          amac: UploadPurpose.logPhoto,
          tayfaId: widget.tayfaId,
          deger: _fotograf,
          etiket: m.bilesen_log_fotograf_etiketi,
          bicim: FotografAlaniBicimi.kare,
          etkin: !_mesgul,
          onDegisti: (yeni) => setState(() => _fotograf = yeni),
        ),
        if (widget.konumAcik) ...[
          const SizedBox(height: TayfamSpacing.s12),
          if (yer == null)
            AracDugmesi(
              etiket: m.bilesen_log_yer_sec,
              ikon: Icons.add_location_alt_outlined,
              onPressed: _mesgul ? null : () => unawaited(_yerSec()),
            )
          else ...[
            Text(m.bilesen_log_yer_secildi, style: context.yazi.bodyLarge),
            AracDugmesi(
              etiket: m.bilesen_log_yer_kaldir,
              ikon: Icons.location_off_outlined,
              onPressed: _mesgul ? null : () => setState(() => _yer = null),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Text(m.bilesen_log_yer_kimin, style: context.yazi.titleSmall),
            const SizedBox(height: TayfamSpacing.s8),
            SecimCipleri<LogLocationVisibility>(
              secenekler: [
                for (final g in _gorunurlukler) (g, _gorunurlukAdi(m, g)),
              ],
              secili: _gorunurluk,
              onSecildi: _mesgul
                  ? null
                  : (g) => setState(() => _gorunurluk = g),
            ),
          ],
        ],
        const SizedBox(height: TayfamSpacing.s12),
        SihirbazBilgiKutusu(
          metin: widget.konumAcik
              ? m.bilesen_log_gizlilik_notu
              : m.bilesen_log_gizlilik_notu_konumsuz,
          ikon: Icons.lock_outline,
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

String _gorunurlukAdi(AppLocalizations m, LogLocationVisibility g) =>
    switch (g) {
      LogLocationVisibility.participants => m.bilesen_log_gorunurluk_katilimci,
      LogLocationVisibility.tayfa => m.bilesen_log_gorunurluk_tayfa,
      LogLocationVisibility.self ||
      LogLocationVisibility.unknown => m.bilesen_log_gorunurluk_ben,
    };
