import 'package:flutter/material.dart';
import '../../../core/permissions/permission_service.dart';

class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when user returns from settings
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _checking = true);
    final has = await PermissionService.hasStoragePermission();
    if (mounted) setState(() {
      _hasPermission = has;
      _checking = false;
    });
  }

  Future<void> _requestPermission() async {
    await PermissionService.requestStoragePermission();
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasPermission) return widget.child;
    return _PermissionDeniedView(onRequest: _requestPermission);
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRequest;

  const _PermissionDeniedView({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.folder_off_rounded,
                size: 80,
                color: Colors.white38,
              ),
              const SizedBox(height: 24),
              const Text(
                'Storage Permission Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Phone Cleaner needs access to your storage to scan for junk files and duplicates.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: onRequest,
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
