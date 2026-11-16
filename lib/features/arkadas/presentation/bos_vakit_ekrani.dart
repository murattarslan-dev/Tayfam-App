import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/takvim_gunu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/arkadas/application/bos_vakit.dart';
import 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// "Boşum" ekranları (Tayfam-Api ADR-0029; tasarım 25-bosum). Gün takvim
// günüdür, saat değildir; "bugün" Europe/Istanbul tarihidir. Günler, dilimler
// ve not log'a yazılmaz (kesin kural 3).

/// Uygulamanın saatine göre Europe/Istanbul takviminde bugün.
DateTime _bugun(WidgetRef ref) => istanbulBugunu(ref.watch(simdiProvider)());

/// Dilimin metni.
String dilimMetni(AppLocalizations m, DaySlot dilim) => switch (dilim) {
  DaySlot.morning => m.bosum_dilim_sabah,
  DaySlot.afternoon => m.bosum_dilim_ogleden_sonra,
  DaySlot.evening => m.bosum_dilim_aksam,
  DaySlot.allDay => m.bosum_dilim_tum_gun,
  DaySlot.unknown => '',
};

/// Bir günün dilimleri sözleşme sırasıyla ("Sabah · Akşam").
String dilimlerMetni(AppLocalizations m, Iterable<DaySlot> dilimler) =>
    [for (final d in dilimleriSirala(dilimler)) dilimMetni(m, d)]
        .join(m.bosum_dilim_ayirici);

/// Gün satırının başlığı: "Bugün", "Yarın" ya da "21 Kasım Cumartesi".
String gunBasligi(AppLocalizations m, DateTime gun, DateTime bugun) {
  if (gun == bugun) return m.bosum_bugun;
  if (gun == gunKaydir(bugun, 1)) return m.bosum_yarin;
  return DateFormat.MMMMEEEEd(m.localeName).format(gun);
}

/// Rozetin metni: "Bugün boş", "Yarın boş" ya da "Cumartesi boş".
String rozetMetni(AppLocalizations m, DateTime gun, DateTime bugun) {
  if (gun == bugun) return m.bosum_rozet_bugun;
  if (gun == gunKaydir(bugun, 1)) return m.bosum_rozet_yarin;
  return m.bosum_rozet_gun(DateFormat.EEEE(m.localeName).format(gun));
}

/// Gün çipinin kısa metni: "Bugün", "Yarın" ya da "Sal 17".
String _gunCipiMetni(AppLocalizations m, DateTime gun, DateTime bugun) {
  if (gun == bugun) return m.bosum_bugun;
  if (gun == gunKaydir(bugun, 1)) return m.bosum_yarin;
  return DateFormat('E d', m.localeName).format(gun);
}

/// "Boş vaktin" giriş satırı (tasarım: Bosum-Arkadaslar): Arkadaşlar
/// ekranında ve profildeki Arkadaşlar kartında. Açıklama kendi gelecek
/// gün sayısıdır; okunana kadar ya da okunamazsa açıklama yoktur.
class BosVakitGirisi extends ConsumerWidget {
  const BosVakitGirisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final gunler = ref.watch(bosVakitlerimProvider).value;
    return MenuSatiri.kartta(
      ikon: Icons.event_available_outlined,
      baslik: m.bosum_baslik,
      aciklama: switch (gunler) {
        null => null,
        [] => m.bosum_giris_yok,
        final liste => m.bosum_giris_sayi(liste.length),
      },
      sag: const SatirOku(),
      onTap: () => unawaited(context.push(Adresler.bosVakit)),
    );
  }
}

/// Bir boş günün satırı (kendi listen ve arkadaşın günleri): solda tarih
/// kutusu, başlık gün, açıklama dilimler, varsa not. [onTap] `null` ise
/// satır düğme değildir ve ok gösterilmez.
class BosGunSatiri extends StatelessWidget {
  const BosGunSatiri({
    super.key,
    required this.gun,
    required this.tarih,
    required this.bugun,
    this.onTap,
  });

