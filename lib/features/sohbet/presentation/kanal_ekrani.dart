import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/sohbet/akis_duzeni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/sohbet/application/kanal_akisi_notifier.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/data/kanal_mesaj_isi.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_formu.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_listesi.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ortak.dart';
import 'package:tayfam/features/sohbet/presentation/katilimcilar_ekrani.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir kanalın mesaj akışı (`/sohbet/kanal/<tayfaId>/<kanalId>`;
/// ADR-0018 §9; 2026-11-13 tasarım: Kanal-Akis, Kanal-Islem).
///
/// - Üst çubukta kanal ikon kutusu, ad ve tayfa adı; yönetimde ⋯ (kanal
///   ayarları).
/// - Aynı yazarın ardışık mesajları gruplanır: ad grubun ilk balonunda,
///   avatar ve saat grubun sonunda. Günün ilk mesajının üstünde gün
///   ayırıcı ("Bugün", "Dün", tarih). Kendi mesajın sağda mor balon.
/// - Bekleyen (kuyruktaki) mesaj saat ikonuyla, gönderilemeyen nar kenarlı
///   balonla gösterilir; gönderilemeyende "Tekrar dene" (aynı
///   `client_request_id`) ve "Sil" vardır (ADR-0006).
/// - Yavaş modda yazma alanının üstünde bilgi satırı; gönderden sonra
///   düğme geri sayıma döner (ADR-0007). Yönetim muaftır (sunucu söyler;
///   istemci yalnızca sadeleştirir).
/// - Uzun basınca "Mesaj işlemleri" alttan sayfası: kendi mesajın ya da
///   yönetimse "Mesajı sil"; silinmiş ve geri alınabilir mesajda yönetime
///   "Geri al". Kanal mesajı şikâyeti sözleşmede yoktur.
/// - Kanala erişim kalmazsa (ör. seçili kişi kanalından çıkarıldın;
///   sunucu aboneliği keser) Sohbet sekmesine dönülür.
/// - Etkinlik ve seçili kişi kanalında üst çubukta kitle ve kişi sayısı;
///   "Katılımcıları gör" katılımcılar ekranını açar (Tayfam-Api #183).
/// - Etkinlik bitince etkinlik kanalının üstünde kapatılamayan sarı
///   kapanış bandı (tasarım: Kanal-Etkinlik-Bitti); akış kayarken üstte
///   kalır. Arşivde yazma alanının yerinde arşiv bilgisi.
///
/// Mesaj metni yalnızca bellekte ve ekrandadır; loglanmaz, diske yazılmaz.
class KanalEkrani extends ConsumerStatefulWidget {
  const KanalEkrani({super.key, required this.tayfaId, required this.kanalId});

  /// Adresteki kimlikler (biçimi yönlendiricide doğrulandı).
  final String tayfaId;
  final String kanalId;

  @override
  ConsumerState<KanalEkrani> createState() => _KanalEkraniState();
}

class _KanalEkraniState extends ConsumerState<KanalEkrani> {
  final TextEditingController _metin = TextEditingController();
  late final KanalRef _kanal = (
    tayfaId: widget.tayfaId,
    kanalId: widget.kanalId,
  );
  late final AcikKanalNotifier _acik;
  DateTime? _bekleBitis;
  Timer? _sayac;

  @override
  void initState() {
    super.initState();
    _acik = ref.read(acikKanalProvider.notifier);
    // Provider çizim sırasında değiştirilmez; sonraya bırakılır.
    scheduleMicrotask(() {
      if (mounted) _acik.ac(_kanal);
    });
  }

  @override
  void dispose() {
    final acik = _acik;
    final kanal = _kanal;
    scheduleMicrotask(() => acik.kapat(kanal));
    _sayac?.cancel();
    _metin.dispose();
    super.dispose();
  }

  Channel? _bul(List<Channel>? liste) {
    if (liste == null) return null;
    for (final k in liste) {
      if (k.id == widget.kanalId) return k;
    }
    return null;
  }

