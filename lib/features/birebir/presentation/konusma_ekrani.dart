import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_okuyucu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/moduller/birebir_sikayet.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/sohbet/akis_duzeni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/features/birebir/application/konusma_notifier.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/e2e_ogeleri.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_ogeleri.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_yazma_alani.dart';
import 'package:tayfam/features/birebir/presentation/sessiz_ogeleri.dart';
import 'package:tayfam/features/cihazlar/cihazlar.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir birebir konuşma (`/sohbet/birebir/<konusmaId>`; ADR-0018 §9,
/// ADR-0020): mesaj akışı (en yeni altta), yazma alanı, okundu bilgisi,
/// mesaj isteğini kabul ve ret, kendi mesajını silme, mesaj şikâyeti ve
/// üst menüde sessize alma.
///
/// Ekran açıkken konuşma okundu işaretlenir. Yeni mesajlar WebSocket
/// olaylarıyla gelir; bağlantı yokken ekran açık ve uygulama ön plandayken
/// aralıklarla REST'ten okunur ([birebirYenilemeAraligiProvider]).
class KonusmaEkrani extends ConsumerStatefulWidget {
  const KonusmaEkrani({super.key, required this.konusmaId});

  /// Adresteki konuşma kimliği (biçimi yönlendiricide doğrulandı).
  final String konusmaId;

  @override
  ConsumerState<KonusmaEkrani> createState() => _KonusmaEkraniState();
}

class _KonusmaEkraniState extends ConsumerState<KonusmaEkrani> {
  Timer? _zamanlayici;
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    _dinleyici = AppLifecycleListener(onResume: _yeniler);
    _zamanlayici = Timer.periodic(
      ref.read(birebirYenilemeAraligiProvider),
      (_) => _onPlandaysaYeniler(),
    );
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _dinleyici.dispose();
    super.dispose();
  }

  /// WebSocket açıkken olaylar yeterlidir; kapalıyken (web geliştirme
  /// derlemesi, kopuk bağlantı) ön plandaysa REST'ten okunur.
  void _onPlandaysaYeniler() {
    if (ref.read(realtimeIstemcisiProvider).durum == RealtimeDurumu.acik) {
      return;
    }
    final durum = WidgetsBinding.instance.lifecycleState;
    if (durum == null || durum == AppLifecycleState.resumed) _yeniler();
  }

  void _yeniler() =>
      unawaited(ref.read(konusmaProvider(widget.konusmaId).notifier).yeniler());

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = konusmaProvider(widget.konusmaId);
    // Ekran açıkken gelen her yeni durumda okundu işareti ilerletilir.
    ref.listen(saglayici, (_, sonraki) {
      if (sonraki.hasValue) {
        unawaited(ref.read(saglayici.notifier).okunduIsaretle());
      }
    });
    final durum = ref.watch(saglayici);
    final veri = durum.value;
    final hata = durum.error;
    // Şifreli geçmiş arşivi konuşma açılınca indirilir ve ekran açık
    // kaldıkça bellekte tutulur (ADR-0020 §3). E2E yoksa (web, iOS)
    // istenmez.
    final e2e = ref.watch(e2eEtkinProvider);
    final arsiv = konusmaArsiviProvider(widget.konusmaId);
    final eskiOkunamiyor = e2e && ref.watch(arsiv.select(_eskiOkunamiyor));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: sohbetUstCubukYuksekligi(context),
        shape: Border(
          bottom: BorderSide(
            color: context.renkler.cizgi,
            width: TayfamSizes.kenar,
          ),
        ),
        title: veri == null
            ? null
            : KonusmaBasligi(kullaniciId: veri.konusma.otherUserId),
        actions: [
          if (veri != null)
            KonusmaMenusu(
              konusmaId: widget.konusmaId,
              karsiId: veri.konusma.otherUserId,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: switch ((veri, hata)) {
          (final KonusmaDurumu veri, _) => _Akis(
            konusmaId: widget.konusmaId,
            durum: veri,
            eskiOkunamiyor: eskiOkunamiyor,
          ),
          (null, final Object hata) => ListView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            children: [
              HataSatiri.hatadan(hata),
              BirebirTekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ],
          ),
          _ => BirebirYukleniyor(etiket: m.birebir_konusma_yukleniyor),
        },
      ),
    );
  }
}