  final AvailabilityDay gun;

  /// [gun]'ün okunmuş tarihi.
  final DateTime tarih;
  final DateTime bugun;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final not = gun.note;
    return MenuSatiri.kartta(
      ikonKutusu: TarihKutusu(an: tarih),
      baslik: gunBasligi(m, tarih, bugun),
      aciklama: dilimlerMetni(m, gun.slots),
      altOge: not == null
          ? null
          : Text(
              m.bosum_not_alinti(not),
              style: context.yazi.bodySmall?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
      sag: onTap == null ? null : const SatirOku(),
      onTap: onTap,
    );
  }
}

/// Günleri [BosGunSatiri] olarak kart içinde gösterir.
class _GunKarti extends StatelessWidget {
  const _GunKarti({required this.gunler, required this.bugun, this.onTap});

  final List<AvailabilityDay> gunler;
  final DateTime bugun;
  final void Function(AvailabilityDay gun, DateTime tarih)? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return ListeKarti(
      children: [
        for (final g in gunler)
          if (takvimGunuOku(g.date) case final tarih?)
            BosGunSatiri(
              gun: g,
              tarih: tarih,
              bugun: bugun,
              onTap: onTap == null ? null : () => onTap(g, tarih),
            ),
      ],
    );
  }
}

/// Boş vaktin (`/profil/arkadaslar/bos-vakit`; tasarım: Bosum-Listem):
/// gizlilik açıklaması, "Boş gün ekle" ve kendi gelecek günlerin. Güne
/// dokununca düzenleme alttan sayfası açılır.
class BosVakitEkrani extends ConsumerWidget {
  const BosVakitEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(bosVakitlerimProvider);
    final bugun = _bugun(ref);
    return Scaffold(
      appBar: AppBar(title: Text(m.bosum_baslik)),
      body: TayfamYenile(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s4,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            Text(
              m.bosum_aciklama,
              style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: m.bosum_ekle,
              ikon: Icons.event_available_outlined,
              onPressed: () => unawaited(context.push(Adresler.bosGunEkle)),
            ),
            BolumEtiketi(baslik: m.bosum_onumuzdeki),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(bosVakitlerimProvider),
              icerik: (gunler) => gunler.isEmpty
                  ? BosMetin(m.bosum_liste_bos)
                  : _GunKarti(
                      gunler: gunler,
                      bugun: bugun,
                      onTap: (gun, tarih) => unawaited(
                        bosGunuDuzenle(context, gun: gun, tarih: tarih),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final onceVardi = ref.read(bosVakitlerimProvider).value != null;
    await ref.read(bosVakitlerimProvider.notifier).yenile();
    if (!context.mounted || !onceVardi) return;
    final hata = ref.read(bosVakitlerimProvider).error;
    if (hata == null) return;
    yenilemeHatasiBildir(
      context,
      hata,
      tekrarDene: () => unawaited(_yenile(context, ref)),
    );
  }
}

/// Dilim çipleri: dört dilim, "tüm gün" tek başına ([dilimDegistir]).
class _DilimCipleri extends StatelessWidget {
  const _DilimCipleri({required this.secili, required this.onDegisti});

  final Set<DaySlot> secili;
  final ValueChanged<Set<DaySlot>>? onDegisti;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final onDegisti = this.onDegisti;
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [
        for (final d in const [
          DaySlot.morning,
          DaySlot.afternoon,
          DaySlot.evening,
          DaySlot.allDay,
        ])
          _SecimCipi(
            etiket: dilimMetni(m, d),
            secili: secili.contains(d),
            onDegisti: onDegisti == null
                ? null
                : () => onDegisti(dilimDegistir(secili, d)),
          ),
      ],
    );
  }
}

/// Çok seçimli çip (tasarım: Bosum-Ekle): seçili marka zemin + marka üstü
/// metin ve onay işareti; seçili değilse giriş kenarlı. Devre dışıysa
/// ([onDegisti] `null`) çizgi kenarlı, ikincil metin; [ikon] verilirse
/// metnin solunda (ekli gün).
class _SecimCipi extends StatelessWidget {
  const _SecimCipi({
    required this.etiket,
    required this.secili,
    required this.onDegisti,
    this.semantikEtiketi,
    this.ikon,
  });

