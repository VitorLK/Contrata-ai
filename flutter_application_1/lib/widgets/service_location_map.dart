import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/map_constants.dart';
import '../core/theme/app_theme.dart';

/// Mapa real compartilhado entre o cadastro e o detalhe do serviço.
/// Quando [onPointChanged] é informado, um toque reposiciona o marcador.
class ServiceLocationMap extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final ValueChanged<LatLng>? onPointChanged;
  final double height;
  final String? semanticsLabel;

  const ServiceLocationMap({
    super.key,
    this.latitude,
    this.longitude,
    this.onPointChanged,
    this.height = 250,
    this.semanticsLabel,
  });

  @override
  State<ServiceLocationMap> createState() => _ServiceLocationMapState();
}

class _ServiceLocationMapState extends State<ServiceLocationMap> {
  static const _brazilCenter = LatLng(-14.235, -51.9253);
  final _controller = MapController();
  bool _mapReady = false;

  LatLng? get _selectedPoint {
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  @override
  void didUpdateWidget(covariant ServiceLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (changed && _selectedPoint != null && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(_selectedPoint!, 16);
      });
    }
  }

  void _zoom(double delta) {
    if (!_mapReady) return;
    final zoom = (_controller.camera.zoom + delta).clamp(3.0, 19.0);
    _controller.move(_controller.camera.center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final point = _selectedPoint;
    final canSelect = widget.onPointChanged != null;

    return Semantics(
      label:
          widget.semanticsLabel ??
          (canSelect
              ? 'Mapa para escolher a localização aproximada do serviço'
              : 'Mapa da localização aproximada do serviço'),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: point ?? _brazilCenter,
                initialZoom: point == null ? 3.8 : 16,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () => _mapReady = true,
                onTap: canSelect
                    ? (_, selectedPoint) =>
                          widget.onPointChanged!(selectedPoint)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConstants.tileUrl,
                  userAgentPackageName: MapConstants.userAgentPackageName,
                  maxZoom: 19,
                ),
                if (point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 54,
                        height: 54,
                        alignment: Alignment.topCenter,
                        child: const _MapPin(),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse(MapConstants.attributionUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (canSelect)
              Positioned(
                left: 10,
                top: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.touch_app_outlined,
                          size: 16,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          point == null
                              ? 'Busque ou toque para marcar'
                              : 'Toque para ajustar o ponto',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _ZoomButton(
                    tooltip: 'Aproximar mapa',
                    icon: Icons.add_rounded,
                    onPressed: () => _zoom(1),
                  ),
                  const SizedBox(height: 6),
                  _ZoomButton(
                    tooltip: 'Afastar mapa',
                    icon: Icons.remove_rounded,
                    onPressed: () => _zoom(-1),
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

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: .28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.location_on_rounded, color: Colors.white),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
