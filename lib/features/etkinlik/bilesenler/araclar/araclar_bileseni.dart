import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/araclar/arac_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/araclar/araclar_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Araçlar ve koltuk paylaşımı bileşeni (`vehicles`; Tayfam-Api ADR-0025
/// §4, ADR-0037 §3, #240; App ADR-0031 §7): katılımcıların araçları
/// (kişi başına bir araç). Bileşenin `seats` parametresi açıksa araç sahibi
/// boş koltuk sayısını yazar, katılımcı "Bu araçla gel" der ve araç sahibi
/// onaylar. Para ya da masraf alanı yoktur. Faz 1'deki konvoy araçları
/// buradadır.
///
/// Araç etkinlik oluşturulurken yazılmaz (bileşen ucundan, "Geliyorum"
/// diyen kişi yazar); bu yüzden sihirbazda form bölümü yoktur. "Garajımdan
/// seç" Üye garajı işiyle gelir.
final class AraclarBileseni extends KayitliBilesen {
  const AraclarBileseni() : super('vehicles');

  @override
  String ad(AppLocalizations m) => m.bilesen_vehicles_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return AraclarBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Bir araç işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef AracIslemi = Future<Object?> Function(AraclarNotifier araclar);

/// Araçlar bileşeninin detaydaki bölümü: başlık, araç kartları ve "Aracını
/// ekle". Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class AraclarBolumu extends ConsumerStatefulWidget {
  const AraclarBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final AracKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<AraclarBolumu> createState() => _AraclarBolumuState();
}

class _AraclarBolumuState extends ConsumerState<AraclarBolumu> {
  bool _mesgul = false;

  /// [islem]'i çalıştırır; başarıda [basari] varsa kısa bildirim, hatada
  /// hata bildirimi gösterir. Aynı anda tek işlem yapılır.
  Future<void> _calistir(AracIslemi islem, {String? basari}) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(
      ref.read(araclarProvider(widget.kimlik).notifier),
    );
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) {
      hataBildir(context, hata);
    } else if (basari != null) {
      aracBildir(context, basari);
    }
  }

  Future<void> _aracKaydet(EventVehicles araclar, EventVehicle? mevcut) async {
    final istek = await aracFormuAc<EventVehicleRequest>(
      context,
      (_) => AracFormu(
        mevcut: mevcut,
        plakaAcik: araclar.plateEnabled,
        koltukAcik: araclar.seatsEnabled,
      ),
    );
    if (istek == null || !mounted) return;
    await _calistir((a) => a.aracYaz(istek));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(araclarProvider(widget.kimlik));
    final araclar = okunan.value;
    final listeler = araclar?.vehicles ?? const <EventVehicle>[];
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_vehicles_ad,
      sag: listeler.isEmpty
          ? null
          : AracBasligiNotu(
              metin: m.bilesen_vehicles_arac_sayisi(listeler.length),
            ),
    );
    if (araclar == null) {
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
              onPressed: () => unawaited(
                ref.read(araclarProvider(widget.kimlik).notifier).yenile(),
              ),
            ),
          ),
        ],
      );
    }
    final etkinlik = widget.etkinlik;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    // Kendi aracı ve koltuk isteğinin (bekleyen ya da onaylanmış) olduğu
    // araç: yalnızca düğmeleri sadeleştirir.
    EventVehicle? benimki;
    String? istegimOlanArac;
    for (final arac in listeler) {
      if (ref.watch(kendisiMiProvider(arac.userId))) benimki = arac;
      for (final id in [...arac.riderUserIds, ...arac.pendingUserIds]) {
        if (ref.watch(kendisiMiProvider(id))) istegimOlanArac = arac.id;
      }
    }
    final katilabilir = araclar.callerCanParticipate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(
          bos: m.bilesen_vehicles_yok,
          satirlar: [
            for (final arac in listeler)
              AracKarti(
                key: ValueKey(arac.id),
                arac: arac,
                araclar: araclar,
                iptal: iptalEdildi(etkinlik),
                aracimVar: benimki != null,
                istegimOlanArac: istegimOlanArac,
                mesgul: _mesgul,
                onDegistir: () => unawaited(_aracKaydet(araclar, arac)),
                onIslem: (islem, {basari}) =>
                    unawaited(_calistir(islem, basari: basari)),
              ),
          ],
        ),
        if (katilabilir && benimki == null) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracDugmesi(
            etiket: m.bilesen_vehicles_ekle,
            ikon: Icons.add,
            onPressed: _mesgul
                ? null
                : () => unawaited(_aracKaydet(araclar, null)),
          ),
        ] else if (benimki == null &&
            etkinlik.callerRsvp != RsvpStatus.going &&
            katilimAcik(etkinlik, simdi)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_vehicles_ekle_bilgi),
        ],
      ],
    );
  }
}

