import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/sohbet/application/kanal_akisi_notifier.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/data/kanal_mesaj_isi.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_formu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir kanalın mesaj akışı (`/sohbet/kanal/<tayfaId>/<kanalId>`;
/// ADR-0018 §9): metin, silme, yavaş mod göstergesi, okundu işaretleme.
///
/// - Bekleyen (kuyruktaki) mesaj saat ikonuyla, gönderilemeyen uyarı
///   ikonuyla gösterilir; gönderilemeyende "Tekrar dene" ve "Sil" vardır
///   (ADR-0006).
/// - Yavaş modda gönder düğmesi geri sayım gösterir (ADR-0007); yönetim
///   muaftır (sunucu söyler; istemci yalnızca sadeleştirir).
/// - Kanala erişim kalmazsa kanal listesine dönülür.
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
    final saglayici = kanalAkisiProvider(_kanal);
    final kanallar = ref.watch(kanallarProvider(widget.tayfaId));
    final kanal = _bul(kanallar.value);
    final yonetimde = ref.watch(tayfaOzetiProvider(widget.tayfaId)).yonetimde;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(kanal?.name ?? ''),
        actions: [
          if (yonetimde && kanal != null)
            IconButton(
              tooltip: m.sohbet_kanal_ayarlari,
              icon: const Icon(Icons.tune),
              onPressed: () => unawaited(
                kanalFormunuAc(context, tayfaId: widget.tayfaId, kanal: kanal),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if ((kanal?.slowModeSeconds ?? 0) > 0)
              _BilgiSeridi(
                ikon: Icons.timer_outlined,
                metin: m.sohbet_yavas_mod_bilgi(kanal!.slowModeSeconds),
              ),
            Expanded(
              child: switch (durum) {
                AsyncValue(value: final akis?) => _MesajListesi(
                  kanal: _kanal,
                  akis: akis,
                  bekleyenler: bekleyenler,
                  yonetimde: yonetimde,
                ),
                AsyncValue(error: final hata?) => Padding(
                  padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HataSatiri.hatadan(hata),
                      TextButton(
                        onPressed: () => ref.invalidate(saglayici),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.square(
                            TayfamSizes.dokunmaMin,
                          ),
                        ),
                        child: Text(m.sohbet_tekrar_dene),
                      ),
                    ],
                  ),
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
              _BilgiSeridi(
                ikon: Icons.inventory_2_outlined,
                metin: m.sohbet_arsiv_bilgi,
              )
            else
              _YazmaAlani(
                denetleyici: _metin,
                bekleSaniye: bekle,
                onGonder: () => _gonder(kanal, yonetimde),
              ),
          ],
        ),
      ),
    );
  }
}

class _BilgiSeridi extends StatelessWidget {
  const _BilgiSeridi({required this.ikon, required this.metin});

  final IconData ikon;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ColoredBox(
      color: r.tintMarka,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.kenarMobil,
          vertical: TayfamSpacing.s8,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(ikon, size: TayfamSizes.ikon, color: r.tintMarkaUstu),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: Text(
                metin,
                style: context.yazi.bodySmall?.copyWith(color: r.tintMarkaUstu),
              ),
            ),
          ],
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
    final ogeler = <Widget>[
      for (final o in bekleyenler.reversed)
        _BekleyenMesaj(key: ValueKey(o.istekKimligi), oge: o),
      for (final mesaj in akis.mesajlar)
        _MesajSatiri(
          key: ValueKey(mesaj.id),
          kanal: kanal,
          mesaj: mesaj,
          yonetimde: yonetimde,
        ),
      if (akis.eskiHatasi case final hata?)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
          child: HataSatiri.hatadan(hata),
        ),
      if (akis.eskiYukleniyor)
        Center(child: TayfamYukleniyor(etiket: m.sohbet_mesajlar_yukleniyor))
      else if (akis.eskiSayfa != null)
        Center(
          child: TextButton(
            onPressed: () => unawaited(
              ref.read(kanalAkisiProvider(kanal).notifier).eskileriYukle(),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.sohbet_daha_eski),
          ),
        ),
    ];
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      itemCount: ogeler.length,
      separatorBuilder: (_, _) => const SizedBox(height: TayfamSpacing.s8),
      itemBuilder: (_, i) => ogeler[i],
    );
  }
}

