import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kura/kura_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kura bileşeni (`draw`; Tayfam-Api ADR-0025 §4, #249; App ADR-0024 §3):
/// etkinliğin katılımcılarını ya da (türde takım kurma bileşeni varsa)
/// takımlarını rastgele sıraya dizer. Ardışık iki yer bir eşleşmedir.
///
/// - Kura bir kez çekilir; sonra değiştirilemez, yeniden çekilemez. Bu
///   yüzden çekmeden önce bunu söyleyen onay istenir.
/// - Eşleşmeler sırasıyla ("Eşleşme 1") listelenir; her yer numarasıyla
///   ve adıyla yazılır. Boş yer ve rakipsiz kalan yer "Bay" yazısıyla
///   (yalnızca renkle değil) gösterilir; sıra kaymaz. Çağıranın yeri
///   "Sen" etiketiyle işaretlenir.
/// - Kurayı organizatör, moderatör ve yönetici çeker (`caller_can_draw`).
///   Düğmeyi gizlemek kolaylıktır; yetkiyi sunucu verir, hatası her
///   durumda gösterilir (kesin kural 5).
/// - Çekim anında süs animasyonu yoktur: sonuç kısa bir solmayla
///   (`TayfamMotion.orta`) gelir; "hareketi azalt" açıkken o da yoktur.
///
/// Etkinlik kartındaki satır liste yanıtı bileşen verisi taşımadığı için
/// çizilmez (ADR-0024 Notlar).
final class KuraBileseni extends KayitliBilesen {
  const KuraBileseni() : super('draw');

  @override
  String ad(AppLocalizations m) => m.bilesen_draw_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return KuraBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
    );
  }
}

/// Kuranın neyi sıraladığı; tanınmayan türde `null`.
String? kuraKonusu(AppLocalizations m, EventDrawSubject konu) => switch (konu) {
  EventDrawSubject.participants => m.bilesen_draw_konu_participants,
  EventDrawSubject.teams => m.bilesen_draw_konu_teams,
  EventDrawSubject.unknown => null,
};

/// Kuranın çekildiği an ("20 Kasım 2026 14:05"), cihazın saat diliminde.
String kuraZamani(AppLocalizations m, DateTime an) =>
    '${DateFormat.yMMMMd(m.localeName).format(an.toLocal())} '
    '${saatMetni(m, an)}';

/// Kura bileşeninin detaydaki bölümü: başlık (sağda neyin sıralandığı),
/// eşleşmeler ve yetkiliye "Kurayı çek". Okunurken yer tutmaz; okunamazsa
/// kısa hata ve "Tekrar dene".
class KuraBolumu extends ConsumerStatefulWidget {
  const KuraBolumu({super.key, required this.kimlik, required this.tanim});

  final KuraKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  @override
  ConsumerState<KuraBolumu> createState() => _KuraBolumuState();
}

class _KuraBolumuState extends ConsumerState<KuraBolumu> {
  bool _mesgul = false;

  KuraNotifier get _notifier => ref.read(kuraProvider(widget.kimlik).notifier);

  /// Geri alınamazlığı söyleyen onaydan sonra kurayı çeker; hatada kısa
  /// bildirim. Aynı anda tek istek.
  Future<void> _cek(EventDraw kura) async {
    if (_mesgul) return;
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_draw_onay,
      metin: kura.subject == EventDrawSubject.teams
          ? m.bilesen_draw_onay_teams
          : m.bilesen_draw_onay_participants,
      eylem: m.bilesen_draw_cek,
    );
    if (!onay || !mounted) return;
    setState(() => _mesgul = true);
    final hata = await _notifier.cek();
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(kuraProvider(widget.kimlik));
    final kura = okunan.value;
    final konu = kura == null ? null : kuraKonusu(m, kura.subject);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_draw_ad,
      sag: konu == null ? null : AracBasligiNotu(metin: konu),
    );
    if (kura == null) {
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
    final takimlar = kura.subject == EventDrawSubject.teams
        ? kura.teamsKey
        : null;
    final takimKimligi = takimlar == null
        ? null
        : (
            tayfaId: widget.kimlik.tayfaId,
            etkinlikId: widget.kimlik.etkinlikId,
            anahtar: takimlar,
          );
    final cekilmis = kura.drawn && kura.entries.isNotEmpty;
    final sure = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TayfamMotion.orta;
    final drawnAt = kura.drawnAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AnimatedSwitcher(
          duration: sure,
          switchInCurve: TayfamMotion.egri,
          child: KeyedSubtree(
            key: ValueKey(cekilmis),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cekilmis && drawnAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TayfamSpacing.s8),
                    child: AracBilgisi(
                      metin: m.bilesen_draw_cekildi(kuraZamani(m, drawnAt)),
                    ),
                  ),
                AracListesi(
                  bos: m.bilesen_draw_yok,
                  satirlar: [
                    if (cekilmis)
                      for (final eslesme in kuraEslesmeleri(kura))
                        KuraEslesmesiSatiri(
                          key: ValueKey('kura-eslesme-${eslesme.no}'),
                          eslesme: eslesme,
                          takimlar: takimKimligi,
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (kura.callerCanDraw && !kura.drawn) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracDugmesi(
            etiket: m.bilesen_draw_cek,
            ikon: Icons.shuffle,
            onPressed: _mesgul ? null : () => unawaited(_cek(kura)),
          ),
        ],
      ],
    );
  }
}

