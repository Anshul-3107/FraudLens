import '../config/api_config.dart';
import '../models/summary.dart';
import 'api_client.dart';

class SummaryService {
  final ApiClient _client = ApiClient.instance;

  Future<SummaryModel> getSummary({
    int? cardId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (cardId != null) {
      queryParams['card'] = cardId;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }

    final response = await _client.get(
      ApiConfig.summaryUrl,
      queryParams: queryParams,
    );
    return SummaryModel.fromJson(response as Map<String, dynamic>);
  }
}
