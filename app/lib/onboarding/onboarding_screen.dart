import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../profil/profile_form.dart';
import '../profil/profile_model.dart';
import '../profil/profile_store.dart';
import '../wspolne/shell/nav_island.dart';
import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import 'location_gateway.dart';

enum OnboardingStep { intro, location, profileAsk, profileForm, done }

/// E0 (MVP): intro -> location -> profile (skippable) -> done. The package
/// download step is not in the MVP (packages are bundled), so progress is
/// "Krok n z 3".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.intro;
  bool? _locationGranted;
  bool _profileSaved = false;
  HouseholdProfile _draft = HouseholdProfile.empty;
  bool _formValid = true;

  void _go(OnboardingStep s) => setState(() => _step = s);

  Future<void> _allow() async {
    final granted = await ref.read(locationPermissionGatewayProvider).request();
    if (!mounted) return;
    setState(() {
      _locationGranted = granted;
      _step = OnboardingStep.profileAsk;
    });
  }

  Future<void> _saveProfile() async {
    if (!_draft.isEmpty) {
      await ref.read(profileProvider.notifier).save(_draft);
      _profileSaved = true;
    }
    if (mounted) _go(OnboardingStep.done);
  }

  Future<void> _finish() async {
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (mounted) context.go('/');
  }

  /// "Krok n z 3" -> n / 3.
  static double _fractionOf(String progress) {
    final m = RegExp(r'(\d+) z (\d+)').firstMatch(progress);
    if (m == null) return 0;
    return int.parse(m.group(1)!) / int.parse(m.group(2)!);
  }

  Widget _title(String text, {String? progress}) {
    final bz = context.bz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress != null) ...[
          Text(progress, style: bz.caption),
          const SizedBox(height: 8),
          OnboardingProgressBar(fraction: _fractionOf(progress)),
        ],
        const SizedBox(height: 8),
        Text(text, style: bz.title),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Status row with a fixed 24 dp icon column so all labels align.
  Widget _statusRow(String label, {required bool done}) {
    final bz = context.bz;
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Icon(
            done ? LucideIcons.check : LucideIcons.minus,
            key: Key(done ? 'onb-status-done' : 'onb-status-skipped'),
            size: 20,
            color: done ? bz.verified : bz.ink300,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: bz.chat)),
      ],
    );
  }

  OnboardingStep? get _previous => switch (_step) {
    OnboardingStep.intro => null,
    OnboardingStep.location => OnboardingStep.intro,
    OnboardingStep.profileAsk => OnboardingStep.location,
    OnboardingStep.profileForm => OnboardingStep.profileAsk,
    OnboardingStep.done => OnboardingStep.profileAsk,
  };

  List<Widget> _body() {
    final bz = context.bz;
    switch (_step) {
      case OnboardingStep.intro:
        return [
          _title('Bezpiecznik'),
          Text(
            'Podpowiada, co zrobić w sytuacji kryzysowej, według oficjalnych poradników. Działa bez internetu. Prowadzi do najbliższego schronu.',
            style: bz.chat,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bz.signalTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  key: const Key('onb-notice-icon'),
                  size: 24,
                  color: bz.signal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nie zastępuje 112. W zagrożeniu życia dzwoń pod 112.',
                    style: bz.step,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          BzButton(
            key: const Key('onb-next'),
            label: 'Dalej',
            variant: BzButtonVariant.primary,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: () => _go(OnboardingStep.location),
          ),
        ];
      case OnboardingStep.location:
        return [
          _title('Pozwól na lokalizację', progress: 'Krok 2 z 3'),
          Text(
            'Pokażę najbliższy schron i wykryję twoje województwo. Tylko gdy używasz aplikacji. Lokalizacja zostaje w telefonie. Wysyłasz ją tylko ty, np. SMS-em do bliskich.',
            style: bz.chat,
          ),
          const Spacer(),
          BzButton(
            key: const Key('onb-allow'),
            label: 'Zezwól',
            variant: BzButtonVariant.primary,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: _allow,
          ),
          const SizedBox(height: 8),
          BzButton(
            key: const Key('onb-later'),
            label: 'Nie teraz',
            variant: BzButtonVariant.ghost,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: () => setState(() {
              _locationGranted = false;
              _step = OnboardingStep.profileAsk;
            }),
          ),
        ];
      case OnboardingStep.profileAsk:
        return [
          _title('Profil domu', progress: 'Krok 3 z 3'),
          if (_locationGranted == false) ...[
            Text(
              'Bez lokalizacji nie pokażę najbliższego schronu. Możesz to zmienić w ustawieniach telefonu.',
              style: bz.caption,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Odpowiedz na kilka pytań o domowników i mieszkanie (ok. 2 min). Dzięki temu porady dotyczą twojej rodziny. Profil zostaje tylko w telefonie.',
            style: bz.chat,
          ),
          const Spacer(),
          BzButton(
            key: const Key('onb-profile-fill'),
            label: 'Uzupełnij',
            variant: BzButtonVariant.primary,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: () => _go(OnboardingStep.profileForm),
          ),
          const SizedBox(height: 8),
          BzButton(
            key: const Key('onb-profile-later'),
            label: 'Później',
            variant: BzButtonVariant.ghost,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: () => _go(OnboardingStep.done),
          ),
        ];
      case OnboardingStep.profileForm:
        return [
          _title('Profil domu', progress: 'Krok 3 z 3'),
          Text(
            'Zostaje w telefonie. Wysyłasz go tylko ty. Każde pole możesz pominąć.',
            style: bz.caption,
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: ProfileForm(
                    initial: _draft,
                    onChanged: (p) => _draft = p,
                    onValidityChanged: (v) {
                      if (v != _formValid) setState(() => _formValid = v);
                    },
                  ),
                ),
                // Soft fade so headings are never sliced under the header.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 16,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const Key('onb-form-fade-top'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [bz.bg000, bz.bg000.withAlpha(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Fade hints that more fields are below the buttons.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 32,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const Key('onb-form-fade'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [bz.bg000.withAlpha(0), bz.bg000],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          BzButton(
            key: const Key('onb-profile-save'),
            label: 'Dalej',
            variant: BzButtonVariant.primary,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: _formValid ? _saveProfile : null,
          ),
          BzButton(
            key: const Key('onb-profile-skip'),
            label: 'Pomiń',
            variant: BzButtonVariant.ghost,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: () => _go(OnboardingStep.done),
          ),
        ];
      case OnboardingStep.done:
        return [
          _title('Gotowe'),
          _statusRow('SOS i karty ratunkowe', done: true),
          const SizedBox(height: 12),
          // Bundled in the APK, so always ready (no packages step in MVP).
          _statusRow('Baza wiedzy', done: true),
          const SizedBox(height: 12),
          _statusRow(
            _profileSaved ? 'Profil domu' : 'Profil domu: pominięto',
            done: _profileSaved,
          ),
          const Spacer(),
          BzButton(
            key: const Key('onb-start'),
            label: 'Zacznij',
            variant: BzButtonVariant.primary,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: _finish,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final prev = _previous;
    final top = MediaQuery.paddingOf(context).top;
    return PopScope(
      canPop: prev == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && prev != null) _go(prev);
      },
      child: Scaffold(
        backgroundColor: context.bz.bg000,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  // Leaves room for the floating shell controls (Back, SOS).
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _body(),
                  ),
                ),
              ),
            ),
            // Same slot as the shell Back button (RootOverlay): left 16, top max(48, inset + 8).
            if (prev != null)
              Positioned(
                left: 16,
                top: top + 8 > 48 ? top + 8 : 48,
                child: BzBackButton(onBack: () => _go(prev)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 6 dp progress bar: `bg-300` track, `ink-100` fill (bundle.css `.bz-progress`).
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        key: const Key('onb-progress'),
        height: 6,
        child: ColoredBox(
          color: bz.bg300,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              key: const Key('onb-progress-fill'),
              widthFactor: fraction.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: bz.ink100),
            ),
          ),
        ),
      ),
    );
  }
}
