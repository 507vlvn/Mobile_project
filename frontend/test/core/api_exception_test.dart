import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';

DioException _dio(DioExceptionType t, {int? status, Object? data}) =>
    DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: t,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
              data: data),
    );

void main() {
  test('uses ProblemDetails title', () {
    final e = ApiException.fromDio(_dio(DioExceptionType.badResponse,
        status: 401, data: {'title': 'Sai tên đăng nhập hoặc mật khẩu'}));
    expect(e.message, 'Sai tên đăng nhập hoặc mật khẩu');
    expect(e.statusCode, 401);
    expect(e.isUnauthorized, true);
  });

  test('prefers first validation error message', () {
    final e = ApiException.fromProblem(400, {
      'title': 'One or more validation errors occurred.',
      'errors': {
        'Password': ['Mật khẩu phải có ít nhất 6 ký tự']
      },
    });
    expect(e.message, 'Mật khẩu phải có ít nhất 6 ký tự');
  });

  test('429 uses server title, falls back to friendly text', () {
    expect(
        ApiException.fromProblem(429, {'title': 'Bạn thao tác quá nhanh'})
            .message,
        'Bạn thao tác quá nhanh');
    final e = ApiException.fromProblem(429, null);
    expect(e.isRateLimited, true);
    expect(e.message, contains('quá nhanh'));
  });

  test('connection error -> network message', () {
    final e = ApiException.fromDio(_dio(DioExceptionType.connectionError));
    expect(e.isNetwork, true);
    expect(e.isConnectivity, true);
    expect(e.message, ApiException.networkMessage);
  });

  test('timeouts -> timeout message', () {
    for (final t in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final e = ApiException.fromDio(_dio(t));
      expect(e.isTimeout, true);
      expect(e.isNetwork, false);
      expect(e.message, startsWith('Máy chủ phản hồi quá lâu'));
    }
  });

  test('5xx without body -> generic server message', () {
    final e = ApiException.fromProblem(500, '<html>');
    expect(e.message, contains('sự cố'));
    expect(e.isClientError, false);
  });
}
