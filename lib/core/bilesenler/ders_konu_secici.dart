import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/alt_sayfa.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

export 'package:tayfam/core/katalog/ders_konu.dart'
    show
        DersKonuAgaci,
        DersKonuSecimi,
        DersKonuSeviyesi,
        dersAlanAdi,
        dersKonuDegeri,
        konuAlanAdi;

/// Bu sayıdan çok seçenekli listede arama kutusu gösterilir.
const int _aramaEsigi = 8;

/// Seçenek sayfasının ekran yüksekliğine oranla en çok yüksekliği.
const double _sayfaOrani = .85;

/// "Konu belirtme" (ve etiket kipinde "Ders belirtme") seçeneğinin
/// sayfadan dönen değeri.
const String _konusuz = '';

/// Eğitim içeriğinin ortak ders/konu seçicisi (ADR-0033 §2): katalogdaki
/// `study_tags`'ten üç seviye, sırayla açılır: sınav/düzey → ders
/// (zorunlu) → konu (isteğe bağlı, seçilen dersin altından). Her seviye
/// dokununca alttan açılan bir listedir; uzun listede Türkçe kurallarla
/// arama vardır.
///
/// Seçimi çağıran tutar ([secim]); [onDegisti] her değişiklikte yeni
/// seçimle çağrılır. Düzey değişince ders ve konu düşer ve `null` gelir.
/// [onDegisti] `null` ise seçici kapalıdır.
///
/// Emekli etiket ve emekli etiketin altındakiler listede sunulmaz; mevcut
/// değer olarak gelirse adıyla gösterilir ve "artık seçilemez" notu
/// düşülür. Göndermeden önce [DersKonuAgaci.gecerli] ile denetlenebilir;
/// son söz sunucunundur: [dersHatasi] / [konuHatasi], sunucunun
/// [dersAlanAdi] / [konuAlanAdi] alan hatalarının metnidir.
///
/// Etiket listesi boşsa sakin bir boş durum gösterilir. Katalog gelene
/// kadar ve okunamazsa [KatalogBekleyici] çizer. Etiket adları katalog
/// içeriğidir, düz metin gösterilir (ADR-0024 §2).
///
/// [DersKonuSecici.etiket] tür alanının (`study_tags`, Tayfam-Api
/// ADR-0043) kipidir: seçim tek bir anahtardır (seçilen en derin etiket)
/// ve seçilebilecek seviyeler [enSig]–[enDerin] aralığıdır; düzey de
/// seçilebiliyorsa ders, ders seçilebiliyorsa konu isteğe bağlıdır.
class DersKonuSecici extends StatefulWidget {
  const DersKonuSecici({
    super.key,
    required this.secim,
    required this.onDegisti,
    this.dersHatasi,
    this.konuHatasi,
    this.konuSecilir = true,
  }) : etiket = null,
       onEtiketDegisti = null,
       enSig = DersKonuSeviyesi.ders,
       enDerin = DersKonuSeviyesi.konu,
       etiketKipi = false;

  /// Tek anahtarlı kip: [etiket] seçili en derin etiket; [onEtiketDegisti]
  /// her değişiklikte yeni anahtarla, seçim düşünce `null` ile çağrılır
  /// (`null` ise seçici kapalıdır). Alanın hatasını çağıran gösterir.
  const DersKonuSecici.etiket({
    super.key,
    required this.etiket,
    required this.onEtiketDegisti,
    this.enSig = DersKonuSeviyesi.ders,
    this.enDerin = DersKonuSeviyesi.konu,
  }) : secim = null,
       onDegisti = null,
       dersHatasi = null,
       konuHatasi = null,
       konuSecilir = true,
       etiketKipi = true;

  final DersKonuSecimi? secim;
  final ValueChanged<DersKonuSecimi?>? onDegisti;

  /// [DersKonuSecici.etiket] kipinde mi.
  final bool etiketKipi;

  /// Etiket kipinde seçili en derin etiket.
  final String? etiket;

  /// Etiket kipinde değişiklik bildirimi.
  final ValueChanged<String?>? onEtiketDegisti;

  /// Etiket kipinde seçilebilecek en sığ seviye.
  final DersKonuSeviyesi enSig;

  /// Etiket kipinde seçilebilecek en derin seviye.
  final DersKonuSeviyesi enDerin;

  /// Ders alanının altında gösterilen hata (ör. zorunlu, `subject_key`).
  final String? dersHatasi;

  /// Konu alanının altında gösterilen hata (`topic_key`).
  final String? konuHatasi;

  /// `false` ise yalnızca düzey ve ders seçilir.
  final bool konuSecilir;

