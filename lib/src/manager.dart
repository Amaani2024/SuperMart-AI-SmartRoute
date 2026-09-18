import 'package:flutter/material.dart';
import 'api.dart';

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key, required this.user, required this.onLogout});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class StaffShell extends StatefulWidget {
  const StaffShell({super.key, required this.user, required this.onLogout});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int index = 0;
  int unreadAlerts = 0;
  bool alertShown = false;
  late final String branch = '${widget.user['branch'] ?? 'A'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkAlerts());
  }

  Future<void> checkAlerts() async {
    try {
      final data = await Api.get('/manager/alerts/$branch');
      final alerts = data['alerts'] as List;
      if (!mounted) return;
      setState(() => unreadAlerts = alerts.length);
      if (alerts.isEmpty || alertShown) return;
      alertShown = true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.notifications_active,
            color: Color(0xffffa000),
            size: 36,
          ),
          title: Text(
            '${alerts.length} branch alert${alerts.length == 1 ? '' : 's'}',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: alerts.take(3).map<Widget>((alert) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(alert['message']),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => index = 2);
              },
              child: const Text('View alerts'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Stock/orders pages will expose a connection error if the API is down.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      StockPage(branch: branch),
      ManagerOrdersPage(branch: branch),
      AlertsPage(
        branch: branch,
        onCountChanged: (count) {
          if (count != unreadAlerts) setState(() => unreadAlerts = count);
        },
      ),
    ];
    const labels = ['Branch Stock', 'Order Fulfilment', 'Operational Alerts'];
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Chip(
              avatar: const Icon(Icons.badge_outlined, size: 18),
              label: Text('Staff · Branch $branch'),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
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
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Stock',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadAlerts > 0,
              label: Text('$unreadAlerts'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class _ManagerShellState extends State<ManagerShell> {
  int index = 0;
  int unreadAlerts = 0;
  bool alertShown = false;
  late String branch = '${widget.user['branch'] ?? 'A'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkAlerts());
  }

  Future<void> checkAlerts({bool showPopup = true}) async {
    try {
      final data = await Api.get('/manager/alerts/$branch');
      final alerts = data['alerts'] as List;
      if (!mounted) return;
      setState(() => unreadAlerts = alerts.length);
      if (showPopup && alerts.isNotEmpty && !alertShown) {
        alertShown = true;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.notifications_active,
              color: Color(0xffffa000),
              size: 36,
            ),
            title: Text(
              '${alerts.length} manager alert${alerts.length == 1 ? '' : 's'}',
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: alerts.take(3).map<Widget>((alert) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(alert['message']),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => index = 4);
                },
                child: const Text('View alerts'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // Other pages will display connection/authentication errors if needed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      InsightsPage(branch: branch),
      StockPage(branch: branch),
      StaffPage(branch: branch),
      ManagerOrdersPage(branch: branch),
      AlertsPage(
        branch: branch,
        onCountChanged: (count) {
          if (count != unreadAlerts) setState(() => unreadAlerts = count);
        },
      ),
    ];
    const labels = ['AI Insights', 'Inventory', 'Staff', 'Orders', 'Alerts'];
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text('Branch $branch')),
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
            icon: Icon(Icons.auto_graph),
            label: 'Insights',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Stock',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Staff',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadAlerts > 0,
              label: Text('$unreadAlerts'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.branch});
  final String branch;

  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: Api.get('/manager/insights/$branch'),
    builder: (data) {
      final kpi = Map<String, dynamic>.from(data['kpis']);
      final categories = List<Map<String, dynamic>>.from(
        (data['categories'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      return RefreshIndicator(
        onRefresh: () async => (context as Element).markNeedsBuild(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xff173f35),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI operations briefing',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    money(kpi['historical_income']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'historical gross income',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            IncomeForecastCard(branch: branch),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _Metric(
                  'Transactions',
                  '${kpi['transactions']}',
                  Icons.receipt,
                ),
                _Metric(
                  'Average basket',
                  '${kpi['average_basket_quantity']}',
                  Icons.shopping_bag,
                ),
                _Metric(
                  'Low stock',
                  '${kpi['low_stock_items']}',
                  Icons.warning_amber,
                ),
                _Metric(
                  'Model R²',
                  '${((kpi['model_r2'] as num) * 100).toStringAsFixed(1)}%',
                  Icons.psychology,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Rush-hour staffing',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...(data['rush_hours'] as List).map(
              (item) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.schedule)),
                  title: Text(
                    '${item['label']} · ${item['transactions']} transactions',
                  ),
                  subtitle: Text(
                    'Assign ${item['recommended_cashiers']} cashiers',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Category performance',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...categories.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    title: Text(item['name']),
                    subtitle: Text('${item['transactions']} transactions'),
                    trailing: Text(
                      money(item['income']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recommended actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            ...(data['recommendations'] as List).map(
              (text) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xffffa000),
                ),
                title: Text('$text'),
              ),
            ),
            const SizedBox(height: 20),
            const LoginActivityPanel(),
          ],
        ),
      );
    },
  );
}

