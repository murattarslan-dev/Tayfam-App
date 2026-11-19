import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Hedef çubuğu bileşeni (`goal`; Tayfam-Api ADR-0025 §4, §5, #246; App
/// ADR-0024 §3): etkinliğin ölçümlerinden birine (tanımdaki `measure`
/// parametresi) konmuş hedef ve ona doğru ilerleme ("40 / 100 kg, %40").
///
/// - Hedef bağlı ölçümün birimindedir. Tanım varsayılan hedef verebilir
///   (`default_target`); organizatör, moderatör ve yönetici etkinliğe
///   kendi hedefini koyar, değiştirir ya da kaldırır (varsayılan geri
///   gelir).
/// - İlerleme sunucuda bağlı ölçümün kaydedilmiş değerinden hesaplanır;
///   önerilen değer sayılmaz. Bağlı ölçüm değişince hedef de yeniden
///   okunur (canlı olay ölçümün anahtarıyla gelir).
/// - Hassas ölçümde değerleri göremeyene ilerleme gösterilmez, nedeni
///   yazılır (`progress_hidden`). İsteğe bağlı ölçüm kapalıysa ilerleme
///   yoktur.
///
/// İlerleme yalnızca renkle anlatılmaz: sayı ve yüzde yazılıdır, çubuk
/// ekran okuyucuya tek bir etiketle okunur; hedefe ulaşınca ikon ve metin
/// de görünür. Düğmeleri gizlemek kolaylıktır; yetkiyi sunucu verir
/// (kesin kural 5). Hedef etkinlik oluşturulurken yazılmaz; sihirbazda form
/// bölümü yoktur. Etkinlik kartındaki satır ([ozetSatiri]) liste yanıtı
/// bileşen verisi taşımadığı için çizilmez (ADR-0024 Notlar).
final class HedefBileseni extends KayitliBilesen {
  const HedefBileseni() : super('goal');

  @override
  String ad(AppLocalizations m) => m.bilesen_goal_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return HedefBolumu(
      kimlik: (
        tayfaId: tayfaId,
        etkinlikId: etkinlik.id,
        anahtar: b.anahtar,
        olcumAnahtari: b.params.metin('measure'),
      ),
      tanim: b.tanim,
    );
  }
}

/// Hedef bileşeninin detaydaki bölümü: başlık ve hedef kartı. Okunurken yer
/// tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class HedefBolumu extends ConsumerStatefulWidget {
  const HedefBolumu({super.key, required this.kimlik, required this.tanim});

  final HedefKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  @override
  ConsumerState<HedefBolumu> createState() => _HedefBolumuState();
}

class _HedefBolumuState extends ConsumerState<HedefBolumu> {
  bool _mesgul = false;

  HedefNotifier get _notifier =>
      ref.read(hedefProvider(widget.kimlik).notifier);

  Future<void> _formuAc(EventGoal hedef) => aracFormuAc<void>(
    context,
    (_) => HedefFormu(hedef: hedef, gonder: _notifier.hedefiKoy),
  );

  Future<void> _kaldir(EventGoal hedef) async {
    final m = AppLocalizations.of(context);
    final varsayilan = hedef.defaultTarget;
    final onay = await cikarmaOnayi(
      context,
      baslik: varsayilan == null
          ? m.bilesen_goal_kaldir_onay
          : m.bilesen_goal_varsayilana_don_onay(
              hedefDegeriMetni(m, hedef, varsayilan),
            ),
      eylem: varsayilan == null
          ? m.bilesen_goal_kaldir
          : m.bilesen_goal_varsayilana_don,
    );
    if (!onay || !mounted || _mesgul) return;
    setState(() => _mesgul = true);
    final hata = await _notifier.hedefiKaldir();
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_goal_ad,
    );
    final okunan = ref.watch(hedefProvider(widget.kimlik));
    final hedef = okunan.value;
    if (hedef == null) {
      if (!okunan.hasError) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          HataSatiri.hatadan(okunan.error!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.etkinlik_tekrar_dene,
              onPressed: () => unawaited(_notifier.yenile()),
            ),
          ),
        ],
      );
    }
    final eylemler = <Widget>[
      if (hedef.callerCanEdit && hedef.target == null)
        CerceveliHapEylem(
          etiket: m.bilesen_goal_koy,
          ikon: Icons.add,
          onPressed: _mesgul ? null : () => unawaited(_formuAc(hedef)),
        ),
      if (hedef.callerCanEdit && hedef.target != null)
        AracIkonDugmesi(
          ipucu: m.bilesen_goal_degistir,
          ikon: Icons.edit_outlined,
          onPressed: _mesgul ? null : () => unawaited(_formuAc(hedef)),
        ),
      if (hedef.callerCanEdit && hedef.targetSet)
        AracIkonDugmesi(
          ipucu: hedef.defaultTarget == null
              ? m.bilesen_goal_kaldir
              : m.bilesen_goal_varsayilana_don,
          ikon: hedef.defaultTarget == null
              ? Icons.delete_outline
              : Icons.undo,
          onPressed: _mesgul ? null : () => unawaited(_kaldir(hedef)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        HedefKarti(hedef: hedef, eylemler: eylemler),
      ],
    );
  }
}

