import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Derece / sıralama bileşeni (`ranking`; Tayfam-Api ADR-0025 §4, §5,
/// ADR-0037 §3, #253; App ADR-0024 §3): katılımcıların bir süreye ya da
/// sıraya göre dizilişi, en iyi önde. Eşit değerler aynı sırayı paylaşır
/// (1, 1, 3); sırayı sunucu verir, istemci hesaplamaz.
///
/// - **Ölçümden** (`source`): aynı türdeki kişisel bir ölçümün kaydedilmiş
///   değerlerinden hesaplanır; ayrı giriş yoktur. Değer ölçümün birimiyle
///   gösterilir. Hassas ölçümde yetkisi olmayana derece gösterilmez,
///   nedeni yazılır (`hidden`).
/// - **Elle** (`metric`): `duration` (süre, `1:02:03,45`) ya da `rank`
///   (sıra); organizatör, moderatör, yönetici ve atanmış hakem katılımcı
///   başına girer (`caller_can_edit`).
///
/// Kişinin kendi satırı yazıyla ("Sen") işaretlidir; ekran okuyucu her
/// satırı tek öğe olarak "sıra, ad, değer" diye okur. Misafir oyuncu
/// dereceye girmez. Düğmeleri gizlemek kolaylıktır; yetkiyi sunucu verir
/// (kesin kural 5). Değerler etkinlik oluşturulurken yazılmaz; sihirbazda
/// form bölümü yoktur.
final class DereceBileseni extends KayitliBilesen {
  const DereceBileseni() : super('ranking');

  @override
  String ad(AppLocalizations m) => m.bilesen_ranking_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return DereceBolumu(
      kimlik: (
        tayfaId: tayfaId,
        etkinlikId: etkinlik.id,
        anahtar: b.anahtar,
        kaynak: b.params.metin('source'),
      ),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Bir derece işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef DereceIslemi = Future<Object?> Function(DereceNotifier derece);

/// Derece bileşeninin detaydaki bölümü: başlık ve sıralı liste. Okunurken
/// yer tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class DereceBolumu extends ConsumerStatefulWidget {
  const DereceBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final DereceKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<DereceBolumu> createState() => _DereceBolumuState();
}

class _DereceBolumuState extends ConsumerState<DereceBolumu> {
  bool _mesgul = false;

  DereceNotifier get _notifier =>
      ref.read(dereceProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir. Aynı anda tek
  /// işlem yapılır.
  Future<void> _calistir(DereceIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  /// Değer formunu açar: [kisi] verilirse o kişinin derecesi, verilmezse
  /// kişi formda seçilir.
  Future<void> _formuAc(
    EventRanking derece, {
    required String baslik,
    double? ilkDeger,
    String? kisi,
  }) => aracFormuAc<void>(
    context,
    (_) => DereceFormu(
      derece: derece,
      baslik: baslik,
      ilkDeger: ilkDeger,
      kisiSecimi: kisi == null
          ? (
              tayfaId: widget.kimlik.tayfaId,
              etkinlikId: widget.kimlik.etkinlikId,
              durum: ListEventAttendeesStatus.going,
            )
          : null,
      gonder: (secilen, deger) {
        final hedef = kisi ?? secilen;
        if (hedef == null) return Future<Object?>.value();
        return _notifier.degeriYaz(hedef, deger);
      },
    ),
  );

  Future<void> _kaldir(String kullaniciId) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_ranking_kaldir_onay,
      eylem: m.bilesen_ranking_kaldir,
    );
    if (!onay || !mounted) return;
    await _calistir((d) => d.degeriKaldir(kullaniciId));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_ranking_ad,
    );
    final okunan = ref.watch(dereceProvider(widget.kimlik));
    final derece = okunan.value;
    if (derece == null) {
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
      children: [baslik, ..._icerik(derece)],
    );
  }

  List<Widget> _icerik(EventRanking derece) {
    final m = AppLocalizations.of(context);
    if (!dereceOlcutuTanindi(derece)) {
      return [AracBilgisi(metin: m.bilesen_ranking_guncelle)];
    }
    if (derece.hidden) {
      return [AracBilgisi(metin: m.bilesen_ranking_gizli)];
    }
    if (!derece.measureEnabled) {
      return [AracBilgisi(metin: m.bilesen_ranking_olcum_kapali)];
    }
    final elle = dereceElle(derece);
    final etkinlik = widget.etkinlik;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final baslamadi =
        !iptalEdildi(etkinlik) && simdi.isBefore(etkinlik.startsAt);
    final bos = baslamadi
        ? m.bilesen_ranking_baslamadi
        : elle
        ? m.bilesen_ranking_yok
        : m.bilesen_ranking_olcum_yok;
    final ben = ref.watch(kendiKimligimProvider).value;
    final yazabilir = elle && derece.callerCanEdit;
    return [
      AracListesi(
        bos: bos,
        satirlar: [
          for (final kayit in derece.entries)
            DereceSatiri(
              key: ValueKey(kayit.userId),
              kullaniciId: kayit.userId,
              sira: kayit.rank,
              deger: dereceDegeriMetni(m, derece, kayit.value),
              degerOkunusu: dereceDegeriOkunusu(m, derece, kayit.value),
              benim: ben != null && kayit.userId == ben,
              degisebilir: yazabilir,
              mesgul: _mesgul,
              onDuzelt: () => unawaited(
                _formuAc(
                  derece,
                  baslik: m.bilesen_ranking_duzelt,
                  ilkDeger: kayit.value,
                  kisi: kayit.userId,
                ),
              ),
              onKaldir: () => unawaited(_kaldir(kayit.userId)),
            ),
        ],
      ),
      if (yazabilir) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: m.bilesen_ranking_kisi_ekle,
          ikon: Icons.add,
          onPressed: _mesgul
              ? null
              : () => unawaited(
                  _formuAc(derece, baslik: m.bilesen_ranking_kisi_ekle),
                ),
        ),
      ],
      if (!elle) ...[
        const SizedBox(height: TayfamSpacing.s8),
        AracBilgisi(metin: m.bilesen_ranking_olcumden),
      ],
    ];
  }
}