class IncomeForecastCard extends StatefulWidget {
  const IncomeForecastCard({super.key, required this.branch});
  final String branch;

  @override
  State<IncomeForecastCard> createState() => _IncomeForecastCardState();
}

class _IncomeForecastCardState extends State<IncomeForecastCard> {
  final price = TextEditingController(text: '25.00');
  final quantity = TextEditingController(text: '5');
  final cost = TextEditingController(text: '3.00');
  final hour = TextEditingController(text: '14');
  String category = 'Food and beverages';
  Map<String, dynamic>? result;
  String? error;
  bool loading = false;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xfff0f8f5),
    child: ExpansionTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xffffb547),
        child: Icon(Icons.calculate_outlined, color: Color(0xff173f35)),
      ),
      title: const Text(
        'AI gross & estimated net calculator',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Use the trained XGBoost model for a transaction'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Product category',
                ),
                items:
                    const [
                      'Electronic accessories',
                      'Fashion accessories',
                      'Food and beverages',
                      'Health and beauty',
                      'Home and lifestyle',
                      'Sports and travel',
                    ].map((value) {
                      return DropdownMenuItem(value: value, child: Text(value));
                    }).toList(),
                onChanged: (value) => setState(() => category = value!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: field(price, 'Unit price', Icons.attach_money),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: field(quantity, 'Quantity', Icons.shopping_basket),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: field(
                      cost,
                      'Operating cost',
                      Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: field(hour, 'Hour (0–23)', Icons.schedule)),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : calculate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(loading ? 'Calculating…' : 'Calculate with AI'),
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: resultTile(
                        'Gross income',
                        money(result!['predicted_gross_income']),
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: resultTile(
                        'Estimated net',
                        money(result!['estimated_net_income']),
                        (result!['estimated_net_income'] as num) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result!['explanation'],
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget field(TextEditingController controller, String label, IconData icon) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );

  Widget resultTile(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Future<void> calculate() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Api.post('/manager/forecast', {
        'branch': widget.branch,
        'customer_type': 'Member',
        'gender': 'Female',
        'product_line': category,
        'unit_price': double.tryParse(price.text),
        'quantity': int.tryParse(quantity.text),
        'payment': 'Ewallet',
        'rating': 7.0,
        'hour': int.tryParse(hour.text),
        'is_weekend': 0,
        'day_num': 2,
        'month_num': DateTime.now().month,
        'operating_cost': double.tryParse(cost.text),
      });
      if (mounted) setState(() => result = response);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.toString().replaceFirst('Exception: ', '');
          result = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class LoginActivityPanel extends StatelessWidget {
  const LoginActivityPanel({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Authentication activity',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Recent attempts; this is an audit trail, not an active-user counter.',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 280,
        child: AsyncPanel(
          future: Api.get('/manager/login-activity?limit=20'),
          builder: (data) {
            final events = data['events'] as List;
            if (events.isEmpty) {
              return const Card(
                child: Center(child: Text('No login activity yet')),
              );
            }
            return Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: events.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final event = events[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      event['success'] ? Icons.verified_user : Icons.gpp_bad,
                      color: event['success'] ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      event['name'].toString().isNotEmpty
                          ? event['name']
                          : event['email'],
                    ),
                    subtitle: Text(
                      '${event['role'] ?? 'unknown'} · '
                      '${event['success'] ? 'Successful' : 'Failed'} · '
                      '${event['created_at']}',
                    ),
                    trailing: Text(
                      event['branch'] == null
                          ? ''
                          : 'Branch ${event['branch']}',
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff173f35)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class StockPage extends StatefulWidget {
  const StockPage({super.key, required this.branch});
  final String branch;
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late Future<Map<String, dynamic>> future = Api.get(
    '/manager/stock/${widget.branch}',
  );
  void reload() =>
      setState(() => future = Api.get('/manager/stock/${widget.branch}'));
  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: future,
    builder: (data) => RefreshIndicator(
      onRefresh: () async => reload(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: (data['stock'] as List).length,
        itemBuilder: (_, i) {
          final item = data['stock'][i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item['is_low']
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  child: Icon(
                    Icons.inventory_2,
                    color: item['is_low'] ? Colors.red : Colors.green,
                  ),
                ),
                title: Text(item['product_name']),
                subtitle: Text(
                  '${item['category']} · Minimum ${item['min_quantity']}',
                ),
                trailing: Text(
                  '${item['quantity']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _update(context, item),
              ),
            ),
          );
        },
      ),
    ),
  );
  Future<void> _update(BuildContext context, dynamic item) async {
    final controller = TextEditingController(text: '${item['quantity']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${item['product_name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Api.post('/manager/stock/update', {
        'product_id': item['product_id'],
        'branch': widget.branch,
        'quantity': int.tryParse(controller.text) ?? item['quantity'],
      });
      reload();
    }
  }
}

class StaffPage extends StatefulWidget {
  const StaffPage({super.key, required this.branch});
  final String branch;

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() =>
      setState(() => future = Api.get('/manager/staff/${widget.branch}'));

  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: future,
    builder: (data) {
      final staff = data['staff'] as List;
      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff173f35), Color(0xff28705e)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xffffb547),
                    child: Icon(Icons.groups, color: Color(0xff173f35)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${staff.length} active staff',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Branch ${widget.branch} team',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: addStaff,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffffb547),
                      foregroundColor: const Color(0xff173f35),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (staff.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: Text('No active staff assigned')),
                ),
              )
            else
              ...staff.map<Widget>(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xffe2f3ed),
                        child: Icon(Icons.badge, color: Color(0xff173f35)),
                      ),
                      title: Text(
                        item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item['role']} · ${item['shift']} shift\n'
                        '${item['shift_start']} – ${item['shift_end']}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Remove staff',
                        onPressed: () => removeStaff(item),
                        icon: const Icon(
                          Icons.person_remove,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> addStaff() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AddStaffDialog(branch: widget.branch),
    );
    if (added == true) {
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member assigned successfully')),
        );
      }
    }
  }

  Future<void> removeStaff(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_remove, color: Colors.red),
        title: Text('Remove ${item['name']}?'),
        content: const Text(
          'They will become inactive, but their historical record is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Api.post('/manager/staff/update', {
      'staff_id': item['id'],
      'is_active': false,
    });
    reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item['name']} removed from active staff')),
      );
    }
  }
}

