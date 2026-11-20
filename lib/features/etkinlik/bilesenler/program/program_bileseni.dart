import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/program/program_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/program/program_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Program akışı bileşeni (`schedule`; Tayfam-Api ADR-0025 §4, #247; App
/// ADR-0024 §3): etkinliğin saatli programı (varış, söyleşi, öğle yemeği
/// …). Bir tür tanımında en çok bir kez bulunur.
///
/// - Maddeler başlangıç saatine göre sıralı gelir; saatler cihazın
///   saatinde gösterilir (ADR-0008). Program birden çok güne yayılıyorsa
///   maddeler günlere ayrılır.
/// - Maddeyi organizatör, moderatör ve yönetici ekler, düzenler ve
///   çıkarır (`caller_can_edit`); madde sayısını `max_items` sınırlar.
///   Düğmeleri gizlemek kolaylıktır; yetkiyi sunucu verir, hatası her
///   durumda gösterilir (kesin kural 5).
/// - Etkinlik sürerken o an süren madde "Şimdi" etiketiyle vurgulanır
///   (yalnızca istemci hesabı, [surenMaddeler]). Vurgu renkle birlikte
///   metindir ve hareketsizdir (ADR-0004: süs animasyonu yok); ekran her
///   çizildiğinde yeniden hesaplanır.
///
/// Maddeler etkinlik oluşturulurken yazılmaz; sihirbazda form bölümü
/// yoktur. Etkinlik kartındaki satır liste yanıtı bileşen verisi
/// taşımadığı için çizilmez (ADR-0024 Notlar).
final class ProgramBileseni extends KayitliBilesen {
  const ProgramBileseni() : super('schedule');

  @override
  String ad(AppLocalizations m) => m.bilesen_schedule_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return ProgramBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Bir program işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef ProgramIslemi = Future<Object?> Function(ProgramNotifier program);

/// Program bileşeninin detaydaki bölümü: başlık, maddeler ve "Programa
/// ekle". Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class ProgramBolumu extends ConsumerStatefulWidget {
  const ProgramBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final ProgramKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<ProgramBolumu> createState() => _ProgramBolumuState();
}

class _ProgramBolumuState extends ConsumerState<ProgramBolumu> {
  bool _mesgul = false;

  ProgramNotifier get _notifier =>
      ref.read(programProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir. Aynı anda tek
  /// işlem yapılır.
  Future<void> _calistir(ProgramIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _ekle(EventSchedule program) => aracFormuAc<void>(
    context,
    (_) => ProgramFormu(
      etkinlik: widget.etkinlik,
      baslangic: programOnerilenBaslangic(program, widget.etkinlik),
      gonder: (istek) => _notifier.ekle(istek),
    ),
  );

  Future<void> _duzenle(EventScheduleItem madde) => aracFormuAc<void>(
    context,
    (_) => ProgramFormu(
      etkinlik: widget.etkinlik,
      baslangic: madde.startsAt,
      madde: madde,
      gonder: (istek) => _notifier.guncelle(madde.id, istek),
    ),
  );

  Future<void> _cikar(EventScheduleItem madde) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_schedule_cikar_onay,
      metin: madde.title,
    );
    if (!onay || !mounted) return;
    await _calistir((p) => p.cikar(madde.id));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(programProvider(widget.kimlik));
    final program = okunan.value;
    final maddeler = program?.items ?? const <EventScheduleItem>[];
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_schedule_ad,
      sag: program == null || !program.callerCanEdit
          ? null
          : AracBasligiNotu(
              metin: m.bilesen_schedule_doluluk(
                maddeler.length,
                program.maxItems,
              ),
            ),
    );
    if (program == null) {
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
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final suren = surenMaddeler(program, widget.etkinlik, simdi);
    final gunlereAyir = _gunSayisi(maddeler) > 1;
    final satirlar = <Widget>[];
    DateTime? oncekiGun;
    for (final madde in maddeler) {
      final gun = _yerelGun(madde.startsAt);
      if (gunlereAyir && gun != oncekiGun) {
        satirlar.add(ProgramGunBasligi(key: ValueKey(gun), gun: gun));
      }
      oncekiGun = gun;
      satirlar.add(
        ProgramSatiri(
          key: ValueKey(madde.id),
          madde: madde,
          suruyor: suren.contains(madde.id),
          duzenleyebilir: program.callerCanEdit,
          mesgul: _mesgul,
          onDuzenle: () => unawaited(_duzenle(madde)),
          onCikar: () => unawaited(_cikar(madde)),
        ),
      );
    }
    final dolu = maddeler.length >= program.maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(bos: m.bilesen_schedule_yok, satirlar: satirlar),
        if (program.callerCanEdit) ...[
          const SizedBox(height: TayfamSpacing.s12),
          if (dolu)
            AracBilgisi(metin: m.bilesen_schedule_dolu(program.maxItems))
          else
            AracDugmesi(
              etiket: m.bilesen_schedule_ekle,
              ikon: Icons.add,
              onPressed: _mesgul ? null : () => unawaited(_ekle(program)),
            ),
        ],
      ],
    );
  }
}

