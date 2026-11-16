import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/zaman/takvim_gunu.dart';
import 'package:tayfam/features/arkadas/application/islem.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';

/// "Boşum" (Tayfam-Api ADR-0029; tasarım 26-bosum). Boş vakit kişinin
/// kendi girdiği gün ve dilimlerdir; tüm arkadaşları görür, bildirim
/// gitmez. Günler ve not yalnızca bellektedir (ADR-0006), log'a yazılmaz
/// (kesin kural 3: kişinin programıdır).

/// Bugünden sonra en çok kaç gün ileri girilebilir (sözleşme: bugün + 30).
const int bosGunEnCokIleri = 30;

/// Rozetin penceresi: bugün dahil önümüzdeki 7 takvim günü (sözleşme).
const int bosRozetPenceresi = 7;

/// Notun en çok uzunluğu (sözleşme: 60 karakter). Sunucu Unicode kod
/// noktası sayar; istemci de [String.runes] ile sayar ki birleşik emoji
/// sınırı sessizce aşmasın.
const int bosNotEnCok = 60;

/// Notta sözleşmenin yasakladığı karakterler: kontrol karakterleri (Cc,
/// satır sonu dahil), satır/paragraf ayırıcı, yön kontrolleri ve görünmez
/// karakterler (U+00AD, U+180E, U+200B, U+200C, U+2060–U+206F, U+FEFF,
/// U+FFF9–U+FFFB). Emoji birleştiricisi U+200D serbesttir.
final RegExp bosNotYasakKarakter = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u00AD\u061C\u180E\u200B\u200C\u200E\u200F'
  r'\u2028\u2029\u202A-\u202E\u2060-\u206F\uFEFF\uFFF9-\uFFFB]',
  unicode: true,
);

/// Sözleşmedeki sıra: sabah, öğleden sonra, akşam; ya da yalnızca tüm gün.
/// Tanınmayan dilim ([DaySlot.unknown]) gönderilmez.
List<DaySlot> dilimleriSirala(Iterable<DaySlot> dilimler) {
  final kume = dilimler.toSet();
  if (kume.contains(DaySlot.allDay)) return const [DaySlot.allDay];
  return [
    for (final d in const [DaySlot.morning, DaySlot.afternoon, DaySlot.evening])
      if (kume.contains(d)) d,
  ];
}

/// [mevcut] seçime [dilim]'e dokunmanın sonucu: seçiliyse kalkar; "tüm
/// gün" seçilince diğerleri, diğerlerinden biri seçilince "tüm gün"
/// kalkar (sözleşme: `all_day` tek başına).
Set<DaySlot> dilimDegistir(Set<DaySlot> mevcut, DaySlot dilim) {
  if (mevcut.contains(dilim)) return {...mevcut}..remove(dilim);
  if (dilim == DaySlot.allDay) return {DaySlot.allDay};
  return {...mevcut}
    ..remove(DaySlot.allDay)
    ..add(dilim);
}

/// Gönderilecek not: yasak karakterler süzülür, baştaki ve sondaki boşluk
/// kırpılır; boşsa not yoktur.
String? notuHazirla(String ham) {
  final temiz = ham.replaceAll(bosNotYasakKarakter, '').trim();
  return temiz.isEmpty ? null : temiz;
}

/// Arkadaş satırındaki rozetin günü: `next_available` yoksa, tarihi
/// okunamıyorsa, dilimi yoksa ya da gün [bugun] … [bugun] + 6 dışındaysa
/// (liste dünden kalmışsa) `null` ve rozet görünmez.
DateTime? rozetGunu(Friend arkadas, DateTime bugun) {
  final ozet = arkadas.nextAvailable;
  if (ozet == null || dilimleriSirala(ozet.slots).isEmpty) return null;
  final gun = takvimGunuOku(ozet.date);
  if (gun == null) return null;
  if (gun.isBefore(bugun)) return null;
  if (!gun.isBefore(gunKaydir(bugun, bosRozetPenceresi))) return null;
  return gun;
}

/// Ekranda gösterilecek günler: tarihi okunabilen ve dilimi olanlar,
/// eskiden yeniye.
List<AvailabilityDay> gosterilecekGunler(Iterable<AvailabilityDay> gunler) {
  final liste = [
    for (final g in gunler)
      if (takvimGunuOku(g.date) != null && dilimleriSirala(g.slots).isNotEmpty)
        g,
  ]..sort((a, b) => a.date.compareTo(b.date));
  return liste;
}

