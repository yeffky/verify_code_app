import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sms_handler.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Forwarder',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _apiEndpointController = TextEditingController(
    text: 'http://xxx.xxx.xxx.xxx:5628/captcha',
  );
  final _targetAppController = TextEditingController(text: '小红书');
  final _phoneNumberController = TextEditingController(text: '1234567890');
  late ReceivePort _receivePort;
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  String buttonText = '开始监控';
  String stopButtonText = '停止监控';
  String? response;
  bool isMonitoring = false;
  RootIsolateToken? _rootIsolateToken;

  @override
  void initState() {
    super.initState();
    _rootIsolateToken = RootIsolateToken.instance;
    _initReceivePort();
  }

  void _initReceivePort() {
    _receivePort = ReceivePort();
    _receivePort.listen((message) {
      if (message is String) {
        setState(() => response = message);
      } else if (message is SendPort) {
        _isolateSendPort = message;
      }
    });
  }

  @override
  void dispose() {
    _stopIsolate();
    _receivePort.close();
    super.dispose();
  }

  void _stopIsolate() {
    if (_isolate != null) {
      _isolateSendPort?.send('stop');
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      throw Exception('SMS permission denied');
    }
  }

  Future<void> startMonitoring() async {
    if (isMonitoring) return;

    try {
      await _checkPermissions();
      _stopIsolate(); // Stop existing isolate if any

      setState(() {
        buttonText = "监控中...";
        isMonitoring = true;
      });

      _isolate = await Isolate.spawn(
        _monitorSmsInBackground,
        [
          _apiEndpointController.text,
          _targetAppController.text,
          _phoneNumberController.text,
          _receivePort.sendPort,
          _rootIsolateToken,
        ],
      );
    } catch (e) {
      setState(() => response = 'Error: ${e.toString()}');
      _handleMonitoringStop();
    }
  }

  void stopMonitoring() {
    _stopIsolate();
    _handleMonitoringStop();
  }

  void _handleMonitoringStop() {
    if (mounted) {
      setState(() {
        buttonText = '开始监控';
        response = null;
        isMonitoring = false;
      });
    }
  }

  static void _monitorSmsInBackground(List<dynamic> args) async {
    final rootIsolateToken = args[4] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

    final apiEndpoint = args[0] as String;
    final targetApp = args[1] as String;
    final phoneNumber = args[2] as String;
    final mainSendPort = args[3] as SendPort;
    final smsHandler = SMSHandler(apiEndpoint, targetApp, phoneNumber);

    final controlPort = ReceivePort();
    mainSendPort.send(controlPort.sendPort);

    final stopCompleter = Completer<void>();
    controlPort.listen((message) {
      if (message == 'stop') {
        stopCompleter.complete();
      }
    });

    try {
      while (!stopCompleter.isCompleted) {
        final value = await smsHandler.initSMSListener().timeout(
          const Duration(seconds: 1),
          onTimeout: () => null,
        );

        if (value != null) {
          mainSendPort.send(value);
        }

        if (stopCompleter.isCompleted) break;
      }
    } finally {
      controlPort.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Forwarder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _apiEndpointController,
              decoration: const InputDecoration(
                labelText: 'API Endpoint',
                hintText: 'Enter your API endpoint URL',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetAppController,
              decoration: const InputDecoration(
                labelText: 'Target App',
                hintText: 'Enter the app name to monitor',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isMonitoring ? null : startMonitoring,
                  child: Text(buttonText),
                ),
                ElevatedButton(
                  onPressed: isMonitoring ? stopMonitoring : null,
                  child: Text(stopButtonText),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              response ?? '等待短信中...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}