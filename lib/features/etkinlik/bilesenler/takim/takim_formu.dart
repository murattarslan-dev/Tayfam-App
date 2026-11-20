import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Takımsız" seçeneğinin değeri.
const int _takimsiz = -1;

/// Takımın görünen adı: adı varsa adı, yoksa "Takım n" ([sira] 1'den).
/// Takım hiçbir yerde yalnızca renkle anlatılmaz.
String takimEtiketi(AppLocalizations m, int sira, String? ad) {
  final temiz = ad?.trim() ?? '';
  return temiz.isEmpty ? m.bilesen_teams_takim_no(sira) : temiz;
}

/// Takımları elle kurma formu (alttan sayfa): takımların adları (isteğe
/// bağlı), takım ekleme/çıkarma ve her kişi için takım seçimi. Kişiler
/// etkinliğe "Geliyorum" diyenler ve takımlarda zaten olanlardır. Sunucu
/// hatası (ör. `teams-not-participant`) formda gösterilir, form açık kalır.
class TakimElleFormu extends ConsumerStatefulWidget {
  const TakimElleFormu({
    super.key,
    required this.takimlar,
    required this.katilimcilar,
    required this.gonder,
  });

  final EventTeams takimlar;
  final KatilimcilarAnahtari katilimcilar;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventTeamsRequest istek) gonder;

  @override
  ConsumerState<TakimElleFormu> createState() => _TakimElleFormuState();
}

class _TakimElleFormuState extends ConsumerState<TakimElleFormu> {
  final List<TextEditingController> _adlar = [];

  /// Kişi → takımın sırası (0'dan).
  final Map<String, int> _atama = {};

  /// Takımlarda olan kişiler, takım sırasıyla (katılımcı listesinde
  /// görünmeseler de formda kalırlar).
  final List<String> _mevcutUyeler = [];

  Set<int> _dolanlar = const {};
  bool _mesgul = false;
  Object? _hata;

  @override
  void initState() {
    super.initState();
    for (final (sira, takim) in takimTaslagi(widget.takimlar).indexed) {
      _adlar.add(TextEditingController(text: takim.ad));
      for (final kisi in takim.uyeler) {
        if (_atama.containsKey(kisi)) continue;
        _atama[kisi] = sira;
        _mevcutUyeler.add(kisi);
      }
    }
  }

  @override
  void dispose() {
    for (final ad in _adlar) {
      ad.dispose();
    }
    super.dispose();
  }

  void _degisti() => setState(() {
    _dolanlar = const {};
    _hata = null;
  });

  void _takimEkle() {
    _adlar.add(TextEditingController());
    _degisti();
  }

  /// [sira]'daki takımı çıkarır; üyeleri takımsız kalır, sonraki takımlar
  /// bir öne kayar.
  void _takimCikar(int sira) {
    _adlar.removeAt(sira).dispose();
    final yeni = <String, int>{};
    for (final MapEntry(key: kisi, value: takim) in _atama.entries) {
      if (takim == sira) continue;
      yeni[kisi] = takim > sira ? takim - 1 : takim;
    }
    _atama
      ..clear()
      ..addAll(yeni);
    _degisti();
  }

  void _ata(String kisi, int takim) {
    if (takim == _takimsiz) {
      _atama.remove(kisi);
    } else {
      _atama[kisi] = takim;
    }
    _degisti();
  }

