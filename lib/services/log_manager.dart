import 'dart:async';
import 'dart:io';
import 'dart:math'; // Added for log() and pow()
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

enum LogLevel { Debug, Info, Warning, Error }

class LogManager {
  static final LogManager _instance = LogManager._internal();
  factory LogManager() => _instance;
  LogManager._internal();
  static LogManager get instance => _instance;

  // Configuration
  static const int _maxFileSize = 1024 * 1024 * 5; // 5MB
  static const int _bufferFlushSize = 5;
  final List<String> _logBuffer = [];
  final Lock _writeLock = Lock();
  bool _isWriting = false;

  //========================
  // Core Logging Methods
  //========================
  Future<String> _getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/connectx_logs.txt';
  }

  Future<void> _flushBuffer() async {
    if (_logBuffer.isEmpty || _isWriting) return;
    _isWriting = true;

    final logsToWrite = _logBuffer.join('\n');
    _logBuffer.clear();

    await _writeLock.synchronized(() async {
      try {
        await _rotateLogsIfNeeded();
        final file = File(await _getLogFilePath());
        await file.writeAsString('$logsToWrite\n', mode: FileMode.append);
      } catch (e) {
        if (kDebugMode) {
          print('LogManager Error: $e');
        }
      } finally {
        _isWriting = false;
      }
    });
  }

  Future<void> _rotateLogsIfNeeded() async {
    final file = File(await _getLogFilePath());
    if (await file.exists() && await file.length() > _maxFileSize) {
      final archivePath = '${await _getLogFilePath()}_${DateTime.now().millisecondsSinceEpoch}';
      await file.copy(archivePath);
      await file.writeAsString('');
    }
  }

  //========================
  // Enhanced Tracking Methods
  //========================

  /// 🕒 Connection Metrics
  void logConnectionEvent(String deviceId, String eventType, {Duration? latency, String? protocol}) {
    final entry = StringBuffer()
      ..write('[${DateTime.now()}] CONN_$eventType | Device: $deviceId');

    if (latency != null) entry.write(' | Latency: ${latency.inMilliseconds}ms');
    if (protocol != null) entry.write(' | Protocol: $protocol');

    _writeLog(entry.toString());
  }

  /// 📊 File Transfer Analytics
  void logFileTransfer(
      String transferId, {
        required String eventType,
        String? device,
        String? filePath,
        int? fileSize,
        double? progress,
        Duration? duration,
        required int speedBytesPerSec,
      }) {
    final entry = StringBuffer()
      ..write('[${DateTime.now()}] FILE_${eventType.toUpperCase()} | ID: $transferId');

    if (device != null) entry.write(' | Device: $device');
    if (filePath != null) entry.write(' | Path: $filePath');
    if (fileSize != null) entry.write(' | Size: ${_formatBytes(fileSize)}');
    if (progress != null) entry.write(' | Progress: ${progress.toStringAsFixed(1)}%');
    if (duration != null) {
      entry.write(' | Duration: ${duration.inMilliseconds}ms');
    }

    // Always include speed if provided
    entry.write(' | Speed: ${_formatBytes(speedBytesPerSec)}/s');

    _writeLog(entry.toString());
  }


  /// 📨 Message Tracking with Advanced Metrics
  void logMessage(
      String messageId, {
        required String direction, // 'SENT' or 'RECEIVED'
        String? device,
        String? messageType,
        Duration? latency,
        int? size,
      }) {
    final entry = StringBuffer()
      ..write('[${DateTime.now()}] MSG_${direction.toUpperCase()} | ID: $messageId');

    if (device != null) entry.write(' | Device: $device');
    if (messageType != null) entry.write(' | Type: $messageType');
    if (latency != null) entry.write(' | Latency: ${latency.inMilliseconds}ms');
    if (size != null) entry.write(' | Size: ${_formatBytes(size)}');

    _writeLog(entry.toString());
  }
  /// 🔌 Socket Initialization Tracking
  void logSocketInitialization({
    required String device,
    required bool isGroupOwner,
    required bool success,
    int? durationMs,
    String? error,
  }) {
    final entry = StringBuffer()
      ..write('[${DateTime.now()}] SOCKET_INIT | Device: $device')
      ..write(' | Role: ${isGroupOwner ? "Group Owner" : "Client"}')
      ..write(' | Status: ${success ? "Success" : "Failed"}');

    if (durationMs != null) entry.write(' | Time: ${durationMs}ms');
    if (error != null) entry.write(' | Error: $error');

    _writeLog(entry.toString());
  }

  //========================
  // Helper Methods
  //========================
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  Future<void> _writeLog(String logEntry) async {
    _logBuffer.add(logEntry);
    if (_logBuffer.length >= _bufferFlushSize) await _flushBuffer();
  }

  // Maintenance methods
  Future<String> readLogs() async {
    return await _writeLock.synchronized(() async {
      try {
        final filePath = await _getLogFilePath();
        final file = File(filePath);
        if (await file.exists()) {
          return await file.readAsString();
        }
        return "No logs found.";
      } catch (e) {
        return "Error reading logs: $e";
      }
    });
  }

  Future<void> clearLogs() async {
    await _writeLock.synchronized(() async {
      try {
        final filePath = await _getLogFilePath();
        final file = File(filePath);
        if (await file.exists()) {
          await file.writeAsString('');
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error clearing logs: $e");
        }
      }
    });
  }
}