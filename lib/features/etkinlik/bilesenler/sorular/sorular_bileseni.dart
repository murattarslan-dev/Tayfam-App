import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sorular/soru_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sorular/sorular_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru toplama bileşeni (`questions`; Tayfam-Api ADR-0025 §4, §5, #256;
/// App ADR-0024 §3): söyleşide canlı soru. "Geliyorum" diyen (ya da
/// katılımı doğrulanmış) üye soru sorar ve sorulara oy verir (kendi
/// sorusuna da); organizatör, moderatör ve yönetici soruyu "cevaplandı"
/// işaretler. Bileşenin `anonymous` parametresi açıksa soru anonim
/// sorulabilir: yazar hiçbir yanıtta yoktur, istemci de göstermez ve
/// tutmaz; yazar yalnızca sorunun kendisinin olduğunu görür.
///
/// Kendi sorusunu yazarı, herkesinkini moderatör ve yönetici kaldırır
/// (`caller_can_remove`); başkasının sorusu şikâyet edilebilir
/// (`event_question`). Liste canlıdır. Düğmeleri gizlemek kolaylıktır;
/// yetkiyi sunucu verir, hatası her durumda gösterilir (kesin kural 5).
///
/// Sorular etkinlik oluşturulurken yazılmaz; sihirbazda form bölümü
/// yoktur.
final class SorularBileseni extends KayitliBilesen {
  const SorularBileseni() : super('questions');

  @override
  String ad(AppLocalizations m) => m.bilesen_questions_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return SorularBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Bir soru işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef SoruIslemi = Future<Object?> Function(SorularNotifier sorular);

/// Soru toplama bileşeninin detaydaki bölümü: başlık, sorular ve "Soru
/// sor". Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class SorularBolumu extends ConsumerStatefulWidget {
  const SorularBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final SorularKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<SorularBolumu> createState() => _SorularBolumuState();
}

class _SorularBolumuState extends ConsumerState<SorularBolumu> {
  bool _mesgul = false;

  SorularNotifier get _notifier =>
      ref.read(sorularProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir. Aynı anda tek
  /// işlem yapılır.
  Future<void> _calistir(SoruIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _sor(EventQuestionList liste) => aracFormuAc<void>(
    context,
    (_) => SoruFormu(
      anonimAcik: liste.anonymousAllowed,
      gonder: (istek) => _notifier.sor(istek),
    ),
  );

  Future<void> _kaldir(EventQuestion soru) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_questions_kaldir_onay,
      eylem: m.bilesen_questions_kaldir,
    );
    if (!onay || !mounted) return;
    await _calistir((s) => s.kaldir(soru.id));
  }

  Future<void> _islem(EventQuestion soru, SoruMenuIslemi islem) async {
    switch (islem) {
      case SoruMenuIslemi.cevaplandi:
        await _calistir((s) => s.cevaplandi(soru.id, isaretle: true));
      case SoruMenuIslemi.isaretiKaldir:
        await _calistir((s) => s.cevaplandi(soru.id, isaretle: false));
      case SoruMenuIslemi.kaldir:
        await _kaldir(soru);
      case SoruMenuIslemi.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: widget.kimlik.tayfaId,
            tur: ReportTargetType.eventQuestion,
            id: soru.id,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(sorularProvider(widget.kimlik));
    final liste = okunan.value;
    final sorular = liste?.questions ?? const <EventQuestion>[];
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_questions_ad,
      sag: sorular.isEmpty
          ? null
          : AracBasligiNotu(metin: m.bilesen_questions_sayi(sorular.length)),
    );
    if (liste == null) {
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
    final etkinlik = widget.etkinlik;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final sinirDoldu = kendiSorularim(liste) >= liste.maxQuestionsPerPerson;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(
          bos: m.bilesen_questions_yok,
          satirlar: [
            for (final soru in sorular)
              SoruSatiri(
                key: ValueKey(soru.id),
                soru: soru,
                oyVerebilir: liste.callerCanAsk,
                isaretleyebilir: liste.callerCanMarkAnswered,
                mesgul: _mesgul,
                onOy: () => unawaited(
                  _calistir((s) => s.oy(soru.id, ver: !soru.callerVoted)),
                ),
                onIslem: (islem) => unawaited(_islem(soru, islem)),
              ),
          ],
        ),
        if (liste.callerCanAsk && !sinirDoldu) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracDugmesi(
            etiket: m.bilesen_questions_sor,
            ikon: Icons.add_comment_outlined,
            onPressed: _mesgul ? null : () => unawaited(_sor(liste)),
          ),
        ] else if (liste.callerCanAsk) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(
            metin: m.bilesen_questions_sinir(liste.maxQuestionsPerPerson),
          ),
        ] else if (etkinlik.callerRsvp != RsvpStatus.going &&
            katilimAcik(etkinlik, simdi)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_questions_katil_bilgi),
        ],
      ],
    );
  }
}

/// Soru satırının menüsündeki işlemler.
enum SoruMenuIslemi { cevaplandi, isaretiKaldir, kaldir, sikayet }

/// Bu yazı ölçeğinin üstünde oy düğmesi metnin altına iner.
const double _dugmeYanYanaEnBuyukOlcek = 1.3;

/// Bir soru: metin; alt satırda soran (anonimse "Anonim", kendisininse
/// "Sen sordun") ve "Cevaplandı" etiketi (ikonlu; yalnızca renge
/// dayanmaz). Yanda oy düğmesi (sayısıyla) ve işlemler menüsü.
class SoruSatiri extends StatelessWidget {
  const SoruSatiri({
    super.key,
    required this.soru,
    required this.oyVerebilir,
    required this.isaretleyebilir,
    required this.mesgul,
    required this.onOy,
    required this.onIslem,
  });

