import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('General', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildSettingsTile(Icons.verified_user, 'Cloud Engine Status', 'Encrypted & Active'),
          _buildSettingsTile(Icons.folder, 'Download Directory', '/storage/emulated/0/Download'),

          const SizedBox(height: 20),
          const Text('Download tools', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildSettingsTile(Icons.chat, 'WhatsApp Status Saver', 'Saved statuses'),
          _buildSettingsTile(Icons.cleaning_services, 'Junk Clean', '1.60 GB available'),
          _buildSettingsTile(Icons.shield, 'Vault & Private Folder', 'Protected'),

          const SizedBox(height: 20),
          const Text('Info', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildSettingsTile(Icons.info, 'About VidGrab Downloader', 'Version 1.0.0 (VidGrab Official)'),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFACC15)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
