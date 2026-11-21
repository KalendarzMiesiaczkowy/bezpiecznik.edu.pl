import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../paczki/pack_controller.dart';
import '../paczki/pack_progress_strip.dart';
import '../profil/profile_form.dart';
import '../profil/profile_model.dart';
import '../profil/profile_store.dart';
import '../wspolne/shell/nav_island.dart';
import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import 'location_gateway.dart';

enum OnboardingStep { intro, location, profileAsk, profileForm }

/// E0 (MVP): intro -> location -> profile (skippable) -> chat. There is no
/// separate package step: the model and the map download in the background
/// from the first frame, and [PackProgressStrip] above the buttons shows the
/// progress on every step. Step progress stays "Krok n z 3".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.intro;
  bool? _locationGranted;
  bool _confirming = false;
  HouseholdProfile _draft = HouseholdProfile.empty;
  bool _formValid = true;

  void _go(OnboardingStep s) => setState(() => _step = s);

  Future<void> _allow() async {
    final granted = await ref.read(locationPermissionGatewayProvider).request();
    if (!mounted) return;
    // The map pack waits for this answer to know the region.
    ref.read(packsProvider.notifier).locationDecided(granted: granted);
    setState(() {
      _locationGranted = granted;
      _step = OnboardingStep.profileAsk;
    });
  }

  Future<void> _saveProfile() async {
    if (_draft.isEmpty) return _finish();
    await ref.read(profileProvider.notifier).save(_draft);
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (!mounted) return;
    setState(() => _confirming = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) context.go('/');
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

  OnboardingStep? get _previous => switch (_step) {
    OnboardingStep.intro => null,
    OnboardingStep.location => OnboardingStep.intro,
    OnboardingStep.profileAsk => OnboardingStep.location,
    OnboardingStep.profileForm => OnboardingStep.profileAsk,
  };

  /// Scrollable step body; the buttons after it stay pinned (large text).
  Widget _scroll(List<Widget> children) => Expanded(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  List<Widget> _body() {
    final bz = context.bz;
    switch (_step) {
      case OnboardingStep.intro:
        return [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                ],
              ),
            ),
          ),
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
          _scroll([
            _title('Pozwól na lokalizację', progress: 'Krok 2 z 3'),
            Text(
              'Pokażę najbliższy schron. Tylko gdy używasz aplikacji. Lokalizacja zostaje w telefonie. Wysyłasz ją tylko ty, np. SMS-em do bliskich.',
              style: bz.chat,
            ),
          ]),
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
            onPressed: () {
              ref.read(packsProvider.notifier).locationDecided(granted: false);
              setState(() {
                _locationGranted = false;
                _step = OnboardingStep.profileAsk;
              });
            },
          ),
        ];
      case OnboardingStep.profileAsk:
        return [
          _scroll([
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
          ]),
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
            onPressed: _finish,
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
            onPressed: _finish,
          ),
        ];
    }
  }

  /// Screen height in text-scaled units below which the strip is left out:
  /// the profile form needs every pixel sooner than the other steps, whose
  /// content scrolls.
  static const double _tightForm = 560;
  static const double _tightStep = 400;

  /// Puts the download progress between the step's scrolling content (its
  /// last `Expanded`) and the pinned buttons. The form step gets the compact
  /// strip. On a small screen with large text there is no room for it: the
  /// download goes on, and Settings shows the progress.
  List<Widget> _withPackStrip(List<Widget> body) {
    final form = _step == OnboardingStep.profileForm;
    final scaled = MediaQuery.sizeOf(context).height / MediaQuery.textScalerOf(context).scale(1);
    if (scaled < (form ? _tightForm : _tightStep)) return body;
    final at = body.lastIndexWhere((w) => w is Expanded) + 1;
    return [
      ...body.take(at),
      PackProgressStrip(
        compact: form,
        padding: EdgeInsets.only(top: 12, bottom: form ? 4 : 16),
      ),
      ...body.skip(at),
    ];
  }

  Widget _confirmation() => Expanded(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Column(
        key: const Key('onb-confirm'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.check, size: 48, color: context.bz.verified),
          const SizedBox(height: 16),
          Text('Dodano profil domu', style: context.bz.title),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final prev = _confirming ? null : _previous;
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
                    children: _confirming ? [_confirmation()] : _withPackStrip(_body()),
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
