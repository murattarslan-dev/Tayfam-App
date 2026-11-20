import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/gunun_icerigi/application/gunun_icerigi.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ekleme ya da düzenleme formunu tam ekran açar. Kaydedilirse sunucunun
/// cevabı (`pin_conflict` dahil), vazgeçilirse `null` döner.
Future<DailyItemSaved?> icerikFormunuAc(
  BuildContext context,
  String tayfaId, {
  DailyItem? mevcut,
}) => Navigator.of(context).push<DailyItemSaved>(
  MaterialPageRoute<DailyItemSaved>(
    fullscreenDialog: true,
    builder: (_) => IcerikFormu(tayfaId: tayfaId, mevcut: mevcut),
  ),
);

/// Metni sözleşmenin biçimine getirir: satır sonu `\n`, art arda en çok
/// bir boş satır, baştaki ve sondaki boşluk yok.
String metniTemizle(String metin) => metin
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Söyleyeni tek satıra indirir; boşsa `null`.
String? soyleyeniTemizle(String metin) {
  final temiz = metin.replaceAll(RegExp(r'\s+'), ' ').trim();
  return temiz.isEmpty ? null : temiz;
}

/// [gun]'ün ayını ve gününü [yil] yılına taşır; 29 Şubat [yil]'dan
/// itibaren ilk artık yıla gider.
DateTime _yilaTasi(DateTime gun, int yil) {
  if (gun.month == 2 && gun.day == 29) {
    var y = yil;
    while (!_artikMi(y)) {
      y++;
    }
    return DateTime(y, 2, 29);
  }
  return DateTime(yil, gun.month, gun.day);
}

bool _artikMi(int yil) => yil % 4 == 0 && (yil % 100 != 0 || yil % 400 == 0);

/// Metnin karakter sayısı (sunucu Unicode kod noktası sayar).
int karakterSayisi(String metin) => metin.runes.length;

/// Günün içeriği formu: metin (çok satırlı), söyleyen ve isteğe bağlı
/// tarihe sabitleme ("Her yıl tekrarla"). Sunucu reddederse hata formda
/// kısa bildirimle gösterilir, girilenler kaybolmaz. Yeni içerikte
/// `client_request_id` form açıkken sabittir (tekrar gönderim koruması).
class IcerikFormu extends ConsumerStatefulWidget {
  const IcerikFormu({super.key, required this.tayfaId, this.mevcut});

  final String tayfaId;

  /// Düzenlenen içerik; `null` ise yeni içerik.
  final DailyItem? mevcut;

  @override
  ConsumerState<IcerikFormu> createState() => _IcerikFormuState();
}

class _IcerikFormuState extends ConsumerState<IcerikFormu> {
  late final TextEditingController _metin = TextEditingController(
    text: widget.mevcut?.body ?? '',
  );
  late final TextEditingController _soyleyen = TextEditingController(
    text: widget.mevcut?.attribution ?? '',
  );
  late final String _istekKimligi = ref.read(istekKimligiUreticisiProvider)();

  /// Seçilen gün; `null` ise sabitleme yok.
  late DateTime? _gun = switch (widget.mevcut?.pin) {
    final p? => DateTime(p.year ?? _artikYil, p.month, p.day),
    null => null,
  };
  late bool _herYil = widget.mevcut?.pin?.year == null;
  bool _metinDokunuldu = false;
  bool _kaydediliyor = false;

  /// Yılsız sabitlemede 29 Şubat da seçilebilsin diye artık bir yıl.
  static const int _artikYil = 2000;

  @override
  void dispose() {
    _metin.dispose();
    _soyleyen.dispose();
    super.dispose();
  }

  String? _metinHatasi(AppLocalizations m) {
    final temiz = metniTemizle(_metin.text);
    if (temiz.isEmpty) return m.gunun_icerigi_metin_bos;
    if (karakterSayisi(temiz) > metinEnCok) {
      return m.gunun_icerigi_metin_uzun(metinEnCok);
    }
    return null;
  }

  DailyPin? get _sabit => switch (_gun) {
    final g? => DailyPin(
      month: g.month,
      day: g.day,
      year: _herYil ? null : g.year,
    ),
    null => null,
  };

