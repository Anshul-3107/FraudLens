import '../config/api_config.dart';
import '../models/paginated_response.dart';
import '../models/transaction.dart';
import 'api_client.dart';

class TransactionService {
  final ApiClient _client = ApiClient.instance;

  Future<PaginatedResponse<TransactionModel>> getTransactions({
    int page = 1,
    int? cardId,
    String? category,
    String? search,
    String? dateFrom,
    String? dateTo,
    double? minAmount,
    bool? flagged,
  }) async {
    final queryParams = <String, dynamic>{'page': page};
    if (cardId != null) {
      queryParams['card'] = cardId;
    }
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }
    if (minAmount != null && minAmount > 0) {
      queryParams['min_amount'] = minAmount;
    }
    if (flagged == true) {
      queryParams['flagged'] = 'true';
    }

    final response = await _client.get(
      ApiConfig.transactionsUrl,
      queryParams: queryParams,
    );
    return PaginatedResponse<TransactionModel>.fromJson(
      response as Map<String, dynamic>,
      (item) => TransactionModel.fromJson(item),
    );
  }

  Future<TransactionModel> getTransaction(int id) async {
    final response = await _client.get(ApiConfig.transactionDetailUrl(id));
    return TransactionModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TransactionCreateResponse> createTransaction(
    TransactionCreateRequest request,
  ) async {
    final response = await _client.post(
      ApiConfig.transactionsUrl,
      body: request.toJson(),
    );
    return TransactionCreateResponse.fromJson(response as Map<String, dynamic>);
  }
}
