import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bolum_etiketi.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/ders_konu_alani.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [birim]'in (sözleşmedeki kapalı birim listesi) çeviri dosyasındaki kısa
/// adı; tanınmayan birim `null` (değer birimsiz gösterilir).
String? katalogBirimAdi(AppLocalizations m, String? birim) => switch (birim) {
  'kg' => m.katalog_birim_kg,
  'piece' => m.katalog_birim_piece,
  'bag' => m.katalog_birim_bag,
  'km' => m.katalog_birim_km,
  'm' => m.katalog_birim_m,
  'altitude_m' => m.katalog_birim_altitude_m,
  'page' => m.katalog_birim_page,
  'minute' => m.katalog_birim_minute,
  'hour' => m.katalog_birim_hour,
  'unit' => m.katalog_birim_unit,
  'goal' => m.katalog_birim_goal,
  'point' => m.katalog_birim_point,
  'night' => m.katalog_birim_night,
  'nm' => m.katalog_birim_nm,
  'box' => m.katalog_birim_box,
  'section' => m.katalog_birim_section,
  'net' => m.katalog_birim_net,
  _ => null,
};

/// [alan]'ın gösterilen adı: katalogdaki `labels`'tan, yerel ayara göre;
/// yoksa alanın anahtarı (ADR-0024 §2).
String katalogAlanAdi(CatalogField alan, String dil) =>
    katalogAdi(alan.labels, dil) ?? alan.key;

/// [alan]'ın [secenek] anahtarının gösterilen adı; adı olmayan seçenek
/// olduğu gibi gösterilir (sözleşme: `option_labels`).
String katalogSecenekAdi(CatalogField alan, String secenek, String dil) =>
    katalogAdi(alan.optionLabels?[secenek], dil) ?? secenek;

/// [hata]'nın [alan] için çeviri dosyasındaki metni.
String katalogAlanHataMetni(
  AppLocalizations m,
  CatalogField alan,
  AlanHatasi hata,
) {
  switch (hata) {
    case AlanHatasi.zorunlu:
      return m.katalog_alan_zorunlu;
    case AlanHatasi.uzunluk:
      return m.katalog_alan_uzunluk(alanMetinSiniri(alan));
    case AlanHatasi.sayi:
      return m.katalog_alan_sayi;
    case AlanHatasi.aralik:
      final aralik = alanAraligi(alan);
      return aralik.enCok >= alanSayiEnCok
          ? m.katalog_alan_en_az(sayiMetni(aralik.enAz))
          : m.katalog_alan_aralik(
              sayiMetni(aralik.enAz),
              sayiMetni(aralik.enCok),
            );
    case AlanHatasi.basamak:
      return m.katalog_alan_basamak(alanBasamagi(alan));
    case AlanHatasi.secim:
      return m.katalog_alan_secim;
    case AlanHatasi.cokSecim:
      return m.katalog_alan_cok_secim(alanEnCokSecim(alan));
    case AlanHatasi.tarih:
      return m.katalog_alan_tarih;
  }
}

/// Bir alanın detayda gösterilen değeri (sunucudan gelen JSON değeri);
/// gösterilecek bir şey yoksa `null`. Değer girdidir: türüne uymayan
/// değer gösterilmez.
///
/// `study_tags` alanı katalogdaki ders/konu listesiyle ([dersKonu])
/// yazılır: her etiket üst zinciriyle, emekli de adıyla; liste yoksa ya da
/// etiket listede hiç yoksa gösterilmez (Tayfam-Api ADR-0043 §4).
String? katalogAlanDegeriMetni(
  BuildContext context,
  CatalogField alan,
  Object? deger, {
  DersKonuAgaci? dersKonu,
}) {
  final m = AppLocalizations.of(context);
  final dil = katalogDili(context);
  final tur = AlanTuru.coz(alan.kind);
  if (tur == null || deger == null) return null;
  String? birimli(String sayi) {
    final birim = katalogBirimAdi(m, alan.unit);
    return birim == null ? sayi : m.katalog_birimli_deger(sayi, birim);
  }

  switch (tur) {
    case AlanTuru.metin:
      return deger is String
          ? katalogDuzMetni(deger, enCok: alanMetinEnCok)
          : null;
    case AlanTuru.uzunMetin:
      return deger is String && deger.trim().isNotEmpty ? deger.trim() : null;
    case AlanTuru.tamSayi:
      return deger is int ? birimli('$deger') : null;
    case AlanTuru.ondalik:
      return deger is num && deger.isFinite
          ? birimli(sayiMetni(deger).replaceAll('.', m.katalog_ondalik_ayraci))
          : null;
    case AlanTuru.sure:
      return deger is int ? m.katalog_sure_degeri(deger) : null;
    case AlanTuru.secim:
      return deger is String ? katalogSecenekAdi(alan, deger, dil) : null;
    case AlanTuru.cokluSecim:
      if (deger is! List<Object?>) return null;
      final adlar = [
        for (final secenek in deger)
          if (secenek is String) katalogSecenekAdi(alan, secenek, dil),
      ];
      return adlar.isEmpty ? null : adlar.join(', ');
    case AlanTuru.dersKonu:
      if (deger is! List<Object?> || dersKonu == null) return null;
      final yollar = [
        for (final anahtar in deger)
          if (anahtar is String) ?dersKonuYolMetni(m, dersKonu, anahtar, dil),
      ];
      return yollar.isEmpty ? null : yollar.join(', ');
    case AlanTuru.evetHayir:
      return deger is bool ? (deger ? m.katalog_evet : m.katalog_hayir) : null;
    case AlanTuru.tarih:
      final tarih = deger is String ? alanTarihiCoz(deger) : null;
      return tarih == null
          ? null
          : MaterialLocalizations.of(context).formatMediumDate(tarih);
  }
}

