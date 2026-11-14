import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/sosyal_medya.dart';
import 'package:tayfam/core/metin/diller.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/application/profil_tamamlama.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/profil/presentation/profil_sayfalari.dart';
import 'package:tayfam/features/profil/presentation/tanitim_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil tamamlama formu (issue #186; tasarım: Profil-Tamamla*).
///
/// [tekAdim] verilmezse girişten sonra açılan formdur (`/profil-tamamla`):
/// yalnızca cevaplanmamış alanların adımları, sonda her zaman "Kim
/// görsün"; üstte adım sayısı kadar bölümlü ilerleme çubuğu ve "Daha sonra
/// doldur" (`POST /v1/me/profile-prompt/snooze`, 7 gün). Verilirse Tanıtım
/// bilgilerin ekranından o adım tek başına açılır ve Kaydet'le kapanır.
///
/// Her adım kendi alanını İleri/Kaydet'te gönderir (`PATCH
/// /v1/me/account`); değişiklik yoksa istek gitmez. "Paylaşmak
/// istemiyorum" alanı `declined_profile_fields`'a ekler ve sonraki adıma
/// geçer. Kural dışı değer (`invalid-request`) alanın altında genel hata
/// metniyle gösterilir. Değerler yalnızca istek gövdesinde gider; log'a ve
/// diske yazılmaz (kesin kural 3, ADR-0006).
class ProfilTamamlamaEkrani extends ConsumerStatefulWidget {
  const ProfilTamamlamaEkrani({super.key, this.tekAdim});

  /// Tek başına açılan adım; `null` ise bütün form.
  final TamamlamaAdimi? tekAdim;

  @override
  ConsumerState<ProfilTamamlamaEkrani> createState() =>
      _ProfilTamamlamaEkraniState();
}

class _ProfilTamamlamaEkraniState extends ConsumerState<ProfilTamamlamaEkrani> {
  /// Form açılırken hesaplanan adımlar; kaydedilen alan listeden düşmez.
  List<TamamlamaAdimi>? _adimlar;
  int _sira = 0;
  bool _erteleniyor = false;

  bool get _tek => widget.tekAdim != null;

  void _kapat() {
    final gezgin = Navigator.of(context);
    if (gezgin.canPop()) gezgin.pop();
  }

  void _ileri() {
    if (!mounted) return;
    final adimlar = _adimlar ?? const <TamamlamaAdimi>[];
    if (_sira + 1 < adimlar.length) {
      setState(() => _sira++);
      return;
    }
    if (!_tek) {
      profilBildirimi(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context).profil_tamamla_kaydedildi,
      );
    }
    _kapat();
  }

  void _geri() {
    if (_sira > 0) {
      setState(() => _sira--);
    } else {
      _kapat();
    }
  }

  Future<void> _ertele() async {
    if (_erteleniyor) return;
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _erteleniyor = true);
    final hata = await ref.read(hesapAyarlariProvider.notifier).ertele();
    if (!mounted) return;
    setState(() => _erteleniyor = false);
    if (hata != null) {
      profilBildirimi(bildirim, profilHatasiMetni(m, hata));
      return;
    }
    _kapat();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(hesapAyarlariProvider);
    final hesap = durum.value;
    if (hesap != null && _adimlar == null) {
      final tekAdim = widget.tekAdim;
      _adimlar = tekAdim != null ? [tekAdim] : tamamlamaAdimlari(hesap);
    }
    final adimlar = _adimlar;
    final Widget govde;
    if (hesap == null || adimlar == null || adimlar.isEmpty) {
      govde = _Durum(
        hata: durum.error,
        onTekrar: () => ref.invalidate(hesapAyarlariProvider),
      );
    } else {
      final adim = adimlar[_sira];
      final sonAdim = _sira == adimlar.length - 1;
      govde = _AdimSayfasi(
        key: ValueKey(adim),
        adim: adim,
        hesap: hesap,
        ilerleme: _tek ? null : (sira: _sira + 1, toplam: adimlar.length),
        eylemEtiketi: _tek || sonAdim
            ? m.profil_kaydet
            : m.profil_tamamla_ileri,
        onBitti: _ileri,
      );
    }
    return PopScope(
      canPop: _tek || _sira == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _geri();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UstSatir(
                    geriGorunur: _tek || _sira > 0,
                    onGeri: _geri,
                    onDahaSonra: _tek || _erteleniyor
                        ? null
                        : () => unawaited(_ertele()),
                    dahaSonraGorunur: !_tek,
                  ),
                  Expanded(child: govde),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Üst satır: geri (formun ilk adımında gizli) ve "Daha sonra doldur".
class _UstSatir extends StatelessWidget {
  const _UstSatir({
    required this.geriGorunur,
    required this.onGeri,
    required this.onDahaSonra,
    required this.dahaSonraGorunur,
  });

  final bool geriGorunur;
  final VoidCallback onGeri;
  final VoidCallback? onDahaSonra;
  final bool dahaSonraGorunur;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.s4,
        TayfamSpacing.s4,
        TayfamSpacing.s8,
        0,
      ),
      child: Row(
        children: [
          Visibility(
            visible: geriGorunur,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: geriGorunur ? onGeri : null,
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
            ),
          ),
          const Spacer(),
          if (dahaSonraGorunur)
            Flexible(
              flex: 4,
              child: BaglantiEylemi(
                etiket: m.profil_tamamla_daha_sonra,
                onPressed: onDahaSonra,
              ),
            ),
        ],
      ),
    );
  }
}

