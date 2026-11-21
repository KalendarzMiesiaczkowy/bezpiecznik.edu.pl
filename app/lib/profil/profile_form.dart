import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import 'profile_model.dart';

/// Editable form shared by E4 (edit) and the E0 wizard step. Reports only
/// valid data through [onChanged]; invalid entries show an error and are not
/// emitted (spec: invalid value is never saved).
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initial,
    required this.onChanged,
    this.onValidityChanged,
  });

  final HouseholdProfile initial;
  final ValueChanged<HouseholdProfile> onChanged;

  /// Reports whether every field is currently valid (false = show errors,
  /// the host should block "Dalej").
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ContactDraft {
  _ContactDraft(String name, String phone)
    : name = TextEditingController(text: name),
      phone = TextEditingController(text: phone);
  final TextEditingController name;
  final TextEditingController phone;
  bool phoneTouched = false;
}

class _ProfileFormState extends State<ProfileForm> {
  late Map<AgeGroup, int> _counts;
  late List<Member> _extraMembers; // keeps labels/mobility of existing members
  late List<TextEditingController> _meds;
  late Set<String> _devices;
  late TextEditingController _otherDevice;
  late TextEditingController _floor;
  bool? _elevator;
  late List<_ContactDraft> _contacts;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _counts = {
      for (final g in AgeGroup.values)
        g: p.members.where((m) => m.ageGroup == g).length,
    };
    _extraMembers = p.members;
    _meds = [
      for (final m in p.medications) TextEditingController(text: m.name),
    ];
    _devices = {...p.powerDevices};
    _otherDevice = TextEditingController(text: p.powerOtherText ?? '');
    _floor = TextEditingController(text: p.home.floor?.toString() ?? '');
    _elevator = p.home.elevator;
    _contacts = [for (final c in p.iceContacts) _ContactDraft(c.name, c.phone)];
  }

  @override
  void dispose() {
    for (final c in [
      ..._meds,
      _otherDevice,
      _floor,
      for (final d in _contacts) ...[d.name, d.phone],
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _floorError() {
    final t = _floor.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    if (v == null || v < -2 || v > 100) return 'Wpisz liczbę od -2 do 100.';
    return null;
  }

  String? _nameError(_ContactDraft d) {
    if (d.name.text.trim().isEmpty && d.phone.text.trim().isNotEmpty) {
      return 'Wpisz nazwę albo usuń wpis.';
    }
    return null;
  }

  String? _phoneError(_ContactDraft d) {
    final t = d.phone.text.trim();
    if (t.isEmpty) {
      return d.name.text.trim().isEmpty || !d.phoneTouched
          ? null
          : 'Wpisz numer w formacie 600 100 200 albo +48 600 100 200.';
    }
    if (isEmergencyNumber(t)) {
      return 'To numer alarmowy. Wpisz numer bliskiej osoby.';
    }
    if (normalizePhone(t) == null) {
      return 'Wpisz numer w formacie 600 100 200 albo +48 600 100 200.';
    }
    return null;
  }

  HouseholdProfile _build() {
    // Rebuild members: keep existing entries of a group (with labels), then
    // trim/extend to the chosen count.
    final members = <Member>[];
    for (final g in AgeGroup.values) {
      final existing = _extraMembers.where((m) => m.ageGroup == g).toList();
      for (var i = 0; i < _counts[g]!; i++) {
        members.add(i < existing.length ? existing[i] : Member(ageGroup: g));
      }
    }
    final contacts = <IceContact>[];
    for (final d in _contacts) {
      if (_nameError(d) != null || _phoneError(d) != null) continue;
      final phone = normalizePhone(d.phone.text.trim());
      if (phone == null || d.name.text.trim().isEmpty) continue;
      contacts.add(IceContact(name: d.name.text.trim(), phone: phone));
    }
    return HouseholdProfile(
      members: members,
      medications: [
        for (final c in _meds)
          if (c.text.trim().isNotEmpty) Medication(name: c.text.trim()),
      ],
      powerDevices: _devices,
      powerOtherText:
          _devices.contains('other') && _otherDevice.text.trim().isNotEmpty
          ? _otherDevice.text.trim()
          : null,
      home: Home(
        floor: _floorError() == null
            ? int.tryParse(_floor.text.trim())
            : widget.initial.home.floor,
        elevator: _elevator,
      ),
      iceContacts: contacts,
    );
  }

  bool get _valid =>
      _floorError() == null &&
      _contacts.every((d) => _nameError(d) == null && _phoneError(d) == null);

  void _changed([VoidCallback? mutate]) {
    setState(() => mutate?.call());
    widget.onChanged(_build());
    widget.onValidityChanged?.call(_valid);
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: context.bz.step),
  );

  /// Ghost buttons carry a horizontal padding; shift left so the label lines
  /// up with the section headings.
  Widget _flushLeft(Widget child) => Align(
    alignment: Alignment.centerLeft,
    child: Transform.translate(
      offset: Offset(-BzButtonSize.md.hPadding, 0),
      child: child,
    ),
  );

  Widget _yesNo(
    String label,
    bool? value,
    ValueChanged<bool?> on, {
    String? key,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.bz.chat)),
        for (final (text, v) in [('Tak', true), ('Nie', false)])
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: BzChip(
              key: key == null ? null : Key('$key-$text'),
              label: text,
              selected: value == v,
              onChanged: (s) => on(s ? v : null),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Kto mieszka w domu?'),
        for (final g in AgeGroup.values)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(child: Text(g.label, style: context.bz.chat)),
                IconButton(
                  key: Key('members-${g.name}-minus'),
                  tooltip: 'Mniej: ${g.short}',
                  onPressed: _counts[g]! > 0
                      ? () => _changed(() => _counts[g] = _counts[g]! - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${_counts[g]}',
                    textAlign: TextAlign.center,
                    key: Key('members-${g.name}-count'),
                  ),
                ),
                IconButton(
                  key: Key('members-${g.name}-plus'),
                  tooltip: 'Więcej: ${g.short}',
                  onPressed: _counts.values.fold<int>(0, (a, b) => a + b) < 15
                      ? () => _changed(() => _counts[g] = _counts[g]! + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        _section('Leki'),
        for (var i = 0; i < _meds.length; i++)
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('med-$i'),
                  controller: _meds[i],
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa leku',
                    helperText: 'Np. insulina.',
                    counterText: '',
                  ),
                  onChanged: (_) => _changed(),
                ),
              ),
              IconButton(
                tooltip: 'Usuń lek',
                onPressed: () => _changed(() => _meds.removeAt(i).dispose()),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        if (_meds.length < 20)
          _flushLeft(
            BzButton(
              key: const Key('med-add'),
              label: '+ Dodaj lek',
              variant: BzButtonVariant.ghost,
              onPressed: () =>
                  _changed(() => _meds.add(TextEditingController())),
            ),
          ),
        _section('Urządzenia zależne od prądu'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in powerDeviceLabels.entries)
              BzChip(
                key: Key('device-${e.key}'),
                label: e.value,
                selected: _devices.contains(e.key),
                onChanged: (s) => _changed(
                  () => s ? _devices.add(e.key) : _devices.remove(e.key),
                ),
              ),
          ],
        ),
        if (_devices.contains('other'))
          TextField(
            key: const Key('device-other-text'),
            controller: _otherDevice,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Inne',
              counterText: '',
            ),
            onChanged: (_) => _changed(),
          ),
        _section('Twoje mieszkanie'),
        TextField(
          key: const Key('home-floor'),
          controller: _floor,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: 'Piętro',
            helperText: '0 to parter',
            errorText: _floorError(),
          ),
          onChanged: (_) => _changed(),
        ),
        _yesNo(
          'Winda',
          _elevator,
          (v) => _changed(() => _elevator = v),
          key: 'home-elevator',
        ),
        _section('Kogo powiadomić w razie zagrożenia?'),
        Text(
          'Do tych osób przygotujemy SMS z twoją pozycją. Wyślesz go sam.',
          style: context.bz.caption,
        ),
        for (var i = 0; i < _contacts.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      key: Key('ice-name-$i'),
                      controller: _contacts[i].name,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: 'Imię',
                        counterText: '',
                        errorText: _nameError(_contacts[i]),
                      ),
                      onChanged: (_) => _changed(),
                    ),
                    SizedBox(height: context.bz.space3),
                    TextField(
                      key: Key('ice-phone-$i'),
                      controller: _contacts[i].phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numer',
                        errorText: _phoneError(_contacts[i]),
                      ),
                      onChanged: (_) =>
                          _changed(() => _contacts[i].phoneTouched = true),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Usuń kontakt',
                onPressed: () => _changed(() {
                  final d = _contacts.removeAt(i);
                  d.name.dispose();
                  d.phone.dispose();
                }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        if (_contacts.length < 5)
          _flushLeft(
            BzButton(
              key: const Key('ice-add'),
              label: '+ Dodaj kontakt',
              variant: BzButtonVariant.ghost,
              onPressed: () =>
                  _changed(() => _contacts.add(_ContactDraft('', ''))),
            ),
          ),
      ],
    );
  }
}

/// Design-system choice chip (`.bz-chip`): 40 dp tall stadium, 1 px
/// `line-150` border, `ink-100` label; on = `action` fill.
class BzChip extends StatelessWidget {
  const BzChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final fg = selected ? bz.onAction : bz.ink100;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? bz.action : const Color(0x00000000),
        shape: StadiumBorder(
          side: BorderSide(color: selected ? bz.action : bz.line150),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: height,
              maxHeight: height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
