import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bridges existing screen constructors to GoRouter while preserving the
/// original Navigator behaviour and its returned values.
extension LegacyGoNavigation on BuildContext {
  Future<T?> pushLegacy<T>(Widget page) => push<T>('/legacy', extra: page);

  void goLegacy(Widget page) => go('/legacy', extra: page);
}