bool _eskiOkunamiyor(AsyncValue<KonusmaArsivi> arsiv) =>
    arsiv.value?.eskiMesajlarOkunamiyor ?? false;

class _Akis extends ConsumerWidget {
  const _Akis({
    required this.konusmaId,
    required this.durum,
    required this.eskiOkunamiyor,
  });

  final String konusmaId;

  final KonusmaDurumu durum;

  /// Arşivde bu cihazda okunamayan eski mesajlar var (ya da cihaz
  /// eşleştirilmemiş).
  final bool eskiOkunamiyor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final notifier = ref.read(konusmaProvider(konusmaId).notifier);
    final konusma = durum.konusma;
    final gorulen = durum.gorulenGidenId;
    final alici = konusma.otherUserId;
    final e2e = ref.watch(e2eEtkinProvider);
    final icerik = ref.watch(birebirIcerikProvider);
    final giden = alici == null
        ? const <GidenMesaj>[]
        : ref.watch(bekleyenBirebirProvider(alici));
    // E2E'nin olmadığı derlemede şifreli konuşmaya yazılamaz (ADR-0020).
    final yalnizcaMobil = !e2e && durum.sifreliVar;
    final simdi = ref.read(birebirSaatiProvider)();
    // Mesajlar ve E2E sistem satırları, eskiden yeniye; liste ters
    // çizildiği için sonra çevrilir.
    final girdiler = <_AkisOgesi>[
      for (final mesaj in durum.mesajlar)
        (zaman: mesaj.createdAt, mesaj: mesaj, satir: null),
      if (e2e)
        for (final satir in icerik.satirlar(konusmaId, alici))
          (zaman: satir.zaman, mesaj: null, satir: satir),
    ]..sort((a, b) => a.zaman.compareTo(b.zaman));
    final duzen = akisDuzeni([
      for (final g in girdiler)
        switch (g.mesaj) {
          final mesaj? => AkisGirdisi(
            zaman: g.zaman,
            yazar: durum.gidenMi(mesaj) ? _gidenYazar : _gelenYazar,
          ),
          null => AkisGirdisi(zaman: g.zaman, sistem: true),
        },
    ]);
    // "Görüldü" yalnızca son kendi mesajın altında (2026-11-13 kararı).
    final sonGiden = durum.mesajlar.where(durum.gidenMi).firstOrNull?.id;
    final eskidenYeniye = <Widget>[
      ?_bant(konusma),
      if (eskiOkunamiyor)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
          child: EskiMesajlarOkunamiyor(),
        ),
      _EskiMesajlar(durum: durum, onDahaEski: notifier.dahaEski),
      for (final (sira, g) in girdiler.indexed) ...[
        if (duzen[sira].gunBasi)
          GunAyirici(metin: gunAyiriciMetni(m, g.zaman, simdi)),
        switch (g) {
          (mesaj: final mesaj?, satir: _, zaman: _) => _mesajOgesi(
            context,
            ref,
            mesaj,
            konum: duzen[sira],
            goruldu: mesaj.id == gorulen && mesaj.id == sonGiden,
            icerik: icerik,
          ),
          (satir: final satir?, mesaj: _, zaman: _) => E2eSatiriOgesi(
            key: ValueKey('e2e-${satir.kimlik}'),
            satir: satir,
          ),
          _ => const SizedBox.shrink(),
        },
      ],
      for (final g in giden)
        GidenOgesi(
          key: ValueKey('giden-${g.istekKimligi}'),
          giden: g,
          onTekrarDene: () => notifier.tekrarDene(g.istekKimligi),
          onSil: () => notifier.vazgec(g.istekKimligi),
        ),
    ];
    final ogeler = eskidenYeniye.reversed.toList();
    final istekGeldi =
        konusma.status == ConversationStatus.requestReceived &&
        konusma.otherUserId != null;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
              vertical: TayfamSpacing.s8,
            ),
            itemCount: ogeler.length,
            itemBuilder: (_, i) => ogeler[i],
          ),
        ),
        if (konusma.otherUserId != null) ...[
          // Kabul ve ret E2E gerektirmez; yalnızca mobil derlemede de var.
          if (istekGeldi) _IstekCubugu(konusmaId: konusmaId),
          if (yalnizcaMobil)
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.renkler.kart,
                border: Border(
                  top: BorderSide(
                    color: context.renkler.cizgi,
                    width: TayfamSizes.kenar,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.kenarMobil,
                  ),
                  child: E2eBilgiSatiri(
                    metin: m.e2e_yalnizca_mobil,
                    ikon: Icons.phone_android_outlined,
                  ),
                ),
              ),
            )
          else ...[
            if (e2e)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.kenarMobil,
                ),
                child: E2eCihazUyarisi(),
              ),
            MesajYazmaAlani(onGonder: notifier.gonder),
          ],
        ],
      ],
    );
  }

  /// Konuşmanın başındaki bant: gelen istek, giden istek ya da silinmiş
  /// hesap.
  Widget? _bant(Conversation konusma) {
    if (konusma.otherUserId == null) {
      return const _BilgiBandi(tur: _BantTuru.silinmis);
    }
    return switch (konusma.status) {
      ConversationStatus.requestReceived => _IstekKarti(
        karsiId: konusma.otherUserId!,
      ),
      ConversationStatus.requestSent => const _BilgiBandi(
        tur: _BantTuru.istekGonderildi,
      ),
      _ => null,
    };
  }

  Widget _mesajOgesi(
    BuildContext context,
    WidgetRef ref,
    DirectMessage mesaj, {
    required AkisKonumu konum,
    required bool goruldu,
    required BirebirIcerikDurumu icerik,
  }) {
    final m = AppLocalizations.of(context);
    final e2e = ref.watch(e2eEtkinProvider);
    final giden = durum.gidenMi(mesaj);
    // Her birebir mesaj uçtan uca şifrelidir (Tayfam-Api #151); metin
    // yalnızca bellekte çözülmüş içerikten gelir.
    final govde = icerik.mesajlar[mesaj.id]?.metin;
    final metin = govde ?? (e2e ? m.e2e_mesaj_okunamiyor : m.e2e_sifreli_mesaj);
    final sikayet = ref.watch(birebirMesajSikayetiProvider);
    final silinebilir = giden && !mesaj.deleted;
    final sikayetEdilebilir =
        !giden && !mesaj.deleted && govde != null && sikayet != null;
    return MesajOgesi(
      key: ValueKey(mesaj.id),
      mesaj: mesaj,
      metin: metin,
      giden: giden,
      goruldu: goruldu,
      kuyruk: konum.grupSonu,
      grupBasi: konum.grupBasi,
      saat: konum.grupSonu ? saatMetni(m, mesaj.createdAt) : null,
      onIslemler: silinebilir || sikayetEdilebilir
          ? () => unawaited(
              _islemler(
                context,
                ref,
                mesaj,
                govde: govde,
                silinebilir: silinebilir,
                sikayet: sikayetEdilebilir ? sikayet : null,
              ),
            )
          : null,
    );
  }

  /// Mesaj işlemleri alttan sayfası (2026-11-13 tasarım: Kanal-Islem):
  /// cihazda çözülmüş metinden kısa alıntı, kendi mesajında "Mesajı sil",
  /// gelen mesajda "Şikâyet et". Alıntı yalnızca ekrandadır; loglanmaz.
  Future<void> _islemler(
    BuildContext context,
    WidgetRef ref,
    DirectMessage mesaj, {
    required String? govde,
    required bool silinebilir,
    required BirebirMesajSikayeti? sikayet,
  }) async {
    final m = AppLocalizations.of(context);
    final secim = await altSayfaAc<_MesajIslemi>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.birebir_mesaj_islemleri,
        children: [
          if (govde != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.s8,
                0,
                TayfamSpacing.s8,
                TayfamSpacing.s8,
              ),
              child: Text(
                m.sohbet_mesaj_alinti(govde),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sayfa.yazi.bodySmall?.copyWith(
                  color: sayfa.renkler.metinIkincil,
                ),
              ),
            ),
          if (silinebilir)
            MenuSatiri(
              ikon: Icons.delete_outline,
              tur: MenuSatiriTuru.yikici,
              baslik: m.birebir_mesaji_sil,
              aciklama: m.birebir_sil_onay_aciklama,
              onTap: () => Navigator.of(sayfa).pop(_MesajIslemi.sil),
            ),
          if (sikayet != null)
            MenuSatiri(
              ikon: Icons.flag_outlined,
              baslik: m.birebir_sikayet_et,
              onTap: () => Navigator.of(sayfa).pop(_MesajIslemi.sikayet),
            ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (secim) {
      case _MesajIslemi.sil:
        await _sil(context, ref, mesaj.id);
      case _MesajIslemi.sikayet:
        if (sikayet == null || govde == null) return;
        // Şikâyet eden mesajın açık metnini kendi cihazından iletir
        // (ADR-0018 §8); metin yalnızca şikâyet isteğine girer.
        await sikayet(context, mesajId: mesaj.id, metin: govde);
      case null:
        return;
    }
  }

  Future<void> _sil(BuildContext context, WidgetRef ref, String mesajId) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (pencere) => AlertDialog(
        title: Text(m.birebir_sil_onay_baslik),
        content: Text(m.birebir_sil_onay_aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            child: Text(m.birebir_vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(true),
            child: Text(m.birebir_sil),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final hata = await ref
        .read(konusmaProvider(konusmaId).notifier)
        .sil(mesajId);
    birebirSonucunuBildir(bildirim, m, hata, m.birebir_mesaj_silindi_bildirimi);
  }
}

enum _MesajIslemi { sil, sikayet }

/// Akıştaki bir öğe: mesaj ya da E2E sistem satırı.
typedef _AkisOgesi = ({
  DateTime zaman,
  DirectMessage? mesaj,
  E2eSistemSatiri? satir,
});

/// Gruplamada iki tarafın yazar anahtarı (birebirde yalnızca iki taraf
/// vardır; kimlik gerekmez).
const String _gidenYazar = 'giden';
const String _gelenYazar = 'gelen';

/// Akışın başında daha eski mesajları okuma düğmesi, göstergesi ya da
/// hatası.
class _EskiMesajlar extends StatelessWidget {
  const _EskiMesajlar({required this.durum, required this.onDahaEski});

  final KonusmaDurumu durum;

  final Future<void> Function() onDahaEski;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    if (durum.eskiHatasi case final hata?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HataSatiri.hatadan(hata),
          BirebirTekrarDene(onPressed: () => unawaited(onDahaEski())),
        ],
      );
    }
    if (durum.eskiYukleniyor) {
      return BirebirYukleniyor(etiket: m.birebir_konusma_yukleniyor);
    }
    if (!durum.eskiVar) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: () => unawaited(onDahaEski()),
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(m.birebir_daha_eski),
      ),
    );
  }
}

