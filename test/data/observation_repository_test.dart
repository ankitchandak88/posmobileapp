import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/network/api_client.dart';
import 'package:urban_pets_verify/core/storage/secure_token_storage.dart';
import 'package:urban_pets_verify/features/review/data/observation_repository.dart';

/// Avoids hitting the real platform secure-storage channel (not available in
/// a plain `flutter test` unit test) — [ApiClient]'s request interceptor
/// always calls `readToken()` before a request goes out.
class _FakeTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readToken() async => null;
}

/// Captures the [RequestOptions] Dio built for the outgoing call (method,
/// path, and — crucially — the exact `data` object, FormData or plain map)
/// and aborts before anything touches the network, by rejecting with a
/// [DioException] the caller can distinguish from a real failure.
class _CapturingInterceptor extends Interceptor {
  RequestOptions? captured;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    captured = options;
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'captured-for-test',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CapturingInterceptor capture;
  late ObservationRepository repository;
  late Directory tempDir;
  late File samplePhoto;

  setUp(() async {
    capture = _CapturingInterceptor();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..interceptors.add(capture);
    final apiClient = ApiClient(tokenStorage: _FakeTokenStorage(), dio: dio);
    repository = ObservationRepository(apiClient: apiClient);

    // A real, tiny file on disk — MultipartFile.fromFile needs one to stat
    // and stream, and this proves the fix actually reads image bytes rather
    // than just forwarding the path string.
    tempDir = await Directory.systemTemp.createTemp('observation_repo_test');
    samplePhoto = File('${tempDir.path}/sample.jpg')
      ..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> expectCaptured(Future<void> Function() action) async {
    try {
      await action();
      fail('expected the request to be aborted by the capturing interceptor');
    } catch (_) {
      // Expected — the interceptor rejects every request on purpose.
    }
  }

  group('ObservationRepository.submit body shape', () {
    test('builds a multipart FormData body with a MultipartFile when a '
        'photo path is present', () async {
      await expectCaptured(
        () => repository.submit(
          type: 'stock_count',
          itemId: '10',
          branchId: '1',
          physicalQty: 17,
          photoPath: samplePhoto.path,
          idempotencyKey: 'uuid-1',
        ),
      );

      final data = capture.captured!.data;
      expect(data, isA<FormData>());
      final formData = data as FormData;

      // Plain scalar fields travel as form fields.
      final fieldMap = {for (final f in formData.fields) f.key: f.value};
      expect(fieldMap['type'], 'stock_count');
      expect(fieldMap['item_id'], '10');
      expect(fieldMap['branch_id'], '1');
      expect(fieldMap['physical_qty'], '17');
      expect(fieldMap['idempotency_key'], 'uuid-1');

      // The photo is a real MultipartFile under the exact `photo` field
      // name the Laravel `ObservationController` validates
      // (`'photo' => ['nullable', 'image', 'max:5120']`), not a string.
      expect(formData.files, hasLength(1));
      expect(formData.files.single.key, 'photo');
      expect(formData.files.single.value, isA<MultipartFile>());
      expect(formData.files.single.value.filename, 'sample.jpg');
    });

    test(
      'sends a plain JSON-able map body (no multipart) when there is no photo',
      () async {
        await expectCaptured(
          () => repository.submit(
            type: 'stock_count',
            itemId: '10',
            branchId: '1',
            physicalQty: 17,
            idempotencyKey: 'uuid-2',
          ),
        );

        final data = capture.captured!.data;
        expect(data, isNot(isA<FormData>()));
        expect(data, isA<Map>());
        final map = data as Map;
        expect(map['type'], 'stock_count');
        expect(map['item_id'], '10');
        expect(map['photo'], isNull);
      },
    );
  });
}
