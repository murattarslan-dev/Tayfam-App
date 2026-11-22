import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir ödüncün durumu ve sıradaki adımı (Tayfam-Api ADR-0040 §1):
/// istek → sahibi onaylar → "Teslim ettim" → "İade aldım".
///
/// Ödünç yalnızca iki tarafına döner; bu bileşen de yalnızca onlara
/// çizilir. Sahibi onaylar, reddeder, teslim eder ve iadeyi işaretler;
/// borç alan teslimden önce isteğini geri alabilir. Durum geçişini istemci
/// kurmaz: her adımdan sonra sunucunun döndürdüğü durum çizilir (App
/// ADR-0033 §4). Sahibi teslim ederken isteğe bağlı iade tarihi seçer;
/// para, depozito, ceza yoktur.
class OduncAdimlari extends ConsumerStatefulWidget {
  const OduncAdimlari({
    super.key,
    required this.tayfaId,
    required this.odunc,
    this.kalemAdi = false,
  });

  final String tayfaId;
  final LibraryLoan odunc;

  /// "Ödünçlerim"de kalemin adı ve türü de yazılır.
  final bool kalemAdi;

  @override
  ConsumerState<OduncAdimlari> createState() => _OduncAdimlariState();
}

class _OduncAdimlariState extends ConsumerState<OduncAdimlari> {
  bool _mesgul = false;

  KutuphaneIslemleri get _islemler => ref.read(kutuphaneIslemleriProvider);

  Future<void> _calistir(Future<void> Function() is_, String basari) async {
    setState(() => _mesgul = true);
    try {
      await is_();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(basari)));
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _onayla() {
    final m = AppLocalizations.of(context);
    return _calistir(
      () => _islemler.onayla(widget.tayfaId, widget.odunc.id),
      m.kutuphane_onaylandi_bildirimi,
    );
  }

  Future<void> _reddet() async {
    final m = AppLocalizations.of(context);
    final onay = await yikiciOnay(
      context,
      baslik: m.kutuphane_reddet_baslik,
      metin: m.kutuphane_reddet_metni,
      eylem: m.kutuphane_reddet,
    );
    if (!onay || !mounted) return;
    await _calistir(
      () => _islemler.reddet(widget.tayfaId, widget.odunc.id),
      m.kutuphane_reddedildi_bildirimi,
    );
  }

  Future<void> _teslimEt() async {
    final m = AppLocalizations.of(context);
    final secim = await showDialog<_TeslimSecimi>(
      context: context,
      builder: (_) => _TeslimPenceresi(simdi: ref.read(simdiProvider)()),
    );
    if (secim == null || !mounted) return;
    await _calistir(
      () => _islemler.teslimEt(
        widget.tayfaId,
        widget.odunc.id,
        iadeTarihi: secim.iadeTarihi,
      ),
      m.kutuphane_teslim_bildirimi,
    );
  }

  Future<void> _iadeAl() {
    final m = AppLocalizations.of(context);
    return _calistir(
      () => _islemler.iadeAl(widget.tayfaId, widget.odunc.id),
      m.kutuphane_iade_bildirimi,
    );
  }

