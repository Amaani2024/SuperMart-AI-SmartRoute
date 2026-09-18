import 'package:flutter/material.dart';
import 'api.dart';
import 'delivery_location_page.dart';
import 'delivery_tracking_page.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.user, required this.onLogout});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int index = 0;
  int orderVersion = 0;
  String branch = 'A';
  final Map<int, Map<String, dynamic>> cart = {};

  void add(dynamic product) {
    setState(() {
      final id = product['id'] as int;
      cart[id] = {
        ...Map<String, dynamic>.from(product),
        'qty': (cart[id]?['qty'] ?? 0) + 1,
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} added'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ShopPage(
        branch: branch,
        onBranch: (v) => setState(() => branch = v),
        onAdd: add,
      ),
      OffersPage(customerId: widget.user['id'], onAdd: add),
      CartPage(
        user: widget.user,
        branch: branch,
        cart: cart,
        onChanged: () => setState(() {}),
        onBranchChanged: (value) => setState(() => branch = value),
        onPlaced: () => setState(() {
          cart.clear();
          orderVersion++;
          index = 3;
        }),
      ),
      OrdersPage(key: ValueKey(orderVersion), customerId: widget.user['id']),
      AssistantPage(branch: branch, onAdd: add),
    ];
    const labels = ['Shop', 'AI Offers', 'Cart', 'My Orders', 'Assistant'];
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[index]),
        actions: [
          IconButton(
            tooltip: 'Account and cloud connection',
            onPressed: showAccount,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            label: 'Offers',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text(
                '${cart.values.fold<int>(0, (sum, e) => sum + e['qty'] as int)}',
              ),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Assistant',
          ),
        ],
      ),
    );
  }

  void showAccount() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _accountRow(Icons.person_outline, '${widget.user['name']}'),
              _accountRow(Icons.mail_outline, '${widget.user['email']}'),
              _accountRow(
                Icons.phone_outlined,
                '${widget.user['phone'] ?? 'Not provided'}',
              ),
              _accountRow(
                Icons.location_on_outlined,
                '${widget.user['address'] ?? 'Not provided'}',
              ),
              const Divider(height: 28),
              const Text(
                'Connected API',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                Api.baseUrl,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const Text(
                'Profile and orders are loaded from the central SQL database.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountRow(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xff173f35)),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class ShopPage extends StatefulWidget {
  const ShopPage({
    super.key,
    required this.branch,
    required this.onBranch,
    required this.onAdd,
  });
  final String branch;
  final ValueChanged<String> onBranch;
  final ValueChanged<dynamic> onAdd;
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String search = '', category = '';
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ShopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branch != widget.branch) load();
  }

  void load() => future = Api.get('/products?branch=${widget.branch}');
  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: future,
    builder: (data) {
      final categories = List<String>.from(data['categories']);
      final products = (data['products'] as List)
          .where(
            (p) =>
                (category.isEmpty || p['category'] == category) &&
                '${p['name']}'.toLowerCase().contains(search.toLowerCase()),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xff173f35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your nearest branch',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'A', label: Text('A')),
                    ButtonSegment(value: 'B', label: Text('B')),
                    ButtonSegment(value: 'C', label: Text('C')),
                  ],
                  selected: {widget.branch},
                  onSelectionChanged: (value) => widget.onBranch(value.first),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? const Color(0xff173f35)
                          : Colors.white,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? const Color(0xffffb547)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['', ...categories]
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(item.isEmpty ? 'All' : item),
                        selected: category == item,
                        onSelected: (_) => setState(() => category = item),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          ...products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xfffff3df),
                        child: Icon(
                          _categoryIcon(p['category']),
                          color: const Color(0xff173f35),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              p['category'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '${money(p['price'])} · ${p['stock_qty']} available',
                              style: TextStyle(
                                color: p['in_stock']
                                    ? Colors.green.shade700
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        onPressed: p['in_stock'] ? () => widget.onAdd(p) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

IconData _categoryIcon(String category) {
  if (category.startsWith('Food')) return Icons.fastfood;
  if (category.startsWith('Electronic')) return Icons.devices;
  if (category.startsWith('Fashion')) return Icons.checkroom;
  if (category.startsWith('Health')) return Icons.health_and_safety;
  if (category.startsWith('Home')) return Icons.home;
  return Icons.sports_basketball;
}

class OffersPage extends StatelessWidget {
  const OffersPage({super.key, required this.customerId, required this.onAdd});
  final int customerId;
  final ValueChanged<dynamic> onAdd;
  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: Api.get('/customer/offers/$customerId'),
    builder: (data) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Selected for you',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text('Based on your ${data['preferred_category']} shopping'),
        const SizedBox(height: 16),
        ...(data['offers'] as List).map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xffffb547),
                  child: Icon(Icons.percent, color: Color(0xff173f35)),
                ),
                title: Text(p['name']),
                subtitle: Text(
                  '${p['reason']}\n${money(p['price'])}  →  ${money(p['offer_price'])}',
                ),
                isThreeLine: true,
                trailing: IconButton.filled(
                  onPressed: () => onAdd(p),
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.user,
    required this.branch,
    required this.cart,
    required this.onChanged,
    required this.onBranchChanged,
    required this.onPlaced,
  });

  final Map<String, dynamic> user;
  final String branch;
  final Map<int, Map<String, dynamic>> cart;
  final VoidCallback onChanged;
  final ValueChanged<String> onBranchChanged;
  final VoidCallback onPlaced;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const deliverySlots = [
    'asap',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '2:00 PM - 3:00 PM',
    '6:00 PM - 7:00 PM',
  ];

  bool delivery = true;
  bool loading = false;
  bool smartLoading = false;
  DeliveryLocationData? location;
  Map<String, dynamic>? recommendation;
  Map<String, dynamic>? quote;
  String selectedSlot = 'asap';

  double get subtotal => widget.cart.values.fold<double>(
        0,
        (sum, item) => sum + (item['price'] as num) * (item['qty'] as int),
      );

  double get deliveryFee => ((quote?['delivery_fee'] ?? 0) as num).toDouble();

  Future<void> selectDeliveryLocation() async {
    final result = await Navigator.push<DeliveryLocationData>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryLocationPage(
          initialAddress: '${widget.user['address'] ?? ''}',
          initialLocation: location,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => location = result);
    await refreshSmartDelivery();
  }

  Future<void> refreshSmartDelivery() async {
    final currentLocation = location;
    if (currentLocation == null || widget.cart.isEmpty || smartLoading) return;
    setState(() => smartLoading = true);
    try {
      final items = widget.cart.values
          .map((item) => {
                'product_id': item['id'],
                'quantity': item['qty'],
              })
          .toList();
      final result = await Api.post('/delivery/recommend-branch', {
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'items': items,
      });
      final recommended = Map<String, dynamic>.from(result['recommended']);
      final recommendedBranch = '${recommended['branch']}';
      widget.onBranchChanged(recommendedBranch);

      final calculation = await Api.post('/delivery/calculate', {
        'branch': recommendedBranch,
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'subtotal': subtotal,
        'delivery_slot': selectedSlot,
      });
      if (!mounted) return;
      setState(() {
        recommendation = recommended;
        quote = Map<String, dynamic>.from(calculation['quote']);
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$exception')),
        );
      }
    } finally {
      if (mounted) setState(() => smartLoading = false);
    }
  }

  void cartChanged() {
    widget.onChanged();
    if (location != null) refreshSmartDelivery();
  }

  @override
  Widget build(BuildContext context) {
    final tax = subtotal * .05;
    final total = subtotal + tax + (delivery ? deliveryFee : 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.cart.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 100),
            child: Column(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 70),
                SizedBox(height: 12),
                Text('Your cart is empty'),
              ],
            ),
          )
        else ...[
          ...widget.cart.values.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(item['name']),
                  subtitle: Text('${money(item['price'])} × ${item['qty']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (item['qty'] == 1) {
                            widget.cart.remove(item['id']);
                          } else {
                            item['qty']--;
                          }
                          cartChanged();
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        onPressed: () {
                          item['qty']++;
                          cartChanged();
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.local_shipping),
                label: Text('Delivery'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.store),
                label: Text('Pickup'),
              ),
            ],
            selected: {delivery},
            onSelectionChanged: (value) => setState(() => delivery = value.first),
          ),
          if (delivery) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.location_on_outlined)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Doorstep GPS location',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('Select the exact gate or doorstep on the map.'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: selectDeliveryLocation,
                          child: Text(location == null ? 'Select' : 'Change'),
                        ),
                      ],
                    ),
                    if (location != null) ...[
                      const Divider(height: 24),
                      Text(location!.address),
                      if (location!.landmark.isNotEmpty)
                        Text(
                          'Landmark: ${location!.landmark}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      Text(
                        '${location!.latitude.toStringAsFixed(5)}, '
                        '${location!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (location!.contactless)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Chip(
                            avatar: Icon(Icons.door_front_door_outlined, size: 18),
                            label: Text('Contactless delivery'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (smartLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (recommendation != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffffb547),
                    child: Icon(Icons.auto_awesome, color: Color(0xff173f35)),
                  ),
                  title: Text(
                    'Recommended: ${recommendation!['branch_name']} '
                    '(Branch ${recommendation!['branch']})',
                  ),
                  subtitle: Text(
                    '${recommendation!['distance_km']} km · '
                    '${recommendation!['estimated_minutes']} minutes\n'
                    '${recommendation!['reason']}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedSlot,
              decoration: const InputDecoration(
                labelText: 'Delivery time slot',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              items: deliverySlots
                  .map(
                    (slot) => DropdownMenuItem(
                      value: slot,
                      child: Text(slot == 'asap' ? 'As soon as possible' : slot),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() => selectedSlot = value);
                if (location != null) await refreshSmartDelivery();
              },
            ),
            if (quote != null) ...[
              const SizedBox(height: 8),
              Text(
                'Smart suggestion: ${quote!['recommended_slot']} — '
                '${quote!['slot_reason']}',
                style: const TextStyle(color: Color(0xff173f35)),
              ),
            ],
          ],
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _total('Subtotal', subtotal),
                  _total('Tax (5%)', tax),
                  if (delivery)
                    _total(
                      quote == null
                          ? 'Delivery fee'
                          : 'Delivery · ${quote!['distance_km']} km',
                      deliveryFee,
                    ),
                  if (delivery && (quote?['slot_discount'] ?? 0) != 0)
                    Text(
                      'Includes Rs. ${quote!['slot_discount']} time-slot discount',
                      style: const TextStyle(color: Colors.green),
                    ),
                  const Divider(),
                  _total('Total', total, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: loading || smartLoading ? null : place,
            icon: const Icon(Icons.lock),
            label: Text(loading ? 'Placing order…' : 'Place order'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ],
    );
  }

  Widget _total(String label, num value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
            Text(
              money(value),
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ],
        ),
      );

  Future<void> place() async {
    if (delivery && location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the doorstep GPS location')),
      );
      return;
    }
    if (delivery && quote == null) {
      await refreshSmartDelivery();
      if (quote == null) return;
    }

    setState(() => loading = true);
    try {
      final currentLocation = location;
      await Api.post('/orders/place', {
        'customer_id': widget.user['id'],
        'branch': widget.branch,
        'order_type': delivery ? 'delivery' : 'pickup',
        if (delivery && currentLocation != null) ...currentLocation.toJson(),
        if (delivery) 'delivery_slot': selectedSlot,
        'items': widget.cart.values
            .map((item) => {
                  'product_id': item['id'],
                  'quantity': item['qty'],
                })
            .toList(),
      });
      widget.onPlaced();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$exception')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.customerId});

  final int customerId;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<Map<String, dynamic>> future = loadOrders();

  Future<Map<String, dynamic>> loadOrders() =>
      Api.get('/orders/customer/${widget.customerId}');

  Future<void> refresh() async {
    setState(() => future = loadOrders());
    await future;
  }

  @override
  Widget build(BuildContext context) => AsyncPanel(
        future: future,
        builder: (data) {
          final orders = data['orders'] as List;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 70),
                        SizedBox(height: 12),
                        Text('No orders yet'),
                      ],
                    ),
                  ),
                ...orders.map<Widget>(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryTrackingPage(
                              orderId: order['id'] as int,
                            ),
                          ),
                        ).then((_) => refresh()),
                        leading: CircleAvatar(
                          child: Icon(
                            order['order_type'] == 'delivery'
                                ? Icons.local_shipping
                                : Icons.store,
                          ),
                        ),
                        title: Text(
                          'Order #${order['id']} · ${money(order['total_amount'])}',
                        ),
                        subtitle: Text(
                          '${order['status'].toString().replaceAll('_', ' ').toUpperCase()}\n'
                          '${order['items'].length} item(s) · ${order['created_at']}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, required this.branch, required this.onAdd});
  final String branch;
  final ValueChanged<dynamic> onAdd;
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final input = TextEditingController();
  final List<Map<String, dynamic>> messages = [
    {
      'assistant': true,
      'text':
          'Hi! I can find products, explain offers, and help with delivery.',
    },
  ];
  bool loading = false;
  Future<void> send() async {
    final value = input.text.trim();
    if (value.isEmpty) return;
    setState(() {
      messages.add({'assistant': false, 'text': value});
      loading = true;
    });
    input.clear();
    try {
      final data = await Api.post('/assistant', {
        'message': value,
        'branch': widget.branch,
      });
      setState(
        () => messages.add({
          'assistant': true,
          'text': data['answer'],
          'products': data['products'],
        }),
      );
    } catch (e) {
      setState(() => messages.add({'assistant': true, 'text': '$e'}));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final message = messages[i],
                assistant = message['assistant'] as bool;
            return Align(
              alignment: assistant
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: assistant ? Colors.white : const Color(0xff173f35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['text'],
                      style: TextStyle(
                        color: assistant ? Colors.black87 : Colors.white,
                      ),
                    ),
                    ...((message['products'] ?? []) as List).map(
                      (p) => TextButton.icon(
                        onPressed: () => widget.onAdd(p),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text('${p['name']} · ${money(p['price'])}'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  onSubmitted: (_) => send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask your shopping assistant…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: loading ? null : send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
