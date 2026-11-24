import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_ortak.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_ortak.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Masa formu (alttan sayfa). [masa] yoksa masa açar: ad, oyun (bileşen
/// ön ayar sunuyorsa zorunlu), hedef puan ve yerler. [masa] varsa yalnızca
/// yerlerini (ilk elden önce) değiştirir. Yerler seçim sırasıyla gider;
/// kişi masasında etkinliğe "Geliyorum" diyenler, takım masasında takım
/// kurma bileşeninin takımları seçilir. Eşli oyunda (`side: pair`) tam 4
/// kişi seçilir; eşler seçim sırasından çıkar (koltuk 1 ve 3, 2 ve 4) ve
/// formda açıkça yazılır. Yerler sonra da verilebilir. Sunucu hatası formda
/// gösterilir, form açık kalır.
class YazbozMasaFormu extends ConsumerStatefulWidget {
  const YazbozMasaFormu({
    super.key,
    required this.kimlik,
    required this.yazboz,
    required this.takimAnahtarlari,
    this.misafirler,
    this.masa,
    this.gonder,
    this.yerleriGonder,
  });

  final YazbozKimligi kimlik;
  final EventScoreboard yazboz;

  /// Etkinliğin türündeki takım kurma bileşenleri; takım masası ilkini
  /// kullanır.
  final List<String> takimAnahtarlari;

  /// Bileşen misafir alıyorsa (`guests`) misafirlerin okunduğu ve eklendiği
  /// yer; değilse `null`. Misafir yalnızca kişi masasına oturur.
  final MisafirKimligi? misafirler;

  /// Yerleri değiştirilen masa; masa açarken `null`.
  final EventScoreTable? masa;

  /// Masa açma isteğini gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventScoreTableRequest istek)? gonder;

  /// Yerleri gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(List<EventScorePlayerInput> yerler)?
  yerleriGonder;

  @override
  ConsumerState<YazbozMasaFormu> createState() => _YazbozMasaFormuState();
}

class _YazbozMasaFormuState extends ConsumerState<YazbozMasaFormu> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _hedef = TextEditingController();

  /// Seçilen kişiler, misafirler ya da takımlar, seçim sırasıyla.
  final List<String> _secilenler = [];

  /// Seçimdeki misafirlerin kimlikleri (yer isteğinde `guest_id`).
  final Set<String> _misafirler = {};

  String? _onAyar;
  bool _adHazir = false;
  bool _adHatali = false;
  bool _hedefHatali = false;
  bool _onAyarYok = false;
  bool _sayiHatali = false;
  bool _mesgul = false;
  Object? _hata;

  bool get _duzenleme => widget.masa != null;

  @override
  void initState() {
    super.initState();
    final masa = widget.masa;
    if (masa == null) {
      final secilebilir = yazbozSecilebilirOnAyarlar(widget.yazboz);
      _onAyar = secilebilir.isEmpty ? null : secilebilir.first.key;
    } else {
      _onAyar = masa.presetKey;
      for (final yer in yazbozYerleri(masa)) {
        final misafir = yer.guestId;
        if (misafir != null) _misafirler.add(misafir);
        final kimlik = yer.userId ?? yer.teamId ?? misafir;
        if (kimlik != null && !_secilenler.contains(kimlik)) {
          _secilenler.add(kimlik);
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_duzenleme && !_adHazir) {
      _adHazir = true;
      _ad.text = AppLocalizations.of(context)
          .bilesen_scoreboard_ad_varsayilan(widget.yazboz.tables.length + 1);
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _hedef.dispose();
    super.dispose();
  }

  EventScorePreset? get _on => yazbozOnAyari(widget.yazboz, _onAyar);

  EventScoreRules get _kural =>
      widget.masa?.rules ?? yazbozMasaKurali(widget.yazboz, _on);

  bool get _takimMasasi => _kural.side == EventScoreRulesSide.team;

  bool get _esli => yazbozEsli(_kural);

  String? get _takimAnahtari => _duzenleme
      ? widget.masa?.teamsKey
      : (widget.takimAnahtarlari.isEmpty
            ? null
            : widget.takimAnahtarlari.first);

  void _degisti() => setState(() {
    _adHatali = false;
    _hedefHatali = false;
    _onAyarYok = false;
    _sayiHatali = false;
    _hata = null;
  });

  void _onAyarSec(String anahtar) {
    final eskiTakim = _takimMasasi;
    _onAyar = anahtar;
    if (_takimMasasi != eskiTakim) _secilenler.clear();
    _degisti();
  }

  void _misafirSec(String kimlik, bool secili) {
    _misafirler.add(kimlik);
    _sec(kimlik, secili);
  }

  void _sec(String kimlik, bool secili) {
    if (secili) {
      if (!_secilenler.contains(kimlik)) _secilenler.add(kimlik);
    } else {
      _secilenler.remove(kimlik);
    }
    _degisti();
  }

  List<EventScorePlayerInput> _yerler() => [
    for (final kimlik in _secilenler)
      if (_takimMasasi)
        EventScorePlayerInput(teamId: kimlik)
      else if (_misafirler.contains(kimlik))
        EventScorePlayerInput(guestId: kimlik)
      else
        EventScorePlayerInput(userId: kimlik),
  ];

  /// Seçilen yer sayısı ön ayarın sınırları içinde mi (boş: yerler sonra).
  bool _sayiUygun() {
    final adet = _secilenler.length;
    if (_esli) return yazbozEsliSayiUygun(adet);
    if (adet == 0) return true;
    if (adet > yazbozYerEnCok) return false;
    final on = _on;
    final enAz = on?.playersMin;
    final enCok = on?.playersMax;
    if (enAz != null && adet < enAz) return false;
    if (enCok != null && adet > enCok) return false;
    return true;
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    final ad = _ad.text.trim();
    final hedefMetni = _hedef.text.trim();
    final hedef = hedefMetni.isEmpty ? null : int.tryParse(hedefMetni);
    final secilebilir = yazbozSecilebilirOnAyarlar(widget.yazboz);
    final adHatali = !_duzenleme && (ad.isEmpty || ad.length > masaAdiEnCok);
    final hedefHatali =
        !_duzenleme &&
        hedefMetni.isNotEmpty &&
        (hedef == null || hedef < 1 || hedef > yazbozHedefEnCok);
    final onAyarYok = !_duzenleme && secilebilir.isNotEmpty && _on == null;
    final sayiHatali = !_sayiUygun();
    if (adHatali || hedefHatali || onAyarYok || sayiHatali) {
      setState(() {
        _adHatali = adHatali;
        _hedefHatali = hedefHatali;
        _onAyarYok = onAyarYok;
        _sayiHatali = sayiHatali;
      });
      return;
    }
    setState(() {
      _hata = null;
      _mesgul = true;
    });
    final yerler = _yerler();
    final Object? hata;
    if (_duzenleme) {
      hata = await widget.yerleriGonder?.call(yerler);
    } else {
      hata = await widget.gonder?.call(
        EventScoreTableRequest(
          label: ad,
          presetKey: secilebilir.isEmpty ? null : _onAyar,
          target: hedef,
          teamsKey: _takimMasasi ? _takimAnahtari : null,
          players: yerler.isEmpty ? null : yerler,
        ),
      );
    }
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
    final dil = katalogDili(context);
    final secilebilir = yazbozSecilebilirOnAyarlar(widget.yazboz);
    final on = _on;
    final kural = _kural;
    final hata = _hata;
    final esli = _esli;
    final enAz = esli ? null : on?.playersMin;
    final enCok = esli ? null : on?.playersMax;
    final ozet = yazbozKuralOzeti(m, kural).join(' · ');
    return AracFormSayfasi(
      baslik: _duzenleme
          ? m.bilesen_scoreboard_yerler
          : m.bilesen_scoreboard_masa_ac,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        if (!_duzenleme) ...[
          TextField(
            key: const ValueKey('yazboz-masa-adi'),
            controller: _ad,
            enabled: !_mesgul,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(masaAdiEnCok)],
            onChanged: (_) => _degisti(),
            decoration: InputDecoration(
              labelText: m.bilesen_scoreboard_ad_alani,
              errorText: _adHatali ? m.bilesen_scoreboard_ad_hatali : null,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          if (secilebilir.isNotEmpty) ...[
            BolumEtiketi(baslik: m.bilesen_scoreboard_oyun),
            SecimCipleri<String>(
              secenekler: [
                for (final o in secilebilir)
                  (o.key, katalogAdi(o.labels, dil) ?? o.key),
              ],
              secili: _onAyar,
              onSecildi: _mesgul ? null : _onAyarSec,
            ),
            if (_onAyarYok) HataSatiri(metin: m.bilesen_scoreboard_oyun_sec),
            const SizedBox(height: TayfamSpacing.s8),
          ],
          if (ozet.isNotEmpty) AracBilgisi(metin: ozet),
          if (kural.rounds == EventScoreRulesRounds.firstTo ||
              kural.target != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            TextField(
              key: const ValueKey('yazboz-hedef'),
              controller: _hedef,
              enabled: !_mesgul,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (_) => _degisti(),
              decoration: InputDecoration(
                labelText: m.bilesen_scoreboard_hedef_alani,
                helperText: m.bilesen_scoreboard_hedef_ipucu,
                errorText: _hedefHatali
                    ? m.bilesen_scoreboard_hedef_hatali
                    : null,
              ),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s16),
        ],
        Text(
          _takimMasasi
              ? m.bilesen_scoreboard_takimlar
              : m.bilesen_scoreboard_oyuncular,
          style: context.yazi.titleSmall,
        ),
        AracBilgisi(
          metin: esli
              ? m.bilesen_scoreboard_esli_aciklama
              : m.bilesen_scoreboard_yer_aciklama,
        ),
        if (esli) const _EsKoltuklari(),
        if (enAz != null && enCok != null)
          AracBilgisi(metin: m.bilesen_scoreboard_yer_siniri(enAz, enCok)),
        if (_sayiHatali)
          HataSatiri(
            metin: esli
                ? m.bilesen_scoreboard_esli_sayi
                : enAz != null && enCok != null
                ? m.bilesen_scoreboard_yer_siniri(enAz, enCok)
                : m.bilesen_scoreboard_yer_cok(yazbozYerEnCok),
          ),
        const SizedBox(height: TayfamSpacing.s8),
        if (_takimMasasi)
          _TakimSecimi(
            kimlik: _takimKimligi(),
            secilenler: _secilenler,
            onSecildi: _mesgul ? null : _sec,
          )
        else
          _KisiSecimi(
            anahtar: yazbozKatilimcilari(widget.kimlik),
            ekler: [
              for (final yer in widget.masa?.players ?? <EventScorePlayer>[])
                ?yer.userId,
            ],
            secilenler: _secilenler,
            esli: esli,
            onSecildi: _mesgul ? null : _sec,
          ),
        if (!_takimMasasi)
          if (widget.misafirler case final misafirler?)
            _MisafirSecimi(
              kimlik: misafirler,
              masaId: widget.masa?.id,
              secilenler: _secilenler,
              esli: esli,
              onSecildi: _mesgul ? null : _misafirSec,
              onSilindi: (id) {
                if (_secilenler.remove(id)) _degisti();
              },
            ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }

  TakimKimligi? _takimKimligi() {
    final anahtar = _takimAnahtari;
    if (anahtar == null) return null;
    return (
      tayfaId: widget.kimlik.tayfaId,
      etkinlikId: widget.kimlik.etkinlikId,
      anahtar: anahtar,
    );
  }
}

/// Eşli oyunda eşlerin koltukları: "1. eş: 1. ve 3. koltuk", "2. eş: 2. ve
/// 4. koltuk".
class _EsKoltuklari extends StatelessWidget {
  const _EsKoltuklari();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final es in const [1, 2])
            Text(
              m.bilesen_scoreboard_es_koltuklari(
                es,
                yazbozEsKoltuklari(es).$1,
                yazbozEsKoltuklari(es).$2,
              ),
              style: context.yazi.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Seçimdeki bir satır: onay kutusu, ad ve seçildiyse yerin sırası (eşli
/// oyunda koltuk ve eş: "3. koltuk · 1. eş").
class _YerSatiri extends StatelessWidget {
  const _YerSatiri({
    super.key,
    required this.ad,
    required this.sira,
    required this.onSecildi,
    this.esli = false,
    this.sag,
  });

  final Widget ad;

  /// Satırın sonundaki isteğe bağlı düğme (misafiri silme).
  final Widget? sag;

  /// Seçildiyse 1'den sıra; değilse `null`.
  final int? sira;

  /// Eşli oyun: sıra koltuktur, eşi de yazılır.
  final bool esli;

  final ValueChanged<bool>? onSecildi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final onSecildi = this.onSecildi;
    final sira = this.sira;
    return CheckboxListTile(
      value: sira != null,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: onSecildi == null
          ? null
          : (deger) => onSecildi(deger ?? false),
      title: ad,
      subtitle: sira == null
          ? null
          : Text(
              esli && sira <= yazbozEsliYer
                  ? m.bilesen_scoreboard_koltuk_es(sira, yazbozEsNo(sira))
                  : m.bilesen_scoreboard_yer_no(sira),
            ),
      secondary: sag,
    );
  }
}

/// Kişi masasında yer seçimi: "Geliyorum" diyenler (ilk sayfa ve "Daha
/// fazla") ve [ekler] (masada zaten olanlar).
class _KisiSecimi extends ConsumerWidget {
  const _KisiSecimi({
    required this.anahtar,
    required this.ekler,
    required this.secilenler,
    required this.esli,
    required this.onSecildi,
  });

  final KatilimcilarAnahtari anahtar;
  final List<String> ekler;
  final List<String> secilenler;
  final bool esli;
  final void Function(String kimlik, bool secili)? onSecildi;

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
    final kisiler = <String>[
      ...{...ekler, ...liste.ogeler.map((k) => k.userId)},
    ];
    if (kisiler.isEmpty) {
      return AracBilgisi(metin: m.bilesen_scoreboard_gelen_yok);
    }
    final onSecildi = this.onSecildi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kisi in kisiler)
          _YerSatiri(
            key: ValueKey('yazboz-kisi-$kisi'),
            ad: KullaniciAdiMetni(kullaniciId: kisi),
            esli: esli,
            sira: secilenler.contains(kisi)
                ? secilenler.indexOf(kisi) + 1
                : null,
            onSecildi: onSecildi == null
                ? null
                : (secili) => onSecildi(kisi, secili),
          ),
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

/// Kişi masasında misafir seçimi (ADR-0031 §4): katılımcıların altında
/// etkinliğin misafirleri ("Misafir" etiketli, profil bağlantısız),
/// yetkiliye "Misafir ekle" ve misafiri silme. Eklenen misafir seçime
/// sonda girer. Yetki sunucudadır; düğmeler yalnızca sadeleştirir.
class _MisafirSecimi extends ConsumerStatefulWidget {
  const _MisafirSecimi({
    required this.kimlik,
    required this.masaId,
    required this.secilenler,
    required this.esli,
    required this.onSecildi,
    required this.onSilindi,
  });

  final MisafirKimligi kimlik;

  /// Yerleri değiştirilen masa: masanın hakemi misafiri bununla ekler.
  final String? masaId;
  final List<String> secilenler;
  final bool esli;
  final void Function(String kimlik, bool secili)? onSecildi;

  /// Silinen misafir seçimden çıkar.
  final ValueChanged<String> onSilindi;

  @override
  ConsumerState<_MisafirSecimi> createState() => _MisafirSecimiState();
}

class _MisafirSecimiState extends ConsumerState<_MisafirSecimi> {
  bool _mesgul = false;

  MisafirNotifier get _notifier =>
      ref.read(misafirProvider(widget.kimlik).notifier);

  Future<void> _ekle(EventGuestPlayers liste) async {
    final once = {for (final g in liste.guests) g.id};
    final masaId = liste.callerCanAdd ? null : widget.masaId;
    await aracFormuAc<void>(
      context,
      (_) => MisafirFormu(gonder: (ad) => _notifier.ekle(ad, masaId: masaId)),
    );
    if (!mounted) return;
    final yeni = ref.read(misafirProvider(widget.kimlik)).value;
    for (final g in yeni?.guests ?? const <EventGuestPlayer>[]) {
      if (!once.contains(g.id)) widget.onSecildi?.call(g.id, true);
    }
  }

  Future<void> _sil(EventGuestPlayer misafir) async {
    if (_mesgul) return;
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_guest_sil_onay,
      metin: m.bilesen_guest_sil_aciklama,
      eylem: m.bilesen_guest_sil,
    );
    if (!onay || !mounted) return;
    setState(() => _mesgul = true);
    final hata = await _notifier.sil(misafir.id);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) {
      hataBildir(context, hata);
    } else {
      widget.onSilindi(misafir.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(misafirProvider(widget.kimlik));
    final liste = durum.value;
    final onSecildi = widget.onSecildi;
    final baslik = Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s16),
      child: Semantics(
        header: true,
        child: Text(m.bilesen_guest_baslik, style: context.yazi.titleSmall),
      ),
    );
    if (liste == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          if (durum.hasError) ...[
            HataSatiri.hatadan(durum.error!),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BaglantiEylemi(
                etiket: m.etkinlik_tekrar_dene,
                onPressed: () => unawaited(_notifier.yenile()),
              ),
            ),
          ] else
            const Center(child: TayfamYukleniyor(gecikmeli: true)),
        ],
      );
    }
    final dolu = liste.guests.length >= liste.maxGuests;
    final ekleyebilir = liste.callerCanAdd || widget.masaId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracBilgisi(
          metin: m.bilesen_guest_sayi(liste.guests.length, liste.maxGuests),
        ),
        for (final g in liste.guests)
          _YerSatiri(
            key: ValueKey('yazboz-misafir-${g.id}'),
            ad: MisafirAdi(kimlik: widget.kimlik, misafirId: g.id),
            esli: widget.esli,
            sira: widget.secilenler.contains(g.id)
                ? widget.secilenler.indexOf(g.id) + 1
                : null,
            onSecildi: onSecildi == null
                ? null
                : (secili) => onSecildi(g.id, secili),
            sag: liste.callerCanRemove
                ? AracIkonDugmesi(
                    key: ValueKey('yazboz-misafir-sil-${g.id}'),
                    ipucu: m.bilesen_guest_sil,
                    ikon: Icons.delete_outline,
                    onPressed: _mesgul || onSecildi == null
                        ? null
                        : () => unawaited(_sil(g)),
                  )
                : null,
          ),
        if (ekleyebilir && dolu)
          AracBilgisi(metin: m.bilesen_guest_dolu(liste.maxGuests))
        else if (ekleyebilir)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('yazboz-misafir-ekle'),
              onPressed: _mesgul || onSecildi == null
                  ? null
                  : () => unawaited(_ekle(liste)),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: Text(m.bilesen_guest_ekle),
            ),
          ),
      ],
    );
  }
}

