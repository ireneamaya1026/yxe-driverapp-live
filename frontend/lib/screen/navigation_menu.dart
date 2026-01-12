// navigation_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/notifiers/navigation_notifier.dart';
import 'package:frontend/theme/colors.dart';

class NavigationMenu extends ConsumerWidget {
  final Future<void> Function(int index)? onItemTap; // ✅ Custom callback for menu taps

  const NavigationMenu({super.key, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationNotifierProvider);

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey,
            width: 1,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: mainColor,
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(
                  color: Colors.white,
                  size: 30,
                );
              }
              return const IconThemeData(
                color: Colors.black,
                size: 24,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) async {
            // Update the selected index in Riverpod
            ref.read(navigationNotifierProvider.notifier).setSelectedIndex(value);

            // If a custom callback is provided, call it
            if (onItemTap != null) {
              await onItemTap!(value);
            } else {
              // Default navigation behavior
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          destinations: const [
            NavigationDestination(
              selectedIcon: Icon(Icons.receipt_long_rounded),
              icon: Icon(Icons.receipt_long_outlined),
              label: '',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.home),
              icon: Icon(Icons.home_outlined),
              label: '',
            ),
            NavigationDestination(
              selectedIcon: Icon(Icons.history_rounded),
              icon: Icon(Icons.history_outlined),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
