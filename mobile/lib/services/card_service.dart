import '../config/api_config.dart';
import '../models/card.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';

class CardService {
  final ApiClient _client = ApiClient.instance;

  Future<PaginatedResponse<CardModel>> getCards({int page = 1}) async {
    final response = await _client.get(
      ApiConfig.cardsUrl,
      queryParams: {'page': page},
    );
    return PaginatedResponse<CardModel>.fromJson(
      response as Map<String, dynamic>,
      (item) => CardModel.fromJson(item),
    );
  }

  Future<List<CardModel>> getAllCards() async {
    final List<CardModel> all = [];
    int page = 1;
    bool hasMore = true;

    while (hasMore && page <= 5) {
      final res = await getCards(page: page);
      all.addAll(res.results);
      if (res.hasNext) {
        page++;
      } else {
        hasMore = false;
      }
    }
    return all;
  }
}
