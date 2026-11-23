import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/alt_sayfa.dart';
import 'package:tayfam/core/bilesenler/birincil_eylem.dart';
import 'package:tayfam/core/bilesenler/bolum_etiketi.dart';
import 'package:tayfam/core/bilesenler/cerceveli_eylem.dart';
import 'package:tayfam/core/bilesenler/ders_konu_secici.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [anahtar]'lı ders/konu etiketinin üst zinciriyle yazımı ("TYT ›
/// Matematik › Türev"; Tayfam-Api ADR-0043 §4). Adlar katalog içeriğidir
/// (ADR-0024 §2); emekli etiket de adıyla yazılır. Listede hiç olmayan
/// anahtar (bozuk ya da eski katalog) için `null`: gösterilmez.
String? dersKonuYolMetni(
  AppLocalizations m,
  DersKonuAgaci agac,
  String anahtar,
  String dil,
) {
  final yol = agac.yol(anahtar);
  if (yol.isEmpty) return null;
  String ad(String a) => katalogAdi(agac.etiket(a)?.labels, dil) ?? a;
  return yol
      .skip(1)
      .fold<String>(ad(yol.first), (ust, a) => m.ders_konu_yol(ust, ad(a)));
}

/// Tür alanı `study_tags`'in form çizimi (Tayfam-Api ADR-0043 §4).
///
/// - **Tek seçim, ders..konu:** ortak [DersKonuSecici]; çıktısı
///   `[konu ?? ders]` olarak yazılır ([dersKonuDegeri]).
/// - **Tek seçim, düzey de seçilebilen alan:** seçicinin etiket kipi
///   ([DersKonuSecici.etiket]).
/// - **Çoklu seçim:** seçilenler üst zinciriyle satır satır, her birinde
///   "Kaldır"; "Ekle" alttan açılan sayfada etiket kipindeki seçiciyle
///   bir etiket daha seçtirir.
///
/// Seçici yalnızca seçilebilir etiketleri (kendisi ve üstleri aktif,
/// seviyesi alanın aralığında) sunar. Mevcut değerdeki emekli etiket
/// adıyla ve "artık seçilemez" notuyla kalır ve değişmeden geri gönderilir;
/// kaldırılabilir ama yeniden eklenemez. Listede hiç olmayan anahtar
/// gösterilmez ama değerden düşürülmez.
class DersKonuAlani extends StatelessWidget {
  const DersKonuAlani({
    super.key,
    required this.alan,
    required this.etiket,
    required this.deger,
    required this.onDegisti,
    this.hataMetni,
  });

  final CatalogField alan;

  /// Alanın gösterilen adı ("(isteğe bağlı)" dahil).
  final String etiket;

  /// Seçili anahtarlar, sırasıyla.
  final List<String> deger;

  /// Yeni değerle çağrılır; değer boşalınca `null`. `null` ise alan
  /// kapalıdır.
  final ValueChanged<List<String>?>? onDegisti;

  final String? hataMetni;

  void _yaz(List<String> yeni) =>
      onDegisti?.call(yeni.isEmpty ? null : List<String>.unmodifiable(yeni));

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final enCok = alanEnCokSecim(alan);
    final enSig = alanEnSigSeviye(alan);
    final enDerin = alanEnDerinSeviye(alan);
    final acik = onDegisti != null;
    if (enCok == 1) {
      final secili = deger.isEmpty ? null : deger.first;
      final temizlenir = acik && secili != null && alan.required_ != true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BolumEtiketi(
            baslik: etiket,
            sag: temizlenir
                ? BaglantiEylemi(
                    etiket: m.ders_konu_alan_temizle,
                    onPressed: () => _yaz(const []),
                  )
                : null,
          ),
          if (enSig == DersKonuSeviyesi.ders)
            KatalogBekleyici(
              builder: (context, katalog) => DersKonuSecici(
                secim: secili == null
                    ? null
                    : katalog.dersKonu.secimOku(secili),
                konuSecilir: enDerin == DersKonuSeviyesi.konu,
                onDegisti: !acik
                    ? null
                    : (secim) => _yaz(dersKonuDegeri(secim)),
              ),
            )
          else
            DersKonuSecici.etiket(
              etiket: secili,
              enSig: enSig,
              enDerin: enDerin,
              onEtiketDegisti: !acik
                  ? null
                  : (k) => _yaz(k == null ? const [] : [k]),
            ),
          ..._hata(),
        ],
      );
    }
    return KatalogBekleyici(
      builder: (context, katalog) {
        final agac = katalog.dersKonu;
        final dil = katalogDili(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BolumEtiketi(
              baslik: etiket,
              sag: Text(
                m.katalog_cok_secim_sayaci(deger.length, enCok),
                style: context.yazi.bodySmall,
              ),
            ),
            for (final anahtar in deger)
              if (dersKonuYolMetni(m, agac, anahtar, dil) case final yol?)
                _SeciliEtiket(
                  metin: yol,
                  not: agac.secilebilir(anahtar) ? null : m.ders_konu_emekli,
                  onKaldir: !acik
                      ? null
                      : () => _yaz([
                          for (final a in deger)
                            if (a != anahtar) a,
                        ]),
                ),
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CerceveliHapEylem(
                etiket: m.ders_konu_alan_ekle,
                ikon: Icons.add,
                onPressed: !acik || deger.length >= enCok
                    ? null
                    : () => unawaited(_ekle(context, enSig, enDerin)),
              ),
            ),
            ..._hata(),
          ],
        );
      },
    );
  }

  /// Alanın hatası (zorunlu, biçim ya da sunucunun `fields.<anahtar>`
  /// hatası) alanın altında.
  List<Widget> _hata() {
    final hataMetni = this.hataMetni;
    return hataMetni == null
        ? const []
        : [
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: hataMetni),
          ];
  }

  Future<void> _ekle(
    BuildContext context,
    DersKonuSeviyesi enSig,
    DersKonuSeviyesi enDerin,
  ) async {
    final secilen = await altSayfaAc<String>(
      context,
      builder: (_) => _EkleSayfasi(
        baslik: etiket,
        enSig: enSig,
        enDerin: enDerin,
        mevcut: deger,
      ),
    );
    if (secilen == null || deger.contains(secilen)) return;
    _yaz([...deger, secilen]);
  }
}

