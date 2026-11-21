import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'czat/templates/template_gallery.dart';
import 'czat/ui/chat_screen.dart';
import 'mapa/map_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'profil/profile_screen.dart';
import 'profil/profile_store.dart';
import 'ustawienia/settings_screen.dart';
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
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: chatRoutePath,
        builder: (context, state) => const ChatScreen(),
        routes: [
          GoRoute(
            path: 'mapa',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: 'ustawienia',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'profil',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      if (kDebugMode)
        GoRoute(path: galleryRoutePath, builder: (context, state) => const GalleryScreen()),
      if (kDebugMode)
        GoRoute(path: templateGalleryRoutePath, builder: (context, state) => const TemplateGalleryScreen()),
    ],
  );
}

/// The app router; tests override it.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Onboarding flag loads async: no redirect while loading; once it resolves
  // to false the router is refreshed and redirects to /onboarding.
  late final GoRouter router;
  router = createAppRouter(needsOnboarding: () => ref.read(onboardingDoneProvider).value == false);
  ref.listen(onboardingDoneProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