/// [an]'ın cihazın saatindeki günü.
DateTime _yerelGun(DateTime an) {
  final yerel = an.toLocal();
  return DateTime(yerel.year, yerel.month, yerel.day);
}

int _gunSayisi(List<EventScheduleItem> maddeler) =>
    {for (final madde in maddeler) _yerelGun(madde.startsAt)}.length;

/// [madde]'nin saati, cihazın saatinde: "09:00" ya da "09:00 – 10:30";
/// bitiş başka gündeyse günüyle.
String programSaatMetni(AppLocalizations m, EventScheduleItem madde) {
  final baslangic = etkinlikSaat(m, madde.startsAt);
  final bitis = madde.endsAt;
  if (bitis == null) return baslangic;
  return m.etkinlik_zaman_araligi(
    baslangic,
    _yerelGun(bitis) == _yerelGun(madde.startsAt)
        ? etkinlikSaat(m, bitis)
        : etkinlikTarihSaat(m, bitis),
  );
}

/// Birden çok güne yayılan programda günün başlığı ("15 Kasım Cumartesi").
class ProgramGunBasligi extends StatelessWidget {
  const ProgramGunBasligi({super.key, required this.gun});

  final DateTime gun;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Semantics(
      header: true,
      child: Text(
        etkinlikKisaGun(m, gun),
        style: context.yazi.labelLarge?.copyWith(
          color: context.renkler.metinGovde,
        ),
      ),
    );
  }
}

/// Bir program maddesi: saat (süren maddede "Şimdi" etiketiyle), başlık
/// ve varsa not. Düzenleyebilene sağda "Düzenle" ve "Programdan çıkar".
class ProgramSatiri extends StatelessWidget {
  const ProgramSatiri({
    super.key,
    required this.madde,
    required this.suruyor,
    required this.duzenleyebilir,
    required this.mesgul,
    required this.onDuzenle,
    required this.onCikar,
  });

  final EventScheduleItem madde;

  /// Madde şu an sürüyor (istemci hesabı).
  final bool suruyor;

  /// Çağıran maddeyi düzenleyebilir (`caller_can_edit`).
  final bool duzenleyebilir;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onDuzenle;
  final VoidCallback onCikar;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final not = madde.note;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: TayfamSpacing.s8,
                    runSpacing: TayfamSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        programSaatMetni(m, madde),
                        style: yazi.labelLarge?.copyWith(
                          color: suruyor ? r.tintMarkaUstu : r.metinGovde,
                          fontWeight: suruyor ? FontWeight.w700 : null,
                        ),
                      ),
                      if (suruyor) Etiket(metin: m.bilesen_schedule_simdi),
                    ],
                  ),
                  Text(madde.title, style: yazi.titleSmall),
                  if (not != null && not.isNotEmpty)
                    Text(
                      not,
                      style: yazi.bodySmall?.copyWith(color: r.metinGovde),
                    ),
                ],
              ),
            ),
          ),
          if (duzenleyebilir) ...[
            AracIkonDugmesi(
              ipucu: m.bilesen_schedule_duzenle,
              ikon: Icons.edit_outlined,
              onPressed: mesgul ? null : onDuzenle,
            ),
            AracIkonDugmesi(
              ipucu: m.bilesen_schedule_cikar,
              ikon: Icons.delete_outline,
              onPressed: mesgul ? null : onCikar,
            ),
          ],
        ],
      ),
    );
  }
}
