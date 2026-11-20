import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/harita/harita_secici_ekrani.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/simdi_baslat.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/features/etkinlik/presentation/tur_secici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Şimdi başlat ekranı (`/simdi?tayfa=<id>`; App ADR-0032 §2): kabuğun
/// üstünde tam ekran, tek ekranda doğaçlama etkinlik.
///
/// - **Tür:** Genel ve son kullanılan türler (en çok
///   [simdiSonTurSayisi], yalnızca bellekte) ve "Tüm türler".
/// - **Başlık:** isteğe bağlı; boşsa "Murat'ın Masa oyunu gecesi" gibi
///   üretilir (`simdi_varsayilan_baslik`).
/// - **Yer:** yüz yüzede harita seçici cihaz konumuyla açılır (konum izni
///   yalnızca bu an istenir); kullanıcı noktayı haritada onaylar. İzin
///   yoksa seçici elle çalışır. Çevrimiçide bağlantı alanı.
/// - Türün zorunlu katalog alanları ve `optional` bileşenlerin aç/kapa
///   satırları; `organizer_choice` parametreleri varsayılanla gider.
/// - "Kimler duysun" bilgi satırı. Arkadaş seçici ayrı iştir (#249).
///
/// Başarıda etkinliğin detayı açılır.
class SimdiEkrani extends ConsumerStatefulWidget {
  const SimdiEkrani({super.key, required this.anahtar});

  final SimdiAnahtari anahtar;

  @override
  ConsumerState<SimdiEkrani> createState() => _SimdiEkraniState();
}

class _SimdiEkraniState extends ConsumerState<SimdiEkrani> {
  final TextEditingController _baslik = TextEditingController();
  final TextEditingController _il = TextEditingController();
  final TextEditingController _ilce = TextEditingController();
  final TextEditingController _baglanti = TextEditingController();

  @override
  void dispose() {
    _baslik.dispose();
    _il.dispose();
    _ilce.dispose();
    _baglanti.dispose();
    super.dispose();
  }

  NotifierProvider<SimdiNotifier, EtkinlikTaslagi> get _provider =>
      simdiBaslatProvider(widget.anahtar);

  SimdiNotifier get _n => ref.read(_provider.notifier);

  EtkinlikTaslagi get _t => ref.read(_provider);

  void _yer(YerBilgisi Function(YerBilgisi y) degistir) =>
      _n.yerAyarla(degistir(_t.yer));

  void _kapat() {
    final gezinme = Navigator.of(context);
    if (gezinme.canPop()) {
      gezinme.pop();
      return;
    }
    final tayfaId = widget.anahtar.tayfaId;
    context.go(tayfaId == null ? Adresler.kok : Adresler.tayfa(tayfaId));
  }

  /// Harita seçicisini cihaz konumuyla açar (nokta henüz yoksa).
  Future<void> _noktaSec() async {
    final m = AppLocalizations.of(context);
    final mevcut = _t.yer.nokta;
    final sonuc = await haritaSeciciAc(
      context,
      baslangic: mevcut,
      konumlaAc: mevcut == null,
      secEtiketi: m.simdi_harita_sec,
    );
    if (sonuc == null || !mounted) return;
    final oneri = sonuc.oneri;
    _n.noktaSec(sonuc.nokta, il: oneri?.il, ilce: oneri?.ilce);
    final yer = _t.yer;
    _il.text = yer.il;
    _ilce.text = yer.ilce;
  }

  Future<void> _tumTurler() async {
    final m = AppLocalizations.of(context);
    final secilen = await Navigator.of(context).push(
      MaterialPageRoute<CatalogEventType>(
        builder: (sayfa) => Scaffold(
          appBar: AppBar(title: Text(m.simdi_tum_turler)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: TurSecici(
              secili: _t.tur,
              onSecildi: (tur) => Navigator.of(sayfa).pop(tur),
            ),
          ),
        ),
      ),
    );
    if (secilen != null && mounted) _n.turSec(secilen);
  }

