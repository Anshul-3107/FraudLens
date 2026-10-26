import 'package:flutter/foundation.dart';

import '../models/investigation.dart';
import '../models/paginated_response.dart';
import '../services/investigation_service.dart';

class InvestigationProvider extends ChangeNotifier {
  final InvestigationService _investigationService;

  List<InvestigationModel> _investigations = [];
  int _count = 0;
  int _page = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;
  bool _isLoading = false;
  String? _errorMessage;

  InvestigationProvider({InvestigationService? investigationService})
    : _investigationService = investigationService ?? InvestigationService();

  List<InvestigationModel> get investigations => _investigations;
  int get count => _count;
  int get page => _page;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInvestigations({int page = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    _page = page;
    notifyListeners();

    try {
      final PaginatedResponse<InvestigationModel> response =
          await _investigationService.getInvestigations(page: _page);

      _investigations = response.results;
      _count = response.count;
      _hasNext = response.hasNext;
      _hasPrevious = response.hasPrevious;
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void nextPage() {
    if (_hasNext && !_isLoading) {
      loadInvestigations(page: _page + 1);
    }
  }

  void previousPage() {
    if (_hasPrevious && !_isLoading && _page > 1) {
      loadInvestigations(page: _page - 1);
    }
  }
}
