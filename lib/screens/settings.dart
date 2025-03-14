import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _pathController;
  late String _downloadPath;

  @override
  void initState() {
    super.initState();
    _loadDownloadPath();
  }

  // Load the saved download path or use the default path
  _loadDownloadPath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedPath = prefs.getString('download_path');
    if (savedPath == null) {
      // Set default to /storage/emulated/0/Download/ if no saved path is found
      _downloadPath = '/storage/emulated/0/Download/ConnectX/';
      prefs.setString('download_path', _downloadPath);
    } else {
      _downloadPath = savedPath;
    }

    _pathController = TextEditingController(text: _downloadPath);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          ListTile(
            title: const Text('Download Path'),
            subtitle: Text(
              _downloadPath,
              maxLines: 1, // Ensure single line display
              overflow: TextOverflow.ellipsis, // Add ellipsis if the text overflows
            ),
            trailing: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () async {
                // Implement folder picker functionality here
                // For now, it's a placeholder.
              },
            ),
          ),
        ],
      ),
    );
  }
}
