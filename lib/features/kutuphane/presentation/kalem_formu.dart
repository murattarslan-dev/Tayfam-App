import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/data/kutuphane_deposu.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ekleme ya da düzenleme formunu tam ekran açar. Kaydedilirse sunucunun
/// döndürdüğü kalem, vazgeçilirse `null` döner.
Future<LibraryItem?> kalemFormunuAc(
  BuildContext context,
  String tayfaId, {
  LibraryItem? mevcut,
}) => Navigator.of(context).push<LibraryItem>(
  MaterialPageRoute<LibraryItem>(
    fullscreenDialog: true,
    builder: (_) => KalemFormu(tayfaId: tayfaId, mevcut: mevcut),
  ),
);

/// Adı sözleşmenin biçimine getirir: tek satır, boşluklar teke iner.
String adiTemizle(String ad) => ad.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Notu sözleşmenin biçimine getirir: satır sonu `\n`, art arda en çok
/// bir boş satır; boşsa `null`.
String? notuTemizle(String not) {
  final temiz = not
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return temiz.isEmpty ? null : temiz;
}

/// Metnin karakter sayısı (sunucu Unicode kod noktası sayar).
int karakterSayisi(String metin) => metin.runes.length;

/// [tur]'de adın en çok uzunluğu (kitapta tayfa sözlüğünün sınırı).
int adSiniri(LibraryItemKind tur) =>
    tur == LibraryItemKind.book ? kitapAdiEnCok : adEnCok;

/// Kalem formu: tür (yalnızca eklerken; sonra değişmez), ad, not ve
/// isteğe bağlı fotoğraf. Kitap adı tayfa sözlüğüne bağlıdır
/// ([SozlukGirisi]; tayfanın önceki kitaplarından öneri), diğer türlerde
/// serbest metin. Sunucu reddederse hata kısa bildirimle gösterilir,
/// girilenler kaybolmaz. Yeni kalemde `client_request_id` form açıkken
/// sabittir (tekrar gönderim koruması).
class KalemFormu extends ConsumerStatefulWidget {
  const KalemFormu({super.key, required this.tayfaId, this.mevcut});

  final String tayfaId;

  /// Düzenlenen kalem; `null` ise yeni kalem.
  final LibraryItem? mevcut;

  @override
  ConsumerState<KalemFormu> createState() => _KalemFormuState();
}