  Future<void> _gunSec() async {
    final bugun = ref.read(simdiProvider)();
    final gun = _gun;
    final ilk = switch (gun) {
      null => DateTime(bugun.year, bugun.month, bugun.day),
      final g when _herYil => _yilaTasi(g, bugun.year),
      final g => g,
    };
    final secilen = await showDatePicker(
      context: context,
      initialDate: ilk.year < sabitYilEnAz || ilk.year > sabitYilEnCok
          ? DateTime(bugun.year, bugun.month, bugun.day)
          : ilk,
      firstDate: DateTime(sabitYilEnAz),
      lastDate: DateTime(sabitYilEnCok, 12, 31),
    );
    if (secilen == null || !mounted) return;
    setState(() => _gun = secilen);
  }

  /// "Her yıl" kapanınca yılsız günün yılı bu yıla (29 Şubat'ta sıradaki
  /// artık yıla) taşınır.
  void _herYiliDegistir(bool yeni) {
    final gun = _gun;
    setState(() {
      if (!yeni && _herYil && gun != null) {
        _gun = _yilaTasi(gun, ref.read(simdiProvider)().year);
      }
      _herYil = yeni;
    });
  }

  Future<void> _kaydet() async {
    final m = AppLocalizations.of(context);
    setState(() => _metinDokunuldu = true);
    if (_metinHatasi(m) != null) return;
    final girdi = (
      metin: metniTemizle(_metin.text),
      soyleyen: soyleyeniTemizle(_soyleyen.text),
      sabit: _sabit,
    );
    setState(() => _kaydediliyor = true);
    final havuz = ref.read(havuzProvider(widget.tayfaId).notifier);
    try {
      final mevcut = widget.mevcut;
      final kayit = mevcut == null
          ? await havuz.ekle(girdi, _istekKimligi)
          : await havuz.duzenle(mevcut.id, girdi);
      if (mounted) Navigator.of(context).pop(kayit);
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final gun = _gun;
    final hata = _metinDokunuldu ? _metinHatasi(m) : null;
    final yalnizcaArtikYil =
        gun != null && _herYil && gun.month == 2 && gun.day == 29;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mevcut == null
              ? m.gunun_icerigi_form_yeni
              : m.gunun_icerigi_form_duzenle,
        ),
        actions: [
          if (_kaydediliyor)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.s16,
              ),
              child: TayfamYukleniyor(etiket: m.gunun_icerigi_kaydediliyor),
            )
          else
            TextButton(
              onPressed: () => unawaited(_kaydet()),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.gunun_icerigi_kaydet),
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
            TextField(
              controller: _metin,
              enabled: !_kaydediliyor,
              minLines: 3,
              maxLines: 10,
              maxLength: metinEnCok,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: m.gunun_icerigi_metin_alani,
                helperText: m.gunun_icerigi_metin_ipucu,
                helperMaxLines: 3,
                errorText: hata,
                errorMaxLines: 3,
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() => _metinDokunuldu = true),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            TextField(
              controller: _soyleyen,
              enabled: !_kaydediliyor,
              maxLength: soyleyenEnCok,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: m.gunun_icerigi_soyleyen_alani,
                helperText: m.gunun_icerigi_soyleyen_ipucu,
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s24),
            BolumEtiketi(baslik: m.gunun_icerigi_sabitle_baslik),
            Text(
              m.gunun_icerigi_sabitle_aciklama,
              style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            if (gun == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _kaydediliyor ? null : () => unawaited(_gunSec()),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(m.gunun_icerigi_gun_sec),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SabitlemeEtiketi(sabit: _sabit!),
                    ),
                  ),
                  TextButton(
                    onPressed: _kaydediliyor
                        ? null
                        : () => unawaited(_gunSec()),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.gunun_icerigi_gun_degistir),
                  ),
                  IconButton(
                    onPressed: _kaydediliyor
                        ? null
                        : () => setState(() => _gun = null),
                    tooltip: m.gunun_icerigi_sabitleme_kaldir,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.gunun_icerigi_her_yil_tekrarla),
                subtitle: yalnizcaArtikYil
                    ? Text(m.gunun_icerigi_artik_yil_notu)
                    : null,
                value: _herYil,
                onChanged: _kaydediliyor ? null : _herYiliDegistir,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
