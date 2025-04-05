import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // To get system default name
import '../provider/theme_provider.dart';
import '../services/log_manager.dart';
import 'log_viewer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late TextEditingController _deviceNameController;
  late SharedPreferences _prefs;
  bool _isEditingDeviceName = false;
  late FocusNode _deviceNameFocusNode;

  @override
  void initState() {
    super.initState();
    _deviceNameFocusNode = FocusNode();
    _loadSettings();
  }

  @override
  void dispose() {
    _deviceNameFocusNode.dispose();
    super.dispose();
  }

  _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    String? storedDeviceName = _prefs.getString('userName');
    String systemDeviceName = Platform.localHostname;
    _deviceNameController = TextEditingController(
      text: storedDeviceName ?? systemDeviceName,
    );

    setState(() {});
  }

  _saveDeviceName() async {
    await _prefs.setString('userName', _deviceNameController.text);
    setState(() {
      _isEditingDeviceName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device name saved successfully!')),
    );
  }

  _toggleEditDeviceName() {
    setState(() {
      if (_isEditingDeviceName) {
        _saveDeviceName();
      } else {
        _isEditingDeviceName = true;
        _deviceNameFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Device Name",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.device_hub, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _deviceNameController,
                        focusNode: _deviceNameFocusNode,
                        decoration: const InputDecoration(border: InputBorder.none),
                        readOnly: !_isEditingDeviceName,
                        autofocus: _isEditingDeviceName,
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: (value) {
                          _saveDeviceName();
                        },
                        onEditingComplete: () {
                          _saveDeviceName();
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isEditingDeviceName ? Icons.check : Icons.edit,
                        color: _isEditingDeviceName ? Colors.green : Colors.blueAccent,
                      ),
                      onPressed: _toggleEditDeviceName,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),

            const Text(
              "Download Path",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "/storage/emulated/0/Download/ConnectX/",
                        style: const TextStyle(fontSize: 14),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),

            const Text(
              "Performance Logs",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.analytics, color: Colors.teal.shade400),
                title: Text('View Logs', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogViewerScreen()),
                  );
                },
              ),
            ),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('Clear Logs', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.clear, size: 20),
                onTap: () async {
                  await LogManager.instance.clearLogs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logs cleared successfully')),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),

            const Text(
              "Appearance",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: isDarkMode ? Colors.orangeAccent : Colors.blueAccent,
                ),
                title: const Text('Dark Mode', style: TextStyle(fontSize: 14)),
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (bool value) {
                    themeProvider.toggleTheme();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}