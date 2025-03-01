/*
 * @Author: yeffky
 * @Date: 2025-02-21 16:07:31
 * @LastEditTime: 2025-02-26 16:59:17
 */
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sms_advanced/sms_advanced.dart';

class SMSHandler {
  final String _apiEndpoint;
  final String _targetApp;
  final String _phoneNumber;

  SMSHandler(this._apiEndpoint, this._targetApp, this._phoneNumber);

  Future<String?> initSMSListener() async {
    SmsQuery query =
        SmsQuery()
          ..querySms(address: _phoneNumber, kinds: [SmsQueryKind.Inbox]);
    List<SmsMessage>? messages = await query.querySms();
    String? result;
    if (messages != null && messages.isNotEmpty) {
      // 获取第一条短信
      SmsMessage firstMessage = messages.first;
      String? messageBody = firstMessage.body;

      // 使用正则表达式匹配验证码，假设验证码是 6 位数字
      RegExp regex = RegExp(r'\d{6}');
      Match? match = regex.firstMatch(messageBody!);

      if (match != null) {
        String smsCode = match.group(0)!;
        // 发送验证码到 API
        result = await _sendCodeToAPI(smsCode);
      } else {
        print('未在短信中找到验证码');
      }
    } else {
      print('未找到短信');
    }
    if (result != null) {
      return result;
    }
    return null;
  }

  // Future<void> _handleSMS(SmsMessage sms) async {
  //   if (sms.body?.contains(_targetApp) ?? false) {
  //     final code = _extractCode(sms.body);
  //     if (code != null) {
  //       await _sendCodeToAPI(code);
  //     }
  //   }
  // }

  String? _extractCode(String? message) {
    if (message == null) return null;
    final regex = RegExp(r'\d{4,6}');
    final match = regex.firstMatch(message);
    return match?.group(0);
  }

  Future<String?> _sendCodeToAPI(String code) async {
    try {
      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      if (response.statusCode != 200) {
        return ('Failed to send code: ${response.statusCode}');
      } else {
        return 'Code sent successfully';
      }
    } catch (e) {
      return ('Error sending code: $e');
    }
  }
  
}
