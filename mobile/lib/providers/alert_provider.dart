import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import '../models/investigation.dart';
import '../models/paginated_response.dart';
import '../services/alert_service.dart';

class AlertProvider extends ChangeNotifier {
  final AlertService _alertService;

  List<AlertModel> _alerts = [];
  int _count = 0;
  int _page = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Filters
  String? _status;
  int? _cardId;
  double? _minScore;
  String? _ordering;

  AlertProvider({AlertService? alertService})
    : _alertService = alertService ?? AlertService();

  List<AlertModel> get alerts => _alerts;
  int get count => _count;
  int get page => _page;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get statusFilter => _status;
  int? get cardId => _cardId;
  double? get minScore => _minScore;
  String? get ordering => _ordering;

  bool get hasActiveFilters =>
      (_status != null && _status!.isNotEmpty) ||
      _cardId != null ||
      (_minScore != null && _minScore! > 0) ||
      (_ordering != null && _ordering!.isNotEmpty);

  Future<void> loadAlerts({int page = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    _page = page;
    notifyListeners();

    try {
      final PaginatedResponse<AlertModel> response = await _alertService
          .getAlerts(
            page: _page,
            status: _status,
            cardId: _cardId,
            minScore: _minScore,
            ordering: _ordering,
          );

      _alerts = response.results;
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
      loadAlerts(page: _page + 1);
    }
  }

  void previousPage() {
    if (_hasPrevious && !_isLoading && _page > 1) {
      loadAlerts(page: _page - 1);
    }
  }

  void setStatus(String? status) {
    _status = status;
    loadAlerts(page: 1);
  }

  void setCard(int? cardId) {
    _cardId = cardId;
    loadAlerts(page: 1);
  }

  void setMinScore(double? minScore) {
    _minScore = minScore;
    loadAlerts(page: 1);
  }

  void setOrdering(String? ordering) {
    _ordering = ordering;
    loadAlerts(page: 1);
  }

  void resetFilters() {
    _status = null;
    _cardId = null;
    _minScore = null;
    _ordering = null;
    loadAlerts(page: 1);
  }

  Future<InvestigationModel> recordInvestigation(
    int alertId,
    InvestigationCreateRequest request,
  ) async {
    final result = await _alertService.recordInvestigation(alertId, request);
    // Reload alerts to reflect updated status and latest verdict
    await loadAlerts(page: _page);
    return result;
  }
}
