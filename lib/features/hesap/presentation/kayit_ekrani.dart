import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/application/kayit_notifier.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/features/hesap/presentation/hukuki_onay.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Doğum tarihi seçici: seçilen tarihi ya da vazgeçilirse `null` döndürür.
typedef DogumTarihiSecici = Future<DateTime?> Function(
  BuildContext context,
  DateTime? secili,
);

/// Sistem tarih seçicisi (ADR-0012 §3): `tr_TR`, ön seçili tarih yok,
/// bugünden ileri seçilemez, yıl görünümüyle açılır.
Future<DateTime?> sistemTarihSecicisi(BuildContext context, DateTime? secili) {
  final bugun = DateUtils.dateOnly(DateTime.now());
  return showDatePicker(
    context: context,
    initialDate: secili,
    firstDate: DateTime(1900),
    lastDate: bugun,
    initialDatePickerMode: DatePickerMode.year,
  );
}

/// Kayıt ekranı (ADR-0012 §3): ad (Google adıyla dolu), doğum tarihi, iki
/// ayrı onay kutusu ve isteğe bağlı referans kodu. Gönderimden önce doğum
/// tarihi bir pencerede teyit ettirilir; pencere yaş sınırını söylemez.
class KayitEkrani extends ConsumerStatefulWidget {
  const KayitEkrani({super.key, this.tarihSecici = sistemTarihSecicisi});

  /// Testlerde sahte seçici verilir.
  final DogumTarihiSecici tarihSecici;

  @override
  ConsumerState<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends ConsumerState<KayitEkrani> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _referans = TextEditingController();
  final TextEditingController _tarihMetni = TextEditingController();
  DateTime? _dogumTarihi;
  bool _aydinlatma = false;
  bool _kosullar = false;
  Set<KayitFormHatasi> _hatalar = const {};

  @override
  void initState() {
    super.initState();
    _ad.text = ref.read(googleAdiProvider) ?? '';
  }

  @override
  void dispose() {
    _ad.dispose();
    _referans.dispose();
    _tarihMetni.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final secilen = await widget.tarihSecici(context, _dogumTarihi);
    if (secilen == null || !mounted) return;
    final metinler = AppLocalizations.of(context);
    setState(() {
      _dogumTarihi = DateUtils.dateOnly(secilen);
      _tarihMetni.text = metinler.hesap_kayit_dogum_tarihi_deger(secilen);
      _hatalar = {..._hatalar}..remove(KayitFormHatasi.dogumTarihi);
    });
  }