class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key, required this.branch});
  final String branch;

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  String role = 'Cashier';
  String shift = 'Morning';
  bool saving = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Assign staff · Branch ${widget.branch}'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items:
                    ['Cashier', 'Supervisor', 'Stock Clerk', 'Delivery Staff']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => role = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: shift,
                decoration: const InputDecoration(labelText: 'Shift'),
                items: ['Morning', 'Evening', 'Night']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => shift = value!),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: saving ? null : save,
        icon: const Icon(Icons.person_add),
        label: Text(saving ? 'Assigning…' : 'Assign'),
      ),
    ],
  );

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final times = switch (shift) {
      'Evening' => ('14:00', '22:00'),
      'Night' => ('22:00', '06:00'),
      _ => ('08:00', '16:00'),
    };
    try {
      await Api.post('/manager/staff/add', {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'role': role,
        'branch': widget.branch,
        'shift': shift,
        'shift_start': times.$1,
        'shift_end': times.$2,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.red),
        );
        setState(() => saving = false);
      }
    }
  }
}

// ignore: unused_element
class _LegacyStaffPage extends StatelessWidget {
  const _LegacyStaffPage({required this.branch});
  final String branch;
  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: Api.get('/manager/staff/$branch'),
    builder: (data) => ListView(
      padding: const EdgeInsets.all(16),
      children: (data['staff'] as List)
          .map<Widget>(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(item['name']),
                  subtitle: Text('${item['role']} · ${item['shift']} shift'),
                  trailing: Text(
                    '${item['shift_start']}\n${item['shift_end']}',
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class ManagerOrdersPage extends StatefulWidget {
  const ManagerOrdersPage({super.key, required this.branch});
  final String branch;
  @override
  State<ManagerOrdersPage> createState() => _ManagerOrdersPageState();
}

class _ManagerOrdersPageState extends State<ManagerOrdersPage> {
  late Future<Map<String, dynamic>> future = Api.get(
    '/orders/branch/${widget.branch}',
  );
  void reload() =>
      setState(() => future = Api.get('/orders/branch/${widget.branch}'));
  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: future,
    builder: (data) => ListView(
      padding: const EdgeInsets.all(16),
      children: (data['orders'] as List)
          .map<Widget>(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text(
                    'Order #${order['id']} · ${order['customer_name']}',
                  ),
                  subtitle: Text(
                    '${order['order_type']} · ${order['status']}\n${order['created_at']}',
                  ),
                  trailing: Text(
                    money(order['total_amount']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _status(context, order),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
  Future<void> _status(BuildContext context, dynamic order) async {
    final delivery = order['order_type'] == 'delivery';
    final values = delivery
        ? const [
            'confirmed',
            'preparing',
            'ready',
            'rider_assigned',
            'out_for_delivery',
            'rider_nearby',
            'cancelled',
          ]
        : const [
            'confirmed',
            'preparing',
            'ready',
            'delivered',
            'cancelled',
          ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Update order progress',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...values.map(
              (value) => ListTile(
                leading: Icon(
                  value == 'rider_assigned'
                      ? Icons.person_pin_circle_outlined
                      : value == 'out_for_delivery'
                          ? Icons.two_wheeler
                          : value == 'rider_nearby'
                              ? Icons.notifications_active_outlined
                              : Icons.arrow_forward,
                ),
                title: Text(value.replaceAll('_', ' ').toUpperCase()),
                onTap: () => Navigator.pop(context, value),
              ),
            ),
            if (delivery && order['driver_id'] != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('VERIFY DELIVERY PIN'),
                subtitle: const Text('Use this only after the customer receives the order.'),
                onTap: () => Navigator.pop(context, '__verify_pin__'),
              ),
            ],
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      if (selected == '__verify_pin__') {
        final pin = await _askForPin(context);
        if (pin == null || pin.isEmpty) return;
        await Api.post('/orders/verify-delivery-pin', {
          'order_id': order['id'],
          'pin': pin,
        });
      } else {
        await Api.post('/orders/update-status', {
          'order_id': order['id'],
          'status': selected,
        });
      }
      reload();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$exception')),
        );
      }
    }
  }

  Future<String?> _askForPin(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer delivery PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '4-digit PIN',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({
    super.key,
    required this.branch,
    required this.onCountChanged,
  });
  final String branch;
  final ValueChanged<int> onCountChanged;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() =>
      setState(() => future = Api.get('/manager/alerts/${widget.branch}'));

  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: future,
    builder: (data) {
      final alerts = data['alerts'] as List;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCountChanged(alerts.length),
      );
      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: alerts.isEmpty
                    ? const Color(0xffe2f3ed)
                    : const Color(0xfffff1db),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    alerts.isEmpty
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    size: 34,
                    color: alerts.isEmpty
                        ? Colors.green
                        : Colors.orange.shade900,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      alerts.isEmpty
                          ? 'All caught up — no unread alerts'
                          : '${alerts.length} alert${alerts.length == 1 ? '' : 's'} need attention',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Column(
                  children: [
                    Icon(Icons.task_alt, size: 64, color: Colors.green),
                    SizedBox(height: 12),
                    Text('Your branch is running smoothly'),
                  ],
                ),
              )
            else
              ...alerts.map<Widget>(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xfffff3df),
                        child: Icon(
                          alertIcon(item['type']),
                          color: Colors.orange.shade900,
                        ),
                      ),
                      title: Text(
                        item['message'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item['type'].toString().replaceAll('_', ' ')} · '
                        '${item['created_at']}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => markRead(item),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  IconData alertIcon(String type) => switch (type) {
    'low_stock' => Icons.inventory_2_outlined,
    'peak_hour' => Icons.schedule,
    'staff_needed' => Icons.person_add_alt,
    _ => Icons.insights,
  };

  Future<void> markRead(dynamic item) async {
    await Api.post('/manager/alerts/read', {'alert_id': item['id']});
    reload();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert marked as resolved')));
    }
  }
}

// ignore: unused_element
class _LegacyAlertsPage extends StatelessWidget {
  const _LegacyAlertsPage({required this.branch});
  final String branch;
  @override
  Widget build(BuildContext context) => AsyncPanel(
    future: Api.get('/manager/alerts/$branch'),
    builder: (data) => ListView(
      padding: const EdgeInsets.all(16),
      children: (data['alerts'] as List)
          .map<Widget>(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xfffff3df),
                    child: Icon(Icons.notifications_active),
                  ),
                  title: Text(item['message']),
                  subtitle: Text('${item['type']} · ${item['created_at']}'),
                  onTap: () => Api.post('/manager/alerts/read', {
                    'alert_id': item['id'],
                  }),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}
