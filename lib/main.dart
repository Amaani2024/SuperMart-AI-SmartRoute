import 'package:flutter/material.dart';

import 'src/api.dart';
import 'src/customer.dart';
import 'src/manager.dart';

void main() => runApp(const SuperMartApp());

class SuperMartApp extends StatefulWidget {
  const SuperMartApp({super.key});

  @override
  State<SuperMartApp> createState() => _SuperMartAppState();
}

class _SuperMartAppState extends State<SuperMartApp> {
  Map<String, dynamic>? user;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SuperMart AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff173f35),
          primary: const Color(0xff173f35),
          secondary: const Color(0xffffb547),
          surface: const Color(0xfff7f7f2),
        ),
        scaffoldBackgroundColor: const Color(0xfff7f7f2),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfff7f7f2),
          foregroundColor: Color(0xff173f35),
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xff173f35),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xffccefe4),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: const Color(0xff173f35),
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          shadowColor: Color(0x18000000),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xff173f35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      home: user == null
          ? LoginPage(onLogin: (value) => setState(() => user = value))
          : switch (user!['role']) {
              'manager' => ManagerShell(user: user!, onLogout: logout),
              'staff' => StaffShell(user: user!, onLogout: logout),
              _ => CustomerShell(user: user!, onLogout: logout),
            },
    );
  }

  void logout() {
    Api.token = null;
    setState(() => user = null);
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});
  final ValueChanged<Map<String, dynamic>> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(text: 'manager.a@supermart.com');
  final password = TextEditingController(text: 'password123');
  String selectedRole = 'manager';
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Api.post('/auth/login', {
        'email': email.text,
        'password': password.text,
        'role': selectedRole,
      });
      Api.token = result['token'];
      widget.onLogin(Map<String, dynamic>.from(result['user']));
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Color(0xffffb547),
                    child: Icon(
                      Icons.storefront,
                      size: 42,
                      color: Color(0xff173f35),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SuperMart AI',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff173f35),
                    ),
                  ),
                  const Text(
                    'Smarter branches. Easier shopping.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 34),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'customer',
                        icon: Icon(Icons.shopping_bag_outlined),
                        label: Text('Customer'),
                      ),
                      ButtonSegment(
                        value: 'staff',
                        icon: Icon(Icons.badge_outlined),
                        label: Text('Staff'),
                      ),
                      ButtonSegment(
                        value: 'manager',
                        icon: Icon(Icons.admin_panel_settings_outlined),
                        label: Text('Manager'),
                      ),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (value) {
                      final role = value.first;
                      setState(() => selectedRole = role);
                      email.text = switch (role) {
                        'manager' => 'manager.a@supermart.com',
                        'staff' => 'staff.a@supermart.com',
                        _ => 'hamdhan@customer.com',
                      };
                    },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    onSubmitted: (_) => login(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : login,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    child: loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (selectedRole != 'customer') {
                              showAccessHelp();
                              return;
                            }
                            final registered = await Navigator.of(context)
                                .push<Map<String, dynamic>>(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                            if (registered != null) {
                              widget.onLogin(registered);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                    ),
                    child: Text(switch (selectedRole) {
                      'manager' => 'Manager account access',
                      'staff' => 'Staff account access',
                      _ => 'Create customer account',
                    }),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Demo manager: manager.a@supermart.com\n'
                    'Demo staff: staff.a@supermart.com\n'
                    'Demo customer: hamdhan@customer.com\nPassword: password123',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showAccessHelp() {
    final manager = selectedRole == 'manager';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          manager ? Icons.admin_panel_settings : Icons.badge_outlined,
          color: const Color(0xff173f35),
          size: 38,
        ),
        title: Text(
          manager ? 'Manager account access' : 'Staff account access',
        ),
        content: Text(
          manager
              ? 'Manager accounts cannot be publicly registered because they '
                    'control staff, stock, orders and business insights. They '
                    'are provisioned by the system administrator.\n\n'
                    'Demo account:\nmanager.a@supermart.com\nPassword: password123'
              : 'Staff accounts cannot be publicly registered because they '
                    'can update branch orders, inventory and alerts. They are '
                    'provisioned by an authorized administrator or manager.\n\n'
                    'Demo account:\nstaff.a@supermart.com\nPassword: password123',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Api.post('/auth/register', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'password': password.text,
      });
      Api.token = result['token'];
      if (mounted) {
        Navigator.pop(context, Map<String, dynamic>.from(result['user']));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join SuperMart',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xff173f35),
                          ),
                    ),
                    const Text(
                      'Your profile is securely saved in the central database.',
                    ),
                    const SizedBox(height: 24),
                    _field(name, 'Full name', Icons.person_outline),
                    _field(
                      email,
                      'Email',
                      Icons.mail_outline,
                      keyboard: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    _field(
                      phone,
                      'Phone number',
                      Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                    ),
                    _field(
                      address,
                      'Delivery address',
                      Icons.location_on_outlined,
                      lines: 2,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: password,
                        obscureText: hidePassword,
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Use at least 8 characters'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => hidePassword = !hidePassword),
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: confirmPassword,
                        obscureText: hidePassword,
                        validator: (value) => value != password.text
                            ? 'Passwords do not match'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: loading ? null : register,
                      icon: const Icon(Icons.person_add),
                      label: Text(
                        loading ? 'Creating account…' : 'Create account',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int lines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        validator:
            validator ??
            (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}
