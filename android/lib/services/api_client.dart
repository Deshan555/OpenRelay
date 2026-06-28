import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// REST API client for the OpenRelay FastAPI backend.
class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({required this.baseUrl});

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Register this device with the server.
  /// POST /devices/register
  Future<DeviceRegisterResponse> registerDevice(DeviceRegisterRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/devices/register'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return DeviceRegisterResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to register device: ${response.body}',
      );
    }
  }

  /// Get all registered devices.
  /// GET /devices/
  Future<List<DeviceInfo>> getAllDevices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/devices/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => DeviceInfo.fromJson(json)).toList();
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to fetch devices: ${response.body}',
      );
    }
  }

  /// Health check — ping the root endpoint.
  Future<bool> ping() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
