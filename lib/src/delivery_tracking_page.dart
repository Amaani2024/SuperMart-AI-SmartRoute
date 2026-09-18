import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  Map<String, dynamic>? data;
  String? error;
  bool refreshing = false;
  Timer? refreshTimer;
  final MapController mapController = MapController();
  bool mapReady = false;

  @override
  void initState() {
    super.initState();
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => load(silent: true));
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (refreshing) return;
    refreshing = true;
    try {
      final result = await Api.get('/orders/${widget.orderId}/tracking');
      if (!mounted) return;
      setState(() {
        data = result;
        error = null;
      });
      await fitRoute();
    } catch (exception) {
      if (!silent && mounted) {
        setState(() => error = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      refreshing = false;
    }
  }

  List<LatLng> points(dynamic raw) => (raw as List? ?? const [])
      .map((point) => LatLng(
            (point['latitude'] as num).toDouble(),
            (point['longitude'] as num).toDouble(),
          ))
      .toList();

  Future<void> fitRoute() async {
    final route = points(data?['route_points']);
    if (!mapReady || route.isEmpty) return;

    if (route.length == 1) {
      mapController.move(route.first, 16);
      return;
    }

    mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: route,
        padding: const EdgeInsets.all(55),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = data;
    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Order #${widget.orderId}')),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: load, child: const Text('Try again')),
                    ],
                  ),
                ),
        ),
      );
    }

    final order = Map<String, dynamic>.from(current['order']);
    final isDelivery = order['order_type'] == 'delivery';
    final status = '${current['effective_status'] ?? order['status']}';
    return Scaffold(
      appBar: AppBar(
        title: Text('Track order #${widget.orderId}'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _statusHeader(status, current),
            if (isDelivery) ...[
              const SizedBox(height: 14),
              _map(current),
              const SizedBox(height: 12),
              if (current['route_mode'] == 'demo_simulation')
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(Icons.science_outlined, size: 18),
                    label: Text('Demo moving route'),
                  ),
                ),
              _driverCard(current),
              if (order['delivery_pin'] != null && status != 'delivered') ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.pin_outlined)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Secure delivery PIN',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text('Share only after receiving your order.'),
                            ],
                          ),
                        ),
                        Text(
                          '${order['delivery_pin']}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _deliveryDetails(order),
            ],
            const SizedBox(height: 16),
            _timeline(status, isDelivery),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statusHeader(String status, Map<String, dynamic> current) {
    final delivered = status == 'delivered';
    final nearby = status == 'rider_nearby' || current['nearby'] == true;
    final title = delivered
        ? 'Order delivered'
        : nearby
            ? 'Your rider is nearby'
            : status == 'out_for_delivery'
                ? 'Your order is on the way'
                : status == 'rider_assigned'
                    ? 'A rider has been assigned'
                    : 'Order ${status.replaceAll('_', ' ')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xffffb547),
              child: Icon(
                delivered ? Icons.check : nearby ? Icons.notifications_active : Icons.local_shipping,
                color: const Color(0xff173f35),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  if (!delivered && current['estimated_arrival_minutes'] != null)
                    Text(
                      'About ${current['estimated_arrival_minutes']} minute(s) · '
                      '${current['remaining_distance_km']} km remaining',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _map(Map<String, dynamic> current) {
    const packageName = 'com.supermart.supermart_flutter';
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    final branch = current['branch_location'];
    final customer = current['customer_location'];
    final driver = current['driver'];
    final completed = points(current['completed_route']);
    final remaining = points(current['remaining_route']);
    final branchPoint = LatLng(
      (branch['latitude'] as num).toDouble(),
      (branch['longitude'] as num).toDouble(),
    );
    final customerPoint = LatLng(
      (customer['latitude'] as num).toDouble(),
      (customer['longitude'] as num).toDouble(),
    );
    final riderPoint = driver == null
        ? branchPoint
        : LatLng(
            (driver['current_latitude'] as num).toDouble(),
            (driver['current_longitude'] as num).toDouble(),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 360,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: branchPoint,
            initialZoom: 13,
            minZoom: 4,
            maxZoom: 19,
            onMapReady: () {
              mapReady = true;
              fitRoute();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: packageName,
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                if (remaining.length >= 2)
                  Polyline(
                    points: remaining,
                    color: Colors.grey.shade600,
                    strokeWidth: 6,
                    pattern: const StrokePattern.dotted(
                      spacingFactor: 1.8,
                      patternFit: PatternFit.appendDot,
                    ),
                  ),
                if (completed.length >= 2)
                  Polyline(
                    points: completed,
                    color: const Color(0xff173f35),
                    strokeWidth: 7,
                  ),
              ],
            ),
            if (driver != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: riderPoint,
                    radius: 45,
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(.16),
                    borderColor: Colors.blue.withOpacity(.55),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: branchPoint,
                  width: 48,
                  height: 48,
                  child: _mapMarker(
                    icon: Icons.store,
                    background: const Color(0xffffb547),
                    foreground: const Color(0xff173f35),
                    tooltip: '${branch['name']}',
                  ),
                ),
                Marker(
                  point: customerPoint,
                  width: 48,
                  height: 48,
                  child: _mapMarker(
                    icon: Icons.home,
                    background: const Color(0xffc62828),
                    foreground: Colors.white,
                    tooltip: 'Your doorstep',
                  ),
                ),
                if (driver != null)
                  Marker(
                    point: riderPoint,
                    width: 54,
                    height: 54,
                    child: _mapMarker(
                      icon: Icons.two_wheeler,
                      background: const Color(0xff1565c0),
                      foreground: Colors.white,
                      tooltip: 'Rider: ${driver['name']}',
                    ),
                  ),
              ],
            ),
            SimpleAttributionWidget(
              source: const Text('OpenStreetMap contributors'),
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
              backgroundColor: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapMarker({
    required IconData icon,
    required Color background,
    required Color foreground,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black38,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: foreground, size: 25),
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> current) {
    final driver = current['driver'];
    if (driver == null) {
      return const Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.person_search_outlined)),
          title: Text('Waiting for a rider'),
          subtitle: Text('The branch will assign a delivery rider after packing.'),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.two_wheeler)),
        title: Text('${driver['name']}'),
        subtitle: Text('${driver['vehicle_number']} · ${driver['phone']}'),
        trailing: IconButton.filledTonal(
          tooltip: 'Call rider',
          onPressed: () => launchUrl(Uri(scheme: 'tel', path: '${driver['phone']}')),
          icon: const Icon(Icons.call),
        ),
      ),
    );
  }

  Widget _deliveryDetails(Map<String, dynamic> order) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delivery details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _detail(Icons.home_outlined, '${order['delivery_address'] ?? ''}'),
              if ('${order['delivery_landmark'] ?? ''}'.isNotEmpty)
                _detail(Icons.place_outlined, '${order['delivery_landmark']}'),
              if ('${order['delivery_instructions'] ?? ''}'.isNotEmpty)
                _detail(Icons.notes_outlined, '${order['delivery_instructions']}'),
              _detail(Icons.schedule_outlined, '${order['delivery_slot'] ?? 'As soon as possible'}'),
              _detail(Icons.route_outlined, '${order['delivery_distance']} km · ${money(order['delivery_fee'])}'),
              if (order['contactless_delivery'] == true)
                _detail(Icons.door_front_door_outlined, 'Contactless delivery selected'),
            ],
          ),
        ),
      );

  Widget _detail(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _timeline(String currentStatus, bool delivery) {
    final steps = delivery
        ? const [
            ('pending', 'Order confirmed'),
            ('confirmed', 'Accepted by branch'),
            ('preparing', 'Preparing items'),
            ('ready', 'Packed and ready'),
            ('rider_assigned', 'Rider assigned'),
            ('out_for_delivery', 'Out for delivery'),
            ('rider_nearby', 'Rider nearby'),
            ('delivered', 'Delivered'),
          ]
        : const [
            ('pending', 'Order confirmed'),
            ('confirmed', 'Accepted by branch'),
            ('preparing', 'Preparing items'),
            ('ready', 'Ready for pickup'),
            ('delivered', 'Collected'),
          ];
    final currentIndex = steps.indexWhere((step) => step.$1 == currentStatus);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order progress', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...steps.indexed.map((entry) {
              final index = entry.$1;
              final step = entry.$2;
              final complete = currentStatus == 'delivered' || index < currentIndex;
              final active = index == currentIndex;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: complete || active
                            ? const Color(0xff173f35)
                            : Colors.grey.shade300,
                        child: Icon(
                          complete ? Icons.check : active ? Icons.circle : Icons.more_horiz,
                          size: 14,
                          color: complete || active ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                      if (index != steps.length - 1)
                        Container(
                          width: 2,
                          height: 34,
                          color: complete ? const Color(0xff173f35) : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      step.$2,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: complete || active ? Colors.black87 : Colors.black45,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
