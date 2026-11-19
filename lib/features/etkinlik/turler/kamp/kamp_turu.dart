import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/arac_formlari.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart'
    show ozetAyraci;
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kamp (ADR-0015 §6): ortak malzeme listesi. Ekleme ve çıkarma yalnızca
/// yönetebilen kullanıcıya (organizatör, moderatör, yönetici;
/// `caller_can_manage`) görünür; "Ben getiririm" yalnızca "Geliyorum"
/// diyene, "Vazgeç" kendi üstlendiği malzemede (issue #187). Düğmeleri
/// gizlemek kolaylıktır; yetkiyi sunucu verir, hatası her durumda
/// gösterilir.
final class KampTuru extends KayitliEtkinlikTuru {
  const KampTuru() : super('camp');

  @override
  Widget? aracBolumu(BuildContext context, Event etkinlik) =>
      KampBolumu(etkinlik: etkinlik);
}

/// Kampın detaydaki bölümü.
class KampBolumu extends ConsumerWidget {
  const KampBolumu({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    final mesgul = ref.watch(aracEylemProvider(anahtar));
    final malzemeler = etkinlik.camp?.items ?? const <CampItem>[];
    final yonetebilir = etkinlik.callerCanManage && !iptalEdildi(etkinlik);
    final ben = ref.watch(kendiKimligimProvider).value;
    final acik = katilimAcik(etkinlik, ref.watch(etkinlikSaatiProvider)());
    final gelen = etkinlik.callerRsvp == RsvpStatus.going;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(
          metin: m.etkinlik_kamp_malzemeler,
          sag: yonetebilir
              ? CerceveliHapEylem(
                  etiket: m.etkinlik_kamp_malzeme_ekle,
                  ikon: Icons.add,
                  onPressed: mesgul
                      ? null
                      : () => unawaited(_ekle(context, ref, anahtar)),
                )
              : null,
        ),
        AracListesi(
          bos: m.etkinlik_kamp_malzeme_yok,
          satirlar: [
            for (final malzeme in malzemeler)
              _MalzemeSatiri(
                malzeme: malzeme,
                benim: ben != null && malzeme.assignedUserId == ben,
                atama: _atama(malzeme, ben: ben, acik: acik, gelen: gelen),
                onAta: mesgul
                    ? null
                    : (kullaniciId) => unawaited(
                        _ata(context, ref, anahtar, malzeme, kullaniciId),
                      ),
                onCikar: !yonetebilir || mesgul
                    ? null
                    : () => unawaited(_cikar(context, ref, anahtar, malzeme)),
                cikarilabilir: yonetebilir,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _ekle(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
  ) => aracFormuAc<void>(
    context,
    (_) => MalzemeFormu(
      anahtar: anahtar,
      kisiSecilebilir: etkinlik.callerCanManage,
    ),
  );

  /// Satırdaki atama düğmesi: boştaki malzemede, "Geliyorum" diyene "Ben
  /// getiririm"; kendi üstlendiğinde "Vazgeç". İptal edilmiş ya da bitmiş
  /// etkinlikte yok. Yönetimin başkasını atama ve atamasını kaldırma
  /// düğmesi tasarımda yoktur (yönetim "Kişi seç"i ekleme formunda
  /// kullanır).
  static _MalzemeAtamasi? _atama(
    CampItem malzeme, {
    required String? ben,
    required bool acik,
    required bool gelen,
  }) {
    if (ben == null || !acik) return null;
    final getiren = malzeme.assignedUserId;
    if (getiren == null) return gelen ? _MalzemeAtamasi.ustlen : null;
    return getiren == ben ? _MalzemeAtamasi.birak : null;
  }

  /// "Ben getiririm" ([kullaniciId] kendi kimliği) ya da "Vazgeç"
  /// (`null`). Hata kısa bildirimle gösterilir; `event-item-taken`
  /// gibi bayat liste hatalarında etkinlik ayrıca yeniden okunur.
  Future<void> _ata(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
    CampItem malzeme,
    String? kullaniciId,
  ) async {
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .malzemeAta(malzeme.id, kullaniciId);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }

  Future<void> _cikar(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
    CampItem malzeme,
  ) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.etkinlik_kamp_malzeme_cikar_onay,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .malzemeCikar(malzeme.id);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

/// Malzeme satırındaki atama düğmesi.
enum _MalzemeAtamasi {
  /// "Ben getiririm": boştaki malzemeyi kendine alır.
  ustlen,

  /// "Vazgeç": kendi üstlendiği malzemeyi bırakır.
  birak,
}

/// Bu yazı ölçeğinin üstünde atama düğmesi metnin altına iner.
const double _dugmeYanYanaEnBuyukOlcek = 1.3;

class _MalzemeSatiri extends ConsumerWidget {
  const _MalzemeSatiri({
    required this.malzeme,
    required this.benim,
    required this.atama,
    required this.onAta,
    required this.onCikar,
    required this.cikarilabilir,
  });

  final CampItem malzeme;

  /// Malzemeyi oturumdaki kullanıcı üstlenmiş ("Getirecek: Sen").
  final bool benim;

  /// Gösterilecek atama düğmesi; `null` ise yok.
  final _MalzemeAtamasi? atama;

  /// Atama isteği: kendi kimliği ("Ben getiririm") ya da `null`
  /// ("Vazgeç"). `null` ise (istek sürerken) düğme kilitlidir.
  final ValueChanged<String?>? onAta;

  final VoidCallback? onCikar;
  final bool cikarilabilir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final getiren = malzeme.assignedUserId;
    // Sözleşme: 0 ya da yok, 1 adet.
    final adet = malzeme.quantity < 1 ? 1 : malzeme.quantity;
    final ikincil = context.yazi.bodySmall;
    final atama = this.atama;
    final onAta = this.onAta;
    final Widget? dugme = switch (atama) {
      null => null,
      _MalzemeAtamasi.ustlen => _SatirHapi(
        etiket: m.etkinlik_kamp_ben_getiririm,
        dolu: true,
        onPressed: onAta == null
            ? null
            : () {
                final ben = ref.read(kendiKimligimProvider).value;
                if (ben != null) onAta(ben);
              },
      ),
      _MalzemeAtamasi.birak => _SatirHapi(
        etiket: m.etkinlik_kamp_vazgec,
        dolu: false,
        onPressed: onAta == null ? null : () => onAta(null),
      ),
    };
    final yanYana =
        MediaQuery.textScalerOf(context).scale(1) <= _dugmeYanYanaEnBuyukOlcek;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(malzeme.name, style: context.yazi.titleSmall),
                // Alt satır (tasarım: Etkinlik-Malzeme-Liste): "2 adet ·
                // Getirecek: …", kendi üstlendiğinde "Getirecek: Sen",
                // boştaysa "Henüz kimse üstlenmedi". Getirecek kişinin
                // adına dokununca kişi profili (#185).
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      m.etkinlik_kamp_adet(etkinlikSayi(m, adet)),
                      style: ikincil,
                    ),
                    ExcludeSemantics(child: Text(ozetAyraci, style: ikincil)),
                    if (getiren == null)
                      Text(m.etkinlik_kamp_kimse_ustlenmedi, style: ikincil)
                    else if (benim)
                      Text(
                        m.etkinlik_kamp_getirecek_sen,
                        style: ikincil?.copyWith(
                          color: context.renkler.tintMarkaUstu,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      KisiyeDokun(
                        kullaniciId: getiren,
                        ipucu: m.etkinlik_kamp_getirecek,
                        child: Wrap(
                          spacing: TayfamSpacing.s4,
                          children: [
                            Text(m.etkinlik_kamp_getirecek, style: ikincil),
                            KullaniciAdiMetni(
                              kullaniciId: getiren,
                              style: ikincil,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (dugme != null && !yanYana)
                  Padding(
                    padding: const EdgeInsets.only(top: TayfamSpacing.s4),
                    child: dugme,
                  ),
              ],
            ),
          ),
          if (dugme != null && yanYana) ...[
            const SizedBox(width: TayfamSpacing.s12),
            dugme,
          ],
          if (cikarilabilir)
            AracIkonDugmesi(
              ipucu: m.etkinlik_kamp_malzeme_cikar,
              ikon: Icons.delete_outline,
              onPressed: onCikar,
            ),
        ],
      ),
    );
  }
}

/// Satır içi küçük hap düğme (tasarım: Etkinlik-Malzeme-Liste): [dolu]
/// marka zemin + beyaz metin ("Ben getiririm"; iki temada aynı), değilse
/// kart zemin, çizgi kenar, ana metin ("Vazgeç"). Dokunma alanı en az
/// 48 px; `onPressed` `null` ise (istek sürerken) kilitlidir.
class _SatirHapi extends StatelessWidget {
  const _SatirHapi({
    required this.etiket,
    required this.dolu,
    required this.onPressed,
  });

  final String etiket;
  final bool dolu;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final (zemin, yazi) = dolu
        ? (r.markaYuzey, r.markaYuzeyUstu)
        : (r.kart, r.metin);
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: zemin,
          foregroundColor: yazi,
          disabledBackgroundColor: r.pasif,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
          shape: StadiumBorder(
            side: dolu
                ? BorderSide.none
                : BorderSide(
                    color: onPressed == null ? r.pasif : r.cizgi,
                    width: TayfamSizes.vurguKenari,
                  ),
          ),
          textStyle: context.yazi.labelLarge,
        ),
        child: Text(etiket, textAlign: TextAlign.center),
      ),
    );
  }
}