/// Çoklu alandaki bir seçim: üst zinciri, emekliyse notu ve "Kaldır".
class _SeciliEtiket extends StatelessWidget {
  const _SeciliEtiket({required this.metin, required this.onKaldir, this.not});

  final String metin;
  final String? not;
  final VoidCallback? onKaldir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final not = this.not;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metin, style: context.yazi.bodyLarge),
                if (not != null)
                  Text(
                    not,
                    style: context.yazi.bodySmall?.copyWith(
                      color: context.renkler.metinIkincil,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: m.ders_konu_alan_kaldir(metin),
            constraints: const BoxConstraints(
              minWidth: TayfamSizes.dokunmaMin,
              minHeight: TayfamSizes.dokunmaMin,
            ),
            onPressed: onKaldir,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Çoklu alana bir etiket ekleme sayfası: etiket kipindeki seçici ve
/// "Ekle". Alanda zaten olan etiket eklenemez.
class _EkleSayfasi extends StatefulWidget {
  const _EkleSayfasi({
    required this.baslik,
    required this.enSig,
    required this.enDerin,
    required this.mevcut,
  });

  final String baslik;
  final DersKonuSeviyesi enSig;
  final DersKonuSeviyesi enDerin;
  final List<String> mevcut;

  @override
  State<_EkleSayfasi> createState() => _EkleSayfasiState();
}

class _EkleSayfasiState extends State<_EkleSayfasi> {
  String? _secili;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final secili = _secili;
    final zaten = secili != null && widget.mevcut.contains(secili);
    return AltSayfaIcerigi(
      baslik: widget.baslik,
      children: [
        DersKonuSecici.etiket(
          etiket: secili,
          enSig: widget.enSig,
          enDerin: widget.enDerin,
          onEtiketDegisti: (k) => setState(() => _secili = k),
        ),
        if (zaten) ...[
          const SizedBox(height: TayfamSpacing.s12),
          Text(
            m.ders_konu_alan_zaten,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s20),
        BirincilEylem(
          etiket: m.ders_konu_alan_ekle,
          onPressed: secili == null || zaten
              ? null
              : () => Navigator.of(context).pop(secili),
        ),
      ],
    );
  }
}
