import 'package:flutter/foundation.dart';

import '../models/paginated_response.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionService _transactionService;

  List<TransactionModel> _transactions = [];
  int _count = 0;
  int _page = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Filter state
  int? _cardId;
  String? _category;
  String? _searchQuery;
  String? _dateFrom;
  String? _dateTo;
  double? _minAmount;
  bool _flaggedOnly = false;

  TransactionProvider({TransactionService? transactionService})
    : _transactionService = transactionService ?? TransactionService();

  List<TransactionModel> get transactions => _transactions;
  int get count => _count;
  int get page => _page;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int? get cardId => _cardId;
  String? get category => _category;
  String? get searchQuery => _searchQuery;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;
  double? get minAmount => _minAmount;
  bool get flaggedOnly => _flaggedOnly;

  bool get hasActiveFilters =>
      _cardId != null ||
      (_category != null && _category!.isNotEmpty) ||
      (_searchQuery != null && _searchQuery!.isNotEmpty) ||
      _dateFrom != null ||
      _dateTo != null ||
      (_minAmount != null && _minAmount! > 0) ||
      _flaggedOnly;

  Future<void> loadTransactions({int page = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    _page = page;
    notifyListeners();

    try {
      final PaginatedResponse<TransactionModel> response =
          await _transactionService.getTransactions(
            page: _page,
            cardId: _cardId,
            category: _category,
            search: _searchQuery,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            minAmount: _minAmount,
            flagged: _flaggedOnly ? true : null,
          );

      _transactions = response.results;
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
      loadTransactions(page: _page + 1);
    }
  }

  void previousPage() {
    if (_hasPrevious && !_isLoading && _page > 1) {
      loadTransactions(page: _page - 1);
    }
  }

  void setSearch(String query) {
    _searchQuery = query.trim().isEmpty ? null : query.trim();
    loadTransactions(page: 1);
  }

  void setCard(int? cardId) {
    _cardId = cardId;
    loadTransactions(page: 1);
  }

  void setCategory(String? category) {
    _category = category;
    loadTransactions(page: 1);
  }

  void setFlaggedOnly(bool value) {
    _flaggedOnly = value;
    loadTransactions(page: 1);
  }

  void setDateRange(String? from, String? to) {
    _dateFrom = from;
    _dateTo = to;
    loadTransactions(page: 1);
  }

  void setMinAmount(double? amount) {
    _minAmount = amount;
    loadTransactions(page: 1);
  }

  void resetFilters() {
    _cardId = null;
    _category = null;
    _searchQuery = null;
    _dateFrom = null;
    _dateTo = null;
    _minAmount = null;
    _flaggedOnly = false;
    loadTransactions(page: 1);
  }

  Future<TransactionCreateResponse> createTransaction(
    TransactionCreateRequest request,
  ) async {
    final response = await _transactionService.createTransaction(request);
    // Reload transactions so the newly added one appears
    loadTransactions(page: 1);
    return response;
  }
}
