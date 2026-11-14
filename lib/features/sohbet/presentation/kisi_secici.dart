import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanal_kisileri.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Seçili kişi kanalı için kişi seçiciyi açar (2026-11-13 tasarım:
/// Kanal-Kisi-Sec). Seçilen kişilerin kimlikleri döner; vazgeçilirse
/// `null`.
///
/// - [secili] başta seçili gelenlerdir (yeni kanalda önceki seçim).
/// - [kanalda] zaten kanalda olanlardır ([ekleme]'de seçili ve pasif
///   görünür, sonuca girmez).
/// - Kanalı açan (sen) her zaman içeridedir; yeni kanalda listenin
///   başında seçili ve pasif durur, sonuca girmez.
/// - Bir seferde en çok [kanalKisiSiniri] kişi seçilir (sözleşme).
Future<List<String>?> kisiSeciciyiAc(
  BuildContext context, {
  required String tayfaId,
  String? kanalAdi,
  List<String> secili = const [],
  Set<String> kanalda = const {},
  bool ekleme = false,
}) => Navigator.of(context).push(
  MaterialPageRoute<List<String>>(
    builder: (_) => KisiSecici(
      tayfaId: tayfaId,
      kanalAdi: kanalAdi,
      secili: secili,
      kanalda: kanalda,
      ekleme: ekleme,
    ),
  ),
);

/// Kişi seçici ekranı.
class KisiSecici extends ConsumerStatefulWidget {
  const KisiSecici({
    super.key,
    required this.tayfaId,
    this.kanalAdi,
    this.secili = const [],
    this.kanalda = const {},
    this.ekleme = false,
  });

  final String tayfaId;
  final String? kanalAdi;
  final List<String> secili;
  final Set<String> kanalda;

  /// Var olan kanala kişi ekleniyor.
  final bool ekleme;

  @override
  ConsumerState<KisiSecici> createState() => _KisiSeciciState();
}

class _KisiSeciciState extends ConsumerState<KisiSecici> {
  late final List<String> _secilenler = [...widget.secili];
  final TextEditingController _arama = TextEditingController();
  String _sorgu = '';

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  void _degistir(String kisi) {
    setState(() {
      if (_secilenler.remove(kisi)) return;
      if (_secilenler.length >= kanalKisiSiniri) {
        final m = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(m.sohbet_kisi_sinir(kanalKisiSiniri))),
          );
        return;
      }
      _secilenler.add(kisi);
    });
  }

  bool _uyuyor(Map<String, KullaniciAdi> adlar, String kisi) {
    final sorgu = turkceKucukHarf(_sorgu.trim());
    if (sorgu.isEmpty) return true;
    final ad = adlar[kisi]?.ad;
    return ad != null && turkceKucukHarf(ad).contains(sorgu);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = kanalUyeAdaylariProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final ben = ref.watch(kendiKimligimProvider).value;
    final adlar = ref.watch(kullaniciAdlariProvider);
    final liste = durum.value;
    final adaylar = [
      for (final u in liste?.ogeler ?? const <Membership>[])
        if (u.userId != ben) u,
    ];
    // Arama yüklenen üyelerin adlarında yapılır; adlar önceden istenir.
    final notifier = ref.read(kullaniciAdlariProvider.notifier);
    for (final u in adaylar) {
      notifier.iste(u.userId);
    }
    final gorunen = [
      for (final u in adaylar)
        if (_uyuyor(adlar, u.userId)) u,
    ];
    final sayi = _secilenler.length;
    final kanalAdi = widget.kanalAdi;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.sohbet_kitle_kisi_sec),
            if (kanalAdi != null && kanalAdi.isNotEmpty)
              Text(
                kanalAdi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s24,
              ),
              children: [
                TextField(
                  controller: _arama,
                  textInputAction: TextInputAction.search,
                  onChanged: (deger) => setState(() => _sorgu = deger),
                  decoration: InputDecoration(
                    hintText: m.sohbet_kisi_ara,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                if (_secilenler.isNotEmpty) ...[
                  const SizedBox(height: TayfamSpacing.s12),
                  _SecilenlerSatiri(
                    secilenler: _secilenler,
                    onKaldir: _degistir,
                  ),
                ],
                if (!widget.ekleme) ...[
                  const SizedBox(height: TayfamSpacing.s12),
                  Text(
                    m.sohbet_kisi_bilgi,
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinGovde,
                    ),
                  ),
                ],
                const SizedBox(height: TayfamSpacing.s12),
                if (liste == null && durum.error != null) ...[
                  HataSatiri.hatadan(durum.error!),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BaglantiEylemi(
                      etiket: m.sohbet_tekrar_dene,
                      onPressed: () => ref.invalidate(saglayici),
                    ),
                  ),
                ] else if (liste == null)
                  const Center(child: TayfamYukleniyor(gecikmeli: true))
                else ...[
                  ListeKarti(
                    children: [
                      if (!widget.ekleme && ben != null && _sorgu.isEmpty)
                        _KisiSecimSatiri(
                          kisi: ben,
                          altMetin: m.sohbet_kisi_acan_icerde,
                          secili: true,
                          onDegis: null,
                        ),
                      for (final u in gorunen)
                        _KisiSecimSatiri(
                          kisi: u.userId,
                          altMetin: widget.kanalda.contains(u.userId)
                              ? m.sohbet_kisi_kanalda
                              : rolMetni(m, u.role),
                          secili:
                              widget.kanalda.contains(u.userId) ||
                              _secilenler.contains(u.userId),
                          onDegis: widget.kanalda.contains(u.userId)
                              ? null
                              : () => _degistir(u.userId),
                        ),
                    ],
                  ),
                  if (gorunen.isEmpty && _sorgu.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(TayfamSpacing.s8),
                      child: Text(
                        m.sohbet_kisi_bos,
                        style: context.yazi.bodyMedium?.copyWith(
                          color: r.metinGovde,
                        ),
                      ),
                    ),
                  if (liste.dahaHatasi case final hata?)
                    HataSatiri.hatadan(hata),
                  if (liste.dahaYukleniyor)
                    const Center(child: TayfamYukleniyor())
                  else if (liste.dahaVar)
                    Center(
                      child: BaglantiEylemi(
                        etiket: m.sohbet_daha_fazla,
                        onPressed: () =>
                            unawaited(ref.read(saglayici.notifier).dahaFazla()),
                      ),
                    ),
                ],
              ],
            ),
          ),
          SeciciAltEylemi(
            child: BirincilEylem(
              etiket: widget.ekleme
                  ? m.sohbet_kisi_ekle_onay(sayi)
                  : m.sohbet_kisi_devam(sayi),
              onPressed: widget.ekleme && sayi == 0
                  ? null
                  : () => Navigator.of(context).pop(List.of(_secilenler)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üyenin rol metni; üyede metin yoktur.
String? rolMetni(AppLocalizations m, Role rol) => switch (rol) {
  Role.admin => m.yonetim_rol_admin,
  Role.moderator => m.yonetim_rol_moderator,
  _ => null,
};

/// Seçici ekranlarının altındaki sabit eylem alanı (çizgiyle ayrılır;
/// etkinlik seçici de kullanır).
class SeciciAltEylemi extends StatelessWidget {
  const SeciciAltEylemi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: child,
        ),
      ),
    );
  }
}

