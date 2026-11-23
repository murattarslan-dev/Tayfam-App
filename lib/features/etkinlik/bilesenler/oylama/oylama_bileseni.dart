import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/oylama/oylama_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/oylama/secenek_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Oylama bileşeni (`vote`; Tayfam-Api ADR-0025 §4, §5, ADR-0037 §3, #254;
/// App ADR-0024 §3, ADR-0031 §7): etkinliğe bağlı, kişi başına tek oylu
/// oylama. Seçenekler tanımdaki kaynaktandır:
///
/// - `free`: organizatörün yazdığı seçenekler (yalnızca burada seçenek
///   eklenir ve kaldırılır, `caller_can_edit_options`);
/// - `participants`: etkinliğe gelenler;
/// - `vehicles`: araçlar bileşenindeki araçlar (araç kartı; plaka yok);
/// - `album`: etkinlik albümünün fotoğrafları (küçük resim).
///
/// **Oy gizlidir:** kimin neye oy verdiği hiçbir yerde gösterilmez;
/// yalnızca kendi oyun işaretlidir ("Oyun"). Oylama açıkken seçenek başına
/// sayı gösterilmez (sunucu 0 döner), yalnızca oy veren sayısı görünür;
/// sayılar ve kazanan oylama kapanınca ya da bileşen donunca
/// (`results_visible`) görünür. Kendine, kendi aracına ve kendi fotoğrafına
/// oy verilmez; o satır seçilemez. Düğmeleri gizlemek kolaylıktır; yetkiyi
/// sunucu verir (kesin kural 5). Seçenekler etkinlik oluşturulurken
/// yazılmaz; sihirbazda form bölümü yoktur.
final class OylamaBileseni extends KayitliBilesen {
  const OylamaBileseni() : super('vote');

  @override
  String ad(AppLocalizations m) => m.bilesen_vote_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return OylamaBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Kişinin metin olarak adı (hesabını silmişse "Silinmiş kullanıcı").
String oylamaKisiAdi(WidgetRef ref, AppLocalizations m, String kullaniciId) {
  ref.read(kullaniciAdlariProvider.notifier).iste(kullaniciId);
  final bilinen = ref.watch(
    kullaniciAdlariProvider.select((adlar) => adlar[kullaniciId]),
  );
  return switch (bilinen) {
    null => m.kullanici_genel,
    KullaniciAdi(:final ad?) => ad,
    KullaniciAdi() => m.kullanici_silinmis,
  };
}

/// Aracın adı: marka ve (varsa) model.
String oylamaAracAdi(EventVoteVehicle arac) =>
    [arac.make, ?arac.model].where((p) => p.trim().isNotEmpty).join(' ');

/// Aracın ayrıntısı: model yılı ve renk (yoksa boş).
String oylamaAracAyrintisi(EventVoteVehicle arac) {
  final yil = arac.modelYear;
  return [
    if (yil != null && yil > 0) '$yil',
    ?arac.color,
  ].where((p) => p.trim().isNotEmpty).join(', ');
}

/// Seçeneğin tek satırlık adı (kutlamanın kazanan kartı da bunu kullanır):
/// serbest seçenekte etiket, katılımcıda kişinin adı, araçta "araç · sahibi",
/// albümde "Fotoğraf · yükleyen".
String oylamaSecenekAdi(
  WidgetRef ref,
  AppLocalizations m,
  EventVoteOption secenek,
) {
  final etiket = secenek.label;
  if (etiket != null && etiket.isNotEmpty) return etiket;
  final kisi = secenek.userId;
  final kisiAdi = kisi == null ? null : oylamaKisiAdi(ref, m, kisi);
  final arac = secenek.vehicle;
  if (arac != null) {
    final ad = oylamaAracAdi(arac);
    return kisiAdi == null ? ad : m.bilesen_vote_sahipli(ad, kisiAdi);
  }
  if (secenek.uploadId != null) {
    return kisiAdi == null
        ? m.bilesen_vote_fotograf_genel
        : m.bilesen_vote_sahipli(m.bilesen_vote_fotograf_genel, kisiAdi);
  }
  return kisiAdi ?? m.bilesen_vote_secenek_genel;
}

/// Bir oylama işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef OylamaIslemi = Future<Object?> Function(OylamaNotifier oylama);

/// Oylama bileşeninin detaydaki bölümü: başlık, durum (açık/kapalı, oy
/// veren sayısı), seçenekler ve yetkiliye seçenek ekleme ile kapatma.
/// Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class OylamaBolumu extends ConsumerStatefulWidget {
  const OylamaBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final OylamaKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<OylamaBolumu> createState() => _OylamaBolumuState();
}

class _OylamaBolumuState extends ConsumerState<OylamaBolumu> {
  bool _mesgul = false;

  OylamaNotifier get _notifier =>
      ref.read(oylamaProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir. Aynı anda tek
  /// işlem yapılır.
  Future<void> _calistir(OylamaIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _secenekEkle() => aracFormuAc<void>(
    context,
    (_) => OylamaSecenekFormu(gonder: _notifier.secenekEkle),
  );

  Future<void> _kaldir(String secenekId) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_vote_kaldir_onay,
      metin: m.bilesen_vote_kaldir_aciklama,
      eylem: m.bilesen_vote_kaldir,
    );
    if (!onay || !mounted) return;
    await _calistir((o) => o.secenegiKaldir(secenekId));
  }

  Future<void> _kapat() async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_vote_kapat_onay,
      metin: m.bilesen_vote_kapat_aciklama,
      eylem: m.bilesen_vote_kapat,
    );
    if (!onay || !mounted) return;
    await _calistir((o) => o.kapat());
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_vote_ad,
    );
    final okunan = ref.watch(oylamaProvider(widget.kimlik));
    final oylama = okunan.value;
    if (oylama == null) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [baslik, ..._icerik(oylama)],
    );
  }

  String _bosMetni(AppLocalizations m, EventVote oylama) =>
      switch (oylama.source) {
        EventVoteSource.free =>
          oylama.callerCanEditOptions
              ? m.bilesen_vote_bos_serbest_yonetici
              : m.bilesen_vote_bos_serbest,
        EventVoteSource.participants => m.bilesen_vote_bos_katilimci,
        EventVoteSource.vehicles => m.bilesen_vote_bos_arac,
        EventVoteSource.album => m.bilesen_vote_bos_album,
        EventVoteSource.unknown => m.bilesen_vote_bos_serbest,
      };

  List<Widget> _icerik(EventVote oylama) {
    final m = AppLocalizations.of(context);
    if (!oylamaKaynagiTanindi(oylama)) {
      return [AracBilgisi(metin: m.bilesen_vote_guncelle)];
    }
    final ben = ref.watch(kendiKimligimProvider).value;
    final etkinlik = widget.etkinlik;
    final secili = oylamaSecenegi(oylama, oylama.callerOptionId);
    final katilmiyor =
        etkinlik.callerRsvp != RsvpStatus.going &&
        etkinlik.callerAttendance != AttendanceStatus.attended;
    final secenekler = oylama.options;
    return [
      OylamaDurumu(oylama: oylama),
      const SizedBox(height: TayfamSpacing.s12),
      AracListesi(
        bos: _bosMetni(m, oylama),
        satirlar: [
          for (final (i, s) in secenekler.indexed)
            OylamaSecenegiSatiri(
              key: ValueKey(s.id),
              secenek: s,
              sira: i + 1,
              secili: secili?.id == s.id,
              kendi: oylamaKendiSecenegim(s, ben),
              oyVerebilir: oylama.callerCanVote,
              sonucGorunur: oylama.resultsVisible,
              kaldirabilir:
                  oylama.callerCanEditOptions &&
                  oylama.source == EventVoteSource.free,
              mesgul: _mesgul,
              onSec: () => unawaited(_calistir((o) => o.oyVer(s.id))),
              onKaldir: () => unawaited(_kaldir(s.id)),
            ),
        ],
      ),
      if (oylama.callerCanVote && secili != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BaglantiEylemi(
            etiket: m.bilesen_vote_geri_al,
            onPressed: _mesgul
                ? null
                : () => unawaited(_calistir((o) => o.oyuGeriAl())),
          ),
        ),
      if (!oylama.closed &&
          !oylama.callerCanVote &&
          katilmiyor &&
          !iptalEdildi(etkinlik) &&
          secenekler.isNotEmpty) ...[
        const SizedBox(height: TayfamSpacing.s8),
        AracBilgisi(metin: m.bilesen_vote_katil),
      ],
      if (oylamaSecenekEklenebilir(oylama)) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: m.bilesen_vote_secenek_ekle,
          ikon: Icons.add,
          onPressed: _mesgul ? null : () => unawaited(_secenekEkle()),
        ),
      ] else if (oylama.callerCanEditOptions &&
          oylama.source == EventVoteSource.free) ...[
        const SizedBox(height: TayfamSpacing.s8),
        AracBilgisi(metin: m.bilesen_vote_secenek_sinir(oylama.maxOptions)),
      ],
      if (oylama.callerCanClose) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: m.bilesen_vote_kapat,
          ikon: Icons.lock_outline,
          onPressed: _mesgul ? null : () => unawaited(_kapat()),
        ),
      ],
    ];
  }
}

