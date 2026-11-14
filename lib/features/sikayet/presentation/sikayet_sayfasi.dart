import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/application/moderasyon_kuyrugu.dart';
import 'package:tayfam/features/sikayet/application/sikayet_formu.dart';
import 'package:tayfam/features/sikayet/application/sikayet_hedefi.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Şikâyet et" sayfasını tam ekran açar (ADR-0018 §8; 2026-11-13
/// tasarım: Sikayet-Uye, Sikayet-Mesaj). Gönderilince sayfa kapanır ve
/// kısa bildirim gösterilir.
///
/// Menülere tek satırla bağlanır, ör. duyuru menüsünde:
/// `sikayetSayfasiniAc(context, SikayetHedefi.tayfada(tayfaId: t,
/// tur: ReportTargetType.announcement, id: d))`.
Future<void> sikayetSayfasiniAc(
  BuildContext context,
  SikayetHedefi hedef,
) async {
  final bildirim = ScaffoldMessenger.of(context);
  final metinler = AppLocalizations.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final gonderildi = await navigator.push(
    MaterialPageRoute<bool>(builder: (_) => SikayetSayfasi(hedef: hedef)),
  );
  if (gonderildi ?? false) {
    bildirim
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(metinler.sikayet_iletildi)));
  }
}

/// Birebir mesaj şikâyeti (ADR-0018 §8): yalnızca platforma gider; mesajın
/// metni şikâyet edenin cihazından, kullanıcının gördüğü ve onayladığı
/// haliyle iletilir. Sohbet paketi mesaj menüsünden bunu çağırır.
Future<void> birebirMesajiSikayetEt(
  BuildContext context, {
  required String mesajId,
  required String mesajMetni,
}) => sikayetSayfasiniAc(
  context,
  SikayetHedefi.birebirMesaj(id: mesajId, mesajMetni: mesajMetni),
);

/// Şikâyet sayfası (tasarım: Sikayet-Uye, Sikayet-Mesaj): üstte hedefin
/// kısa önizlemesi (üye: avatar ve ad; içerik: tür ve başlık; tayfa: adı;
/// birebir mesaj: cihazda çözülen metin), hedefe göre soru, gerekçe
/// listesi ("Çocuk ya da genç güvenliği" en üstte, nar açıklamalı),
/// isteğe bağlı not ve gizlilik kutusu. Gerekçe seçilmeden "Şikâyeti
/// gönder" pasiftir.
///
/// Şikâyet edenin kimliği şikâyet edilene ve tayfa yönetimine gösterilmez
/// (sözleşme); sayfa bunu söyler. Tayfa, birebir mesaj ve "Yönetimin
/// yetkiyi kötüye kullanması" yalnızca Tayfam ekibine gider. Birebir
/// mesajın metni yalnızca ekranda ve istek gövdesindedir; saklanmaz,
/// loglanmaz (kesin kural 3).
class SikayetSayfasi extends ConsumerStatefulWidget {
  const SikayetSayfasi({super.key, required this.hedef});

  final SikayetHedefi hedef;

  @override
  ConsumerState<SikayetSayfasi> createState() => _SikayetSayfasiState();
}

