/*
 * @Author: yeffky
 * @Date: 2025-02-21 16:07:31
 * @LastEditTime: 2025-02-26 18:51:12
 */
import 'dart:io';

import 'package:flutter/material.dart';
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
    text: 'http://XXX.XXX.XXX.XXX:5628/captcha',
  );
  final _targetAppController = TextEditingController(text: '小红书');
  final _phoneNumberController = TextEditingController(text: '1234567890');
  late SMSHandler _smsHandler;

  @override
  void initState() {
    super.initState();
    _initializeSMSHandler();
  }

  Future<String?> _initializeSMSHandler() async {
    final apiEndpoint = _apiEndpointController.text;
    final targetApp = _targetAppController.text;
    final phoneNumber = _phoneNumberController.text;
    if (apiEndpoint.isNotEmpty) {
      _smsHandler = SMSHandler(apiEndpoint, targetApp, phoneNumber);
      String? result1 = await _smsHandler.initSMSListener();
      return result1;
    }
    return null;
  }

  String buttonText = '开始监控';
  String? result;
  String? response;

  void changeButtonText(String? text) {
    setState(() {
      buttonText = text ?? '开始监控';
    });
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
                hintText:
                    'Enter your API endpoint URL (e.g., "http://example.com/captcha")',
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
                hintText: 'Enter the app name to monitor (e.g., "小红书")',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (await Permission.sms.request().isGranted) {
                  // 权限已授予，执行 SMS 查询
                  changeButtonText("监控中...");

                  while (result == null) {
                    result = await _initializeSMSHandler();
                    if (result != null) {
                      changeButtonText("监控完成");
                      break;
                    }
                    sleep(Duration(seconds: 5)); // 每隔5秒检查一次
                  }
                  print(result);
                  changeButtonText('开始监控');
                  response = result;
                  result = null;
                }
              },
              child: Text(buttonText),
            ),
            const SizedBox(height: 16),
            Text(response ?? '请输入API Endpoint和目标App名称'),
          ],
        ),
      ),
    );
  }
}
