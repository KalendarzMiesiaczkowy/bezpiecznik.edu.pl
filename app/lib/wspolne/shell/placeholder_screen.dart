import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bz_theme.dart';

/// A link shown on a [PlaceholderScreen] (navigates with `context.go`).
class PlaceholderLink {
  const PlaceholderLink(this.label, this.location);

  final String label;
  final String location;
}

/// Temporary screen body. Later tasks replace the route builders in
/// `app_router.dart` with the real screens.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.links = const [],
  });

  final String title;
  final List<PlaceholderLink> links;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Scaffold(
      backgroundColor: bz.bg000,
      body: SafeArea(
        child: Padding(
          // Leaves room for the floating shell controls.
          padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: bz.title),
              const SizedBox(height: 16),
              for (final link in links)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => context.go(link.location),
                    child: Text(link.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
