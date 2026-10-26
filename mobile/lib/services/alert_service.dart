import '../config/api_config.dart';
import '../models/alert.dart';
import '../models/investigation.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';

class AlertService {
  final ApiClient _client = ApiClient.instance;

  Future<PaginatedResponse<AlertModel>> getAlerts({
    int page = 1,
    String? status,
    int? cardId,
    double? minScore,
    String? ordering,
  }) async {
    final queryParams = <String, dynamic>{'page': page};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (cardId != null) {
      queryParams['card'] = cardId;
    }
    if (minScore != null && minScore > 0) {
      queryParams['min_score'] = minScore;
    }
    if (ordering != null && ordering.isNotEmpty) {
      queryParams['ordering'] = ordering;
    }

    final response = await _client.get(
      ApiConfig.alertsUrl,
      queryParams: queryParams,
    );
    return PaginatedResponse<AlertModel>.fromJson(
      response as Map<String, dynamic>,
      (item) => AlertModel.fromJson(item),
    );
  }

  Future<AlertModel> getAlert(int id) async {
    final response = await _client.get(ApiConfig.alertDetailUrl(id));
    return AlertModel.fromJson(response as Map<String, dynamic>);
  }

  Future<InvestigationModel> recordInvestigation(
    int alertId,
    InvestigationCreateRequest request,
  ) async {
    final response = await _client.post(
      ApiConfig.alertInvestigateUrl(alertId),
      body: request.toJson(),
    );
    return InvestigationModel.fromJson(response as Map<String, dynamic>);
  }
}