  @override
  State<DersKonuSecici> createState() => _DersKonuSeciciState();
}

class _DersKonuSeciciState extends State<DersKonuSecici> {
  /// Ders henüz seçilmemişken seçilen düzey; ders seçiliyken düzey dersin
  /// üstüdür.
  String? _duzey;

  @override
  Widget build(BuildContext context) {
    return KatalogBekleyici(
      builder: (context, katalog) => widget.etiketKipi
          ? _cizEtiket(context, katalog.dersKonu)
          : _ciz(context, katalog.dersKonu),
    );
  }

  /// Etiket kipi: seçili anahtarın yolundan düzey, ders ve konu alanları.
  Widget _cizEtiket(BuildContext context, DersKonuAgaci agac) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final onEtiketDegisti = widget.onEtiketDegisti;
    final acik = onEtiketDegisti != null;
    final secili = widget.etiket;
    final enSig = widget.enSig;
    final enDerin = widget.enDerin;
    final duzeySecilir = enSig == DersKonuSeviyesi.duzey;
    if (secili == null &&
        (duzeySecilir ? agac.duzeyler().isEmpty : !agac.secilebilirDersVar)) {
      return const _BosDurum();
    }

    final yol = secili == null ? const <String>[] : agac.yol(secili);
    final duzey = yol.isNotEmpty ? yol[0] : _duzey;
    final ders = yol.length > 1 ? yol[1] : null;
    final konu = yol.length > 2 ? yol[2] : null;
    final dersler = duzey == null || enDerin == DersKonuSeviyesi.duzey
        ? const <CatalogStudyTag>[]
        : agac.altlar(duzey, mevcut: ders);
    final konular = ders == null || enDerin != DersKonuSeviyesi.konu
        ? const <CatalogStudyTag>[]
        : agac.altlar(ders, mevcut: konu);
    final dersGorunur = duzey != null && enDerin != DersKonuSeviyesi.duzey;
    final konuGorunur = ders != null && konular.isNotEmpty;

    String ad(String anahtar) =>
        katalogAdi(agac.etiket(anahtar)?.labels, dil) ?? anahtar;
    String? not(String? anahtar) =>
        anahtar != null && !agac.secilebilir(anahtar)
        ? m.ders_konu_emekli
        : null;
    void bildir(String? yeni) {
      if (yeni != secili) onEtiketDegisti?.call(yeni);
    }