/// Bir araç kartı (ADR-0031 §7): araç, plaka (sunucu döndürdüyse), sahibi;
/// koltuk paylaşımı açıksa boş koltuk, yolcular, bekleyen istekler ve "Bu
/// araçla gel".
class AracKarti extends ConsumerWidget {
  const AracKarti({
    super.key,
    required this.arac,
    required this.araclar,
    required this.iptal,
    required this.aracimVar,
    required this.istegimOlanArac,
    required this.mesgul,
    required this.onDegistir,
    required this.onIslem,
  });

  final EventVehicle arac;

  /// Bileşenin araçları (parametreler ve çağıranın yetkileri için).
  final EventVehicles araclar;

  /// Etkinlik iptal edildi: çıkarma düğmeleri gösterilmez.
  final bool iptal;

  /// Çağıranın bu bileşende aracı var (koltuk isteyemez).
  final bool aracimVar;

  /// Çağıranın koltuk isteğinin (bekleyen ya da onaylanmış) olduğu araç.
  final String? istegimOlanArac;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onDegistir;

  final void Function(AracIslemi islem, {String? basari}) onIslem;

  Future<void> _onayliIslem(
    BuildContext context, {
    required String baslik,
    String? metin,
    String? eylem,
    required AracIslemi islem,
  }) async {
    final onay = await cikarmaOnayi(
      context,
      baslik: baslik,
      metin: metin,
      eylem: eylem,
    );
    if (onay && context.mounted) onIslem(islem);
  }

