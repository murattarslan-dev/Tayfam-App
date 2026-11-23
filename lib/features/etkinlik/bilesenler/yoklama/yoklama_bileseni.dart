import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yoklama/yoklama_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Beklenen dönüş seçicisinin en uzak günü: başlangıçtan bu kadar sonrası.
const Duration yoklamaDonusEnUzak = Duration(days: 365);

/// Yoklama ve dönmeme alarmı bileşeni (`roll_call`; Tayfam-Api ADR-0025
/// §4, §9, #242; App ADR-0024 §3): kim çıktı, kim döndü. "Geliyorum"
/// diyen üye varış penceresinde "Çıktım" der (katılım sayılır), dönünce
/// "Döndüm" der. Bileşenin `alarm` parametresi açıksa beklenen dönüş +
/// toleransta dönmeyen kişi için organizatöre, yöneticilere ve
/// moderatörlere bildirim gider; alarm sunucudadır.
///
/// "Döndüm" güvenlik sinyalidir: bitişten sonra, iptal edilmiş etkinlikte
/// ve susturulmuşken de gösterilir. Beklenen dönüşü organizatör yazar
/// (`caller_can_edit`); herkesin kaydını yöneten görür
/// (`caller_can_manage`). Cihaz konumu alınmaz (Tayfam-Api ADR-0008).
///
/// Beklenen dönüş etkinlik oluşturulurken gönderilmez (sözleşme:
/// oluşturulduktan sonra bileşen ucundan yazılır); sihirbazda form bölümü
/// yoktur. Faz 1'deki yürüyüş yoklaması buradan çizilir.
final class YoklamaBileseni extends KayitliBilesen {
  const YoklamaBileseni() : super('roll_call');

  @override
  String ad(AppLocalizations m) => m.bilesen_roll_call_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return YoklamaBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Bir yoklama işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef YoklamaIslemi = Future<Object?> Function(YoklamaNotifier yoklama);

/// Yoklama bileşeninin detaydaki bölümü: başlık, kendi kartı ve (yönetene)
/// herkesin kaydı. Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar
/// dene".
class YoklamaBolumu extends ConsumerStatefulWidget {
  const YoklamaBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final YoklamaKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<YoklamaBolumu> createState() => _YoklamaBolumuState();
}

class _YoklamaBolumuState extends ConsumerState<YoklamaBolumu> {
  bool _mesgul = false;