    final dersEtiketi = duzeySecilir
        ? m.ders_konu_ders_istege_bagli
        : m.ders_konu_ders;
    final cocuklar = <Widget>[
      _SeciciAlani(
        etiket: m.ders_konu_duzey,
        deger: duzey == null ? null : ad(duzey),
        not: not(duzey),
        onTap: !acik
            ? null
            : () => unawaited(
                _sec(
                  context,
                  baslik: m.ders_konu_duzey,
                  secenekler: agac.duzeyler(mevcut: duzey),
                  secili: duzey,
                  agac: agac,
                  dil: dil,
                  sonra: (k) {
                    if (k == duzey) return;
                    setState(() => _duzey = k);
                    // Düzey seçilebiliyorsa düzey seçimdir; değilse ders
                    // seçilene kadar seçim yoktur.
                    if (duzeySecilir) {
                      bildir(k);
                    } else if (secili != null) {
                      bildir(null);
                    }
                  },
                ),
              ),
      ),
    ];
    if (dersGorunur) {
      cocuklar
        ..add(const SizedBox(height: TayfamSpacing.s16))
        ..add(
          _SeciciAlani(
            etiket: dersEtiketi,
            deger: ders == null ? null : ad(ders),
            not: not(ders),
            onTap: !acik || dersler.isEmpty
                ? null
                : () => unawaited(
                    _sec(
                      context,
                      baslik: dersEtiketi,
                      secenekler: dersler,
                      secili: ders ?? (duzeySecilir ? _konusuz : null),
                      bosEtiket: duzeySecilir
                          ? m.ders_konu_ders_belirtme
                          : null,
                      agac: agac,
                      dil: dil,
                      sonra: (k) => bildir(k == _konusuz ? duzey : k),
                    ),
                  ),
          ),
        );
    }
    if (konuGorunur) {
      cocuklar
        ..add(const SizedBox(height: TayfamSpacing.s16))
        ..add(
          _SeciciAlani(
            etiket: m.ders_konu_konu,
            deger: konu == null ? null : ad(konu),
            not: not(konu),
            onTap: !acik
                ? null
                : () => unawaited(
                    _sec(
                      context,
                      baslik: m.ders_konu_konu,
                      secenekler: konular,
                      secili: konu ?? _konusuz,
                      bosEtiket: m.ders_konu_konu_belirtme,
                      agac: agac,
                      dil: dil,
                      sonra: (k) => bildir(k == _konusuz ? ders : k),
                    ),
                  ),
          ),
        );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cocuklar,
    );
  }

  Widget _ciz(BuildContext context, DersKonuAgaci agac) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final secim = widget.secim;
    final acik = widget.onDegisti != null;
    if (secim == null && !agac.secilebilirDersVar) {
      return const _BosDurum();
    }

    final duzey = (secim == null ? null : agac.duzeyi(secim)) ?? _duzey;
    final duzeyler = agac.duzeyler(mevcut: duzey);
    final dersler = duzey == null
        ? const <CatalogStudyTag>[]
        : agac.altlar(duzey, mevcut: secim?.ders);
    final konular = secim == null || !widget.konuSecilir
        ? const <CatalogStudyTag>[]
        : agac.altlar(secim.ders, mevcut: secim.konu);

    String ad(String anahtar) =>
        katalogAdi(agac.etiket(anahtar)?.labels, dil) ?? anahtar;
    String? not(String? anahtar) =>
        anahtar != null && !agac.secilebilir(anahtar)
        ? m.ders_konu_emekli
        : null;

    final cocuklar = <Widget>[
      _SeciciAlani(
        etiket: m.ders_konu_duzey,
        deger: duzey == null ? null : ad(duzey),
        not: not(duzey),
        onTap: !acik
            ? null
            : () => unawaited(
                _sec(
                  context,
                  baslik: m.ders_konu_duzey,
                  secenekler: duzeyler,
                  secili: duzey,
                  agac: agac,
                  dil: dil,
                  sonra: (k) {
                    if (k == duzey) return;
                    setState(() => _duzey = k);
                    if (widget.secim != null) widget.onDegisti?.call(null);
                  },
                ),
              ),
      ),
    ];
    if (duzey != null || secim != null) {
      cocuklar
        ..add(const SizedBox(height: TayfamSpacing.s16))
        ..add(
          _SeciciAlani(
            etiket: m.ders_konu_ders,
            deger: secim == null ? null : ad(secim.ders),
            not: not(secim?.ders),
            hata: widget.dersHatasi,
            onTap: !acik || dersler.isEmpty
                ? null
                : () => unawaited(
                    _sec(
                      context,
                      baslik: m.ders_konu_ders,
                      secenekler: dersler,
                      secili: secim?.ders,
                      agac: agac,
                      dil: dil,
                      sonra: (k) {
                        if (k == secim?.ders) return;
                        widget.onDegisti?.call(DersKonuSecimi(ders: k));
                      },
                    ),
                  ),
          ),
        );
    }
    if (secim != null && konular.isNotEmpty) {
      final konu = secim.konu;
      cocuklar
        ..add(const SizedBox(height: TayfamSpacing.s16))
        ..add(
          _SeciciAlani(
            etiket: m.ders_konu_konu,
            deger: konu == null ? null : ad(konu),
            not: not(konu),
            hata: widget.konuHatasi,
            onTap: !acik
                ? null
                : () => unawaited(
                    _sec(
                      context,
                      baslik: m.ders_konu_konu,
                      secenekler: konular,
                      secili: konu ?? _konusuz,
                      bosEtiket: m.ders_konu_konu_belirtme,
                      agac: agac,
                      dil: dil,
                      sonra: (k) {
                        final yeni = k == _konusuz ? null : k;
                        if (yeni == konu) return;
                        widget.onDegisti?.call(
                          DersKonuSecimi(ders: secim.ders, konu: yeni),
                        );
                      },
                    ),
                  ),
          ),
        );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cocuklar,
    );
  }

  /// Seçenek sayfasını açar; bir seçenek seçilirse [sonra] onun anahtarıyla
  /// çağrılır (sayfa kapatılırsa çağrılmaz).
  Future<void> _sec(
    BuildContext context, {
    required String baslik,
    required List<CatalogStudyTag> secenekler,
    required String? secili,
    required DersKonuAgaci agac,
    required String dil,
    required void Function(String anahtar) sonra,
    String? bosEtiket,
  }) async {
    final liste = [
      for (final e in secenekler)
        (
          anahtar: e.key,
          ad: katalogAdi(e.labels, dil) ?? e.key,
          emekli: !agac.secilebilir(e.key),
        ),
    ];
    final secilen = await altSayfaAc<String>(
      context,
      builder: (_) => _SecenekListesi(
        baslik: baslik,
        secenekler: liste,
        secili: secili,
        bosEtiket: bosEtiket,
      ),
    );
    if (secilen == null || !mounted) return;
    sonra(secilen);
  }
}