  Future<void> _kaydet(List<String> kisiSirasi) async {
    if (_mesgul) return;
    final sonuc = takimIstegi(
      adlar: [for (final ad in _adlar) ad.text],
      atama: _atama,
      kisiSirasi: kisiSirasi,
      kisiSiniri: takimKisiSiniri(widget.takimlar),
    );
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() => _dolanlar = sonuc.dolanlar);
      return;
    }
    setState(() {
      _dolanlar = const {};
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

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(widget.katilimcilar));
    final gelenler = durum.value?.ogeler.map((k) => k.userId) ?? const <String>[];
    final kisiler = <String>[
      ...{...gelenler, ..._mevcutUyeler},
    ];
    final sinir = takimSiniri(widget.takimlar);
    final kisiSiniri = takimKisiSiniri(widget.takimlar);
    final hata = _hata;
    final takimlar = [
      for (final (sira, ad) in _adlar.indexed)
        (sira, takimEtiketi(m, sira + 1, ad.text)),
    ];
    return AracFormSayfasi(
      baslik: m.bilesen_teams_elle_baslik,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet(kisiler)),
      alanlar: [
        Text(m.bilesen_teams_takimlar, style: context.yazi.titleSmall),
        if (kisiSiniri != null)
          AracBilgisi(metin: m.bilesen_teams_kisi_siniri(kisiSiniri)),
        const SizedBox(height: TayfamSpacing.s8),
        if (_adlar.isEmpty) AracBilgisi(metin: m.bilesen_teams_hepsi_kalkar),
        for (final (sira, ad) in _adlar.indexed) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('takim-adi-$sira'),
                  controller: ad,
                  enabled: !_mesgul,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(takimAdiEnCok),
                  ],
                  onChanged: (_) => _degisti(),
                  decoration: InputDecoration(
                    labelText: m.bilesen_teams_ad_alani(sira + 1),
                    hintText: m.bilesen_teams_takim_no(sira + 1),
                  ),
                ),
              ),
              AracIkonDugmesi(
                ipucu: m.bilesen_teams_takim_cikar(sira + 1),
                ikon: Icons.remove_circle_outline,
                onPressed: _mesgul ? null : () => _takimCikar(sira),
              ),
            ],
          ),
          if (_dolanlar.contains(sira) && kisiSiniri != null)
            HataSatiri(metin: m.bilesen_teams_takim_dolu(kisiSiniri)),
          const SizedBox(height: TayfamSpacing.s8),
        ],
        if (_adlar.length < sinir)
          AracDugmesi(
            etiket: m.bilesen_teams_takim_ekle,
            ikon: Icons.add,
            onPressed: _mesgul ? null : _takimEkle,
          ),
        const SizedBox(height: TayfamSpacing.s16),
        Text(m.bilesen_teams_kisiler, style: context.yazi.titleSmall),
        const SizedBox(height: TayfamSpacing.s8),
        _KisiListesi(
          anahtar: widget.katilimcilar,
          kisiler: kisiler,
          satir: (kisi) => _KisiSecimi(
            key: ValueKey('takim-kisi-$kisi'),
            kisi: kisi,
            etiket: m.bilesen_teams_kisinin_takimi,
            secili: _atama[kisi] ?? _takimsiz,
            secenekler: [(_takimsiz, m.bilesen_teams_takimsiz), ...takimlar],
            onSecildi: _mesgul ? null : (takim) => _ata(kisi, takim),
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// Dengeli kurma formu (alttan sayfa): her katılımcı için 1–5 seviye
/// (varsayılan 3). Seviyeler yalnızca bu formun belleğindedir; kurulumda
/// sunucuya gider, hiçbir yerde saklanmaz ve önbelleğe alınmaz (sunucu da
/// saklamaz).
class TakimSeviyeFormu extends ConsumerStatefulWidget {
  const TakimSeviyeFormu({
    super.key,
    required this.katilimcilar,
    required this.yenidenKurulum,
    required this.gonder,
  });

  final KatilimcilarAnahtari katilimcilar;

  /// Takımlar zaten kurulu: kurulum onların yerini alır (formda yazılır).
  final bool yenidenKurulum;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventTeamsGenerateRequest istek) gonder;

  @override
  ConsumerState<TakimSeviyeFormu> createState() => _TakimSeviyeFormuState();
}

class _TakimSeviyeFormuState extends ConsumerState<TakimSeviyeFormu> {
  final Map<String, int> _seviyeler = {};
  bool _mesgul = false;
  Object? _hata;

  Future<void> _kur() async {
    if (_mesgul) return;
    setState(() {
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(takimSeviyeIstegi(_seviyeler));
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

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(widget.katilimcilar));
    final kisiler = [...?durum.value?.ogeler.map((k) => k.userId)];
    final hata = _hata;
    return AracFormSayfasi(
      baslik: m.bilesen_teams_seviye_baslik,
      onayEtiketi: m.bilesen_teams_kur,
      onOnay: _mesgul ? null : () => unawaited(_kur()),
      alanlar: [
        AracBilgisi(metin: m.bilesen_teams_seviye_aciklama),
        if (widget.yenidenKurulum) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_teams_yeniden_aciklama),
        ],
        const SizedBox(height: TayfamSpacing.s16),
        _KisiListesi(
          anahtar: widget.katilimcilar,
          kisiler: kisiler,
          satir: (kisi) => _KisiSecimi(
            key: ValueKey('takim-seviye-$kisi'),
            kisi: kisi,
            etiket: m.bilesen_teams_seviye_alani,
            secili: _seviyeler[kisi] ?? takimVarsayilanSeviye,
            secenekler: [
              for (var s = takimSeviyeEnAz; s <= takimSeviyeEnCok; s++)
                (s, m.bilesen_teams_seviye(s)),
            ],
            onSecildi: _mesgul
                ? null
                : (seviye) => setState(() {
                    _seviyeler[kisi] = seviye;
                    _hata = null;
                  }),
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// Formlardaki kişi listesi: etkinliğe "Geliyorum" diyenler (ilk sayfa ve
/// "Daha fazla") ve [kisiler]'deki ekler. Okunurken yükleniyor, okunamazsa
/// hata gösterilir.
class _KisiListesi extends ConsumerWidget {
  const _KisiListesi({
    required this.anahtar,
    required this.kisiler,
    required this.satir,
  });

  final KatilimcilarAnahtari anahtar;
  final List<String> kisiler;
  final Widget Function(String kisi) satir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    final liste = durum.value;
    if (liste == null) {
      if (durum.hasError) return HataSatiri.hatadan(durum.error!);
      return const Center(child: TayfamYukleniyor(gecikmeli: true));
    }
    if (kisiler.isEmpty) {
      return AracBilgisi(metin: m.bilesen_teams_gelen_yok);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kisi in kisiler) satir(kisi),
        if (liste.dahaVar)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: liste.dahaYukleniyor
                  ? null
                  : () => unawaited(notifier.dahaFazla()),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.etkinlik_daha_fazla),
            ),
          ),
      ],
    );
  }
}

