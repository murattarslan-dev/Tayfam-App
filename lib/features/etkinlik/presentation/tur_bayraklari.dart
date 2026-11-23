import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinliğin türü (oluşturulduğu sürümüyle) `album_notice` bayraklı mı
/// (istemci ADR-0031 §6). Tanım elde yoksa (katalog gelmedi ya da okunamadı)
/// izin yine sorulur: onaysız yüklemeyi sunucu `album-consent-required` ile
/// reddeder; bayraksız türde `consent_ack` yok sayılır. Katalog hiç
/// okunmadıysa okuması başlatılır.
///
/// Yalnızca `build` içinde çağrılır (katalog izlenir).
bool albumIzniSorulur(WidgetRef ref, Event etkinlik) {
  final tanim = turTaniminiIzle(
    ref,
    etkinlik.type,
    surum: etkinlik.typeVersion,
  );
  if (tanim == null) {
    if (ref.read(katalogProvider).value == null) {
      final katalog = ref.read(katalogProvider.notifier);
      // Derleme sırasında durum değiştirilmez; bir sonraki mikro görevde.
      unawaited(Future<void>.microtask(katalog.gerekli));
    }
    return true;
  }
  return tanim.definition.flags?.albumNotice ?? false;
}

/// `album_notice` bayraklı türde albüme yüklemeden önceki izin onayı
/// (istemci ADR-0031 §6): "Evet, izin aldım" ile `true`. Her yüklemede
/// sorulur; cevap hiçbir yere yazılmaz ("bir daha sorma" yok). Pencerenin
/// dışına dokunmak ya da geri tuşu "Vazgeç" sayılır.
Future<bool> albumIzniOnayi(BuildContext context) async {
  final m = AppLocalizations.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(m.bayrak_album_izin_baslik),
      scrollable: true,
      content: Text(m.bayrak_album_izin_metni),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.bayrak_album_izin_onay),
        ),
      ],
    ),
  );
  return onay ?? false;
}

/// Katılımcı listesi okunurken sunucu `attendees-hidden` döndü mü: türü
/// `sensitive_attendance` bayraklı etkinlikte listeyi yalnızca organizatör,
/// moderatör ve yönetici alır (Tayfam-Api #257). Yetkiye istemci karar
/// vermez; listeyi ister ve bu cevapta yalnızca sayıları gösterir.
bool katilimcilarGizli(Object? hata) =>
    hata is ApiProblem && hata.type == ProblemType.attendeesHidden;
