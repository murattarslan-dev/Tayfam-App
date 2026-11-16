import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/bildirim_listesi_notifier.dart';

/// Satır içi işlemden sonra düğmelerin yerinde görünen sonuç (karar 2).
enum SatirIciSonuc {
  /// Arkadaşlık isteği kabul edildi: "Artık arkadaşsınız".
  arkadasOldunuz,

  /// Davet kabul edildi, üyelik etkin: "Katıldın".
  katildin,

  /// Davet kabul edildi, onaylı tayfada yönetimin onayını bekliyor:
  /// "İsteğin gönderildi".
  istekGonderildi,

  /// İstek ya da davet reddedildi: "Reddedildi".
  reddedildi,

  /// Arkadaş önerisi kapatıldı: "Bir daha önerilmeyecek".
  oneriKapatildi,
}

/// Satır içi işlemlerin durumu: sonuçlanan bildirimler ve süren işlemler.
@immutable
final class SatirIciDurumu {
  const SatirIciDurumu({this.sonuclar = const {}, this.isleniyor = const {}});

  /// Bildirim kimliği → sonuç.
  final Map<String, SatirIciSonuc> sonuclar;

  /// İşlemi süren bildirimlerin kimlikleri (düğmeler devre dışı).
  final Set<String> isleniyor;

  SatirIciDurumu _degistir({
    Map<String, SatirIciSonuc>? sonuclar,
    Set<String>? isleniyor,
  }) => SatirIciDurumu(
    sonuclar: sonuclar ?? this.sonuclar,
    isleniyor: isleniyor ?? this.isleniyor,
  );
}

/// Bildirim satırındaki Reddet / Kabul et / Katıl (2026-11-13 tasarım:
/// Bildirimler, karar 2) ve arkadaş önerisindeki Kapat / Arkadaş ekle
/// (25-arkadas-onerisi, karar 1). İşlem arkadaşlık özelliğinin uçlarıyla
/// yapılır ([bildirimYanitlariProvider]); başarıda bildirim okundu
/// işaretlenir ve sonuç düğmelerin yerinde görünür.
///
/// Sonuç yalnızca bellektedir ve ekranla birlikte bırakılır (ADR-0006).
/// Arkadaşlık isteği ve davette liste yeniden açılınca düğmeler yine
/// görünür ve sunucu güncel durumu hata olarak bildirir; arkadaş önerisi
/// ise sunucunun `resolution` alanı `pending` olmaktan çıkınca listede hiç
/// görünmez.
class SatirIciNotifier extends Notifier<SatirIciDurumu> {
  @override
  SatirIciDurumu build() {
    ref.watch(oturumDurumuProvider);
    return const SatirIciDurumu();
  }

  /// Arkadaşlık isteğini ya da tayfa davetini kabul eder; arkadaş
  /// önerisinde istek gönderir ("Arkadaş ekle"). Başarıda `null`, aksi
  /// halde gösterilecek hata.
  Future<Object?> kabulEt(Notification bildirim) =>
      _calistir(bildirim, (yanitlar) async {
        final kisi = bildirimKisisi(bildirim);
        final tayfa = davetTayfasi(bildirim);
        final islem = satirIciIslem(bildirim);
        if (islem == SatirIciIslem.arkadaslik && kisi != null) {
          final hata = await yanitlar.istegiKabulEt(kisi);
          return (hata, SatirIciSonuc.arkadasOldunuz);
        }
        if (islem == SatirIciIslem.oneri && kisi != null) {
          final yanit = await yanitlar.oneriyiEkle(kisi);
          final sonuc = yanit.arkadas
              ? SatirIciSonuc.arkadasOldunuz
              : SatirIciSonuc.istekGonderildi;
          return (yanit.hata, sonuc);
        }
        if (islem == SatirIciIslem.davet && tayfa != null) {
          final yanit = await yanitlar.davetiKabulEt(tayfa);
          final sonuc = yanit.etkin
              ? SatirIciSonuc.katildin
              : SatirIciSonuc.istekGonderildi;
          return (yanit.hata, sonuc);
        }
        return (null, null);
      });

  /// Arkadaşlık isteğini ya da tayfa davetini reddeder, arkadaş önerisini
  /// kapatır (karşı tarafa bildirilmez). Başarıda `null`, aksi halde
  /// gösterilecek hata.
  Future<Object?> reddet(Notification bildirim) =>
      _calistir(bildirim, (yanitlar) async {
        final kisi = bildirimKisisi(bildirim);
        final tayfa = davetTayfasi(bildirim);
        final islem = satirIciIslem(bildirim);
        if (islem == SatirIciIslem.oneri && kisi != null) {
          final hata = await yanitlar.oneriyiKapat(kisi);
          return (hata, SatirIciSonuc.oneriKapatildi);
        }
        Object? hata;
        if (islem == SatirIciIslem.arkadaslik && kisi != null) {
          hata = await yanitlar.istegiReddet(kisi);
        } else if (islem == SatirIciIslem.davet && tayfa != null) {
          hata = await yanitlar.davetiReddet(tayfa);
        } else {
          return (null, null);
        }
        return (hata, SatirIciSonuc.reddedildi);
      });

  Future<Object?> _calistir(
    Notification bildirim,
    Future<(Object?, SatirIciSonuc?)> Function(BildirimYanitlari) islem,
  ) async {
    final id = bildirim.id;
    if (state.isleniyor.contains(id) || state.sonuclar.containsKey(id)) {
      return null;
    }
    state = state._degistir(isleniyor: {...state.isleniyor, id});
    final (hata, sonuc) = await islem(ref.read(bildirimYanitlariProvider));
    if (!ref.mounted) return hata;
    state = state._degistir(
      isleniyor: {...state.isleniyor}..remove(id),
      sonuclar: hata == null && sonuc != null
          ? {...state.sonuclar, id: sonuc}
          : null,
    );
    if (hata == null && sonuc != null) {
      unawaited(ref.read(bildirimListesiProvider.notifier).okunduIsaretle(id));
    }
    return hata;
  }
}

/// Bildirim satırlarındaki işlemlerin durumu; ekran kapanınca bırakılır.
final satirIciProvider =
    NotifierProvider.autoDispose<SatirIciNotifier, SatirIciDurumu>(
      SatirIciNotifier.new,
      name: 'satirIciProvider',
    );
