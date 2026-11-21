import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../profil/profile_form.dart';
import '../profil/profile_model.dart';
import '../profil/profile_store.dart';
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

  Widget _title(String text, {String? progress}) {
    final bz = context.bz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress != null) Text(progress, style: bz.caption),
        const SizedBox(height: 8),
        Text(text, style: bz.title),
        const SizedBox(height: 16),
      ],
    );
  }

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
            decoration: BoxDecoration(border: Border.all(color: bz.line150), borderRadius: BorderRadius.circular(12)),
            child: Text('Nie zastępuje 112. W zagrożeniu życia dzwoń pod 112.', style: bz.step),
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
          Text('Zostaje w telefonie. Wysyłasz go tylko ty. Każde pole możesz pominąć.', style: bz.caption),
          Expanded(
            child: SingleChildScrollView(
              child: ProfileForm(initial: _draft, onChanged: (p) => _draft = p),
            ),
          ),
          const SizedBox(height: 8),
          BzButton(
            key: const Key('onb-profile-save'),
            label: 'Dalej',
            variant: BzButtonVariant.primary,
            size: BzButtonSize.xl,
            fullWidth: true,
            onPressed: _saveProfile,
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
          Text('✓ SOS i karty ratunkowe', style: bz.chat),
          Text(_profileSaved ? '✓ Profil domu' : 'Profil domu: pominięto', style: bz.chat),
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
    return Scaffold(
      backgroundColor: context.bz.bg000,
      body: SafeArea(
        child: Padding(
          // Leaves room for the floating shell controls (SOS).
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _body()),
        ),
      ),
    );
  }
}
