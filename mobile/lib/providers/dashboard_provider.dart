import 'package:flutter/foundation.dart';

import '../models/card.dart';
import '../models/summary.dart';
import '../services/summary_service.dart';

class DashboardProvider extends ChangeNotifier {
  final SummaryService _summaryService;

  SummaryModel? _summary;
  bool _isLoading = false;
  String? _errorMessage;

  CardModel? _selectedCard;
  String? _dateFrom;
  String? _dateTo;

  DashboardProvider({SummaryService? summaryService})
    : _summaryService = summaryService ?? SummaryService();

  SummaryModel? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CardModel? get selectedCard => _selectedCard;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;

  bool get hasActiveFilters =>
      _selectedCard != null || _dateFrom != null || _dateTo != null;

  void setCardFilter(CardModel? card) {
    _selectedCard = card;
    loadSummary();
  }

  void setDateRange(String? from, String? to) {
    _dateFrom = from;
    _dateTo = to;
    loadSummary();
  }

  void clearFilters() {
    _selectedCard = null;
    _dateFrom = null;
    _dateTo = null;
    loadSummary();
  }

  Future<void> loadSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _summaryService.getSummary(
        cardId: _selectedCard?.id,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }
}
