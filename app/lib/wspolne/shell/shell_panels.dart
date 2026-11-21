import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Which shell panels are open: P1 (drawer), P2 (contact with services) and an
/// app dialog. Hosts live in `RootOverlay`.
@immutable
class ShellPanelsState {
  const ShellPanelsState({
    this.drawerOpen = false,
    this.contactOpen = false,
    this.dialog,
  });

  final bool drawerOpen;
  final bool contactOpen;

  /// Builder of the open app dialog (null = none). See [ShellPanels.openDialog].
  final WidgetBuilder? dialog;

  bool get anyOpen => drawerOpen || contactOpen || dialog != null;

  ShellPanelsState copyWith({
    bool? drawerOpen,
    bool? contactOpen,
    Object? dialog = _keep,
  }) {
    return ShellPanelsState(
      drawerOpen: drawerOpen ?? this.drawerOpen,
      contactOpen: contactOpen ?? this.contactOpen,
      dialog: identical(dialog, _keep) ? this.dialog : dialog as WidgetBuilder?,
    );
  }

  static const Object _keep = Object();
}

class ShellPanels extends Notifier<ShellPanelsState> {
  @override
  ShellPanelsState build() => const ShellPanelsState();

  void openDrawer() {
    // The drawer covers the composer: close the keyboard with it.
    FocusManager.instance.primaryFocus?.unfocus();
    state = state.copyWith(drawerOpen: true);
  }
  void closeDrawer() => state = state.copyWith(drawerOpen: false);
  void openContactPanel() => state = state.copyWith(contactOpen: true);
  void closeContactPanel() => state = state.copyWith(contactOpen: false);

  /// Shows an app dialog in the shell layer between P2 and SOS (spec layer 4).
  /// Dialogs shown through the `Navigator` would end up below P1/P2.
  void openDialog(WidgetBuilder builder) => state = state.copyWith(dialog: builder);
  void closeDialog() => state = state.copyWith(dialog: null);

  /// Android system Back: closes the topmost layer (dialog, then P2, then P1).
  /// Returns false when nothing was open.
  bool closeTopmost() {
    if (state.dialog != null) {
      closeDialog();
    } else if (state.contactOpen) {
      closeContactPanel();
    } else if (state.drawerOpen) {
      closeDrawer();
    } else {
      return false;
    }
    return true;
  }
}

final shellPanelsProvider = NotifierProvider<ShellPanels, ShellPanelsState>(
  ShellPanels.new,
);