/// "Kim getirecek?" seçenekleri (tasarım: Etkinlik-Malzeme-Ekle).
enum MalzemeGetiren {
  /// Kendisi (`assigned_user_id` = kendi kimliği).
  ben,

  /// Henüz kimse (alan gönderilmez).
  kimse,

  /// Etkinliğe gelenlerden biri; yalnızca organizatör ve yönetim.
  kisi,
}

/// Kamp malzemesi ekleme formu (issue #187; tasarım:
/// Etkinlik-Malzeme-Ekle): ad (60), adet sayacı (1–999), "Kim getirecek?"
/// Ben / Henüz kimse / Kişi seç. "Kişi seç" yalnızca [kisiSecilebilir]
/// (organizatör ve yönetim) ise görünür ve "Geliyorum" diyenlerden seçer.
/// Atanan kişi `going` değilse sunucu `event-not-going` döner; form açık
/// kalır ve hatayı gösterir.
class MalzemeFormu extends ConsumerStatefulWidget {
  const MalzemeFormu({
    super.key,
    required this.anahtar,
    this.kisiSecilebilir = false,
  });

  final EtkinlikAnahtari anahtar;
  final bool kisiSecilebilir;

  @override
  ConsumerState<MalzemeFormu> createState() => _MalzemeFormuState();
}

