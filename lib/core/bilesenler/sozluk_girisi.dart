import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa sözlüğünde bir değer: kimliği ve gösterilen metni (Tayfam-Api
/// `TayfaVocabularyValue`; birleştirilmiş değer hedefine çözülmüş gelir).
typedef SozlukOnerisi = ({String kimlik, String metin});

/// Öneri araması yazmayı bu kadar bekler (App ADR-0031 §5).
const Duration sozlukAramaGecikmesi = Duration(milliseconds: 300);

/// Öneri araması için en az bu kadar harf yazılır (ADR-0031 §5).
const int sozlukAramaEnAz = 2;

/// Sözleşmedeki arama metni sınırı (`q`, en fazla 60 karakter).
const int sozlukAramaEnCok = 60;

/// Formda gösterilen en çok öneri (sunucu 20'ye kadar döndürür).
const int sozlukOneriEnCok = 5;

/// [metin]'in sözlükteki karşılaştırma anahtarı: baştaki ve sondaki boşluk
/// atılır, boşluklar teke iner, Türkçe küçük harfe çevrilir (sunucunun
/// tekillik kuralı; ADR-0008). Yalnızca karşılaştırma içindir; arayüzde
/// gösterilmez.
String sozlukAnahtari(String metin) =>
    turkceKucukHarf(metin.trim().replaceAll(RegExp(r'\s+'), ' '));

/// [metin] [oneriler]'den birinin aynısı mı (sözlük anahtarına göre);
/// öyleyse o öneri.
SozlukOnerisi? sozlukEslesmesi(String metin, Iterable<SozlukOnerisi> oneriler) {
  final anahtar = sozlukAnahtari(metin);
  if (anahtar.isEmpty) return null;
  for (final oneri in oneriler) {
    if (sozlukAnahtari(oneri.metin) == anahtar) return oneri;
  }
  return null;
}

/// Tayfa sözlüğüne bağlı metin alanı (App ADR-0031 §5; Tayfam-Api
/// ADR-0037 §4): serbest metin + tayfanın önceki değerlerinden otomatik
/// tamamlama.
///
/// - Yazdıkça [sozlukAramaGecikmesi] sonra, en az [sozlukAramaEnAz] harfte
///   [ara] çağrılır; eski aramanın geç gelen sonucu yok sayılır. Öneriler
///   alanın hemen altında, dokunulabilir satırlar olarak gösterilir.
///   Öneriler yalnızca bellektedir, ekran ömrüyle sınırlıdır (ADR-0006).
/// - Öneri seçilince ya da yazılan metin bir öneriyle aynıysa (Türkçe küçük
///   harf, tek boşluk) [onDegisti] değerin kimliğiyle çağrılır; kayıt
///   değerin kimliğini gönderir. Değilse kimlik `null`dır ve metin yeni
///   değer olarak gider (sunucu sözlüğe ekler).
/// - Arama hatası formu durdurmaz: öneri gösterilmez, metin yine gider.
/// - [onDegisti] `null` ise alan kapalıdır (gönderim sürerken).
class SozlukGirisi extends StatefulWidget {
  const SozlukGirisi({
    super.key,
    required this.etiket,
    required this.metin,
    required this.kimlik,
    required this.ara,
    required this.onDegisti,
    this.enCokUzunluk,
    this.hataMetni,
    this.hataStili,
  });

  /// Alanın etiketi (katalog metni; "(isteğe bağlı)" eki çağırandadır).
  final String etiket;

  /// Alandaki metin.
  final String metin;

  /// Seçili sözlük değerinin kimliği; yeni metinde `null`.
  final String? kimlik;

  /// `GET …/vocabulary/{namespace}?q=` çağrısı.
  final Future<List<SozlukOnerisi>> Function(String arama) ara;

  /// Metin ya da seçim değişince yeni metin ve (varsa) değerin kimliği.
  final void Function(String metin, String? kimlik)? onDegisti;

  /// Metnin en çok uzunluğu (sayaç gösterilir).
  final int? enCokUzunluk;

  final String? hataMetni;
  final TextStyle? hataStili;

  @override
  State<SozlukGirisi> createState() => _SozlukGirisiState();
}

class _SozlukGirisiState extends State<SozlukGirisi> {
  late final TextEditingController _denetleyici = TextEditingController(
    text: widget.metin,
  );
  Timer? _zamanlayici;

  /// Son başlatılan aramanın sırası; geç gelen eski sonuç atılır.
  int _sira = 0;
  List<SozlukOnerisi> _oneriler = const [];

  /// Son tamamlanan aramanın anahtarı (yeni değer ipucu için).
  String? _arananAnahtar;
  bool _araniyor = false;

  @override
  void didUpdateWidget(SozlukGirisi eski) {
    super.didUpdateWidget(eski);
    // Değer dışarıdan değiştiyse (form sıfırlandı) metin de değişir.
    if (_denetleyici.text != widget.metin) _denetleyici.text = widget.metin;
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _denetleyici.dispose();
    super.dispose();
  }

  void _yazildi(String metin) {
    widget.onDegisti?.call(metin, sozlukEslesmesi(metin, _oneriler)?.kimlik);
    _zamanlayici?.cancel();
    final arama = metin.trim();
    if (arama.runes.length < sozlukAramaEnAz) {
      _sira++;
      setState(() {
        _oneriler = const [];
        _arananAnahtar = null;
        _araniyor = false;
      });
      return;
    }
    _zamanlayici = Timer(sozlukAramaGecikmesi, () => unawaited(_ara(arama)));
  }

  Future<void> _ara(String arama) async {
    final sira = ++_sira;
    final q = String.fromCharCodes(arama.runes.take(sozlukAramaEnCok));
    setState(() => _araniyor = true);
    List<SozlukOnerisi> sonuc;
    try {
      sonuc = await widget.ara(q);
    } on Exception {
      sonuc = const [];
    }
    if (!mounted || sira != _sira) return;
    setState(() {
      _oneriler = List.unmodifiable(sonuc);
      _arananAnahtar = sozlukAnahtari(arama);
      _araniyor = false;
    });
    // Yazılan metin bilinen bir değerse değerin kimliği gider.
    final metin = _denetleyici.text;
    final eslesen = sozlukEslesmesi(metin, _oneriler);
    if (eslesen != null && eslesen.kimlik != widget.kimlik) {
      widget.onDegisti?.call(metin, eslesen.kimlik);
    }
  }

  void _sec(SozlukOnerisi oneri) {
    _zamanlayici?.cancel();
    _sira++;
    _denetleyici.value = TextEditingValue(
      text: oneri.metin,
      selection: TextSelection.collapsed(offset: oneri.metin.length),
    );
    setState(() {
      _oneriler = const [];
      _arananAnahtar = sozlukAnahtari(oneri.metin);
      _araniyor = false;
    });
    widget.onDegisti?.call(oneri.metin, oneri.kimlik);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final acik = widget.onDegisti != null;
    final metin = _denetleyici.text;
    final kimlik = widget.kimlik;
    // Seçili değerle aynı olan öneri tekrar gösterilmez.
    final oneriler = [
      for (final o in _oneriler)
        if (o.kimlik != kimlik) o,
    ].take(sozlukOneriEnCok).toList(growable: false);
    final String? ipucu;
    if (kimlik != null) {
      ipucu = m.bilesen_vocab_sozlukten;
    } else if (!_araniyor &&
        _arananAnahtar != null &&
        _arananAnahtar == sozlukAnahtari(metin)) {
      ipucu = m.bilesen_vocab_yeni_deger;
    } else {
      ipucu = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _denetleyici,
          enabled: acik,
          maxLength: widget.enCokUzunluk,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _yazildi,
          decoration: InputDecoration(
            labelText: widget.etiket,
            helperText: ipucu,
            helperMaxLines: 3,
            errorText: widget.hataMetni,
            errorStyle: widget.hataStili,
            errorMaxLines: 3,
            suffixIcon: kimlik == null
                ? null
                : ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: context.renkler.metinIkincil,
                    ),
                  ),
          ),
        ),
        if (acik && oneriler.isNotEmpty)
          _OneriListesi(oneriler: oneriler, onSec: _sec),
      ],
    );
  }
}