  YoklamaNotifier get _notifier =>
      ref.read(yoklamaProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir. Aynı anda tek
  /// işlem yapılır.
  Future<void> _calistir(YoklamaIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  /// Beklenen dönüşü seçtirir (cihazın saatinde gün ve saat); başlangıçtan
  /// sonra değilse yazılmaz.
  Future<void> _donusSec(EventRollCall yoklama) async {
    final m = AppLocalizations.of(context);
    final etkinlik = widget.etkinlik;
    final ilk = (yoklama.expectedReturnAt ?? etkinlik.endsAt).toLocal();
    final bas = etkinlik.startsAt.toLocal();
    final ilkGun = DateTime(bas.year, bas.month, bas.day);
    final sonGun = ilkGun.add(yoklamaDonusEnUzak);
    final secilenGun = DateTime(ilk.year, ilk.month, ilk.day);
    final gun = await showDatePicker(
      context: context,
      initialDate: secilenGun.isBefore(ilkGun)
          ? ilkGun
          : secilenGun.isAfter(sonGun)
          ? sonGun
          : secilenGun,
      firstDate: ilkGun,
      lastDate: sonGun,
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: ilk.hour, minute: ilk.minute),
    );
    if (saat == null || !mounted) return;
    final donus = DateTime(
      gun.year,
      gun.month,
      gun.day,
      saat.hour,
      saat.minute,
    ).toUtc();
    if (!donus.isAfter(etkinlik.startsAt)) {
      aracBildir(context, m.etkinlik_donus_hata);
      return;
    }
    await _calistir((y) => y.donusYaz(donus));
  }

  Future<void> _donusuKaldir() async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_roll_call_kaldir_onay,
      metin: m.bilesen_roll_call_kaldir_metni,
      eylem: m.bilesen_roll_call_kaldir,
    );
    if (!onay || !mounted) return;
    await _calistir((y) => y.donusYaz(null));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(yoklamaProvider(widget.kimlik));
    final yoklama = okunan.value;
    final disarida = yoklama == null
        ? 0
        : yoklama.entries.where((k) => k.returnedAt == null).length;
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_roll_call_ad,
      sag: yoklama == null || !yoklama.callerCanManage || disarida == 0
          ? null
          : AracBasligiNotu(
              metin: m.bilesen_roll_call_disarida(etkinlikSayi(m, disarida)),
            ),
    );
    if (yoklama == null) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        YoklamaKarti(
          yoklama: yoklama,
          cikabilir: yoklamadaCikabilir(yoklama, widget.etkinlik, simdi),
          mesgul: _mesgul,
          onCik: () => unawaited(_calistir((y) => y.cik())),
          onDon: () => unawaited(_calistir((y) => y.don())),
          onDonusSec: () => unawaited(_donusSec(yoklama)),
          onDonusuKaldir: () => unawaited(_donusuKaldir()),
        ),
        if (yoklama.callerCanManage) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracListesi(
            bos: m.bilesen_roll_call_kimse_cikmadi,
            satirlar: [
              for (final kayit in yoklama.entries)
                YoklamaSatiri(
                  key: ValueKey(kayit.userId),
                  kayit: kayit,
                  gecikti: gecikti(kayit, yoklama, simdi),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Kendi yoklama kartı (tasarım: Etkinlik-Turler yürüyüş yoklaması):
/// alarmın durumu, beklenen dönüş (yazabilene "Beklenen dönüşü yaz" /
/// "Değiştir" ve "Kaldır"), kendi çıkış ve dönüş saati, "Çıktım" ya da
/// "Döndüm".
class YoklamaKarti extends StatelessWidget {
  const YoklamaKarti({
    super.key,
    required this.yoklama,
    required this.cikabilir,
    required this.mesgul,
    required this.onCik,
    required this.onDon,
    required this.onDonusSec,
    required this.onDonusuKaldir,
  });

  final EventRollCall yoklama;

  /// "Çıktım" gösterilir mi ([yoklamadaCikabilir]).
  final bool cikabilir;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onCik;
  final VoidCallback onDon;
  final VoidCallback onDonusSec;
  final VoidCallback onDonusuKaldir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final donus = yoklama.expectedReturnAt;
    final kayit = yoklama.mine;
    final kayitDonus = kayit?.returnedAt;
    final donebilir = yoklamadanDonebilir(yoklama);
    final bilgi = !yoklama.alarm
        ? m.bilesen_roll_call_bilgi
        : donus == null
        ? m.bilesen_roll_call_alarm_kurulmadi
        : m.bilesen_roll_call_alarm_bilgi(
            etkinlikSayi(m, yoklama.returnGraceMinutes),
          );
    final govde = context.yazi.bodyLarge;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AracBilgisi(metin: bilgi),
          if (donus != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              m.bilesen_roll_call_beklenen_donus(etkinlikTarihSaat(m, donus)),
              style: govde,
            ),
          ],
          if (yoklama.callerCanEdit) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CerceveliHapEylem(
                  etiket: donus == null
                      ? m.bilesen_roll_call_donus_yaz
                      : m.bilesen_roll_call_donus_degistir,
                  ikon: Icons.schedule,
                  onPressed: mesgul ? null : onDonusSec,
                ),
                if (donus != null)
                  BaglantiEylemi(
                    etiket: m.bilesen_roll_call_kaldir,
                    onPressed: mesgul ? null : onDonusuKaldir,
                  ),
              ],
            ),
          ],
          if (kayit != null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              m.bilesen_roll_call_cikisin(etkinlikSaat(m, kayit.startedAt)),
              style: govde,
            ),
            if (kayitDonus != null)
              Text(
                m.bilesen_roll_call_donusun(etkinlikSaat(m, kayitDonus)),
                style: govde,
              ),
          ],
          if (cikabilir || donebilir) ...[
            const SizedBox(height: TayfamSpacing.s12),
            BirincilEylem(
              etiket: cikabilir
                  ? m.bilesen_roll_call_ciktim
                  : m.bilesen_roll_call_dondum,
              ikon: cikabilir ? Icons.hiking : Icons.home_outlined,
              onPressed: mesgul ? null : (cikabilir ? onCik : onDon),
            ),
          ],
        ],
      ),
    );
  }
}

/// Yönetenin listesindeki bir kayıt: kişinin adı (dokununca profili),
/// çıkış ya da dönüş saati; dönmemiş ve alarm anı geçmişse "Dönmedi"
/// işareti (renk tek başına anlam taşımaz, metin de yazılır).
class YoklamaSatiri extends StatelessWidget {
  const YoklamaSatiri({super.key, required this.kayit, required this.gecikti});

  final RollCallEntry kayit;

  /// Dönmemiş ve alarm anı geçmiş ([gecikti]).
  final bool gecikti;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final ikincil = context.yazi.bodySmall;
    final donus = kayit.returnedAt;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KisiyeDokun(
                  kullaniciId: kayit.userId,
                  child: KullaniciAdiMetni(
                    kullaniciId: kayit.userId,
                    style: context.yazi.titleSmall,
                  ),
                ),
                Text(
                  donus == null
                      ? m.bilesen_roll_call_cikti(
                          etkinlikSaat(m, kayit.startedAt),
                        )
                      : m.bilesen_roll_call_dondu(etkinlikSaat(m, donus)),
                  style: ikincil,
                ),
              ],
            ),
          ),
          if (gecikti) ...[
            const SizedBox(width: TayfamSpacing.s8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: r.tintNar,
                borderRadius: TayfamRadii.hapKoseleri,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s8,
                  vertical: TayfamSpacing.s4,
                ),
                child: Text(
                  m.bilesen_roll_call_donmedi,
                  style: context.yazi.labelMedium?.copyWith(color: r.narMetin),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