  Future<void> _geriAl() {
    final m = AppLocalizations.of(context);
    return _calistir(
      () => _islemler.istegiGeriAl(widget.tayfaId, widget.odunc.itemId),
      m.kutuphane_istek_geri_alindi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final odunc = widget.odunc;
    final sahip = odunc.callerIsOwner;
    final karsi = sahip ? odunc.borrowerUserId : odunc.ownerUserId;
    final simdi = ref.watch(simdiProvider)();
    final iade = odunc.dueAt;
    final gecikti =
        iade != null &&
        odunc.state == LibraryLoanState.handedOver &&
        iade.isBefore(simdi);
    final ikincil = yazi.bodyMedium?.copyWith(color: r.metinGovde);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.kalemAdi) ...[
          Text(
            odunc.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: yazi.titleMedium?.copyWith(color: r.metin),
          ),
          const SizedBox(height: TayfamSpacing.s8),
        ],
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            if (widget.kalemAdi) TurEtiketi(tur: odunc.itemKind),
            Etiket(
              metin: oduncDurumu(m, odunc.state),
              ton: oduncTonu(odunc.state),
            ),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s8),
        MergeSemantics(
          child: Wrap(
            spacing: TayfamSpacing.s4,
            children: [
              Text(
                sahip ? m.kutuphane_odunc_alan : m.kutuphane_sahibi,
                style: ikincil,
              ),
              if (karsi == null)
                Text(m.kullanici_silinmis, style: ikincil)
              else
                KullaniciAdiMetni(
                  kullaniciId: karsi,
                  maxLines: 1,
                  style: yazi.bodyMedium?.copyWith(
                    color: r.metin,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s4),
        Text(_adimMetni(m, odunc), style: ikincil),
        if (iade != null && oduncSuruyor(odunc.state)) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            gecikti
                ? m.kutuphane_iade_gecti(tarihMetni(m, iade))
                : m.kutuphane_iade_tarihi(tarihMetni(m, iade)),
            style: yazi.bodyMedium?.copyWith(
              color: gecikti ? r.narMetin : r.metinGovde,
              fontWeight: gecikti ? FontWeight.w600 : null,
            ),
          ),
        ],
        if (odunc.orphanedAt != null && oduncSuruyor(odunc.state)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.warning_amber_outlined, color: r.narMetin),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: Text(
                  m.kutuphane_odunc_sahipsiz,
                  style: yazi.bodyMedium?.copyWith(color: r.metin),
                ),
              ),
            ],
          ),
        ],
        ..._eylemler(m, odunc),
      ],
    );
  }

  String _adimMetni(AppLocalizations m, LibraryLoan odunc) =>
      switch ((odunc.state, odunc.callerIsOwner)) {
        (LibraryLoanState.requested, true) => m.kutuphane_adim_istek_sahip,
        (LibraryLoanState.requested, false) => m.kutuphane_adim_istek_alan,
        (LibraryLoanState.approved, true) => m.kutuphane_adim_onay_sahip,
        (LibraryLoanState.approved, false) => m.kutuphane_adim_onay_alan,
        (LibraryLoanState.handedOver, true) => m.kutuphane_adim_teslim_sahip,
        (LibraryLoanState.handedOver, false) => m.kutuphane_adim_teslim_alan,
        _ => m.kutuphane_adim_bitti,
      };

  List<Widget> _eylemler(AppLocalizations m, LibraryLoan odunc) {
    if (_mesgul) {
      return [
        const SizedBox(height: TayfamSpacing.s12),
        Center(child: TayfamYukleniyor(etiket: m.kutuphane_isleniyor)),
      ];
    }
    final dugmeler = <Widget>[
      if (odunc.callerIsOwner)
        ...switch (odunc.state) {
          LibraryLoanState.requested => [
            IkincilEylem(
              etiket: m.kutuphane_reddet,
              onPressed: () => unawaited(_reddet()),
            ),
            BirincilEylem(
              etiket: m.kutuphane_onayla,
              ikon: Icons.check,
              onPressed: () => unawaited(_onayla()),
            ),
          ],
          LibraryLoanState.approved => [
            IkincilEylem(
              etiket: m.kutuphane_reddet,
              onPressed: () => unawaited(_reddet()),
            ),
            BirincilEylem(
              etiket: m.kutuphane_teslim_ettim,
              ikon: Icons.outbox_outlined,
              onPressed: () => unawaited(_teslimEt()),
            ),
          ],
          LibraryLoanState.handedOver => [
            BirincilEylem(
              etiket: m.kutuphane_iade_aldim,
              ikon: Icons.move_to_inbox_outlined,
              onPressed: () => unawaited(_iadeAl()),
            ),
          ],
          _ => const <Widget>[],
        }
      else if (odunc.state == LibraryLoanState.requested ||
          odunc.state == LibraryLoanState.approved)
        IkincilEylem(
          etiket: m.kutuphane_istegi_geri_al,
          onPressed: () => unawaited(_geriAl()),
        ),
    ];
    if (dugmeler.isEmpty) return const [];
    return [
      const SizedBox(height: TayfamSpacing.s12),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: dugmeler,
      ),
    ];
  }
}

/// Teslim penceresinin sonucu: isteğe bağlı iade tarihi.
typedef _TeslimSecimi = ({DateTime? iadeTarihi});

/// "Teslim ettim" onayı ve isteğe bağlı iade tarihi. Tarih yarından en çok
/// [iadeEnCokGun] gün sonrasına kadar seçilir; günün sonu gönderilir.
class _TeslimPenceresi extends StatefulWidget {
  const _TeslimPenceresi({required this.simdi});

  final DateTime simdi;

  @override
  State<_TeslimPenceresi> createState() => _TeslimPenceresiState();
}

class _TeslimPenceresiState extends State<_TeslimPenceresi> {
  DateTime? _gun;

  DateTime get _bugun =>
      DateTime(widget.simdi.year, widget.simdi.month, widget.simdi.day);

  Future<void> _sec() async {
    final ilk = _bugun.add(const Duration(days: 1));
    final secilen = await showDatePicker(
      context: context,
      initialDate: _gun ?? _bugun.add(const Duration(days: 14)),
      firstDate: ilk,
      lastDate: _bugun.add(const Duration(days: iadeEnCokGun)),
    );
    if (secilen == null || !mounted) return;
    setState(() => _gun = secilen);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final gun = _gun;
    final dugme = TextButton.styleFrom(
      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
    );
    return AlertDialog(
      title: Text(m.kutuphane_teslim_baslik),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(m.kutuphane_teslim_metni),
          const SizedBox(height: TayfamSpacing.s12),
          Text(
            gun == null
                ? m.kutuphane_iade_tarihi_yok
                : m.kutuphane_iade_tarihi(tarihMetni(m, gun)),
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metin,
              fontWeight: FontWeight.w600,
            ),
          ),
          Wrap(
            spacing: TayfamSpacing.s4,
            children: [
              TextButton.icon(
                onPressed: () => unawaited(_sec()),
                style: dugme,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  gun == null
                      ? m.kutuphane_iade_tarihi_sec
                      : m.kutuphane_iade_tarihi_degistir,
                ),
              ),
              if (gun != null)
                TextButton(
                  onPressed: () => setState(() => _gun = null),
                  style: dugme,
                  child: Text(m.kutuphane_iade_tarihi_kaldir),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: dugme,
          child: Text(m.kutuphane_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop<_TeslimSecimi>((
            iadeTarihi: gun == null
                ? null
                : DateTime(gun.year, gun.month, gun.day, 23, 59),
          )),
          style: dugme,
          child: Text(m.kutuphane_teslim_ettim),
        ),
      ],
    );
  }
}
