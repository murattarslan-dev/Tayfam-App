import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/application/qr_tarama_notifier.dart';
import 'package:tayfam/features/cihazlar/data/ayarlar_acici.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_tarayici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Cihaz bağla" (eşleştirilmiş cihaz): yeni telefondaki QR'ı okutur,
/// doğrular ve geçmiş anahtarlarını şifreli gönderir.
///
/// Kamera yalnızca bu ekranda ve tarama durumundayken açılır; izin de
/// ilk kez burada istenir. Reddedilirse kamera izni ekranı ve (iOS'ta)
/// ayarlara gitme düğmesi gösterilir. Kamera görüntüsü kaydedilmez ve
/// loglanmaz.
class CihazBaglaEkrani extends ConsumerWidget {
  const CihazBaglaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(qrTaramaProvider);
    final notifier = ref.read(qrTaramaProvider.notifier);
    return CihazBaglaGorunumu(
      durum: durum,
      ayarlar: ref.watch(ayarlarAciciProvider),
      tekrarTara: notifier.tekrarTara,
      kamera: durum is QrTaraniyor
          ? ref.watch(qrTarayiciProvider)(
              kodOkundu: (metin) => unawaited(notifier.kodOkundu(metin)),
              izinReddedildi: notifier.izinReddedildi,
              acilamadi: notifier.kameraAcilamadi,
            )
          : null,
    );
  }
}

/// "Cihaz bağla" ekranının [durum]'a göre görünümü: tarama ve işleme koyu
/// tam ekran kamera görünümünde (tasarım: Cihaz-Tara), sonuçlar ve kamera
/// izni ayrı ekranlarda (Cihaz-Basarili, Cihaz-Hata, Cihaz-Kamera-Izni).
class CihazBaglaGorunumu extends StatelessWidget {
  const CihazBaglaGorunumu({
    super.key,
    required this.durum,
    required this.ayarlar,
    required this.tekrarTara,
    this.kamera,
  });

  final QrTaramaDurumu durum;
  final AyarlarAcici ayarlar;
  final VoidCallback tekrarTara;

  /// Kamera önizlemesi; yalnızca tarama durumunda verilir.
  final Widget? kamera;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    void kapat() => unawaited(Navigator.of(context).maybePop());
    final tekrar = BirincilEylem(
      etiket: m.cihaz_tara_tekrar,
      ikon: Icons.qr_code_scanner,
      onPressed: tekrarTara,
    );
    return switch (durum) {
      QrTaraniyor() => _TaramaGorunumu(kamera: kamera),
      QrIsleniyor() => const _TaramaGorunumu(isleniyor: true),
      QrGonderildi() => CihazSonucEkrani(
        ton: CihazSonucTonu.basarili,
        baslik: m.cihaz_tara_basarili,
        aciklama: m.cihaz_tara_basarili_aciklama,
        eylemler: [BirincilEylem(etiket: m.cihaz_tamam, onPressed: kapat)],
      ),
      QrKameraIzniYok() => CihazSonucEkrani(
        ton: CihazSonucTonu.izin,
        ustBaslik: m.cihaz_bagla_baslik,
        baslik: m.cihaz_kamera_izin_baslik,
        aciklama: m.cihaz_kamera_izin_aciklama,
        // Android'de uygulama ayarları açılamaz; yol metinde anlatılır
        // (ADR-0020 §7).
        eylemler: ayarlar.destekleniyor
            ? [
                BirincilEylem(
                  etiket: m.cihaz_ayarlari_ac,
                  ikon: Icons.settings_outlined,
                  onPressed: () => unawaited(ayarlar.ac()),
                ),
                CihazIkincilEylem(
                  etiket: m.cihaz_tara_tekrar,
                  onPressed: tekrarTara,
                ),
              ]
            : [tekrar],
      ),
      QrKameraAcilamadi() => CihazSonucEkrani(
        ton: CihazSonucTonu.hata,
        baslik: m.cihaz_hata_baslik,
        aciklama: m.cihaz_kamera_hatasi,
        eylemler: [
          tekrar,
          CihazIkincilEylem(etiket: m.cihaz_kapat, onPressed: kapat),
        ],
      ),
      QrTaramaHatasi(:final hata) => CihazSonucEkrani(
        ton: CihazSonucTonu.hata,
        baslik: m.cihaz_hata_baslik,
        aciklama: cihazHataMetni(m, hata),
        eylemler: [
          tekrar,
          CihazIkincilEylem(etiket: m.cihaz_kapat, onPressed: kapat),
        ],
      ),
    };
  }
}

/// Koyu tam ekran tarayıcı: arkada kamera, mango köşeli çerçeve ve tarama
/// çizgisi, altında talimat ve kamera gizlilik notu. Tema ne olursa olsun
/// koyu temanın token'larıyla çizilir. [isleniyor] ise kamera kapalıdır ve
/// çerçevenin içinde yükleniyor gösterilir.
class _TaramaGorunumu extends StatelessWidget {
  const _TaramaGorunumu({this.kamera, this.isleniyor = false});

