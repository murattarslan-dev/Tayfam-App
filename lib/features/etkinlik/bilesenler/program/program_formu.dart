import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/program/program_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bitiş seçilirken önerilen süre (başlangıçtan sonra).
const Duration _onerilenSure = Duration(hours: 1);

/// Program maddesi formu: başlık (120), başlangıç, isteğe bağlı bitiş ve
/// not (500). [madde] verilirse düzenlemedir; değerleri ondan dolar.
/// Saatler cihazın saatinde seçilir ve gösterilir, sunucuya UTC gider;
/// tarih seçici etkinliğin başlangıcından bir gün önce ile bitişinden bir
/// gün sonrası arasındaki günleri sunar. Sunucu reddederse (`event-limit`,
/// `invalid-request` …) form açık kalır ve hatayı gösterir.
class ProgramFormu extends StatefulWidget {
  const ProgramFormu({
    super.key,
    required this.etkinlik,
    required this.baslangic,
    required this.gonder,
    this.madde,
  });

  final Event etkinlik;

  /// Yeni maddenin önerilen başlangıcı (düzenlemede kullanılmaz).
  final DateTime baslangic;

  /// Düzenlenen madde; yeni maddede `null`.
  final EventScheduleItem? madde;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventScheduleItemRequest istek) gonder;

  @override
  State<ProgramFormu> createState() => _ProgramFormuState();
}

class _ProgramFormuState extends State<ProgramFormu> {
  late final TextEditingController _baslik = TextEditingController(
    text: widget.madde?.title ?? '',
  );
  late final TextEditingController _not = TextEditingController(
    text: widget.madde?.note ?? '',
  );
  late DateTime _baslangic = widget.madde?.startsAt ?? widget.baslangic;
  late DateTime? _bitis = widget.madde?.endsAt;
  Set<ProgramHatasi> _hatalar = const {};
  bool _mesgul = false;
  Object? _hata;

  @override
  void dispose() {
    _baslik.dispose();
    _not.dispose();
    super.dispose();
  }

  /// Gün ve saat seçtirir (cihazın saatinde); seçilmezse `null`.
  Future<DateTime?> _anSec(DateTime ilk) async {
    final etkinlik = widget.etkinlik;
    final enErken = programEnErken(etkinlik).toLocal();
    final enGec = programEnGec(etkinlik).toLocal();
    final ilkGun = DateTime(enErken.year, enErken.month, enErken.day);
    final sonGun = DateTime(enGec.year, enGec.month, enGec.day);
    final yerel = ilk.toLocal();
    final secilen = DateTime(yerel.year, yerel.month, yerel.day);
    final gun = await showDatePicker(
      context: context,
      initialDate: secilen.isBefore(ilkGun)
          ? ilkGun
          : secilen.isAfter(sonGun)
          ? sonGun
          : secilen,
      firstDate: ilkGun,
      lastDate: sonGun,
    );
    if (gun == null || !mounted) return null;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: yerel.hour, minute: yerel.minute),
    );
    if (saat == null) return null;
    return DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
  }

  Future<void> _baslangicSec() async {
    final an = await _anSec(_baslangic);
    if (an == null || !mounted) return;
    setState(() {
      _baslangic = an;
      _hatalar = _hatalar.difference({ProgramHatasi.baslangic});
    });
  }

  Future<void> _bitisSec() async {
    final an = await _anSec(_bitis ?? _baslangic.add(_onerilenSure));
    if (an == null || !mounted) return;
    setState(() {
      _bitis = an;
      _hatalar = _hatalar.difference({ProgramHatasi.bitis});
    });
  }

  Future<void> _gonder() async {
    if (_mesgul) return;
    final sonuc = programIstegi(
      etkinlik: widget.etkinlik,
      baslik: _baslik.text,
      baslangic: _baslangic,
      bitis: _bitis,
      not: _not.text,
    );
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() => _hatalar = sonuc.hatalar);
      return;
    }
    setState(() {
      _hatalar = const {};
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(istek);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _mesgul = false;
        _hata = hata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = _hata;
    final bitis = _bitis;
    final duzenleme = widget.madde != null;
    return AracFormSayfasi(
      baslik: duzenleme ? m.bilesen_schedule_duzenle : m.bilesen_schedule_ekle,
      onayEtiketi: duzenleme ? m.etkinlik_kaydet : m.etkinlik_ekle,
      onOnay: _mesgul ? null : () => unawaited(_gonder()),
      alanlar: [
        TextField(
          controller: _baslik,
          autofocus: !duzenleme,
          maxLength: programBasligiEnCok,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.bilesen_schedule_baslik_alani,
            errorText: _hatalar.contains(ProgramHatasi.baslik)
                ? m.bilesen_schedule_baslik_hata(programBasligiEnCok)
                : null,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        ProgramAnAlani(
          etiket: m.bilesen_schedule_baslangic,
          deger: etkinlikTarihSaat(m, _baslangic),
          hata: _hatalar.contains(ProgramHatasi.baslangic)
              ? m.bilesen_schedule_baslangic_hata
              : null,
          onTap: _mesgul ? null : () => unawaited(_baslangicSec()),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        ProgramAnAlani(
          etiket: m.bilesen_schedule_bitis,
          deger: bitis == null
              ? m.bilesen_schedule_bitis_yok
              : etkinlikTarihSaat(m, bitis),
          hata: _hatalar.contains(ProgramHatasi.bitis)
              ? m.bilesen_schedule_bitis_hata
              : null,
          onTap: _mesgul ? null : () => unawaited(_bitisSec()),
          onTemizle: bitis == null || _mesgul
              ? null
              : () => setState(() {
                  _bitis = null;
                  _hatalar = _hatalar.difference({ProgramHatasi.bitis});
                }),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        TextField(
          controller: _not,
          maxLength: programNotuEnCok,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.bilesen_schedule_not_alani,
            errorText: _hatalar.contains(ProgramHatasi.not)
                ? m.bilesen_schedule_not_hata(programNotuEnCok)
                : null,
            errorMaxLines: 2,
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// Formdaki gün ve saat alanı: etiketli kutu, dokununca seçici açılır.
/// [onTemizle] verilirse sağda "Bitişi kaldır" düğmesi vardır. Ekran
/// okuyucu etiket ve değeri düğme olarak okur.
class ProgramAnAlani extends StatelessWidget {
  const ProgramAnAlani({
    super.key,
    required this.etiket,
    required this.deger,
    required this.onTap,
    this.hata,
    this.onTemizle,
  });

  final String etiket;
  final String deger;
  final String? hata;

  /// `null` ise (gönderim sürerken) seçilemez.
  final VoidCallback? onTap;

  final VoidCallback? onTemizle;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final temizle = onTemizle;
    return InkWell(
      onTap: onTap,
      borderRadius: TayfamRadii.dugmeKoseleri,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiket,
          errorText: hata,
          errorMaxLines: 3,
          enabled: onTap != null,
          suffixIcon: temizle == null
              ? const ExcludeSemantics(child: Icon(Icons.event_outlined))
              : AracIkonDugmesi(
                  ipucu: m.bilesen_schedule_bitisi_kaldir,
                  ikon: Icons.close,
                  onPressed: temizle,
                ),
        ),
        child: Text(deger, style: context.yazi.bodyLarge),
      ),
    );
  }
}
