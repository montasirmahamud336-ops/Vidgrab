import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _vpsUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vpsUrlController.text = ApiService.baseUrl;
  }

  void _saveServerUrl() async {
    final url = _vpsUrlController.text.trim();
    if (url.isNotEmpty) {
      await ApiService.saveBaseUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VPS Server URL saved!'), backgroundColor: Color(0xFFFACC15)),
      );
    }
  }

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

          // VPS Server URL Config
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                const Text('VPS Server URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Set your VPS domain or IP for backend API', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vpsUrlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'https://api.yourvps.com',
                          hintStyle: TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Color(0xFF27272A),
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15)),
                      onPressed: _saveServerUrl,
                      child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Download tools', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildSettingsTile(Icons.folder, 'Download Directory', '/storage/emulated/0/Download'),
          _buildSettingsTile(Icons.chat, 'WhatsApp Status Saver', 'Saved statuses'),
          _buildSettingsTile(Icons.cleaning_services, 'Junk Clean', '1.60 GB available'),
          _buildSettingsTile(Icons.shield, 'Vault & Private Folder', 'Protected'),

          const SizedBox(height: 20),
          const Text('Info', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildSettingsTile(Icons.info, 'About SnapTube Downloader', 'Version 1.0.0'),
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