enum _BantTuru { istekGonderildi, silinmis }

/// Bilgi bandı: gönderilen istek cevap bekliyor ya da hesap silinmiş.
class _BilgiBandi extends StatelessWidget {
  const _BilgiBandi({required this.tur});

  final _BantTuru tur;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final metin = switch (tur) {
      _BantTuru.istekGonderildi => m.birebir_istek_bekliyor_bilgi,
      _BantTuru.silinmis => m.birebir_silinmis_bilgi,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline,
              size: TayfamSizes.ikon,
              color: context.renkler.metinIkincil,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(child: BirebirAciklama(metin)),
        ],
      ),
    );
  }
}

/// Gelen mesaj isteği kartı (2026-11-13 tasarım: Birebir-Istek): akışın
/// en üstünde tint-brand kart, "<ad> sana mesaj isteği gönderdi" ve
/// açıklama. Kabul ve ret alt çubuktadır ([_IstekCubugu]).
class _IstekKarti extends ConsumerWidget {
  const _IstekKarti({required this.karsiId});

  final String karsiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    ref.read(kullaniciAdlariProvider.notifier).iste(karsiId);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[karsiId]),
    );
    final ad = switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.secimKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  m.birebir_istek_geldi_baslik(ad),
                  style: context.yazi.titleSmall?.copyWith(color: r.metin),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                m.birebir_istek_geldi_aciklama,
                style: context.yazi.bodySmall?.copyWith(color: r.metinGovde),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gelen mesaj isteğinin alt çubuğu (tasarım: Birebir-Istek): çerçeveli
