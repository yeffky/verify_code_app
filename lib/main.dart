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
    text: 'http://47.122.42.169:5628/captcha',
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

  // 在主isolate的接收端口监听中添加状态更新
  void _initReceivePort() {
    _receivePort = ReceivePort();
    _receivePort.listen((message) {
      if (message is String) {
        if (message == 'isolate_stopped') {
          // 处理isolate退出通知
          if (mounted) {
            setState(() {
              _isolate = null;
              isMonitoring = false;
              buttonText = '开始监控';
            });
          }
        } else {
          setState(() => response = message);
        }
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

  // 修改 _stopIsolate 方法，仅发送停止信号，不强制终止Isolate
  void _stopIsolate() {
    if (_isolate != null) {
      _isolateSendPort?.send('stop');
    }
  }

  Future<void> _checkPermissions() async {
    final status_sms = await Permission.sms.request();
    if (!status_sms.isGranted) {
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

      _isolate = await Isolate.spawn(_monitorSmsInBackground, [
        _apiEndpointController.text,
        _targetAppController.text,
        _phoneNumberController.text,
        _receivePort.sendPort,
        _rootIsolateToken,
      ]);
    } catch (e) {
      setState(() => response = 'Error: ${e.toString()}');
      _handleMonitoringStop();
    }
  }

  // 修改停止监控方法
  void stopMonitoring() {
    _stopIsolate();
    // 移除 _handleMonitoringStop，改由isolate退出通知触发状态更新
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
        print(value);
        mainSendPort.send(value);

        if (stopCompleter.isCompleted) break;
      }
    } finally {
      controlPort.close();
      mainSendPort.send('isolate_stopped'); // 添加退出通知
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
              onChanged: (value) {
                // 当用户输入内容时，更新 _apiEndpointController 的值
                setState(() {
                  _apiEndpointController.text = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number[condition 1]',
                hintText: 'Enter your phone number',
              ),
              onChanged: (value) {
                // 当用户输入内容时，更新 _phoneNumberController 的值
                setState(() {
                  _phoneNumberController.text = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetAppController,
              decoration: const InputDecoration(
                labelText: 'Target App[condition 2]',
                hintText: 'Enter the app name to monitor',
              ),
              onChanged: (value) {
                // 当用户输入内容时，更新 _targetAppController 的值
                setState(() {
                  _targetAppController.text = value;
                });
              },
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
