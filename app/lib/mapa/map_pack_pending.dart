import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../paczki/pack.dart';
import '../paczki/pack_controller.dart';
import '../paczki/pack_progress_strip.dart';
import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';

// Drafted copy (verify: true): ekran-2-mapa.md has no texts for a map pack
// that is still downloading.
const mapPackDownloadingTitle = 'Pobieram mapę…';
const mapPackDownloadingBody = 'Dzieje się to tylko raz. Potem mapa działa bez internetu.';
const mapPackWaitingTitle = 'Mapa jeszcze się nie pobrała';
const mapPackWaitWifiBody = 'Czekam na Wi-Fi.';
const mapPackErrorTitle = 'Nie udało się pobrać mapy';
const mapPackErrorBody = 'Sprawdź internet i spróbuj ponownie. To, co już pobrane, zostaje w telefonie.';
const mapPackNoSpaceTitle = 'Za mało miejsca w telefonie';
const mapPackOutsideTitle = 'Jesteś poza mapą szczegółową';
const mapPackOutsideBody = 'Mapa szczegółowa obejmuje woj. zachodniopomorskie.';
const mapPackUnavailableTitle = 'Mapa nie jest dostępna';
const mapPackUnavailableBody = 'Ta wersja aplikacji nie ma mapy do pobrania.';
const mapPackRetry = 'Spróbuj ponownie';

/// Shown instead of the map while its pack is not on the device: download
/// progress, or what the download is waiting for and how to unblock it.
class MapPackPending extends ConsumerWidget {
  const MapPackPending({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final status = ref.watch(packsProvider.select((s) => s.byId(mapPackId)));
    final controller = ref.read(packsProvider.notifier);
    final size = status == null ? '' : formatPackSize(status.pack.bytes);

    final String title;
    final String body;
    double? fraction;
    String? actionLabel;
    VoidCallback? action;
    switch (status?.phase) {
      case null:
        title = mapPackUnavailableTitle;
        body = mapPackUnavailableBody;
      case PackPhase.waiting:
        title = mapPackWaitingTitle;
        body = packStripMapWaits;
      case PackPhase.waitingWifi:
        title = mapPackWaitingTitle;
        body = mapPackWaitWifiBody;
        actionLabel = '$packStripUseCellular ($size)';
        action = controller.allowCellular;
      case PackPhase.downloading || PackPhase.verifying || PackPhase.done:
        title = mapPackDownloadingTitle;
        body = mapPackDownloadingBody;
        fraction = status!.fraction;
      case PackPhase.error:
        title = mapPackErrorTitle;
        body = mapPackErrorBody;
        actionLabel = mapPackRetry;
        action = () => controller.retry(mapPackId);
      case PackPhase.noSpace:
        title = mapPackNoSpaceTitle;
        body = 'Mapa potrzebuje ok. $size. Zwolnij miejsce i spróbuj ponownie.';
        actionLabel = mapPackRetry;
        action = () => controller.retry(mapPackId);
      case PackPhase.skipped:
        title = mapPackOutsideTitle;
        body = mapPackOutsideBody;
        actionLabel = 'Pobierz mimo to ($size)';
        action = () => controller.retry(mapPackId);
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(bz.space6),
        child: Column(
          key: const Key('map-pack-pending'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: bz.title, textAlign: TextAlign.center),
            SizedBox(height: bz.space3),
            Text(body, style: bz.chat.copyWith(color: bz.ink200), textAlign: TextAlign.center),
            if (fraction != null) ...[
              SizedBox(height: bz.space5),
              PackProgressBar(fraction: fraction),
              SizedBox(height: bz.space2),
              Text(
                '${(fraction * 100).floor()}% z $size',
                style: bz.caption.copyWith(color: bz.ink200),
              ),
            ],
            if (actionLabel != null) ...[
              SizedBox(height: bz.space5),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: bz.minTouchTarget),
                child: BzButton(
                  key: const Key('map-pack-action'),
                  label: actionLabel,
                  size: BzButtonSize.lg,
                  onPressed: action,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