/// Oylamanın durumu: kapandıysa "Kapandı" etiketi, oy veren sayısı ve
/// sonuçlar henüz görünmüyorsa nedeni. Kimin oy verdiği yazılmaz.
class OylamaDurumu extends StatelessWidget {
  const OylamaDurumu({super.key, required this.oylama});

  final EventVote oylama;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Etiket(
              metin: oylama.closed
                  ? m.bilesen_vote_kapandi
                  : m.bilesen_vote_acik,
              ton: oylama.closed ? EtiketTonu.notr : EtiketTonu.teal,
            ),
            Text(
              m.bilesen_vote_oy_veren(oylama.voterCount),
              style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ],
        ),
        if (!oylama.resultsVisible) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_vote_sonuc_gizli),
        ],
      ],
    );
  }
}

/// Oylamada bir seçenek: seçim işareti (oy verebilene), kaynağa göre
/// küçük resim ya da simge, ad ve ayrıntı, kendi oyunsa "Oyun", kendi
/// seçeneğinse "Sen" etiketi; sonuçlar görünürken oy sayısı ve kazanana
/// "Kazanan". Satır ekran okuyucuda tek seçim düğmesi olarak okunur
/// (seçili / seçili değil); kendi seçeneğin seçilemez. [kaldirabilir] ise
/// yanında "Seçeneği kaldır".
class OylamaSecenegiSatiri extends ConsumerWidget {
  const OylamaSecenegiSatiri({
    super.key,
    required this.secenek,
    required this.sira,
    required this.secili,
    required this.kendi,
    required this.oyVerebilir,
    required this.sonucGorunur,
    required this.kaldirabilir,
    required this.mesgul,
    required this.onSec,
    required this.onKaldir,
  });

