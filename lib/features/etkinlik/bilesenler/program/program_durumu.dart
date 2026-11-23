import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınırlar (`EventScheduleItemRequest`).
const int programBasligiEnCok = 120;
const int programNotuEnCok = 500;

/// Madde saatleri etkinliğin başlangıcından en çok bu kadar önce,
/// bitişinden en çok bu kadar sonra olabilir.
const Duration programPayi = Duration(days: 1);

int _uzunluk(String metin) => metin.runes.length;

/// Program formundaki bir alanın hatası.
enum ProgramHatasi { baslik, not, baslangic, bitis }

/// Madde saatlerinin girilebileceği en erken an ([etkinlik]'in
/// başlangıcından [programPayi] önce).
DateTime programEnErken(Event etkinlik) =>
    etkinlik.startsAt.subtract(programPayi);

/// Madde saatlerinin girilebileceği en geç an ([etkinlik]'in bitişinden
/// [programPayi] sonra).
DateTime programEnGec(Event etkinlik) => etkinlik.endsAt.add(programPayi);

/// Madde formu. Saatler gerçek anlardır (cihazın saatinde seçilir) ve
/// sunucuya UTC gider (üretilen model çevirir). Boş not gönderilmez;
/// düzenlemede gönderilmeyen bitiş ve not sunucuda kalkar.
///
/// Hata yoksa istek, varsa yalnızca hatalar döner. Son sözü sunucu söyler
/// (`invalid-request`).
({EventScheduleItemRequest? istek, Set<ProgramHatasi> hatalar}) programIstegi({
  required Event etkinlik,
  required String baslik,
  required DateTime? baslangic,
  DateTime? bitis,
  String not = '',
}) {
  final hatalar = <ProgramHatasi>{};
  final b = baslik.trim();
  if (b.isEmpty || _uzunluk(b) > programBasligiEnCok) {
    hatalar.add(ProgramHatasi.baslik);
  }
  final n = not.trim();
  if (_uzunluk(n) > programNotuEnCok) hatalar.add(ProgramHatasi.not);
  final enErken = programEnErken(etkinlik);
  final enGec = programEnGec(etkinlik);
  if (baslangic == null ||
      baslangic.isBefore(enErken) ||
      baslangic.isAfter(enGec)) {
    hatalar.add(ProgramHatasi.baslangic);
  }
  if (bitis != null &&
      ((baslangic != null && !bitis.isAfter(baslangic)) ||
          bitis.isAfter(enGec))) {
    hatalar.add(ProgramHatasi.bitis);
  }
  if (hatalar.isNotEmpty || baslangic == null) {
    return (istek: null, hatalar: hatalar);
  }
  return (
    istek: EventScheduleItemRequest(
      startsAt: baslangic.toUtc(),
      endsAt: bitis?.toUtc(),
      title: b,
      note: n.isEmpty ? null : n,
    ),
    hatalar: const {},
  );
}

/// Yeni maddenin önerilen başlangıcı: program boşsa etkinliğin
/// başlangıcı, değilse son maddenin bitişi (yoksa başlangıcı).
DateTime programOnerilenBaslangic(EventSchedule program, Event etkinlik) {
  if (program.items.isEmpty) return etkinlik.startsAt;
  final son = program.items.last;
  return son.endsAt ?? son.startsAt;
}

/// [simdi] süren maddeler (yalnızca istemci hesabı; sunucu "şimdi" bilgisi
/// vermez). Madde başlamışsa ve bitişinden (yoksa daha geç başlayan
/// sonraki maddeden, o da yoksa etkinliğin bitişinden) önceyse sürüyor
/// sayılır; aynı saatte başlayan maddeler birlikte sürer. İptal edilen
/// etkinlikte madde sürmez. Maddeler başlangıç saatine göre sıralıdır.
Set<String> surenMaddeler(
  EventSchedule program,
  Event etkinlik,
  DateTime simdi,
) {
  if (iptalEdildi(etkinlik)) return const {};
  final maddeler = program.items;
  final sonuc = <String>{};
  for (final (sira, madde) in maddeler.indexed) {
    if (madde.startsAt.isAfter(simdi)) continue;
    final bitis =
        madde.endsAt ?? _sonrakiBaslangic(maddeler, sira) ?? etkinlik.endsAt;
    if (simdi.isBefore(bitis)) sonuc.add(madde.id);
  }
  return sonuc;
}

DateTime? _sonrakiBaslangic(List<EventScheduleItem> maddeler, int sira) {
  final baslangic = maddeler[sira].startsAt;
  for (final sonraki in maddeler.skip(sira + 1)) {
    if (sonraki.startsAt.isAfter(baslangic)) return sonraki.startsAt;
  }
  return null;
}

/// Bir etkinliğin bir program bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef ProgramKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Programın yeniden okunmasını gerektiren hatalar: program başkasının
/// işlemiyle, etkinliğin durumuyla ya da yetkiyle değişmiş.
const Set<ProblemType> _bayatProgramHatalari = {
  ProblemType.eventItemNotFound,
  ProblemType.eventLimit,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Program akışı bileşeninin durumu (`GET …/components/{component_key}/
/// schedule`; Tayfam-Api #247), çağıranın gördüğü haliyle. Bölüm açıkken
/// canlıdır (ADR-0024 §5): program ya da etkinliğin durumu değişince
/// REST'ten yeniden okunur.
///
/// Yazan her uç programın güncel halini döner; durum onunla değişir.
/// Başlık ve not yalnızca bellekte tutulur ve loglanmaz (ADR-0006). Yetki
/// sunucudadır; istemci yalnızca düğmeleri sadeleştirir (kesin kural 5).
class ProgramNotifier extends AsyncNotifier<EventSchedule> {
  ProgramNotifier(this.kimlik);

  final ProgramKimligi kimlik;

  @override
  Future<EventSchedule> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .program(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu bölümde gösterilir.
    }
  }

  /// Programa madde ekler (organizatör, moderatör, yönetici).
  Future<Object?> ekle(EventScheduleItemRequest istek) => _yaz(
    (d) => d.programMaddesiEkle(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      istek,
    ),
  );

  /// Maddenin bütün değerlerini değiştirir.
  Future<Object?> guncelle(String maddeId, EventScheduleItemRequest istek) =>
      _yaz(
        (d) => d.programMaddesiniGuncelle(
          kimlik.tayfaId,
          kimlik.etkinlikId,
          kimlik.anahtar,
          maddeId,
          istek,
        ),
      );

  /// Maddeyi programdan çıkarır.
  Future<Object?> cikar(String maddeId) => _yaz(
    (d) => d.programMaddesiniCikar(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      maddeId,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Program bayatlamışsa (madde silinmiş, dolmuş, donmuş,
  /// yetki değişmiş) yeniden okunur.
  Future<Object?> _yaz(
    Future<EventSchedule> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final program = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(program);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatProgramHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir program bileşeninin durumu. Hata otomatik yeniden denenmez.
final programProvider = AsyncNotifierProvider.autoDispose
    .family<ProgramNotifier, EventSchedule, ProgramKimligi>(
      ProgramNotifier.new,
      name: 'programProvider',
      retry: yenidenDenemeYok,
    );
