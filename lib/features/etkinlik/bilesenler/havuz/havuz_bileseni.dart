import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/havuz/havuz_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/soru_havuzu/soru_havuzu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru havuzu bağlantısı bileşeni (`pool_link`; Tayfam-Api #271,
/// ADR-0037 §3, ADR-0040 §2; App ADR-0024 §3): etkinliği (soru çözüm
/// oturumu) tayfanın soru havuzundaki sorulara bağlar.
///
/// - Bağlı sorular organizatörün sırasıyla listelenir; dokununca soru
///   havuzundaki sorusu ve cevapları açılır. Sorular, cevaplar ve oylar
///   havuzda kalır.
/// - Organizatör, moderatör ve yönetici listeyi seçim sayfasından
///   değiştirir (en çok `max_links`); düğme yalnızca `caller_can_edit`
///   iken görünür, kararı sunucu verir (kesin kural 5).
/// - Tayfanın soru havuzu modülü kapalıysa (`module-disabled`) bölüm
///   bunu söyler.
///
/// Etkinlik oluşturulurken soru bağlanmaz; sihirbazda form bölümü yoktur.
/// Etkinlik kartındaki satır liste yanıtı bileşen verisi taşımadığı için
/// çizilmez (ADR-0024 Notlar).
final class HavuzBaglantisiBileseni extends KayitliBilesen {
  const HavuzBaglantisiBileseni() : super('pool_link');

  @override
  String ad(AppLocalizations m) => m.bilesen_pool_link_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return HavuzBaglantisiBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
    );
  }
}