  void _okunduIsaretle() {
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(ref.read(kanalAkisiProvider(_kanal).notifier).okunduIsaretle());
    });
  }

  /// Geri sayımın bitişi: yerel yavaş mod beklemesi ya da kuyruktaki
  /// mesajın sunucudan aldığı bekleme süresi.
  DateTime? _bitis(List<KuyrukOgesi> bekleyenler) {
    var bitis = _bekleBitis;
    for (final o in bekleyenler) {
      final hata = o.hata;
      final zaman = o.sonrakiDeneme;
      if (hata is ApiProblem &&
          hata.type == ProblemType.slowMode &&
          zaman != null &&
          (bitis == null || zaman.isAfter(bitis))) {
        bitis = zaman;
      }
    }
    return bitis;
  }

  void _sayaciKur(DateTime? bitis) {
    final simdi = ref.read(simdiProvider)();
    if (bitis == null || !bitis.isAfter(simdi)) {
      _sayac?.cancel();
      _sayac = null;
      return;
    }
    _sayac ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final simdi = ref.read(simdiProvider)();
      final b = _bitis(_bekleyenler());
      if (b == null || !b.isAfter(simdi)) {
        _sayac?.cancel();
        _sayac = null;
        _bekleBitis = null;
      }
      setState(() {});
    });
  }

  List<KuyrukOgesi> _bekleyenler() => [
    for (final o in ref.read(cevrimdisiKuyrukProvider))
      if (o.grup == kanalGrubu(widget.kanalId)) o,
  ];

  void _gonder(Channel? kanal, bool yonetimde) {
    final metin = _metin.text;
    final gitti = ref.read(kanalAkisiProvider(_kanal).notifier).gonder(metin);
    if (!gitti) return;
    _metin.clear();
    final yavas = kanal?.slowModeSeconds ?? 0;
    if (yavas > 0 && !yonetimde) {
      setState(() {
        _bekleBitis = ref.read(simdiProvider)().add(Duration(seconds: yavas));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = kanalAkisiProvider(_kanal);
    final kanallar = ref.watch(kanallarProvider(widget.tayfaId));
    final kanal = _bul(kanallar.value);
    final ozet = ref.watch(tayfaOzetiProvider(widget.tayfaId));
    final yonetimde = ozet.yonetimde;
    final durum = ref.watch(saglayici);
    final bekleyenler = [
      for (final o in ref.watch(cevrimdisiKuyrukProvider))
        if (o.grup == kanalGrubu(widget.kanalId)) o,
    ];

    ref.listen(kanallarProvider(widget.tayfaId), (onceki, simdiki) {
      final vardi = _bul(onceki?.value) != null;
      if (vardi && simdiki.hasValue && _bul(simdiki.value) == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(m.sohbet_erisim_kalmadi)));
        context.go(Adresler.sohbet);
      }
    });
    ref.listen(saglayici, (onceki, simdiki) {
      final eskiEnYeni = onceki?.value?.mesajlar.firstOrNull?.id;
      final yeniEnYeni = simdiki.value?.mesajlar.firstOrNull?.id;
      if (yeniEnYeni != null && yeniEnYeni != eskiEnYeni) _okunduIsaretle();
    });

    final bitis = _bitis(bekleyenler);
    _sayaciKur(bitis);
    final simdi = ref.read(simdiProvider)();
    final kalan = bitis == null ? 0 : bitis.difference(simdi).inSeconds + 1;
    final bekle = bitis != null && bitis.isAfter(simdi) ? kalan : 0;
    final yavas = kanal?.slowModeSeconds ?? 0;
    final kitle = kanal == null ? null : KanalKitlesi.kanaldan(kanal);
    final altBaslik = kanal == null ? null : _altBaslik(m, kanal, ozet.ad);
    final arsivZamani = kanal?.archiveAt;
    final bant = kanal == null || kanal.archivedAt != null || arsivZamani == null
        ? null
        : kapanisBandi(arsivZamani, simdi);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: sohbetUstCubukYuksekligi(context),
        shape: Border(
          bottom: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
        title: kanal == null
            ? null
            : Row(
                children: [
                  KanalIkonKutusu(
                    ikon: kanalIkonu(kanal),
                    boyut: TayfamSizes.ustCubukKutusu,
                  ),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kanal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.yazi.titleMedium,
                        ),
                        if (altBaslik != null)
                          Text(
                            altBaslik,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.yazi.labelSmall?.copyWith(
                              color: r.metinIkincil,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (kanal != null && (kitle?.sabit ?? false))
            IconButton(
              tooltip: m.sohbet_katilimcilari_gor,
              icon: const Icon(Icons.group_outlined),
              onPressed: () => unawaited(katilimcilariAc(context, _kanal)),
            ),
          if (yonetimde && kanal != null)
            IconButton(
              tooltip: m.sohbet_kanal_ayarlari,
              icon: const Icon(Icons.more_horiz),
              onPressed: () => unawaited(
                kanalFormunuAc(context, tayfaId: widget.tayfaId, kanal: kanal),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (bant != null) _KapanisBandi(bant: bant),
          Expanded(
            child: switch (durum) {
              AsyncValue(value: final akis?) => _MesajListesi(
                kanal: _kanal,
                akis: akis,
                bekleyenler: bekleyenler,
                yonetimde: yonetimde,
              ),
              AsyncValue(error: final hata?) => ListView(
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                children: [
                  HataSatiri.hatadan(hata),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BaglantiEylemi(
                      etiket: m.sohbet_tekrar_dene,
                      onPressed: () => ref.invalidate(saglayici),
                    ),
                  ),
                ],
              ),
              _ => Center(
                child: TayfamYukleniyor(
                  boyut: TayfamSizes.yukleniyorTamEkran,
                  etiket: m.sohbet_mesajlar_yukleniyor,
                  gecikmeli: true,
                ),
              ),
            },
          ),
          if (kanal?.archivedAt != null)
            _ArsivBilgisi(metin: m.sohbet_arsiv_bilgi)
          else
            MesajYazmaCubugu(
              denetleyici: _metin,
              ipucu: bekle > 0
                  ? m.sohbet_gonder_bekle(bekle)
                  : m.sohbet_mesaj_ipucu,
              gonderEtiketi: m.sohbet_gonder,
              enUzun: mesajEnUzun,
              onGonder: () => _gonder(kanal, yonetimde),
              geriSayim: bekle > 0 ? m.sohbet_geri_sayim(bekle) : null,
              geriSayimEtiketi: bekle > 0 ? m.sohbet_gonder_bekle(bekle) : null,
              ust: yavas > 0 ? _YavasModSatiri(saniye: yavas) : null,
            ),
        ],
      ),
    );
  }
}

/// Üst çubuktaki alt metin: etkinlik kanalında "Etkinlik kanalı · 24
/// kişi" (arşivde "Etkinlik kanalı · arşivde"), seçili kişi kanalında
/// "Seçili kişiler · 5 kişi", diğerlerinde tayfanın adı.
String? _altBaslik(AppLocalizations m, Channel kanal, String? tayfaAdi) {
  final sayi = kanal.memberCount;
  switch (KanalKitlesi.kanaldan(kanal)) {
    case KanalKitlesi.etkinlik:
      if (kanal.archivedAt != null) return m.sohbet_kanal_alt_arsiv;
      if (sayi == null) return m.sohbet_kanal_alt_etkinlik_sayisiz;
      return m.sohbet_kanal_alt_etkinlik(sayi);
    case KanalKitlesi.secili:
      if (sayi == null) return tayfaAdi;
      return m.sohbet_kanal_alt_secili(sayi);
    case KanalKitlesi.herkes || KanalKitlesi.yonetim:
      return tayfaAdi;
  }
}

/// Etkinlik kanalının kapanış bandı (tasarım: Kanal-Etkinlik-Bitti):
/// tint-mango zemin, ikon, başlık ve arşiv tarihi. Kapatılamaz; akışın
/// üstünde sabittir. Ekran okuyucuya durum olarak okunur.
class _KapanisBandi extends StatelessWidget {
  const _KapanisBandi({required this.bant});

  final KapanisBandi bant;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMango,
          border: Border(
            bottom: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
            vertical: TayfamSpacing.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: TayfamSizes.ikon,
                  color: r.tintMangoUstu,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kapanisBasligi(m, bant),
                      style: context.yazi.titleSmall?.copyWith(
                        color: r.tintMangoUstu,
                      ),
                    ),
                    Text(
                      kapanisAciklamasi(m, bant),
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.tintMangoUstu,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yazma alanının üstündeki yavaş mod bilgisi (tasarım: Kanal-Akis).
class _YavasModSatiri extends StatelessWidget {
  const _YavasModSatiri({required this.saniye});

  final int saniye;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.timer_outlined,
              size: TayfamSizes.ikonKucuk,
              color: r.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).sohbet_yavas_mod_bilgi(saniye),
              style: context.yazi.labelSmall?.copyWith(color: r.metinIkincil),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arşivlenmiş kanalda yazma alanının yerindeki bilgi.
class _ArsivBilgisi extends StatelessWidget {
  const _ArsivBilgisi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: TayfamSizes.ikon,
                  color: r.metinIkincil,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Text(
                  metin,
                  style: context.yazi.bodySmall?.copyWith(color: r.metinGovde),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MesajListesi extends ConsumerWidget {
  const _MesajListesi({
    required this.kanal,
    required this.akis,
    required this.bekleyenler,
    required this.yonetimde,
  });

  final KanalRef kanal;
  final KanalAkisi akis;
  final List<KuyrukOgesi> bekleyenler;
  final bool yonetimde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    if (akis.mesajlar.isEmpty && bekleyenler.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: Text(
            m.sohbet_kanal_bos,
            textAlign: TextAlign.center,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ),
      );
    }
    final simdi = ref.read(simdiProvider)();
    // Akış eskiden yeniye düzenlenir; liste ters çizildiği için sonra
    // çevrilir.
    final mesajlar = akis.mesajlar.reversed.toList();
    final duzen = akisDuzeni([
      for (final mesaj in mesajlar)
        AkisGirdisi(zaman: mesaj.createdAt, yazar: mesaj.authorUserId),
    ]);
    final eskidenYeniye = <Widget>[
      if (akis.eskiHatasi case final hata?)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
          child: HataSatiri.hatadan(hata),
        ),
      if (akis.eskiYukleniyor)
        Center(child: TayfamYukleniyor(etiket: m.sohbet_mesajlar_yukleniyor))
      else if (akis.eskiSayfa != null)
        Center(
          child: BaglantiEylemi(
            etiket: m.sohbet_daha_eski,
            onPressed: () => unawaited(
              ref.read(kanalAkisiProvider(kanal).notifier).eskileriYukle(),
            ),
          ),
        ),
      for (final (sira, mesaj) in mesajlar.indexed) ...[
        if (duzen[sira].gunBasi)
          GunAyirici(metin: gunAyiriciMetni(m, mesaj.createdAt, simdi)),
        _MesajSatiri(
          key: ValueKey(mesaj.id),
          kanal: kanal,
          mesaj: mesaj,
          konum: duzen[sira],
          yonetimde: yonetimde,
        ),
      ],
      for (final o in bekleyenler)
        _BekleyenMesaj(key: ValueKey(o.istekKimligi), oge: o),
    ];
    final ogeler = eskidenYeniye.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.kenarMobil,
        vertical: TayfamSpacing.s8,
      ),
      itemCount: ogeler.length,
      itemBuilder: (_, i) => ogeler[i],
    );
  }
}

class _MesajSatiri extends ConsumerWidget {
  const _MesajSatiri({
    super.key,
    required this.kanal,
    required this.mesaj,
    required this.konum,
    required this.yonetimde,
  });

  final KanalRef kanal;
  final ChannelMessage mesaj;
  final AkisKonumu konum;
  final bool yonetimde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final yazar = mesaj.authorUserId;
    KullaniciAdi? bilinen;
    if (yazar != null) {
      ref.read(kullaniciAdlariProvider.notifier).iste(yazar);
      bilinen = ref.watch(
        kullaniciAdlariProvider.select((adlar) => adlar[yazar]),
      );
    }
    final ben = yazar != null && ref.watch(kendisiMiProvider(yazar));
    final gonderen = switch (bilinen) {
      _ when yazar == null => m.kullanici_silinmis,
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    final silinebilir = !mesaj.deleted && (ben || yonetimde);
    final geriAlinabilir =
        yonetimde && mesaj.deleted && (mesaj.restorable ?? false);
    final body = mesaj.body;
    final silinmis = mesaj.deleted || body == null;

    Widget balon = SohbetBalonu(
      metin: body == null || mesaj.deleted ? m.sohbet_mesaj_silindi : body,
      giden: ben,
      gonderen: ben ? null : gonderen,
      tur: silinmis ? BalonTuru.silinmis : BalonTuru.akis,
      kuyruk: konum.grupSonu,
      adGoster: konum.grupBasi,
    );
    if (silinebilir || geriAlinabilir) {
      balon = Semantics(
        onLongPressHint: m.sohbet_mesaj_islemleri,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => unawaited(
            _eylemler(
              context,
              ref,
              alinti: silinmis ? null : body,
              sil: silinebilir,
              geriAl: geriAlinabilir,
            ),
          ),
          child: balon,
        ),
      );
    }
    final saat = konum.grupSonu
        ? MesajAltSatiri(children: [Text(saatMetni(m, mesaj.createdAt))])
        : null;
    final ust = konum.grupBasi ? TayfamSpacing.s12 : TayfamSpacing.s4;
    if (ben) {
      return Padding(
        padding: EdgeInsets.only(top: ust),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [balon, ?saat],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: ust),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (konum.grupSonu)
            Padding(
              // Avatar, saat satırının üstünde balonun hizasında durur.
              padding: EdgeInsets.only(
                bottom: saat == null ? 0 : TayfamSpacing.s24,
              ),
              child: KimlikAvatari(
                kullaniciId: yazar,
                cap: TayfamSizes.mesajAvatari,
              ),
            )
          else
            const SizedBox(width: TayfamSizes.mesajAvatari),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [balon, ?saat],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eylemler(
    BuildContext context,
    WidgetRef ref, {
    required String? alinti,
    required bool sil,
    required bool geriAl,
  }) async {
    final m = AppLocalizations.of(context);
    final secim = await altSayfaAc<_KanalMesajIslemi>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.sohbet_mesaj_islemleri,
        children: [
          if (alinti != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.s8,
                0,
                TayfamSpacing.s8,
                TayfamSpacing.s8,
              ),
              child: Text(
                m.sohbet_mesaj_alinti(alinti),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sayfa.yazi.bodySmall?.copyWith(
                  color: sayfa.renkler.metinIkincil,
                ),
              ),
            ),
          if (sil)
            MenuSatiri(
              ikon: Icons.delete_outline,
              tur: MenuSatiriTuru.yikici,
              baslik: m.sohbet_mesaji_sil,
              aciklama: m.sohbet_mesaj_sil_onay_aciklama,
              onTap: () => Navigator.of(sayfa).pop(_KanalMesajIslemi.sil),
            ),
          if (geriAl)
            MenuSatiri(
              ikon: Icons.restore,
              baslik: m.sohbet_mesaj_geri_al,
              onTap: () => Navigator.of(sayfa).pop(_KanalMesajIslemi.geriAl),
            ),
        ],
      ),
    );
    if (secim == null || !context.mounted) return;
    final notifier = ref.read(kanalAkisiProvider(kanal).notifier);
    try {
      switch (secim) {
        case _KanalMesajIslemi.sil:
          final onay = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(m.sohbet_mesaj_sil_onay_baslik),
              content: Text(m.sohbet_mesaj_sil_onay_aciklama),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(m.sohbet_vazgec),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(m.sohbet_mesaj_sil),
                ),
              ],
            ),
          );
          if (onay != true) return;
          await notifier.sil(mesaj.id);
        case _KanalMesajIslemi.geriAl:
          await notifier.geriAl(mesaj.id);
      }
    } on Exception catch (hata) {
      if (context.mounted) hataBildir(context, hata);
    }
  }
}

