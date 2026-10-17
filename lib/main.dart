
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const GasGuardApp());

class GasGuardApp extends StatefulWidget {
  const GasGuardApp({super.key});

  @override
  State<GasGuardApp> createState() => _GasGuardAppState();
}

class _GasGuardAppState extends State<GasGuardApp> {
  ThemeMode mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GasGuard',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepOrange,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        home: GasGuardHome(
          onTheme: (dark) => setState(
            () => mode = dark ? ThemeMode.dark : ThemeMode.light,
          ),
        ),
      );
}

class GasGuardHome extends StatefulWidget {
  final void Function(bool) onTheme;

  const GasGuardHome({super.key, required this.onTheme});

  @override
  State<GasGuardHome> createState() => _GasGuardHomeState();
}

class _GasGuardHomeState extends State<GasGuardHome> {
  int tab = 0;
  bool loading = true;
  bool onboarded = false;
  double cylinder = 12.5;
  double remaining = 6.0;
  double daily = 0.35;

  double get percent =>
      (remaining / cylinder * 100).clamp(0, 100).toDouble();

  double get days => daily <= 0 ? 0 : remaining / daily;

  String get status =>
      percent <= 15 ? 'LOW' : percent <= 35 ? 'GETTING LOW' : 'GOOD';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      onboarded = p.getBool('onboarded') ?? false;
      cylinder = p.getDouble('cylinder') ?? 12.5;
      remaining = p.getDouble('remaining') ?? 6.0;
      daily = p.getDouble('daily') ?? 0.35;
      loading = false;
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', onboarded);
    await p.setDouble('cylinder', cylinder);
    await p.setDouble('remaining', remaining);
    await p.setDouble('daily', daily);
  }

  Future<void> finishOnboarding(
      double c, double r, double d) async {
    setState(() {
      cylinder = c > 0 ? c : 12.5;
      remaining = r.clamp(0, cylinder);
      daily = d.clamp(0.08, 2.0);
      onboarded = true;
    });
    await save();
  }

  Future<void> refill() async {
    final c = TextEditingController(text: cylinder.toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add refill'),
        content: TextField(
          controller: c,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Gas added',
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(c.text);
              if (v != null && v > 0) {
                setState(() {
                  remaining =
                      (remaining + v).clamp(0, cylinder);
                });
                await save();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> logCooking() async {
    final options = {
      'Light cooking': 0.12,
      'Normal cooking': 0.25,
      'Heavy cooking': 0.45,
    };

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.keys
              .map(
                (x) => ListTile(
                  leading: const Icon(
                    Icons.local_fire_department_outlined,
                  ),
                  title: Text(x),
                  onTap: () => Navigator.pop(context, x),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (choice == null) return;
    final used = options[choice]!;

    setState(() {
      remaining = (remaining - used).clamp(0, cylinder);
      daily = (daily * 0.8 + used * 0.2).clamp(0.08, 2.0);
    });
    await save();

    if (mounted && percent <= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GasGuard warning: gas level is low.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!onboarded) {
      return Onboarding(onDone: finishOnboarding);
    }

    final pages = [home(), usage(), settings()];

    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Usage',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget home() => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GasGuard',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Know before your gas runs out.'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      '${percent.round()}%',
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('${remaining.toStringAsFixed(1)} kg remaining'),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: percent <= 15
                            ? Colors.red
                            : percent <= 35
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: info(
                    'Estimated days',
                    days.toStringAsFixed(1),
                    Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: info(
                    'Daily use',
                    '${daily.toStringAsFixed(2)} kg',
                    Icons.speed_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: logCooking,
              icon: const Icon(Icons.restaurant),
              label: const Text('Log cooking'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: refill,
              icon: const Icon(Icons.add),
              label: const Text('Add refill'),
            ),
            if (percent <= 15)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const ListTile(
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('Gas is running low'),
                  subtitle: Text('Consider arranging a refill soon.'),
                ),
              ),
          ],
        ),
      );

  Widget info(String title, String value, IconData icon) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title),
            ],
          ),
        ),
      );

  Widget usage() => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Usage',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'GasGuard learns from your cooking logs to improve its estimate.',
            ),
            const SizedBox(height: 22),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated daily consumption',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${daily.toStringAsFixed(2)} kg/day',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          7,
                          (i) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: FractionallySizedBox(
                                heightFactor: 0.3 + ((i + 2) * 0.09 % 0.7),
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Tip: log cooking after using the stove. These are estimates, not direct measurements of gas inside the cylinder.',
                ),
              ),
            ),
          ],
        ),
      );

  Widget settings() => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.propane_tank_outlined),
                    title: const Text('Cylinder size'),
                    subtitle: Text('${cylinder.toStringAsFixed(1)} kg'),
                    onTap: editCylinder,
                  ),
                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: const Text('Daily gas usage'),
                    subtitle: Text('${daily.toStringAsFixed(2)} kg/day'),
                    onTap: editDaily,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark mode'),
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: widget.onTheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'GasGuard estimates remaining gas from refill and usage information. A physical weight sensor could provide more accurate readings in a future version.',
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> editCylinder() async {
    final c = TextEditingController(text: cylinder.toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cylinder size'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(c.text);
              if (v != null && v > 0) {
                setState(() {
                  cylinder = v;
                  remaining = remaining.clamp(0, v);
                });
                await save();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> editDaily() async {
    final c = TextEditingController(text: daily.toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Daily usage'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg/day'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(c.text);
              if (v != null && v > 0) {
                setState(() => daily = v.clamp(0.08, 2.0));
                await save();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class Onboarding extends StatefulWidget {
  final Future<void> Function(double, double, double) onDone;

  const Onboarding({super.key, required this.onDone});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  double cylinder = 12.5;
  double remaining = 6;
  double daily = 0.35;

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Welcome to GasGuard',
      'Cylinder size',
      'Gas remaining',
      'Daily usage',
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.local_fire_department,
                size: 76,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                titles[step],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                step == 0
                    ? 'Know before your gas runs out.'
                    : 'You can change this later in Settings.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (step == 1)
                field(cylinder, 'kg', (v) => cylinder = v),
              if (step == 2)
                field(remaining, 'kg', (v) => remaining = v),
              if (step == 3)
                field(daily, 'kg/day', (v) => daily = v),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  if (step < 3) {
                    setState(() => step++);
                  } else {
                    await widget.onDone(cylinder, remaining, daily);
                  }
                },
                child: Text(
                  step < 3 ? 'Continue' : 'Start using GasGuard',
                ),
              ),
              if (step > 0)
                TextButton(
                  onPressed: () => setState(() => step--),
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget field(
    double value,
    String suffix,
    void Function(double) change,
  ) {
    final c = TextEditingController(text: value.toString());
    return TextField(
      controller: c,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Enter value',
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final n = double.tryParse(v);
        if (n != null) change(n);
      },
    );
  }
}