/// "Reddet" (nar-metin) ve birincil "Kabul et". Cevap yazmak da kabul
/// sayılır (sözleşme); bu yüzden yazma alanı çubuğun altında kalır.
/// Reddedince gönderen bunu öğrenmez.
class _IstekCubugu extends ConsumerStatefulWidget {
  const _IstekCubugu({required this.konusmaId});

  final String konusmaId;

  @override
  ConsumerState<_IstekCubugu> createState() => _IstekCubuguState();
}

class _IstekCubuguState extends ConsumerState<_IstekCubugu> {
  bool _islemde = false;

  Future<void> _kabulEt() async {
    final bildirim = ScaffoldMessenger.of(context);
    final m = AppLocalizations.of(context);
    setState(() => _islemde = true);
    final hata = await ref
        .read(konusmaProvider(widget.konusmaId).notifier)
        .kabulEt();
    if (mounted) setState(() => _islemde = false);
    birebirSonucunuBildir(bildirim, m, hata);
  }

  Future<void> _reddet() async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (pencere) => AlertDialog(
        title: Text(m.birebir_reddet_onay_baslik),
        content: Text(m.birebir_reddet_onay_aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            child: Text(m.birebir_vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(true),
            child: Text(m.birebir_reddet),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _islemde = true);
    final hata = await ref
        .read(konusmaProvider(widget.konusmaId).notifier)
        .reddet();
    birebirSonucunuBildir(bildirim, m, hata, m.birebir_reddedildi);
    if (!mounted) return;
    setState(() => _islemde = false);
    if (hata == null) context.go(Adresler.mesajIstekleri);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s12,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s4,
        ),
        child: Row(
          children: [
            Expanded(
              child: YikiciEylem(
                etiket: m.birebir_reddet,
                onPressed: _islemde ? null : () => unawaited(_reddet()),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: BirincilEylem(
                etiket: m.birebir_kabul_et,
                onPressed: _islemde ? null : () => unawaited(_kabulEt()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Konuşma ekranının üst çubuğundaki başlık (2026-11-13 tasarım:
/// Birebir-Konusma): avatar, ad ve altında kilit + "Uçtan uca şifreli".
/// Dokununca karşı tarafın profili açılır; hesap silinmişse dokunulmaz.
class KonusmaBasligi extends StatelessWidget {
  const KonusmaBasligi({super.key, required this.kullaniciId});

  /// Karşı tarafın kimliği; hesabı silinmişse `null`.
  final String? kullaniciId;

  @override
  Widget build(BuildContext context) {
    final kimlik = kullaniciId;
    final r = context.renkler;
    final icerik = Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Row(
        children: [
          KimlikAvatari(kullaniciId: kimlik, cap: TayfamSizes.ustCubukKutusu),
          const SizedBox(width: TayfamSpacing.s12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                KarsiTarafAdi(
                  kullaniciId: kimlik,
                  style: context.yazi.titleMedium,
                  maxLines: 1,
                ),
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: TayfamSizes.ikonKucuk,
                        color: r.metinIkincil,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s4),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context).bilesen_uctan_uca_sifreli,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.yazi.bodySmall?.copyWith(
                          color: r.metinIkincil,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (kimlik == null) return icerik;
    return Semantics(
      button: true,
      onTapHint: AppLocalizations.of(context).birebir_profili_gor,
      child: InkWell(
        borderRadius: TayfamRadii.dugmeKoseleri,
        onTap: () => unawaited(context.push(Adresler.kisi(kimlik))),
        child: icerik,
      ),
    );
  }
}