/// Takım masasında yer seçimi: takım kurma bileşeninin takımları.
class _TakimSecimi extends ConsumerWidget {
  const _TakimSecimi({
    required this.kimlik,
    required this.secilenler,
    required this.onSecildi,
  });

  /// Takım kurma bileşeni; etkinlikte yoksa `null`.
  final TakimKimligi? kimlik;
  final List<String> secilenler;
  final void Function(String kimlik, bool secili)? onSecildi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final kimlik = this.kimlik;
    if (kimlik == null) {
      return AracBilgisi(metin: m.bilesen_scoreboard_takim_bileseni_yok);
    }
    final durum = ref.watch(takimProvider(kimlik));
    final takimlar = durum.value;
    if (takimlar == null) {
      if (durum.hasError) return HataSatiri.hatadan(durum.error!);
      return const Center(child: TayfamYukleniyor(gecikmeli: true));
    }
    final sirali = [...takimlar.teams]
      ..sort((a, b) => a.position.compareTo(b.position));
    if (sirali.isEmpty) {
      return AracBilgisi(metin: m.bilesen_scoreboard_takimsiz);
    }
    final onSecildi = this.onSecildi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final takim in sirali)
          _YerSatiri(
            key: ValueKey('yazboz-takim-${takim.id}'),
            ad: Text(takimEtiketi(m, takim.position, takim.name)),
            sira: secilenler.contains(takim.id)
                ? secilenler.indexOf(takim.id) + 1
                : null,
            onSecildi: onSecildi == null
                ? null
                : (secili) => onSecildi(takim.id, secili),
          ),
      ],
    );
  }
}

