import 'package:flutter/material.dart';
import '../../../core/utils/size_formatter.dart';

class ConfirmationDialog extends StatelessWidget {
  final int itemCount;
  final int totalBytes;
  final VoidCallback onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.itemCount,
    required this.totalBytes,
    required this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context, {
    required int itemCount,
    required int totalBytes,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        itemCount: itemCount,
        totalBytes: totalBytes,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      title: const Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: Color(0xFFF44336)),
          SizedBox(width: 10),
          Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$itemCount item${itemCount == 1 ? '' : 's'} • ${SizeFormatter.format(totalBytes)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This action cannot be undone.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF44336),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
