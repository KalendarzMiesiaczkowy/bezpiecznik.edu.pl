import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// `<support dir>/paczki`: where downloaded packs live. Read by the pack
/// controller, the map installer and the edge LLM engine.
Future<Directory> defaultPacksDir() async =>
    Directory(p.join((await getApplicationSupportDirectory()).path, 'paczki'));
