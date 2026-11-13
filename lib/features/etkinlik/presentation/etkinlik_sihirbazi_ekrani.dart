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
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/features/etkinlik/presentation/tekrar_ekrani.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sihirbazdaki rota önizlemesinin yüksekliği.
const double sihirbazRotaYuksekligi = 120;

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
          : const Center(
              child: TayfamYukleniyor(
                boyut: TayfamSizes.yukleniyorTamEkran,
                gecikmeli: true,
              ),
            );
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

/// Etkinlik oluşturma ve düzenleme sihirbazı (ADR-0015 §3; 2026-11-13
/// yeniden tasarım, ADR-0015 Notlar): 1 tür, 2 başlık ve zaman, 3 yer
/// (yüz yüzede harita seçici, il, ilçe; çevrimiçide bağlantı), 4 türe özel
/// alanlar, kontenjan ve tekrar, 5 önizleme ("Her şey doğru mu?").
///
/// Üstte kapat (X; girilen bir şey varsa "Vazgeçilsin mi?"), başlık,
/// "Adım n / N" ve ilerleme çubuğu; altta sabit Geri ve İleri (son adımda
/// "Etkinliği aç" ya da "Kaydet"). Girilenler adımlar arasında korunur;
/// Android geri tuşu önceki adıma döner. Önizlemedeki "Değiştir" ilgili
/// adıma götürür, oradan "İleri" önizlemeye döner. Sunucu hatası
/// önizlemede gösterilir.
///
/// Düzenlemede tür değişmez (tür adımı yoktur), tekrar düzenlenmez ve seri
/// etkinlikte yalnızca bu etkinliğin değişeceği söylenir. Oluşturmada
/// başarıyla etkinliğin detayı açılır; düzenlemede detaya dönülür.
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

  /// "Sınırsız" kapatılınca kontenjanın başladığı değer.
  static const int _varsayilanKontenjan = 10;

  @override
  void initState() {
    super.initState();
    final t = ref.read(etkinlikSihirbaziProvider(_anahtar));
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
    ]) {
      d.dispose();
    }
    super.dispose();
  }

  EtkinlikSihirbaziNotifier get _n =>
      ref.read(etkinlikSihirbaziProvider(_anahtar).notifier);

  EtkinlikTaslagi get _t => ref.read(etkinlikSihirbaziProvider(_anahtar));

  bool get _duzenleme => _anahtar.duzenlenen != null;

  void _ayrinti(TurAyrintisi Function(TurAyrintisi a) degisim) =>
      _n.ayrintiAyarla(degisim(_t.ayrinti));

  void _yer(YerBilgisi Function(YerBilgisi y) degisim) =>
      _n.yerAyarla(degisim(_t.yer));

  /// Kapat (X) ya da ilk adımda geri: girilen bir şey varsa onay sorulur.
  Future<void> _kapat() async {
    if (_n.girdiVar && _t.sonuc == null) {
      final vazgec = await _vazgecOnayi(context);
      if (!vazgec || !mounted) return;
    }
    if (!mounted) return;
    // Navigator.pop, PopScope'u (girilen varken kapanmayı engeller) atlar;
    // onay yukarıda alındı.
    final gezinme = Navigator.of(context);
    if (gezinme.canPop()) {
      gezinme.pop();
      return;
    }
    final eski = _anahtar.duzenlenen;
    context.go(
      eski == null
          ? Adresler.etkinlikler(widget.tayfaId)
          : Adresler.etkinlik(widget.tayfaId, eski.id),
    );
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

  Future<void> _tekrarAc() async {
    final t = _t;
    final simdi = ref.read(etkinlikSaatiProvider)();
    final sonuc = await tekrarEkraniniAc(
      context,
      secim: t.tekrar,
      baslangic: t.baslangic ?? simdi,
    );
    if (sonuc == null || !mounted) return;
    _n.tekrarAyarla(sonuc.secim);
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

  void _kontenjanSinirsiz(bool sinirsiz) {
    final metin = sinirsiz ? '' : '$_varsayilanKontenjan';
    _kontenjan.text = metin;
    _n.kontenjanAyarla(metin);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final provider = etkinlikSihirbaziProvider(_anahtar);
    ref.listen(provider, (_, sonraki) {
      final id = sonraki.sonuc;
      if (id == null) return;
      if (_duzenleme && context.canPop()) {
        context.pop();
      } else {
        context.go(Adresler.etkinlik(widget.tayfaId, id));
      }
    });
    final t = ref.watch(provider);
    final ilkAdim = _n.ilkAdim;
    final sonAdim = t.adim == SihirbazAdimi.onizleme;
    final kilitli = t.gonderiliyor;
    return PopScope(
      canPop: t.sonuc != null || (t.adim <= ilkAdim && !_n.girdiVar),
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (geriDonuldu || kilitli) return;
        if (!_n.geri()) unawaited(_kapat());
      },
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SihirbazUstCubugu(
              baslik: _duzenleme
                  ? m.etkinlik_duzenle_baslik
                  : m.etkinlik_olustur_baslik,
              adimMetni: m.etkinlik_adim(
                t.adim - ilkAdim + 1,
                etkinlikAdimSayisi - ilkAdim,
              ),
              adim: t.adim - ilkAdim + 1,
              toplam: etkinlikAdimSayisi - ilkAdim,
              onKapat: kilitli ? null : () => unawaited(_kapat()),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: TayfamSizes.okumaGenisligi,
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(t.adim),
                    padding: const EdgeInsets.fromLTRB(
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s20,
                      TayfamSpacing.kenarMobil,
                      TayfamSpacing.s32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Seri etkinlikte düzenleme yalnızca bu etkinliği
                        // değiştirir (ADR-0015 §3); her adımda üstte.
                        if (_anahtar.duzenlenen?.seriesId != null) ...[
                          SihirbazBilgiKutusu(
                            metin: m.etkinlik_seri_duzenleme_notu,
                            ikon: Icons.event_repeat_outlined,
                          ),
                          const SizedBox(height: TayfamSpacing.s20),
                        ],
                        switch (t.adim) {
                          SihirbazAdimi.tur => _turAdimi(context, t),
                          SihirbazAdimi.bilgi => _bilgiAdimi(context, t),
                          SihirbazAdimi.yer => _yerAdimi(context, t),
                          SihirbazAdimi.ayrinti => _ayrintiAdimi(context, t),
                          _ => _OnizlemeAdimi(
                            taslak: t,
                            duzenlenen: _anahtar.duzenlenen,
                            onDegistir: kilitli ? null : _n.adimaGit,
                          ),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SihirbazAltCubugu(
          geriEtiketi: m.etkinlik_geri,
          onGeri: t.adim > ilkAdim && !kilitli ? () => _n.geri() : null,
          ileriEtiketi: !sonAdim
              ? m.etkinlik_ileri
              : _duzenleme
              ? m.etkinlik_duzenle_gonder
              : m.etkinlik_olustur_gonder,
          onIleri: kilitli
              ? null
              : sonAdim
              ? () => unawaited(_n.gonder())
              : _n.ileri,
        ),
      ),
    );
  }

  // --- Adım 1: tür ----------------------------------------------------------

  Widget _turAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final ilgi =
        ref.watch(tayfaOzetiProvider(widget.tayfaId)).tayfa?.interests ??
        const <EventType>[];
    final onde = [
      for (final tur in secilebilirEtkinlikTurleri)
        if (ilgi.contains(tur)) tur,
    ];
    final digerleri = [
      for (final tur in secilebilirEtkinlikTurleri)
        if (!onde.contains(tur)) tur,
    ];
    List<Widget> kutular(List<EventType> turler) => [
      for (final tur in turler)
        _TurKutusu(
          tur: tur,
          secili: t.tur == tur,
          onSecildi: t.gonderiliyor ? null : () => _n.turSec(tur),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.etkinlik_tur_baslik,
          aciklama: m.etkinlik_tur_adim_aciklama,
        ),
        if (t.hatalar.contains(TaslakHatasi.tur)) ...[
          const SizedBox(height: TayfamSpacing.s12),
          HataSatiri(metin: m.etkinlik_tur_hata),
        ],
        if (onde.isNotEmpty) ...[
          BolumEtiketi(baslik: m.etkinlik_tur_ilgi_alanlari),
          IkiSutunluIzgara(children: kutular(onde)),
          BolumEtiketi(baslik: m.etkinlik_tur_digerleri),
        ] else
          const SizedBox(height: TayfamSpacing.s20),
        IkiSutunluIzgara(children: kutular(digerleri)),
      ],
    );
  }

  // --- Adım 2: başlık ve zaman ----------------------------------------------

  Widget _bilgiAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final baslangic = t.baslangic;
    final bitis = t.bitis;
    final kapali = t.gonderiliyor;
    final baslangicHatasi = h.contains(TaslakHatasi.baslangicYok)
        ? m.etkinlik_baslangic_yok
        : h.contains(TaslakHatasi.baslangicGecmis)
        ? m.etkinlik_baslangic_gecmis
        : null;
    final bitisHatasi = h.contains(TaslakHatasi.bitis)
        ? m.etkinlik_bitis_hata
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(baslik: m.etkinlik_bilgi_baslik),
        const SizedBox(height: TayfamSpacing.s20),
        TextField(
          controller: _baslik,
          enabled: !kapali,
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
        YanYana(
          sol: _ZamanKutusu(
            etiket: m.etkinlik_baslangic,
            an: baslangic,
            ayniGun: false,
            hatali: baslangicHatasi != null,
            onPressed: kapali
                ? null
                : () async {
                    final secilen = await _tarihSaatSec(baslangic);
                    if (secilen != null) _n.baslangicAyarla(secilen);
                  },
          ),
          sag: _ZamanKutusu(
            etiket: m.etkinlik_bitis,
            an: bitis,
            ayniGun:
                baslangic != null &&
                bitis != null &&
                _ayniGun(baslangic, bitis),
            hatali: bitisHatasi != null,
            onPressed: kapali
                ? null
                : () async {
                    final secilen = await _tarihSaatSec(bitis ?? baslangic);
                    if (secilen != null) _n.bitisAyarla(secilen);
                  },
          ),
        ),
        if (baslangicHatasi != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: baslangicHatasi),
        ],
        if (bitisHatasi != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: bitisHatasi),
        ],
        const SizedBox(height: TayfamSpacing.s20),
        TextField(
          controller: _aciklama,
          enabled: !kapali,
          maxLength: etkinlikAciklamaEnCok,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _n.aciklamaAyarla,
          decoration: InputDecoration(
            labelText: m.etkinlik_aciklama_etiketi,
            hintText: m.etkinlik_aciklama_ipucu,
            alignLabelWithHint: true,
            errorText: h.contains(TaslakHatasi.aciklama)
                ? m.etkinlik_aciklama_hata
                : null,
          ),
        ),
        BolumEtiketi(baslik: m.etkinlik_kapak_baslik),
        FotografAlani(
          amac: UploadPurpose.cover,
          tayfaId: widget.tayfaId,
          deger: t.kapak,
          etiket: m.medya_kapak_etiketi,
          etkin: !kapali,
          onDegisti: _n.kapakAyarla,
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(m.etkinlik_kapak_aciklama, style: context.yazi.bodySmall),
      ],
    );
  }

  // --- Adım 3: yer ----------------------------------------------------------

  Widget _yerAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final yer = t.yer;
    final cevrimici = yer.mod == EventMode.online;
    final kapali = t.gonderiliyor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(baslik: m.etkinlik_yer_adim_baslik),
        const SizedBox(height: TayfamSpacing.s20),
        // İki parçalı seçim; büyük yazıda alt satıra iner.
        SecimCipleri<EventMode>(
          secenekler: [
            (EventMode.inPerson, m.etkinlik_mod_yuz_yuze),
            (EventMode.online, m.etkinlik_mod_cevrimici),
          ],
          secili: cevrimici ? EventMode.online : EventMode.inPerson,
          onSecildi: kapali ? null : (mod) => _yer((y) => y.kopya(mod: mod)),
        ),
        if (cevrimici) ...[
          const SizedBox(height: TayfamSpacing.s20),
          TextField(
            controller: _baglanti,
            enabled: !kapali,
            keyboardType: TextInputType.url,
            maxLength: etkinlikBaglantiEnCok,
            onChanged: (v) => _yer((y) => y.kopya(baglanti: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_baglanti_etiketi,
              errorText: h.contains(TaslakHatasi.baglanti)
                  ? m.etkinlik_baglanti_hata
                  : null,
            ),
          ),
        ] else ...[
          BolumEtiketi(baslik: m.etkinlik_yer_baslik),
          _NoktaKarti(
            nokta: yer.nokta,
            onSec: kapali ? null : () => unawaited(_noktaSec()),
          ),
          if (h.contains(TaslakHatasi.nokta)) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.etkinlik_nokta_hata),
          ],
          const SizedBox(height: TayfamSpacing.s20),
          TextField(
            controller: _noktaAdi,
            enabled: !kapali,
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
          YanYana(
            sol: TextField(
              controller: _il,
              enabled: !kapali,
              maxLength: etkinlikIlEnCok,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _yer((y) => y.kopya(il: v)),
              decoration: InputDecoration(
                labelText: m.etkinlik_il_etiketi,
                errorText: h.contains(TaslakHatasi.il)
                    ? m.etkinlik_il_hata
                    : null,
                errorMaxLines: 3,
              ),
            ),
            sag: TextField(
              controller: _ilce,
              enabled: !kapali,
              maxLength: etkinlikIlEnCok,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _yer((y) => y.kopya(ilce: v)),
              decoration: InputDecoration(
                labelText: m.etkinlik_ilce_etiketi,
                errorText: h.contains(TaslakHatasi.ilce)
                    ? m.etkinlik_ilce_hata
                    : null,
                errorMaxLines: 3,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- Adım 4: türe özel alanlar, kontenjan ve tekrar ----------------------

  Widget _ayrintiAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final kapali = t.gonderiliyor;
    final sinirsiz = t.kontenjan.trim().isEmpty;
    final tekrarHatasi = h.contains(TaslakHatasi.tekrarTarih)
        ? m.etkinlik_tekrar_tarih_hata
        : h.contains(TaslakHatasi.tekrarAralik)
        ? m.etkinlik_aralik_hata(tekrarAralikEnAz, tekrarAralikEnCok)
        : h.contains(TaslakHatasi.tekrarSayi)
        ? m.etkinlik_aralik_hata(tekrarSayiEnAz, tekrarSayiEnCok)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.etkinlik_ayrinti_adim_baslik,
          aciklama: m.etkinlik_ayrinti_adim_aciklama,
        ),
        BolumEtiketi(baslik: m.etkinlik_kontenjan),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SayiSayaci(
              denetleyici: _kontenjan,
              etiket: m.etkinlik_kontenjan,
              enAz: 1,
              enCok: etkinlikKontenjanEnCok,
              etkin: !kapali && !sinirsiz,
              onDegisti: _n.kontenjanAyarla,
            ),
            const SizedBox(height: TayfamSpacing.s8),
            MergeSemantics(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      m.etkinlik_kontenjan_sinirsiz,
                      style: context.yazi.titleSmall,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Switch(
                    value: sinirsiz,
                    onChanged: kapali ? null : _kontenjanSinirsiz,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (h.contains(TaslakHatasi.kontenjan)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: m.etkinlik_sayi_hata(etkinlikKontenjanEnCok)),
        ],
        ..._turAlanlari(context, t),
        if (!_duzenleme) ...[
          BolumEtiketi(baslik: m.etkinlik_tekrar_baslik),
          ListeKarti(
            children: [
              MenuSatiri.kartta(
                baslik: m.etkinlik_tekrar_baslik,
                aciklama: tekrarKisaOzeti(m, t.tekrar),
                ikon: Icons.event_repeat_outlined,
                sag: const SatirOku(),
                onTap: kapali ? null : () => unawaited(_tekrarAc()),
              ),
            ],
          ),
          if (tekrarHatasi != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: tekrarHatasi),
          ],
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
    List<(bool?, String)> ucDurum() => [
      (true, m.etkinlik_var),
      (false, m.etkinlik_yok),
      (null, m.etkinlik_bilinmiyor),
    ];
    switch (t.tur) {
      case EventType.camp:
        return [
          const SizedBox(height: TayfamSpacing.s20),
          TextField(
            controller: _kampYeri,
            enabled: !kapali,
            maxLength: etkinlikKampYeriEnCok,
            onChanged: (v) => _ayrinti((a) => a.kopya(kampYeri: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_kamp_yeri_etiketi,
              errorText: uzunluk(TaslakHatasi.kampYeri, etkinlikKampYeriEnCok),
            ),
          ),
          BolumEtiketi(baslik: m.etkinlik_kamp_su),
          SecimCipleri<bool?>(
            secenekler: ucDurum(),
            secili: a.su,
            onSecildi: kapali ? null : (v) => _ayrinti((a) => a.kopya(su: v)),
          ),
          BolumEtiketi(baslik: m.etkinlik_kamp_tuvalet),
          SecimCipleri<bool?>(
            secenekler: ucDurum(),
            secili: a.tuvalet,
            onSecildi: kapali
                ? null
                : (v) => _ayrinti((a) => a.kopya(tuvalet: v)),
          ),
          const SizedBox(height: TayfamSpacing.s20),
          TextField(
            controller: _kampNotu,
            enabled: !kapali,
            maxLength: etkinlikKampNotuEnCok,
            minLines: 2,
            maxLines: 5,
            onChanged: (v) => _ayrinti((a) => a.kopya(kampNotu: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_kamp_notu_etiketi,
              alignLabelWithHint: true,
              errorText: uzunluk(TaslakHatasi.kampNotu, etkinlikKampNotuEnCok),
            ),
          ),
        ];
      case EventType.hike:
        final donus = a.donus;
        return [
          BolumEtiketi(baslik: m.etkinlik_yuruyus_zorluk),
          SecimCipleri<int>(
            secenekler: [
              for (var z = 1; z <= etkinlikZorlukEnCok; z++) (z, '$z'),
            ],
            secili: a.zorluk,
            // Seçili zorluğa yeniden dokunmak seçimi kaldırır.
            onSecildi: kapali
                ? null
                : (z) =>
                      _ayrinti((a) => a.kopya(zorluk: a.zorluk == z ? 0 : z)),
          ),
          const SizedBox(height: TayfamSpacing.s20),
          YanYana(
            sol: TextField(
              controller: _mesafe,
              enabled: !kapali,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => _ayrinti((a) => a.kopya(mesafe: v)),
              decoration: InputDecoration(
                labelText: m.etkinlik_mesafe_etiketi,
                errorText: sayi(
                  TaslakHatasi.mesafe,
                  etkinlikMesafeEnCok.toInt(),
                ),
                errorMaxLines: 3,
              ),
            ),
            sag: TextField(
              controller: _yukselti,
              enabled: !kapali,
              keyboardType: TextInputType.number,
              onChanged: (v) => _ayrinti((a) => a.kopya(yukselti: v)),
              decoration: InputDecoration(
                labelText: m.etkinlik_yukselti_etiketi,
                errorText: sayi(TaslakHatasi.yukselti, etkinlikYukseltiEnCok),
                errorMaxLines: 3,
              ),
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
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.etkinlik_yuruyus_donus_notu, style: context.yazi.bodySmall),
        ];
      case EventType.fishing:
        return [
          BolumEtiketi(baslik: m.etkinlik_balik_gizlilik),
          SecimCipleri<FishingDetailsSpotVisibility>(
            secenekler: [
              for (final g in const [
                FishingDetailsSpotVisibility.tayfa,
                FishingDetailsSpotVisibility.participants,
              ])
                (g, balikGizliligiAdi(m, g)),
            ],
            secili: a.balikGizliligi,
            onSecildi: kapali
                ? null
                : (g) => _ayrinti((a) => a.kopya(balikGizliligi: g)),
          ),
        ];
      case EventType.gaming:
        return [
          const SizedBox(height: TayfamSpacing.s20),
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
          BolumEtiketi(baslik: m.etkinlik_oyun_platform),
          SecimCipleri<GamingDetailsPlatform>(
            secenekler: [
              for (final p in secilebilirPlatformlar) (p, platformAdi(m, p)),
            ],
            secili: a.platform,
            onSecildi: kapali
                ? null
                : (p) => _ayrinti((a) => a.kopya(platform: p)),
          ),
          if (h.contains(TaslakHatasi.platform)) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.etkinlik_secim_hata),
          ],
        ];
      case EventType.sports:
        return [
          BolumEtiketi(baslik: m.etkinlik_spor),
          SecimCipleri<SportsDetailsSport>(
            secenekler: [
              for (final s in secilebilirSporlar) (s, sporAdi(m, s)),
            ],
            secili: a.spor,
            onSecildi: kapali ? null : (s) => _ayrinti((a) => a.kopya(spor: s)),
          ),
          if (h.contains(TaslakHatasi.spor)) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.etkinlik_secim_hata),
          ],
          const SizedBox(height: TayfamSpacing.s20),
          TextField(
            controller: _sahaAdi,
            enabled: !kapali,
            maxLength: etkinlikSahaEnCok,
            onChanged: (v) => _ayrinti((a) => a.kopya(sahaAdi: v)),
            decoration: InputDecoration(
              labelText: m.etkinlik_spor_saha_etiketi,
              errorText: uzunluk(TaslakHatasi.sahaAdi, etkinlikSahaEnCok),
            ),
          ),
        ];
      case EventType.convoy:
        return [
          BolumEtiketi(baslik: m.etkinlik_rota_baslik),
          _RotaKarti(
            rota: a.rota,
            onCiz: kapali ? null : () => unawaited(_rotaSec()),
          ),
          if (h.contains(TaslakHatasi.rota)) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.etkinlik_rota_hata),
          ],
        ];
      case EventType.general || EventType.unknown || null:
        return const [];
    }
  }
}