enum _KanalMesajIslemi { sil, geriAl }

/// Kuyruktaki kendi mesajın: gönderiliyorsa saat ikonu, gönderilemediyse
/// nar kenarlı balon ve "Tekrar dene" / "Sil".
class _BekleyenMesaj extends ConsumerWidget {
  const _BekleyenMesaj({super.key, required this.oge});

  final KuyrukOgesi oge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final isi = oge.isi;
    final metin = isi is KanalMesajIsi ? isi.metin : '';
    final basarisiz = oge.durum == KuyrukDurumu.gonderilemedi;
    final kuyruk = ref.read(cevrimdisiKuyrukProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SohbetBalonu(
            metin: metin,
            giden: true,
            tur: basarisiz ? BalonTuru.gonderilemedi : BalonTuru.akis,
          ),
          if (basarisiz)
            GonderilemediSatiri(
              durum: m.sohbet_mesaj_gonderilemedi,
              tekrarDene: m.sohbet_tekrar_dene,
              sil: m.sohbet_mesaj_sil,
              onTekrarDene: () => kuyruk.tekrarDene(oge.istekKimligi),
              onSil: () => kuyruk.sil(oge.istekKimligi),
            )
          else
            MesajAltSatiri(
              children: [
                Icon(
                  Icons.schedule,
                  size: TayfamSizes.ikonKucuk,
                  color: r.metinIkincil,
                  semanticLabel: m.sohbet_mesaj_gonderiliyor,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