/// Kendi boş günlerin (`GET /v1/me/availability`). Yalnızca bellektedir;
/// oturum değişince sıfırlanır.
class BosVakitlerimNotifier extends AsyncNotifier<List<AvailabilityDay>> {
  @override
  Future<List<AvailabilityDay>> build() async {
    ref.watch(oturumDurumuProvider);
    final gunler = await ref.watch(arkadasDeposuProvider).bosGunlerim();
    return gosterilecekGunler(gunler);
  }

  /// Ekran yenilemesi; hata durumda kalır.
  Future<void> yenile() async {
    ref.invalidateSelf();
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  /// [gun]'ü [dilimler] ve [not] ile kaydeder (`PUT`, o günün kaydını
  /// bütünüyle değiştirir). Başarıda `null`, aksi halde hata.
  Future<Object?> kaydet(DateTime gun, Set<DaySlot> dilimler, String not) =>
      arkadasIslemi(ref, () => _kaydet(gun, dilimler, not));

  /// [gunler]'i sırayla kaydeder. Bir gün düşerse durur: kaydedilemeyen
  /// ve denenmemiş günler [kalan]da, hata [hata]dadır; başarılı günler
  /// listeye işlenmiştir.
  Future<({List<DateTime> kalan, Object? hata})> cokluKaydet(
    List<DateTime> gunler,
    Set<DaySlot> dilimler,
    String not,
  ) async {
    final sirali = [...gunler]..sort();
    for (final (sira, gun) in sirali.indexed) {
      final hata = await arkadasIslemi(ref, () => _kaydet(gun, dilimler, not));
      if (hata != null) return (kalan: sirali.sublist(sira), hata: hata);
      if (!ref.mounted) break;
    }
    return (kalan: const <DateTime>[], hata: null);
  }

  /// [gun]'ün boş vaktini siler (`DELETE`; yoksa da başarılı).
  Future<Object?> sil(DateTime gun) => arkadasIslemi(ref, () async {
    final metin = takvimGunuMetni(gun);
    await ref.read(arkadasDeposuProvider).bosGunSil(metin);
    if (!ref.mounted) return;
    final liste = state.value;
    if (liste == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData([
      for (final g in liste)
        if (g.date != metin) g,
    ]);
  });

  Future<void> _kaydet(DateTime gun, Set<DaySlot> dilimler, String not) async {
    final sirali = dilimleriSirala(dilimler);
    if (sirali.isEmpty) {
      throw ArgumentError.value(dilimler, 'dilimler', 'boş olamaz');
    }
    final kayit = await ref
        .read(arkadasDeposuProvider)
        .bosGunKaydet(
          takvimGunuMetni(gun),
          AvailabilityInput(slots: sirali, note: notuHazirla(not)),
        );
    if (!ref.mounted) return;
    final liste = state.value;
    if (liste == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(
      gosterilecekGunler([
        for (final g in liste)
          if (g.date != kayit.date) g,
        kayit,
      ]),
    );
  }
}

/// Kendi boş günlerin. Ekranlar arasında (liste, ekleme, profil girişi)
/// paylaşılır; dinleyen kalmayınca bırakılır.
final bosVakitlerimProvider =
    AsyncNotifierProvider.autoDispose<
      BosVakitlerimNotifier,
      List<AvailabilityDay>
    >(
      BosVakitlerimNotifier.new,
      name: 'bosVakitlerimProvider',
      retry: yenidenDenemeYok,
    );

/// Bir arkadaşın boş günleri (`GET /v1/users/{user_id}/availability`).
/// Görünmüyorsa (`user-not-found`: arkadaş değil, engel, hesap yok) hata
/// durumudur; ekran bunları ayırt etmez. Yalnızca bellektedir.
class ArkadasBosGunleriNotifier extends AsyncNotifier<List<AvailabilityDay>> {
  ArkadasBosGunleriNotifier(this.kullaniciId);

  /// Arkadaşın kimliği (sunucudan gelen arkadaş listesinden).
  final String kullaniciId;

  @override
  Future<List<AvailabilityDay>> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(arkadasDeposuProvider);
    try {
      return gosterilecekGunler(await depo.arkadasBosGunleri(kullaniciId));
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      rethrow;
    }
  }
}

/// Arkadaşın boş günleri; alttan sayfa kapanınca bırakılır.
final arkadasBosGunleriProvider = AsyncNotifierProvider.autoDispose
    .family<ArkadasBosGunleriNotifier, List<AvailabilityDay>, String>(
      ArkadasBosGunleriNotifier.new,
      name: 'arkadasBosGunleriProvider',
      retry: yenidenDenemeYok,
    );