  /// Boş başlıkta kullanılacak başlık: "Murat'ın Masa oyunu gecesi"; ad
  /// bilinmiyorsa yalnızca türün adı.
  String _varsayilanBaslik(AppLocalizations m, String turAdi) {
    final ben = ref.watch(kendiKimligimProvider).value;
    if (ben == null) return turAdi;
    ref.read(kullaniciAdlariProvider.notifier).iste(ben);
    final ad = ref.watch(kullaniciAdlariProvider)[ben]?.ad?.trim();
    if (ad == null || ad.isEmpty) return turAdi;
    return m.simdi_varsayilan_baslik(ad, ilgiEki(ad), turAdi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    ref.listen(_provider, (_, sonraki) {
      final id = sonraki.sonuc;
      if (id == null) return;
      final tayfaId = widget.anahtar.tayfaId ?? sonraki.anlikSonuc?.tayfa.id;
      if (tayfaId == null) return;
      context.go(Adresler.etkinlik(tayfaId, id));
    });
    final t = ref.watch(_provider);
    final dil = katalogDili(context);
    final turAdi =
        katalogAdi(t.turTanimi?.labels, dil) ?? t.tur ?? m.simdi_baslik;
    final varsayilan = _varsayilanBaslik(m, turAdi);
    final kilitli = t.gonderiliyor || t.sonuc != null;
    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: kilitli ? null : _kapat),
        title: Text(m.simdi_baslik),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TayfamSizes.okumaGenisligi,
          ),
          child: KatalogBekleyici(
            builder: (context, katalog) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._turBolumu(context, t, katalog),
                  BolumEtiketi(baslik: m.simdi_baslik_bolumu),
                  TextField(
                    controller: _baslik,
                    enabled: !kilitli,
                    maxLength: etkinlikBaslikEnCok,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _n.baslikAyarla,
                    decoration: InputDecoration(
                      labelText: m.simdi_baslik_etiketi,
                      helperText: m.simdi_baslik_ipucu(varsayilan),
                      helperMaxLines: 3,
                      errorText: t.hatalar.contains(TaslakHatasi.baslik)
                          ? m.etkinlik_baslik_hata
                          : null,
                    ),
                  ),
                  ..._alanBolumu(t),
                  ..._yerBolumu(context, t),
                  BilesenFormBolumleri(
                    tanim: t.turTanimi,
                    secimler: t.bilesenler,
                    tayfaId: widget.anahtar.tayfaId,
                    etkin: !kilitli,
                    yalnizcaAcKapa: true,
                    onAcKapa: (bilesen, acik) =>
                        _n.bilesenAcKapat(bilesen, acik: acik),
                    onSecim: (_, _, _) {},
                  ),
                  const SizedBox(height: TayfamSpacing.s20),
                  SihirbazBilgiKutusu(
                    metin: _haberMetni(m, t),
                    ikon: Icons.notifications_none,
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  SihirbazBilgiKutusu(
                    metin: m.simdi_sure_bilgisi,
                    ikon: Icons.schedule,
                  ),
                  if (t.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SihirbazAltCubugu(
        ileriEtiketi: t.gonderiliyor ? m.simdi_gonderiliyor : m.simdi_gonder,
        onIleri: kilitli
            ? null
            : () => unawaited(_n.gonder(varsayilanBaslik: varsayilan)),
      ),
    );
  }

  String _haberMetni(AppLocalizations m, EtkinlikTaslagi t) {
    if (widget.anahtar.tayfaId != null) return m.simdi_haber_tayfa;
    return t.davetliler.isEmpty ? m.simdi_haber_anlik : m.simdi_haber_davetli;
  }

  // --- Tür -------------------------------------------------------------------

  List<Widget> _turBolumu(
    BuildContext context,
    EtkinlikTaslagi t,
    Katalog katalog,
  ) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final kilitli = t.gonderiliyor || t.sonuc != null;
    // Genel, son kullanılanlar ve (listede yoksa) seçili tür; en çok
    // [simdiSonTurSayisi] son tür.
    final anahtarlar = <String>[
      simdiVarsayilanTur,
      ...ref.watch(sonSimdiTurleriProvider),
      ?t.tur,
    ];
    final turler = <CatalogEventType>[];
    for (final anahtar in anahtarlar) {
      final tur = katalog.tur(anahtar);
      if (tur == null ||
          tur.status != CatalogStatus.active ||
          turler.contains(tur)) {
        continue;
      }
      turler.add(tur);
    }
    return [
      BolumEtiketi(
        baslik: m.simdi_tur_baslik,
        sag: TextButton(
          onPressed: kilitli ? null : () => unawaited(_tumTurler()),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.simdi_tum_turler),
        ),
      ),
      if (turler.isNotEmpty)
        IkiSutunluIzgara(
          children: [
            for (final tur in turler)
              TurKutusu(
                gorunum: turTanimiGorunumu(tur, katalog, dil),
                secili: t.tur == tur.key,
                guncellemeGerekli: !alanlarTaniniyor(
                  tur.definition.fields ?? const <CatalogField>[],
                ),
                onSecildi: kilitli ? null : () => _n.turSec(tur),
              ),
          ],
        ),
      if (t.hatalar.contains(TaslakHatasi.tur)) ...[
        const SizedBox(height: TayfamSpacing.s8),
        HataSatiri(metin: m.etkinlik_tur_hata),
      ],
    ];
  }

  // --- Zorunlu alanlar ---------------------------------------------------------

  List<Widget> _alanBolumu(EtkinlikTaslagi t) {
    final alanlar = simdiAlanlari(t.turTanimi);
    if (alanlar.isEmpty) return const [];
    return [
      const SizedBox(height: TayfamSpacing.s8),
      KatalogAlanlari(
        key: ValueKey(t.tur),
        alanlar: alanlar,
        degerler: t.alanlar,
        hatalar: t.hatalar.contains(TaslakHatasi.alanlar)
            ? alanHatalari(alanlar, t.alanlar)
            : const {},
        onDegisti: t.gonderiliyor ? null : _n.alanlariAyarla,
      ),
    ];
  }

  // --- Yer -------------------------------------------------------------------

  List<Widget> _yerBolumu(BuildContext context, EtkinlikTaslagi t) {
    final m = AppLocalizations.of(context);
    final h = t.hatalar;
    final yer = t.yer;
    final cevrimici = yer.mod == EventMode.online;
    final kapali = t.gonderiliyor || t.sonuc != null;
    final modlar = turModlari(t.turTanimi);
    return [
      BolumEtiketi(baslik: m.simdi_yer_baslik),
      if (modlar.length > 1) ...[
        SecimCipleri<EventMode>(
          secenekler: [
            (EventMode.inPerson, m.etkinlik_mod_yuz_yuze),
            (EventMode.online, m.etkinlik_mod_cevrimici),
          ],
          secili: cevrimici ? EventMode.online : EventMode.inPerson,
          onSecildi: kapali ? null : (mod) => _yer((y) => y.kopya(mod: mod)),
        ),
        const SizedBox(height: TayfamSpacing.s12),
      ],
      if (cevrimici)
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
        )
      else ...[
        _NoktaSatiri(
          secildi: yer.nokta != null,
          onSec: kapali ? null : () => unawaited(_noktaSec()),
        ),
        if (h.contains(TaslakHatasi.nokta)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: m.etkinlik_nokta_hata),
        ],
        const SizedBox(height: TayfamSpacing.s12),
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
    ];
  }
}

/// Buluşma noktası satırı: seçilmemişse "Bulunduğum yeri seç" (harita
/// cihaz konumuyla açılır), seçilince "Nokta seçildi" ve "Değiştir".
class _NoktaSatiri extends StatelessWidget {
  const _NoktaSatiri({required this.secildi, required this.onSec});

  final bool secildi;
  final VoidCallback? onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
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
                    secildi ? Icons.check : Icons.place_outlined,
                    size: TayfamSizes.ikon,
                    color: r.tintMarkaUstu,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
                Flexible(
                  child: Text(
                    secildi
                        ? m.etkinlik_nokta_secildi
                        : m.etkinlik_nokta_secilmedi,
                    style: context.yazi.titleSmall,
                  ),
                ),
              ],
            ),
            CerceveliHapEylem(
              etiket: secildi ? m.etkinlik_nokta_degistir : m.simdi_nokta_sec,
              ikon: Icons.my_location,
              onPressed: onSec,
            ),
          ],
        ),
      ),
    );
  }
}