  Future<void> _koltukIste(BuildContext context) async {
    final m = AppLocalizations.of(context);
    final onceki = istegimOlanArac;
    if (onceki != null && onceki != arac.id) {
      final onay = await cikarmaOnayi(
        context,
        baslik: m.bilesen_vehicles_koltuk_degistir_onay,
        metin: m.bilesen_vehicles_koltuk_degistir_metni,
        eylem: m.bilesen_vehicles_koltuk_iste,
      );
      if (!onay || !context.mounted) return;
    }
    onIslem(
      (a) => a.koltukIste(arac.id),
      basari: m.bilesen_vehicles_istek_gonderildi,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final benim = ref.watch(kendisiMiProvider(arac.userId));
    final ad = [
      arac.make,
      arac.model,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' ');
    final yil = arac.modelYear;
    final ayrinti = [
      if (yil != null && yil > 0) '$yil',
      arac.color,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
    final plaka = arac.plate?.trim();
    final ikincil = context.yazi.bodyMedium?.copyWith(color: r.metinGovde);
    final koltuklar = araclar.seatsEnabled;
    final bos = bosKoltuk(arac);
    final istegim = istegimOlanArac == arac.id;
    final koltukIstenebilir =
        koltuklar &&
        araclar.callerCanParticipate &&
        !aracimVar &&
        !istegim &&
        bos > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: r.tintMango,
                  borderRadius: TayfamRadii.dugmeKoseleri,
                ),
                child: SizedBox.square(
                  dimension: TayfamSizes.menuIkonKutusu,
                  child: Icon(
                    Icons.directions_car_outlined,
                    size: TayfamSizes.ikon,
                    color: r.tintMangoUstu,
                  ),
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ad, style: context.yazi.titleSmall),
                        if (ayrinti.isNotEmpty) Text(ayrinti, style: ikincil),
                        if (plaka != null && plaka.isNotEmpty)
                          Text(
                            m.bilesen_vehicles_plaka(plaka),
                            style: ikincil,
                          ),
                        if (koltuklar && arac.seats > 0)
                          Text(
                            m.bilesen_vehicles_bos_koltuk(bos),
                            style: ikincil,
                          ),
                      ],
                    ),
                  ),
                  // Araç sahibinin adına dokununca kişi profili (#185).
                  KisiyeDokun(
                    kullaniciId: arac.userId,
                    child: KullaniciAdiMetni(
                      kullaniciId: arac.userId,
                      style: ikincil,
                    ),
                  ),
                ],
              ),
            ),
            if (benim && araclar.callerCanParticipate)
              AracIkonDugmesi(
                ipucu: m.bilesen_vehicles_degistir,
                ikon: Icons.edit_outlined,
                onPressed: mesgul ? null : onDegistir,
              ),
            if (!iptal && (benim || araclar.callerCanManage))
              AracIkonDugmesi(
                ipucu: m.bilesen_vehicles_cikar,
                ikon: Icons.delete_outline,
                onPressed: mesgul
                    ? null
                    : () => unawaited(
                        _onayliIslem(
                          context,
                          baslik: m.bilesen_vehicles_cikar_onay,
                          metin: arac.riderUserIds.isEmpty &&
                                  arac.pendingUserIds.isEmpty
                              ? null
                              : m.bilesen_vehicles_cikar_metni,
                          islem: (a) => a.aracCikar(arac.id),
                        ),
                      ),
              ),
          ],
        ),
        if (koltuklar)
          for (final id in arac.riderUserIds)
            _KoltukSatiri(
              key: ValueKey('yolcu-$id'),
              kullaniciId: id,
              bekliyor: false,
              eylemler: (kendisi) => [
                if (!iptal && (kendisi || benim || araclar.callerCanManage))
                  AracIkonDugmesi(
                    ipucu: kendisi
                        ? m.bilesen_vehicles_birak
                        : m.bilesen_vehicles_yolcu_cikar,
                    ikon: Icons.person_remove_outlined,
                    onPressed: mesgul
                        ? null
                        : () => unawaited(
                            _onayliIslem(
                              context,
                              baslik: kendisi
                                  ? m.bilesen_vehicles_birak_onay
                                  : m.bilesen_vehicles_yolcu_cikar_onay,
                              eylem: kendisi ? m.bilesen_vehicles_birak : null,
                              islem: (a) => a.koltukBirak(arac.id, id),
                            ),
                          ),
                  ),
              ],
            ),
        if (koltuklar)
          for (final id in arac.pendingUserIds)
            _KoltukSatiri(
              key: ValueKey('bekleyen-$id'),
              kullaniciId: id,
              bekliyor: true,
              eylemler: (kendisi) => [
                if (benim && araclar.callerCanParticipate)
                  AracIkonDugmesi(
                    ipucu: m.bilesen_vehicles_onayla,
                    ikon: Icons.check,
                    onPressed: mesgul
                        ? null
                        : () => onIslem((a) => a.koltukOnayla(arac.id, id)),
                  ),
                if (!iptal && (kendisi || benim || araclar.callerCanManage))
                  AracIkonDugmesi(
                    ipucu: kendisi
                        ? m.bilesen_vehicles_geri_cek
                        : m.bilesen_vehicles_reddet,
                    ikon: Icons.close,
                    onPressed: mesgul
                        ? null
                        : () => unawaited(
                            _onayliIslem(
                              context,
                              baslik: kendisi
                                  ? m.bilesen_vehicles_geri_cek_onay
                                  : m.bilesen_vehicles_reddet_onay,
                              eylem: kendisi
                                  ? m.bilesen_vehicles_geri_cek_eylem
                                  : m.bilesen_vehicles_reddet_eylem,
                              islem: (a) => a.koltukBirak(arac.id, id),
                            ),
                          ),
                  ),
              ],
            ),
        if (koltukIstenebilir) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracDugmesi(
            etiket: m.bilesen_vehicles_koltuk_iste,
            ikon: Icons.event_seat_outlined,
            onPressed: mesgul ? null : () => unawaited(_koltukIste(context)),
          ),
        ],
      ],
    );
  }
}

/// Araç kartında bir yolcu ya da bekleyen istek: kişinin adı (dokununca
/// profil), bekliyorsa "Onay bekliyor" ve satır sonundaki düğmeler.
class _KoltukSatiri extends ConsumerWidget {
  const _KoltukSatiri({
    super.key,
    required this.kullaniciId,
    required this.bekliyor,
    required this.eylemler,
  });

  final String kullaniciId;
  final bool bekliyor;

  /// Satır sonundaki düğmeler; parametre kişinin çağıranın kendisi olup
  /// olmadığıdır.
  final List<Widget> Function(bool kendisi) eylemler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kendisi = ref.watch(kendisiMiProvider(kullaniciId));
    final ikincil = context.yazi.bodyMedium?.copyWith(color: r.metinGovde);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: TayfamSpacing.s12),
      child: Row(
        children: [
          // Süs: anlam yanındaki metindedir.
          ExcludeSemantics(
            child: Icon(
              bekliyor ? Icons.hourglass_empty : Icons.event_seat_outlined,
              size: TayfamSizes.ikonOrta,
              color: r.metinGovde,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KisiyeDokun(
                  kullaniciId: kullaniciId,
                  child: KullaniciAdiMetni(
                    kullaniciId: kullaniciId,
                    style: context.yazi.bodyMedium,
                  ),
                ),
                if (bekliyor)
                  Text(m.bilesen_vehicles_bekliyor, style: ikincil),
              ],
            ),
          ),
          ...eylemler(kendisi),
        ],
      ),
    );
  }
}