/// El formu (alttan sayfa): masanın her yeri için puan (sayı klavyesi,
/// eksi olabilir) ya da sonuç (galibiyet, beraberlik, mağlubiyet). Boş
/// bırakılan yer o elde skorsuzdur. Eşli masada her eş için tek alan
/// vardır ("1. eş: Ayşe & Mehmet"); skor eşin ilk koltuğuyla gider, sunucu
/// eşin iki koltuğuna da yazar. [duzeltilen] verilirse son el düzeltilir ve
/// alanlar onun skorlarıyla dolar.
class YazbozElFormu extends StatefulWidget {
  const YazbozElFormu({
    super.key,
    required this.kimlik,
    required this.masa,
    required this.el,
    required this.gonder,
    this.duzeltilen,
    this.misafirler,
  });

  final YazbozKimligi kimlik;
  final EventScoreTable masa;

  /// Bileşen misafir alıyorsa misafirlerin okunduğu yer; değilse `null`.
  final MisafirKimligi? misafirler;

  /// Elin numarası.
  final int el;

  final EventScoreRound? duzeltilen;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventScoreRoundRequest istek) gonder;

  @override
  State<YazbozElFormu> createState() => _YazbozElFormuState();
}

class _YazbozElFormuState extends State<YazbozElFormu> {
  final Map<String, TextEditingController> _puanlar = {};
  final Map<String, EventScoreEntryOutcome> _sonuclar = {};
  Set<String> _hatalilar = const {};
  bool _bos = false;
  bool _mesgul = false;
  Object? _hata;

