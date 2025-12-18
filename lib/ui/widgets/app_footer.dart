import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade50,
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.hasData ? 'v${snapshot.data!.version}' : '';

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Developed by Shinto PC $version',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.phone, size: 14, color: Colors.black54),
              const SizedBox(width: 4),
              const Icon(Icons.chat, size: 14, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                '+91 9419927293',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