/// Derecede bir satır: sıra, ad, kişinin kendisiyse
/// "Sen" etiketi ve değer; [degisebilir] ise "Düzelt" ve "Dereceyi
/// kaldır". Sıra, ad ve değer ekran okuyucuda tek öğe okunur ("1. sıra,
/// Ayşe, 1 saat 2 dakika 3,45 saniye"); bu yüzden ad profile dokunma alanı
/// değildir (ayrı ekran okuyucu öğesi olurdu). Dar ekranda ve büyük yazıda
/// değer adın altına iner.
class DereceSatiri extends StatelessWidget {
  const DereceSatiri({
    super.key,
    required this.kullaniciId,
    required this.sira,
    required this.deger,
    required this.benim,
    required this.degisebilir,
    required this.mesgul,
    required this.onDuzelt,
    required this.onKaldir,
    this.degerOkunusu,
  });

  final String kullaniciId;

  /// Sunucunun verdiği sıra (eşitler aynı sırayı paylaşır).
  final int sira;

  /// Değerin yazımı; `null`: değer sıranın kendisidir, yazılmaz.
  final String? deger;

  /// Değerin ekran okuyucu metni; `null`: [deger] okunur.
  final String? degerOkunusu;

  /// Satır oturumdaki kişinin.
  final bool benim;

  final bool degisebilir;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onDuzelt;
  final VoidCallback onKaldir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final r = context.renkler;
    const rakam = [FontFeature.tabularFigures()];
    final deger = this.deger;
    return Row(
      children: [
        Expanded(
          child: MergeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Row(
                children: [
                  Text(
                    m.bilesen_ranking_sira(sira),
                    semanticsLabel: m.bilesen_ranking_sira_okunus(sira),
                    style: yazi.titleSmall?.copyWith(
                      color: r.metinGovde,
                      fontFeatures: rakam,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: TayfamSpacing.s8,
                      runSpacing: TayfamSpacing.s4,
                      children: [
                        Wrap(
                          spacing: TayfamSpacing.s8,
                          runSpacing: TayfamSpacing.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            KullaniciAdiMetni(
                              kullaniciId: kullaniciId,
                              style: yazi.bodyLarge,
                            ),
                            if (benim) Etiket(metin: m.bilesen_ranking_sen),
                          ],
                        ),
                        if (deger != null)
                          Text(
                            deger,
                            semanticsLabel: degerOkunusu,
                            style: yazi.titleSmall?.copyWith(
                              fontFeatures: rakam,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (degisebilir) ...[
          AracIkonDugmesi(
            ipucu: m.bilesen_ranking_duzelt,
            ikon: Icons.edit_outlined,
            onPressed: mesgul ? null : onDuzelt,
          ),
          AracIkonDugmesi(
            ipucu: m.bilesen_ranking_kaldir,
            ikon: Icons.delete_outline,
            onPressed: mesgul ? null : onKaldir,
          ),
        ],
      ],
    );
  }
}
