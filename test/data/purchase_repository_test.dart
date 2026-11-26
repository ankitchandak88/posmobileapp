import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/constants/api_constants.dart';
import 'package:urban_pets_verify/core/network/api_client.dart';
import 'package:urban_pets_verify/core/storage/secure_token_storage.dart';
import 'package:urban_pets_verify/features/purchase/data/purchase_repository.dart';

class _FakeTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readToken() async => 'fake-jwt-token';
}

class _MockDioAdapter implements HttpClientAdapter {
  _MockDioAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PurchaseRepository repository;
  late RequestOptions lastOptions;

  void setupMockClient(dynamic responseData, {int statusCode = 200}) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = _MockDioAdapter((options) async {
      lastOptions = options;
      return ResponseBody.fromString(
        responseData is String ? responseData : DioMediaType('application', 'json').toString(),
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });

    // Instead of raw ResponseBody, using interceptor to provide parsed response
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          lastOptions = options;
          handler.resolve(
            Response(
              requestOptions: options,
              data: responseData,
              statusCode: statusCode,
            ),
          );
        },
      ),
    );

    final apiClient = ApiClient(tokenStorage: _FakeTokenStorage(), dio: dio);
    repository = PurchaseRepository(apiClient);
  }

  group('PurchaseRepository Unit Tests', () {
    test('purchaseOrders builds correct query parameters and parses list', () async {
      setupMockClient({
        'data': [
          {
            'id': '101',
            'po_number': 'PO-2026-0001',
            'supplier_id': '12',
            'supplier_name': 'Mars Petcare',
            'total_qty': 30,
            'total_items': 3,
            'status': 'Open',
          },
          {
            'id': '102',
            'po_number': 'PO-2026-0002',
            'supplier_id': '12',
            'supplier_name': 'Mars Petcare',
            'total_qty': 15,
            'total_items': 1,
            'status': 'Open',
          },
        ],
      });

      final orders = await repository.purchaseOrders(
        supplierId: '12',
        search: 'PO-2026',
        branchId: '1',
        status: 'Open',
      );

      expect(lastOptions.path, ApiConstants.purchaseOrders);
      expect(lastOptions.queryParameters['supplier_id'], '12');
      expect(lastOptions.queryParameters['search'], 'PO-2026');
      expect(lastOptions.queryParameters['branch_id'], '1');
      expect(lastOptions.queryParameters['status'], 'Open');

      expect(orders, hasLength(2));
      expect(orders[0].poNumber, 'PO-2026-0001');
      expect(orders[1].poNumber, 'PO-2026-0002');
    });

    test('purchaseOrderDetail parses full PO with items', () async {
      setupMockClient({
        'data': {
          'id': '501',
          'po_number': 'PO-2026-0042',
          'supplier_id': '7',
          'supplier_name': 'Mars Petcare India',
          'total_qty': 25,
          'total_items': 1,
          'items': [
            {
              'id': '1',
              'po_item_id': '1',
              'item_id': '101',
              'name': 'Pedigree 10kg',
              'ordered_qty': 25,
            },
          ],
        },
      });

      final po = await repository.purchaseOrderDetail('501');

      expect(lastOptions.path, ApiConstants.purchaseOrderDetail('501'));
      expect(po.id, '501');
      expect(po.poNumber, 'PO-2026-0042');
      expect(po.items, hasLength(1));
      expect(po.items.first.name, 'Pedigree 10kg');
      expect(po.items.first.orderedQty, 25);
    });
  });
}
