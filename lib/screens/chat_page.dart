import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../services/chat_storage.dart';
import '../services/wifi_p2p_manager.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import '../services/log_manager.dart';
import 'dart:math'; // For calculating transfer speed
import 'package:uuid/uuid.dart';

import 'videocall.dart';

class ChatPage extends StatefulWidget {
  final String deviceName;
  final String deviceAddress;
  final WifiP2PInfo? wifiP2PInfo;

  const ChatPage({
    super.key,
    required this.deviceName,
    required this.deviceAddress,
    this.wifiP2PInfo,
  });

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  List<ChatMessage> _messages = [];
  final ChatStorage _chatStorage = ChatStorage();
  String socketStatus = 'Socket inactive';
  bool isVideoCallActive = false;
  final GlobalKey<VideoCallWidgetState> _videoCallKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkConnectionAndSocket();
    final logManager = LogManager();
    logManager.logSocketInitialization(
      device: widget.deviceName,
      isGroupOwner: widget.wifiP2PInfo?.isGroupOwner ?? false,
      success: true, // or set based on actual result
    );
    WifiP2PManager.instance.setMessageHandler(_handleIncomingMessage);

  }

  Future<void> _checkConnectionAndSocket() async {
    bool isConnected = widget.wifiP2PInfo?.isConnected ?? false;
    bool isGroupOwner = widget.wifiP2PInfo?.isGroupOwner ?? false;

    try {
      if (isConnected) {
        if (isGroupOwner) {
          await startSocket();
          snack('Socket created!');
        } else {
          await connectToSocket();
          snack('Connected to socket!');
        }
      } else {
        snack('Not connected to any Wi-Fi P2P network.');
      }
    } catch (e) {
      snack('Error: ${e.toString()}');
    }
  }

  Future<void> _loadMessages() async {
    List<ChatMessage> messages = await _chatStorage.loadChat(widget.deviceAddress);
    setState(() {
      _messages = messages;
    });
  }

  void _sendMessage(String message) async {
    if (message.isEmpty) return;

    final startTime = DateTime.now(); // For ID and latency (if needed)
    final timestamp = startTime.millisecondsSinceEpoch;

    // Prepare message as JSON
    final messagePayload = jsonEncode({
      'text': message,
      'timestamp': timestamp,
    });

    ChatMessage chatMessage = ChatMessage(sender: 'Me', message: message);
    setState(() {
      _messages.add(chatMessage);
    });

    await _chatStorage.saveChat(widget.deviceAddress, _messages);
    _controller.clear();

    // Send message
    WifiP2PManager.instance.sendStringToSocket(messagePayload);

    // ✅ Updated logging portion
    LogManager.instance.logMessage(
      'msg-$timestamp',
      direction: 'SENT',
      device: widget.deviceAddress,
      messageType: 'text',
      latency: const Duration(milliseconds: 0), // Optionally log 0ms as placeholder
      size: utf8.encode(messagePayload).length, // Accurate byte size of payload
    );
  }



  Future<void> startSocket() async {
    if (widget.wifiP2PInfo != null) {
      final startTime = DateTime.now(); // 🕒 Start timing
      DateTime? endTime; // Declare outside so we can use it later

      bool started = false;

      try {
        started = await WifiP2PManager.instance.startSocket(
          groupOwnerAddress: widget.wifiP2PInfo!.groupOwnerAddress,
          downloadPath: "/storage/emulated/0/Download/ConnectX/",
          maxConcurrentDownloads: 2,
          deleteOnError: true,
          onConnect: (name, address) {
            snack("$name connected to socket with address: $address");

            setState(() {
              socketStatus = 'Socket active';
            });

            WifiP2PManager.instance.sendStringToSocket('Socket active');

            // End timing when the socket actually connects
            endTime = DateTime.now();
          },
          transferUpdate: (transfer) {
            if (transfer.completed) {
              snack(
                "${transfer.failed ? "failed to ${transfer.receiving ? "receive" : "send"}" : transfer.receiving ? "received" : "sent"}: ${transfer.filename}",
              );
            }
          },
          receiveString: (req) async {
            _handleIncomingMessage(req);
          },
        );
      } catch (e) {
        endTime ??= DateTime.now();

        LogManager.instance.logSocketInitialization(
          device: widget.deviceAddress,
          isGroupOwner: true,
          success: false,
          durationMs: endTime!.difference(startTime).inMilliseconds,
          error: e.toString(),
        );

        snack("Socket initialization failed: $e");
        return;
      }

      // If endTime wasn't set in onConnect (e.g., no connect event), use now
      endTime ??= DateTime.now();

      // ✅ Log success/failure with duration
      LogManager.instance.logSocketInitialization(
        device: widget.deviceAddress,
        isGroupOwner: true,
        success: started,
        durationMs: endTime!.difference(startTime).inMilliseconds,
      );

      snack("open socket: $started");
    }
  }


  Future<void> connectToSocket() async {
    if (widget.wifiP2PInfo != null) {
      final startTime = DateTime.now(); // ⏱ Start timing
      bool connected = false;
      DateTime? endTime;

      try {
        await WifiP2PManager.instance.connectToSocket(
          groupOwnerAddress: widget.wifiP2PInfo!.groupOwnerAddress,
          downloadPath: "/storage/emulated/0/Download/ConnectX/",
          maxConcurrentDownloads: 3,
          deleteOnError: true,
          onConnect: (address) {
            snack("Connected to socket: $address");
            connected = true;
            endTime = DateTime.now(); // ⏱ End timing on successful connect
          },
          transferUpdate: (transfer) {
            if (transfer.completed) {
              snack(
                  "${transfer.failed ? "failed to ${transfer.receiving ? "receive" : "send"}" : transfer.receiving ? "received" : "sent"}: ${transfer.filename}"
              );
            }
          },
          receiveString: (req) async {
            _handleIncomingMessage(req);
          },
        );
      } catch (e) {
        snack("Failed to connect to socket: $e");
        endTime ??= DateTime.now(); // Log timing even if it fails early
      }

      endTime ??= DateTime.now(); // Ensure endTime is set

      LogManager.instance.logSocketInitialization(
        device: widget.deviceAddress,
        isGroupOwner: false,
        success: connected,
        durationMs: endTime!.difference(startTime).inMilliseconds,
      );
    }
  }


  Future<void> sendFile(bool phone) async {
    String? filePath = await FilesystemPicker.open(
      context: context,
      rootDirectory: Directory(phone ? "/storage/emulated/0/" : "/storage/"),
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
      showGoUp: true,
      folderIconColor: Colors.blue,
    );

    if (filePath == null) return;

    final file = File(filePath);
    if (!await file.exists()) return;

    final fileSize = await file.length();
    final startTime = DateTime.now();
    final String transferId = const Uuid().v4(); // Generate unique ID

    List<TransferUpdate>? updates =
    await WifiP2PManager.instance.sendFiletoSocket([filePath]);

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    bool failed = updates?.any((u) => u.failed) ?? true;

    final double durationInSeconds = duration.inMilliseconds / 1000;
    final double speedBytesPerSecond = durationInSeconds > 0 ? fileSize / durationInSeconds : 0;

    LogManager.instance.logFileTransfer(
      transferId,
      eventType: failed ? "failed" : "completed",
      device: widget.deviceAddress,
      filePath: filePath,
      fileSize: fileSize,
      duration: duration,
      speedBytesPerSec: speedBytesPerSecond.toInt(),
    );

    print(updates);
  }

  void _handleIncomingMessage(dynamic message) {
    if (message is String) {
      if (message.startsWith('{')) {
        try {
          final data = jsonDecode(message);

          // ✅ Log only if it's a text message with timestamp
          if (data.containsKey('text') && data.containsKey('timestamp')) {
            final receivedTime = DateTime.now();
            final sentTimestamp = data['timestamp'];
            final latency = receivedTime.difference(
              DateTime.fromMillisecondsSinceEpoch(sentTimestamp),
            );

            LogManager.instance.logMessage(
              'msg-$sentTimestamp',
              direction: 'RECEIVED',
              device: widget.deviceAddress,
              messageType: 'text',
              latency: latency,
              size: utf8.encode(message).length,
            );

            // ✅ DISPLAY message on receiver UI
            _handleTextMessage(data['text']);
          }

          // Handle signaling messages (offer/answer/ICE)
          if (data['type'] == 'offer' ||
              data['type'] == 'answer' ||
              data['type'] == 'iceCandidate') {
            if (isVideoCallActive) {
              _videoCallKey.currentState?.handleSignalingData(data);
            }
          } else {
            _handleJsonMessage(message);
          }
        } catch (e) {
          debugPrint("Error decoding JSON message: $e");
        }
      } else {
        if (message == "Socket active") {
          setState(() {
            socketStatus = "Socket active";
          });
        } else {
          _handleTextMessage(message);
        }
      }
    }
  }


  void _handleTextMessage(String message) {
    final receiveTime = DateTime.now(); // ⏱️ Capture receive time

    ChatMessage receivedMessage = ChatMessage(sender: 'Other', message: message);
    setState(() {
      _messages.add(receivedMessage);
    });
    _chatStorage.saveChat(widget.deviceAddress, _messages);

    // Log received message
    LogManager.instance.logMessage(
      'msg-${receiveTime.millisecondsSinceEpoch}', // Unique ID
      direction: 'RECEIVED',
      device: widget.deviceAddress,
      messageType: 'text',
      latency: null, // You can add latency if you calculate it later
      size: message.length,
    );
  }



  void _handleJsonMessage(String message) {
    try {
      final data = jsonDecode(message);
      switch (data['type']) {
        case 'call_initiation':
          setState(() {
            isVideoCallActive = true; // Show video call UI
          });
          break;
        case 'call_end':
          setState(() {
            isVideoCallActive = false; // Hide video call UI
          });
          break;
        default:
          debugPrint("Unknown message type: ${data['type']}");
          break;
      }
    } catch (e) {
      debugPrint("Error decoding JSON message: $e");
    }
  }

  void _endVideoCall() {
    setState(() {
      isVideoCallActive = false;
    });
    WifiP2PManager.instance.sendStringToSocket(jsonEncode({
      'type': 'call_end',
      'peerId': widget.deviceAddress,
    }));
  }

  Future<void> requestManageAllFilesPermissionAndSendFile() async {
    // Request permission to manage all files (MANAGE_EXTERNAL_STORAGE)
    PermissionStatus status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      await sendFile(true);
    } else {
      print('Permission denied to manage all files.');
    }
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(bottom: 11.0),
          child: Text(widget.deviceName),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Start Video Call',
            onPressed: () {
              setState(() {
                isVideoCallActive = true; // Show video call UI
              });
              WifiP2PManager.instance.sendStringToSocket(jsonEncode({
                'type': 'call_initiation',
                'peerId': widget.deviceAddress,
              }));
              Future.delayed(Duration(seconds: 2), () {
                _sendMessage("Starting video call");
              });
            },
          ),
        ],
        flexibleSpace: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 72.0, bottom: 3.0),
            child: Text(
              socketStatus,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isSender = message.sender == 'Me';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSender
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                message.message,
                                style: TextStyle(
                                  color: isSender ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () async {
                        await requestManageAllFilesPermissionAndSendFile();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        _sendMessage(_controller.text);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Video Call Overlay
          if (isVideoCallActive)
            Positioned(
              bottom: 80,
              right: 10,
              child: VideoCallWidget(
                key: _videoCallKey,
                peerId: widget.deviceName,
                onEndCall: _endVideoCall,
              ),
            ),
        ],
      ),
    );
  }
}