/// Tek alan çizici (ADR-0024 §3): katalogdaki tür alanlarını (ve `log`
/// bileşeninin kayıt alanlarını) tanımdan çizer. Kapalı alan türü listesi:
/// `text`, `long_text`, `integer`, `decimal`, `choice`, `multi_choice`,
/// `boolean`, `date`, `duration`, `study_tags` (Tayfam-Api ADR-0043;
/// [DersKonuAlani]).
///
/// - Alan adları ve seçenek adları katalog metnidir: düz metin gösterilir,
///   yerel ayara göre seçilir (ADR-0024 §2). Birimler ve hatalar çeviri
///   dosyasındadır.
/// - Zorunlu olmayan alanın adında "(isteğe bağlı)" yazar; hata alanın
///   hemen altında gösterilir ([hatalar]).
/// - Tanınmayan türdeki alan çizilmez.
/// - Değerler [degerler]'dedir ([AlanDegerleri]); her değişiklikte
///   [onDegisti] yeni haritayla çağrılır. [onDegisti] `null` ise alanlar
///   kapalıdır (gönderim sürerken).
/// - Tayfa sözlüğüne bağlı `text` alanı (`vocabulary`) [sozlukAlani]
///   verildiyse onunla çizilir (otomatik tamamlama, App ADR-0031 §5);
///   değeri çağıran tutar. Verilmezse düz metin alanıdır.
class KatalogAlanlari extends StatefulWidget {
  const KatalogAlanlari({
    super.key,
    required this.alanlar,
    required this.degerler,
    required this.onDegisti,
    this.hatalar = const {},
    this.sozlukAlani,
  });

  final List<CatalogField> alanlar;
  final AlanDegerleri degerler;
  final ValueChanged<AlanDegerleri>? onDegisti;
  final Map<String, AlanHatasi> hatalar;

  /// Sözlüğe bağlı alanın çizicisi: alan, etiketi, hata metni ve stili.
  final Widget Function(
    CatalogField alan,
    String etiket,
    String? hataMetni,
    TextStyle? hataStili,
  )?
  sozlukAlani;

  @override
  State<KatalogAlanlari> createState() => _KatalogAlanlariState();
}

class _KatalogAlanlariState extends State<KatalogAlanlari> {
  final Map<String, TextEditingController> _denetleyiciler = {};

  @override
  void didUpdateWidget(KatalogAlanlari eski) {
    super.didUpdateWidget(eski);
    // Değer dışarıdan değiştiyse (tür değişti, form sıfırlandı) metin
    // alanı da değişir; kendi yazdığımız değer zaten aynıdır.
    for (final MapEntry(key: anahtar, value: d) in _denetleyiciler.entries) {
      final deger = widget.degerler[anahtar];
      final metin = deger is String ? deger : '';
      if (d.text != metin) d.text = metin;
    }
  }

  @override
  void dispose() {
    for (final d in _denetleyiciler.values) {
      d.dispose();
    }
    super.dispose();
  }