  final String etiket;
  final bool secili;
  final VoidCallback? onDegisti;
  final String? semantikEtiketi;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onDegisti = this.onDegisti;
    final ikon = this.ikon;
    final etkin = onDegisti != null;
    final yaziRengi = !etkin
        ? r.metinIkincil
        : secili
        ? r.markaUstu
        : r.metin;
    return FilterChip(
      label: Text(etiket, semanticsLabel: semantikEtiketi),
      avatar: ikon == null
          ? null
          : ExcludeSemantics(
              child: Icon(ikon, size: TayfamSizes.ikonKucuk, color: yaziRengi),
            ),
      selected: secili,
      onSelected: etkin ? (_) => onDegisti() : null,
      showCheckmark: true,
      checkmarkColor: r.markaUstu,
      selectedColor: r.marka,
      labelStyle: context.yazi.labelLarge?.copyWith(color: yaziRengi),
      side: secili
          ? BorderSide.none
          : BorderSide(
              color: etkin ? r.girisKenari : r.cizgi,
              width: TayfamSizes.kenar,
            ),
      shape: const StadiumBorder(),
    );
  }
}

/// Notu en çok [enCok] Unicode kod noktasında tutar (sunucu kod noktası
/// sayar; birleşik emoji tek görünse de birden çok sayılır).
final class _KodNoktasiSiniri extends TextInputFormatter {
  const _KodNoktasiSiniri(this.enCok);

  final int enCok;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.text.runes.length > enCok ? oldValue : newValue;
}

/// Not alanı: etiketli tek satır, kod noktası sayaçlı; yasak karakterler
/// (satır sonu, kontrol, yön ve görünmez karakterler) yazılırken süzülür.
class _NotAlani extends StatelessWidget {
  const _NotAlani({required this.denetleyici, required this.etkin});

  final TextEditingController denetleyici;
  final bool etkin;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: denetleyici,
      builder: (context, deger, _) => TextField(
        controller: denetleyici,
        enabled: etkin,
        maxLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.deny(bosNotYasakKarakter),
          const _KodNoktasiSiniri(bosNotEnCok),
        ],
        decoration: InputDecoration(
          labelText: m.bosum_not_etiketi,
          hintText: m.bosum_not_ipucu,
          counterText: m.bosum_not_sayac(deger.text.runes.length, bosNotEnCok),
        ),
      ),
    );
  }
}

/// Alan başlığı ("Ne zaman?").
class _AlanBasligi extends StatelessWidget {
  const _AlanBasligi(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(metin, style: context.yazi.titleSmall),
  );
}

/// Kuralın kısa açıklaması (çiplerin altında).
class _Aciklama extends StatelessWidget {
  const _Aciklama(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Text(
    metin,
    style: context.yazi.bodySmall?.copyWith(
      color: context.renkler.metinIkincil,
    ),
  );
}

/// Bir boş günü düzenleme alttan sayfası (tasarım: Bosum-Duzenle).
Future<void> bosGunuDuzenle(
  BuildContext context, {
  required AvailabilityDay gun,
  required DateTime tarih,
}) => altSayfaAc<void>(
  context,
  builder: (_) => _DuzenlemeSayfasi(gun: gun, tarih: tarih),
);

class _DuzenlemeSayfasi extends ConsumerStatefulWidget {
  const _DuzenlemeSayfasi({required this.gun, required this.tarih});

  final AvailabilityDay gun;
  final DateTime tarih;

