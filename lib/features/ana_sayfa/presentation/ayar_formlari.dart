import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/ana_sayfa/presentation/gosterim_kartlari.dart';
import 'package:tayfam/features/ana_sayfa/presentation/metrik.dart';
import 'package:tayfam/features/istatistik/istatistik.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// İstatistik kartında en çok kaç metrik (sözleşme: `StatsWidgetConfig`).
const int istatistikEnCokMetrik = 4;

/// Şampiyonlar kartında en çok kaç tür (sözleşme:
/// `ChampionsWidgetConfig`).
const int sampiyonEnCokTur = 10;

/// Geri sayım başlığının en çok uzunluğu (sözleşme).
const int geriSayimBaslikEnCok = 60;

/// Hedefin en büyük değeri (sözleşme: `GoalWidgetConfig.target`).
const double hedefEnCok = 1000000000;

/// Ortak metriklerin anahtarları (sözleşme: `TayfaStatMetricKey`); her
/// tayfada seçilebilir.
const List<String> ortakMetrikler = [
  'events',
  'attended',
  'participants',
  'duration',
];

/// Seçilebilir bir metrik: anahtarı ve adı.
typedef MetrikSecenegi = ({String anahtar, String ad});

/// Metrik seçenekleri: ortak metrikler (günlük özetinde değil), sonra
/// tayfanın tüm zamanlar istatistiğinde görünen metrikler, sonra listede
/// olmayan ama seçili olanlar. Bu sürümün tanımadığı metrik seçilemez
/// (seçiliyse adı "tanınmıyor" olarak kalır).
List<MetrikSecenegi> metrikSecenekleri(
  AppLocalizations m, {
  required List<TayfaStat> statlar,
  required Katalog katalog,
  required String dil,
  required Iterable<String> secili,
  bool yalnizcaGunluk = false,
}) {
  final gorulen = <String>{};
  final sonuc = <MetrikSecenegi>[];
  void ekle(String anahtar, {bool bilinmeyen = false}) {
    if (!gorulen.add(anahtar)) return;
    final ad = anaSayfaMetrigi(
      m,
      anahtar: anahtar,
      deger: 0,
      katalog: katalog,
      dil: dil,
    )?.ad;
    if (ad != null) {
      sonuc.add((anahtar: anahtar, ad: ad));
    } else if (bilinmeyen) {
      sonuc.add((anahtar: anahtar, ad: m.anasayfa_metrik_bilinmiyor));
    }
  }

  if (!yalnizcaGunluk) ortakMetrikler.forEach(ekle);
  for (final s in statlar) {
    if (yalnizcaGunluk && s.source != TayfaStatSource.log) continue;
    ekle(s.metricKey);
  }
  for (final s in secili) {
    ekle(s, bilinmeyen: true);
  }
  return sonuc;
}

/// Ayar sayfalarının iskeleti: başlık, "Kaydet" (geçerli değilse kapalı)
/// ve kayan içerik. Kaydedince sayfa yeni ayarla kapanır; geri tuşu
/// vazgeçer.
class _AyarSayfasi extends StatelessWidget {
  const _AyarSayfasi({
    required this.baslik,
    required this.onKaydet,
    required this.children,
  });

  final String baslik;

  /// `null` ise "Kaydet" kapalıdır.
  final VoidCallback? onKaydet;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(baslik),
        actions: [
          TextButton(
            onPressed: onKaydet,
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.anasayfa_ayar_kaydet),
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
          children: children,
        ),
      ),
    );
  }
}

Future<HomeWidgetConfig?> _ac(BuildContext context, Widget sayfa) =>
    Navigator.of(context).push<HomeWidgetConfig>(
      MaterialPageRoute<HomeWidgetConfig>(
        fullscreenDialog: true,
        builder: (_) => sayfa,
      ),
    );

/// Dönem çipleri; seçili çipte onay işareti vardır (yalnızca renge
/// dayanmaz). Dar ekranda alt satıra kayar.
class _DonemCipleri extends StatelessWidget {
  const _DonemCipleri({
    required this.donemler,
    required this.secili,
    required this.onSec,
  });