/// Hesap okunurken gösterge; okunamadıysa hata ve "Tekrar dene".
class _Durum extends StatelessWidget {
  const _Durum({required this.hata, required this.onTekrar});

  final Object? hata;
  final VoidCallback onTekrar;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = this.hata;
    if (hata == null) {
      return Center(
        child: TayfamYukleniyor(
          boyut: TayfamSizes.yukleniyorTamEkran,
          etiket: m.profil_yukleniyor,
          gecikmeli: true,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [
        HataSatiri(metin: profilHatasiMetni(m, hata)),
        const SizedBox(height: TayfamSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onTekrar,
            child: Text(m.profil_tekrar_dene),
          ),
        ),
      ],
    );
  }
}

/// Bir adımın sayfası: adıma göre içerik.
class _AdimSayfasi extends StatelessWidget {
  const _AdimSayfasi({
    super.key,
    required this.adim,
    required this.hesap,
    required this.ilerleme,
    required this.eylemEtiketi,
    required this.onBitti,
  });

  final TamamlamaAdimi adim;
  final Account hesap;
  final ({int sira, int toplam})? ilerleme;
  final String eylemEtiketi;
  final VoidCallback onBitti;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final _Ortak ortak = (
      hesap: hesap,
      ilerleme: ilerleme,
      eylemEtiketi: eylemEtiketi,
      onBitti: onBitti,
    );
    return switch (adim) {
      TamamlamaAdimi.ilgiler => _IlgiAdimi(ortak: ortak),
      TamamlamaAdimi.hakkimda => _MetinAdimi(
        ortak: ortak,
        alan: ProfileField.about,
        baslik: m.profil_tamamla_hakkimda_baslik,
        aciklama: m.profil_tamamla_hakkimda_aciklama,
        etiket: m.profil_alan_hakkimda,
        not: m.profil_tamamla_hakkimda_not,
        enCok: hakkimdaEnCok,
        cokSatir: true,
      ),
      TamamlamaAdimi.meslek => _MetinAdimi(
        ortak: ortak,
        alan: ProfileField.occupation,
        baslik: m.profil_tamamla_meslek_baslik,
        aciklama: m.profil_tamamla_meslek_aciklama,
        etiket: m.profil_alan_meslek,
        not: m.profil_tamamla_satir_not,
        enCok: tekSatirEnCok,
        cokSatir: false,
      ),
      TamamlamaAdimi.takim => _MetinAdimi(
        ortak: ortak,
        alan: ProfileField.team,
        baslik: m.profil_tamamla_takim_baslik,
        aciklama: m.profil_tamamla_takim_aciklama,
        etiket: m.profil_alan_takim,
        not: m.profil_tamamla_satir_not,
        enCok: tekSatirEnCok,
        cokSatir: false,
      ),
      TamamlamaAdimi.diller => _DilAdimi(ortak: ortak),
      TamamlamaAdimi.sosyal => _SosyalAdimi(ortak: ortak),
      TamamlamaAdimi.gorunurluk => _GorunurlukAdimi(ortak: ortak),
    };
  }
}

/// Adımların ortak girdileri.
typedef _Ortak = ({
  Account hesap,
  ({int sira, int toplam})? ilerleme,
  String eylemEtiketi,
  VoidCallback onBitti,
});

