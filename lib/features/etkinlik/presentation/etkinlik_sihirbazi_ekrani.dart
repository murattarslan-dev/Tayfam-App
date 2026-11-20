import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_bolumleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/presentation/anlik/anlik_acildi_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/anlik/arkadas_secimi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/core/harita/harita_secici_ekrani.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/features/etkinlik/presentation/tekrar_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/tur_secici.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
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
///
/// [EtkinlikSihirbaziEkrani.anlik] anlık (bireysel) etkinliktir (ADR-0026;
/// tasarım: `docs/tasarim/29`): tayfa yoktur, başlık "Anlık etkinlik"; tür
/// adımında ilgi alanı grubu, bilgi adımında kapak, ayrıntı adımında tekrar
/// yoktur; ayrıntıdan sonra "Kimleri çağıralım?" adımı gelir. Başarıda
/// "Etkinlik açıldı" ekranı ([AnlikAcildiEkrani]) sihirbazın yerine çizilir.
class EtkinlikSihirbaziEkrani extends ConsumerStatefulWidget {
  const EtkinlikSihirbaziEkrani({
    super.key,
    required String this.tayfaId,
    this.duzenlenen,
  }) : anlikBaslangic = (gun: null, davetli: null);

  /// Anlık etkinlik sihirbazı; [anlikBaslangic] adresten gelen, doğrulanmış
  /// açılış değerleridir.
  const EtkinlikSihirbaziEkrani.anlik({
    super.key,
    this.anlikBaslangic = (gun: null, davetli: null),
  }) : tayfaId = null,
       duzenlenen = null;

  /// Etkinliğin tayfası; anlık etkinlikte `null`.
  final String? tayfaId;

  /// Düzenlenen etkinlik; oluşturmada `null`.
  final Event? duzenlenen;

  /// Anlık etkinliğin açılış değerleri.
  final AnlikAnahtari anlikBaslangic;

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

  late final NotifierProvider<EtkinlikSihirbaziNotifier, EtkinlikTaslagi>
  _provider = widget.tayfaId == null
      ? anlikSihirbazProvider(widget.anlikBaslangic)
      : etkinlikSihirbaziProvider(_anahtar);

  bool get _anlik => widget.tayfaId == null;

  late final TextEditingController _baslik;
  late final TextEditingController _aciklama;
  late final TextEditingController _noktaAdi;
  late final TextEditingController _il;
  late final TextEditingController _ilce;
  late final TextEditingController _baglanti;
  late final TextEditingController _kontenjan;

  /// "Sınırsız" kapatılınca kontenjanın başladığı değer.
  static const int _varsayilanKontenjan = 10;

