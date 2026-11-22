import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/presentation/ortak.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart' show SuzgecCipi;
import 'package:tayfam/features/tayfa/tayfa.dart' show tayfaOzetiProvider;
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın materyal kütüphanesi (`/t/<tayfaId>/materyal`; App ADR-0033
/// §2, Tayfam-Api ADR-0040 §3): başlıkta tayfanın adı, süzgeç (tür,
/// ders/konu, "Benimkiler") ve satırları tek kartta sayfalı liste (yeniden
/// eskiye). Aşağı çekince yenilenir. Süzgeç sunucuda uygulanır.
///
/// Satıra dokununca detay açılır; bağlantı listeden doğrudan açılmaz.
/// "Materyal ekle" sunucu `caller_can_add` derse görünür (kesin kural 5).
/// Modül kapalıysa sunucunun `module-disabled` hatası gösterilir.
class MateryalListeEkrani extends ConsumerStatefulWidget {
  const MateryalListeEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<MateryalListeEkrani> createState() =>
      _MateryalListeEkraniState();
}

class _MateryalListeEkraniState extends ConsumerState<MateryalListeEkrani> {
  MateryalSuzgeci _suzgec = suzgecYok;

  MateryalSorgusu get _sorgu => (tayfaId: widget.tayfaId, suzgec: _suzgec);

  void _suzgecAyarla(MateryalSuzgeci yeni) => setState(() => _suzgec = yeni);

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = materyalListesiProvider(_sorgu);
    final durum = ref.watch(saglayici);
    final ekleyebilir =
        durum.hasValue && ref.read(saglayici.notifier).ekleyebilir;
    final tayfaAdi = ref.watch(tayfaOzetiProvider(widget.tayfaId)).ad;
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(
        title: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.materyal_ad),
              if (tayfaAdi != null)
                Text(
                  tayfaAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.yazi.bodySmall,
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: ekleyebilir
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(
                materyalFormunuAc(context, tayfaId: widget.tayfaId),
              ),
              icon: const Icon(Icons.add),
              label: Text(m.materyal_ekle),
            )
          : null,
      body: TayfamYenile(
        onRefresh: _yenile,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                // Alttaki "Materyal ekle" düğmesi son satırı örtmesin.
                TayfamSpacing.s64 + TayfamSpacing.s40,
              ),
              children: [
                _Suzgec(suzgec: _suzgec, onDegisti: _suzgecAyarla),
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
                      etiket: m.materyal_yukleniyor,
                      gecikmeli: true,
                    ),
                  )
                else if (liste.ogeler.isEmpty)
                  TayfamKart(
                    child: Text(
                      suzgecBos(_suzgec)
                          ? m.materyal_bos
                          : m.materyal_bos_suzgec,
                      style: context.yazi.bodyMedium?.copyWith(
                        color: context.renkler.metinGovde,
                      ),
                    ),
                  )
                else ...[
                  ListeKarti(
                    children: [
                      for (final materyal in liste.ogeler)
                        MateryalSatiri(
                          key: ValueKey(materyal.id),
                          materyal: materyal,
                          onTap: () => unawaited(
                            context.push(
                              Adresler.materyalDetayi(
                                widget.tayfaId,
                                materyal.id,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (liste.dahaHatasi case final dahaHatasi?) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri.hatadan(dahaHatasi),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_tekrar_dene,
                        onPressed: _dahaFazla,
                      ),
                    ),
                  ] else if (liste.dahaYukleniyor) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    Center(
                      child: TayfamYukleniyor(etiket: m.materyal_yukleniyor),
                    ),
                  ] else if (liste.dahaVar) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    Center(
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_daha_fazla,
                        onPressed: _dahaFazla,
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

  void _dahaFazla() =>
      unawaited(ref.read(materyalListesiProvider(_sorgu).notifier).dahaFazla());

  /// Listeyi yeniler; başarısız olursa eldeki liste kalır ve hata kısa
  /// bildirimle gösterilir.
  Future<void> _yenile() async {
    final saglayici = materyalListesiProvider(_sorgu);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !mounted) return;
    if (ref.read(saglayici).hasValue) {
      yenilemeHatasiBildir(
        context,
        hata,
        tekrarDene: () => unawaited(_yenile()),
      );
    }
  }
}

/// Süzgeç çipleri: "Tümü", tür (bağlantı, not), ders/konu (alttan sayfada
/// ortak seçiciyle) ve "Benimkiler". Dar ekranda ve büyük yazıda alt
/// satıra iner.
class _Suzgec extends ConsumerWidget {
  const _Suzgec({required this.suzgec, required this.onDegisti});

  final MateryalSuzgeci suzgec;
  final ValueChanged<MateryalSuzgeci> onDegisti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final dersKonu = suzgec.dersKonu;
    final adlar = dersKonu == null
        ? null
        : dersKonuAdlari(
            ref.watch(katalogProvider).value,
            katalogDili(context),
            ders: dersKonu.ders,
            konu: dersKonu.konu,
          );
    final dersMetni = adlar == null
        ? ''
        : [adlar.ders, adlar.konu].nonNulls.join(' · ');
    return Semantics(
      container: true,
      label: m.materyal_suzgec,
      child: Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          SuzgecCipi(
            metin: m.materyal_suzgec_tumu,
            secili: suzgecBos(suzgec),
            onSecildi: () => onDegisti(suzgecYok),
          ),
          for (final tur in const [MaterialKind.link, MaterialKind.notePhoto])
            SuzgecCipi(
              metin: materyalTurAdi(m, tur),
              secili: suzgec.tur == tur,
              onSecildi: () => onDegisti((
                tur: suzgec.tur == tur ? null : tur,
                dersKonu: suzgec.dersKonu,
                benim: suzgec.benim,
              )),
            ),
          SuzgecCipi(
            metin: dersMetni.isEmpty ? m.materyal_ders_sec : dersMetni,
            secili: dersKonu != null,
            onSecildi: () => unawaited(_dersSec(context)),
          ),
          SuzgecCipi(
            metin: m.materyal_benimkiler,
            secili: suzgec.benim,
            onSecildi: () => onDegisti((
              tur: suzgec.tur,
              dersKonu: suzgec.dersKonu,
              benim: !suzgec.benim,
            )),
          ),
        ],
      ),
    );
  }

  Future<void> _dersSec(BuildContext context) async {
    final sonuc = await altSayfaAc<({DersKonuSecimi? secim})>(
      context,
      builder: (_) => _DersSuzgeciSayfasi(ilk: suzgec.dersKonu),
    );
    if (sonuc == null) return;
    onDegisti((tur: suzgec.tur, dersKonu: sonuc.secim, benim: suzgec.benim));
  }
}

/// Ders/konu süzgeci: ortak seçici, "Temizle" ve "Uygula".
class _DersSuzgeciSayfasi extends StatefulWidget {
  const _DersSuzgeciSayfasi({required this.ilk});

  final DersKonuSecimi? ilk;

  @override
  State<_DersSuzgeciSayfasi> createState() => _DersSuzgeciSayfasiState();
}

class _DersSuzgeciSayfasiState extends State<_DersSuzgeciSayfasi> {
  late DersKonuSecimi? _secim = widget.ilk;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return AltSayfaIcerigi(
      baslik: m.materyal_ders_suzgeci,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DersKonuSecici(
              secim: _secim,
              onDegisti: (yeni) => setState(() => _secim = yeni),
            ),
            const SizedBox(height: TayfamSpacing.s24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                IkincilEylem(
                  etiket: m.materyal_suzgec_temizle,
                  onPressed: () =>
                      Navigator.of(context)
                          .pop<({DersKonuSecimi? secim})>((secim: null)),
                ),
                BirincilEylem(
                  etiket: m.materyal_suzgec_uygula,
                  onPressed: () =>
                      Navigator.of(context)
                          .pop<({DersKonuSecimi? secim})>((secim: _secim)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
