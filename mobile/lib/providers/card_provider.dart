import 'package:flutter/foundation.dart';

import '../models/card.dart';
import '../services/card_service.dart';

class CardProvider extends ChangeNotifier {
  final CardService _cardService;

  List<CardModel> _cards = [];
  bool _isLoading = false;
  String? _errorMessage;

  CardProvider({CardService? cardService})
    : _cardService = cardService ?? CardService();

  List<CardModel> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCards() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _cards = await _cardService.getAllCards();
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }
}
