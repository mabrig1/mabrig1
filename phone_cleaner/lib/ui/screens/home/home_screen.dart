import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/size_formatter.dart';
import '../../../data/models/storage_info.dart';
import '../../../providers/storage_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(storageInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Cleaner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(storageInfoProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              storageAsync.when(
                data: (info) => _StorageCard(info: info),
                loading: () => const _StorageCardSkeleton(),
                error: (_, __) => const _StorageCardError(),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
              const SizedBox(height: 24),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.cleaning_services_rounded,
                title: 'Junk Cleaner',
                subtitle: 'Remove cache, temp & log files',
                color: AppColors.primary,
                onTap: () => context.push('/junk'),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideX(begin: -0.1, end: 0),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.copy_all_rounded,
                title: 'Duplicate Finder',
                subtitle: 'Find & remove duplicate files',
                color: AppColors.secondary,
                onTap: () => context.push('/duplicates'),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideX(begin: -0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  final StorageInfo info;
  const _StorageCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Storage',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            CircularPercentIndicator(
              radius: 90,
              lineWidth: 14,
              percent: info.usedPercent.clamp(0.0, 1.0),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(info.usedPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Used',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              progressColor: AppColors.gaugeUsed,
              backgroundColor: AppColors.gaugeFree,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 800,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StorageStat(
                  label: 'Used',
                  value: SizeFormatter.format(info.usedBytes),
                  color: AppColors.gaugeUsed,
                ),
                Container(width: 1, height: 32, color: AppColors.divider),
                _StorageStat(
                  label: 'Free',
                  value: SizeFormatter.format(info.freeBytes),
                  color: Colors.white70,
                ),
                Container(width: 1, height: 32, color: AppColors.divider),
                _StorageStat(
                  label: 'Total',
                  value: SizeFormatter.format(info.totalBytes),
                  color: Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StorageStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _StorageCardSkeleton extends StatelessWidget {
  const _StorageCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StorageCardError extends StatelessWidget {
  const _StorageCardError();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Unable to load storage info',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