  Future<void> _gonder(OnaySurumleri surumler) async {
    final sonuc = kayitFormunuDenetle(
      ad: _ad.text,
      googleAdi: ref.read(googleAdiProvider),
      dogumTarihi: _dogumTarihi,
      aydinlatmaOnayi: _aydinlatma,
      kosullarOnayi: _kosullar,
      referansKodu: _referans.text,
      surumler: surumler,
      bugun: DateTime.now(),
    );
    setState(() => _hatalar = sonuc.hatalar);
    final bilgi = sonuc.bilgi;
    if (bilgi == null) return;
    final dogru = await showDialog<bool>(
      context: context,
      builder: (context) => DogumTarihiTeyidi(tarih: bilgi.dogumTarihi),
    );
    if (dogru != true || !mounted) return;
    await ref.read(kayitProvider.notifier).gonder(bilgi);
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    // Sürümler değişince (consent-outdated) kullanıcı yeni metinleri
    // yeniden onaylar.
    ref.listen(kayitProvider, (onceki, sonraki) {
      final eski = onceki?.value?.surumler;
      final yeni = sonraki.value?.surumler;
      if (eski != null && yeni != null && eski != yeni) {
        setState(() {
          _aydinlatma = false;
          _kosullar = false;
        });
      }
    });
    final durum = ref.watch(kayitProvider);
    final deger = durum.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(metinler.hesap_kayit_baslik),
        actions: [
          TextButton(
            onPressed: () =>
                unawaited(ref.read(kayitProvider.notifier).cikisYap()),
            child: Text(metinler.hesap_cikis_yap),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: deger != null
                ? _form(context, metinler, deger)
                : YuklemeDurumu(
                    yukleniyor: durum.isLoading,
                    hata: durum.error,
                    tekrarDene: () => ref.invalidate(kayitProvider),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations metinler,
    KayitDurumu deger,
  ) {
    final yazi = context.yazi;
    final kilitli = deger.gonderiliyor;
    final hata = deger.hata;
    final surumler = deger.surumler;
    // Form kısa; ListView gibi tembel kurulmaz, bütün alanlar ağaçta
    // (ekran okuyucu sırası ve testler).
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            metinler.hesap_kayit_aciklama,
            style: yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde),
          ),
          const SizedBox(height: TayfamSpacing.s24),
          TextField(
            controller: _ad,
            enabled: !kilitli,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: metinler.hesap_kayit_ad,
              helperText: metinler.hesap_kayit_ad_yardim,
              errorText: _hatalar.contains(KayitFormHatasi.ad)
                  ? metinler.hesap_kayit_ad_hata
                  : null,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          TextField(
            controller: _tarihMetni,
            readOnly: true,
            enabled: !kilitli,
            onTap: () => unawaited(_tarihSec()),
            decoration: InputDecoration(
              labelText: metinler.hesap_kayit_dogum_tarihi,
              hintText: metinler.hesap_kayit_dogum_tarihi_bos,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
              errorText: _hatalar.contains(KayitFormHatasi.dogumTarihi)
                  ? metinler.hesap_kayit_dogum_tarihi_hata
                  : null,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
          HukukiOnay(
            etiket: metinler.hesap_aydinlatma_onay,
            isaretli: _aydinlatma,
            degisti: kilitli ? null : (d) => setState(() => _aydinlatma = d),
            baglantilar: [
              (
                metinler.hesap_aydinlatma_ac,
                surumler.adres(HukukiMetin.aydinlatma),
              ),
            ],
            hata: _hatalar.contains(KayitFormHatasi.aydinlatma)
                ? metinler.hesap_aydinlatma_hata
                : null,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          HukukiOnay(
            etiket: metinler.hesap_kosullar_onay,
            isaretli: _kosullar,
            degisti: kilitli ? null : (d) => setState(() => _kosullar = d),
            baglantilar: [
              (
                metinler.hesap_kosullar_ac,
                surumler.adres(HukukiMetin.kosullar),
              ),
            ],
            hata: _hatalar.contains(KayitFormHatasi.kosullar)
                ? metinler.hesap_kosullar_hata
                : null,
          ),
          const SizedBox(height: TayfamSpacing.s16),
          TextField(
            controller: _referans,
            enabled: !kilitli,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: metinler.hesap_kayit_referans,
              errorText: _hatalar.contains(KayitFormHatasi.referansKodu)
                  ? metinler.hesap_kayit_referans_hata
                  : null,
            ),
          ),
          if (hata != null) ...[
            const SizedBox(height: TayfamSpacing.s16),
            HataMetni(metin: hesapHatasiMetni(metinler, hata)),
          ],
          const SizedBox(height: TayfamSpacing.s24),
          BirincilEylem(
            etiket: metinler.hesap_kayit_gonder,
            onPressed: kilitli ? null : () => unawaited(_gonder(surumler)),
          ),
        ],
      ),
    );
  }
}

/// Gönderimden önceki doğum tarihi teyidi (ADR-0012 §3): "Doğum tarihin 12
/// Mart 2009. Doğru mu?" — "Düzelt" (`false`) / "Doğru, devam et" (`true`).
/// Yaş sınırı ya da sonucu söylenmez.
class DogumTarihiTeyidi extends StatelessWidget {
  const DogumTarihiTeyidi({super.key, required this.tarih});

  final DateTime tarih;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(metinler.hesap_teyit_baslik),
      content: Text(metinler.hesap_teyit_metin(tarih)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(metinler.hesap_teyit_duzelt),
        ),
        BirincilEylem(
          etiket: metinler.hesap_teyit_devam,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
