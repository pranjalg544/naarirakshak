import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';
import '../theme/app_theme.dart';

/// Reusable OpenStreetMap widget for NaariRakshak using `flutter_map`.
///
/// Features high-accuracy GPS live location detection, auto-centering,
/// route polylines, companion avatar markers, and pulsing emergency SOS beacon pins.
class OpenStreetMapWidget extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final double height;
  final List<Marker> extraMarkers;
  final List<LatLng>? routePoints;
  final bool isSosActive;
  final bool interactive;
  final bool useLiveGps;
  final String titleLabel;

  const OpenStreetMapWidget({
    super.key,
    required this.center,
    this.zoom = 13.5,
    this.height = 200,
    this.extraMarkers = const [],
    this.routePoints,
    this.isSosActive = false,
    this.interactive = true,
    this.useLiveGps = true,
    this.titleLabel = 'Live OpenStreetMap',
  });

  @override
  State<OpenStreetMapWidget> createState() => _OpenStreetMapWidgetState();
}

class _OpenStreetMapWidgetState extends State<OpenStreetMapWidget>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  final _locationService = LocationService();

  LatLng? _liveGpsPosition;
  bool _isLocating = false;
  StreamSubscription<LatLng>? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isSosActive) {
      _pulseController.repeat(reverse: true);
    }

    if (widget.useLiveGps) {
      _detectExactLocation();
    }
  }

  Future<void> _detectExactLocation() async {
    setState(() => _isLocating = true);
    final detectedLoc = await _locationService.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _liveGpsPosition = detectedLoc;
      _isLocating = false;
    });

    // Start continuous tracking
    _locationService.startTracking();
    _gpsSubscription = _locationService.locationStream.listen((newLoc) {
      if (!mounted) return;
      setState(() => _liveGpsPosition = newLoc);
    });
  }

  void _recenterOnMyLocation() {
    final target = _liveGpsPosition ?? widget.center;
    _mapController.move(target, 15.0);
  }

  @override
  void didUpdateWidget(covariant OpenStreetMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSosActive != oldWidget.isSosActive) {
      if (widget.isSosActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _locationService.dispose();
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCenter = _liveGpsPosition ?? widget.center;

    final defaultRoute = widget.routePoints ??
        [
          activeCenter,
          LatLng(activeCenter.latitude - 0.02, activeCenter.longitude - 0.04),
          LatLng(activeCenter.latitude - 0.05, activeCenter.longitude - 0.16),
        ];

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSosActive ? AppColors.coral : AppColors.border,
          width: widget.isSosActive ? 2.0 : 1.0,
        ),
        boxShadow: widget.isSosActive
            ? [
                BoxShadow(
                  color: AppColors.coral.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // ── OpenStreetMap Tile Layer ──────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: activeCenter,
                initialZoom: widget.zoom,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                // Official OpenStreetMap Tile Server (100% Free, Public Domain, No Watermark)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.naarirakshak.app',
                ),

                // Commute Route Polyline
                if (defaultRoute.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: defaultRoute,
                        strokeWidth: 4.5,
                        color: widget.isSosActive
                            ? AppColors.coral
                            : AppColors.amber,
                      ),
                    ],
                  ),

                // Markers Layer
                MarkerLayer(
                  markers: [
                    ...widget.extraMarkers,

                    // Origin Marker
                    Marker(
                      point: defaultRoute.first,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.bgDeep,
                          size: 16,
                        ),
                      ),
                    ),

                    // Destination Marker
                    Marker(
                      point: defaultRoute.last,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                    // Live User / Emergency Beacon Marker
                    Marker(
                      point: activeCenter,
                      width: widget.isSosActive ? 52 : 40,
                      height: widget.isSosActive ? 52 : 40,
                      child: widget.isSosActive
                          ? AnimatedBuilder(
                              animation: _pulseController,
                              builder: (_, _) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width:
                                        52 * (0.8 + _pulseController.value * 0.4),
                                    height:
                                        52 * (0.8 + _pulseController.value * 0.4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.coral.withValues(
                                        alpha: 0.4 * (1.0 - _pulseController.value),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.coral,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Top OpenStreetMap Status Watermark Tag ────────────────────────
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLocating)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.amber,
                        ),
                      )
                    else
                      Icon(
                        widget.isSosActive
                            ? Icons.warning_rounded
                            : Icons.gps_fixed_rounded,
                        size: 11,
                        color: widget.isSosActive
                            ? AppColors.coral
                            : (_liveGpsPosition != null
                                ? AppColors.green
                                : AppColors.amber),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isSosActive
                          ? 'LIVE EMERGENCY BEACON · OSM'
                          : (_isLocating
                              ? 'Locating exact GPS...'
                              : (_liveGpsPosition != null
                                  ? 'Exact GPS Active · OSM'
                                  : widget.titleLabel)),
                      style: AppTextStyles.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Interactive Map Controls (Locate Me & Zoom Controls) ────────
            if (widget.interactive)
              Positioned(
                bottom: 10,
                right: 10,
                child: Column(
                  children: [
                    // Recenter on My Exact Location Button
                    InkWell(
                      onTap: _recenterOnMyLocation,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.bgDeep,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Zoom In
                    InkWell(
                      onTap: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child:
                            const Icon(Icons.add, size: 16, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Zoom Out
                    InkWell(
                      onTap: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.remove,
                          size: 16,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
