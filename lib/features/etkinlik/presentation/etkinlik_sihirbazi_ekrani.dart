import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/harita_secici_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/features/etkinlik/presentation/rota_secici_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik düzenleme (`/t/<tayfaId>/etkinlikler/<etkinlikId>/duzenle`):
/// etkinlik okununca sihirbaz o etkinlikle açılır. Sonraki yenilemeler
/// girilenleri silmesin diye ilk okunan etkinlik kullanılır.
class EtkinlikDuzenlemeEkrani extends ConsumerStatefulWidget {
  const EtkinlikDuzenlemeEkrani({
    super.key,
    required this.tayfaId,
    required this.etkinlikId,
  });

  final String tayfaId;
  final String etkinlikId;

  @override
  ConsumerState<EtkinlikDuzenlemeEkrani> createState() =>
      _EtkinlikDuzenlemeEkraniState();
}

class _EtkinlikDuzenlemeEkraniState
    extends ConsumerState<EtkinlikDuzenlemeEkrani> {
  Event? _ilk;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ilk = _ilk;
    if (ilk != null) {
      return EtkinlikSihirbaziEkrani(tayfaId: widget.tayfaId, duzenlenen: ilk);
    }
    final Widget govde;
    if (!uuidBicimindeMi(widget.etkinlikId)) {
      govde = HataSatiri(metin: m.hata_event_not_found);
    } else {
      final detay = ref.watch(
        etkinlikDetayProvider((
          tayfaId: widget.tayfaId,
          etkinlikId: widget.etkinlikId,
        )),
      );
      final etkinlik = detay.value;
      if (etkinlik != null) {
        _ilk = etkinlik;
        return EtkinlikSihirbaziEkrani(
          tayfaId: widget.tayfaId,
          duzenlenen: etkinlik,
        );
      }
      final hata = detay.error;
      govde = hata != null
          ? HataSatiri.hatadan(hata)
          : const Center(child: TayfamYukleniyor(boyut: TayfamSizes.yukleniyorTamEkran, gecikmeli: true,));
    }
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_duzenle_baslik)),
      body: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: govde,
      ),
    );
  }
}

/// Etkinlik oluşturma ve düzenleme sihirbazı (ADR-0015 §3): tür → başlık,
/// açıklama, başlangıç ve bitiş → yer (yüz yüzeyse harita seçici, il,
/// ilçe; çevrimiçiyse bağlantı) → türe özel alanlar, kontenjan ve tekrar.
///
/// Geri ve ileri gezinmede girilenler korunur; Android geri tuşu ilk adıma
/// kadar önceki adıma döner. Oluşturmada başarıyla etkinliğin detayı
/// açılır; düzenlemede detaya dönülür. Düzenlemede tür değişmez, tekrar
/// düzenlenmez ve seri etkinlikte yalnızca bu etkinliğin değişeceği
/// söylenir.
class EtkinlikSihirbaziEkrani extends ConsumerStatefulWidget {
  const EtkinlikSihirbaziEkrani({
    super.key,
    required this.tayfaId,
    this.duzenlenen,
  });

  final String tayfaId;

  /// Düzenlenen etkinlik; oluşturmada `null`.
  final Event? duzenlenen;

  @override
  ConsumerState<EtkinlikSihirbaziEkrani> createState() =>
      _EtkinlikSihirbaziEkraniState();
}