class _MalzemeFormuState extends ConsumerState<MalzemeFormu> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _adet = TextEditingController(text: '1');
  MalzemeGetiren _getiren = MalzemeGetiren.kimse;
  String? _secilenKisi;
  Set<MalzemeHatasi> _hatalar = const {};
  bool _kisiHatasi = false;
  Object? _hata;

  KatilimcilarAnahtari get _gelenler => (
    tayfaId: widget.anahtar.tayfaId,
    etkinlikId: widget.anahtar.etkinlikId,
    durum: ListEventAttendeesStatus.going,
  );

  @override
  void dispose() {
    _ad.dispose();
    _adet.dispose();
    super.dispose();
  }

  Future<void> _ekle() async {
    final String? getiren;
    switch (_getiren) {
      case MalzemeGetiren.ben:
        getiren = ref.read(kendiKimligimProvider).value;
      case MalzemeGetiren.kimse:
        getiren = null;
      case MalzemeGetiren.kisi:
        getiren = _secilenKisi;
    }
    final sonuc = malzemeIstegi(
      ad: _ad.text,
      adet: _adet.text,
      getiren: getiren,
    );
    final kisiEksik = _getiren != MalzemeGetiren.kimse && getiren == null;
    final istek = sonuc.istek;
    if (istek == null || kisiEksik) {
      setState(() {
        _hatalar = sonuc.hatalar;
        _kisiHatasi = kisiEksik;
      });
      return;
    }
    setState(() {
      _hatalar = const {};
      _kisiHatasi = false;
      _hata = null;
    });
    final hata = await ref
        .read(aracEylemProvider(widget.anahtar).notifier)
        .malzemeEkle(istek);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _hata = hata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(aracEylemProvider(widget.anahtar));
    final hata = _hata;
    final benBilinir = ref.watch(kendiKimligimProvider).value != null;
    return AracFormSayfasi(
      baslik: m.etkinlik_kamp_malzeme_ekle,
      onayEtiketi: m.etkinlik_ekle,
      onOnay: mesgul ? null : () => unawaited(_ekle()),
      alanlar: [
        TextField(
          controller: _ad,
          autofocus: true,
          maxLength: malzemeAdiEnCok,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.etkinlik_kamp_malzeme_adi,
            errorText: _hatalar.contains(MalzemeHatasi.ad)
                ? m.etkinlik_kamp_malzeme_adi_hata
                : null,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        SayiSayaci(
          denetleyici: _adet,
          etiket: m.etkinlik_kamp_adet_etiketi,
          enAz: 1,
          enCok: malzemeAdediEnCok,
          etkin: !mesgul,
          onDegisti: (_) => setState(() {}),
        ),
        if (_hatalar.contains(MalzemeHatasi.adet))
          Padding(
            padding: const EdgeInsets.only(top: TayfamSpacing.s4),
            child: HataSatiri(metin: m.etkinlik_sayi_hata(malzemeAdediEnCok)),
          ),
        const SizedBox(height: TayfamSpacing.s16),
        Text(m.etkinlik_kamp_kim_getirecek, style: context.yazi.titleSmall),
        const SizedBox(height: TayfamSpacing.s8),
        SecimCipleri<MalzemeGetiren>(
          secenekler: [
            if (benBilinir) (MalzemeGetiren.ben, m.etkinlik_kamp_getiren_ben),
            (MalzemeGetiren.kimse, m.etkinlik_kamp_getiren_kimse),
            if (widget.kisiSecilebilir)
              (MalzemeGetiren.kisi, m.etkinlik_kamp_getiren_kisi),
          ],
          secili: _getiren,
          onSecildi: mesgul
              ? null
              : (g) => setState(() {
                  _getiren = g;
                  _kisiHatasi = false;
                  _hata = null;
                }),
        ),
        if (widget.kisiSecilebilir) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.etkinlik_kamp_kisi_sec_notu),
        ],
        if (_getiren == MalzemeGetiren.kisi) ...[
          const SizedBox(height: TayfamSpacing.s8),
          _GelenSecici(
            anahtar: _gelenler,
            secili: _secilenKisi,
            onSecildi: (id) => setState(() {
              _secilenKisi = id;
              _kisiHatasi = false;
            }),
          ),
        ],
        if (_kisiHatasi) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: m.etkinlik_kamp_kisi_sec_hata),
        ],
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// "Kişi seç": etkinliğe "Geliyorum" diyenler (ilk sayfa ve "Daha fazla").
class _GelenSecici extends ConsumerWidget {
  const _GelenSecici({
    required this.anahtar,
    required this.secili,
    required this.onSecildi,
  });

  final KatilimcilarAnahtari anahtar;
  final String? secili;
  final ValueChanged<String> onSecildi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    return durum.when(
      data: (liste) {
        if (liste.ogeler.isEmpty) {
          return AracBilgisi(metin: m.etkinlik_kamp_gelen_yok);
        }
        return RadioGroup<String>(
          groupValue: secili,
          onChanged: (id) {
            if (id != null) onSecildi(id);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final kisi in liste.ogeler)
                RadioListTile<String>(
                  value: kisi.userId,
                  contentPadding: EdgeInsets.zero,
                  title: KullaniciAdiMetni(kullaniciId: kisi.userId),
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
          ),
        );
      },
      error: (hata, _) => HataSatiri.hatadan(hata),
      loading: () => const Center(child: TayfamYukleniyor(gecikmeli: true)),
    );
  }
}