  final List<HomeWidgetPeriod> donemler;
  final HomeWidgetPeriod secili;
  final ValueChanged<HomeWidgetPeriod> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.anasayfa_ayar_donem),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final d in donemler)
              ChoiceChip(
                label: Text(donemMetni(m, d, null)),
                selected: d == secili,
                onSelected: (_) => onSec(d),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tayfanın tüm zamanlar istatistiğini okuyup metrik seçeneklerini
/// kuran sarmalayıcı. İstatistik okunamazsa hata satırı gösterilir; ortak
/// metrikler yine seçilebilir.
class _MetrikSecenekleri extends ConsumerWidget {
  const _MetrikSecenekleri({
    required this.tayfaId,
    required this.secili,
    required this.builder,
    this.yalnizcaGunluk = false,
  });

  final String tayfaId;
  final Iterable<String> secili;
  final bool yalnizcaGunluk;
  final Widget Function(BuildContext context, List<MetrikSecenegi> secenekler)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(
      tayfaIstatistikleriProvider((tayfaId: tayfaId, yil: tumZamanlar)),
    );
    final statlar = durum.value?.totals;
    if (statlar == null && durum.error == null) {
      return Center(child: TayfamYukleniyor(etiket: m.anasayfa_yukleniyor));
    }
    return KatalogBekleyici(
      builder: (context, katalog) {
        final secenekler = metrikSecenekleri(
          m,
          statlar: statlar ?? const [],
          katalog: katalog,
          dil: katalogDili(context),
          secili: secili,
          yalnizcaGunluk: yalnizcaGunluk,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (durum.error case final hata?) HataSatiri.hatadan(hata),
            builder(context, secenekler),
          ],
        );
      },
    );
  }
}

/// Tek seçimli metrik listesi: seçili satırda onay işareti; ekran okuyucu
/// satırı seçili/seçili değil diye okur.
class _TekMetrikListesi extends StatelessWidget {
  const _TekMetrikListesi({
    required this.secenekler,
    required this.secili,
    required this.onSec,
  });

  final List<MetrikSecenegi> secenekler;
  final String? secili;
  final ValueChanged<String> onSec;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ListeKarti(
      children: [
        for (final s in secenekler)
          Semantics(
            selected: s.anahtar == secili,
            inMutuallyExclusiveGroup: true,
            child: ListTile(
              title: Text(s.ad),
              trailing: s.anahtar == secili
                  ? Icon(Icons.check, color: r.marka)
                  : null,
              onTap: () => onSec(s.anahtar),
            ),
          ),
      ],
    );
  }
}

// --- İstatistik (`stats`) -----------------------------------------------------

/// İstatistik kartının ayarını açar: en çok dört metrik ve dönem (bu yıl
/// ya da tüm zamanlar).
Future<HomeWidgetConfig?> istatistikAyariniAc(
  BuildContext context,
  String tayfaId,
  HomeWidgetConfig? mevcut,
) => _ac(context, _IstatistikAyari(tayfaId: tayfaId, mevcut: mevcut?.stats));

class _IstatistikAyari extends StatefulWidget {
  const _IstatistikAyari({required this.tayfaId, required this.mevcut});

  final String tayfaId;
  final StatsWidgetConfig? mevcut;

  @override
  State<_IstatistikAyari> createState() => _IstatistikAyariState();
}

