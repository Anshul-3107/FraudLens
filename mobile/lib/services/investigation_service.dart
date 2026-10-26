import '../config/api_config.dart';
import '../models/investigation.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';

class InvestigationService {
  final ApiClient _client = ApiClient.instance;

  Future<PaginatedResponse<InvestigationModel>> getInvestigations({
    int page = 1,
  }) async {
    final response = await _client.get(
      ApiConfig.investigationsUrl,
      queryParams: {'page': page},
    );
    return PaginatedResponse<InvestigationModel>.fromJson(
      response as Map<String, dynamic>,
      (item) => InvestigationModel.fromJson(item),
    );
  }
}
