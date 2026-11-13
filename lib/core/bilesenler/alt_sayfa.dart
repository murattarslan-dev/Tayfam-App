import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Kısa işler için alttan açılan sayfa (2026-11-13 yeniden tasarım): tayfa
/// menüsü, tayfa değiştirme, "Oluştur", üye işlemleri, yeni davet linki.
/// Uzun ekranlar (tayfa ayarları ve alt ekranları) tam ekran açılır.
///
/// Sayfa kök navigator'da açılır; gezinme çubuğunun da üstünü örter.
/// Tutamak gösterilir, yükseklik içeriğe göre ayarlanır, alt kenarda
/// sistem boşluğu bırakılır.
Future<T?> altSayfaAc<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: builder,
  );
}

/// Alttan sayfanın içerik iskeleti: başlık ve satırlar, kaydırılabilir.
/// Kenar boşluğu tasarımdaki gibi 16 px; alt kenarda 24 px.
class AltSayfaIcerigi extends StatelessWidget {
  const AltSayfaIcerigi({
    super.key,
    required this.children,
    this.baslik,
    this.ust,
  });

  /// Sayfanın başlığı; ekran okuyucuda başlık olarak okunur.
  final String? baslik;

  /// Başlık yerine gösterilen özel üst bölüm (ör. üye işlemlerinde avatar
  /// ve ad).
  final Widget? ust;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final baslik = this.baslik;
    final ust = this.ust;
    // Sayfalar kısa olduğu için bütün satırlar bir kerede kurulur; uzun
    // yazı ölçeğinde içerik kayar.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        0,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (ust != null)
          ust
        else if (baslik != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s8,
              0,
              TayfamSpacing.s8,
              TayfamSpacing.s12,
            ),
            child: Semantics(
              header: true,
              child: Text(baslik, style: context.yazi.headlineSmall),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
