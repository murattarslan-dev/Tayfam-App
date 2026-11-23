import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/kalem_formu.dart';
import 'package:tayfam/features/kutuphane/presentation/odunc_adimlari.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kalem detayı (`/t/<tayfaId>/kutuphane/<kalemId>`; Tayfam-Api ADR-0040
/// §1).
///
/// Herkes adı, türü, sahibini, notu, fotoğrafı, durumu ve sıradaki kişi
/// sayısını görür. Ödünç (`active_loan`) yalnızca iki tarafına, sıra
/// (`queue`) yalnızca sahibine döner; istemci de başka bilgi göstermez.
///
/// - Sahibi: ödüncün adımları, sıra, "Düzenle" ve "Geri çek" (onaylı,
///   geri alınamaz).
/// - Diğer üyeler: "Ödünç iste" (sunucu ödünç açar ya da sıraya koyar),
///   sıradaysa yeri ve "Sıradan çık", "Şikâyet et"; moderatöre "Kaldır".
///
/// Kalem bulunamazsa (`library-item-not-found`: geri çekilmiş, kaldırılmış
/// ya da hiç yok; örneğin ödünç adımı bildiriminden gelindi) "Tekrar dene"
/// yerine "Bu eşya artık kütüphanede değil" ve "Kütüphaneye git" çıkar
/// ([kalemYokMu]); kalemin adı bilinmez, yazılmaz.
///
/// Sahiplik kendi kimliğinle karşılaştırılarak yalnızca arayüzü
/// sadeleştirir; yetkiyi sunucu verir (kesin kural 5).
class KalemEkrani extends ConsumerStatefulWidget {
  const KalemEkrani({super.key, required this.tayfaId, required this.kalemId});

  final String tayfaId;

  /// Adresteki kalem kimliği (girdi; sunucu bilinmeyeni reddeder).
  final String kalemId;

  @override
  ConsumerState<KalemEkrani> createState() => _KalemEkraniState();
}

enum _Islem { duzenle, geriCek, kaldir, sikayet }

class _KalemEkraniState extends ConsumerState<KalemEkrani> {
  bool _mesgul = false;

  KalemAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, kalemId: widget.kalemId);

  KutuphaneIslemleri get _islemler => ref.read(kutuphaneIslemleriProvider);

  Future<void> _calistir(Future<void> Function() is_) async {
    setState(() => _mesgul = true);
    try {
      await is_();
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  /// Kalem yoksa kütüphane listesi açılır; liste önbelleği eski kalemi
  /// göstermesin diye yenilenir. Yönlendirici yoksa (ekran bir sayfanın
  /// üstünde açıldıysa) geri dönülür.
  void _kutuphaneyeGit() {
    ref.invalidate(kalemlerProvider);
    final yonlendirici = GoRouter.maybeOf(context);
    if (yonlendirici != null) {
      yonlendirici.go(kutuphaneAdresi(widget.tayfaId));
    } else {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  void _bildir(String metin) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(metin)));

  Future<void> _iste() {
    final m = AppLocalizations.of(context);
    return _calistir(() async {
      final kalem = await _islemler.iste(widget.tayfaId, widget.kalemId);
      if (!mounted) return;
      final sira = kalem.callerQueueRank;
      _bildir(
        sira != null
            ? m.kutuphane_siraya_girdin(sira)
            : m.kutuphane_istek_gonderildi,
      );
    });
  }

  Future<void> _siradanCik() {
    final m = AppLocalizations.of(context);
    return _calistir(() async {
      await _islemler.istegiGeriAl(widget.tayfaId, widget.kalemId);
      if (mounted) _bildir(m.kutuphane_siradan_ciktin);
    });
  }

  Future<void> _islem(_Islem islem, LibraryItem kalem) async {
    final m = AppLocalizations.of(context);
    switch (islem) {
      case _Islem.duzenle:
        final kayit = await kalemFormunuAc(
          context,
          widget.tayfaId,
          mevcut: kalem,
        );
        if (kayit != null && mounted) _bildir(m.kutuphane_kaydedildi);
      case _Islem.geriCek || _Islem.kaldir:
        final sahip = islem == _Islem.geriCek;
        final onay = await yikiciOnay(
          context,
          baslik: sahip
              ? m.kutuphane_geri_cek_baslik
              : m.kutuphane_kaldir_baslik,
          metin: m.kutuphane_geri_cek_metni,
          eylem: sahip ? m.kutuphane_geri_cek : m.kutuphane_kaldir,
        );
        if (!onay || !mounted) return;
        await _calistir(() async {
          await _islemler.geriCek(widget.tayfaId, widget.kalemId);
          if (!mounted) return;
          _bildir(sahip ? m.kutuphane_geri_cekildi : m.kutuphane_kaldirildi);
          Navigator.of(context).pop();
        });
      case _Islem.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: widget.tayfaId,
            tur: ReportTargetType.libraryItem,
            id: kalem.id,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = kalemProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final kalem = durum.value;
    final hata = durum.error;
    final sahip = kalem?.ownerUserId;
    final benim = sahip != null && ref.watch(kendisiMiProvider(sahip));
    final yonetimde = ref.watch(tayfaOzetiProvider(widget.tayfaId)).yonetimde;
    return Scaffold(
      appBar: AppBar(
        title: Text(m.kutuphane_kalem_baslik),
        actions: [
          if (kalem != null)
            PopupMenuButton<_Islem>(
              tooltip: m.kutuphane_secenekler,
              icon: const Icon(Icons.more_vert),
              enabled: !_mesgul,
              onSelected: (islem) => unawaited(_islem(islem, kalem)),
              itemBuilder: (_) => [
                if (benim) ...[
                  PopupMenuItem(
                    value: _Islem.duzenle,
                    child: Text(m.kutuphane_duzenle),
                  ),
                  PopupMenuItem(
                    value: _Islem.geriCek,
                    child: Text(m.kutuphane_geri_cek),
                  ),
                ] else ...[
                  PopupMenuItem(
                    value: _Islem.sikayet,
                    child: Text(m.kutuphane_sikayet_et),
                  ),
                  if (yonetimde)
                    PopupMenuItem(
                      value: _Islem.kaldir,
                      child: Text(m.kutuphane_kaldir),
                    ),
                ],
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch ((kalem, hata)) {
          (final kalem?, _) => _Icerik(
            tayfaId: widget.tayfaId,
            kalem: kalem,
            benim: benim,
            mesgul: _mesgul,
            onIste: () => unawaited(_iste()),
            onSiradanCik: () => unawaited(_siradanCik()),
          ),
          (null, final hata?) when kalemYokMu(hata) => _KalemYok(
            onKutuphane: _kutuphaneyeGit,
          ),
          (null, final hata?) => YuklemeHatasi(
            hata: hata,
            onTekrarDene: () => ref.invalidate(saglayici),
          ),
          (null, null) => Center(
            child: TayfamYukleniyor(etiket: m.kutuphane_yukleniyor),
          ),
        },
      ),
    );
  }
}

/// Kalem bulunamadı mı (`library-item-not-found`). Geri çekilme,
/// kaldırılma ve hiç olmama bilerek ayrılmaz; öteki hatalar (bağlantı,
/// üyelik) "Tekrar dene" ile gösterilir.
bool kalemYokMu(Object hata) => switch (hata) {
  ApiProblem(type: ProblemType.libraryItemNotFound) => true,
  _ => false,
};

/// "Bu eşya artık kütüphanede değil": ortada ikon, açıklama ve
/// "Kütüphaneye git".
class _KalemYok extends StatelessWidget {
  const _KalemYok({required this.onKutuphane});

  final VoidCallback onKutuphane;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return ListView(
      children: [
        OrtaDurum(
          ikon: Icons.inventory_2_outlined,
          baslik: m.hata_library_item_not_found,
          aciklama: m.kutuphane_kalem_yok_aciklama,
          eylem: CerceveliHapEylem(
            etiket: m.kutuphane_kalem_yok_eylem,
            onPressed: onKutuphane,
          ),
        ),
      ],
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({
    required this.tayfaId,
    required this.kalem,
    required this.benim,
    required this.mesgul,
    required this.onIste,
    required this.onSiradanCik,
  });

  final String tayfaId;
  final LibraryItem kalem;
  final bool benim;
  final bool mesgul;
  final VoidCallback onIste;
  final VoidCallback onSiradanCik;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final foto = kalem.photoUploadId;
    final not = kalem.note;
    final sahip = kalem.ownerUserId;
    final odunc = kalem.activeLoan;
    final sira = kalem.queue ?? const <LibraryQueueEntry>[];
    final ikincil = yazi.bodyMedium?.copyWith(color: r.metinGovde);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s12,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s40,
      ),
      children: [
        if (foto != null) ...[
          ClipRRect(
            borderRadius: TayfamRadii.onizlemeKoseleri,
            child: AspectRatio(
              aspectRatio: TayfamSizes.kapakOrani,
              child: MedyaGorseli(
                uploadId: foto,
                etiket: m.kutuphane_fotograf_alani,
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s16),
        ],
        Text(kalem.name, style: yazi.titleLarge?.copyWith(color: r.metin)),
        const SizedBox(height: TayfamSpacing.s8),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            TurEtiketi(tur: kalem.kind),
            DurumEtiketi(durum: kalem.status),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s12),
        MergeSemantics(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TayfamSpacing.s4,
            children: [
              Text(m.kutuphane_sahibi, style: ikincil),
              if (sahip == null)
                Text(m.kullanici_silinmis, style: ikincil)
              else
                KisiyeDokun(
                  kullaniciId: sahip,
                  child: KullaniciAdiMetni(
                    kullaniciId: sahip,
                    maxLines: 1,
                    style: yazi.bodyMedium?.copyWith(
                      color: r.metin,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (not != null && not.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s12),
          Text(not, style: yazi.bodyLarge?.copyWith(color: r.metin)),
        ],
        if (kalem.queueLength > 0) ...[
          const SizedBox(height: TayfamSpacing.s12),
          Text(m.kutuphane_sira_uzunlugu(kalem.queueLength), style: ikincil),
        ],
        const SizedBox(height: TayfamSpacing.s24),
        BolumBasligi(baslik: m.kutuphane_odunc_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        if (odunc != null)
          TayfamKart(
            child: OduncAdimlari(tayfaId: tayfaId, odunc: odunc),
          )
        else if (benim)
          Text(m.kutuphane_odunc_yok_sahip, style: ikincil)
        else
          _IstekBolumu(
            kalem: kalem,
            mesgul: mesgul,
            onIste: onIste,
            onSiradanCik: onSiradanCik,
          ),
        if (benim && sira.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s24),
          BolumBasligi(baslik: m.kutuphane_sira_baslik),
          const SizedBox(height: TayfamSpacing.s8),
          ListeKarti(
            children: [
              for (final s in sira)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TayfamSpacing.s16,
                    vertical: TayfamSpacing.s12,
                  ),
                  child: MergeSemantics(
                    child: Row(
                      children: [
                        Text(
                          m.kutuphane_sira_no(s.rank),
                          style: yazi.labelLarge?.copyWith(
                            color: r.metinIkincil,
                          ),
                        ),
                        const SizedBox(width: TayfamSpacing.s12),
                        Expanded(
                          child: KullaniciAdiMetni(
                            kullaniciId: s.userId,
                            maxLines: 2,
                            style: yazi.bodyLarge?.copyWith(color: r.metin),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ödüncün tarafı olmayan üye: "Ödünç iste" ya da sıradaki yeri ve
/// "Sıradan çık". Kalem başkasındaysa kimde olduğu yazılmaz.
class _IstekBolumu extends StatelessWidget {
  const _IstekBolumu({
    required this.kalem,
    required this.mesgul,
    required this.onIste,
    required this.onSiradanCik,
  });

  final LibraryItem kalem;
  final bool mesgul;
  final VoidCallback onIste;
  final VoidCallback onSiradanCik;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final sira = kalem.callerQueueRank;
    if (mesgul) {
      return Center(child: TayfamYukleniyor(etiket: m.kutuphane_isleniyor));
    }
    if (sira != null) {
      return TayfamKart(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              m.kutuphane_siradaki_yerin(sira),
              style: yazi.titleMedium?.copyWith(color: r.metin),
            ),
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              m.kutuphane_sira_aciklama,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IkincilEylem(
                etiket: m.kutuphane_siradan_cik,
                onPressed: onSiradanCik,
              ),
            ),
          ],
        ),
      );
    }
    final musait = kalem.status == LibraryItemStatus.available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          musait ? m.kutuphane_iste_aciklama : m.kutuphane_sira_gir_aciklama,
          style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        BirincilEylem(
          etiket: musait ? m.kutuphane_odunc_iste : m.kutuphane_siraya_gir,
          ikon: Icons.front_hand_outlined,
          onPressed: onIste,
        ),
      ],
    );
  }
}