  @override
  void initState() {
    super.initState();
    final t = ref.read(_provider);
    _baslik = TextEditingController(text: t.baslik);
    _aciklama = TextEditingController(text: t.aciklama);
    _noktaAdi = TextEditingController(text: t.yer.noktaAdi);
    _il = TextEditingController(text: t.yer.il);
    _ilce = TextEditingController(text: t.yer.ilce);
    _baglanti = TextEditingController(text: t.yer.baglanti);
    _kontenjan = TextEditingController(text: t.kontenjan);
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
    ]) {
      d.dispose();
    }
    super.dispose();
  }

  EtkinlikSihirbaziNotifier get _n => ref.read(_provider.notifier);

  EtkinlikTaslagi get _t => ref.read(_provider);

  bool get _duzenleme => _anahtar.duzenlenen != null;

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
    final tayfaId = widget.tayfaId;
    context.go(
      tayfaId == null
          ? Adresler.kok
          : eski == null
          ? Adresler.etkinlikler(tayfaId)
          : Adresler.etkinlik(tayfaId, eski.id),
    );
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
    final provider = _provider;
    ref.listen(provider, (_, sonraki) {
      final id = sonraki.sonuc;
      final tayfaId = widget.tayfaId;
      // Anlık etkinlikte "Etkinlik açıldı" ekranı sihirbazın yerine çizilir.
      if (id == null || tayfaId == null) return;
      if (_duzenleme && context.canPop()) {
        context.pop();
      } else {
        context.go(Adresler.etkinlik(tayfaId, id));
      }
    });
    final t = ref.watch(provider);
    // Düzenlemede katalog alanları etkinliğin kendi tür sürümüyle çizilir;
    // tanım sonradan gelirse taslağa işlenir.
    if (_anahtar.duzenlenen case final eski? when t.turTanimi == null) {
      final tanim = turTaniminiIzle(ref, eski.type, surum: eski.typeVersion);
      if (tanim != null && tanim.version == eski.typeVersion) {
        final n = _n;
        unawaited(Future<void>.microtask(() => n.tanimGeldi(tanim)));
      }
    }
    // Düzenlemede bileşen seçimleri etkinliğin sunucudaki halinden
    // doldurulur (ADR-0031 §1); yalnızca çizilecek bileşen varsa okunur.
    if (_anahtar.duzenlenen case final eski?
        when !t.bilesenlerOkundu && t.turTanimi != null) {
      final kayit = ref.watch(etkinlikBilesenKaydiProvider);
      if (bilesenPlani(t.turTanimi, kayit).any((p) => p.bilesen != null)) {
        final durum = ref
            .watch(
              etkinlikBilesenleriProvider((
                tayfaId: eski.tayfaId,
                etkinlikId: eski.id,
              )),
            )
            .value;
        if (durum != null) {
          final n = _n;
          unawaited(Future<void>.microtask(() => n.bilesenDurumuGeldi(durum)));
        }
      }
    }
    if (t.anlikSonuc case final sonuc?) {
      return AnlikAcildiEkrani(
        sonuc: sonuc,
        davetliSayisi: t.davetliler.length,
      );
    }
    final n = _n;
    final ilkAdim = n.ilkAdim;
    final adimSayisi = n.adimSayisi;
    final sonAdim = t.adim == n.onizlemeAdimi;
    final kilitli = t.gonderiliyor;
    return PopScope(
      // Anlık sihirbaz `go` ile açılır; altında sayfa olmayabilir (kapat
      // kök adrese döner).
      canPop:
          !_anlik && (t.sonuc != null || (t.adim <= ilkAdim && !n.girdiVar)),
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (geriDonuldu || kilitli) return;
        if (!_n.geri()) unawaited(_kapat());
      },
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SihirbazUstCubugu(
              baslik: _anlik
                  ? m.anlik_baslik
                  : _duzenleme
                  ? m.etkinlik_duzenle_baslik
                  : m.etkinlik_olustur_baslik,
              adimMetni: m.etkinlik_adim(
                t.adim - ilkAdim + 1,
                adimSayisi - ilkAdim,
              ),
              adim: t.adim - ilkAdim + 1,
              toplam: adimSayisi - ilkAdim,
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
                          SihirbazAdimi.davet when _anlik => _davetAdimi(
                            context,
                            t,
                          ),
                          _ => _OnizlemeAdimi(
                            taslak: t,
                            duzenlenen: _anahtar.duzenlenen,
                            anlik: _anlik,
                            davetliOzeti: _anlik
                                ? _davetliOzeti(context, t.davetliler)
                                : null,
                            onDegistir: kilitli ? null : n.adimaGit,
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
    final tayfaId = widget.tayfaId;
    // Anlık etkinlikte tayfa yoktur; ilgi alanı grubu çıkmaz.
    final ilgi = tayfaId == null
        ? const <String>[]
        : ref.watch(tayfaOzetiProvider(tayfaId)).tayfa?.interests ??
              const <String>[];
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
        TurSecici(
          secili: t.tur,
          ilgiAlanlari: ilgi,
          onSecildi: t.gonderiliyor ? null : _n.turSec,
        ),
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
    // Açık uçlu etkinliğin zamanı düzenlenemez (Tayfam-Api ADR-0038 §1).
    final zamanKilitli = _n.zamanKilitli;
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
            onPressed: kapali || zamanKilitli
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
            onPressed: kapali || zamanKilitli
                ? null
                : () async {
                    final secilen = await _tarihSaatSec(bitis ?? baslangic);
                    if (secilen != null) _n.bitisAyarla(secilen);
                  },
          ),
        ),
        if (zamanKilitli) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.simdi_zaman_duzenlenemez,
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
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
        // Anlık etkinlikte kapak oluşturmada verilemez (sözleşme); sonra
        // düzenlemeyle eklenir.
        if (widget.tayfaId case final tayfaId?) ...[
          BolumEtiketi(baslik: m.etkinlik_kapak_baslik),
          FotografAlani(
            amac: UploadPurpose.cover,
            tayfaId: tayfaId,
            deger: t.kapak,
            etiket: m.medya_kapak_etiketi,
            etkin: !kapali,
            onDegisti: _n.kapakAyarla,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.etkinlik_kapak_aciklama, style: context.yazi.bodySmall),
        ],
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
    // Düzenlemede mod, etkinliğin bugünkü modu tür tanımında olmasa da
    // değiştirilebilir kalır; son söz sunucunundur.
    final modlar = _duzenleme
        ? const [EventMode.inPerson, EventMode.online]
        : turModlari(t.turTanimi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(baslik: m.etkinlik_yer_adim_baslik),
        const SizedBox(height: TayfamSpacing.s20),
        // İki parçalı seçim; büyük yazıda alt satıra iner. Tür tek modda
        // yapılabiliyorsa (katalog `modes`) seçim gösterilmez.
        if (modlar.length > 1)
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
          // "Halka açık yerde buluşur" (ADR-0027; 30-kesfet-ve-guvenlik,
          // karar 25): tayfa ayarlarındaki anahtarların iskeleti. Anlık
          // etkinlik Keşfet'e hiç çıkmaz (Tayfam-Api ADR-0033 §12); orada
          // yoktur.
          if (!_anlik)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                m.etkinlik_halka_acik,
                style: context.yazi.titleMedium,
              ),
              subtitle: Text(
                m.etkinlik_halka_acik_aciklama,
                style: context.yazi.bodySmall?.copyWith(
                  color: context.renkler.metinIkincil,
                ),
              ),
              value: yer.halkaAcik,
              onChanged: kapali
                  ? null
                  : (acik) => _yer((y) => y.kopya(halkaAcik: acik)),
            ),
        ],
      ],
    );
  }

  // --- Anlık etkinlik, adım 5: kimleri çağıralım? --------------------------

  Widget _davetAdimi(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.anlik_davet_baslik,
          aciklama: m.anlik_davet_aciklama(anlikDavetliEnCok),
        ),
        const SizedBox(height: TayfamSpacing.s20),
        ArkadasSecimi(
          secili: t.davetliler,
          onDegistir: t.gonderiliyor ? null : _n.davetliDegistir,
        ),
      ],
    );
  }

  /// Önizlemedeki "Davetliler" satırı: ilk iki ad ve kalan sayı. Adlar
  /// yüklü arkadaş listesinden; bilinmiyorsa yalnızca sayı.
  String _davetliOzeti(BuildContext context, List<String> davetliler) {
    final m = AppLocalizations.of(context);
    if (davetliler.isEmpty) return m.anlik_davetli_yok;
    final arkadaslar =
        ref.watch(arkadaslarProvider).value?.ogeler ?? const <Friend>[];
    final adlar = {for (final a in arkadaslar) a.userId: a.displayName};
    final bilinen = [for (final id in davetliler) ?adlar[id]];
    if (bilinen.length != davetliler.length) {
      return m.anlik_davetli_sayi(davetliler.length);
    }
    const gosterilen = 2;
    final ilkler = bilinen.take(gosterilen).join(', ');
    final kalan = bilinen.length - gosterilen;
    return kalan > 0 ? m.anlik_davetli_fazla(ilkler, kalan) : ilkler;
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
        // Anlık etkinlik tekrarlanmaz (sözleşme).
        if (!_duzenleme && !_anlik) ...[
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

  /// Türe özel alanlar: katalogdaki tür alanları (tek alan çizici,
  /// ADR-0024 §3) ve bileşenlerin seçimleri.
  List<Widget> _turAlanlari(BuildContext context, EtkinlikTaslagi t) {
    final alanlar = turAlanlari(t.turTanimi);
    return [
      if (alanlar.isNotEmpty)
        KatalogAlanlari(
          alanlar: alanlar,
          degerler: t.alanlar,
          hatalar: t.hatalar.contains(TaslakHatasi.alanlar)
              ? alanHatalari(alanlar, t.alanlar)
              : const {},
          onDegisti: t.gonderiliyor ? null : _n.alanlariAyarla,
        ),
      // Bileşenler: `optional` aç/kapa satırları ve organizatöre bırakılan
      // seçimler (ADR-0031 §1). Düzenlemede durum okunana kadar çizilmez.
      if (t.bilesenlerOkundu)
        BilesenFormBolumleri(
          tanim: t.turTanimi,
          secimler: t.bilesenler,
          tayfaId: widget.tayfaId,
          etkinlik: _anahtar.duzenlenen,
          kilitli: t.bilesenlerKilitli,
          etkin: !t.gonderiliyor,
          onAcKapa: (bilesen, acik) => _n.bilesenAcKapat(bilesen, acik: acik),
          onSecim: _n.bilesenSec,
        ),
    ];
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

/// Önizleme (5. adım; tasarım: Sihirbaz-Onizleme): "Her şey doğru mu?",
/// türün renginde başlıklı özet kartı ve satırlar (Ne zaman, Nerede,
/// Kontenjan, Tekrar). Her satırdaki "Değiştir" ilgili
/// adıma götürür. Sunucunun hatası burada gösterilir.
class _OnizlemeAdimi extends ConsumerWidget {
  const _OnizlemeAdimi({
    required this.taslak,
    required this.duzenlenen,
    required this.onDegistir,
    this.anlik = false,
    this.davetliOzeti,
  });

  final EtkinlikTaslagi taslak;
  final Event? duzenlenen;

  /// Anlık etkinlik: tekrar satırı yerine "Davetliler"; altta arşiv ve
  /// davet linki bilgisi; `instant-event-limit` sınır kutusunda.
  final bool anlik;

  /// Anlık etkinlikte "Davetliler" satırının değeri.
  final String? davetliOzeti;

  /// `null` ise "Değiştir" devre dışıdır (gönderim sürerken).
  final ValueChanged<int>? onDegistir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final t = taslak;
    final degistir = onDegistir;
    final tur = t.tur ?? '';
    final gorunum = turGorunumu(
      tur,
      t.turTanimi,
      ref.watch(katalogProvider).value,
      katalogDili(context),
    );
    final turAdi = gorunum.ad ?? m.katalog_tur_bilinmiyor;
    final cift = context.turRenkleri.cift(gorunum.renk);
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
    final alanDegerleri = alanGovdesi(turAlanlari(t.turTanimi), t.alanlar);
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
      if (duzenlenen == null && !anlik)
        (
          m.etkinlik_tekrar_baslik,
          tekrarKisaOzeti(m, t.tekrar),
          SihirbazAdimi.ayrinti,
        ),
      // Katalogdaki tür alanlarından değeri girilenler.
      for (final alan in turAlanlari(t.turTanimi))
        if (katalogAlanDegeriMetni(context, alan, alanDegerleri[alan.key])
            case final deger?)
          (
            katalogAlanAdi(alan, katalogDili(context)),
            deger,
            SihirbazAdimi.ayrinti,
          ),
      if (anlik)
        (
          m.anlik_onizleme_davetliler,
          davetliOzeti ?? m.anlik_davetli_yok,
          SihirbazAdimi.davet,
        ),
    ];
    final hata = t.hata;
    final sinirHatasi =
        hata is ApiProblem && hata.type == ProblemType.instantEventLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdimBasligi(
          baslik: m.etkinlik_onizleme_baslik,
          aciklama: anlik
              ? m.anlik_onizleme_aciklama
              : duzenlenen == null
              ? m.etkinlik_onizleme_aciklama
              : m.etkinlik_onizleme_duzenleme_aciklama,
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s16),
          if (sinirHatasi)
            SinirKutusu(
              baslik: m.anlik_sinir_baslik,
              metin: m.anlik_sinir_metni,
            )
          else
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
                            turAdi,
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
        if (anlik) ...[
          const SizedBox(height: TayfamSpacing.s16),
          SihirbazBilgiKutusu(
            metin: m.anlik_onizleme_bilgi,
            ikon: Icons.info_outline,
          ),
        ],
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