  TextEditingController _denetleyici(String anahtar) =>
      _denetleyiciler.putIfAbsent(anahtar, () {
        final deger = widget.degerler[anahtar];
        return TextEditingController(text: deger is String ? deger : '');
      });

  void _ayarla(String anahtar, Object? deger) {
    final yeni = {...widget.degerler};
    if (deger == null) {
      yeni.remove(anahtar);
    } else {
      yeni[anahtar] = deger;
    }
    widget.onDegisti?.call(Map.unmodifiable(yeni));
  }

  Future<void> _tarihSec(CatalogField alan) async {
    final mevcut = widget.degerler[alan.key];
    final secili = mevcut is String ? alanTarihiCoz(mevcut) : null;
    final bugun = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: secili ?? DateTime(bugun.year, bugun.month, bugun.day),
      firstDate: DateTime(_ilkYil),
      lastDate: DateTime(_sonYil, DateTime.december, 31),
    );
    if (secilen == null || !mounted) return;
    _ayarla(alan.key, alanTarihiYaz(secilen));
  }

  /// Tarih seçicinin sınırları.
  static const int _ilkYil = 1900;
  static const int _sonYil = 2100;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final acik = widget.onDegisti != null;
    // Hata metni ana metin rengindedir (ADR-0004: nar metin rengi olmaz;
    // açık zeminde 4.5:1'i tutmaz). Hatayı kenar rengi ve metin taşır.
    final hataStili = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metin,
    );
    final cocuklar = <Widget>[];
    for (final alan in widget.alanlar) {
      final tur = AlanTuru.coz(alan.kind);
      if (tur == null || !alanTaniniyor(alan)) continue;
      final ad = katalogAlanAdi(alan, dil);
      final etiket = alan.required_ == true
          ? ad
          : m.katalog_alan_istege_bagli(ad);
      final hata = widget.hatalar[alan.key];
      final hataMetni = hata == null
          ? null
          : katalogAlanHataMetni(m, alan, hata);
      final deger = widget.degerler[alan.key];
      final sozlukAlani = widget.sozlukAlani;
      if (tur == AlanTuru.metin &&
          alan.vocabulary != null &&
          sozlukAlani != null) {
        cocuklar
          ..add(const SizedBox(height: TayfamSpacing.s20))
          ..add(sozlukAlani(alan, etiket, hataMetni, hataStili));
        continue;
      }
      switch (tur) {
        case AlanTuru.dersKonu:
          cocuklar.add(
            DersKonuAlani(
              key: ValueKey('katalog-alan-${alan.key}'),
              alan: alan,
              etiket: etiket,
              deger: deger is List<Object?>
                  ? deger.whereType<String>().toList()
                  : const <String>[],
              hataMetni: hataMetni,
              onDegisti: acik ? (yeni) => _ayarla(alan.key, yeni) : null,
            ),
          );
        case AlanTuru.metin || AlanTuru.uzunMetin:
          final uzun = tur == AlanTuru.uzunMetin;
          cocuklar
            ..add(const SizedBox(height: TayfamSpacing.s20))
            ..add(
              TextField(
                key: ValueKey('katalog-alan-${alan.key}'),
                controller: _denetleyici(alan.key),
                enabled: acik,
                maxLength: alanMetinSiniri(alan),
                minLines: uzun ? 3 : 1,
                maxLines: uzun ? 6 : 1,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => _ayarla(alan.key, v),
                decoration: InputDecoration(
                  labelText: etiket,
                  alignLabelWithHint: uzun,
                  errorText: hataMetni,
                  errorStyle: hataStili,
                  errorMaxLines: 3,
                ),
              ),
            );
        case AlanTuru.tamSayi || AlanTuru.ondalik || AlanTuru.sure:
          final ondalik = tur == AlanTuru.ondalik;
          final eksi = alanAraligi(alan).enAz < 0;
          cocuklar
            ..add(const SizedBox(height: TayfamSpacing.s20))
            ..add(
              TextField(
                key: ValueKey('katalog-alan-${alan.key}'),
                controller: _denetleyici(alan.key),
                enabled: acik,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: ondalik,
                  signed: eksi,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(ondalik ? r'[0-9.,-]' : r'[0-9-]'),
                  ),
                  LengthLimitingTextInputFormatter(_sayiUzunlugu),
                ],
                onChanged: (v) => _ayarla(alan.key, v),
                decoration: InputDecoration(
                  labelText: etiket,
                  suffixText: tur == AlanTuru.sure
                      ? m.katalog_birim_minute
                      : katalogBirimAdi(m, alan.unit),
                  errorText: hataMetni,
                  errorStyle: hataStili,
                  errorMaxLines: 3,
                ),
              ),
            );
        case AlanTuru.secim:
          cocuklar
            ..add(BolumEtiketi(baslik: etiket))
            ..add(
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  for (final secenek in alanSecenekleri(alan))
                    ChoiceChip(
                      label: Text(katalogSecenekAdi(alan, secenek, dil)),
                      selected: deger == secenek,
                      // Zorunlu olmayan alanda seçili seçeneğe yeniden
                      // dokunmak seçimi kaldırır.
                      onSelected: !acik
                          ? null
                          : (_) => _ayarla(
                              alan.key,
                              deger == secenek && alan.required_ != true
                                  ? null
                                  : secenek,
                            ),
                    ),
                ],
              ),
            );
        case AlanTuru.cokluSecim:
          final secili = deger is List<Object?>
              ? deger.whereType<String>().toList()
              : const <String>[];
          final enCok = alanEnCokSecim(alan);
          final dolu = secili.length >= enCok;
          cocuklar
            ..add(
              BolumEtiketi(
                baslik: etiket,
                sag: Text(
                  m.katalog_cok_secim_sayaci(secili.length, enCok),
                  style: context.yazi.bodySmall,
                ),
              ),
            )
            ..add(
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  for (final secenek in alanSecenekleri(alan))
                    FilterChip(
                      label: Text(katalogSecenekAdi(alan, secenek, dil)),
                      selected: secili.contains(secenek),
                      // En çok seçime ulaşılınca yalnızca seçililer
                      // kaldırılabilir.
                      onSelected: !acik || (dolu && !secili.contains(secenek))
                          ? null
                          : (sec) {
                              final yeni = [
                                for (final s in secili)
                                  if (s != secenek) s,
                                if (sec) secenek,
                              ];
                              _ayarla(
                                alan.key,
                                yeni.isEmpty
                                    ? null
                                    : List<String>.unmodifiable(yeni),
                              );
                            },
                    ),
                ],
              ),
            );
        case AlanTuru.evetHayir:
          cocuklar
            ..add(BolumEtiketi(baslik: etiket))
            ..add(
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  for (final (secenek, secenekAdi) in [
                    (true, m.katalog_evet),
                    (false, m.katalog_hayir),
                  ])
                    ChoiceChip(
                      label: Text(secenekAdi),
                      selected: deger == secenek,
                      onSelected: !acik
                          ? null
                          : (_) => _ayarla(
                              alan.key,
                              deger == secenek && alan.required_ != true
                                  ? null
                                  : secenek,
                            ),
                    ),
                ],
              ),
            );
        case AlanTuru.tarih:
          final tarih = deger is String ? alanTarihiCoz(deger) : null;
          cocuklar
            ..add(BolumEtiketi(baslik: etiket))
            ..add(
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: acik ? () => unawaited(_tarihSec(alan)) : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          TayfamSizes.dokunmaMin,
                        ),
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        tarih == null
                            ? m.katalog_tarih_sec
                            : MaterialLocalizations.of(context)
                                  .formatMediumDate(tarih),
                      ),
                    ),
                  ),
                  if (tarih != null && alan.required_ != true)
                    IconButton(
                      tooltip: m.katalog_tarih_temizle,
                      constraints: const BoxConstraints(
                        minWidth: TayfamSizes.dokunmaMin,
                        minHeight: TayfamSizes.dokunmaMin,
                      ),
                      onPressed: acik ? () => _ayarla(alan.key, null) : null,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            );
      }
      // Metin alanları ve ders/konu alanı hatayı kendisi gösterir;
      // diğerlerinde satır.
      final kendiHatasi =
          tur == AlanTuru.dersKonu ||
          tur == AlanTuru.metin ||
          tur == AlanTuru.uzunMetin ||
          tur == AlanTuru.tamSayi ||
          tur == AlanTuru.ondalik ||
          tur == AlanTuru.sure;
      if (hataMetni != null && !kendiHatasi) {
        cocuklar
          ..add(const SizedBox(height: TayfamSpacing.s8))
          ..add(HataSatiri(metin: hataMetni));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cocuklar,
    );
  }

  /// Sayı alanına yazılabilen en çok karakter.
  static const int _sayiUzunlugu = 20;
}
