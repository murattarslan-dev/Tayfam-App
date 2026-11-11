import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/birebir_sikayet.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/features/birebir/application/konusma_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/e2e_ogeleri.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_ogeleri.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_yazma_alani.dart';
import 'package:tayfam/features/birebir/presentation/sessiz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir birebir konuşma (`/sohbet/birebir/<konusmaId>`; ADR-0018 §9, düz
/// sürüm): mesaj akışı (en yeni altta), yazma alanı, okundu bilgisi,
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
    return Scaffold(
      appBar: AppBar(
        title: veri == null
            ? null
            : KarsiTarafAdi(kullaniciId: veri.konusma.otherUserId),
        actions: [
          if (veri != null) KonusmaSessizMenusu(konusmaId: widget.konusmaId),
        ],
      ),
      body: SafeArea(
        child: switch ((veri, hata)) {
          (final KonusmaDurumu veri, _) => _Akis(
            konusmaId: widget.konusmaId,
            durum: veri,
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

class _Akis extends ConsumerWidget {
  const _Akis({required this.konusmaId, required this.durum});

  final String konusmaId;

  final KonusmaDurumu durum;

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
        : ref.watch(bekleyenBirebirProvider(alici)).reversed.toList();
    // Web geliştirme derlemesinde şifreli konuşmaya yazılamaz (ADR-0020).
    final yalnizcaMobil =
        !e2e &&
        (durum.sifreliVar ||
            giden.any(
              (g) => switch (g.hata) {
                ApiProblem(type: ProblemType.e2eRequired) => true,
                _ => false,
              },
            ));
    // Mesajlar ve E2E sistem satırları, en yeni önce.
    final akis = <(DateTime, Widget)>[
      for (final mesaj in durum.mesajlar)
        (
          mesaj.createdAt,
          _mesajOgesi(context, ref, mesaj, gorulen: gorulen, icerik: icerik),
        ),
      if (e2e)
        for (final satir in icerik.satirlar(konusmaId, alici))
          (
            satir.zaman,
            E2eSatiriOgesi(key: ValueKey('e2e-${satir.kimlik}'), satir: satir),
          ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final ogeler = <Widget>[
      for (final g in giden)
        GidenOgesi(
          key: ValueKey('giden-${g.istekKimligi}'),
          giden: g,
          onTekrarDene: () => notifier.tekrarDene(g.istekKimligi),
          onSil: () => notifier.vazgec(g.istekKimligi),
        ),
      for (final (_, oge) in akis) oge,
      _EskiMesajlar(durum: durum, onDahaEski: notifier.dahaEski),
      if (e2e && durum.duzVar)
        E2eBilgiSatiri(
          metin: m.e2e_sifreli_degil_aciklama,
          ikon: Icons.lock_open_outlined,
        ),
      ?_bant(konusma),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
              vertical: TayfamSpacing.s8,
            ),
            children: ogeler,
          ),
        ),
        if (konusma.otherUserId != null) ...[
          const Divider(height: TayfamSizes.kenar),
          if (yalnizcaMobil)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
              ),
              child: E2eBilgiSatiri(
                metin: m.e2e_yalnizca_mobil,
                ikon: Icons.phone_android_outlined,
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
      ConversationStatus.requestReceived => _IstekBandi(konusmaId: konusmaId),
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
    required String? gorulen,
    required BirebirIcerikDurumu icerik,
  }) {
    final m = AppLocalizations.of(context);
    final e2e = ref.watch(e2eEtkinProvider);
    final giden = durum.gidenMi(mesaj);
    final sifreli = mesaj.encryption == DirectMessageEncryption.e2e;
    // Şifreli mesajın metni yalnızca bellekte çözülmüş içerikten gelir.
    final cozulmus = sifreli ? icerik.mesajlar[mesaj.id]?.metin : null;
    final govde = sifreli ? cozulmus : mesaj.body;
    final metin = sifreli && cozulmus == null
        ? (e2e ? m.e2e_mesaj_okunamiyor : m.e2e_sifreli_mesaj)
        : govde;
    final sikayet = ref.watch(birebirMesajSikayetiProvider);
    final silinebilir = giden && !mesaj.deleted;
    final sikayetEdilebilir =
        !giden && !mesaj.deleted && govde != null && sikayet != null;
    return MesajOgesi(
      key: ValueKey(mesaj.id),
      mesaj: mesaj,
      metin: metin,
      giden: giden,
      goruldu: mesaj.id == gorulen,
      sifreliDegil: e2e && mesaj.encryption == DirectMessageEncryption.server,
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

  Future<void> _islemler(
    BuildContext context,
    WidgetRef ref,
    DirectMessage mesaj, {
    required String? govde,
    required bool silinebilir,
    required BirebirMesajSikayeti? sikayet,
  }) async {
    final m = AppLocalizations.of(context);
    final secim = await showModalBottomSheet<_MesajIslemi>(
      context: context,
      showDragHandle: true,
      builder: (sayfa) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (silinebilir)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(m.birebir_mesaji_sil),
                  onTap: () => Navigator.of(sayfa).pop(_MesajIslemi.sil),
                ),
              if (sikayet != null)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(m.birebir_sikayet_et),
                  onTap: () => Navigator.of(sayfa).pop(_MesajIslemi.sikayet),
                ),
            ],
          ),
        ),
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

/// Gelen mesaj isteği bandı: açıklama, "Kabul et" ve "Reddet". Cevap
/// yazmak da kabul sayılır (sözleşme). Reddedince gönderen bunu öğrenmez.
class _IstekBandi extends ConsumerStatefulWidget {
  const _IstekBandi({required this.konusmaId});

  final String konusmaId;

  @override
  ConsumerState<_IstekBandi> createState() => _IstekBandiState();
}

class _IstekBandiState extends ConsumerState<_IstekBandi> {
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintMarka,
          borderRadius: TayfamRadii.kartKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.birebir_istek_geldi_bilgi,
                style: context.yazi.bodyMedium?.copyWith(
                  color: r.tintMarkaUstu,
                ),
              ),
              const SizedBox(height: TayfamSpacing.s12),
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  BirincilEylem(
                    etiket: m.birebir_kabul_et,
                    onPressed: _islemde ? null : () => unawaited(_kabulEt()),
                  ),
                  IkincilEylem(
                    etiket: m.birebir_reddet,
                    onPressed: _islemde ? null : () => unawaited(_reddet()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
