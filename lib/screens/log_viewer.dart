import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_manager.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({Key? key}) : super(key: key);

  @override
  _LogViewerScreenState createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _logs = "";
  bool _isLoading = false;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _filter = "";

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text);
    });
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    _logs = await LogManager.instance.readLogs();
    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  List<String> get _filteredLogs {
    return _logs.split('\n').where((log) =>
        log.toLowerCase().contains(_filter.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _logs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Filter logs',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                ? const Center(child: Text('No logs found'))
                : Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _filteredLogs.length,
                itemBuilder: (context, index) {
                  final log = _filteredLogs[index];
                  return _LogEntryItem(log: log);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntryItem extends StatelessWidget {
  final String log;

  const _LogEntryItem({required this.log});

  Color _getEntryColor() {
    if (log.contains('ERROR')) return Colors.red[300]!;
    if (log.contains('WARNING')) return Colors.orange[300]!;
    if (log.contains('FILE')) return Colors.blue[300]!;
    if (log.contains('MSG')) return Colors.green[300]!;
    if (log.contains('CONN')) return Colors.purple[300]!;
    return Colors.grey[800]!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _getEntryColor(),
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: SelectableText(
        log,
        style: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 12,
        ),
      ),
    );
  }
  }
