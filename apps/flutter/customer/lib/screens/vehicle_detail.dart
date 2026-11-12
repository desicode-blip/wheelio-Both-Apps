import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'booking.dart' show VehiclePlate;

// v2 CU-VEHICLE (12 Nov 2026, Aman): tapping a saved vehicle first shows the vehicle —
// details, photos, edit and delete — and then offers to book a wash for it.
// Route N.vehicleDetail. C46c.

class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _delete(BuildContext context, Vehicle v) async {
    final store = context.store, router = context.router;
    final blocked = store.vehicleDeleteBlocked(v);
    if (blocked != null) {
      await showWAlert(context, title: 'Can’t delete yet', message: blocked, actions: const [AlertAction('OK', cancel: true)]);
      return;
    }
    await showWAlert(
      context,
      title: 'Delete ${v.plate.isEmpty ? 'this vehicle' : v.plate}?',
      message: 'It is removed from your saved vehicles. Your past bookings stay as they are.',
      actions: [
        AlertAction('Delete vehicle', destructive: true, onTap: () async {
          await store.deleteVehicle(v);
          router.pop();
          store.set(() => store.toast = 'Vehicle deleted');
        }),
        const AlertAction('Keep', cancel: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final v = store.myVehicles.where((x) => x.id == id).firstOrNull;
    if (v == null) {
      return WScreen(header: WAppBar(title: 'Your vehicle', onLeading: router.pop), children: const [WTitleBlock('This vehicle is no longer saved')]);
    }
    final washes = store.washesFor(v);
    final place = v.place;
    return WScreen(
      header: WAppBar(title: 'Your vehicle', onLeading: router.pop),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Book a wash for this vehicle', onTap: () {
          store.openRepeat(v.id);
          router.push(R(N.repeatBooking, id: v.id));
        }),
      ),
      children: [
        const SizedBox(height: 8),
        WCard(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  WIconBox(v.type.icon, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (v.plate.isEmpty) const WText('No number plate yet', WType.bodyStrong) else VehiclePlate(v.plate),
                        const SizedBox(height: 6),
                        WText(v.type.name, WType.caption),
                      ],
                    ),
                  ),
                ],
              ),
              if (place != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: WColor.divider),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WIconView(WIcon.location, size: 18, color: WColor.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [const WText('Last parked at', WType.caption), const SizedBox(height: 2), WText('${place.title} · ${place.parkingShort}', WType.body)],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        WCard(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: WText('Photos', WType.title)),
                  WLink(v.photos.isEmpty ? 'Add photos' : 'Change', onTap: () => router.push(R(N.vehicleEdit, id: v.id))),
                ],
              ),
              const SizedBox(height: 10),
              if (v.photos.isEmpty)
                const WText('No photos yet. Photos help your Captain find the right vehicle.', WType.caption)
              else
                Row(
                  children: [
                    for (final a in PhotoAngle.values)
                      if (v.photos[a] != null) ...[
                        Expanded(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(aspectRatio: 1, child: Image.memory(v.photos[a]!, fit: BoxFit.cover, gaplessPlayback: true)),
                              ),
                              const SizedBox(height: 4),
                              WText(a.label.replaceAll(' side', ''), WType.small),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        WCard(
          radius: 16,
          padding: 6,
          child: Column(
            children: [
              WListRow(icon: WIcon.edit, title: 'Edit details', subtitle: 'Vehicle type, number plate, photos', onTap: () => router.push(R(N.vehicleEdit, id: v.id))),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.trash, title: 'Delete vehicle', tone: Tone.error, chevron: false, onTap: () => _delete(context, v)),
            ],
          ),
        ),
        if (washes.isNotEmpty) ...[
          const SizedBox(height: 22),
          const WText('Recent washes', WType.title),
          const SizedBox(height: 10),
          WCard(
            radius: 16,
            padding: 6,
            child: Column(
              children: [
                for (final (i, o) in washes.take(3).indexed) ...[
                  if (i > 0) const WDivider(inset: 54),
                  WListRow(
                    icon: WIcon.sparkle,
                    title: Fmt.date(o.slot.date),
                    subtitle: '${o.status.isUpcoming ? 'Booked' : o.status == OrderStatus.cancelled ? 'Cancelled' : 'Done'} · ${Fmt.rupees(o.price)}',
                    onTap: () => router.push(R(N.bookingDetail, id: o.id)),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