  @override
  ConsumerState<_DuzenlemeSayfasi> createState() => _DuzenlemeSayfasiState();
}

class _DuzenlemeSayfasiState extends ConsumerState<_DuzenlemeSayfasi> {
  late Set<DaySlot> _dilimler = dilimleriSirala(widget.gun.slots).toSet();
  late final TextEditingController _not = TextEditingController(
    text: widget.gun.note ?? '',
  );
  bool _calisiyor = false;
  Object? _hata;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _calistir(
    Future<Object?> Function(BosVakitlerimNotifier n) islem,
  ) async {
    setState(() {
      _calisiyor = true;
      _hata = null;
    });
    final hata = await islem(ref.read(bosVakitlerimProvider.notifier));
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _calisiyor = false;
      _hata = hata;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final bugun = _bugun(ref);
    final hata = _hata;
    final etkin = !_calisiyor;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AltSayfaIcerigi(
        ust: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            0,
            TayfamSpacing.s8,
            TayfamSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  gunBasligi(m, widget.tarih, bugun),
                  style: context.yazi.headlineSmall,
                ),
              ),
              _Aciklama(m.bosum_duzenle_aciklama),
            ],
          ),
        ),
        children: [
          _AlanBasligi(m.bosum_dilim_baslik),
          const SizedBox(height: TayfamSpacing.s8),
          _DilimCipleri(
            secili: _dilimler,
            onDegisti: etkin ? (d) => setState(() => _dilimler = d) : null,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          _Aciklama(m.bosum_dilim_kural),
          const SizedBox(height: TayfamSpacing.s20),
          _NotAlani(denetleyici: _not, etkin: etkin),
          if (hata != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri.hatadan(hata),
          ],
          const SizedBox(height: TayfamSpacing.s16),
          BirincilEylem(
            etiket: m.bosum_kaydet,
            onPressed: etkin && _dilimler.isNotEmpty
                ? () => unawaited(
                    _calistir(
                      (n) => n.kaydet(widget.tarih, _dilimler, _not.text),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          YikiciEylem(
            etiket: m.bosum_sil,
            ikon: Icons.delete_outline,
            onPressed: etkin
                ? () => unawaited(_calistir((n) => n.sil(widget.tarih)))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Boş gün ekleme (`/profil/arkadaslar/bos-vakit/ekle`; tasarım:
/// Bosum-Ekle): önümüzdeki 31 günden (bugün + 30) çok seçim, dilimler ve
/// not; altta sabit "N günü kaydet". Zaten eklenmiş günler devre dışıdır
/// (listeden değiştirilir), böylece bir kayıt farkında olmadan üzerine
/// yazılmaz. Kaydetme her gün için ayrı `PUT`'tur; biri düşerse başarılı
/// günler seçimden çıkar, ekran açık kalır ve hata gösterilir.
class BosGunEkleEkrani extends ConsumerStatefulWidget {
  const BosGunEkleEkrani({super.key});

  @override
  ConsumerState<BosGunEkleEkrani> createState() => _BosGunEkleEkraniState();
}

class _BosGunEkleEkraniState extends ConsumerState<BosGunEkleEkrani> {
  final Set<DateTime> _gunler = {};
  Set<DaySlot> _dilimler = {};
  final TextEditingController _not = TextEditingController();
  bool _kaydediliyor = false;
  Object? _hata;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    final sonuc = await ref
        .read(bosVakitlerimProvider.notifier)
        .cokluKaydet(_gunler.toList(), _dilimler, _not.text);
    if (!mounted) return;
    if (sonuc.hata == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _kaydediliyor = false;
      _hata = sonuc.hata;
      _gunler
        ..clear()
        ..addAll(sonuc.kalan);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(bosVakitlerimProvider);
    final bugun = _bugun(ref);
    final hata = _hata;
    final hazir =
        !_kaydediliyor &&
        _gunler.isNotEmpty &&
        _dilimler.isNotEmpty &&
        durum.value != null;
    return Scaffold(
      appBar: AppBar(title: Text(m.bosum_ekle)),
      body: Column(
        children: [
          Expanded(
            child: ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(bosVakitlerimProvider),
              icerik: (mevcut) => _icerik(context, mevcut, bugun),
            ),
          ),
          if (hata != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
                vertical: TayfamSpacing.s8,
              ),
              child: HataSatiri.hatadan(hata),
            ),
          SihirbazAltCubugu(
            ileriEtiketi: _gunler.isEmpty
                ? m.bosum_kaydet
                : m.bosum_kaydet_sayi(_gunler.length),
            onIleri: hazir ? () => unawaited(_kaydet()) : null,
          ),
        ],
      ),
    );
  }

  Widget _icerik(
    BuildContext context,
    List<AvailabilityDay> mevcut,
    DateTime bugun,
  ) {
    final m = AppLocalizations.of(context);
    final ekli = {for (final g in mevcut) ?takvimGunuOku(g.date)};
    final etkin = !_kaydediliyor;
    // Bugünden bugün + 30'a kadar, aylara göre.
    final aylar = <DateTime, List<DateTime>>{};
    for (var i = 0; i <= bosGunEnCokIleri; i++) {
      final gun = gunKaydir(bugun, i);
      aylar.putIfAbsent(DateTime.utc(gun.year, gun.month), () => []).add(gun);
    }
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s24,
      ),
      children: [
        _AlanBasligi(m.bosum_gunler_baslik),
        const SizedBox(height: TayfamSpacing.s4),
        _Aciklama(m.bosum_gunler_aciklama),
        for (final MapEntry(key: ay, value: gunler) in aylar.entries) ...[
          const SizedBox(height: TayfamSpacing.s12),
          Text(
            DateFormat.MMMM(m.localeName).format(ay),
            style: context.yazi.labelLarge?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              for (final gun in gunler)
                if (ekli.contains(gun))
                  _SecimCipi(
                    etiket: _gunCipiMetni(m, gun, bugun),
                    semantikEtiketi: m.bosum_gun_ekli(
                      gunBasligi(m, gun, bugun),
                    ),
                    secili: false,
                    onDegisti: null,
                    ikon: Icons.event_available_outlined,
                  )
                else
                  _SecimCipi(
                    etiket: _gunCipiMetni(m, gun, bugun),
                    semantikEtiketi: gunBasligi(m, gun, bugun),
                    secili: _gunler.contains(gun),
                    onDegisti: etkin
                        ? () => setState(() {
                            if (!_gunler.remove(gun)) _gunler.add(gun);
                          })
                        : null,
                  ),
            ],
          ),
        ],
        const SizedBox(height: TayfamSpacing.s24),
        _AlanBasligi(m.bosum_dilim_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        _DilimCipleri(
          secili: _dilimler,
          onDegisti: etkin ? (d) => setState(() => _dilimler = d) : null,
        ),
        const SizedBox(height: TayfamSpacing.s8),
        _Aciklama(m.bosum_dilim_kural),
        const SizedBox(height: TayfamSpacing.s24),
        _NotAlani(denetleyici: _not, etkin: etkin),
      ],
    );
  }
}

/// Arkadaş satırındaki rozet (tasarım: Bosum-Arkadaslar): teal etiket
/// "Cumartesi boş"; satırın içinde ayrı düğmedir (en az 48 dp), dokununca
/// arkadaşın boş günleri açılır. Satırın geri kalanı kişi profilini açar.
class BosVakitRozeti extends StatelessWidget {
  const BosVakitRozeti({
    super.key,
    required this.arkadas,
    required this.gun,
    required this.bugun,
  });

  final Friend arkadas;
  final DateTime gun;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final metin = rozetMetni(m, gun, bugun);
    void ac() => unawaited(
      arkadasBosGunleriniAc(
        context,
        kullaniciId: arkadas.userId,
        ad: arkadas.displayName,
        avatarUploadId: arkadas.avatarUploadId,
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      // Ayrı düğüm: satırın düğmesine (kişi profili) birleşmez; ekran
      // okuyucuda rozet ayrı bir eylemdir.
      child: Semantics(
        container: true,
        button: true,
        label: m.bosum_rozet_semantik(arkadas.displayName, metin),
        onTap: ac,
        excludeSemantics: true,
        child: OdakCercevesi(
          koseler: TayfamRadii.hapKoseleri,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: ac,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TayfamSizes.dokunmaMin,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Etiket(
                    metin: metin,
                    ton: EtiketTonu.teal,
                    ikon: Icons.event_available_outlined,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arkadaşın boş günleri alttan sayfası (tasarım: Bosum-Arkadas-Gunleri):
/// 30 günün tamamı ve notlar, altta kişi profilindeki ek eylemler (ör.
/// "Mesaj gönder"). "Bir şey yapalım" anlık etkinlik işiyle eklenecek.
Future<void> arkadasBosGunleriniAc(
  BuildContext context, {
  required String kullaniciId,
  required String ad,
  String? avatarUploadId,
}) => altSayfaAc<void>(
  context,
  builder: (_) => _ArkadasGunleriSayfasi(
    kullaniciId: kullaniciId,
    ad: ad,
    avatarUploadId: avatarUploadId,
  ),
);

class _ArkadasGunleriSayfasi extends ConsumerWidget {
  const _ArkadasGunleriSayfasi({
    required this.kullaniciId,
    required this.ad,
    required this.avatarUploadId,
  });

  final String kullaniciId;
  final String ad;
  final String? avatarUploadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = arkadasBosGunleriProvider(kullaniciId);
    final durum = ref.watch(saglayici);
    final bugun = _bugun(ref);
    final deger = durum.value;
    final hata = durum.error;
    // Görünmüyor: arkadaş değil, engel, hesap yok; ayırt edilmez.
    final gorunmuyor =
        hata is ApiProblem && hata.type == ProblemType.userNotFound;
    final bilgi = KisiProfiliBilgisi(
      kullaniciId: kullaniciId,
      gorunenAd: ad,
      arkadas: true,
      ortakTayfaVar: false,
    );
    final eylemler = gorunmuyor
        ? const <Widget>[]
        : [
            for (final eylem in ref.watch(kisiProfiliEylemleriProvider))
              ?eylem(context, bilgi),
          ];
    final Widget icerik;
    if (gorunmuyor) {
      icerik = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.profil_goruntulenemiyor_baslik,
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.profil_goruntulenemiyor_aciklama,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ],
      );
    } else if (deger != null) {
      icerik = deger.isEmpty
          ? BosMetin(m.bosum_arkadas_bos)
          : _GunKarti(gunler: deger, bugun: bugun);
    } else if (hata != null) {
      icerik = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HataSatiri.hatadan(hata),
          const SizedBox(height: TayfamSpacing.s8),
          CerceveliHapEylem(
            etiket: m.yukleme_hatasi_tekrar_dene,
            ikon: Icons.refresh,
            onPressed: () => ref.invalidate(saglayici),
          ),
        ],
      );
    } else {
      icerik = Center(
        child: TayfamYukleniyor(etiket: m.bosum_yukleniyor, gecikmeli: true),
      );
    }
    return AltSayfaIcerigi(
      ust: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s8,
          0,
          TayfamSpacing.s8,
          TayfamSpacing.s12,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: KullaniciAvatari(ad: ad, avatarUploadId: avatarUploadId),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(ad, style: context.yazi.headlineSmall),
                  ),
                  _Aciklama(m.bosum_arkadas_alt),
                ],
              ),
            ),
          ],
        ),
      ),
      children: [
        icerik,
        for (final eylem in eylemler) ...[
          const SizedBox(height: TayfamSpacing.s16),
          eylem,
        ],
      ],
    );
  }
}