  final EventQuestion soru;

  /// Çağıran oy verebilir (`caller_can_ask`).
  final bool oyVerebilir;

  /// Çağıran cevaplandı işaretleyebilir (`caller_can_mark_answered`).
  final bool isaretleyebilir;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onOy;

  final ValueChanged<SoruMenuIslemi> onIslem;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final ikincil = context.yazi.bodySmall?.copyWith(color: r.metinIkincil);
    final cevaplandi = soru.answeredAt != null;
    final yazar = soru.authorId;
    final altSatir = <Widget>[
      if (soru.callerIsAuthor)
        Text(m.bilesen_questions_sen_sordun, style: ikincil)
      else if (!soru.anonymous && yazar != null)
        // Soranın adına dokununca kişi profili (#185).
        KisiyeDokun(
          kullaniciId: yazar,
          ipucu: m.bilesen_questions_soran,
          child: KullaniciAdiMetni(kullaniciId: yazar, style: ikincil),
        ),
      if (soru.anonymous)
        Etiket(
          metin: m.bilesen_questions_anonim,
          ton: EtiketTonu.notr,
          ikon: Icons.visibility_off_outlined,
        ),
      if (cevaplandi)
        Etiket(
          metin: m.bilesen_questions_cevaplandi,
          ton: EtiketTonu.teal,
          ikon: Icons.check_circle_outline,
        ),
    ];
    final islemler = <PopupMenuEntry<SoruMenuIslemi>>[
      if (isaretleyebilir)
        PopupMenuItem(
          value: cevaplandi
              ? SoruMenuIslemi.isaretiKaldir
              : SoruMenuIslemi.cevaplandi,
          child: Text(
            cevaplandi
                ? m.bilesen_questions_isareti_kaldir
                : m.bilesen_questions_cevaplandi_isaretle,
          ),
        ),
      if (soru.callerCanRemove)
        PopupMenuItem(
          value: SoruMenuIslemi.kaldir,
          child: Text(m.bilesen_questions_kaldir),
        ),
      if (!soru.callerIsAuthor)
        PopupMenuItem(
          value: SoruMenuIslemi.sikayet,
          child: Text(m.bilesen_questions_sikayet_et),
        ),
    ];
    final oy = _OyDugmesi(
      sayi: soru.voteCount,
      verildi: soru.callerVoted,
      onPressed: oyVerebilir && !mesgul ? onOy : null,
    );
    final yanYana =
        MediaQuery.textScalerOf(context).scale(1) <= _dugmeYanYanaEnBuyukOlcek;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  soru.body,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: cevaplandi ? r.metinGovde : r.metin,
                  ),
                ),
                if (altSatir.isNotEmpty) ...[
                  const SizedBox(height: TayfamSpacing.s4),
                  Wrap(
                    spacing: TayfamSpacing.s8,
                    runSpacing: TayfamSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: altSatir,
                  ),
                ],
                if (!yanYana)
                  Padding(
                    padding: const EdgeInsets.only(top: TayfamSpacing.s4),
                    child: oy,
                  ),
              ],
            ),
          ),
        ),
        if (yanYana) ...[const SizedBox(width: TayfamSpacing.s8), oy],
        if (islemler.isNotEmpty)
          PopupMenuButton<SoruMenuIslemi>(
            key: ValueKey('soru-islemler-${soru.id}'),
            tooltip: m.bilesen_questions_islemler,
            enabled: !mesgul,
            onSelected: onIslem,
            itemBuilder: (_) => islemler,
          ),
      ],
    );
  }
}

/// Oy düğmesi (hap): ok ikonu ve oy sayısı. Oy verildiyse dolu ikon ve
/// marka tonu; ekran okuyucu sayıyı ve oy verilip verilmediğini okur
/// (yalnızca renge dayanmaz). `onPressed` `null` ise oy verilemez; sayı
/// yine görünür. Dokunma alanı en az 48 px.
class _OyDugmesi extends StatelessWidget {
  const _OyDugmesi({
    required this.sayi,
    required this.verildi,
    required this.onPressed,
  });

  final int sayi;
  final bool verildi;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final m = AppLocalizations.of(context);
    final onPressed = this.onPressed;
    final pasif = onPressed == null;
    final (Color zemin, Color renk, Color? kenar) = verildi
        ? (r.tintMarka, r.tintMarkaUstu, null)
        : (r.kart, pasif ? r.metinIkincil : r.metin, r.cizgi);
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: Semantics(
        container: true,
        button: !pasif,
        enabled: !pasif,
        toggled: pasif ? null : verildi,
        label: verildi
            ? m.bilesen_questions_oy_anlam_verdin(sayi)
            : m.bilesen_questions_oy_anlam(sayi),
        hint: pasif ? null : m.bilesen_questions_oy_ipucu,
        onTap: onPressed,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TayfamSizes.dokunmaMin,
            minHeight: TayfamSizes.dokunmaMin,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: zemin,
              shape: StadiumBorder(
                side: kenar == null
                    ? BorderSide.none
                    : BorderSide(color: kenar, width: TayfamSizes.vurguKenari),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: TayfamSizes.dokunmaMin,
                    minHeight: TayfamSizes.dokunmaMin,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TayfamSpacing.s12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          verildi
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_alt_outlined,
                          size: TayfamSizes.ikonOrta,
                          color: renk,
                        ),
                        const SizedBox(width: TayfamSpacing.s4),
                        Text(
                          etkinlikSayi(m, sayi),
                          style: context.yazi.labelLarge?.copyWith(color: renk),
                        ),
                      ],
                    ),
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