/// Hedefin kartı: hedef (ya da "Henüz hedef konmadı") ve sağında eylemler;
/// altında ilerleme çubuğu ya da ilerlemenin neden gösterilmediği. Dar
/// ekranda ve büyük yazıda eylemler alt satıra iner.
class HedefKarti extends StatelessWidget {
  const HedefKarti({super.key, required this.hedef, this.eylemler = const []});

  final EventGoal hedef;
  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final hedefDeger = hedef.target;
    final mevcut = hedef.current;
    final alt = <Widget>[
      if (hedefDeger != null && !hedef.targetSet)
        AracBilgisi(metin: m.bilesen_goal_varsayilan_notu),
      if (!hedef.measureEnabled)
        AracBilgisi(metin: m.bilesen_goal_olcum_kapali)
      else if (hedef.progressHidden)
        AracBilgisi(metin: m.bilesen_goal_gizli)
      else if (hedefDeger != null && mevcut != null)
        HedefCubugu(hedef: hedef),
      if (hedef.reached && !hedef.progressHidden && hedef.measureEnabled)
        const _Ulasildi(),
    ];
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Süs: anlam yanındaki metindedir.
                    ExcludeSemantics(
                      child: Icon(
                        Icons.flag_outlined,
                        size: TayfamSizes.ikon,
                        color: r.tintMarkaUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Flexible(
                      child: Text(
                        hedefDeger == null
                            ? m.bilesen_goal_yok
                            : m.bilesen_goal_hedef(
                                hedefDegeriMetni(m, hedef, hedefDeger),
                              ),
                        style: hedefDeger == null
                            ? context.yazi.bodyMedium?.copyWith(
                                color: r.metinGovde,
                              )
                            : context.yazi.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (eylemler.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: eylemler),
              ],
            ),
            for (final parca in alt) ...[
              const SizedBox(height: TayfamSpacing.s8),
              parca,
            ],
          ],
        ),
      ),
    );
  }
}

/// İlerleme çubuğu: "40 / 100 kg" ve "%40" yazılı, altında tam yuvarlak
/// çubuk (anket çubuğuyla aynı ölçü). Ekran okuyucu tek etiket okur;
/// çubuk süstür. Hareket azaltıldıysa çubuk canlandırılmaz.
class HedefCubugu extends StatelessWidget {
  const HedefCubugu({super.key, required this.hedef});

  final EventGoal hedef;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final hedefDeger = hedef.target ?? 0;
    final ilerleme = m.bilesen_goal_ilerleme(
      olcumSayisi(m, hedef.current ?? 0, hedefBasamagi(hedef)),
      hedefDegeriMetni(m, hedef, hedefDeger),
    );
    final yuzde = hedefYuzdesi(hedef) ?? 0;
    final oran = hedefOrani(hedef);
    final sure = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TayfamMotion.uzun;
    return Semantics(
      container: true,
      label: m.bilesen_goal_cubuk_anlam(ilerleme, yuzde),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(ilerleme, style: context.yazi.bodyLarge)),
              const SizedBox(width: TayfamSpacing.s12),
              Text(m.bilesen_goal_yuzde(yuzde), style: context.yazi.titleMedium),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          ClipRRect(
            borderRadius: TayfamRadii.hapKoseleri,
            child: SizedBox(
              height: TayfamSizes.anketCubugu,
              child: ColoredBox(
                color: r.cizgi,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: oran),
                    duration: sure,
                    curve: TayfamMotion.egri,
                    builder: (context, deger, _) => FractionallySizedBox(
                      widthFactor: deger,
                      heightFactor: 1,
                      child: ColoredBox(color: r.marka),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Hedefe ulaşıldı": ikon ve metin (renk tek başına anlam taşımaz).
class _Ulasildi extends StatelessWidget {
  const _Ulasildi();

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.check_circle_outline,
            size: TayfamSizes.ikon,
            color: context.renkler.tintTealUstu,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s8),
        Expanded(
          child: Text(m.bilesen_goal_ulasildi, style: context.yazi.titleSmall),
        ),
      ],
    );
  }
}