class _KalemFormuState extends ConsumerState<KalemFormu> {
  late final TextEditingController _ad = TextEditingController(
    text: widget.mevcut?.name ?? '',
  );
  late final TextEditingController _not = TextEditingController(
    text: widget.mevcut?.note ?? '',
  );
  late final String _istekKimligi = ref.read(istekKimligiUreticisiProvider)();
  late LibraryItemKind _tur = switch (widget.mevcut?.kind) {
    null || LibraryItemKind.unknown => LibraryItemKind.book,
    final LibraryItemKind t => t,
  };
  late String? _fotograf = widget.mevcut?.photoUploadId;
  String? _kitapKimligi;
  bool _dokunuldu = false;
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _ad.dispose();
    _not.dispose();
    super.dispose();
  }

  String? _adHatasi(AppLocalizations m) {
    final ad = adiTemizle(_ad.text);
    if (ad.isEmpty) return m.kutuphane_ad_bos;
    final sinir = adSiniri(_tur);
    if (karakterSayisi(ad) > sinir) return m.kutuphane_ad_uzun(sinir);
    return null;
  }

  String? _notHatasi(AppLocalizations m) {
    final not = notuTemizle(_not.text);
    if (not != null && karakterSayisi(not) > notEnCok) {
      return m.kutuphane_not_uzun(notEnCok);
    }
    return null;
  }

  Future<void> _kaydet() async {
    final m = AppLocalizations.of(context);
    setState(() => _dokunuldu = true);
    if (_adHatasi(m) != null || _notHatasi(m) != null) return;
    final girdi = (
      ad: adiTemizle(_ad.text),
      not: notuTemizle(_not.text),
      fotograf: _fotograf,
    );
    setState(() => _kaydediliyor = true);
    final islemler = ref.read(kutuphaneIslemleriProvider);
    try {
      final mevcut = widget.mevcut;
      final kalem = mevcut == null
          ? await islemler.ekle(widget.tayfaId, _tur, girdi, _istekKimligi)
          : await islemler.duzenle(widget.tayfaId, mevcut.id, girdi);
      if (mounted) Navigator.of(context).pop(kalem);
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Widget _adAlani(AppLocalizations m, String? hata) {
    final sinir = adSiniri(_tur);
    if (_tur == LibraryItemKind.book) {
      final depo = ref.read(kutuphaneDeposuProvider);
      return SozlukGirisi(
        etiket: m.kutuphane_kitap_adi_alani,
        metin: _ad.text,
        kimlik: _kitapKimligi,
        enCokUzunluk: sinir,
        hataMetni: hata,
        ara: (arama) => depo.kitapOnerileri(widget.tayfaId, arama),
        onDegisti: _kaydediliyor
            ? null
            : (metin, kimlik) => setState(() {
                _ad.text = metin;
                _kitapKimligi = kimlik;
                _dokunuldu = true;
              }),
      );
    }
    return TextField(
      controller: _ad,
      enabled: !_kaydediliyor,
      maxLength: sinir,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: m.kutuphane_ad_alani,
        errorText: hata,
        errorMaxLines: 3,
      ),
      onChanged: (_) => setState(() => _dokunuldu = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final yeni = widget.mevcut == null;
    final adHatasi = _dokunuldu ? _adHatasi(m) : null;
    final notHatasi = _notHatasi(m);
    return Scaffold(
      appBar: AppBar(
        title: Text(yeni ? m.kutuphane_form_yeni : m.kutuphane_form_duzenle),
        actions: [
          if (_kaydediliyor)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s16,
              ),
              child: TayfamYukleniyor(etiket: m.kutuphane_kaydediliyor),
            )
          else
            TextButton(
              onPressed: () => unawaited(_kaydet()),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.kutuphane_kaydet),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s12,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            BolumEtiketi(baslik: m.kutuphane_tur_alani),
            if (yeni)
              Wrap(
                spacing: TayfamSpacing.s8,
                runSpacing: TayfamSpacing.s8,
                children: [
                  for (final tur in secilebilirTurler)
                    ChoiceChip(
                      avatar: Icon(turIkonu(tur)),
                      label: Text(turAdi(m, tur)),
                      selected: tur == _tur,
                      onSelected: _kaydediliyor
                          ? null
                          : (_) => setState(() => _tur = tur),
                    ),
                ],
              )
            else ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TurEtiketi(tur: _tur),
              ),
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                m.kutuphane_tur_degismez,
                style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            KeyedSubtree(
              key: ValueKey(_tur == LibraryItemKind.book),
              child: _adAlani(m, adHatasi),
            ),
            if (_tur == LibraryItemKind.book) ...[
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                m.kutuphane_kitap_adi_ipucu,
                style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            TextField(
              controller: _not,
              enabled: !_kaydediliyor,
              minLines: 2,
              maxLines: 6,
              maxLength: notEnCok,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: m.kutuphane_not_alani,
                helperText: m.kutuphane_not_ipucu,
                helperMaxLines: 3,
                errorText: notHatasi,
                errorMaxLines: 3,
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            BolumEtiketi(baslik: m.kutuphane_fotograf_alani),
            FotografAlani(
              amac: UploadPurpose.libraryItem,
              tayfaId: widget.tayfaId,
              deger: _fotograf,
              etiket: m.kutuphane_fotograf_alani,
              bicim: FotografAlaniBicimi.kare,
              etkin: !_kaydediliyor,
              onDegisti: (yeni) => setState(() => _fotograf = yeni),
            ),
          ],
        ),
      ),
    );
  }
}
