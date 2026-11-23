import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/bilesenler/araclar/araclar_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/garaj/garaj.dart'
    show GarajdanSecim, garajimProvider;
import 'package:tayfam/l10n/app_localizations.dart';

/// Kendi aracını ekleme ve değiştirme formu (alttan sayfa); kaydedilirse
/// istek döner. Plaka alanı yalnızca [plakaAcik], boş koltuk alanı
/// yalnızca [koltukAcik] ise vardır (bileşenin `plate` ve `seats`
/// parametreleri).
///
/// Garajında araç varsa üstte "Garajımdan seç" listesi çıkar (App
/// ADR-0033 §2): seçilince marka, model, yıl ve renk alanları kalkar,
/// sunucu garajdan kopyalar. Plaka garajda yoktur; burada yazılır.
class AracFormu extends ConsumerStatefulWidget {
  const AracFormu({
    super.key,
    this.mevcut,
    required this.plakaAcik,
    required this.koltukAcik,
  });

  /// Değiştirilen araç; yeni araçta `null`.
  final EventVehicle? mevcut;

  final bool plakaAcik;
  final bool koltukAcik;

  @override
  ConsumerState<AracFormu> createState() => _AracFormuState();
}

class _AracFormuState extends ConsumerState<AracFormu> {
  late final TextEditingController _marka = TextEditingController(
    text: widget.mevcut?.make,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.mevcut?.model,
  );
  late final TextEditingController _yil = TextEditingController(
    text: switch (widget.mevcut?.modelYear) {
      final yil? when yil > 0 => '$yil',
      _ => '',
    },
  );
  late final TextEditingController _renk = TextEditingController(
    text: widget.mevcut?.color,
  );
  late final TextEditingController _plaka = TextEditingController(
    text: widget.mevcut?.plate,
  );
  late final TextEditingController _koltuk = TextEditingController(
    text: switch (widget.mevcut?.seats) {
      final sayi? when sayi > 0 => '$sayi',
      _ => '',
    },
  );
  Set<AracHatasi> _hatalar = const {};

  /// Seçilen garaj aracı; elle yazılıyorsa `null`. Garajda artık yoksa
  /// seçim yok sayılır ([_gecerliGarajAraci]).
  late String? _garajAraci = widget.mevcut?.garageVehicleId;

  /// [_garajAraci] kendi garajında hâlâ varsa kimliği.
  String? get _gecerliGarajAraci {
    final secili = _garajAraci;
    if (secili == null) return null;
    final araclar = ref.read(garajimProvider).value?.vehicles ?? const [];
    return araclar.any((a) => a.id == secili) ? secili : null;
  }

  int get _buYil => ref.read(etkinlikSaatiProvider)().toLocal().year;

  @override
  void dispose() {
    _marka.dispose();
    _model.dispose();
    _yil.dispose();
    _renk.dispose();
    _plaka.dispose();
    _koltuk.dispose();
    super.dispose();
  }

  void _kaydet() {
    final sonuc = aracIstegi(
      garajAraci: _gecerliGarajAraci,
      marka: _marka.text,
      model: _model.text,
      yil: _yil.text,
      renk: _renk.text,
      plaka: _plaka.text,
      koltuk: _koltuk.text,
      plakaAcik: widget.plakaAcik,
      koltukAcik: widget.koltukAcik,
      buYil: _buYil,
    );
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() => _hatalar = sonuc.hatalar);
      return;
    }
    Navigator.of(context).pop(istek);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final h = _hatalar;
    // Garaj okununca seçim listesi ve geçerli seçim yeniden çizilir.
    ref.watch(garajimProvider);
    final garajAraci = _gecerliGarajAraci;
    return AracFormSayfasi(
      baslik: widget.mevcut == null
          ? m.bilesen_vehicles_ekle
          : m.bilesen_vehicles_degistir,
      onayEtiketi: widget.mevcut == null ? m.etkinlik_ekle : m.etkinlik_kaydet,
      onOnay: _kaydet,
      alanlar: [
        GarajdanSecim(
          secili: garajAraci,
          onDegisti: (arac) => setState(() {
            _garajAraci = arac?.id;
            _hatalar = const {};
          }),
        ),
        if (garajAraci == null) ...[
          TextField(
            controller: _marka,
            maxLength: aracMarkaEnCok,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: m.etkinlik_arac_marka,
              errorText: h.contains(AracHatasi.marka)
                  ? m.etkinlik_arac_marka_hata
                  : null,
            ),
          ),
          TextField(
            controller: _model,
            maxLength: aracModelEnCok,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: m.etkinlik_arac_model,
              errorText: h.contains(AracHatasi.model)
                  ? m.etkinlik_uzunluk_hata(aracModelEnCok)
                  : null,
            ),
          ),
          TextField(
            controller: _yil,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: m.etkinlik_arac_yil,
              errorText: h.contains(AracHatasi.yil)
                  ? m.etkinlik_arac_yil_hata(_buYil + 1)
                  : null,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          TextField(
            controller: _renk,
            maxLength: aracRenkEnCok,
            decoration: InputDecoration(
              labelText: m.etkinlik_arac_renk,
              errorText: h.contains(AracHatasi.renk)
                  ? m.etkinlik_uzunluk_hata(aracRenkEnCok)
                  : null,
            ),
          ),
        ],
        if (widget.koltukAcik) ...[
          TextField(
            controller: _koltuk,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: m.bilesen_vehicles_koltuk_alani,
              helperText: m.bilesen_vehicles_koltuk_yardim,
              helperMaxLines: 3,
              errorText: h.contains(AracHatasi.koltuk)
                  ? m.bilesen_vehicles_koltuk_hata(koltukEnCok)
                  : null,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
        ],
        if (widget.plakaAcik) ...[
          TextField(
            controller: _plaka,
            maxLength: plakaEnCok,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: m.etkinlik_arac_plaka,
              errorText: h.contains(AracHatasi.plaka)
                  ? m.etkinlik_arac_plaka_hata
                  : null,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          SihirbazBilgiKutusu(
            metin: m.etkinlik_arac_gizlilik_notu,
            ikon: Icons.lock_outline,
          ),
        ],
      ],
    );
  }
}