/// Bir kişinin adı ve altında tek seçim (takımı ya da seviyesi). Ad ve
/// seçim tek öğe olarak okunur.
class _KisiSecimi extends StatelessWidget {
  const _KisiSecimi({
    super.key,
    required this.kisi,
    required this.etiket,
    required this.secili,
    required this.secenekler,
    required this.onSecildi,
  });

  final String kisi;

  /// Seçimin ne olduğu ("Takımı", "Seviyesi"); ekran okuyucu için.
  final String etiket;

  final int secili;
  final List<(int, String)> secenekler;

  /// `null`: seçim geçici olarak kapalı (gönderim sürüyor).
  final ValueChanged<int>? onSecildi;

  @override
  Widget build(BuildContext context) {
    final onSecildi = this.onSecildi;
    return Padding(
      padding: const EdgeInsets.only(bottom: TayfamSpacing.s8),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KullaniciAdiMetni(kullaniciId: kisi, style: context.yazi.bodyLarge),
            Semantics(
              label: etiket,
              child: DropdownButton<int>(
                isExpanded: true,
                value: secili,
                onChanged: onSecildi == null
                    ? null
                    : (deger) {
                        if (deger != null) onSecildi(deger);
                      },
                items: [
                  for (final (deger, ad) in secenekler)
                    DropdownMenuItem<int>(
                      value: deger,
                      child: Text(ad, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
