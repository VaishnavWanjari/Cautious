import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/local_store.dart';
import 'data/seed_data.dart';
import 'features/home_shell.dart';
import 'features/onboarding_screen.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.create();

  // First launch: seed the Vaishnav & Shefali demo configuration so the app
  // demonstrates full personalization out of the box.
  if (!store.onboarded && store.loadProfile() == null) {
    await store.saveProfile(SeedData.demoProfile());
    await store.saveVendors(SeedData.demoVendors());
    await store.saveBudget(SeedData.demoBudget());
    await store.saveShopping(SeedData.demoShopping());
    await store.saveGuests(SeedData.demoGuests());
  }

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const SvWeddingApp(),
    ),
  );
}

class SvWeddingApp extends ConsumerWidget {
  const SvWeddingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(localStoreProvider).onboarded;
    return MaterialApp(
      title: 'SV Wedding Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
