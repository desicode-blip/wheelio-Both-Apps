import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'map_loader_stub.dart'
    if (dart.library.js_interop) 'map_loader_web.dart'
    as loader;

/// Replaces only the existing map surface; location is selected by the owner.
class LivePlaceMap extends StatefulWidget {
  const LivePlaceMap({
    super.key,
    required this.config,
    required this.latitude,
    required this.longitude,
    required this.onMoved,
    this.onLocate,
  });
  final Map<String, dynamic> config;
  final double latitude, longitude;
  final void Function(double latitude, double longitude) onMoved;

  /// "Locate me": returns the phone's position to move the map to, or null to stay.
  final Future<(double, double)?> Function()? onLocate;
  @override
  State<LivePlaceMap> createState() => _LivePlaceMapState();
}

class _LivePlaceMapState extends State<LivePlaceMap> {
  late Future<void> ready = loader.prepareMap(widget.config);
  late LatLng position = LatLng(widget.latitude, widget.longitude);
  bool moved = false, locating = false;
  GoogleMapController? _map;

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      final found = await widget.onLocate!();
      if (found != null && mounted) {
        await _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(found.$1, found.$2), 17));
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(
          child: TextButton(
            onPressed: () =>
                setState(() => ready = loader.prepareMap(widget.config)),
            child: const Text('Map unavailable · Retry'),
          ),
        );
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      return Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: position, zoom: 16),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) => _map = controller,
            onCameraMove: (camera) {
              position = camera.target;
              moved = true;
            },
            onCameraIdle: () {
              if (moved) {
                moved = false;
                widget.onMoved(position.latitude, position.longitude);
              }
            },
          ),
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: WIconView(WIcon.location, size: 40, color: WColor.primary),
            ),
          ),
          // Bottom right: clear of the Google logo (bottom left) and the centre pin.
          if (widget.onLocate != null)
            Positioned(right: 12, bottom: 12, child: MapLocateButton(busy: locating, onTap: _locate)),
        ],
      );
    },
  );
}
