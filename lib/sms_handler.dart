/*
 * @Author: yeffky
 * @Date: 2025-02-21 16:07:31
 * @LastEditTime: 2025-03-03 12:39:28
 */
import 'package:http/http.dart' as http;
import 'package:sms_advanced/contact.dart';
import 'dart:convert';
import 'package:sms_advanced/sms_advanced.dart';

class SMSHandler {
  final String _apiEndpoint;
  final String _targetApp;
  final String _phoneNumber;

  SMSHandler(this._apiEndpoint, this._targetApp, this._phoneNumber);

  Future<String?> initSMSListener() async {
    print(_phoneNumber);
    SmsQuery query = SmsQuery();
    List<SmsMessage>? messages = await query.querySms(
      address: _phoneNumber,
      kinds: [SmsQueryKind.Inbox],
    ); // 获取收件箱中的短信
    if (messages.isEmpty) {
      List<SmsMessage>? messages = await query.querySms(
        kinds: [SmsQueryKind.Inbox],
      ); // 根据条件二进行查询
      for (SmsMessage message in messages) {
        if (message.body?.contains(_targetApp) ?? false) {
          final code = _extractCode(message.body);
          if (code != null) {
            return await _sendCodeToAPI(code);
          }
        }
      }
    }
    String? result;
    if (messages.isNotEmpty) {
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
        result = '未在短信中找到验证码';
      }
    } else {
      result = '未找到短信';
    }
    if (result != null) {
      return result;
    }
    return null;
  }

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
        return 'Successfully Code sent';
      }
    } catch (e) {
      return ('Error sending code: $e');
    }
  }
}