/// Bileşenin detaydaki bölümü: başlık, bağlı sorular ve (yetkiliye)
/// "Soruları seç". Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar
/// dene".
class HavuzBaglantisiBolumu extends ConsumerWidget {
  const HavuzBaglantisiBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
  });

  final HavuzBaglantisiKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = havuzBaglantilariProvider(kimlik);
    final okunan = ref.watch(saglayici);
    final veri = okunan.value;
    final baslikMetni =
        katalogAdi(tanim.labels, katalogDili(context)) ??
        m.bilesen_pool_link_ad;
    if (veri == null) {
      final hata = okunan.error;
      if (hata == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AracBasligi(metin: baslikMetni),
          if (hata is ApiProblem && hata.type == ProblemType.moduleDisabled)
            AracBilgisi(metin: m.bilesen_pool_link_modul_kapali)
          else ...[
            HataSatiri.hatadan(hata),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BaglantiEylemi(
                etiket: m.etkinlik_tekrar_dene,
                onPressed: () =>
                    unawaited(ref.read(saglayici.notifier).yenile()),
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(
          metin: baslikMetni,
          sag: veri.callerCanEdit
              ? CerceveliHapEylem(
                  etiket: m.bilesen_pool_link_sec,
                  ikon: Icons.playlist_add_check,
                  onPressed: () => unawaited(_secimiAc(context, ref, veri)),
                )
              : null,
        ),
        if (veri.questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
            child: AracBilgisi(metin: m.bilesen_pool_link_bos),
          )
        else
          ListeKarti(
            children: [
              for (final soru in veri.questions)
                HavuzSoruSatiri(
                  key: ValueKey(soru.questionId),
                  ders: soru.subjectKey,
                  konu: soru.topicKey,
                  metin: soru.body,
                  fotografSayisi: soru.photoUploadIds.length,
                  cevapSayisi: soru.answerCount,
                  satirSayisi: 2,
                  onTap: () => unawaited(
                    context.push(
                      Adresler.havuzSorusu(kimlik.tayfaId, soru.questionId),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _secimiAc(
    BuildContext context,
    WidgetRef ref,
    EventPoolLinks veri,
  ) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final secilen = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<List<String>>(
        fullscreenDialog: true,
        builder: (_) => HavuzSecimSayfasi(
          tayfaId: kimlik.tayfaId,
          ilk: [for (final s in veri.questions) s.questionId],
          enCok: veri.maxLinks,
        ),
      ),
    );
    if (secilen == null || !context.mounted) return;
    final hata = await ref
        .read(havuzBaglantilariProvider(kimlik).notifier)
        .yaz(secilen);
    if (!context.mounted) return;
    if (hata != null) {
      hataBildir(context, hata);
      return;
    }
    bildirim
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m.bilesen_pool_link_kaydedildi)));
  }
}

/// Bağlanacak soruların seçimi (tam ekran): tayfanın soru havuzu,
/// yeniden eskiye ve sayfalı; her satır işaret kutulu. Seçim sırası
/// bağlantı sırasıdır (önce mevcutlar, sonra yeni seçilenler). En çok
/// [enCok] soru seçilir; sınıra gelince işaretsiz satırlar pasifleşir ve
/// sayaç bunu söyler. "Kaydet" seçilen kimlikleri döndürür.
class HavuzSecimSayfasi extends ConsumerStatefulWidget {
  const HavuzSecimSayfasi({
    super.key,
    required this.tayfaId,
    required this.ilk,
    required this.enCok,
  });

  final String tayfaId;

  /// Şu an bağlı soruların kimlikleri, sırasıyla.
  final List<String> ilk;

  /// Bileşenin `max_links` değeri.
  final int enCok;

  @override
  ConsumerState<HavuzSecimSayfasi> createState() => _HavuzSecimSayfasiState();
}

class _HavuzSecimSayfasiState extends ConsumerState<HavuzSecimSayfasi> {
  late final List<String> _secilen = [...widget.ilk];

  void _degistir(String id, {required bool secili}) {
    setState(() {
      if (!secili) {
        _secilen.remove(id);
      } else if (!_secilen.contains(id) && _secilen.length < widget.enCok) {
        _secilen.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = havuzSecimListesiProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    final dolu = _secilen.length >= widget.enCok;
    final katalog = ref.watch(katalogProvider).value;
    final dil = katalogDili(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(m.bilesen_pool_link_sec),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s12),
            child: Center(
              child: BirincilEylem(
                etiket: m.bilesen_pool_link_kaydet,
                onPressed: () => Navigator.of(context).pop(_secilen),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s40,
              ),
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    m.bilesen_pool_link_sayac(_secilen.length, widget.enCok),
                    style: context.yazi.bodyMedium?.copyWith(
                      color: dolu ? r.metin : r.metinGovde,
                    ),
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s12),
                if (liste == null && hata != null)
                  YuklemeHatasi(
                    hata: hata,
                    onTekrarDene: () => ref.invalidate(saglayici),
                  )
                else if (liste == null)
                  Center(
                    child: TayfamYukleniyor(
                      boyut: TayfamSizes.yukleniyorTamEkran,
                      etiket: m.bilesen_pool_link_yukleniyor,
                      gecikmeli: true,
                    ),
                  )
                else if (liste.ogeler.isEmpty)
                  AracBilgisi(metin: m.bilesen_pool_link_havuz_bos)
                else ...[
                  ListeKarti(
                    children: [
                      for (final soru in liste.ogeler)
                        _SecimSatiri(
                          key: ValueKey(soru.id),
                          soru: soru,
                          alt: _altMetin(katalog, dil, soru),
                          secili: _secilen.contains(soru.id),
                          etkin: !dolu || _secilen.contains(soru.id),
                          onDegisti: (secili) =>
                              _degistir(soru.id, secili: secili),
                        ),
                    ],
                  ),
                  if (liste.dahaHatasi case final dahaHatasi?) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri.hatadan(dahaHatasi),
                  ],
                  if (liste.dahaYukleniyor) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    Center(
                      child: TayfamYukleniyor(
                        etiket: m.bilesen_pool_link_yukleniyor,
                      ),
                    ),
                  ] else if (liste.dahaVar) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    Center(
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_daha_fazla,
                        onPressed: () => unawaited(
                          ref.read(saglayici.notifier).dahaFazla(),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _altMetin(Katalog? katalog, String dil, Question soru) {
    final adlar = dersKonuAdlari(
      katalog,
      dil,
      ders: soru.subjectKey,
      konu: soru.topicKey,
    );
    final metin = [adlar.ders, adlar.konu].nonNulls.join(' · ');
    return metin.isEmpty ? null : metin;
  }
}

/// Seçim sayfasındaki bir soru: işaret kutusu, metnin ilk satırları
/// (metinsiz soruda "Fotoğraflı soru") ve ders/konu. Bütün satır tek
/// dokunma alanıdır.
class _SecimSatiri extends StatelessWidget {
  const _SecimSatiri({
    super.key,
    required this.soru,
    required this.alt,
    required this.secili,
    required this.etkin,
    required this.onDegisti,
  });

  final Question soru;
  final String? alt;
  final bool secili;
  final bool etkin;
  final ValueChanged<bool> onDegisti;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final metin = soru.body.trim();
    final alt = this.alt;
    return CheckboxListTile(
      value: secili,
      onChanged: etkin ? (v) => onDegisti(v ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        metin.isEmpty ? m.soru_havuzu_fotografli_soru : metin,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: alt == null ? null : Text(alt),
    );
  }
}
