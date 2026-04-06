import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Permissions'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_open_rounded,
                  color: AppColors.warning),
              title: const Text('Manage Storage Permission',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                  'Required on Android 11+ for full junk scan',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.open_in_new_rounded,
                  color: Colors.white38, size: 18),
              onTap: () => openAppSettings(),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                  title: const Text('Version',
                      style: TextStyle(color: Colors.white)),
                  trailing: const Text('1.0.0',
                      style: TextStyle(color: Colors.white54)),
                ),
                const Divider(height: 1, color: AppColors.divider),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded,
                      color: AppColors.primary),
                  title: const Text('Phone Cleaner',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Remove junk & duplicate files',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
