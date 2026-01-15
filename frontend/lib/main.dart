import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/color_palette.dart';
import 'package:frontend/models/pod_offline_model.dart';
import 'package:frontend/provider/theme_provider.dart';
import 'package:frontend/splashscreen.dart';
import 'package:frontend/theme/text_styles.dart';
import 'package:hive_flutter/adapters.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Hive.initFlutter();

   Hive.registerAdapter(PodModelAdapter());

  // Open the box once at app startup
  await Hive.openBox<PodModel>('pendingPods');
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLightTheme = ref.watch(themeProvider);
    return MaterialApp(
      theme: isLightTheme
          ? ThemeData.from(colorScheme: lightColorScheme) // Use light theme
          : ThemeData.from(colorScheme: darkColorScheme), // Use dark theme
      home: const Splashscreen(),
      builder: (context, child) {
        AppTextStyles.init(context);
        return child!;
      }, // Start with the splash screen
      debugShowCheckedModeBanner: false,
    );
  }
}