class _SikayetSayfasiState extends ConsumerState<SikayetSayfasi> {
  final TextEditingController _not = TextEditingController();
  ReportReason? _gerekce;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final gerekce = _gerekce;
    if (gerekce == null) return;
    final tamam = await ref
        .read(sikayetFormuProvider(widget.hedef).notifier)
        .gonder(gerekce, _not.text);
    if (tamam && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final hedef = widget.hedef;
    final durum = ref.watch(sikayetFormuProvider(hedef));
    final mesgul = durum.gonderiliyor;
    final mesaj = switch (hedef.mesajMetni) {
      null => null,
      final metin => kanitMetni(metin),
    };
    final platform =
        hedef.yalnizcaPlatform || _gerekce == ReportReason.staffConduct;
    final gonderilebilir =
        !mesgul &&
        _gerekce != null &&
        (hedef.mesajMetni == null || mesaj != null);
    return Scaffold(
      appBar: AppBar(title: Text(m.sikayet_baslik)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s4,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hedef.mesajMetni == null)
              _HedefOnizlemesi(hedef: hedef)
            else if (mesaj != null)
              _MesajOnizlemesi(metin: mesaj)
            else
              HataSatiri(metin: m.sikayet_mesaj_bos),
            const SizedBox(height: TayfamSpacing.s20),
            Semantics(
              header: true,
              child: Text(
                sikayetSorusu(m, hedef.tur),
                style: yazi.headlineSmall,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Semantics(
              container: true,
              label: m.sikayet_gerekce_baslik,
              child: RadioGroup<ReportReason>(
                groupValue: _gerekce,
                onChanged: (secim) {
                  if (secim != null && !mesgul) {
                    setState(() => _gerekce = secim);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final gerekce in hedef.gerekceler)
                      _GerekceSatiri(
                        gerekce: gerekce,
                        secili: gerekce == _gerekce,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s20),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(m.sikayet_not_etiketi, style: yazi.titleSmall),
                  const SizedBox(height: TayfamSpacing.s8),
                  TextField(
                    controller: _not,
                    enabled: !mesgul,
                    maxLength: sikayetNotuEnCok,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: m.sikayet_not_ipucu,
                      hintMaxLines: 3,
                      helperText: m.sikayet_not_kisisel,
                      helperMaxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            _GizlilikKutusu(
              metin: platform
                  ? m.sikayet_gizlilik_platform
                  : m.sikayet_gizlilik,
            ),
            if (durum.hata case final hata?) ...[
              const SizedBox(height: TayfamSpacing.s12),
              HataSatiri.hatadan(hata),
            ],
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: r.zemin,
          border: Border(
            top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
              vertical: TayfamSpacing.s12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: YikiciEylem(
                etiket: m.sikayet_gonder,
                dolu: true,
                onPressed: gonderilebilir ? () => unawaited(_gonder()) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gerekçe satırı: radyo ve metin, altında ince çizgi. "Çocuk ya da genç
/// güvenliği"nin açıklaması nar renktedir (öncelikli inceleme).
class _GerekceSatiri extends StatelessWidget {
  const _GerekceSatiri({required this.gerekce, required this.secili});

  final ReportReason gerekce;
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final aciklama = gerekceAciklamasi(m, gerekce);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: RadioListTile<ReportReason>(
        value: gerekce,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s4,
        ),
        title: Text(
          gerekceMetni(m, gerekce),
          style: yazi.bodyLarge?.copyWith(
            fontWeight: secili ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        subtitle: aciklama == null
            ? null
            : Text(
                aciklama,
                style: yazi.bodySmall?.copyWith(
                  color: gerekce == ReportReason.childSafety
                      ? r.narMetin
                      : r.metinGovde,
                ),
              ),
      ),
    );
  }
}

/// Önizleme kutusu: tint-brand zemin, 16 px köşe.
class _OnizlemeKutusu extends StatelessWidget {
  const _OnizlemeKutusu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.renkler.tintMarka,
        borderRadius: TayfamRadii.secimKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: child,
      ),
    );
  }
}

/// Şikâyet edilen şeyin önizlemesi: üye (avatar ve ad), tayfa (adı) ya da
/// içerik (türü ve başlığı; başlığı olmayan türde yalnızca türü). İçerik
/// başlığı kuyruktaki önizlemeyle aynı yoldan, yalnızca bellekte okunur.
class _HedefOnizlemesi extends ConsumerWidget {
  const _HedefOnizlemesi({required this.hedef});

  final SikayetHedefi hedef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final tur = hedef.tur;
    final tayfaId = hedef.tayfaId;
    final etiket = Text(
      hedefTuruMetni(m, tur),
      style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
    );
    final adStili = yazi.titleMedium;
    if (tur == ReportTargetType.user) {
      return _OnizlemeKutusu(
        child: Row(
          children: [
            KimlikAvatari(kullaniciId: hedef.id),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etiket,
                  KullaniciAdiMetni(kullaniciId: hedef.id, style: adStili),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final String? baslik;
    if (tur == ReportTargetType.tayfa && tayfaId != null) {
      baslik =
          ref.watch(tayfaOzetiProvider(tayfaId)).ad ?? m.tayfa_adi_bilinmiyor;
    } else if (tayfaId != null &&
        onizlenebilirTurler.contains(tur) &&
        uuidBicimindeMi(tayfaId) &&
        uuidBicimindeMi(hedef.id)) {
      final HedefAnahtari anahtar = (tayfaId: tayfaId, tur: tur, id: hedef.id);
      baslik = ref.watch(hedefOnizlemesiProvider(anahtar)).value?.baslik;
    } else {
      baslik = null;
    }
    return _OnizlemeKutusu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          etiket,
          if (baslik != null) Text(baslik, style: adStili),
        ],
      ),
    );
  }
}

/// Birebir mesaj şikâyetinde iletilecek metin (tasarım: Sikayet-Mesaj):
/// kullanıcı ne paylaştığını görür. Metin yalnızca bu ekranda ve istek
/// gövdesindedir; saklanmaz, loglanmaz.
class _MesajOnizlemesi extends StatelessWidget {
  const _MesajOnizlemesi({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    return _OnizlemeKutusu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.sikayet_mesaj_iletilecek,
            style: yazi.labelMedium?.copyWith(color: r.metinIkincil),
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(metin, style: yazi.bodyLarge?.copyWith(color: r.metin)),
        ],
      ),
    );
  }
}

/// Gizlilik kutusu: kalkan ikonu ve kimin göreceği (tayfa yönetimi ya da
/// yalnızca Tayfam ekibi).
class _GizlilikKutusu extends StatelessWidget {
  const _GizlilikKutusu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.onizlemeKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.verified_user_outlined,
                size: TayfamSizes.ikon,
                color: r.tintMarkaUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Text(
                metin,
                style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
