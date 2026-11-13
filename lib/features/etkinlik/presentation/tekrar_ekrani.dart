import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tekrar ekranının sonucu: "Tamam"la seçilen tekrar (`null`: tek
/// seferlik).
typedef TekrarSonucu = ({TekrarSecimi? secim});

/// Tekrar ekranını açar; "Tamam"da seçim, vazgeçilirse `null` döner.
Future<TekrarSonucu?> tekrarEkraniniAc(
  BuildContext context, {
  required TekrarSecimi? secim,
  required DateTime baslangic,
}) => Navigator.of(context).push(
  MaterialPageRoute<TekrarSonucu>(
    builder: (_) => TekrarEkrani(secim: secim, baslangic: baslangic),
  ),
);

/// Tekrar ekranı (2026-11-13 tasarım: Sihirbaz-Tekrar, Sihirbaz-Tekrar-
/// Tarih): sıklık (Tek seferlik / Her hafta / Her ay), aralık, "Ne zaman
/// bitsin?" (Bitiş yok / Belirli sayıda / Belirli bir günde) ve seçimi düz
/// Türkçe özetleyen kutu ([tekrarOzeti]; RRULE'un açacağı etkinlikler
/// istemcide hesaplanır).
///
/// Seçim yalnızca bu ekranda tutulur; "Tamam" geçerliyse sihirbaza döner,
/// "Geri" ya da sistem geri tuşu değişikliği bırakır. Sınırlar sözleşmeyle
/// aynıdır (aralık 1–52, sayı 1–500, son gün en çok beş yıl).
class TekrarEkrani extends ConsumerStatefulWidget {
  const TekrarEkrani({super.key, required this.secim, required this.baslangic});

  /// Sihirbazdaki seçim; `null` tek seferlik.
  final TekrarSecimi? secim;

  /// Etkinliğin başlangıcı (UTC).
  final DateTime baslangic;

  @override
  ConsumerState<TekrarEkrani> createState() => _TekrarEkraniState();
}

class _TekrarEkraniState extends ConsumerState<TekrarEkrani> {
  /// Sıklık; `null` tek seferlik.
  late TekrarSikligi? _siklik = widget.secim?.siklik;

  /// Aralık, bitiş, sayı ve son gün; tek seferlik seçilse de korunur.
  late TekrarSecimi _ayar = widget.secim ?? const TekrarSecimi();

  late final TextEditingController _aralik = TextEditingController(
    text: '${_ayar.aralik}',
  );
  late final TextEditingController _sayi = TextEditingController(
    text: '${_ayar.sayi}',
  );

  /// "Tamam"a basıldı mı (hatalar o zamandan sonra gösterilir).
  bool _denendi = false;

  @override
  void dispose() {
    _aralik.dispose();
    _sayi.dispose();
    super.dispose();
  }

  TekrarSecimi? get _secim {
    final siklik = _siklik;
    return siklik == null ? null : _ayar.degistir(siklik: siklik);
  }

  void _ayarla(TekrarSecimi yeni) => setState(() => _ayar = yeni);

  Future<void> _sonGunSec() async {
    final simdi = ref.read(etkinlikSaatiProvider)().toLocal();
    final ilkGun = DateTime(simdi.year, simdi.month, simdi.day);
    final mevcut = _ayar.sonGun;
    final gun = await showDatePicker(
      context: context,
      initialDate: mevcut == null
          ? ilkGun
          : DateTime(mevcut.year, mevcut.month, mevcut.day),
      firstDate: ilkGun,
      lastDate: DateTime(ilkGun.year + 5, ilkGun.month, ilkGun.day),
    );
    if (gun == null || !mounted) return;
    _ayarla(
      _ayar.degistir(sonGun: DateTime.utc(gun.year, gun.month, gun.day)),
    );
  }

  void _tamam() {
    final secim = _secim;
    if (secim != null && tekrarHatasi(secim, widget.baslangic) != null) {
      setState(() => _denendi = true);
      return;
    }
    Navigator.of(context).pop<TekrarSonucu>((secim: secim));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final secim = _secim;
    final hata = !_denendi || secim == null
        ? null
        : tekrarHatasi(secim, widget.baslangic);
    final sonGun = _ayar.sonGun;
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_tekrar_baslik)),
      bottomNavigationBar: SihirbazAltCubugu(
        geriEtiketi: m.etkinlik_geri,
        onGeri: () => Navigator.of(context).pop(),
        ileriEtiketi: m.etkinlik_tamam,
        onIleri: _tamam,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TayfamSizes.okumaGenisligi,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s8,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s32,
            ),
            children: [
              AdimBasligi(
                baslik: m.etkinlik_tekrar_baslik,
                aciklama: m.etkinlik_tekrar_aciklama,
              ),
              BolumEtiketi(baslik: m.etkinlik_tekrar_siklik),
              SecimCipleri<TekrarSikligi?>(
                secenekler: [
                  (null, m.etkinlik_tekrar_yok),
                  (TekrarSikligi.haftalik, m.etkinlik_tekrar_haftalik),
                  (TekrarSikligi.aylik, m.etkinlik_tekrar_aylik),
                ],
                secili: _siklik,
                onSecildi: (s) => setState(() => _siklik = s),
              ),
              if (secim != null) ...[
                BolumEtiketi(
                  baslik: secim.siklik == TekrarSikligi.haftalik
                      ? m.etkinlik_tekrar_aralik_haftalik
                      : m.etkinlik_tekrar_aralik_aylik,
                ),
                SayiSayaci(
                  denetleyici: _aralik,
                  etiket: secim.siklik == TekrarSikligi.haftalik
                      ? m.etkinlik_tekrar_aralik_haftalik
                      : m.etkinlik_tekrar_aralik_aylik,
                  enAz: tekrarAralikEnAz,
                  enCok: tekrarAralikEnCok,
                  onDegisti: (v) => _ayarla(
                    _ayar.degistir(aralik: int.tryParse(v.trim()) ?? 0),
                  ),
                ),
                if (hata == TekrarHatasi.aralik) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  HataSatiri(
                    metin: m.etkinlik_aralik_hata(
                      tekrarAralikEnAz,
                      tekrarAralikEnCok,
                    ),
                  ),
                ],
                if (secim.siklik == TekrarSikligi.aylik) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(
                    m.etkinlik_tekrar_aylik_not,
                    style: context.yazi.bodySmall,
                  ),
                ],
                BolumEtiketi(baslik: m.etkinlik_tekrar_bitis_soru),
                SecimCipleri<TekrarBitisi>(
                  secenekler: [
                    (TekrarBitisi.yok, m.etkinlik_tekrar_bitis_yok),
                    (TekrarBitisi.sayi, m.etkinlik_tekrar_bitis_sayi),
                    (TekrarBitisi.tarih, m.etkinlik_tekrar_bitis_tarih),
                  ],
                  secili: secim.bitis,
                  onSecildi: (b) => _ayarla(_ayar.degistir(bitis: b)),
                ),
                if (secim.bitis == TekrarBitisi.sayi) ...[
                  BolumEtiketi(baslik: m.etkinlik_tekrar_sayi_etiketi),
                  SayiSayaci(
                    denetleyici: _sayi,
                    etiket: m.etkinlik_tekrar_sayi_etiketi,
                    enAz: tekrarSayiEnAz,
                    enCok: tekrarSayiEnCok,
                    onDegisti: (v) => _ayarla(
                      _ayar.degistir(sayi: int.tryParse(v.trim()) ?? 0),
                    ),
                  ),
                  if (hata == TekrarHatasi.sayi) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri(
                      metin: m.etkinlik_aralik_hata(
                        tekrarSayiEnAz,
                        tekrarSayiEnCok,
                      ),
                    ),
                  ],
                ],
                if (secim.bitis == TekrarBitisi.tarih) ...[
                  const SizedBox(height: TayfamSpacing.s16),
                  ListeKarti(
                    children: [
                      MenuSatiri.kartta(
                        baslik: m.etkinlik_tekrar_son_gun,
                        aciklama: sonGun == null
                            ? m.etkinlik_zaman_sec
                            : etkinlikGun(m, sonGun),
                        ikon: Icons.event_outlined,
                        sag: const SatirOku(),
                        onTap: _sonGunSec,
                      ),
                    ],
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  if (hata == TekrarHatasi.tarih)
                    HataSatiri(metin: m.etkinlik_tekrar_tarih_hata)
                  else
                    Text(
                      m.etkinlik_tekrar_tarih_hata,
                      style: context.yazi.bodySmall,
                    ),
                ],
              ],
              const SizedBox(height: TayfamSpacing.s24),
              SihirbazBilgiKutusu(
                metin: tekrarOzeti(m, secim, widget.baslangic),
                ikon: Icons.event_repeat_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
