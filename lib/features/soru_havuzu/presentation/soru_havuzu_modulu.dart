import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/soru_havuzu/application/havuz_listesi.dart';
import 'package:tayfam/features/soru_havuzu/presentation/havuz_ekrani.dart';
import 'package:tayfam/features/soru_havuzu/presentation/havuz_karti.dart';
import 'package:tayfam/features/soru_havuzu/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Havuz sorusu rotasındaki soru kimliği parametresinin adı.
const String havuzSoruIdParametresi = 'havuzSoruId';

/// Soru havuzu modülü (`question_pool`; ADR-0002, App ADR-0033 §2,
/// Tayfam-Api ADR-0040 §2): Eğitim tayfalarının takıldıkları soruları
/// birbirine sorduğu havuz.
///
/// Rotalar `/t/<tayfaId>/soru-havuzu` (liste) ve
/// `…/soru-havuzu/<soruId>` (soru ve cevaplar; Soru-Cevap'ın detay
/// ekranı, havuz görünümüyle). Ana sayfadaki kartı modül bölümü değil,
/// `question_pool` ana sayfa bileşenidir ([SoruHavuzuBileseni]); modül
/// kapalıysa sunucunun `modules` alanına göre görünmez.
class SoruHavuzuModulu implements TayfaModule {
  const SoruHavuzuModulu();

  @override
  String get sunucuAnahtari => Module.questionPool.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.soruHavuzuYolu,
      builder: (context, state) => HavuzEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: ':$havuzSoruIdParametresi',
          builder: (context, state) => SoruEkrani(
            tayfaId: _tayfaId(state),
            soruId: state.pathParameters[havuzSoruIdParametresi]!,
          ),
        ),
      ],
    ),
  ];

  /// Kart ana sayfa bileşeni kaydından çizilir; modülün ayrı bölümü yok.
  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      const SizedBox.shrink();

  @override
  Widget? anaSayfaOneCikan(BuildContext context, String tayfaId) => null;

  @override
  OlusturmaSecenegi? get olusturmaSecenegi => const OlusturmaSecenegi(
    ikon: Icons.school_outlined,
    baslik: _olusturBaslik,
    aciklama: _olusturAciklama,
    izinli: _herUye,
    ac: _soruSor,
  );

  @override
  KurulumAdimi? get kurulumAdimi => null;

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) =>
      _yenile(ref, tayfaId);
}

String _olusturBaslik(BuildContext context) =>
    AppLocalizations.of(context).soru_havuzu_olustur;

String _olusturAciklama(BuildContext context) =>
    AppLocalizations.of(context).soru_havuzu_olustur_aciklama;

/// Her üye soru sorabilir; yetkiyi sunucu verir (kesin kural 5).
bool _herUye(TayfaYetkisi yetki) => true;

void _soruSor(BuildContext context, String tayfaId) =>
    unawaited(havuzSoruFormunuAc(context, tayfaId: tayfaId));

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;

Future<void> _yenile(WidgetRef ref, String tayfaId) async {
  final liste = havuzListesiProvider(anaHavuzListesi(tayfaId));
  if (ref.read(liste.exists)) await ref.read(liste.notifier).yenile();
}

/// Ana sayfadaki "Soru havuzu" bileşeni (`question_pool`, `kind:
/// module`): son sorular. Ayarı yoktur.
final class SoruHavuzuBileseni implements AnaSayfaBileseni {
  const SoruHavuzuBileseni();

  @override
  String get anahtar => Module.questionPool.wire;

  @override
  IconData get ikon => Icons.school_outlined;

  @override
  String ad(BuildContext context) => AppLocalizations.of(context).soru_havuzu_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).soru_havuzu_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      HavuzKarti(tayfaId: tayfaId);

  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) => _yenile(ref, tayfaId);

  @override
  BilesenAyari? get ayar => null;
}

/// Havuz sorusunun soru-cevap ekranlarındaki görünümü: ders/konu,
/// fotoğraflar ve havuz formları. Kayıtta `soruHavuzuGorunumuProvider`'a
/// verilir.
final class HavuzGorunumu implements SoruHavuzuGorunumu {
  const HavuzGorunumu();

  @override
  Widget soruIcerigi(BuildContext context, Question soru) =>
      HavuzSoruIcerigi(soru: soru);

  @override
  Widget? cevapEki(BuildContext context, Answer cevap) =>
      cevap.photoUploadIds.isEmpty
      ? null
      : HavuzFotograflari(kimlikler: cevap.photoUploadIds);

  @override
  Future<void> soruyuDuzenle(BuildContext context, Question soru) =>
      havuzSoruFormunuAc(context, tayfaId: soru.tayfaId, duzenlenen: soru);

  @override
  Future<void> cevapFormunuAc(
    BuildContext context,
    Question soru, {
    Answer? duzenlenen,
  }) => havuzCevapFormunuAc(context, soru: soru, duzenlenen: duzenlenen);

  @override
  void soruDegisti(WidgetRef ref, Question soru) =>
      havuzListelerineUygulaEkrandan(
        ref,
        soru.tayfaId,
        (l) => l.guncelle(soru),
      );

  @override
  void soruSilindi(WidgetRef ref, Question soru) =>
      havuzListelerineUygulaEkrandan(
        ref,
        soru.tayfaId,
        (l) => l.cikar(soru.id),
      );
}

/// Havuz sorusunun detaydaki içeriği: ders/konu etiketleri, soran ve
/// tarih, düz metin (biçim ve bağlantı yorumlanmaz) ve fotoğraflar.
class HavuzSoruIcerigi extends StatelessWidget {
  const HavuzSoruIcerigi({super.key, required this.soru});

  final Question soru;

  @override
  Widget build(BuildContext context) {
    final metin = soru.body.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: DersKonuEtiketleri(
              ders: soru.subjectKey,
              konu: soru.topicKey,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          YazarSatiri(yazarId: soru.authorUserId, zaman: soru.createdAt),
          if (metin.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s12),
            SelectableText(
              metin,
              style: context.yazi.bodyLarge?.copyWith(
                color: context.renkler.metin,
              ),
            ),
          ],
          if (soru.photoUploadIds.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s12),
            HavuzFotograflari(kimlikler: soru.photoUploadIds),
          ],
        ],
      ),
    );
  }
}
