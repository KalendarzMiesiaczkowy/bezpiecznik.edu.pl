import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'wspolne/shell/placeholder_screen.dart';
import 'wspolne/theme/gallery_screen.dart';

/// Key of the app `Navigator`. Dialogs/sheets opened through it stay below
/// the shell overlay (SOS).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

const onboardingRoutePath = '/onboarding';
const chatRoutePath = '/';
const mapRoutePath = '/mapa';
const settingsRoutePath = '/ustawienia';
const profileRoutePath = '/ustawienia/profil';

/// Builds the app router.
///
/// Stack per spec: E1 (chat) is always at the bottom; E2 and E3 are pushed
/// over it (nested routes), E4 over E3.
///
/// [needsOnboarding] is the hook for the first-run logic (task C05): when it
/// returns true every location is redirected to `/onboarding` (E0). The
/// onboarding screen must make it return false before navigating to `/`.
GoRouter createAppRouter({
  bool Function()? needsOnboarding,
  String initialLocation = chatRoutePath,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) {
      final onboarding = needsOnboarding?.call() ?? false;
      final atOnboarding = state.uri.path == onboardingRoutePath;
      if (onboarding && !atOnboarding) return onboardingRoutePath;
      return null;
    },
    routes: [
      GoRoute(
        path: onboardingRoutePath,
        builder: (context, state) => const PlaceholderScreen(title: 'Pierwsze uruchomienie'),
      ),
      GoRoute(
        path: chatRoutePath,
        builder: (context, state) => const PlaceholderScreen(title: 'Czat'),
        routes: [
          GoRoute(
            path: 'mapa',
            builder: (context, state) => const PlaceholderScreen(title: 'Mapa'),
          ),
          GoRoute(
            path: 'ustawienia',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Ustawienia',
              links: [PlaceholderLink('Profil', profileRoutePath)],
            ),
            routes: [
              GoRoute(
                path: 'profil',
                builder: (context, state) => const PlaceholderScreen(title: 'Profil'),
              ),
            ],
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(path: galleryRoutePath, builder: (context, state) => const GalleryScreen()),
    ],
  );
}

/// The app router; tests override it.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