  bool get _sonucModu => widget.masa.rules.result == EventScoreRulesResult.wdl;

  List<EventScorePlayer> get _yerler => yazbozYerleri(widget.masa);

  bool get _esli => yazbozEsli(widget.masa.rules);

  List<YazbozEsi> get _esler => yazbozEsleri(widget.masa);

  /// Skor girilen kimlikler sırasıyla: yerler ya da eşli masada eşlerin
  /// ilk koltukları.
  List<String> get _sira => _esli
      ? [for (final es in _esler) yazbozTemsilci(es)]
      : [for (final yer in _yerler) yer.id];

  @override
  void initState() {
    super.initState();
    final onceki = {
      for (final s in widget.duzeltilen?.scores ?? <EventScoreEntry>[])
        s.playerId: s,
    };
    if (_esli) {
      for (final es in _esler) {
        EventScoreEntry? skor;
        for (final yer in es.yerler) {
          skor ??= onceki[yer.id];
        }
        _doldur(yazbozTemsilci(es), skor);
      }
    } else {
      for (final yer in _yerler) {
        _doldur(yer.id, onceki[yer.id]);
      }
    }
  }

  /// [kimlik]in alanını düzeltilen elin [skor]uyla doldurur.
  void _doldur(String kimlik, EventScoreEntry? skor) {
    _puanlar[kimlik] = TextEditingController(
      text: skor?.points?.toString() ?? '',
    );
    final sonuc = skor?.outcome;
    if (sonuc != null && sonuc != EventScoreEntryOutcome.unknown) {
      _sonuclar[kimlik] = sonuc;
    }
  }