class _IstatistikAyariState extends State<_IstatistikAyari> {
  late final List<String> _secili = [
    ...?widget.mevcut?.metricKeys.take(istatistikEnCokMetrik),
  ];
  late HomeWidgetPeriod _donem = switch (widget.mevcut?.period) {
    HomeWidgetPeriod.allTime => HomeWidgetPeriod.allTime,
    _ => HomeWidgetPeriod.thisYear,
  };

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final dolu = _secili.length >= istatistikEnCokMetrik;
    return _AyarSayfasi(
      baslik: m.anasayfa_stats_ad,
      onKaydet: _secili.isEmpty
          ? null
          : () => Navigator.of(context).pop(
              HomeWidgetConfig(
                stats: StatsWidgetConfig(
                  metricKeys: List.unmodifiable(_secili),
                  period: _donem,
                ),
              ),
            ),
      children: [
        _DonemCipleri(
          donemler: const [HomeWidgetPeriod.thisYear, HomeWidgetPeriod.allTime],
          secili: _donem,
          onSec: (d) => setState(() => _donem = d),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BolumEtiketi(
          baslik: m.anasayfa_ayar_metrikler(
            _secili.length,
            istatistikEnCokMetrik,
          ),
        ),
        _MetrikSecenekleri(
          tayfaId: widget.tayfaId,
          secili: _secili,
          builder: (context, secenekler) => ListeKarti(
            children: [
              for (final s in secenekler)
                CheckboxListTile(
                  title: Text(s.ad),
                  value: _secili.contains(s.anahtar),
                  onChanged: !_secili.contains(s.anahtar) && dolu
                      ? null
                      : (secildi) => setState(() {
                          if (secildi ?? false) {
                            _secili.add(s.anahtar);
                          } else {
                            _secili.remove(s.anahtar);
                          }
                        }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Yıllık hedef (`goal`) ----------------------------------------------------

/// Yıllık hedefin ayarını açar: bir metrik ve hedef değer. Yıl alanı
/// varsa korunur (yoksa her zaman içinde bulunulan yıl).
Future<HomeWidgetConfig?> hedefAyariniAc(
  BuildContext context,
  String tayfaId,
  HomeWidgetConfig? mevcut,
) => _ac(context, _HedefAyari(tayfaId: tayfaId, mevcut: mevcut?.goal));

/// Hedef değer metnini okur (`1.250`, `12,5`); geçersizse ya da sınır
/// dışındaysa `null`.
double? hedefDegeriOku(String metin) {
  final temiz = metin.trim().replaceAll('.', '').replaceAll(',', '.');
  final deger = double.tryParse(temiz);
  if (deger == null || !deger.isFinite || deger <= 0 || deger > hedefEnCok) {
    return null;
  }
  return deger;
}

class _HedefAyari extends StatefulWidget {
  const _HedefAyari({required this.tayfaId, required this.mevcut});

  final String tayfaId;
  final GoalWidgetConfig? mevcut;

  @override
  State<_HedefAyari> createState() => _HedefAyariState();
}

class _HedefAyariState extends State<_HedefAyari> {
  late String? _metrik = widget.mevcut?.metricKey;
  late final TextEditingController _hedef = TextEditingController();
  bool _hedefDokunuldu = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mevcut = widget.mevcut;
    if (mevcut != null && _hedef.text.isEmpty && !_hedefDokunuldu) {
      _hedef.text = istatistikSayisi(
        AppLocalizations.of(context),
        mevcut.target,
      );
    }
  }

  @override
  void dispose() {
    _hedef.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hedef = hedefDegeriOku(_hedef.text);
    final metrik = _metrik;
    return _AyarSayfasi(
      baslik: m.anasayfa_goal_ad,
      onKaydet: metrik == null || hedef == null
          ? null
          : () => Navigator.of(context).pop(
              HomeWidgetConfig(
                goal: GoalWidgetConfig(
                  metricKey: metrik,
                  target: hedef,
                  year: widget.mevcut?.year,
                ),
              ),
            ),
      children: [
        TextField(
          controller: _hedef,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: m.anasayfa_goal_hedef_alani,
            errorText: _hedefDokunuldu && hedef == null
                ? m.anasayfa_goal_hedef_hatasi
                : null,
          ),
          onChanged: (_) => setState(() => _hedefDokunuldu = true),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BolumEtiketi(baslik: m.anasayfa_ayar_metrik),
        _MetrikSecenekleri(
          tayfaId: widget.tayfaId,
          secili: [?metrik],
          builder: (context, secenekler) => _TekMetrikListesi(
            secenekler: secenekler,
            secili: metrik,
            onSec: (a) => setState(() => _metrik = a),
          ),
        ),
      ],
    );
  }
}

// --- Günlük özeti (`log_summary`) ---------------------------------------------

/// Günlük özetinin ayarını açar: bir günlük istatistiği ve dönem.
Future<HomeWidgetConfig?> gunlukOzetiAyariniAc(
  BuildContext context,
  String tayfaId,
  HomeWidgetConfig? mevcut,
) => _ac(
  context,
  _GunlukOzetiAyari(tayfaId: tayfaId, mevcut: mevcut?.logSummary),
);

class _GunlukOzetiAyari extends StatefulWidget {
  const _GunlukOzetiAyari({required this.tayfaId, required this.mevcut});

  final String tayfaId;
  final LogSummaryWidgetConfig? mevcut;

  @override
  State<_GunlukOzetiAyari> createState() => _GunlukOzetiAyariState();
}

class _GunlukOzetiAyariState extends State<_GunlukOzetiAyari> {
  late String? _metrik = widget.mevcut?.metricKey;
  late HomeWidgetPeriod _donem = switch (widget.mevcut?.period) {
    HomeWidgetPeriod.allTime => HomeWidgetPeriod.allTime,
    _ => HomeWidgetPeriod.thisYear,
  };

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final metrik = _metrik;
    return _AyarSayfasi(
      baslik: m.anasayfa_log_summary_ad,
      onKaydet: metrik == null
          ? null
          : () => Navigator.of(context).pop(
              HomeWidgetConfig(
                logSummary: LogSummaryWidgetConfig(
                  metricKey: metrik,
                  period: _donem,
                ),
              ),
            ),
      children: [
        _DonemCipleri(
          donemler: const [HomeWidgetPeriod.thisYear, HomeWidgetPeriod.allTime],
          secili: _donem,
          onSec: (d) => setState(() => _donem = d),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BolumEtiketi(baslik: m.anasayfa_ayar_metrik),
        _MetrikSecenekleri(
          tayfaId: widget.tayfaId,
          secili: [?metrik],
          yalnizcaGunluk: true,
          builder: (context, secenekler) => secenekler.isEmpty
              ? IstatistikNotu(
                  metin: m.anasayfa_log_summary_bos,
                  ikincil: false,
                )
              : _TekMetrikListesi(
                  secenekler: secenekler,
                  secili: metrik,
                  onSec: (a) => setState(() => _metrik = a),
                ),
        ),
      ],
    );
  }
}

// --- Geri sayım (`countdown`) -------------------------------------------------

/// Geri sayımın ayarını açar: başlık (1–60) ve gelecekteki an.
Future<HomeWidgetConfig?> geriSayimAyariniAc(
  BuildContext context,
  String tayfaId,
  HomeWidgetConfig? mevcut,
) => _ac(context, _GeriSayimAyari(mevcut: mevcut?.countdown));

class _GeriSayimAyari extends ConsumerStatefulWidget {
  const _GeriSayimAyari({required this.mevcut});

  final CountdownWidgetConfig? mevcut;

  @override
  ConsumerState<_GeriSayimAyari> createState() => _GeriSayimAyariState();
}

class _GeriSayimAyariState extends ConsumerState<_GeriSayimAyari> {
  late final TextEditingController _baslik = TextEditingController(
    text: widget.mevcut?.title ?? '',
  );
  late DateTime? _an = widget.mevcut?.at;

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  Future<void> _anSec() async {
    final simdi = ref.read(simdiProvider)().toLocal();
    final baslangic = (_an ?? simdi.add(const Duration(days: 7))).toLocal();
    final ilkGun = DateTime(simdi.year, simdi.month, simdi.day);
    final secilen = DateTime(baslangic.year, baslangic.month, baslangic.day);
    final gun = await showDatePicker(
      context: context,
      initialDate: secilen.isBefore(ilkGun) ? ilkGun : secilen,
      firstDate: ilkGun,
      lastDate: DateTime(ilkGun.year + 5, ilkGun.month, ilkGun.day),
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: baslangic.hour, minute: baslangic.minute),
    );
    if (saat == null || !mounted) return;
    setState(() {
      _an = DateTime(
        gun.year,
        gun.month,
        gun.day,
        saat.hour,
        saat.minute,
      ).toUtc();
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final simdi = ref.watch(simdiProvider)();
    final baslik = _baslik.text.trim();
    final an = _an;
    final gecmis = an != null && !an.isAfter(simdi);
    final baslikGecerli =
        baslik.isNotEmpty && baslik.length <= geriSayimBaslikEnCok;
    return _AyarSayfasi(
      baslik: m.anasayfa_countdown_ad,
      onKaydet: switch (an) {
        final an? when baslikGecerli && !gecmis =>
          () => Navigator.of(context).pop(
            HomeWidgetConfig(
              countdown: CountdownWidgetConfig(title: baslik, at: an),
            ),
          ),
        _ => null,
      },
      children: [
        TextField(
          controller: _baslik,
          maxLength: geriSayimBaslikEnCok,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.anasayfa_countdown_baslik_alani,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        BolumEtiketi(baslik: m.anasayfa_countdown_an_alani),
        ListeKarti(
          children: [
            ListeKartiSatiri(
              onTap: () => unawaited(_anSec()),
              child: Row(
                children: [
                  const ExcludeSemantics(child: Icon(Icons.event_outlined)),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Text(
                      an == null
                          ? m.anasayfa_countdown_an_sec
                          : m.anasayfa_countdown_an(
                              DateFormat.yMMMMEEEEd(m.localeName)
                                  .format(an.toLocal()),
                              saatMetni(m, an),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (gecmis)
          Padding(
            padding: const EdgeInsets.only(top: TayfamSpacing.s8),
            child: HataSatiri(metin: m.anasayfa_countdown_gecmis),
          ),
      ],
    );
  }
}

// --- Şampiyonlar (`champions`) ------------------------------------------------

/// Şampiyonlar kartının ayarını açar: türler (boşsa her tür, en çok on)
/// ve dönem (son 30 gün ya da bu yıl).
Future<HomeWidgetConfig?> sampiyonlarAyariniAc(
  BuildContext context,
  String tayfaId,
  HomeWidgetConfig? mevcut,
) => _ac(context, _SampiyonlarAyari(mevcut: mevcut?.champions));

/// Türün tanımında kutlama bileşeni var mı (şampiyon çıkabilir).
bool kutlamaliTur(CatalogEventType tur) =>
    (tur.definition.components ?? const <CatalogComponent>[]).any(
      (b) => b.kind == 'celebration',
    );

class _SampiyonlarAyari extends StatefulWidget {
  const _SampiyonlarAyari({required this.mevcut});

  final ChampionsWidgetConfig? mevcut;

  @override
  State<_SampiyonlarAyari> createState() => _SampiyonlarAyariState();
}

class _SampiyonlarAyariState extends State<_SampiyonlarAyari> {
  late final List<String> _turler = [
    ...?widget.mevcut?.eventTypes.take(sampiyonEnCokTur),
  ];
  late HomeWidgetPeriod _donem = switch (widget.mevcut?.period) {
    HomeWidgetPeriod.last30Days => HomeWidgetPeriod.last30Days,
    _ => HomeWidgetPeriod.thisYear,
  };

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final dolu = _turler.length >= sampiyonEnCokTur;
    return _AyarSayfasi(
      baslik: m.anasayfa_champions_ad,
      onKaydet: () => Navigator.of(context).pop(
        HomeWidgetConfig(
          champions: ChampionsWidgetConfig(
            eventTypes: List.unmodifiable(_turler),
            period: _donem,
          ),
        ),
      ),
      children: [
        _DonemCipleri(
          donemler: const [
            HomeWidgetPeriod.last30Days,
            HomeWidgetPeriod.thisYear,
          ],
          secili: _donem,
          onSec: (d) => setState(() => _donem = d),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BolumEtiketi(baslik: m.anasayfa_champions_turler),
        IstatistikNotu(metin: m.anasayfa_champions_turler_aciklama),
        const SizedBox(height: TayfamSpacing.s8),
        KatalogBekleyici(
          builder: (context, katalog) {
            final dil = katalogDili(context);
            final turler = [
              for (final t in katalog.turler)
                if (_turler.contains(t.key) ||
                    (t.status == CatalogStatus.active && kutlamaliTur(t)))
                  if (katalogAdi(t.labels, dil) case final ad?) (t, ad),
            ];
            return ListeKarti(
              children: [
                for (final (t, ad) in turler)
                  CheckboxListTile(
                    title: Text(ad),
                    value: _turler.contains(t.key),
                    onChanged: !_turler.contains(t.key) && dolu
                        ? null
                        : (secildi) => setState(() {
                            if (secildi ?? false) {
                              _turler.add(t.key);
                            } else {
                              _turler.remove(t.key);
                            }
                          }),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
