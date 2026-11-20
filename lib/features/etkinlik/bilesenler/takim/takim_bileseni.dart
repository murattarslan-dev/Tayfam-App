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
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Takım kurma bileşeni (`teams`; Tayfam-Api ADR-0025 §4, #248; App
/// ADR-0024 §3): etkinliğin katılımcılarını takımlara böler (takım başına
/// 2 kişi: ikili eşleştirme, ör. eş dalıcı).
///
/// - Takımlar sırasıyla listelenir; her takımın adı ya da numarası
///   ("Takım 2") yazılıdır, kişi sayısı ve üyeleri altında. Takım hiçbir
///   yerde yalnızca renkle anlatılmaz; çağıranın takımı "Senin takımın"
///   etiketiyle (metin) işaretlenir.
/// - Takımları organizatör, moderatör ve yönetici kurar
///   (`caller_can_edit`): `random` ve `balanced` modda sunucu kurar
///   (yeniden kurulum onayla), her modda elle düzenlenebilir. Dengeli
///   kurmada seviyeler yalnızca formun belleğindedir; saklanmaz.
///   Düğmeleri gizlemek kolaylıktır; yetkiyi sunucu verir, hatası her
///   durumda gösterilir (kesin kural 5).
/// - Mod organizatöre bırakılmışsa sihirbazda seçilir ([formBolumu]).
///
/// Etkinlik kartındaki satır liste yanıtı bileşen verisi taşımadığı için
/// çizilmez (ADR-0024 Notlar).
final class TakimBileseni extends KayitliBilesen {
  const TakimBileseni() : super('teams');

  @override
  String ad(AppLocalizations m) => m.bilesen_teams_ad;

  @override
  Widget? formBolumu(BilesenBaglami b) => _TakimModSecimi(baglam: b);

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return TakimBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
    );
  }
}

/// Sihirbazdaki mod seçimi (organizatöre bırakılmışsa).
class _TakimModSecimi extends StatelessWidget {
  const _TakimModSecimi({required this.baglam});

  final BilesenBaglami baglam;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return BilesenSecimAlani(
      baglam: baglam,
      param: 'mode',
      baslik: m.bilesen_teams_mod_baslik,
      etiketler: {
        for (final mod in EventTeamsMode.values)
          if (takimModAdi(m, mod) case final ad?) mod.wire: ad,
      },
    );
  }
}

/// Modun adı; tanınmayan modda `null`.
String? takimModAdi(AppLocalizations m, EventTeamsMode mod) => switch (mod) {
  EventTeamsMode.random => m.bilesen_teams_mod_random,
  EventTeamsMode.balanced => m.bilesen_teams_mod_balanced,
  EventTeamsMode.manual => m.bilesen_teams_mod_manual,
  EventTeamsMode.unknown => null,
};

/// Bir takım işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef TakimIslemi = Future<Object?> Function(TakimNotifier takim);

/// Takım kurma bileşeninin detaydaki bölümü: başlık (sağda mod), takımlar
/// ve düzenleyene "Takımları kur" / "Elle düzenle". Okunurken yer tutmaz;
/// okunamazsa kısa hata ve "Tekrar dene".
class TakimBolumu extends ConsumerStatefulWidget {
  const TakimBolumu({super.key, required this.kimlik, required this.tanim});

  final TakimKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  @override
  ConsumerState<TakimBolumu> createState() => _TakimBolumuState();
}

class _TakimBolumuState extends ConsumerState<TakimBolumu> {
  bool _mesgul = false;

