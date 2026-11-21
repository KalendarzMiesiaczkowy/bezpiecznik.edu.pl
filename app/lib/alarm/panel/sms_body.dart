/// SOS SMS body and `sms:` / `tel:` URIs (spec `panel-2-kontakt-ze-sluzbami.md`,
/// "Szablon SMS"). Pure functions, reusable by the chat `call` template.
library;

import '../../profil/profile_model.dart';

/// Replaces Polish diacritics (SMS stays in the cheaper GSM-7 charset).
String stripPolish(String s) {
  const from = 'ąćęłńóśźżĄĆĘŁŃÓŚŹŻ';
  const to = 'acelnoszzACELNOSZZ';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Profile facts that may go into the SMS, in Polish (for the UI preview).
/// Never contains household member names or contact numbers.
class ProfileSmsFacts {
  const ProfileSmsFacts({this.household = const [], this.medications = const [], this.devices = const [], this.floor, this.floorSms});

  final List<String> household;
  final List<String> medications;
  final List<String> devices;

  /// "Piętro 7, bez windy" style fragment, null when unknown.
  final String? floor;

  /// Same fact in the SMS wording: `Piętro 7, bez windy`.
  final String? floorSms;

  bool get isEmpty => household.isEmpty && medications.isEmpty && devices.isEmpty && floor == null;

  /// Preview under the switch, e.g. `niemowlę, insulina, 7. piętro bez windy`.
  String get preview => [
    ...household,
    ...medications,
    ...devices,
    ?floor,
  ].join(', ');

  /// The `{profil}` line of the template (ASCII); empty when no facts.
  String get smsLine {
    final parts = <String>[
      if (household.isNotEmpty) 'Dom: ${household.join(', ')}.',
      if (medications.isNotEmpty) 'Leki: ${medications.join(', ')}.',
      if (devices.isNotEmpty) 'Urzadzenia: ${devices.join(', ')}.',
      if (floorSms != null) '$floorSms.',
    ];
    return stripPolish(parts.join(' '));
  }
}

ProfileSmsFacts profileSmsFacts(HouseholdProfile p) {
  const attention = [AgeGroup.infant, AgeGroup.child, AgeGroup.senior];
  final household = <String>[
    for (final g in attention)
      if (p.members.any((m) => m.ageGroup == g)) g.short,
    if (p.members.any((m) => m.limitedMobility == true)) 'ograniczona mobilność',
  ];
  final meds = [
    for (final m in p.medications)
      if (m.name.trim().isNotEmpty) m.name.trim() + (m.needsFridge == true ? ' (lodówka)' : ''),
  ];
  final devices = [
    for (final k in powerDeviceLabels.keys)
      if (p.powerDevices.contains(k))
        if (k == 'other')
          ((p.powerOtherText ?? '').trim().isEmpty ? powerDeviceLabels[k]! : p.powerOtherText!.trim())
        else
          powerDeviceLabels[k]!.toLowerCase(),
  ];
  final f = p.home.floor;
  final noLift = p.home.elevator == false;
  String? floor;
  if (f != null) {
    floor = '${f == 0 ? 'parter' : '$f. piętro'}${noLift ? ' bez windy' : ''}';
  } else if (noLift) {
    floor = 'bez windy';
  }
  final floorSms = [
    if (f != null) 'Piętro $f',
    if (noLift) 'bez windy',
  ].join(', ');
  return ProfileSmsFacts(
    household: household,
    medications: meds,
    devices: devices,
    floor: floor,
    floorSms: floorSms.isEmpty ? null : (f == null ? 'Bez windy' : floorSms),
  );
}

/// Everything the SMS template needs. [position] fields are null without fix.
class SosSmsInput {
  const SosSmsInput({
    this.lat,
    this.lon,
    this.accuracyM,
    this.positionTime,
    this.fresh = true,
    this.situation,
    this.address,
    this.profile,
  });

  final double? lat;
  final double? lon;
  final double? accuracyM;
  final DateTime? positionTime;

  /// False when the position is only the last known one (no current GPS).
  final bool fresh;

  /// Rescue card name or last user message (the caller truncates to 80).
  final String? situation;
  final String? address;

  /// Null = profile switch off or nothing to add.
  final ProfileSmsFacts? profile;
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _coord(double v) => v.toStringAsFixed(5);

/// Shortens a free-text situation to [max] characters.
String clipSituation(String s, [int max = 80]) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : t.substring(0, max).trimRight();
}

String buildSosSms(SosSmsInput i) {
  final lines = <String>['SOS. Potrzebuje pomocy.'];
  final sit = i.situation?.trim() ?? '';
  if (sit.isNotEmpty) lines[0] = '${lines[0]} Sytuacja: ${sit.endsWith('.') ? sit : '$sit.'}';
  final hasPos = i.lat != null && i.lon != null;
  final time = i.positionTime == null ? '' : _hhmm(i.positionTime!);
  if (!hasPos) {
    lines.add('Pozycja: nieznana (brak GPS).');
  } else {
    final lat = _coord(i.lat!);
    final lon = _coord(i.lon!);
    final acc = i.accuracyM == null ? '' : 'dokladnosc ${i.accuracyM!.round()} m';
    final detail = [acc, time].where((e) => e.isNotEmpty).join(', ');
    if (i.fresh) {
      lines.add('Pozycja: $lat, $lon${detail.isEmpty ? '' : ' ($detail)'}');
    } else {
      lines.add('Ostatnia pozycja: $lat, $lon (${time.isEmpty ? '' : '$time, '}teraz brak GPS)');
    }
    lines.add('https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon');
    final adr = i.address?.trim() ?? '';
    if (adr.isNotEmpty) lines.add('Adres (ok.): $adr');
  }
  final prof = i.profile?.smsLine ?? '';
  if (prof.isNotEmpty) lines.add(prof);
  lines.add('Jesli nie odpowiadam, zadzwon pod 112 i podaj te dane.');
  return stripPolish(lines.join('\n'));
}

/// ICE numbers that may receive the SMS: valid, and never an emergency number.
List<String> smsRecipients(List<IceContact> contacts) => [
  for (final c in contacts)
    if (!isEmergencyNumber(c.phone) && normalizePhone(c.phone) != null) normalizePhone(c.phone)!,
];

/// `sms:` URI opening the system composer; empty recipients = empty "To".
Uri smsUri(List<String> recipients, String body) =>
    Uri.parse('sms:${recipients.join(',')}?body=${Uri.encodeComponent(body)}');

Uri telUri(String number) => Uri(scheme: 'tel', path: number);

/// `52°13'47.2"N 21°00'42.4"E`.
String formatDms(double lat, double lon) {
  String one(double v, String pos, String neg) {
    final a = v.abs();
    var d = a.floor();
    var m = ((a - d) * 60).floor();
    var s = double.parse((((a - d) * 60 - m) * 60).toStringAsFixed(1));
    if (s >= 60) {
      s = 0;
      m += 1;
    }
    if (m >= 60) {
      m = 0;
      d += 1;
    }
    return '$d°${m.toString().padLeft(2, '0')}\'${s.toStringAsFixed(1).padLeft(4, '0')}"${v >= 0 ? pos : neg}';
  }

  return '${one(lat, 'N', 'S')} ${one(lon, 'E', 'W')}';
}
