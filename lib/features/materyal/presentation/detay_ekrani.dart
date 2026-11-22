import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/api/gen/models.dart' as api show Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/presentation/ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart'
    show YazarSatiri, bildirimGoster;
import 'package:tayfam/l10n/app_localizations.dart';

/// Materyal detayı (`/t/<tayfaId>/materyal/<materyalId>`; Tayfam-Api
/// ADR-0040 §3): tür, ders/konu, başlık, yazar ve tarih; bağlantıda alan
/// adı ve "Bağlantıyı aç" (önce "Tayfam dışına çıkıyorsun" uyarısı), not
/// fotoğrafında fotoğraflar.
///
/// Menü: "Düzenle" sunucu `caller_can_edit` derse, "Sil" (yazarı) ya da
/// "Kaldır" (moderatör) `caller_can_delete` derse; yazar olmayana
/// "Şikâyet et". Yetkiyi sunucu verir (kesin kural 5).
class MateryalDetayEkrani extends ConsumerStatefulWidget {
  const MateryalDetayEkrani({
    super.key,
    required this.tayfaId,
    required this.materyalId,
  });

  final String tayfaId;

  /// Adresteki materyal kimliği (girdi; sunucu bilinmeyeni reddeder).
  final String materyalId;

  @override
  ConsumerState<MateryalDetayEkrani> createState() =>
      _MateryalDetayEkraniState();
}

enum _Islem { duzenle, sil, kaldir, sikayet }

class _MateryalDetayEkraniState extends ConsumerState<MateryalDetayEkrani> {
  bool _mesgul = false;

  MateryalAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, materyalId: widget.materyalId);

  Future<void> _islem(_Islem islem, api.Material materyal) async {
    final m = AppLocalizations.of(context);
    switch (islem) {
      case _Islem.duzenle:
        await materyalFormunuAc(
          context,
          tayfaId: widget.tayfaId,
          duzenlenen: materyal,
        );
      case _Islem.sil || _Islem.kaldir:
        final yazar = islem == _Islem.sil;
        final onay = await _yikiciOnay(
          context,
          baslik: yazar ? m.materyal_sil_baslik : m.materyal_kaldir_baslik,
          metin: m.materyal_sil_metni,
          eylem: yazar ? m.materyal_sil : m.materyal_kaldir,
        );
        if (!onay || !mounted) return;
        setState(() => _mesgul = true);
        try {
          await ref
              .read(materyalIslemleriProvider)
              .sil(widget.tayfaId, widget.materyalId);
          if (!mounted) return;
          bildirimGoster(
            ScaffoldMessenger.of(context),
            yazar ? m.materyal_silindi : m.materyal_kaldirildi,
          );
          Navigator.of(context).pop();
        } on Exception catch (hata) {
          if (mounted) hataBildir(context, hata);
        } finally {
          if (mounted) setState(() => _mesgul = false);
        }
      case _Islem.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: widget.tayfaId,
            tur: ReportTargetType.material,
            id: materyal.id,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = materyalProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final materyal = durum.value;
    final hata = durum.error;
    final yazarId = materyal?.authorUserId;
    final benim = yazarId != null && ref.watch(kendisiMiProvider(yazarId));
    final islemler = materyal == null
        ? const <_Islem>[]
        : [
            if (materyal.callerCanEdit && materyal.kind != MaterialKind.unknown)
              _Islem.duzenle,
            if (materyal.callerCanDelete) benim ? _Islem.sil : _Islem.kaldir,
            if (!benim) _Islem.sikayet,
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(m.materyal_detay_baslik),
        actions: [
          if (materyal != null && islemler.isNotEmpty)
            PopupMenuButton<_Islem>(
              tooltip: m.materyal_secenekler,
              icon: const Icon(Icons.more_vert),
              enabled: !_mesgul,
              onSelected: (islem) => unawaited(_islem(islem, materyal)),
              itemBuilder: (_) => [
                for (final islem in islemler)
                  PopupMenuItem(
                    value: islem,
                    child: Text(switch (islem) {
                      _Islem.duzenle => m.materyal_duzenle,
                      _Islem.sil => m.materyal_sil,
                      _Islem.kaldir => m.materyal_kaldir,
                      _Islem.sikayet => m.materyal_sikayet_et,
                    }),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch ((materyal, hata)) {
          (final materyal?, _) => _Icerik(materyal: materyal),
          (null, final hata?) => YuklemeHatasi(
            hata: hata,
            onTekrarDene: () => ref.invalidate(saglayici),
          ),
          (null, null) => Center(
            child: TayfamYukleniyor(etiket: m.materyal_yukleniyor),
          ),
        },
      ),
    );
  }
}

class _Icerik extends ConsumerWidget {
  const _Icerik({required this.materyal});

  final api.Material materyal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final fotograflar = materyal.photoUploadIds ?? const <String>[];
    final alanAdi = materyal.domain;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TayfamSizes.okumaGenisligi),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s12,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                Etiket(
                  metin: materyalTurAdi(m, materyal.kind),
                  ton: EtiketTonu.notr,
                  ikon: materyalTurIkonu(materyal.kind),
                ),
              ],
            ),
            const SizedBox(height: TayfamSpacing.s8),
            DersKonuEtiketleri(
              ders: materyal.subjectKey,
              konu: materyal.topicKey,
            ),
            const SizedBox(height: TayfamSpacing.s12),
            Semantics(
              header: true,
              child: Text(
                materyal.title,
                style: yazi.headlineSmall?.copyWith(color: r.metin),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            YazarSatiri(
              yazarId: materyal.authorUserId,
              zaman: materyal.createdAt,
            ),
            const SizedBox(height: TayfamSpacing.s16),
            if (materyal.kind == MaterialKind.link)
              TayfamKart(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(Icons.public, color: r.metinIkincil),
                        ),
                        const SizedBox(width: TayfamSpacing.s8),
                        Expanded(
                          child: Text(
                            alanAdi ?? m.materyal_tur_baglanti,
                            style: yazi.titleMedium?.copyWith(color: r.metin),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TayfamSpacing.s4),
                    Text(
                      m.materyal_onizleme_yok,
                      style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
                    ),
                    const SizedBox(height: TayfamSpacing.s12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BirincilEylem(
                        etiket: m.materyal_baglantiyi_ac,
                        ikon: Icons.open_in_new,
                        onPressed: () => unawaited(
                          materyalBaglantisiniAc(context, ref, materyal),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (fotograflar.isNotEmpty)
              MateryalFotograflari(kimlikler: fotograflar),
          ],
        ),
      ),
    );
  }
}

/// Onay penceresi: son adım dolu yıkıcı düğmedir (ADR-0004 Notlar).
Future<bool> _yikiciOnay(
  BuildContext context, {
  required String baslik,
  required String metin,
  required String eylem,
}) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final m = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(baslik),
        scrollable: true,
        content: Text(metin),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.materyal_vazgec),
          ),
          YikiciEylem(
            etiket: eylem,
            dolu: true,
            onPressed: () => Navigator.of(pencere).pop(true),
          ),
        ],
      );
    },
  );
  return onay ?? false;
}
