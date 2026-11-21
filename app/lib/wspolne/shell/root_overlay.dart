import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../alarm/panel/contact_panel.dart';
import '../../app_router.dart';
import '../../czat/drawer/chat_drawer.dart';
import 'cpr_indicator.dart';
import 'cpr_state.dart';
import 'nav_island.dart';
import 'panel_host.dart';
import 'shell_panels.dart';
import 'sos_button.dart';

/// Which controls the shell shows for a location.
enum ShellScreen { onboarding, chat, other }

ShellScreen shellScreenForPath(String path) {
  if (path == onboardingRoutePath) return ShellScreen.onboarding;
  if (path == chatRoutePath) return ShellScreen.chat;
  return ShellScreen.other;
}

const _edgeMargin = 16.0;
const _minTop = 48.0;
const _edgeSwipeWidth = 20.0;

/// App-wide overlay rendered by `MaterialApp.router(builder: ...)` above the
/// `Navigator` (spec: README "Elementy globalne").
///
/// Layer order, bottom to top (Stack children order):
///  1. [child] (the Navigator: screen content, pinned CPR, composer)
///  2. left-edge swipe strip (E1 only)
///  3. island / Back / CPR indicator
///  4. P1 drawer with dimmed scrim
///  5. P2 contact panel with scrim
///  6. app dialog (see [ShellPanels.openDialog])
///  7. SOS (always topmost of the app layers)
///
/// The overlay ignores `viewInsets`, so the keyboard never moves SOS/island.
class RootOverlay extends ConsumerStatefulWidget {
  const RootOverlay({super.key, required this.child, this.sosLauncher = defaultSosLauncher});

  final Widget child;

  /// Passed to the SOS button (tests inject a fake).
  final UriLauncher sosLauncher;

  @override
  ConsumerState<RootOverlay> createState() => _RootOverlayState();
}

class _RootOverlayState extends ConsumerState<RootOverlay> with WidgetsBindingObserver {
  late GoRouter _router;
  GoRouter? _routerOrNull;
  String _path = chatRoutePath;

  @override
  void initState() {
    super.initState();
    // Registered in initState of this ancestor, i.e. before the Router below
    // registers its own back-button callback, so panels are closed first.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = ref.read(appRouterProvider);
    if (!identical(router, _routerOrNull)) {
      _routerOrNull?.routerDelegate.removeListener(_onRoute);
      _routerOrNull = router;
      _router = router;
      router.routerDelegate.addListener(_onRoute);
      _path = _currentPath();
    }
  }

  String _currentPath() {
    final config = _router.routerDelegate.currentConfiguration;
    return config.isEmpty ? chatRoutePath : config.uri.path;
  }

  void _onRoute() {
    final path = _currentPath();
    if (path == _path) return;
    // setState during a build is not allowed; routes notify from the delegate.
    scheduleMicrotask(() {
      if (!mounted) return;
      setState(() => _path = path);
      // P1 belongs to the chat; leaving E1 closes it.
      if (path != chatRoutePath) ref.read(shellPanelsProvider.notifier).closeDrawer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routerOrNull?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // Closes a panel/dialog first; false lets the router pop the screen.
    return ref.read(shellPanelsProvider.notifier).closeTopmost();
  }

  void _back() {
    if (_router.canPop()) {
      _router.pop();
    } else {
      _router.go(chatRoutePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panels = ref.watch(shellPanelsProvider);
    // Tell the platform the framework handles Back while a panel is open.
    // Without this, Android (predictive back) sees an unpoppable root
    // Navigator and finishes the activity without calling didPopRoute.
    ref.listen(shellPanelsProvider.select((s) => s.anyOpen), (_, open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NavigationNotification(canHandlePop: open || _router.canPop()).dispatch(context);
      });
    });
    final notifier = ref.read(shellPanelsProvider.notifier);
    final cprActive = ref.watch(cprActiveProvider);
    final screen = shellScreenForPath(_path);
    final top = MediaQuery.paddingOf(context).top;
    final topInset = top + 8 > _minTop ? top + 8 : _minTop;
    final showCpr = cprActive && screen == ShellScreen.other;

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<NavigationNotification>(
            // The Navigator reports "cannot pop" on every history change; while
            // a panel is open replace that with "can handle" (see above).
            onNotification: (n) {
              if (n.canHandlePop || !ref.read(shellPanelsProvider).anyOpen) return false;
              const NavigationNotification(canHandlePop: true).dispatch(context);
              return true;
            },
            child: widget.child,
          ),
        ),
        // Everything below ignores viewInsets (keyboard).
        Positioned.fill(
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  if (screen == ShellScreen.chat && !panels.drawerOpen)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _edgeSwipeWidth,
                      child: _EdgeSwipe(onSwipe: notifier.openDrawer),
                    ),
                  if (screen == ShellScreen.chat)
                    Positioned(
                      left: _edgeMargin,
                      top: topInset,
                      child: NavIsland(
                        onMenu: notifier.openDrawer,
                        onMap: () => _router.go(mapRoutePath),
                      ),
                    ),
                  if (screen == ShellScreen.other)
                    Positioned(
                      left: _edgeMargin,
                      top: topInset,
                      child: BzBackButton(onBack: _back),
                    ),
                  if (showCpr)
                    Positioned(
                      // Leaves room for Back (left) and SOS (right).
                      left: _edgeMargin + 48 + 8,
                      right: _edgeMargin + SosButton.size + 8,
                      top: topInset,
                      child: Center(
                        child: CprIndicator(onTap: () => _router.go(chatRoutePath)),
                      ),
                    ),
                  Positioned.fill(
                    child: PanelHost(
                      key: const Key('panel-drawer'),
                      open: panels.drawerOpen,
                      edge: PanelEdge.left,
                      onClose: notifier.closeDrawer,
                      child: const ChatDrawer(),
                    ),
                  ),
                  Positioned.fill(
                    child: PanelHost(
                      key: const Key('panel-contact'),
                      open: panels.contactOpen,
                      edge: PanelEdge.bottom,
                      onClose: notifier.closeContactPanel,
                      child: const ContactPanel(),
                    ),
                  ),
                  if (panels.dialog != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: notifier.closeDialog,
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.scrim,
                          child: Center(child: Builder(builder: panels.dialog!)),
                        ),
                      ),
                    ),
                  Positioned(
                    right: _edgeMargin,
                    top: topInset,
                    child: SosButton(launcher: widget.sosLauncher),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Invisible strip on the left edge of E1: a swipe to the right opens P1.
class _EdgeSwipe extends StatefulWidget {
  const _EdgeSwipe({required this.onSwipe});

  final VoidCallback onSwipe;

  @override
  State<_EdgeSwipe> createState() => _EdgeSwipeState();
}

class _EdgeSwipeState extends State<_EdgeSwipe> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        if (_dx > 40 || (d.primaryVelocity ?? 0) > 300) widget.onSwipe();
        _dx = 0;
      },
      onHorizontalDragCancel: () => _dx = 0,
    );
  }
}