/// Alanın altındaki öneriler: kart zeminli, kenarlı liste; her satır en az
/// 48 dp yüksekliğinde tek düğmedir.
class _OneriListesi extends StatelessWidget {
  const _OneriListesi({required this.oneriler, required this.onSec});

  final List<SozlukOnerisi> oneriler;
  final ValueChanged<SozlukOnerisi> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s4),
      child: Semantics(
        container: true,
        label: m.bilesen_vocab_oneriler,
        child: Material(
          color: r.kart,
          shape: RoundedRectangleBorder(
            borderRadius: TayfamRadii.dugmeKoseleri,
            side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, oneri) in oneriler.indexed) ...[
                if (sira > 0)
                  Divider(height: TayfamSizes.kenar, color: r.cizgi),
                OdakCercevesi(
                  koseler: BorderRadius.zero,
                  child: MergeSemantics(
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => onSec(oneri),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: TayfamSizes.dokunmaMin,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TayfamSpacing.s12,
                              vertical: TayfamSpacing.s8,
                            ),
                            child: Row(
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.history,
                                    size: TayfamSizes.ikon,
                                    color: r.metinIkincil,
                                  ),
                                ),
                                const SizedBox(width: TayfamSpacing.s12),
                                Expanded(
                                  child: Text(
                                    oneri.metin,
                                    style: context.yazi.bodyLarge?.copyWith(
                                      color: r.metin,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