  TakimNotifier get _notifier =>
      ref.read(takimProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir. Aynı anda tek
  /// işlem yapılır.
  Future<void> _calistir(TakimIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  /// Sunucuya kurdurur: dengeli modda önce seviye formu; rastgele modda
  /// takımlar varsa yerlerini alacağı onaylanır.
  Future<void> _kur(EventTeams takimlar) async {
    final yeniden = takimlar.teams.isNotEmpty;
    if (takimlar.mode == EventTeamsMode.balanced) {
      await aracFormuAc<void>(
        context,
        (_) => TakimSeviyeFormu(
          katilimcilar: takimKatilimcilari(widget.kimlik),
          yenidenKurulum: yeniden,
          gonder: (istek) => _notifier.olustur(istek),
        ),
      );
      return;
    }
    if (yeniden) {
      final m = AppLocalizations.of(context);
      final onay = await cikarmaOnayi(
        context,
        baslik: m.bilesen_teams_yeniden_onay,
        metin: m.bilesen_teams_yeniden_aciklama,
        eylem: m.bilesen_teams_yeniden_kur,
      );
      if (!onay || !mounted) return;
    }
    await _calistir((t) => t.olustur(const EventTeamsGenerateRequest()));
  }

  Future<void> _elleDuzenle(EventTeams takimlar) => aracFormuAc<void>(
    context,
    (_) => TakimElleFormu(
      takimlar: takimlar,
      katilimcilar: takimKatilimcilari(widget.kimlik),
      gonder: (istek) => _notifier.elleKur(istek),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(takimProvider(widget.kimlik));
    final takimlar = okunan.value;
    final modAdi = takimlar == null ? null : takimModAdi(m, takimlar.mode);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_teams_ad,
      sag: modAdi == null ? null : AracBasligiNotu(metin: modAdi),
    );
    if (takimlar == null) {
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
    final sirali = [...takimlar.teams]
      ..sort((a, b) => a.position.compareTo(b.position));
    final sunucuKurar =
        takimlar.mode == EventTeamsMode.random ||
        takimlar.mode == EventTeamsMode.balanced;
    final kurulu = sirali.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(
          bos: m.bilesen_teams_yok,
          satirlar: [
            for (final takim in sirali)
              TakimSatiri(key: ValueKey(takim.id), takim: takim),
          ],
        ),
        if (takimlar.callerCanEdit) ...[
          const SizedBox(height: TayfamSpacing.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TayfamSpacing.s8,
            children: [
              if (sunucuKurar)
                AracDugmesi(
                  etiket: kurulu
                      ? m.bilesen_teams_yeniden_kur
                      : m.bilesen_teams_kur,
                  ikon: Icons.shuffle,
                  onPressed: _mesgul
                      ? null
                      : () => unawaited(_kur(takimlar)),
                ),
              AracDugmesi(
                etiket: m.bilesen_teams_elle_duzenle,
                ikon: Icons.edit_outlined,
                onPressed: _mesgul
                    ? null
                    : () => unawaited(_elleDuzenle(takimlar)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Bir takım: adı ya da numarası, çağıranın takımıysa "Senin takımın",
/// kişi sayısı ve üyeler (adına dokununca kişi profili).
class TakimSatiri extends ConsumerWidget {
  const TakimSatiri({super.key, required this.takim});

  final EventTeam takim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    var benim = false;
    for (final uye in takim.memberIds) {
      if (ref.watch(kendisiMiProvider(uye))) benim = true;
    }
    final ad = takim.name?.trim() ?? '';
    final kisi = m.bilesen_teams_kisi_sayisi(takim.memberIds.length);
    final ozet = ad.isEmpty
        ? kisi
        : m.bilesen_teams_ozet(m.bilesen_teams_takim_no(takim.position), kisi);
    final ikincil = yazi.bodySmall?.copyWith(color: r.metinGovde);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        takimEtiketi(m, takim.position, takim.name),
                        style: yazi.titleSmall,
                      ),
                    ),
                    if (benim) Etiket(metin: m.bilesen_teams_senin),
                  ],
                ),
                Text(ozet, style: ikincil),
              ],
            ),
          ),
          for (final uye in takim.memberIds)
            KisiyeDokun(
              key: ValueKey(uye),
              kullaniciId: uye,
              child: KullaniciAdiMetni(
                kullaniciId: uye,
                style: yazi.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