class _EtkinlikSihirbaziEkraniState
    extends ConsumerState<EtkinlikSihirbaziEkrani> {
  late final SihirbazAnahtari _anahtar = (
    tayfaId: widget.tayfaId,
    duzenlenen: widget.duzenlenen,
  );

  late final TextEditingController _baslik;
  late final TextEditingController _aciklama;
  late final TextEditingController _noktaAdi;
  late final TextEditingController _il;
  late final TextEditingController _ilce;
  late final TextEditingController _baglanti;
  late final TextEditingController _kontenjan;
  late final TextEditingController _kampYeri;
  late final TextEditingController _kampNotu;
  late final TextEditingController _mesafe;
  late final TextEditingController _yukselti;
  late final TextEditingController _tolerans;
  late final TextEditingController _oyun;
  late final TextEditingController _sahaAdi;
  late final TextEditingController _tekrarAralik;
  late final TextEditingController _tekrarSayi;

  @override
  void initState() {
    super.initState();
    final t = ref.read(etkinlikSihirbaziProvider(_anahtar));
    final tekrar = t.tekrar ?? const TekrarSecimi();
    _baslik = TextEditingController(text: t.baslik);
    _aciklama = TextEditingController(text: t.aciklama);
    _noktaAdi = TextEditingController(text: t.yer.noktaAdi);
    _il = TextEditingController(text: t.yer.il);
    _ilce = TextEditingController(text: t.yer.ilce);
    _baglanti = TextEditingController(text: t.yer.baglanti);
    _kontenjan = TextEditingController(text: t.kontenjan);
    _kampYeri = TextEditingController(text: t.ayrinti.kampYeri);
    _kampNotu = TextEditingController(text: t.ayrinti.kampNotu);
    _mesafe = TextEditingController(text: t.ayrinti.mesafe);
    _yukselti = TextEditingController(text: t.ayrinti.yukselti);
    _tolerans = TextEditingController(text: t.ayrinti.tolerans);
    _oyun = TextEditingController(text: t.ayrinti.oyun);
    _sahaAdi = TextEditingController(text: t.ayrinti.sahaAdi);
    _tekrarAralik = TextEditingController(text: '${tekrar.aralik}');
    _tekrarSayi = TextEditingController(text: '${tekrar.sayi}');
  }

  @override
  void dispose() {
    for (final d in [
      _baslik,
      _aciklama,
      _noktaAdi,
      _il,
      _ilce,
      _baglanti,
      _kontenjan,
      _kampYeri,
      _kampNotu,
      _mesafe,
      _yukselti,
      _tolerans,
      _oyun,
      _sahaAdi,
      _tekrarAralik,
      _tekrarSayi,
    ]) {
      d.dispose();
    }
    super.dispose();
  }

  EtkinlikSihirbaziNotifier get _n =>
      ref.read(etkinlikSihirbaziProvider(_anahtar).notifier);

  EtkinlikTaslagi get _t => ref.read(etkinlikSihirbaziProvider(_anahtar));

  void _ayrinti(TurAyrintisi Function(TurAyrintisi a) degisim) =>
      _n.ayrintiAyarla(degisim(_t.ayrinti));

  void _yer(YerBilgisi Function(YerBilgisi y) degisim) =>
      _n.yerAyarla(degisim(_t.yer));

  void _tekrar(TekrarSecimi Function(TekrarSecimi s) degisim) {
    final mevcut = _t.tekrar;
    if (mevcut != null) _n.tekrarAyarla(degisim(mevcut));
  }

  Future<void> _rotaSec() async {
    final t = _t;
    final rota = await rotaSeciciAc(
      context,
      baslangic: t.ayrinti.rota,
      merkez: t.yer.nokta,
    );
    if (rota == null || !mounted) return;
    _ayrinti((a) => a.kopya(rota: rota));
  }

  Future<void> _noktaSec() async {
    final sonuc = await haritaSeciciAc(context, baslangic: _t.yer.nokta);
    if (sonuc == null || !mounted) return;
    final oneri = sonuc.oneri;
    _n.noktaSec(sonuc.nokta, ad: oneri?.ad, il: oneri?.il, ilce: oneri?.ilce);
    final yer = _t.yer;
    _noktaAdi.text = yer.noktaAdi;
    _il.text = yer.il;
    _ilce.text = yer.ilce;
  }

  /// Tarih ve saat seçtirir; seçim cihazın saatidir, UTC'ye çevrilir.
  Future<DateTime?> _tarihSaatSec(DateTime? mevcut) async {
    final simdi = ref.read(etkinlikSaatiProvider)().toLocal();
    final baslangic = (mevcut ?? simdi.add(varsayilanSure)).toLocal();
    final ilkGun = DateTime(simdi.year, simdi.month, simdi.day);
    final secilen = DateTime(baslangic.year, baslangic.month, baslangic.day);
    final gun = await showDatePicker(
      context: context,
      initialDate: secilen.isBefore(ilkGun) ? ilkGun : secilen,
      firstDate: ilkGun,
      lastDate: DateTime(ilkGun.year + 5, ilkGun.month, ilkGun.day),
    );
    if (gun == null || !mounted) return null;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: baslangic.hour, minute: baslangic.minute),
    );
    if (saat == null) return null;
    return DateTime(
      gun.year,
      gun.month,
      gun.day,
      saat.hour,
      saat.minute,
    ).toUtc();
  }

  Future<void> _sonGunSec() async {
    final simdi = ref.read(etkinlikSaatiProvider)().toLocal();
    final ilkGun = DateTime(simdi.year, simdi.month, simdi.day);
    final mevcut = _t.tekrar?.sonGun;
    final gun = await showDatePicker(
      context: context,
      initialDate: mevcut == null
          ? ilkGun
          : DateTime(mevcut.year, mevcut.month, mevcut.day),
      firstDate: ilkGun,
      lastDate: DateTime(ilkGun.year + 5, ilkGun.month, ilkGun.day),
    );
    if (gun == null || !mounted) return;
    _tekrar(
      (s) => s.degistir(sonGun: DateTime.utc(gun.year, gun.month, gun.day)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final provider = etkinlikSihirbaziProvider(_anahtar);
    ref.listen(provider, (_, sonraki) {
      final id = sonraki.sonuc;
      if (id == null) return;
      if (_anahtar.duzenlenen != null) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Adresler.etkinlik(widget.tayfaId, id));
        }
      } else {
        context.go(Adresler.etkinlik(widget.tayfaId, id));
      }
    });
    final t = ref.watch(provider);
    final duzenleme = _anahtar.duzenlenen != null;
    final ilkAdim = duzenleme ? 1 : 0;
    final sonAdim = t.adim == etkinlikAdimSayisi - 1;
    final kilitli = t.gonderiliyor;
    final seri = _anahtar.duzenlenen?.seriesId != null;
    return PopScope(
      canPop: t.adim <= ilkAdim,
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (!geriDonuldu) _n.geri();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            duzenleme ? m.etkinlik_duzenle_baslik : m.etkinlik_olustur_baslik,
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      m.etkinlik_adim(
                        t.adim - ilkAdim + 1,
                        etkinlikAdimSayisi - ilkAdim,
                      ),
                      style: context.yazi.labelLarge?.copyWith(
                        color: context.renkler.metinIkincil,
                      ),
                    ),
                    if (seri) ...[
                      const SizedBox(height: TayfamSpacing.s8),
                      Text(
                        m.etkinlik_seri_duzenleme_notu,
                        style: context.yazi.bodyMedium?.copyWith(
                          color: context.renkler.metinGovde,
                        ),
                      ),
                    ],
                    const SizedBox(height: TayfamSpacing.s8),
                    switch (t.adim) {
                      0 => _turAdimi(context, t),
                      1 => _bilgiAdimi(context, t),
                      2 => _yerAdimi(context, t),
                      _ => _ayrintiAdimi(context, t),
                    },
                    if (t.hata case final hata?) ...[
                      const SizedBox(height: TayfamSpacing.s16),
                      HataSatiri.hatadan(hata),
                    ],
                    const SizedBox(height: TayfamSpacing.s24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s8,
                      children: [
                        if (t.adim > ilkAdim)
                          TextButton(
                            onPressed: kilitli ? null : () => _n.geri(),
                            style: TextButton.styleFrom(
                              minimumSize: const Size.square(
                                TayfamSizes.dokunmaMin,
                              ),
                            ),
                            child: Text(m.etkinlik_geri),
                          ),
                        BirincilEylem(
                          etiket: !sonAdim
                              ? m.etkinlik_ileri
                              : duzenleme
                              ? m.etkinlik_duzenle_gonder
                              : m.etkinlik_olustur_gonder,
                          onPressed: kilitli
                              ? null
                              : sonAdim
                              ? () => unawaited(_n.gonder())
                              : _n.ileri,
                        ),
                      ],
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

  // --- Adım 1: tür -----------------------------------------------------------

  Widget _turAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: m.etkinlik_tur_baslik),
        const SizedBox(height: TayfamSpacing.s16),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final tur in secilebilirEtkinlikTurleri)
              _TurSecimCipi(
                tur: tur,
                secili: t.tur == tur,
                onSecildi: t.gonderiliyor ? null : () => _n.turSec(tur),
              ),
          ],
        ),
        if (t.hatalar.contains(TaslakHatasi.tur)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: m.etkinlik_tur_hata),
        ],
      ],
    );
  }

  // --- Adım 2: başlık ve zaman ------------------------------------------------

  Widget _bilgiAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final baslangic = t.baslangic;
    final bitis = t.bitis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: m.etkinlik_bilgi_baslik),
        const SizedBox(height: TayfamSpacing.s16),
        TextField(
          controller: _baslik,
          enabled: !t.gonderiliyor,
          maxLength: etkinlikBaslikEnCok,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: _n.baslikAyarla,
          decoration: InputDecoration(
            labelText: m.etkinlik_baslik_etiketi,
            errorText: h.contains(TaslakHatasi.baslik)
                ? m.etkinlik_baslik_hata
                : null,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        TextField(
          controller: _aciklama,
          enabled: !t.gonderiliyor,
          maxLength: etkinlikAciklamaEnCok,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _n.aciklamaAyarla,
          decoration: InputDecoration(
            labelText: m.etkinlik_aciklama_etiketi,
            alignLabelWithHint: true,
            errorText: h.contains(TaslakHatasi.aciklama)
                ? m.etkinlik_aciklama_hata
                : null,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        Text(m.medya_kapak_etiketi, style: context.yazi.titleSmall),
        Text(
          m.etkinlik_kapak_aciklama,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        FotografAlani(
          amac: UploadPurpose.cover,
          tayfaId: widget.tayfaId,
          deger: t.kapak,
          etiket: m.medya_kapak_etiketi,
          etkin: !t.gonderiliyor,
          onDegisti: _n.kapakAyarla,
        ),
        const SizedBox(height: TayfamSpacing.s16),
        _ZamanAlani(
          etiket: m.etkinlik_baslangic,
          deger: baslangic == null ? null : etkinlikTarihSaat(m, baslangic),
          hata: h.contains(TaslakHatasi.baslangicYok)
              ? m.etkinlik_baslangic_yok
              : h.contains(TaslakHatasi.baslangicGecmis)
              ? m.etkinlik_baslangic_gecmis
              : null,
          onPressed: t.gonderiliyor
              ? null
              : () async {
                  final secilen = await _tarihSaatSec(baslangic);
                  if (secilen != null) _n.baslangicAyarla(secilen);
                },
        ),
        const SizedBox(height: TayfamSpacing.s12),
        _ZamanAlani(
          etiket: m.etkinlik_bitis,
          deger: bitis == null ? null : etkinlikTarihSaat(m, bitis),
          hata: h.contains(TaslakHatasi.bitis) ? m.etkinlik_bitis_hata : null,
          onPressed: t.gonderiliyor
              ? null
              : () async {
                  final secilen = await _tarihSaatSec(bitis ?? baslangic);
                  if (secilen != null) _n.bitisAyarla(secilen);
                },
        ),
      ],
    );
  }

  // --- Adım 3: yer ------------------------------------------------------------

  Widget _yerAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final yer = t.yer;
    final nokta = yer.nokta;
    final cevrimici = yer.mod == EventMode.online;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: m.etkinlik_yer_adim_baslik),
        const SizedBox(height: TayfamSpacing.s16),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            ChoiceChip(
              label: Text(m.etkinlik_mod_yuz_yuze),
              selected: !cevrimici,
              onSelected: t.gonderiliyor
                  ? null
                  : (_) => _yer((y) => y.kopya(mod: EventMode.inPerson)),
            ),
            ChoiceChip(
              label: Text(m.etkinlik_mod_cevrimici),
              selected: cevrimici,
              onSelected: t.gonderiliyor
                  ? null
                  : (_) => _yer((y) => y.kopya(mod: EventMode.online)),
            ),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s16),
        if (cevrimici)
          TextField(
            controller: _baglanti,
            enabled: !t.gonderiliyor,
            keyboardType: TextInputType.url,
            maxLength: etkinlikBaglantiEnCok,
            onChanged: (v) => _yer((y) => y.kopya(baglanti: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_baglanti_etiketi,
              errorText: h.contains(TaslakHatasi.baglanti)
                  ? m.etkinlik_baglanti_hata
                  : null,
            ),
          )
        else ...[
          if (nokta != null) ...[
            ClipRRect(
              borderRadius: TayfamRadii.onizlemeKoseleri,
              child: SizedBox(
                height: haritaOnizlemeYuksekligi,
                child: OsmHarita(
                  key: ValueKey(nokta),
                  merkez: nokta,
                  yakinlik: haritaOnizlemeYakinligi,
                  isaret: nokta,
                  etkilesimli: false,
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s8),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: t.gonderiliyor ? null : () => unawaited(_noktaSec()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.place_outlined),
              label: Text(
                nokta == null
                    ? m.etkinlik_nokta_sec
                    : m.etkinlik_nokta_degistir,
              ),
            ),
          ),
          if (h.contains(TaslakHatasi.nokta)) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.etkinlik_nokta_hata),
          ],
          const SizedBox(height: TayfamSpacing.s16),
          TextField(
            controller: _noktaAdi,
            enabled: !t.gonderiliyor,
            maxLength: etkinlikYerAdiEnCok,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => _yer((y) => y.kopya(noktaAdi: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_nokta_adi_etiketi,
              errorText: h.contains(TaslakHatasi.noktaAdi)
                  ? m.etkinlik_uzunluk_hata(etkinlikYerAdiEnCok)
                  : null,
            ),
          ),
          TextField(
            controller: _il,
            enabled: !t.gonderiliyor,
            maxLength: etkinlikIlEnCok,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => _yer((y) => y.kopya(il: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_il_etiketi,
              errorText: h.contains(TaslakHatasi.il)
                  ? m.etkinlik_il_hata
                  : null,
            ),
          ),
          TextField(
            controller: _ilce,
            enabled: !t.gonderiliyor,
            maxLength: etkinlikIlEnCok,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => _yer((y) => y.kopya(ilce: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_ilce_etiketi,
              errorText: h.contains(TaslakHatasi.ilce)
                  ? m.etkinlik_ilce_hata
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  // --- Adım 4: türe özel alanlar, kontenjan ve tekrar ------------------------

  Widget _ayrintiAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final duzenleme = _anahtar.duzenlenen != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdimBasligi(metin: m.etkinlik_ayrinti_adim_baslik),
        const SizedBox(height: TayfamSpacing.s16),
        ..._turAlanlari(context, t),
        TextField(
          controller: _kontenjan,
          enabled: !t.gonderiliyor,
          keyboardType: TextInputType.number,
          onChanged: _n.kontenjanAyarla,
          decoration: InputDecoration(
            labelText: m.etkinlik_kontenjan_etiketi,
            errorText: h.contains(TaslakHatasi.kontenjan)
                ? m.etkinlik_sayi_hata(etkinlikKontenjanEnCok)
                : null,
          ),
        ),
        if (!duzenleme) ...[
          const SizedBox(height: TayfamSpacing.s24),
          ..._tekrarAlanlari(context, t),
        ],
      ],
    );
  }

  List<Widget> _turAlanlari(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final a = t.ayrinti;
    final kapali = t.gonderiliyor;
    String? uzunluk(TaslakHatasi hata, int enCok) =>
        h.contains(hata) ? m.etkinlik_uzunluk_hata(enCok) : null;
    String? sayi(TaslakHatasi hata, int enCok) =>
        h.contains(hata) ? m.etkinlik_sayi_hata(enCok) : null;
    switch (t.tur) {
      case EventType.camp:
        return [
          TextField(
            controller: _kampYeri,
            enabled: !kapali,
            maxLength: etkinlikKampYeriEnCok,
            onChanged: (v) => _ayrinti((a) => a.kopya(kampYeri: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_kamp_yeri,
              errorText: uzunluk(TaslakHatasi.kampYeri, etkinlikKampYeriEnCok),
            ),
          ),
          _UcDurumSecimi(
            etiket: m.etkinlik_kamp_su,
            deger: a.su,
            onSecildi: kapali ? null : (v) => _ayrinti((a) => a.kopya(su: v)),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          _UcDurumSecimi(
            etiket: m.etkinlik_kamp_tuvalet,
            deger: a.tuvalet,
            onSecildi: kapali
                ? null
                : (v) => _ayrinti((a) => a.kopya(tuvalet: v)),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _kampNotu,
            enabled: !kapali,
            maxLength: etkinlikKampNotuEnCok,
            minLines: 2,
            maxLines: 5,
            onChanged: (v) => _ayrinti((a) => a.kopya(kampNotu: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_kamp_notu,
              alignLabelWithHint: true,
              errorText: uzunluk(TaslakHatasi.kampNotu, etkinlikKampNotuEnCok),
            ),
          ),
        ];
      case EventType.hike:
        final donus = a.donus;
        return [
          DropdownButtonFormField<int>(
            initialValue: a.zorluk,
            isExpanded: true,
            decoration: InputDecoration(labelText: m.etkinlik_yuruyus_zorluk),
            items: [
              for (var z = 0; z <= etkinlikZorlukEnCok; z++)
                DropdownMenuItem(
                  value: z,
                  child: Text(
                    z == 0
                        ? m.etkinlik_zorluk_yok
                        : m.etkinlik_zorluk_degeri(z),
                  ),
                ),
            ],
            onChanged: kapali
                ? null
                : (z) => _ayrinti((a) => a.kopya(zorluk: z ?? 0)),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _mesafe,
            enabled: !kapali,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => _ayrinti((a) => a.kopya(mesafe: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_mesafe_etiketi,
              errorText: sayi(TaslakHatasi.mesafe, etkinlikMesafeEnCok.toInt()),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _yukselti,
            enabled: !kapali,
            keyboardType: TextInputType.number,
            onChanged: (v) => _ayrinti((a) => a.kopya(yukselti: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_yukselti_etiketi,
              errorText: sayi(TaslakHatasi.yukselti, etkinlikYukseltiEnCok),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          _ZamanAlani(
            etiket: m.etkinlik_yuruyus_donus,
            deger: donus == null ? null : etkinlikTarihSaat(m, donus),
            hata: h.contains(TaslakHatasi.donus) ? m.etkinlik_donus_hata : null,
            onPressed: kapali
                ? null
                : () async {
                    final secilen = await _tarihSaatSec(
                      donus ?? t.bitis ?? t.baslangic,
                    );
                    if (secilen != null) {
                      _ayrinti((a) => a.kopya(donus: secilen));
                    }
                  },
            onTemizle: donus == null || kapali
                ? null
                : () => _ayrinti((a) => a.kopya(donus: null)),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _tolerans,
            enabled: !kapali,
            keyboardType: TextInputType.number,
            onChanged: (v) => _ayrinti((a) => a.kopya(tolerans: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_tolerans_etiketi,
              errorText: sayi(TaslakHatasi.tolerans, etkinlikToleransEnCok),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ];
      case EventType.fishing:
        return [
          Text(m.etkinlik_balik_gizlilik, style: context.yazi.titleSmall),
          RadioGroup<FishingDetailsSpotVisibility>(
            groupValue: a.balikGizliligi,
            onChanged: (v) {
              if (v != null && !kapali) {
                _ayrinti((a) => a.kopya(balikGizliligi: v));
              }
            },
            child: Column(
              children: [
                for (final g in const [
                  FishingDetailsSpotVisibility.tayfa,
                  FishingDetailsSpotVisibility.participants,
                ])
                  RadioListTile<FishingDetailsSpotVisibility>(
                    value: g,
                    contentPadding: EdgeInsets.zero,
                    title: Text(balikGizliligiAdi(m, g)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ];
      case EventType.gaming:
        return [
          TextField(
            controller: _oyun,
            enabled: !kapali,
            maxLength: etkinlikOyunEnCok,
            onChanged: (v) => _ayrinti((a) => a.kopya(oyun: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_oyun,
              errorText: h.contains(TaslakHatasi.oyun)
                  ? m.etkinlik_oyun_hata
                  : null,
            ),
          ),
          DropdownButtonFormField<GamingDetailsPlatform>(
            initialValue: a.platform,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: m.etkinlik_oyun_platform,
              errorText: h.contains(TaslakHatasi.platform)
                  ? m.etkinlik_secim_hata
                  : null,
            ),
            items: [
              for (final p in secilebilirPlatformlar)
                DropdownMenuItem(value: p, child: Text(platformAdi(m, p))),
            ],
            onChanged: kapali
                ? null
                : (p) {
                    if (p != null) _ayrinti((a) => a.kopya(platform: p));
                  },
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ];
      case EventType.sports:
        return [
          DropdownButtonFormField<SportsDetailsSport>(
            initialValue: a.spor,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: m.etkinlik_spor,
              errorText: h.contains(TaslakHatasi.spor)
                  ? m.etkinlik_secim_hata
                  : null,
            ),
            items: [
              for (final s in secilebilirSporlar)
                DropdownMenuItem(value: s, child: Text(sporAdi(m, s))),
            ],
            onChanged: kapali
                ? null
                : (s) {
                    if (s != null) _ayrinti((a) => a.kopya(spor: s));
                  },
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _sahaAdi,
            enabled: !kapali,
            maxLength: etkinlikSahaEnCok,
            onChanged: (v) => _ayrinti((a) => a.kopya(sahaAdi: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_spor_saha,
              errorText: uzunluk(TaslakHatasi.sahaAdi, etkinlikSahaEnCok),
            ),
          ),
        ];
      case EventType.convoy:
        return [
          Text(m.etkinlik_rota_baslik, style: context.yazi.titleSmall),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            a.rota.isEmpty
                ? m.etkinlik_rota_yok
                : m.etkinlik_konvoy_rota_noktalari(
                    etkinlikSayi(m, a.rota.length),
                  ),
            style: context.yazi.bodyMedium,
          ),
          if (h.contains(TaslakHatasi.rota))
            HataSatiri(metin: m.etkinlik_rota_hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: kapali ? null : () => unawaited(_rotaSec()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.route),
              label: Text(
                a.rota.isEmpty ? m.etkinlik_rota_ciz : m.etkinlik_rota_duzenle,
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ];
      case EventType.general || EventType.unknown || null:
        return const [];
    }
  }

  List<Widget> _tekrarAlanlari(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final tekrar = t.tekrar;
    final kapali = t.gonderiliyor;
    final sonGun = tekrar?.sonGun;
    return [
      Text(m.etkinlik_tekrar_baslik, style: context.yazi.titleSmall),
      const SizedBox(height: TayfamSpacing.s8),
      Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          ChoiceChip(
            label: Text(m.etkinlik_tekrar_yok),
            selected: tekrar == null,
            onSelected: kapali ? null : (_) => _n.tekrarAyarla(null),
          ),
          for (final (siklik, etiket) in [
            (TekrarSikligi.haftalik, m.etkinlik_tekrar_haftalik),
            (TekrarSikligi.aylik, m.etkinlik_tekrar_aylik),
          ])
            ChoiceChip(
              label: Text(etiket),
              selected: tekrar?.siklik == siklik,
              onSelected: kapali
                  ? null
                  : (_) => _n.tekrarAyarla(
                      (tekrar ??
                              TekrarSecimi(
                                aralik: int.tryParse(_tekrarAralik.text) ?? 1,
                                sayi: int.tryParse(_tekrarSayi.text) ?? 10,
                              ))
                          .degistir(siklik: siklik),
                    ),
            ),
        ],
      ),
      if (tekrar != null) ...[
        const SizedBox(height: TayfamSpacing.s12),
        TextField(
          controller: _tekrarAralik,
          enabled: !kapali,
          keyboardType: TextInputType.number,
          onChanged: (v) =>
              _tekrar((s) => s.degistir(aralik: int.tryParse(v.trim()) ?? 0)),
          decoration: InputDecoration(
            labelText: tekrar.siklik == TekrarSikligi.haftalik
                ? m.etkinlik_tekrar_aralik_haftalik
                : m.etkinlik_tekrar_aralik_aylik,
            errorText: h.contains(TaslakHatasi.tekrarAralik)
                ? m.etkinlik_aralik_hata(tekrarAralikEnAz, tekrarAralikEnCok)
                : null,
          ),
        ),
        if (tekrar.siklik == TekrarSikligi.aylik) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.etkinlik_tekrar_aylik_not,
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final (bitis, etiket) in [
              (TekrarBitisi.yok, m.etkinlik_tekrar_bitis_yok),
              (TekrarBitisi.sayi, m.etkinlik_tekrar_bitis_sayi),
              (TekrarBitisi.tarih, m.etkinlik_tekrar_bitis_tarih),
            ])
              ChoiceChip(
                label: Text(etiket),
                selected: tekrar.bitis == bitis,
                onSelected: kapali
                    ? null
                    : (_) => _tekrar((s) => s.degistir(bitis: bitis)),
              ),
          ],
        ),
        if (tekrar.bitis == TekrarBitisi.sayi) ...[
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _tekrarSayi,
            enabled: !kapali,
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                _tekrar((s) => s.degistir(sayi: int.tryParse(v.trim()) ?? 0)),
            decoration: InputDecoration(
              labelText: m.etkinlik_tekrar_sayi_etiketi,
              errorText: h.contains(TaslakHatasi.tekrarSayi)
                  ? m.etkinlik_aralik_hata(tekrarSayiEnAz, tekrarSayiEnCok)
                  : null,
            ),
          ),
        ],
        if (tekrar.bitis == TekrarBitisi.tarih) ...[
          const SizedBox(height: TayfamSpacing.s12),
          _ZamanAlani(
            etiket: m.etkinlik_tekrar_son_gun,
            deger: sonGun == null ? null : etkinlikGun(m, sonGun),
            hata: h.contains(TaslakHatasi.tekrarTarih)
                ? m.etkinlik_tekrar_tarih_hata
                : null,
            onPressed: kapali ? null : () => unawaited(_sonGunSec()),
          ),
        ],
      ],
    ];
  }
}

class _AdimBasligi extends StatelessWidget {
  const _AdimBasligi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(metin, style: context.yazi.headlineSmall),
    );
  }
}

/// Tür seçimi çipi: türün ikonu ve adı her zaman görünür; seçiliyken
/// türün kendi dolgusu (ADR-0004 Notlar, tür kaydı).
class _TurSecimCipi extends StatelessWidget {
  const _TurSecimCipi({
    required this.tur,
    required this.secili,
    required this.onSecildi,
  });

  final EventType tur;
  final bool secili;
  final VoidCallback? onSecildi;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final girdi = etkinlikTuruGirdisi(tur);
    final cift = context.turRenkleri.cift(girdi.renk);
    final yaziRengi = secili ? cift.ustu : r.metin;
    final onSecildi = this.onSecildi;
    return ChoiceChip(
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
      onSelected: onSecildi == null ? null : (_) => onSecildi(),
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

/// Tarih ve saat alanı: etiket, seçilen değer (yoksa "Seç") ve hata.
/// Dokununca seçici açılır; [onTemizle] verilirse değer silinebilir.
class _ZamanAlani extends StatelessWidget {
  const _ZamanAlani({
    required this.etiket,
    required this.deger,
    required this.hata,
    required this.onPressed,
    this.onTemizle,
  });

  final String etiket;
  final String? deger;
  final String? hata;
  final VoidCallback? onPressed;
  final VoidCallback? onTemizle;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = this.hata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          etiket,
          style: context.yazi.labelLarge?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s4),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.schedule),
              label: Text(deger ?? m.etkinlik_zaman_sec),
            ),
            if (onTemizle != null)
              TextButton(
                onPressed: onTemizle,
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.etkinlik_temizle),
              ),
          ],
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s4),
          HataSatiri(metin: hata),
        ],
      ],
    );
  }
}

/// Var / yok / bilinmiyor seçimi (kamp: su, tuvalet).
class _UcDurumSecimi extends StatelessWidget {
  const _UcDurumSecimi({
    required this.etiket,
    required this.deger,
    required this.onSecildi,
  });

  final String etiket;
  final bool? deger;
  final ValueChanged<bool?>? onSecildi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final onSecildi = this.onSecildi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiket, style: context.yazi.titleSmall),
        const SizedBox(height: TayfamSpacing.s4),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final secenek in const [true, false, null])
              ChoiceChip(
                label: Text(varYok(m, secenek)),
                selected: deger == secenek,
                onSelected: onSecildi == null
                    ? null
                    : (_) => onSecildi(secenek),
              ),
          ],
        ),
      ],
    );
  }
}
