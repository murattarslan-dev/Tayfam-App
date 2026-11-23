import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Arama kutusu bu kadar türden sonra gösterilir (az türde gereksizdir).
const int turAramaEsigi = 8;

/// [turler] içinden adı [sorgu]'yu içerenler (Türkçe küçük harfle; arama
/// için, ADR-0008). Boş sorgu hepsini döndürür.
List<CatalogEventType> turAra(
  List<CatalogEventType> turler,
  String sorgu,
  String dil,
) {
  final aranan = turkceKucukHarf(sorgu.trim());
  if (aranan.isEmpty) return turler;
  return [
    for (final tur in turler)
      if (turkceKucukHarf(katalogAdi(tur.labels, dil) ?? tur.key)
          .contains(aranan))
        tur,
  ];
}

/// Tür seçici (ADR-0024 §4): sihirbazın tür adımının gövdesi.
///
/// Türler katalogdan gelir: önce tayfanın ilgi alanlarındaki türler
/// ([ilgiAlanlari]), sonra "Tüm türler" (ilgi alanına göre gruplu,
/// aranabilir). Emekli (`retired`) türler listelenmez. Alan türü
/// tanınmayan tür listelenir ama seçilemez ("uygulamayı güncelle";
/// ADR-0024 §3).
///
/// Katalog gelene kadar yükleniyor durumu, okunamazsa "Tekrar dene"
/// gösterilir. Tür adları katalog metnidir (düz metin; ADR-0024 §2).
class TurSecici extends StatefulWidget {
  const TurSecici({
    super.key,
    required this.secili,
    required this.onSecildi,
    this.ilgiAlanlari = const [],
  });

  /// Seçili türün anahtarı; yoksa `null`.
  final String? secili;

  /// `null` ise seçim kapalıdır (gönderim sürerken).
  final ValueChanged<CatalogEventType>? onSecildi;

  /// Tayfanın ilgi alanları (katalog anahtarları); anlık etkinlikte boş.
  final List<String> ilgiAlanlari;

  @override
  State<TurSecici> createState() => _TurSeciciState();
}

class _TurSeciciState extends State<TurSecici> {
  final TextEditingController _arama = TextEditingController();
  String _sorgu = '';

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  List<Widget> _kutular(
    List<CatalogEventType> turler,
    Katalog katalog,
    String dil,
  ) => [
    for (final tur in turler)
      TurKutusu(
        gorunum: turTanimiGorunumu(tur, katalog, dil),
        secili: widget.secili == tur.key,
        guncellemeGerekli: !alanlarTaniniyor(
          tur.definition.fields ?? const <CatalogField>[],
        ),
        onSecildi: widget.onSecildi == null
            ? null
            : () => widget.onSecildi!(tur),
      ),
  ];

  @override
  Widget build(BuildContext context) => KatalogBekleyici(builder: _liste);

  Widget _liste(BuildContext context, Katalog katalog) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final turler = katalog.secilebilirTurler;
    final arama = _sorgu.trim().isNotEmpty;
    final bulunan = turAra(turler, _sorgu, dil);
    // Tayfanın ilgi alanlarındaki türler, ilgi alanlarının sırasıyla;
    // birden fazla ilgi alanında yer alan tür bir kez.
    final onde = <CatalogEventType>[];
    for (final ilgi in widget.ilgiAlanlari) {
      for (final tur in katalog.ilgiAlanininTurleri(ilgi)) {
        if (!onde.contains(tur)) onde.add(tur);
      }
    }
    // "Tüm türler": ilgi alanına göre gruplu; tür ana ilgi alanında
    // (ilk `interest_keys`) bir kez listelenir.
    final gruplar = <(String?, List<CatalogEventType>)>[
      for (final ilgi in katalog.ilgiAlanlari)
        (
          katalogAdi(ilgi.labels, dil),
          [
            for (final tur in bulunan)
              if (tur.interestKeys.firstOrNull == ilgi.key) tur,
          ],
        ),
      // İlgi alanı katalogda olmayan türler sonda, başlıksız.
      (
        null,
        [
          for (final tur in bulunan)
            if (katalog.ilgiAlani(tur.interestKeys.firstOrNull ?? '') == null)
              tur,
        ],
      ),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onde.isNotEmpty && !arama) ...[
          BolumEtiketi(baslik: m.etkinlik_tur_ilgi_alanlari),
          IkiSutunluIzgara(children: _kutular(onde, katalog, dil)),
        ],
        BolumEtiketi(baslik: m.katalog_tum_turler),
        if (turler.length > turAramaEsigi) ...[
          TextField(
            controller: _arama,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _sorgu = v),
            decoration: InputDecoration(
              labelText: m.katalog_tur_ara,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: arama
                  ? IconButton(
                      tooltip: m.katalog_aramayi_temizle,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _arama.clear();
                        setState(() => _sorgu = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
        ],
        if (gruplar.isEmpty)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s16),
              child: Text(
                arama ? m.katalog_tur_bulunamadi : m.katalog_tur_yok,
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
            ),
          ),
        for (final (ad, grup) in gruplar) ...[
          if (ad != null && gruplar.length > 1)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: TayfamSpacing.s4,
                top: TayfamSpacing.s12,
                bottom: TayfamSpacing.s8,
              ),
              child: Semantics(
                header: true,
                child: Text(ad, style: context.yazi.labelLarge),
              ),
            )
          else
            const SizedBox(height: TayfamSpacing.s8),
          IkiSutunluIzgara(children: _kutular(grup, katalog, dil)),
        ],
      ],
    );
  }
}

/// Tür seçim kutusu (tasarım: Sihirbaz-Tur): türün renginde ikon kutusu ve
/// ad; seçiliyken marka kenar, tint zemin ve işaret. Renk tek başına bilgi
/// taşımaz: seçim ekran okuyucuda da bildirilir.
///
/// [guncellemeGerekli] ise tür bu sürümde oluşturulamaz (alan türü
/// tanınmıyor): kutu kapalıdır ve nedenini yazar.
class TurKutusu extends StatelessWidget {
  const TurKutusu({
    super.key,
    required this.gorunum,
    required this.secili,
    required this.onSecildi,
    this.guncellemeGerekli = false,
  });

  final KatalogGorunumu gorunum;
  final bool secili;
  final bool guncellemeGerekli;
  final VoidCallback? onSecildi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final cift = context.turRenkleri.cift(gorunum.renk);
    final acik = !guncellemeGerekli && onSecildi != null;
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
          button: true,
          enabled: acik,
          selected: secili,
          inMutuallyExclusiveGroup: true,
          child: InkWell(
            onTap: acik ? onSecildi : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.turKutusu,
              ),
              child: Padding(
                padding: const EdgeInsets.all(TayfamSpacing.s12),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cift.dolgu,
                              borderRadius: TayfamRadii.dugmeKoseleri,
                            ),
                            child: SizedBox.square(
                              dimension: TayfamSizes.menuIkonKutusu,
                              child: Icon(
                                gorunum.ikon,
                                size: TayfamSizes.ikon,
                                color: cift.ustu,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s8),
                        Text(
                          gorunum.ad ?? m.katalog_tur_bilinmiyor,
                          style: context.yazi.titleMedium,
                        ),
                        if (guncellemeGerekli)
                          Text(
                            m.katalog_tur_guncelle,
                            style: context.yazi.bodySmall,
                          ),
                      ],
                    ),
                    if (secili)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: r.marka,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox.square(
                              dimension: TayfamSizes.seciliIsareti,
                              child: Icon(
                                Icons.check,
                                size: TayfamSizes.ikonKucuk,
                                color: r.markaUstu,
                              ),
                            ),
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