  @override
  void dispose() {
    for (final c in _puanlar.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _degisti() => setState(() {
    _hatalilar = const {};
    _bos = false;
    _hata = null;
  });

  Future<void> _kaydet() async {
    if (_mesgul) return;
    final sira = _sira;
    final sonuc = _sonucModu
        ? yazbozSonucIstegi(sira, _sonuclar)
        : yazbozPuanIstegi(sira, {
            for (final MapEntry(key: yer, value: c) in _puanlar.entries)
              yer: c.text,
          });
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() {
        _hatalilar = sonuc.hatali;
        _bos = sonuc.hatali.isEmpty;
      });
      return;
    }
    setState(() {
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
    final hata = _hata;
    final takimlar = widget.masa.teamsKey;
    final esli = _esli;
    final adStili = context.yazi.bodyLarge;
    final girisler = <(String, Widget)>[
      if (esli)
        for (final es in _esler)
          (
            yazbozTemsilci(es),
            YazbozEsAdi(
              es: es,
              misafirler: widget.misafirler,
              numarali: true,
              style: adStili,
            ),
          )
      else
        for (final yer in _yerler)
          (
            yer.id,
            YazbozYerAdi(
              yer: yer,
              takimlar: takimlar == null
                  ? null
                  : (
                      tayfaId: widget.kimlik.tayfaId,
                      etkinlikId: widget.kimlik.etkinlikId,
                      anahtar: takimlar,
                    ),
              misafirler: widget.misafirler,
              style: adStili,
            ),
          ),
    ];
    return AracFormSayfasi(
      baslik: widget.duzeltilen == null
          ? m.bilesen_scoreboard_el_baslik(widget.el)
          : m.bilesen_scoreboard_duzelt_baslik(widget.el),
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        AracBilgisi(
          metin: switch ((_sonucModu, esli)) {
            (true, true) => m.bilesen_scoreboard_esli_sonuc_aciklama,
            (true, false) => m.bilesen_scoreboard_sonuc_aciklama,
            (false, true) => m.bilesen_scoreboard_esli_puan_aciklama,
            (false, false) => m.bilesen_scoreboard_puan_aciklama,
          },
        ),
        const SizedBox(height: TayfamSpacing.s8),
        for (final (id, ad) in girisler)
          Padding(
            key: ValueKey('yazboz-el-yer-$id'),
            padding: const EdgeInsets.only(bottom: TayfamSpacing.s8),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ad,
                  if (_sonucModu)
                    _SonucSecimi(
                      secili: _sonuclar[id],
                      onSecildi: _mesgul
                          ? null
                          : (sonuc) {
                              if (sonuc == null) {
                                _sonuclar.remove(id);
                              } else {
                                _sonuclar[id] = sonuc;
                              }
                              _degisti();
                            },
                    )
                  else
                    TextField(
                      key: ValueKey('yazboz-puan-$id'),
                      controller: _puanlar[id],
                      enabled: !_mesgul,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onChanged: (_) => _degisti(),
                      decoration: InputDecoration(
                        labelText: m.bilesen_scoreboard_puan_alani,
                        errorText: _hatalilar.contains(id)
                            ? m.bilesen_scoreboard_puan_hatali
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_bos)
          HataSatiri(
            metin: _sonucModu
                ? m.bilesen_scoreboard_sonuc_yok
                : m.bilesen_scoreboard_puan_yok,
          ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// Bir yerin el sonucu: yok, galibiyet, beraberlik, mağlubiyet.
class _SonucSecimi extends StatelessWidget {
  const _SonucSecimi({required this.secili, required this.onSecildi});

  final EventScoreEntryOutcome? secili;
  final ValueChanged<EventScoreEntryOutcome?>? onSecildi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final onSecildi = this.onSecildi;
    return Semantics(
      label: m.bilesen_scoreboard_sonuc_alani,
      child: DropdownButton<EventScoreEntryOutcome?>(
        isExpanded: true,
        value: secili,
        onChanged: onSecildi,
        items: [
          DropdownMenuItem<EventScoreEntryOutcome?>(
            child: Text(m.bilesen_scoreboard_sonuc_bos),
          ),
          for (final sonuc in const [
            EventScoreEntryOutcome.win,
            EventScoreEntryOutcome.draw,
            EventScoreEntryOutcome.loss,
          ])
            DropdownMenuItem<EventScoreEntryOutcome?>(
              value: sonuc,
              child: Text(yazbozSonucAdi(m, sonuc) ?? ''),
            ),
        ],
      ),
    );
  }
}

/// Masanın adını değiştirme formu (alttan sayfa).
class YazbozAdFormu extends StatefulWidget {
  const YazbozAdFormu({super.key, required this.ad, required this.gonder});

  final String ad;

  /// Yeni adı gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(String ad) gonder;

  @override
  State<YazbozAdFormu> createState() => _YazbozAdFormuState();
}

class _YazbozAdFormuState extends State<YazbozAdFormu> {
  late final TextEditingController _ad = TextEditingController(text: widget.ad);
  bool _hatali = false;
  bool _mesgul = false;
  Object? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    final ad = _ad.text.trim();
    if (ad.isEmpty || ad.length > masaAdiEnCok) {
      setState(() => _hatali = true);
      return;
    }
    setState(() {
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(ad);
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
    final hata = _hata;
    return AracFormSayfasi(
      baslik: m.bilesen_scoreboard_adlandir,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        TextField(
          key: const ValueKey('yazboz-yeni-ad'),
          controller: _ad,
          enabled: !_mesgul,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(masaAdiEnCok)],
          onChanged: (_) => setState(() {
            _hatali = false;
            _hata = null;
          }),
          decoration: InputDecoration(
            labelText: m.bilesen_scoreboard_ad_alani,
            errorText: _hatali ? m.bilesen_scoreboard_ad_hatali : null,
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

/// Masanın hakemleri (alttan sayfa): bu masaya atanmış hakemler (kaldırma
/// düğmesiyle) ve "Geliyorum" diyenlerden hakem atama. Hakem masada el
/// girer ve masayı bitirebilir; bileşenin ya da etkinliğin tamamının
/// hakemleri de girebilir (onlar burada listelenmez). Yetki sunucudadır.
class YazbozHakemFormu extends ConsumerStatefulWidget {
  const YazbozHakemFormu({super.key, required this.kimlik, required this.masa});

  final YazbozKimligi kimlik;
  final EventScoreTable masa;

  @override
  ConsumerState<YazbozHakemFormu> createState() => _YazbozHakemFormuState();
}

class _YazbozHakemFormuState extends ConsumerState<YazbozHakemFormu> {
  String? _secilen;
  bool _mesgul = false;
  Object? _hata;

  ({String tayfaId, String etkinlikId}) get _etkinlik =>
      (tayfaId: widget.kimlik.tayfaId, etkinlikId: widget.kimlik.etkinlikId);

  Future<void> _calistir(Future<void> Function(EtkinlikDeposu d) islem) async {
    if (_mesgul) return;
    setState(() {
      _hata = null;
      _mesgul = true;
    });
    Object? hata;
    try {
      await islem(ref.read(etkinlikDeposuProvider));
    } on Exception catch (e) {
      hata = e;
    }
    if (!mounted) return;
    ref.invalidate(etkinlikHakemleriProvider(_etkinlik));
    setState(() {
      _mesgul = false;
      _hata = hata;
      if (hata == null) _secilen = null;
    });
  }

  Future<void> _ata() async {
    final kisi = _secilen;
    if (kisi == null) return;
    await _calistir(
      (d) => d.hakemAta(
        widget.kimlik.tayfaId,
        widget.kimlik.etkinlikId,
        EventRefereeAssignRequest(
          userId: kisi,
          componentKey: widget.kimlik.anahtar,
          scopeId: widget.masa.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hakemler = [
      for (final h
          in ref.watch(etkinlikHakemleriProvider(_etkinlik)).value ??
              const <EventReferee>[])
        if (h.componentKey == widget.kimlik.anahtar &&
            h.scopeId == widget.masa.id)
          h,
    ];
    final atanmis = {for (final h in hakemler) h.userId};
    final anahtar = yazbozKatilimcilari(widget.kimlik);
    final gelenler = [
      for (final k
          in ref.watch(katilimcilarProvider(anahtar)).value?.ogeler ??
              const <Attendee>[])
        if (!atanmis.contains(k.userId)) k.userId,
    ];
    final secilen = gelenler.contains(_secilen) ? _secilen : null;
    final hata = _hata;
    return AracFormSayfasi(
      baslik: m.bilesen_scoreboard_hakemler_baslik(widget.masa.label),
      onayEtiketi: m.bilesen_scoreboard_hakem_ata,
      onOnay: _mesgul || secilen == null ? null : () => unawaited(_ata()),
      alanlar: [
        AracBilgisi(metin: m.bilesen_scoreboard_hakem_aciklama),
        const SizedBox(height: TayfamSpacing.s8),
        if (hakemler.isEmpty)
          AracBilgisi(metin: m.bilesen_scoreboard_hakem_yok)
        else
          for (final h in hakemler)
            Row(
              key: ValueKey('yazboz-hakem-${h.id}'),
              children: [
                Expanded(child: KullaniciAdiMetni(kullaniciId: h.userId)),
                AracIkonDugmesi(
                  ipucu: m.bilesen_scoreboard_hakem_kaldir,
                  ikon: Icons.remove_circle_outline,
                  onPressed: _mesgul
                      ? null
                      : () => unawaited(
                          _calistir(
                            (d) => d.hakemKaldir(
                              widget.kimlik.tayfaId,
                              widget.kimlik.etkinlikId,
                              h.id,
                            ),
                          ),
                        ),
                ),
              ],
            ),
        const SizedBox(height: TayfamSpacing.s16),
        if (gelenler.isEmpty)
          AracBilgisi(metin: m.bilesen_scoreboard_gelen_yok)
        else
          Semantics(
            label: m.bilesen_scoreboard_hakem_sec,
            child: DropdownButton<String>(
              key: const ValueKey('yazboz-hakem-secimi'),
              isExpanded: true,
              value: secilen,
              hint: Text(m.bilesen_scoreboard_hakem_sec),
              onChanged: _mesgul
                  ? null
                  : (kisi) => setState(() {
                      _secilen = kisi;
                      _hata = null;
                    }),
              items: [
                for (final kisi in gelenler)
                  DropdownMenuItem<String>(
                    value: kisi,
                    child: KullaniciAdiMetni(kullaniciId: kisi, maxLines: 1),
                  ),
              ],
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
