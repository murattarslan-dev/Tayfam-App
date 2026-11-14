import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';

/// Girişten sonra profil tamamlama formunu açan kabuk katmanı (issue #186;
/// `shell/kayitlar.dart`'taki `kabukKatmanlariProvider` ile kabuğun
/// çevresine eklenir).
///
/// Kabuk açılınca hesap okunur (`GET /v1/me/account`); hesabın
/// `profile_completion_pending` alanı `true` ise form (`/profil-tamamla`)
/// kabuğun üstünde bir kez açılır. Erteleme ve hangi alanların sorulacağı
/// sunucudadır. Kabuk açık kaldıkça form yeniden açılmaz; çıkış yapılıp
/// yeniden girilince kabuk yeniden kurulur ve sunucu yine karar verir.
/// Hesap okunamazsa form açılmaz.
class ProfilTamamlamaIstemi extends ConsumerStatefulWidget {
  const ProfilTamamlamaIstemi({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProfilTamamlamaIstemi> createState() =>
      _ProfilTamamlamaIstemiState();
}

class _ProfilTamamlamaIstemiState extends ConsumerState<ProfilTamamlamaIstemi> {
  /// Hesap dinleyicisini kapatır; dinleyici hesabı kabuk açıkken canlı
  /// tutar (`autoDispose`).
  void Function()? _dinlemeyiBirak;
  bool _acildi = false;

  @override
  void initState() {
    super.initState();
    _dinlemeyiBirak = ref
        .listenManual(
          hesapAyarlariProvider,
          (_, durum) => _denetle(durum.value),
          fireImmediately: true,
        )
        .close;
  }

  @override
  void dispose() {
    _dinlemeyiBirak?.call();
    super.dispose();
  }

  void _denetle(Account? hesap) {
    if (_acildi || hesap == null || !hesap.profileCompletionPending) return;
    _acildi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.push(Adresler.profilTamamla));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