  final EventVoteOption secenek;

  /// Seçeneğin listedeki sırası (1'den; albüm fotoğrafının adı).
  final int sira;

  /// Kendi oyun bu seçenekte.
  final bool secili;

  /// Seçeneğin arkasındaki kişi sensin (kendine oy verilmez).
  final bool kendi;

  /// Çağıran şu an oy verebilir (`caller_can_vote`).
  final bool oyVerebilir;

  /// Sayılar ve kazanan görünür (`results_visible`).
  final bool sonucGorunur;

  final bool kaldirabilir;

  /// Bir işlem sürüyor: dokunma geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onSec;
  final VoidCallback onKaldir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final (baslik, ayrinti) = _metinler(ref, m);
    final secilebilir = oyVerebilir && !kendi && !secili && !mesgul;
    final isaretli = oyVerebilir || secili;
    final gorsel = _onGorsel(context, m);
    final etiketler = <Widget>[
      if (secili) Etiket(metin: m.bilesen_vote_oyun, ikon: Icons.check),
      if (kendi) Etiket(metin: m.bilesen_vote_sen, ton: EtiketTonu.notr),
      if (sonucGorunur && secenek.winner)
        Etiket(
          metin: m.bilesen_vote_kazanan,
          ton: EtiketTonu.mango,
          ikon: Icons.emoji_events_outlined,
        ),
    ];
    final satir = Semantics(
      inMutuallyExclusiveGroup: isaretli,
      checked: isaretli ? secili : null,
      enabled: isaretli ? (oyVerebilir && !kendi) : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: TayfamRadii.onizlemeKoseleri,
          onTap: secilebilir ? onSec : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: secili ? r.tintMarka : null,
              borderRadius: TayfamRadii.onizlemeKoseleri,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s8,
                  vertical: TayfamSpacing.s8,
                ),
                child: Row(
                  children: [
                    if (isaretli) ...[
                      ExcludeSemantics(
                        child: Icon(
                          secili
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: secili
                              ? r.tintMarkaUstu
                              : (oyVerebilir && !kendi
                                    ? r.metinGovde
                                    : r.metinIkincil),
                        ),
                      ),
                      const SizedBox(width: TayfamSpacing.s8),
                    ],
                    if (gorsel != null) ...[
                      gorsel,
                      const SizedBox(width: TayfamSpacing.s12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baslik,
                            style: yazi.bodyLarge?.copyWith(
                              color: secili ? r.tintMarkaUstu : r.metin,
                            ),
                          ),
                          if (ayrinti != null && ayrinti.isNotEmpty)
                            Text(
                              ayrinti,
                              style: yazi.bodySmall?.copyWith(
                                color: secili ? r.tintMarkaUstu : r.metinGovde,
                              ),
                            ),
                          if (etiketler.isNotEmpty) ...[
                            const SizedBox(height: TayfamSpacing.s4),
                            Wrap(
                              spacing: TayfamSpacing.s8,
                              runSpacing: TayfamSpacing.s4,
                              children: etiketler,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (sonucGorunur) ...[
                      const SizedBox(width: TayfamSpacing.s8),
                      Text(
                        m.bilesen_vote_oy_sayisi(secenek.voteCount),
                        style: yazi.titleSmall?.copyWith(
                          color: secili ? r.tintMarkaUstu : r.metin,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: MergeSemantics(child: satir)),
        if (kaldirabilir)
          AracIkonDugmesi(
            ipucu: m.bilesen_vote_kaldir,
            ikon: Icons.delete_outline,
            onPressed: mesgul ? null : onKaldir,
          ),
      ],
    );
  }

  /// Başlık ve (varsa) ayrıntı satırı.
  (String, String?) _metinler(WidgetRef ref, AppLocalizations m) {
    final kisi = secenek.userId;
    final arac = secenek.vehicle;
    if (arac != null) {
      final ayrinti = oylamaAracAyrintisi(arac);
      final sahip = kisi == null
          ? null
          : m.bilesen_vote_sahibi(oylamaKisiAdi(ref, m, kisi));
      final String? alt;
      if (sahip == null) {
        alt = ayrinti;
      } else if (ayrinti.isEmpty) {
        alt = sahip;
      } else {
        alt = m.bilesen_vote_sahipli(ayrinti, sahip);
      }
      return (oylamaAracAdi(arac), alt);
    }
    if (secenek.uploadId != null) {
      return (
        m.bilesen_vote_fotograf(sira),
        kisi == null
            ? null
            : m.bilesen_vote_yukleyen(oylamaKisiAdi(ref, m, kisi)),
      );
    }
    final etiket = secenek.label;
    if (etiket != null && etiket.isNotEmpty) return (etiket, null);
    if (kisi != null) return (oylamaKisiAdi(ref, m, kisi), null);
    return (m.bilesen_vote_secenek_genel, null);
  }

  /// Kaynağa göre satırın başındaki görsel: albümde küçük resim, araçta ve
  /// katılımcıda simge; serbest seçenekte `null`. Simge süstür.
  Widget? _onGorsel(BuildContext context, AppLocalizations m) {
    final r = context.renkler;
    final yukleme = secenek.uploadId;
    if (yukleme != null) {
      return ClipRRect(
        borderRadius: TayfamRadii.onizlemeKoseleri,
        child: SizedBox.square(
          dimension: TayfamSizes.fotografKucukResim,
          child: MedyaGorseli(
            uploadId: yukleme,
            etiket: m.bilesen_vote_fotograf_etiketi,
          ),
        ),
      );
    }
    final IconData? ikon = secenek.vehicle != null
        ? Icons.directions_car_outlined
        : (secenek.label == null && secenek.userId != null
              ? Icons.person_outline
              : null);
    if (ikon == null) return null;
    return ExcludeSemantics(child: Icon(ikon, color: r.metinGovde));
  }
}