/// Bir eşleşme: başlık ("Eşleşme 2") ve iki yer; rakipsiz kalan yer için
/// ikinci satır "Bay".
class KuraEslesmesiSatiri extends StatelessWidget {
  const KuraEslesmesiSatiri({
    super.key,
    required this.eslesme,
    required this.takimlar,
  });

  final KuraEslesmesi eslesme;

  /// Takım kurasında takımların okunduğu bileşen; katılımcı kurasında
  /// `null`.
  final TakimKimligi? takimlar;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ikinci = eslesme.ikinci;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              m.bilesen_draw_eslesme(eslesme.no),
              style: context.yazi.titleSmall,
            ),
          ),
          KuraYeriSatiri(yer: eslesme.ilk, takimlar: takimlar),
          if (ikinci != null)
            KuraYeriSatiri(yer: ikinci, takimlar: takimlar)
          else
            const _BaySatiri(),
        ],
      ),
    );
  }
}

/// Kurada bir yer: sıra numarası ve kişinin ya da takımın adı (kişiye
/// dokununca profili); boş yerde "Bay". Çağıranın yeri "Sen" etiketli.
class KuraYeriSatiri extends ConsumerWidget {
  const KuraYeriSatiri({super.key, required this.yer, required this.takimlar});

  final EventDrawEntry yer;

  final TakimKimligi? takimlar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi.bodyMedium;
    final kisi = yer.userId;
    final takimId = yer.teamId;
    if (kuraYeriBos(yer)) return _BaySatiri(sira: yer.position);
    Widget ad;
    var benim = false;
    if (kisi != null) {
      benim = ref.watch(kendisiMiProvider(kisi));
      ad = KisiyeDokun(
        kullaniciId: kisi,
        child: KullaniciAdiMetni(kullaniciId: kisi, style: yazi),
      );
    } else {
      final kimlik = takimlar;
      final takimListesi = kimlik == null
          ? const <EventTeam>[]
          : ref.watch(takimProvider(kimlik)).value?.teams ??
                const <EventTeam>[];
      EventTeam? takim;
      for (final t in takimListesi) {
        if (t.id == takimId) takim = t;
      }
      if (takim != null) {
        for (final uye in takim.memberIds) {
          if (ref.watch(kendisiMiProvider(uye))) benim = true;
        }
      }
      ad = Text(
        takim == null
            ? m.bilesen_draw_takim
            : takimEtiketi(m, takim.position, takim.name),
        style: yazi,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          _SiraNo(sira: yer.position),
          const SizedBox(width: TayfamSpacing.s8),
          Flexible(child: ad),
          if (benim) ...[
            const SizedBox(width: TayfamSpacing.s8),
            Etiket(metin: m.bilesen_draw_sen),
          ],
        ],
      ),
    );
  }
}

/// Boş ya da rakipsiz yer: "Bay" (karşısındaki tur atlar). Rakipsiz
/// kalan yerin ([sira] `null`) numarası yoktur.
class _BaySatiri extends StatelessWidget {
  const _BaySatiri({this.sira});

  final int? sira;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          if (sira case final no?) ...[
            _SiraNo(sira: no),
            const SizedBox(width: TayfamSpacing.s8),
          ],
          Flexible(
            child: Text(
              m.bilesen_draw_bay,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yerin sıra numarası ("3.").
class _SiraNo extends StatelessWidget {
  const _SiraNo({required this.sira});

  final int sira;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Text(
      m.bilesen_draw_sira(sira),
      style: context.yazi.bodyMedium?.copyWith(
        color: context.renkler.metinGovde,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