/// Seçicinin bir seviyesi: form alanı görünümünde, dokununca listesi
/// açılan düğme. Ekran okuyucu etiketi, seçili değeri ve varsa hatayı ya
/// da notu tek öğe olarak okur.
class _SeciciAlani extends StatelessWidget {
  const _SeciciAlani({
    required this.etiket,
    required this.deger,
    required this.onTap,
    this.not,
    this.hata,
  });

  final String etiket;
  final String? deger;
  final String? not;
  final String? hata;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final deger = this.deger;
    final acik = onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: acik,
      label: etiket,
      value: deger ?? '',
      hint: hata ?? not,
      onTap: onTap,
      excludeSemantics: true,
      child: OdakCercevesi(
        koseler: TayfamRadii.dugmeKoseleri,
        child: InkWell(
          onTap: onTap,
          borderRadius: TayfamRadii.dugmeKoseleri,
          child: InputDecorator(
            isEmpty: deger == null,
            decoration: InputDecoration(
              labelText: etiket,
              helperText: not,
              helperMaxLines: 3,
              errorText: hata,
              errorMaxLines: 3,
              enabled: acik,
              suffixIcon: const Icon(Icons.expand_more),
            ),
            child: deger == null ? null : Text(deger),
          ),
        ),
      ),
    );
  }
}

/// Liste boşken (içerik henüz yüklenmedi) gösterilen sakin not.
class _BosDurum extends StatelessWidget {
  const _BosDurum();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s12),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.menu_book_outlined,
              size: TayfamSizes.ikon,
              color: r.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              m.ders_konu_liste_bos,
              style: context.yazi.bodyMedium?.copyWith(color: r.metinIkincil),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Secenek = ({String anahtar, String ad, bool emekli});

/// Bir seviyenin seçenekleri (alttan açılan sayfa). [secili] işaretlidir;
/// [bosEtiket] verilirse listenin başında seçimi kaldıran seçenek olur.
class _SecenekListesi extends StatefulWidget {
  const _SecenekListesi({
    required this.baslik,
    required this.secenekler,
    required this.secili,
    this.bosEtiket,
  });

  final String baslik;
  final List<_Secenek> secenekler;
  final String? secili;
  final String? bosEtiket;

  @override
  State<_SecenekListesi> createState() => _SecenekListesiState();
}

class _SecenekListesiState extends State<_SecenekListesi> {
  final TextEditingController _arama = TextEditingController();

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final aramali = widget.secenekler.length > _aramaEsigi;
    final arama = turkceKucukHarf(_arama.text.trim());
    final gorunen = [
      for (final s in widget.secenekler)
        if (arama.isEmpty || turkceKucukHarf(s.ad).contains(arama)) s,
    ];
    final bosEtiket = arama.isEmpty ? widget.bosEtiket : null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _sayfaOrani,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.kenarMobil,
              0,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s12,
            ),
            child: Semantics(
              header: true,
              child: Text(widget.baslik, style: context.yazi.headlineSmall),
            ),
          ),
          if (aramali)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                0,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
              ),
              child: TextField(
                controller: _arama,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: m.ders_konu_ara,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
          Flexible(
            child: gorunen.isEmpty && bosEtiket == null
                ? Padding(
                    padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                    child: Text(
                      m.ders_konu_sonuc_yok,
                      style: context.yazi.bodyMedium?.copyWith(
                        color: context.renkler.metinIkincil,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: TayfamSpacing.s24),
                    children: [
                      if (bosEtiket != null)
                        _SecenekSatiri(
                          ad: bosEtiket,
                          secili: widget.secili == _konusuz,
                          onTap: () => Navigator.of(context).pop(_konusuz),
                        ),
                      for (final s in gorunen)
                        _SecenekSatiri(
                          ad: s.ad,
                          not: s.emekli ? m.ders_konu_emekli : null,
                          secili: s.anahtar == widget.secili,
                          onTap: () => Navigator.of(context).pop(s.anahtar),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SecenekSatiri extends StatelessWidget {
  const _SecenekSatiri({
    required this.ad,
    required this.secili,
    required this.onTap,
    this.not,
  });

  final String ad;
  final String? not;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final not = this.not;
    return Semantics(
      selected: secili,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.kenarMobil,
        ),
        title: Text(ad),
        subtitle: not == null ? null : Text(not),
        selected: secili,
        trailing: secili
            ? const ExcludeSemantics(child: Icon(Icons.check))
            : null,
        onTap: onTap,
      ),
    );
  }
}