/// Seçilen kişiler: ilk üçü adıyla (dokununca seçimden çıkar), kalanı
/// "+N".
class _SecilenlerSatiri extends ConsumerWidget {
  const _SecilenlerSatiri({required this.secilenler, required this.onKaldir});

  final List<String> secilenler;
  final ValueChanged<String> onKaldir;

  static const int _gosterilen = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final kalan = secilenler.length - _gosterilen;
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final kisi in secilenler.take(_gosterilen))
          InputChip(
            avatar: KimlikAvatari(
              kullaniciId: kisi,
              cap: TayfamSizes.avatarYigini,
            ),
            label: Text(kisiAdi(m, ref, kisi)),
            onDeleted: () => onKaldir(kisi),
          ),
        if (kalan > 0)
          Text(
            m.sohbet_kisi_fazlasi(kalan),
            style: context.yazi.labelLarge?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
      ],
    );
  }
}

/// Kişi seçicideki satır: kişi ve sağda onay kutusu. [onDegis] `null`
/// ise pasif (kanalı açan ya da zaten kanalda).
class _KisiSecimSatiri extends StatelessWidget {
  const _KisiSecimSatiri({
    required this.kisi,
    required this.altMetin,
    required this.secili,
    required this.onDegis,
  });

  final String kisi;
  final String? altMetin;
  final bool secili;
  final VoidCallback? onDegis;

  @override
  Widget build(BuildContext context) {
    final onDegis = this.onDegis;
    return MergeSemantics(
      child: ListeKartiSatiri(
        onTap: onDegis,
        child: KisiSatiriIcerigi(
          kisi: kisi,
          altMetin: altMetin,
          sag: Checkbox(
            value: secili,
            onChanged: onDegis == null ? null : (_) => onDegis(),
          ),
        ),
      ),
    );
  }
}