/// Adımların kayıt durumu: gönderiliyor ve son hata.
mixin _Kaydedici<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool mesgul = false;
  Object? hata;

  /// [islem]'i çalıştırır; başarıda [onBitti] çağrılır, hata adımın
  /// altında gösterilir.
  Future<void> kaydet(
    Future<Object?> Function(HesapAyarlariNotifier hesap) islem,
    VoidCallback onBitti,
  ) async {
    if (mesgul) return;
    setState(() {
      mesgul = true;
      hata = null;
    });
    final sonuc = await islem(ref.read(hesapAyarlariProvider.notifier));
    if (!mounted) return;
    setState(() {
      mesgul = false;
      hata = sonuc;
    });
    if (sonuc == null) onBitti();
  }

  /// "Paylaşmak istemiyorum": [alan] reddedilir ve sonraki adıma geçilir.
  void reddet(ProfileField alan, VoidCallback onBitti) =>
      unawaited(kaydet((hesap) => hesap.reddet(alan), onBitti));
}

/// Adımların iskeleti: ilerleme, başlık, açıklama, içerik, hata, bilgi
/// notu, "Paylaşmak istemiyorum" ve altta sabit birincil eylem.
class _AdimIskeleti extends StatelessWidget {
  const _AdimIskeleti({
    required this.ilerleme,
    required this.baslik,
    required this.aciklama,
    required this.icerik,
    required this.not,
    required this.eylemEtiketi,
    required this.onEylem,
    required this.hata,
    this.onReddet,
  });

  final ({int sira, int toplam})? ilerleme;
  final String baslik;
  final String aciklama;
  final List<Widget> icerik;
  final String not;
  final String eylemEtiketi;
  final VoidCallback? onEylem;
  final Object? hata;
  final VoidCallback? onReddet;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ilerleme = this.ilerleme;
    final hata = this.hata;
    final onReddet = this.onReddet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s8,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s24,
            ),
            children: [
              if (ilerleme != null) ...[
                _Ilerleme(sira: ilerleme.sira, toplam: ilerleme.toplam),
                const SizedBox(height: TayfamSpacing.s16),
              ],
              Semantics(
                header: true,
                child: Text(baslik, style: context.yazi.headlineMedium),
              ),
              const SizedBox(height: TayfamSpacing.s8),
              Text(
                aciklama,
                style: context.yazi.bodyMedium?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s16),
              ...icerik,
              if (hata != null) ...[
                const SizedBox(height: TayfamSpacing.s8),
                HataSatiri(metin: profilHatasiMetni(m, hata)),
              ],
              const SizedBox(height: TayfamSpacing.s16),
              _BilgiNotu(metin: not),
              if (onReddet != null) ...[
                const SizedBox(height: TayfamSpacing.s8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BaglantiEylemi(
                    etiket: m.profil_tamamla_paylasmak_istemiyorum,
                    onPressed: onReddet,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s16,
          ),
          child: BirincilEylem(etiket: eylemEtiketi, onPressed: onEylem),
        ),
      ],
    );
  }
}

/// Adım sayısı kadar bölümlü ilerleme çubuğu (tasarım: Profil-Tamamla).
/// Çubuk süstür; ekran okuyucu "5 adımdan 1. adım" okur.
class _Ilerleme extends StatelessWidget {
  const _Ilerleme({required this.sira, required this.toplam});