bool _ayniGun(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// "Vazgeçilsin mi?" onayı; vazgeçilirse `true`.
Future<bool> _vazgecOnayi(BuildContext context) async {
  final m = AppLocalizations.of(context);
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(m.etkinlik_vazgec_baslik),
      scrollable: true,
      content: Text(m.etkinlik_vazgec_metni),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec_devam),
        ),
        YikiciEylem(
          etiket: m.etkinlik_vazgec,
          dolu: true,
          onPressed: () => Navigator.of(pencere).pop(true),
        ),
      ],
    ),
  );
  return sonuc ?? false;
}

/// Tür seçim kutusu (tasarım: Sihirbaz-Tur): türün renginde ikon kutusu,
/// ad ve kısa açıklama; seçiliyken marka kenar, tint zemin ve işaret.
/// Renk tek başına bilgi taşımaz: seçim ekran okuyucuda da bildirilir.
class _TurKutusu extends StatelessWidget {
  const _TurKutusu({
    required this.tur,
    required this.secili,
    required this.onSecildi,
  });

  final EventType tur;
  final bool secili;
  final VoidCallback? onSecildi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final girdi = etkinlikTuruGirdisi(tur);
    final cift = context.turRenkleri.cift(girdi.renk);
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
          selected: secili,
          inMutuallyExclusiveGroup: true,
          child: InkWell(
            onTap: onSecildi,
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
                                girdi.ikon,
                                size: TayfamSizes.ikon,
                                color: cift.ustu,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s8),
                        Text(girdi.ad(m), style: context.yazi.titleMedium),
                        Text(
                          turAciklamasi(m, tur),
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

/// Başlangıç ya da bitiş kutusu (tasarım: Sihirbaz-Bilgi): üstte etiket ve
/// gün (küçük), altta saat (büyük); bitiş başlangıçla aynı gündeyse "Aynı
/// gün". Seçilmemişse "Seç". Dokununca tarih ve saat seçicisi açılır.
class _ZamanKutusu extends StatelessWidget {
  const _ZamanKutusu({
    required this.etiket,
    required this.an,
    required this.ayniGun,
    required this.hatali,
    required this.onPressed,
  });

  final String etiket;
  final DateTime? an;
  final bool ayniGun;
  final bool hatali;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final an = this.an?.toLocal();
    final gun = an == null
        ? null
        : ayniGun
        ? m.etkinlik_ayni_gun
        : etkinlikKisaGun(m, an);
    final saat = an == null ? m.etkinlik_zaman_sec : etkinlikSaat(m, an);
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: BorderSide(
            color: hatali ? r.narMetin : r.girisKenari,
            width: hatali
                ? TayfamSizes.alanOdakKenari
                : TayfamSizes.vurguKenari,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiket,
                    style: context.yazi.labelMedium?.copyWith(
                      color: r.metinIkincil,
                    ),
                  ),
                  if (gun != null) Text(gun, style: context.yazi.bodySmall),
                  Text(saat, style: context.yazi.headlineSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Buluşma noktası kartı (tasarım: Sihirbaz-Yer): seçilmemişse "Haritada
/// seç"; seçilince harita önizlemesi, "Nokta seçildi" ve "Noktayı
/// değiştir".
class _NoktaKarti extends StatelessWidget {
  const _NoktaKarti({required this.nokta, required this.onSec});

  final LatLng? nokta;
  final VoidCallback? onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final nokta = this.nokta;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nokta != null)
            SizedBox(
              height: haritaOnizlemeYuksekligi,
              child: OsmHarita(
                key: ValueKey(nokta),
                merkez: nokta,
                yakinlik: haritaOnizlemeYakinligi,
                isaret: nokta,
                etkilesimli: false,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        nokta == null ? Icons.place_outlined : Icons.check,
                        size: TayfamSizes.ikon,
                        color: r.tintMarkaUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Flexible(
                      child: Text(
                        nokta == null
                            ? m.etkinlik_nokta_secilmedi
                            : m.etkinlik_nokta_secildi,
                        style: context.yazi.titleSmall,
                      ),
                    ),
                  ],
                ),
                CerceveliHapEylem(
                  etiket: nokta == null
                      ? m.etkinlik_nokta_sec
                      : m.etkinlik_nokta_degistir,
                  ikon: Icons.map_outlined,
                  onPressed: onSec,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Konvoy rotası kartı (tasarım: Sihirbaz-Ayrinti): çizilmediyse "Rota
/// çizilmedi." ve "Rota çiz"; çizildiyse küçük önizleme, nokta sayısı ve
/// "Rotayı düzenle".
class _RotaKarti extends StatelessWidget {
  const _RotaKarti({required this.rota, required this.onCiz});

  final List<LatLng> rota;
  final VoidCallback? onCiz;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final bos = rota.isEmpty;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!bos)
            SizedBox(
              height: sihirbazRotaYuksekligi,
              child: OsmHarita(
                key: ValueKey(rota.length),
                merkez: rota.first,
                yakinlik: rotaSeciciYakinligi,
                rota: rota,
                etkilesimli: false,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.route_outlined,
                        size: TayfamSizes.ikon,
                        color: r.tintMarkaUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Flexible(
                      child: Text(
                        bos
                            ? m.etkinlik_rota_yok
                            : m.etkinlik_konvoy_rota_noktalari(
                                etkinlikSayi(m, rota.length),
                              ),
                        style: context.yazi.titleSmall,
                      ),
                    ),
                  ],
                ),
                CerceveliHapEylem(
                  etiket: bos ? m.etkinlik_rota_ciz : m.etkinlik_rota_duzenle,
                  ikon: Icons.route,
                  onPressed: onCiz,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Önizleme (5. adım; tasarım: Sihirbaz-Onizleme): "Her şey doğru mu?",
/// türün renginde başlıklı özet kartı ve satırlar (Ne zaman, Nerede,
/// Kontenjan, Tekrar; konvoyda Rota). Her satırdaki "Değiştir" ilgili
/// adıma götürür. Sunucunun hatası burada gösterilir.
class _OnizlemeAdimi extends StatelessWidget {
  const _OnizlemeAdimi({
    required this.taslak,
    required this.duzenlenen,
    required this.onDegistir,
  });

  final EtkinlikTaslagi taslak;
  final Event? duzenlenen;

  /// `null` ise "Değiştir" devre dışıdır (gönderim sürerken).
  final ValueChanged<int>? onDegistir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final t = taslak;
    final degistir = onDegistir;
    final tur = t.tur ?? EventType.general;
    final girdi = etkinlikTuruGirdisi(tur);
    final cift = context.turRenkleri.cift(girdi.renk);
    final baslangic = t.baslangic;
    final bitis = t.bitis;
    final yer = t.yer;
    final kontenjan = kontenjanSayisi(t.kontenjan) ?? 0;
    final nerede = yer.mod == EventMode.online
        ? m.etkinlik_karti_cevrimici
        : [
            yer.noktaAdi.trim(),
            [
              yer.ilce.trim(),
              yer.il.trim(),
            ].where((p) => p.isNotEmpty).join(', '),
          ].where((p) => p.isNotEmpty).join(ozetAyraci);
    final satirlar = <(String, String, int)>[
      (
        m.etkinlik_onizleme_ne_zaman,
        baslangic == null || bitis == null
            ? m.etkinlik_zaman_sec
            : etkinlikZamanAraligi(m, baslangic, bitis),
        SihirbazAdimi.bilgi,
      ),
      (m.etkinlik_onizleme_nerede, nerede, SihirbazAdimi.yer),
      (
        m.etkinlik_kontenjan,
        kontenjan > 0
            ? m.etkinlik_onizleme_kisi(kontenjan)
            : m.etkinlik_kontenjan_sinirsiz,
        SihirbazAdimi.ayrinti,
      ),
      if (duzenlenen == null)
        (
          m.etkinlik_tekrar_baslik,
          tekrarKisaOzeti(m, t.tekrar),
          SihirbazAdimi.ayrinti,
        ),
      if (tur == EventType.convoy)
        (
          m.etkinlik_konvoy_rota,
          t.ayrinti.rota.isEmpty
              ? m.etkinlik_rota_yok
              : m.etkinlik_konvoy_rota_noktalari(
                  etkinlikSayi(m, t.ayrinti.rota.length),
                ),
          SihirbazAdimi.ayrinti,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.etkinlik_onizleme_baslik,
          aciklama: duzenlenen == null
              ? m.etkinlik_onizleme_aciklama
              : m.etkinlik_onizleme_duzenleme_aciklama,
        ),
        if (t.hata case final hata?) ...[
          const SizedBox(height: TayfamSpacing.s16),
          HataSatiri.hatadan(hata),
        ],
        const SizedBox(height: TayfamSpacing.s20),
        Material(
          color: r.kart,
          shape: RoundedRectangleBorder(
            borderRadius: TayfamRadii.kartKoseleri,
            side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: cift.dolgu,
                child: Padding(
                  padding: const EdgeInsets.all(TayfamSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: r.markaYuzeyKutusu,
                          borderRadius: TayfamRadii.hapKoseleri,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TayfamSpacing.s12,
                            vertical: TayfamSpacing.s4,
                          ),
                          child: Text(
                            girdi.ad(m),
                            style: context.yazi.labelLarge?.copyWith(
                              color: r.markaYuzeyUstu,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s8),
                      Text(
                        t.baslik.trim(),
                        style: context.yazi.titleLarge?.copyWith(
                          color: cift.ustu,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final (etiket, deger, adim) in satirlar) ...[
                Divider(
                  height: TayfamSizes.kenar,
                  thickness: TayfamSizes.kenar,
                  color: r.cizgi,
                ),
                _OnizlemeSatiri(
                  etiket: etiket,
                  deger: deger,
                  onDegistir: degistir == null ? null : () => degistir(adim),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OnizlemeSatiri extends StatelessWidget {
  const _OnizlemeSatiri({
    required this.etiket,
    required this.deger,
    required this.onDegistir,
  });

  final String etiket;
  final String deger;
  final VoidCallback? onDegistir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.s16,
        TayfamSpacing.s8,
        TayfamSpacing.s4,
        TayfamSpacing.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiket,
                    style: context.yazi.labelMedium?.copyWith(
                      color: context.renkler.metinIkincil,
                    ),
                  ),
                  Text(deger, style: context.yazi.bodyLarge),
                ],
              ),
            ),
          ),
          BaglantiEylemi(
            etiket: m.etkinlik_degistir,
            semantikEtiketi: m.etkinlik_degistir_etiketi(etiket),
            onPressed: onDegistir,
          ),
        ],
      ),
    );
  }
}

/// Tarih ve saat alanı (yürüyüşte beklenen dönüş): etiket, seçilen değer
/// (yoksa "Seç") ve hata. Dokununca seçici açılır; [onTemizle] verilirse
/// değer silinebilir.
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
            CerceveliHapEylem(
              etiket: deger ?? m.etkinlik_zaman_sec,
              ikon: Icons.schedule,
              onPressed: onPressed,
            ),
            if (onTemizle != null)
              BaglantiEylemi(etiket: m.etkinlik_temizle, onPressed: onTemizle),
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
