import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_theme.dart';
import '../wspolne/theme/top_fade.dart';
import 'profile_form.dart';
import 'profile_model.dart';
import 'profile_store.dart';

/// E4 `edit`: autosave 500 ms after the last valid change, "Zapisano" toast.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Timer? _debounce;
  HouseholdProfile? _pending;
  late final ProfileNotifier _notifier = ref.read(profileProvider.notifier);
  late final ScaffoldMessengerState _messenger = ScaffoldMessenger.of(context);

  void _onChanged(HouseholdProfile p) {
    _pending = p;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    try {
      await _notifier.save(p);
      _messenger.showSnackBar(
        const SnackBar(
          content: Text('Zapisano'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {
      _messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać. Spróbuj ponownie.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_pending != null) unawaited(_flush());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final profile = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: bz.bg000,
      body: Stack(
        children: [
          SafeArea(
            child: profile.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text(
                  'Nie mogę odczytać profilu. Możesz utworzyć go od nowa.',
                ),
              ),
              data: (p) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 32),
                children: [
                  Text('Profil domu', style: bz.title),
                  const SizedBox(height: 8),
                  Text(
                    'Zostaje w telefonie. Wysyłasz go tylko ty, np. SMS-em do bliskich. Nie ma konta ani serwera.',
                    style: bz.caption,
                  ),
                  if (p.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Profil jest pusty. Uzupełnij go, żeby odpowiedzi dotyczyły twojej rodziny.',
                      style: bz.chat,
                    ),
                  ],
                  ProfileForm(initial: p, onChanged: _onChanged),
                ],
              ),
            ),
          ),
          const TopFade(),
        ],
      ),
    );
  }
}