class _MesajSatiri extends ConsumerWidget {
  const _MesajSatiri({
    super.key,
    required this.kanal,
    required this.mesaj,
    required this.yonetimde,
  });

  final KanalRef kanal;
  final ChannelMessage mesaj;
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
    final ben = bilinen?.ben ?? false;
    final gonderen = switch (bilinen) {
      _ when yazar == null => m.kullanici_silinmis,
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    final silinebilir = !mesaj.deleted && (ben || yonetimde);
    final geriAlinabilir = mesaj.deleted && (mesaj.restorable ?? false);

    final Widget icerik;
    final body = mesaj.body;
    if (mesaj.deleted || body == null) {
      icerik = Align(
        alignment: ben
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Text(
          m.sohbet_mesaj_silindi,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinIkincil,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else {
      icerik = SohbetBalonu(
        metin: body,
        giden: ben,
        gonderen: ben ? null : gonderen,
      );
    }
    if (!silinebilir && !geriAlinabilir) return icerik;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => unawaited(
        _eylemler(context, ref, sil: silinebilir, geriAl: geriAlinabilir),
      ),
      child: icerik,
    );
  }

  Future<void> _eylemler(
    BuildContext context,
    WidgetRef ref, {
    required bool sil,
    required bool geriAl,
  }) async {
    final m = AppLocalizations.of(context);
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sil)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(m.sohbet_mesaj_sil),
                onTap: () => Navigator.of(context).pop('sil'),
              ),
            if (geriAl)
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(m.sohbet_mesaj_geri_al),
                onTap: () => Navigator.of(context).pop('geri'),
              ),
          ],
        ),
      ),
    );
    if (secim == null || !context.mounted) return;
    final notifier = ref.read(kanalAkisiProvider(kanal).notifier);
    try {
      if (secim == 'sil') {
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
      } else {
        await notifier.geriAl(mesaj.id);
      }
    } on Exception catch (hata) {
      if (context.mounted) hataBildir(context, hata);
    }
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SohbetBalonu(metin: metin, giden: true),
        const SizedBox(height: TayfamSpacing.s4),
        if (basarisiz)
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TayfamSpacing.s8,
            children: [
              Icon(
                Icons.error_outline,
                size: TayfamSizes.ikonKucuk,
                color: r.metin,
              ),
              Text(
                m.sohbet_mesaj_gonderilemedi,
                style: context.yazi.bodySmall?.copyWith(color: r.metin),
              ),
              TextButton(
                onPressed: () => kuyruk.tekrarDene(oge.istekKimligi),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.sohbet_tekrar_dene),
              ),
              TextButton(
                onPressed: () => kuyruk.sil(oge.istekKimligi),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.sohbet_mesaj_sil),
              ),
            ],
          )
        else
          Icon(
            Icons.schedule,
            size: TayfamSizes.ikonKucuk,
            color: r.metinIkincil,
            semanticLabel: m.sohbet_mesaj_gonderiliyor,
          ),
      ],
    );
  }
}

class _YazmaAlani extends StatelessWidget {
  const _YazmaAlani({
    required this.denetleyici,
    required this.bekleSaniye,
    required this.onGonder,
  });

  final TextEditingController denetleyici;
  final int bekleSaniye;
  final VoidCallback onGonder;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        border: Border(top: BorderSide(color: r.cizgi)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s8,
          vertical: TayfamSpacing.s8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: denetleyici,
                minLines: 1,
                maxLines: 5,
                maxLength: mesajEnUzun,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: m.sohbet_mesaj_ipucu),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            if (bekleSaniye > 0)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TayfamSizes.dokunmaMin,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    m.sohbet_gonder_bekle(bekleSaniye),
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinIkincil,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                tooltip: m.sohbet_gonder,
                onPressed: onGonder,
                icon: const Icon(Icons.send),
              ),
          ],
        ),
      ),
    );
  }
}