  final Widget? kamera;
  final bool isleniyor;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Theme(
      data: TayfamTheme.koyu(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Builder(
          builder: (context) {
            final r = context.renkler;
            final kamera = this.kamera;
            return Scaffold(
              backgroundColor: r.zemin,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  ?kamera,
                  // Çerçevenin dışını karartır (tasarımdaki radyal geçiş).
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -.15),
                          radius: .9,
                          colors: [
                            r.zemin.withValues(alpha: 0),
                            r.zemin.withValues(alpha: .9),
                          ],
                          stops: const [.45, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, kisit) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: kisit.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _UstCubuk(baslik: m.cihaz_bagla_baslik),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: TayfamSpacing.s24,
                                  vertical: TayfamSpacing.s24,
                                ),
                                child: Column(
                                  children: [
                                    TaramaCercevesi(isleniyor: isleniyor),
                                    const SizedBox(height: TayfamSpacing.s40),
                                    Semantics(
                                      liveRegion: isleniyor,
                                      child: Text(
                                        isleniyor
                                            ? m.cihaz_tara_isleniyor
                                            : m.cihaz_tara_baslik,
                                        textAlign: TextAlign.center,
                                        style: context.yazi.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(height: TayfamSpacing.s8),
                                    Text(
                                      m.cihaz_tara_talimat,
                                      textAlign: TextAlign.center,
                                      style: context.yazi.bodyMedium?.copyWith(
                                        color: r.metinGovde,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  TayfamSpacing.s20,
                                  0,
                                  TayfamSpacing.s20,
                                  TayfamSpacing.s24,
                                ),
                                child: _GizlilikNotu(
                                  metin: m.cihaz_kamera_gizlilik,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Kamera görünümünün üst çubuğu: yarı saydam daire içinde geri düğmesi
/// ve başlık.
class _UstCubuk extends StatelessWidget {
  const _UstCubuk({required this.baslik});

  final String baslik;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s8,
        vertical: TayfamSpacing.s4,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => unawaited(Navigator.of(context).maybePop()),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            style: IconButton.styleFrom(
              backgroundColor: r.metin.withValues(alpha: .12),
              foregroundColor: r.metin,
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(baslik, style: context.yazi.headlineSmall),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mango köşeli tarama çerçevesi ve içinde yukarı aşağı gezen tarama
/// çizgisi. "Hareketi azalt" açıkken çizgi ortada durur. [isleniyor] ise
/// çizgi yerine yükleniyor gösterilir. Süstür; ekran okuyucu atlar.
class TaramaCercevesi extends StatefulWidget {
  const TaramaCercevesi({super.key, this.isleniyor = false});

  final bool isleniyor;

  @override
  State<TaramaCercevesi> createState() => _TaramaCercevesiState();
}

class _TaramaCercevesiState extends State<TaramaCercevesi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cizgi = AnimationController(
    vsync: this,
    duration: TayfamMotion.taramaCizgisi,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _oynat();
  }

  @override
  void didUpdateWidget(TaramaCercevesi eski) {
    super.didUpdateWidget(eski);
    _oynat();
  }

  void _oynat() {
    if (widget.isleniyor || MediaQuery.disableAnimationsOf(context)) {
      _cizgi
        ..stop()
        ..value = .5;
    } else if (!_cizgi.isAnimating) {
      unawaited(_cizgi.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _cizgi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final m = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, kisit) {
        final kenar = kisit.maxWidth < TayfamSizes.taramaCercevesi
            ? kisit.maxWidth
            : TayfamSizes.taramaCercevesi;
        final kose = BorderSide(
          color: r.mango,
          width: TayfamSizes.taramaKenari,
        );
        const yaricap = Radius.circular(TayfamRadii.taramaKosesi);
        Widget parca(Alignment hiza, Border kenarlar, BorderRadius koseler) =>
            Align(
              alignment: hiza,
              child: Container(
                width: TayfamSizes.taramaKosesi,
                height: TayfamSizes.taramaKosesi,
                decoration: BoxDecoration(
                  border: kenarlar,
                  borderRadius: koseler,
                ),
              ),
            );
        return SizedBox.square(
          dimension: kenar,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: Stack(
                  children: [
                    parca(
                      Alignment.topLeft,
                      Border(top: kose, left: kose),
                      const BorderRadius.only(topLeft: yaricap),
                    ),
                    parca(
                      Alignment.topRight,
                      Border(top: kose, right: kose),
                      const BorderRadius.only(topRight: yaricap),
                    ),
                    parca(
                      Alignment.bottomLeft,
                      Border(bottom: kose, left: kose),
                      const BorderRadius.only(bottomLeft: yaricap),
                    ),
                    parca(
                      Alignment.bottomRight,
                      Border(bottom: kose, right: kose),
                      const BorderRadius.only(bottomRight: yaricap),
                    ),
                  ],
                ),
              ),
              // Durumun metni çerçevenin altındaki başlıktadır.
              if (widget.isleniyor)
                Center(
                  child: ExcludeSemantics(
                    child: TayfamYukleniyor(
                      boyut: TayfamSizes.ikonKutusu,
                      zemin: r.zemin,
                      etiket: m.cihaz_tara_isleniyor,
                    ),
                  ),
                )
              else
                ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _cizgi,
                    builder: (context, _) => Align(
                      alignment: Alignment(0, _cizgi.value * 1.6 - .8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TayfamSpacing.s20,
                        ),
                        child: Container(
                          key: const ValueKey('tarama-cizgisi'),
                          height: TayfamSizes.taramaCizgisi,
                          decoration: BoxDecoration(
                            color: r.mango.withValues(alpha: .7),
                            borderRadius: TayfamRadii.hapKoseleri,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Kamera görünümünün altındaki gizlilik notu: yarı saydam kutu, kalkan
/// ikonu.
class _GizlilikNotu extends StatelessWidget {
  const _GizlilikNotu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: r.metin.withValues(alpha: .1),
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.verified_user_outlined,
              size: TayfamSizes.ikonOrta,
              color: r.metinGovde,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.labelSmall?.copyWith(color: r.metinGovde),
            ),
          ),
        ],
      ),
    );
  }
}