  final int sira;
  final int toplam;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      label: AppLocalizations.of(context).profil_tamamla_adim(sira, toplam),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 1; i <= toplam; i++) ...[
              if (i > 1) const SizedBox(width: TayfamSpacing.s4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i <= sira ? r.marka : r.cizgi,
                    borderRadius: TayfamRadii.hapKoseleri,
                  ),
                  child: const SizedBox(height: TayfamSizes.ilerlemeParcasi),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Alanın altındaki tint-brand bilgi notu (tasarım: her alanın altında
/// bilgi notu).
class _BilgiNotu extends StatelessWidget {
  const _BilgiNotu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.onizlemeKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                size: TayfamSizes.ikonOrta,
                color: r.tintMarkaUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: Text(
                metin,
                style: context.yazi.bodySmall?.copyWith(color: r.metinGovde),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 · İlgi alanları: etkinlik türlerinden çoklu seçim (en çok 7; yedi tür
/// var).
class _IlgiAdimi extends ConsumerStatefulWidget {
  const _IlgiAdimi({required this.ortak});

  final _Ortak ortak;

  @override
  ConsumerState<_IlgiAdimi> createState() => _IlgiAdimiState();
}

class _IlgiAdimiState extends ConsumerState<_IlgiAdimi>
    with _Kaydedici<_IlgiAdimi> {
  late final Set<EventType> _secili = {...widget.ortak.hesap.interests};

  List<EventType> _sirali(Iterable<EventType> turler) => [
    for (final t in ilgiAlanlari)
      if (turler.contains(t)) t,
  ];

  void _ileri() {
    final yeni = _sirali(_secili);
    if (listEquals(yeni, _sirali(widget.ortak.hesap.interests))) {
      widget.ortak.onBitti();
      return;
    }
    unawaited(
      kaydet(
        (hesap) => hesap.guncelle(AccountUpdate(interests: yeni)),
        widget.ortak.onBitti,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return _AdimIskeleti(
      ilerleme: widget.ortak.ilerleme,
      baslik: m.profil_tamamla_ilgi_baslik,
      aciklama: m.profil_tamamla_ilgi_aciklama,
      icerik: [
        Semantics(
          label: m.profil_alan_ilgiler,
          container: true,
          child: Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final tur in ilgiAlanlari)
                IlgiCipi(
                  tur: tur,
                  secili: _secili.contains(tur),
                  onDegisti: mesgul
                      ? null
                      : () => setState(() {
                          if (!_secili.remove(tur)) _secili.add(tur);
                        }),
                ),
            ],
          ),
        ),
      ],
      not: m.profil_tamamla_ilgi_not,
      eylemEtiketi: widget.ortak.eylemEtiketi,
      onEylem: mesgul ? null : _ileri,
      hata: hata,
      onReddet: mesgul
          ? null
          : () => reddet(ProfileField.interests, widget.ortak.onBitti),
    );
  }
}

/// 2–4 · Hakkımda (çok satır, 160), meslek ve takım (tek satır, 60): aynı
/// iskelet. Boşaltıp kaydetmek alanı temizler (`""`).
class _MetinAdimi extends ConsumerStatefulWidget {
  const _MetinAdimi({
    required this.ortak,
    required this.alan,
    required this.baslik,
    required this.aciklama,
    required this.etiket,
    required this.not,
    required this.enCok,
    required this.cokSatir,
  });

  final _Ortak ortak;
  final ProfileField alan;
  final String baslik;
  final String aciklama;
  final String etiket;
  final String not;
  final int enCok;
  final bool cokSatir;

  @override
  ConsumerState<_MetinAdimi> createState() => _MetinAdimiState();
}

class _MetinAdimiState extends ConsumerState<_MetinAdimi>
    with _Kaydedici<_MetinAdimi> {
  late final TextEditingController _metin = TextEditingController(text: _eski);

  String get _eski {
    final hesap = widget.ortak.hesap;
    final deger = switch (widget.alan) {
      ProfileField.about => hesap.about,
      ProfileField.occupation => hesap.occupation,
      ProfileField.team => hesap.team,
      _ => null,
    };
    return deger ?? '';
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  void _ileri() {
    final yeni = _metin.text.trim();
    if (yeni == _eski.trim()) {
      widget.ortak.onBitti();
      return;
    }
    final degisiklik = switch (widget.alan) {
      ProfileField.about => AccountUpdate(about: yeni),
      ProfileField.occupation => AccountUpdate(occupation: yeni),
      _ => AccountUpdate(team: yeni),
    };
    unawaited(
      kaydet((hesap) => hesap.guncelle(degisiklik), widget.ortak.onBitti),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdimIskeleti(
      ilerleme: widget.ortak.ilerleme,
      baslik: widget.baslik,
      aciklama: widget.aciklama,
      icerik: [
        TextField(
          key: ValueKey('tamamla-${widget.alan.name}'),
          controller: _metin,
          enabled: !mesgul,
          maxLength: widget.enCok,
          minLines: widget.cokSatir ? 3 : 1,
          maxLines: widget.cokSatir ? 5 : 1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: widget.cokSatir
              ? TextInputAction.newline
              : TextInputAction.done,
          onChanged: (_) {
            if (hata != null) setState(() => hata = null);
          },
          decoration: InputDecoration(labelText: widget.etiket),
        ),
      ],
      not: widget.not,
      eylemEtiketi: widget.ortak.eylemEtiketi,
      onEylem: mesgul ? null : _ileri,
      hata: hata,
      onReddet: mesgul ? null : () => reddet(widget.alan, widget.ortak.onBitti),
    );
  }
}

/// 5 · Diller: seçilenler çip, sayaç, arama ve onay kutulu liste (ISO
/// 639-1, en çok 5; adlar istemcideki Türkçe listeden).
class _DilAdimi extends ConsumerStatefulWidget {
  const _DilAdimi({required this.ortak});

  final _Ortak ortak;

  @override
  ConsumerState<_DilAdimi> createState() => _DilAdimiState();
}

class _DilAdimiState extends ConsumerState<_DilAdimi>
    with _Kaydedici<_DilAdimi> {
  late final List<String> _secili = [...widget.ortak.hesap.languages];
  final TextEditingController _arama = TextEditingController();

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  void _degistir(String kod) => setState(() {
    if (!_secili.remove(kod) && _secili.length < dilEnCok) _secili.add(kod);
  });

  void _ileri() {
    final eski = widget.ortak.hesap.languages;
    if (setEquals(_secili.toSet(), eski.toSet())) {
      widget.ortak.onBitti();
      return;
    }
    final yeni = List<String>.of(_secili);
    unawaited(
      kaydet(
        (hesap) => hesap.guncelle(AccountUpdate(languages: yeni)),
        widget.ortak.onBitti,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final aranan = turkceKucukHarf(_arama.text.trim());
    final liste = [
      for (final kod in dilKodlari)
        if (aranan.isEmpty ||
            turkceKucukHarf(dilAdi(m, kod) ?? kod).contains(aranan))
          kod,
    ];
    final dolu = _secili.length >= dilEnCok;
    return _AdimIskeleti(
      ilerleme: widget.ortak.ilerleme,
      baslik: m.profil_tamamla_dil_baslik,
      aciklama: m.profil_tamamla_dil_aciklama,
      icerik: [
        if (_secili.isNotEmpty) ...[
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final kod in _secili)
                InputChip(
                  label: Text(dilAdi(m, kod) ?? kod),
                  onDeleted: mesgul ? null : () => _degistir(kod),
                  deleteButtonTooltipMessage: m.profil_tamamla_dil_kaldir(
                    dilAdi(m, kod) ?? kod,
                  ),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
        ],
        Text(
          m.profil_tamamla_dil_sayac(_secili.length, dilEnCok),
          style: context.yazi.bodySmall?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        TextField(
          key: const ValueKey('tamamla-dil-arama'),
          controller: _arama,
          enabled: !mesgul,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: m.profil_tamamla_dil_ara,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (liste.isEmpty)
          Text(
            m.profil_tamamla_dil_bos,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        for (final kod in liste)
          CheckboxListTile(
            value: _secili.contains(kod),
            onChanged: mesgul || (dolu && !_secili.contains(kod))
                ? null
                : (_) => _degistir(kod),
            title: Text(dilAdi(m, kod) ?? kod),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
          ),
      ],
      not: m.profil_tamamla_dil_not,
      eylemEtiketi: widget.ortak.eylemEtiketi,
      onEylem: mesgul ? null : _ileri,
      hata: hata,
      onReddet: mesgul
          ? null
          : () => reddet(ProfileField.languages, widget.ortak.onBitti),
    );
  }
}

/// 6 · Sosyal medya: Instagram, X, TikTok, YouTube; `@` sabit önek,
/// yalnızca kullanıcı adı. Kurallar istemcide de denetlenir; kural dışı
/// değer satırın altında hata gösterir ve istek gitmez.
class _SosyalAdimi extends ConsumerStatefulWidget {
  const _SosyalAdimi({required this.ortak});

  final _Ortak ortak;

  @override
  ConsumerState<_SosyalAdimi> createState() => _SosyalAdimiState();
}

class _SosyalAdimiState extends ConsumerState<_SosyalAdimi>
    with _Kaydedici<_SosyalAdimi> {
  late final Map<SocialAccountPlatform, TextEditingController> _alanlar = {
    for (final p in sosyalPlatformlar)
      p: TextEditingController(text: _eskiAd(p) ?? ''),
  };
  final Set<SocialAccountPlatform> _gecersiz = {};

  String? _eskiAd(SocialAccountPlatform p) {
    for (final h in widget.ortak.hesap.socialAccounts) {
      if (h.platform == p) return h.username;
    }
    return null;
  }

  @override
  void dispose() {
    for (final alan in _alanlar.values) {
      alan.dispose();
    }
    super.dispose();
  }

  void _ileri() {
    final gecersiz = <SocialAccountPlatform>{};
    final yeni = <SocialAccount>[];
    for (final p in sosyalPlatformlar) {
      final ad = sosyalKullaniciAdi(_alanlar[p]!.text);
      if (ad.isEmpty) continue;
      if (!sosyalKullaniciAdiGecerli(p, ad)) {
        gecersiz.add(p);
      } else {
        yeni.add(SocialAccount(platform: p, username: ad));
      }
    }
    if (gecersiz.isNotEmpty) {
      setState(() {
        _gecersiz
          ..clear()
          ..addAll(gecersiz);
        hata = null;
      });
      return;
    }
    setState(_gecersiz.clear);
    final eski = {
      for (final h in widget.ortak.hesap.socialAccounts)
        if (h.platform != SocialAccountPlatform.unknown) h.platform: h.username,
    };
    final yeniHarita = {for (final h in yeni) h.platform: h.username};
    if (mapEquals(eski, yeniHarita)) {
      widget.ortak.onBitti();
      return;
    }
    unawaited(
      kaydet(
        (hesap) => hesap.guncelle(AccountUpdate(socialAccounts: yeni)),
        widget.ortak.onBitti,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return _AdimIskeleti(
      ilerleme: widget.ortak.ilerleme,
      baslik: m.profil_tamamla_sosyal_baslik,
      aciklama: m.profil_tamamla_sosyal_aciklama,
      icerik: [
        for (final (sira, p) in sosyalPlatformlar.indexed) ...[
          if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
          TextField(
            key: ValueKey('tamamla-sosyal-${p.name}'),
            controller: _alanlar[p],
            enabled: !mesgul,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_gecersiz.contains(p) || hata != null) {
                setState(() {
                  _gecersiz.remove(p);
                  hata = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: sosyalPlatformAdi(m, p),
              prefixText: '@',
              hintText: m.profil_tamamla_sosyal_ipucu,
              errorText: _gecersiz.contains(p)
                  ? m.profil_tamamla_sosyal_hata
                  : null,
              errorMaxLines: 3,
            ),
          ),
        ],
      ],
      not: m.profil_tamamla_sosyal_not,
      eylemEtiketi: widget.ortak.eylemEtiketi,
      onEylem: mesgul ? null : _ileri,
      hata: hata,
      onReddet: mesgul
          ? null
          : () => reddet(ProfileField.socialAccounts, widget.ortak.onBitti),
    );
  }
}

/// Son adım · Kim görsün (`about_visibility`; varsayılan
/// `friends_and_mutual`). "Paylaşmak istemiyorum" yoktur.
class _GorunurlukAdimi extends ConsumerStatefulWidget {
  const _GorunurlukAdimi({required this.ortak});

  final _Ortak ortak;

  @override
  ConsumerState<_GorunurlukAdimi> createState() => _GorunurlukAdimiState();
}

class _GorunurlukAdimiState extends ConsumerState<_GorunurlukAdimi>
    with _Kaydedici<_GorunurlukAdimi> {
  late AboutVisibility _secim = switch (widget.ortak.hesap.aboutVisibility) {
    AboutVisibility.unknown => AboutVisibility.friendsAndMutual,
    final g => g,
  };

  void _kaydet() {
    if (_secim == widget.ortak.hesap.aboutVisibility) {
      widget.ortak.onBitti();
      return;
    }
    final secim = _secim;
    unawaited(
      kaydet(
        (hesap) => hesap.guncelle(AccountUpdate(aboutVisibility: secim)),
        widget.ortak.onBitti,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return _AdimIskeleti(
      ilerleme: widget.ortak.ilerleme,
      baslik: m.profil_tamamla_gorunurluk_baslik,
      aciklama: m.profil_tamamla_gorunurluk_aciklama,
      icerik: [
        RadioGroup<AboutVisibility>(
          groupValue: _secim,
          onChanged: (secim) {
            if (secim != null && !mesgul) setState(() => _secim = secim);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, g) in tanitimGorunurlukSecenekleri.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                SecimKarti(
                  secili: g == _secim,
                  child: RadioListTile<AboutVisibility>(
                    value: g,
                    title: Text(tanitimGorunurlukAdi(m, g)),
                    subtitle: Text(
                      tanitimGorunurlukAciklamasi(m, g),
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      not: m.profil_tamamla_gorunurluk_not,
      eylemEtiketi: widget.ortak.eylemEtiketi,
      onEylem: mesgul ? null : _kaydet,
      hata: hata,
    );
  }
}
