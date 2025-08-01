// Complete CryptoCalc Flutter Application - Single File

// ==================== ENUMS ====================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:either_dart/either.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cryptocalc/app_theme.dart';

part 'app.freezed.dart';
part 'app.g.dart';

enum CurrencyType { cryptocurrency, fiat }

enum ConversionDirection { fromTo, toFrom }

enum ApiStatus { initial, loading, loaded, error }

enum SortOption { nameAsc, nameDesc, priceAsc, priceDesc, dateAsc, dateDesc }

// ==================== CONSTANTS ====================

class AppConstants {
  static const String coinMarketCapBaseUrl = 'https://pro-api.coinmarketcap.com';
  static const String coinMarketCapApiKey = '89919707-930c-4192-a8cc-9f586169829f';
  static const int apiTimeout = 30;
  static const int cacheExpiryMinutes = 5;

  static const String btcCode = 'BTC';
  static const String ethCode = 'ETH';
  static const String usdCode = 'USD';
  static const String eurCode = 'EUR';
  static const String kztCode = 'KZT';
  static const String rubCode = 'RUB';

  static const String defaultFromCurrency = btcCode;
  static const String defaultToCurrency = usdCode;
  static const double defaultAmount = 1.0;

  static const double minAmount = 0.0001;
  static const double maxAmount = 999999999.9999;
  static const int maxDecimalPlaces = 4;

  static const int maxHistoryRecords = 1000;

  static const String appName = 'CryptoCalc';
  static const String appVersion = '1.0.0';
}

class UIConstants {
  static const Color primaryColor = Color(0xFFFFFFFF);
  static const Color secondaryColor = Color(0xFF2E3440);
  static const Color successColor = Color(0xFFA3BE8C);
  static const Color errorColor = Color(0xFFBF616A);
  static const Color warningColor = Color(0xFFEBCB8B);
  static const Color backgroundColor = Color(0xFFECEFF4);

  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double modalRadius = 24.0;
  static const double mainPadding = 20.0;
  static const double cardPadding = 16.0;

  static const TextStyle headingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFamily: 'Roboto',
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: 'Roboto',
  );

  static const TextStyle numberStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: 'Roboto',
  );

  static const Duration animationDuration = Duration(milliseconds: 300);
}

// ==================== PREDEFINED DATA ====================

class SupportedCurrencies {
  static final List<Map<String, dynamic>> cryptocurrencies = [
    {'id': 'bitcoin', 'code': 'BTC', 'name': 'Bitcoin', 'symbol': '₿'},
    {'id': 'ethereum', 'code': 'ETH', 'name': 'Ethereum', 'symbol': 'Ξ'},
    {'id': 'binancecoin', 'code': 'BNB', 'name': 'Binance Coin', 'symbol': 'BNB'},
    {'id': 'cardano', 'code': 'ADA', 'name': 'Cardano', 'symbol': '₳'},
    {'id': 'solana', 'code': 'SOL', 'name': 'Solana', 'symbol': 'SOL'},
    {'id': 'polkadot', 'code': 'DOT', 'name': 'Polkadot', 'symbol': 'DOT'},
    {'id': 'avalanche-2', 'code': 'AVAX', 'name': 'Avalanche', 'symbol': 'AVAX'},
    {'id': 'chainlink', 'code': 'LINK', 'name': 'Chainlink', 'symbol': 'LINK'},
    {'id': 'matic-network', 'code': 'MATIC', 'name': 'Polygon', 'symbol': 'MATIC'},
    {'id': 'dogecoin', 'code': 'DOGE', 'name': 'Dogecoin', 'symbol': 'Ð'},
  ];

  static final List<Map<String, String>> fiatCurrencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'KZT', 'name': 'Kazakhstan Tenge', 'symbol': '₸'},
    {'code': 'RUB', 'name': 'Russian ruble', 'symbol': '₽'},
  ];
}

// ==================== ENTITIES ====================

abstract class Currency {
  const Currency({required this.code, required this.name, required this.symbol});

  final String code;
  final String name;
  final String symbol;
}

class Cryptocurrency extends Currency {
  const Cryptocurrency({
    required super.code,
    required super.name,
    required super.symbol,
    required this.id,
    required this.currentPrice,
    required this.marketCap,
    required this.priceChangePercentage24h,
    required this.lastUpdated,
  });

  final String id;
  final double currentPrice;
  final double? marketCap;
  final double? priceChangePercentage24h;
  final DateTime lastUpdated;
}

class FiatCurrency extends Currency {
  const FiatCurrency({
    required super.code,
    required super.name,
    required super.symbol,
    required this.exchangeRate,
    required this.lastUpdated,
  });

  final double exchangeRate;
  final DateTime lastUpdated;
}

class Conversion {
  const Conversion({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.toAmount,
    required this.exchangeRate,
    required this.timestamp,
  });

  final String id;
  final Currency fromCurrency;
  final Currency toCurrency;
  final double fromAmount;
  final double toAmount;
  final double exchangeRate;
  final DateTime timestamp;
}

class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.cryptocurrency,
    required this.amount,
    required this.dateAdded,
    required this.currentValue,
    required this.priceChangePercentage,
  });

  final String id;
  final Cryptocurrency cryptocurrency;
  final double amount;
  final DateTime dateAdded;
  final double currentValue;
  final double priceChangePercentage;
}

// ==================== EXTENSIONS ====================

extension CurrencyExtensions on Currency {
  String get displayName => '$name ($code)';

  bool get isCrypto => this is Cryptocurrency;

  bool get isFiat => this is FiatCurrency;

  String formatAmount(double amount) {
    if (isFiat) {
      switch (code) {
        case AppConstants.kztCode:
          return amount.toStringAsFixed(0);
        case AppConstants.usdCode:
        case AppConstants.eurCode:
        case AppConstants.rubCode:
          return amount.toStringAsFixed(2);
        default:
          return amount.toStringAsFixed(2);
      }
    } else {
      return amount.toStringAsFixed(4);
    }
  }

  String formatWithSymbol(double amount) {
    final formattedAmount = formatAmount(amount);
    final parts = formattedAmount.split('.');
    if (parts[0].length > 3) {
      parts[0] = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ',
      );
    }
    final finalAmount = parts.join('.');
    return '$symbol$finalAmount';
  }
}

extension ConversionExtensions on Conversion {
  String get formattedFromAmount => fromCurrency.formatWithSymbol(fromAmount);
  String get formattedToAmount => toCurrency.formatWithSymbol(toAmount);
  String get conversionPair => '${fromCurrency.code}/${toCurrency.code}';
  String get formattedTimestamp =>
      '${timestamp.day}.${timestamp.month}.${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
}

// ==================== ERROR HANDLING ====================

abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}

// ==================== MODELS ====================

@freezed
@HiveType(typeId: 0)
sealed class CryptocurrencyModel with _$CryptocurrencyModel implements Cryptocurrency {
  const factory CryptocurrencyModel({
    @HiveField(0) required String id,
    @HiveField(1) required String code,
    @HiveField(2) required String name,
    @HiveField(3) required String symbol,
    @HiveField(4) required double currentPrice,
    @HiveField(5) double? marketCap,
    @HiveField(6) double? priceChangePercentage24h,
    @HiveField(7) required DateTime lastUpdated,
  }) = _CryptocurrencyModel;

  factory CryptocurrencyModel.fromJson(Map<String, dynamic> json) =>
      _$CryptocurrencyModelFromJson(json);
}

@freezed
@HiveType(typeId: 1)
sealed class FiatCurrencyModel with _$FiatCurrencyModel implements FiatCurrency {
  const factory FiatCurrencyModel({
    @HiveField(0) required String code,
    @HiveField(1) required String name,
    @HiveField(2) required String symbol,
    @HiveField(3) required double exchangeRate,
    @HiveField(4) required DateTime lastUpdated,
  }) = _FiatCurrencyModel;

  factory FiatCurrencyModel.fromJson(Map<String, dynamic> json) =>
      _$FiatCurrencyModelFromJson(json);
}

@freezed
@HiveType(typeId: 2)
sealed class ConversionModel with _$ConversionModel implements Conversion {
  const factory ConversionModel({
    @HiveField(0) required String id,
    @HiveField(1) required CurrencyModel fromCurrency,
    @HiveField(2) required CurrencyModel toCurrency,
    @HiveField(3) required double fromAmount,
    @HiveField(4) required double toAmount,
    @HiveField(5) required double exchangeRate,
    @HiveField(6) required DateTime timestamp,
  }) = _ConversionModel;

  factory ConversionModel.fromJson(Map<String, dynamic> json) => _$ConversionModelFromJson(json);
}

@freezed
@HiveType(typeId: 3)
sealed class CurrencyModel with _$CurrencyModel implements Currency {
  const factory CurrencyModel({
    @HiveField(0) required String code,
    @HiveField(1) required String name,
    @HiveField(2) required String symbol,
    @HiveField(3) required bool isCrypto,
    @HiveField(4) String? id,
  }) = _CurrencyModel;

  factory CurrencyModel.fromJson(Map<String, dynamic> json) => _$CurrencyModelFromJson(json);
}

@freezed
@HiveType(typeId: 4)
sealed class PortfolioItemModel with _$PortfolioItemModel implements PortfolioItem {
  const factory PortfolioItemModel({
    @HiveField(0) required String id,
    @HiveField(1) required CryptocurrencyModel cryptocurrency,
    @HiveField(2) required double amount,
    @HiveField(3) required DateTime dateAdded,
    @HiveField(4) required double currentValue,
    @HiveField(5) required double priceChangePercentage,
  }) = _PortfolioItemModel;

  factory PortfolioItemModel.fromJson(Map<String, dynamic> json) =>
      _$PortfolioItemModelFromJson(json);
}

// ==================== MODEL EXTENSIONS ====================

extension CryptocurrencyModelExtensions on CryptocurrencyModel {
  static CryptocurrencyModel fromEntity(Cryptocurrency entity) {
    return CryptocurrencyModel(
      id: entity.id,
      code: entity.code,
      name: entity.name,
      symbol: entity.symbol,
      currentPrice: entity.currentPrice,
      marketCap: entity.marketCap,
      priceChangePercentage24h: entity.priceChangePercentage24h,
      lastUpdated: entity.lastUpdated,
    );
  }

  Cryptocurrency toEntity() {
    return Cryptocurrency(
      id: this.id,
      code: code,
      name: name,
      symbol: symbol,
      currentPrice: currentPrice,
      marketCap: marketCap,
      priceChangePercentage24h: priceChangePercentage24h,
      lastUpdated: lastUpdated,
    );
  }
}

extension FiatCurrencyModelExtensions on FiatCurrencyModel {
  static FiatCurrencyModel fromEntity(FiatCurrency entity) {
    return FiatCurrencyModel(
      code: entity.code,
      name: entity.name,
      symbol: entity.symbol,
      exchangeRate: entity.exchangeRate,
      lastUpdated: entity.lastUpdated,
    );
  }

  FiatCurrency toEntity() {
    return FiatCurrency(
      code: code,
      name: name,
      symbol: symbol,
      exchangeRate: exchangeRate,
      lastUpdated: lastUpdated,
    );
  }
}

// ==================== USE CASES ====================

class GetCurrencyRatesUsecase {
  final CurrencyRepository repository;

  GetCurrencyRatesUsecase(this.repository);

  Future<Either<Failure, CurrencyRatesResult>> call(GetCurrencyRatesParams params) async {
    return await repository.getCurrencyRates(
      cryptocurrencies: params.cryptocurrencies,
      fiatCurrencies: params.fiatCurrencies,
      forceRefresh: params.forceRefresh,
    );
  }
}

class GetCurrencyRatesParams {
  final List<String> cryptocurrencies;
  final List<String> fiatCurrencies;
  final bool forceRefresh;

  GetCurrencyRatesParams({
    required this.cryptocurrencies,
    required this.fiatCurrencies,
    this.forceRefresh = false,
  });
}

class CurrencyRatesResult {
  final List<Cryptocurrency> cryptocurrencies;
  final List<FiatCurrency> fiatCurrencies;

  CurrencyRatesResult({required this.cryptocurrencies, required this.fiatCurrencies});
}

class ConvertCurrencyUsecase {
  final ConversionRepository repository;

  ConvertCurrencyUsecase(this.repository);

  Future<Either<Failure, ConvertCurrencyResult>> call(ConvertCurrencyParams params) async {
    return await repository.convertCurrency(
      fromCurrency: params.fromCurrency,
      toCurrency: params.toCurrency,
      amount: params.amount,
    );
  }
}

class ConvertCurrencyParams {
  final Currency fromCurrency;
  final Currency toCurrency;
  final double amount;

  ConvertCurrencyParams({
    required this.fromCurrency,
    required this.toCurrency,
    required this.amount,
  });
}

class ConvertCurrencyResult {
  final double convertedAmount;
  final double exchangeRate;
  final Conversion conversion;

  ConvertCurrencyResult({
    required this.convertedAmount,
    required this.exchangeRate,
    required this.conversion,
  });
}

class GetConversionHistoryUsecase {
  final ConversionRepository repository;

  GetConversionHistoryUsecase(this.repository);

  Future<Either<Failure, List<Conversion>>> call(GetConversionHistoryParams params) async {
    return await repository.getConversionHistory(
      filterByCurrency: params.filterByCurrency,
      limit: params.limit,
    );
  }
}

class GetConversionHistoryParams {
  final String? filterByCurrency;
  final int? limit;

  GetConversionHistoryParams({this.filterByCurrency, this.limit});
}

class ManagePortfolioUsecase {
  final PortfolioRepository repository;

  ManagePortfolioUsecase(this.repository);

  Future<Either<Failure, List<PortfolioItem>>> getPortfolio() async {
    return await repository.getPortfolio();
  }

  Future<Either<Failure, void>> addPortfolioItem(AddPortfolioItemParams params) async {
    return await repository.addPortfolioItem(
      cryptocurrency: params.cryptocurrency,
      amount: params.amount,
      dateAdded: params.dateAdded,
    );
  }

  Future<Either<Failure, void>> updatePortfolioItem(UpdatePortfolioItemParams params) async {
    return await repository.updatePortfolioItem(id: params.id, amount: params.amount);
  }

  Future<Either<Failure, void>> deletePortfolioItem(String id) async {
    return await repository.deletePortfolioItem(id);
  }

  Future<Either<Failure, double>> getTotalPortfolioValue(String baseCurrency) async {
    return await repository.getTotalPortfolioValue(baseCurrency);
  }
}

class AddPortfolioItemParams {
  final Cryptocurrency cryptocurrency;
  final double amount;
  final DateTime dateAdded;

  AddPortfolioItemParams({
    required this.cryptocurrency,
    required this.amount,
    required this.dateAdded,
  });
}

class UpdatePortfolioItemParams {
  final String id;
  final double amount;

  UpdatePortfolioItemParams({required this.id, required this.amount});
}

// ==================== REPOSITORY INTERFACES ====================

abstract class CurrencyRepository {
  Future<Either<Failure, CurrencyRatesResult>> getCurrencyRates({
    required List<String> cryptocurrencies,
    required List<String> fiatCurrencies,
    bool forceRefresh = false,
  });

  Future<Either<Failure, Cryptocurrency>> getCryptocurrencyByCode(String code);
  Future<Either<Failure, FiatCurrency>> getFiatCurrencyByCode(String code);
  Stream<List<Cryptocurrency>> watchCryptocurrencies();
  Stream<List<FiatCurrency>> watchFiatCurrencies();
}

abstract class ConversionRepository {
  Future<Either<Failure, ConvertCurrencyResult>> convertCurrency({
    required Currency fromCurrency,
    required Currency toCurrency,
    required double amount,
  });

  Future<Either<Failure, List<Conversion>>> getConversionHistory({
    String? filterByCurrency,
    int? limit,
  });

  Future<Either<Failure, void>> saveConversion(Conversion conversion);
  Future<Either<Failure, void>> exportHistoryToCsv();
  Stream<List<Conversion>> watchConversionHistory();
}

abstract class PortfolioRepository {
  Future<Either<Failure, List<PortfolioItem>>> getPortfolio();

  Future<Either<Failure, void>> addPortfolioItem({
    required Cryptocurrency cryptocurrency,
    required double amount,
    required DateTime dateAdded,
  });

  Future<Either<Failure, void>> updatePortfolioItem({required String id, required double amount});

  Future<Either<Failure, void>> deletePortfolioItem(String id);

  Future<Either<Failure, double>> getTotalPortfolioValue(String baseCurrency);

  Stream<List<PortfolioItem>> watchPortfolio();
}

// ==================== DATA SOURCES ====================

// Обновляем CoinMarketCapApi
abstract class CoinMarketCapApi {
  Future<Map<String, dynamic>> getCryptocurrencyQuotes(List<String> symbols);
  Future<Map<String, dynamic>> getFiatExchangeRates(List<String> currencies);
}

class CoinMarketCapApiImpl implements CoinMarketCapApi {
  final http.Client client;

  CoinMarketCapApiImpl({required this.client});

  @override
  Future<Map<String, dynamic>> getCryptocurrencyQuotes(
    List<String> symbols,
  ) async {
    final symbolsString = symbols.join(',');
    final url = Uri.parse(
      '${AppConstants.coinMarketCapBaseUrl}/v1/cryptocurrency/quotes/latest'
      '?symbol=$symbolsString&convert=USD',
    );

    try {
      print('Fetching crypto quotes from: $url');
      final response = await client.get(
        url,
        headers: {
          'X-CMC_PRO_API_KEY': AppConstants.coinMarketCapApiKey,
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
        if (jsonResponse['status']['error_code'] == 0) {
          return jsonResponse['data'] as Map<String, dynamic>;
        } else {
          throw ServerException(jsonResponse['status']['error_message']);
        }
      } else {
        throw ServerException('Failed to fetch cryptocurrency quotes: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Network error: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getFiatExchangeRates(
    List<String> currencies,
  ) async {
    // Используем CoinMarketCap fiat API
    final url = Uri.parse(
      '${AppConstants.coinMarketCapBaseUrl}/v1/fiat/map',
    );

    try {
      print('Fetching fiat rates from: $url');
      final response = await client.get(
        url,
        headers: {
          'X-CMC_PRO_API_KEY': AppConstants.coinMarketCapApiKey,
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
        if (jsonResponse['status']['error_code'] == 0) {
          final fiatList = jsonResponse['data'] as List;
          
          // Преобразуем в нужный формат
          final result = <String, dynamic>{};
          for (final fiat in fiatList) {
            final code = fiat['symbol'] as String;
            if (currencies.contains(code)) {
              result[code] = {
                'name': fiat['name'],
                'symbol': fiat['sign'] ?? fiat['symbol'],
                'id': fiat['id'],
              };
            }
          }
          
          // Получаем актуальные курсы через конвертацию USD
          return await _getActualFiatRates(result, currencies);
        } else {
          throw ServerException(jsonResponse['status']['error_message']);
        }
      } else {
        throw ServerException('Failed to fetch fiat exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      print('Fiat API Error: $e');
      if (e is ServerException) rethrow;
      throw ServerException('Network error: ${e.toString()}');
    }
  }

  // Получаем актуальные курсы через USD конвертацию
  Future<Map<String, dynamic>> _getActualFiatRates(
    Map<String, dynamic> fiatInfo,
    List<String> currencies,
  ) async {
    final result = <String, dynamic>{};
    
    for (final currency in currencies) {
      if (currency == 'USD') {
        result[currency] = {
          'name': 'US Dollar',
          'symbol': '\$',
          'rate': 1.0,
        };
        continue;
      }

      try {
        // Получаем курс через конвертацию 1 USD в целевую валюту
        final conversionUrl = Uri.parse(
          '${AppConstants.coinMarketCapBaseUrl}/v1/tools/price-conversion'
          '?amount=1&symbol=USD&convert=$currency',
        );

        final response = await client.get(
          conversionUrl,
          headers: {
            'X-CMC_PRO_API_KEY': AppConstants.coinMarketCapApiKey,
            'Accept': 'application/json',
          },
        ).timeout(Duration(seconds: AppConstants.apiTimeout));

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
          if (jsonResponse['status']['error_code'] == 0) {
            final data = jsonResponse['data'];
            final quote = data['quote'][currency];
            final rate = quote['price']?.toDouble() ?? 1.0;
            
            result[currency] = {
              'name': fiatInfo[currency]?['name'] ?? currency,
              'symbol': _getFiatSymbol(currency),
              'rate': rate,
            };
          }
        }
      } catch (e) {
        print('Error getting rate for $currency: $e');
        // Fallback к статичным данным если API не работает
        result[currency] = {
          'name': fiatInfo[currency]?['name'] ?? currency,
          'symbol': _getFiatSymbol(currency),
          'rate': _getFallbackRate(currency),
        };
      }
    }
    
    return result;
  }

  String _getFiatSymbol(String currency) {
    switch (currency) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'KZT': return '₸';
      case 'RUB': return '₽';
      default: return currency;
    }
  }

  double _getFallbackRate(String currency) {
    switch (currency) {
      case 'USD': return 1.0;
      case 'EUR': return 0.85;
      case 'KZT': return 450.0;
      case 'RUB': return 83.0;
      default: return 1.0;
    }
  }
}

abstract class CurrencyLocalDataSource {
  Future<List<CryptocurrencyModel>> getCachedCryptocurrencies();
  Future<List<FiatCurrencyModel>> getCachedFiatCurrencies();
  Future<void> cacheCryptocurrencies(List<CryptocurrencyModel> cryptocurrencies);
  Future<void> cacheFiatCurrencies(List<FiatCurrencyModel> fiatCurrencies);
  Future<CryptocurrencyModel?> getCryptocurrencyByCode(String code);
  Future<FiatCurrencyModel?> getFiatCurrencyByCode(String code);
  Future<bool> isCacheValid();
  Stream<List<CryptocurrencyModel>> watchCryptocurrencies();
  Stream<List<FiatCurrencyModel>> watchFiatCurrencies();
}

class CurrencyLocalDataSourceImpl implements CurrencyLocalDataSource {
  final Box<CryptocurrencyModel> _cryptoBox;
  final Box<FiatCurrencyModel> _fiatBox;
  final Box<DateTime> _cacheBox;

  CurrencyLocalDataSourceImpl({
    required Box<CryptocurrencyModel> cryptoBox,
    required Box<FiatCurrencyModel> fiatBox,
    required Box<DateTime> cacheBox,
  }) : _cryptoBox = cryptoBox,
       _fiatBox = fiatBox,
       _cacheBox = cacheBox;

  @override
  Future<List<CryptocurrencyModel>> getCachedCryptocurrencies() async {
    try {
      return _cryptoBox.values.toList();
    } catch (e) {
      throw CacheException('Failed to get cached cryptocurrencies: ${e.toString()}');
    }
  }

  @override
  Future<List<FiatCurrencyModel>> getCachedFiatCurrencies() async {
    try {
      return _fiatBox.values.toList();
    } catch (e) {
      throw CacheException('Failed to get cached fiat currencies: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheCryptocurrencies(List<CryptocurrencyModel> cryptocurrencies) async {
    try {
      await _cryptoBox.clear();
      for (final crypto in cryptocurrencies) {
        await _cryptoBox.put(crypto.code, crypto);
      }
      await _cacheBox.put('crypto_last_updated', DateTime.now());
    } catch (e) {
      throw CacheException('Failed to cache cryptocurrencies: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheFiatCurrencies(List<FiatCurrencyModel> fiatCurrencies) async {
    try {
      await _fiatBox.clear();
      for (final fiat in fiatCurrencies) {
        await _fiatBox.put(fiat.code, fiat);
      }
      await _cacheBox.put('fiat_last_updated', DateTime.now());
    } catch (e) {
      throw CacheException('Failed to cache fiat currencies: ${e.toString()}');
    }
  }

  @override
  Future<CryptocurrencyModel?> getCryptocurrencyByCode(String code) async {
    try {
      return _cryptoBox.get(code);
    } catch (e) {
      throw CacheException('Failed to get cryptocurrency by code: ${e.toString()}');
    }
  }

  @override
  Future<FiatCurrencyModel?> getFiatCurrencyByCode(String code) async {
    try {
      return _fiatBox.get(code);
    } catch (e) {
      throw CacheException('Failed to get fiat currency by code: ${e.toString()}');
    }
  }

  @override
  Future<bool> isCacheValid() async {
    try {
      final cryptoLastUpdated = _cacheBox.get('crypto_last_updated');
      final fiatLastUpdated = _cacheBox.get('fiat_last_updated');

      if (cryptoLastUpdated == null || fiatLastUpdated == null) {
        return false;
      }

      final now = DateTime.now();
      final cryptoExpired = now.difference(cryptoLastUpdated).inMinutes > 5;
      final fiatExpired = now.difference(fiatLastUpdated).inMinutes > 5;

      return !cryptoExpired && !fiatExpired;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<List<CryptocurrencyModel>> watchCryptocurrencies() {
    return _cryptoBox.watch().map((_) => _cryptoBox.values.toList());
  }

  @override
  Stream<List<FiatCurrencyModel>> watchFiatCurrencies() {
    return _fiatBox.watch().map((_) => _fiatBox.values.toList());
  }
}

abstract class ConversionLocalDataSource {
  Future<List<ConversionModel>> getConversionHistory({String? filterByCurrency, int? limit});
  Future<void> saveConversion(ConversionModel conversion);
  Future<void> clearHistory();
  Stream<List<ConversionModel>> watchConversionHistory();
}

class ConversionLocalDataSourceImpl implements ConversionLocalDataSource {
  final Box<ConversionModel> _conversionsBox;

  ConversionLocalDataSourceImpl({required Box<ConversionModel> conversionsBox})
    : _conversionsBox = conversionsBox;

  @override
  Future<List<ConversionModel>> getConversionHistory({String? filterByCurrency, int? limit}) async {
    try {
      var conversions = _conversionsBox.values.toList();

      conversions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (filterByCurrency != null) {
        conversions =
            conversions
                .where(
                  (conversion) =>
                      conversion.fromCurrency.code == filterByCurrency ||
                      conversion.toCurrency.code == filterByCurrency,
                )
                .toList();
      }

      if (limit != null && limit > 0) {
        conversions = conversions.take(limit).toList();
      }

      return conversions;
    } catch (e) {
      throw CacheException('Failed to get conversion history: ${e.toString()}');
    }
  }

  @override
  Future<void> saveConversion(ConversionModel conversion) async {
    try {
      await _conversionsBox.put(conversion.id, conversion);

      if (_conversionsBox.length > AppConstants.maxHistoryRecords) {
        final conversions = _conversionsBox.values.toList();
        conversions.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final toRemove = conversions.take(_conversionsBox.length - AppConstants.maxHistoryRecords);
        for (final old in toRemove) {
          await _conversionsBox.delete(old.id);
        }
      }
    } catch (e) {
      throw CacheException('Failed to save conversion: ${e.toString()}');
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      await _conversionsBox.clear();
    } catch (e) {
      throw CacheException('Failed to clear history: ${e.toString()}');
    }
  }

  @override
  Stream<List<ConversionModel>> watchConversionHistory() {
    return _conversionsBox.watch().map((_) => _conversionsBox.values.toList());
  }
}

abstract class PortfolioLocalDataSource {
  Future<List<PortfolioItemModel>> getPortfolio();
  Future<void> addPortfolioItem(PortfolioItemModel item);
  Future<void> updatePortfolioItem(String id, PortfolioItemModel item);
  Future<void> deletePortfolioItem(String id);
  Future<PortfolioItemModel?> getPortfolioItemById(String id);
  Stream<List<PortfolioItemModel>> watchPortfolio();
}

class PortfolioLocalDataSourceImpl implements PortfolioLocalDataSource {
  final Box<PortfolioItemModel> _portfolioBox;

  PortfolioLocalDataSourceImpl({required Box<PortfolioItemModel> portfolioBox})
    : _portfolioBox = portfolioBox;

  @override
  Future<List<PortfolioItemModel>> getPortfolio() async {
    try {
      return _portfolioBox.values.toList();
    } catch (e) {
      throw CacheException('Failed to get portfolio: ${e.toString()}');
    }
  }

  @override
  Future<void> addPortfolioItem(PortfolioItemModel item) async {
    try {
      await _portfolioBox.put(item.id, item);
    } catch (e) {
      throw CacheException('Failed to add portfolio item: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePortfolioItem(String id, PortfolioItemModel item) async {
    try {
      await _portfolioBox.put(id, item);
    } catch (e) {
      throw CacheException('Failed to update portfolio item: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePortfolioItem(String id) async {
    try {
      await _portfolioBox.delete(id);
    } catch (e) {
      throw CacheException('Failed to delete portfolio item: ${e.toString()}');
    }
  }

  @override
  Future<PortfolioItemModel?> getPortfolioItemById(String id) async {
    try {
      return _portfolioBox.get(id);
    } catch (e) {
      throw CacheException('Failed to get portfolio item by id: ${e.toString()}');
    }
  }

  @override
  Stream<List<PortfolioItemModel>> watchPortfolio() {
    return _portfolioBox.watch().map((_) => _portfolioBox.values.toList());
  }
}

// ==================== REPOSITORY IMPLEMENTATIONS ====================

class CurrencyRepositoryImpl implements CurrencyRepository {
  final CoinMarketCapApi remoteDataSource;
  final CurrencyLocalDataSource localDataSource;

  CurrencyRepositoryImpl({required this.remoteDataSource, required this.localDataSource});

  @override
  Future<Either<Failure, CurrencyRatesResult>> getCurrencyRates({
    required List<String> cryptocurrencies,
    required List<String> fiatCurrencies,
    bool forceRefresh = false,
  }) async {
    try {
      final isCacheValid = await localDataSource.isCacheValid();

      if (!forceRefresh && isCacheValid) {
        final cachedCryptos = await localDataSource.getCachedCryptocurrencies();
        final cachedFiats = await localDataSource.getCachedFiatCurrencies();

        return Right(
          CurrencyRatesResult(
            cryptocurrencies: cachedCryptos.map((c) => c.toEntity()).toList(),
            fiatCurrencies: cachedFiats.map((f) => f.toEntity()).toList(),
          ),
        );
      }

      final cryptoData = await remoteDataSource.getCryptocurrencyQuotes(cryptocurrencies);
      final fiatData = await remoteDataSource.getFiatExchangeRates(fiatCurrencies);

      final cryptoModels = _convertCryptoData(cryptoData);
      final fiatModels = _convertFiatData(fiatData);

      await localDataSource.cacheCryptocurrencies(cryptoModels);
      await localDataSource.cacheFiatCurrencies(fiatModels);

      return Right(
        CurrencyRatesResult(
          cryptocurrencies: cryptoModels.map((c) => c.toEntity()).toList(),
          fiatCurrencies: fiatModels.map((f) => f.toEntity()).toList(),
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Cryptocurrency>> getCryptocurrencyByCode(String code) async {
    try {
      final model = await localDataSource.getCryptocurrencyByCode(code);
      if (model != null) {
        return Right(model.toEntity());
      } else {
        return Left(NotFoundFailure('Cryptocurrency not found: $code'));
      }
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FiatCurrency>> getFiatCurrencyByCode(String code) async {
    try {
      final model = await localDataSource.getFiatCurrencyByCode(code);
      if (model != null) {
        return Right(model.toEntity());
      } else {
        return Left(NotFoundFailure('Fiat currency not found: $code'));
      }
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<List<Cryptocurrency>> watchCryptocurrencies() {
    return localDataSource.watchCryptocurrencies().map(
      (models) => models.map((m) => m.toEntity()).toList(),
    );
  }

  @override
  Stream<List<FiatCurrency>> watchFiatCurrencies() {
    return localDataSource.watchFiatCurrencies().map(
      (models) => models.map((m) => m.toEntity()).toList(),
    );
  }

  List<CryptocurrencyModel> _convertCryptoData(Map<String, dynamic> data) {
    final List<CryptocurrencyModel> models = [];

    for (final entry in data.entries) {
      try {
        // Для v1 API данные приходят напрямую как объект, а не массив
        final cryptoData = entry.value as Map<String, dynamic>;
        final quote = cryptoData['quote']['USD'] as Map<String, dynamic>;

        final predefined = SupportedCurrencies.cryptocurrencies.firstWhere(
          (c) => c['code'] == cryptoData['symbol'],
        );

        models.add(
          CryptocurrencyModel(
            id: predefined['id']!,
            code: cryptoData['symbol'],
            name: cryptoData['name'],
            symbol: predefined['symbol']!,
            currentPrice: quote['price']?.toDouble() ?? 0.0,
            marketCap: quote['market_cap']?.toDouble(),
            priceChangePercentage24h: quote['percent_change_24h']?.toDouble(),
            lastUpdated: DateTime.parse(quote['last_updated']),
          ),
        );

        print('Processed ${cryptoData['symbol']}: \$${quote['price']}');
      } catch (e) {
        print('Error processing crypto ${entry.key}: $e');
        continue;
      }
    }

    return models;
  }

  List<FiatCurrencyModel> _convertFiatData(Map<String, dynamic> data) {
    final List<FiatCurrencyModel> models = [];

    for (var fiat in data.entries) {
      final code = fiat.key;
      final fiatInfo = fiat.value as Map<String, dynamic>;

       models.add(
        FiatCurrencyModel(
          code: code,
          name: fiatInfo['name']!,
          symbol: fiatInfo['symbol']!,
          exchangeRate: fiatInfo['rate'],
          lastUpdated: DateTime.now(),
        ),
      );
    }

    return models;
  }
}

class ConversionRepositoryImpl implements ConversionRepository {
  final ConversionLocalDataSource localDataSource;
  final CurrencyLocalDataSource currencyLocalDataSource;

  ConversionRepositoryImpl({required this.localDataSource, required this.currencyLocalDataSource});

  @override
  Future<Either<Failure, ConvertCurrencyResult>> convertCurrency({
    required Currency fromCurrency,
    required Currency toCurrency,
    required double amount,
  }) async {
    try {
      print('Converting $amount ${fromCurrency.code} to ${toCurrency.code}');

      final fromCrypto = await currencyLocalDataSource.getCryptocurrencyByCode(fromCurrency.code);
      final fromFiat = await currencyLocalDataSource.getFiatCurrencyByCode(fromCurrency.code);
      final toCrypto = await currencyLocalDataSource.getCryptocurrencyByCode(toCurrency.code);
      final toFiat = await currencyLocalDataSource.getFiatCurrencyByCode(toCurrency.code);

      double fromPriceUSD = 1.0;
      double toPriceUSD = 1.0;

      // Получаем цену исходной валюты в USD
      if (fromCurrency.code == 'USD') {
        fromPriceUSD = 1.0;
      } else if (fromCrypto != null) {
        fromPriceUSD = fromCrypto.currentPrice;
        print('From crypto price: $fromPriceUSD USD');
      } else if (fromFiat != null) {
        // Для фиата: если это не USD, то используем обратный курс
        fromPriceUSD = fromFiat.code == 'USD' ? 1.0 : 1.0 / fromFiat.exchangeRate;
        print('From fiat price: $fromPriceUSD USD');
      }

      // Получаем цену целевой валюты в USD
      if (toCurrency.code == 'USD') {
        toPriceUSD = 1.0;
      } else if (toCrypto != null) {
        toPriceUSD = toCrypto.currentPrice;
        print('To crypto price: $toPriceUSD USD');
      } else if (toFiat != null) {
        // Для фиата: если это не USD, то используем обратный курс
        toPriceUSD = toFiat.code == 'USD' ? 1.0 : 1.0 / toFiat.exchangeRate;
        print('To fiat price: $toPriceUSD USD');
      }

      // Рассчитываем курс и конвертированную сумму
      final exchangeRate = fromPriceUSD / toPriceUSD;
      final convertedAmount = amount * exchangeRate;

      print('Exchange rate: $exchangeRate, Converted: $convertedAmount');

      final conversion = ConversionModel(
        id: UuidGenerator.generate(),
        fromCurrency: CurrencyModel(
          code: fromCurrency.code,
          name: fromCurrency.name,
          symbol: fromCurrency.symbol,
          isCrypto: fromCurrency.isCrypto,
          id: fromCurrency is Cryptocurrency ? fromCurrency.id : null,
        ),
        toCurrency: CurrencyModel(
          code: toCurrency.code,
          name: toCurrency.name,
          symbol: toCurrency.symbol,
          isCrypto: toCurrency.isCrypto,
          id: toCurrency is Cryptocurrency ? toCurrency.id : null,
        ),
        fromAmount: amount,
        toAmount: convertedAmount,
        exchangeRate: exchangeRate,
        timestamp: DateTime.now(),
      );

      await localDataSource.saveConversion(conversion);

      return Right(
        ConvertCurrencyResult(
          convertedAmount: convertedAmount,
          exchangeRate: exchangeRate,
          conversion: conversion,
        ),
      );
    } on CacheException catch (e) {
      print('Cache error: ${e.message}');
      return Left(CacheFailure(e.message));
    } catch (e) {
      print('Conversion error: $e');
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Conversion>>> getConversionHistory({
    String? filterByCurrency,
    int? limit,
  }) async {
    try {
      final models = await localDataSource.getConversionHistory(
        filterByCurrency: filterByCurrency,
        limit: limit,
      );
      return Right(models);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveConversion(Conversion conversion) async {
    try {
      final model = ConversionModel(
        id: conversion.id,
        fromCurrency: CurrencyModel(
          code: conversion.fromCurrency.code,
          name: conversion.fromCurrency.name,
          symbol: conversion.fromCurrency.symbol,
          isCrypto: conversion.fromCurrency.isCrypto,
        ),
        toCurrency: CurrencyModel(
          code: conversion.toCurrency.code,
          name: conversion.toCurrency.name,
          symbol: conversion.toCurrency.symbol,
          isCrypto: conversion.toCurrency.isCrypto,
        ),
        fromAmount: conversion.fromAmount,
        toAmount: conversion.toAmount,
        exchangeRate: conversion.exchangeRate,
        timestamp: conversion.timestamp,
      );

      await localDataSource.saveConversion(model);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> exportHistoryToCsv() async {
    try {
      final conversions = await localDataSource.getConversionHistory();
      final csvContent = _generateCsvContent(conversions);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/conversion_history.csv');
      await file.writeAsString(csvContent);

      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<List<Conversion>> watchConversionHistory() {
    return localDataSource.watchConversionHistory();
  }

  String _generateCsvContent(List<ConversionModel> conversions) {
    final buffer = StringBuffer();

    buffer.writeln('Date,From Currency,From Amount,To Currency,To Amount,Exchange Rate');

    for (final conversion in conversions) {
      buffer.writeln(
        [
          conversion.timestamp.toIso8601String(),
          conversion.fromCurrency.code,
          conversion.fromAmount,
          conversion.toCurrency.code,
          conversion.toAmount,
          conversion.exchangeRate,
        ].join(','),
      );
    }

    return buffer.toString();
  }
}

class PortfolioRepositoryImpl implements PortfolioRepository {
  final PortfolioLocalDataSource localDataSource;

  PortfolioRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<PortfolioItem>>> getPortfolio() async {
    try {
      final models = await localDataSource.getPortfolio();
      return Right(models);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addPortfolioItem({
    required Cryptocurrency cryptocurrency,
    required double amount,
    required DateTime dateAdded,
  }) async {
    try {
      final item = PortfolioItemModel(
        id: UuidGenerator.generate(),
        cryptocurrency: CryptocurrencyModelExtensions.fromEntity(cryptocurrency),
        amount: amount,
        dateAdded: dateAdded,
        currentValue: amount * cryptocurrency.currentPrice,
        priceChangePercentage: cryptocurrency.priceChangePercentage24h ?? 0.0,
      );

      await localDataSource.addPortfolioItem(item);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePortfolioItem({
    required String id,
    required double amount,
  }) async {
    try {
      final existingItem = await localDataSource.getPortfolioItemById(id);
      if (existingItem == null) {
        return Left(NotFoundFailure('Portfolio item not found'));
      }

      final updatedItem = existingItem.copyWith(
        amount: amount,
        currentValue: amount * existingItem.cryptocurrency.currentPrice,
      );

      await localDataSource.updatePortfolioItem(id, updatedItem);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePortfolioItem(String id) async {
    try {
      await localDataSource.deletePortfolioItem(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalPortfolioValue(String baseCurrency) async {
    try {
      final items = await localDataSource.getPortfolio();
      double total = 0.0;

      for (final item in items) {
        total += item.currentValue;
      }

      return Right(total);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<List<PortfolioItem>> watchPortfolio() {
    return localDataSource.watchPortfolio();
  }
}

// ==================== UTILS ====================

class UuidGenerator {
  static String generate() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '${timestamp}_$randomPart';
  }
}

class InputValidators {
  static bool isValidAmount(String input) {
    if (input.isEmpty) return false;

    final amount = double.tryParse(input);
    if (amount == null) return false;

    return amount >= AppConstants.minAmount && amount <= AppConstants.maxAmount;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid number';
    }

    if (amount < AppConstants.minAmount) {
      return 'Amount must be at least ${AppConstants.minAmount}';
    }

    if (amount > AppConstants.maxAmount) {
      return 'Amount must be less than ${AppConstants.maxAmount}';
    }

    final parts = value.split('.');
    if (parts.length > 1 && parts[1].length > AppConstants.maxDecimalPlaces) {
      return 'Maximum ${AppConstants.maxDecimalPlaces} decimal places allowed';
    }

    return null;
  }

  static String formatAmountInput(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');

    final parts = cleaned.split('.');
    if (parts.length > 2) {
      return '${parts[0]}.${parts.sublist(1).join('')}';
    }

    if (parts.length == 2 && parts[1].length > AppConstants.maxDecimalPlaces) {
      parts[1] = parts[1].substring(0, AppConstants.maxDecimalPlaces);
    }

    return parts.join('.');
  }
}

class NumberFormatter {
  static String formatCurrency(double amount, String currencyCode) {
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: _getDecimalPlaces(currencyCode),
    );

    return formatter.format(amount).trim();
  }

  static String formatWithThousandsSeparator(double amount) {
    final formatter = NumberFormat('#,##0.####');
    return formatter.format(amount).replaceAll(',', ' ');
  }

  static int _getDecimalPlaces(String currencyCode) {
    switch (currencyCode) {
      case 'KZT':
        return 0;
      case 'USD':
      case 'EUR':
      case 'RUB':
        return 2;
      default:
        return 4;
    }
  }
}

// ==================== HIVE INITIALIZATION ====================

class HiveInitializer {
  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    Hive.init(directory.path);

    await _registerAdapters();
    await _openBoxes();
  }

  static Future<void> _registerAdapters() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CryptocurrencyModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FiatCurrencyModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ConversionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CurrencyModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(PortfolioItemModelAdapter());
    }
  }

  static Future<void> _openBoxes() async {
    await Hive.openBox<CryptocurrencyModel>('cryptocurrencies');
    await Hive.openBox<FiatCurrencyModel>('fiat_currencies');
    await Hive.openBox<ConversionModel>('conversions');
    await Hive.openBox<PortfolioItemModel>('portfolio');
    await Hive.openBox<DateTime>('cache_timestamps');
  }

  static Future<void> closeBoxes() async {
    await Hive.close();
  }

  static Future<void> clearAllData() async {
    await Hive.box<CryptocurrencyModel>('cryptocurrencies').clear();
    await Hive.box<FiatCurrencyModel>('fiat_currencies').clear();
    await Hive.box<ConversionModel>('conversions').clear();
    await Hive.box<PortfolioItemModel>('portfolio').clear();
    await Hive.box<DateTime>('cache_timestamps').clear();
  }
}

// ==================== PROVIDERS ====================

class ConverterProvider extends ChangeNotifier {
  final ConvertCurrencyUsecase _convertCurrencyUsecase;
  final GetCurrencyRatesUsecase _getCurrencyRatesUsecase;

  ConverterProvider({
    required ConvertCurrencyUsecase convertCurrencyUsecase,
    required GetCurrencyRatesUsecase getCurrencyRatesUsecase,
  }) : _convertCurrencyUsecase = convertCurrencyUsecase,
       _getCurrencyRatesUsecase = getCurrencyRatesUsecase;

  ApiStatus _status = ApiStatus.initial;
  String? _errorMessage;

  Currency? _fromCurrency;
  Currency? _toCurrency;
  double _fromAmount = AppConstants.defaultAmount;
  double _toAmount = 0.0;
  double _exchangeRate = 0.0;

  List<Currency> _availableCurrencies = [];
  List<String> _recentCurrencyPairs = [];
  ConversionDirection _lastInputDirection = ConversionDirection.fromTo;

  ApiStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Currency? get fromCurrency => _fromCurrency;
  Currency? get toCurrency => _toCurrency;
  double get fromAmount => _fromAmount;
  double get toAmount => _toAmount;
  double get exchangeRate => _exchangeRate;
  List<Currency> get availableCurrencies => _availableCurrencies;
  List<String> get recentCurrencyPairs => _recentCurrencyPairs;
  bool get isLoading => _status == ApiStatus.loading;
  bool get hasError => _status == ApiStatus.error;

  Future<void> initialize() async {
    await loadCurrencyRates();
    _setDefaultCurrencies();
  }

  Future<void> loadCurrencyRates({bool forceRefresh = false}) async {
    _setStatus(ApiStatus.loading);

    final result = await _getCurrencyRatesUsecase(
      GetCurrencyRatesParams(
        cryptocurrencies:
            SupportedCurrencies.cryptocurrencies.map((c) => c['code']! as String).toList(),
        fiatCurrencies: SupportedCurrencies.fiatCurrencies.map((f) => f['code']!).toList(),
        forceRefresh: forceRefresh,
      ),
    );

    result.fold(
      (failure) {
        _setStatus(ApiStatus.error);
        _errorMessage = failure.message;
      },
      (currencyRates) {
        final List<Currency> currencies = [];
        currencies.addAll(currencyRates.cryptocurrencies);
        currencies.addAll(currencyRates.fiatCurrencies);

        _availableCurrencies = currencies;
        _setStatus(ApiStatus.loaded);
        _errorMessage = null;

        if (_fromCurrency != null && _toCurrency != null) {
          _performConversion();
        }
      },
    );
  }

  void setFromCurrency(Currency currency) {
    if (_fromCurrency?.code != currency.code) {
      _fromCurrency = currency;
      _addToRecentPairs();
      _performConversion();
      _triggerHapticFeedback();
    }
  }

  void setToCurrency(Currency currency) {
    if (_toCurrency?.code != currency.code) {
      _toCurrency = currency;
      _addToRecentPairs();
      _performConversion();
      _triggerHapticFeedback();
    }
  }

  void setFromAmount(double amount) {
    if (_fromAmount != amount) {
      _fromAmount = amount;
      _lastInputDirection = ConversionDirection.fromTo;
      _performConversion();
    }
  }

  void setToAmount(double amount) {
    if (_toAmount != amount) {
      _toAmount = amount;
      _lastInputDirection = ConversionDirection.toFrom;
      _performReverseConversion();
    }
  }

  void swapCurrencies() {
    if (_fromCurrency != null && _toCurrency != null) {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;

      _addToRecentPairs();
      _performConversion();
      _triggerHapticFeedback();
    }
  }

  void selectRecentPair(String pair) {
    final parts = pair.split('/');
    if (parts.length == 2) {
      final fromCurrency = _availableCurrencies.firstWhere(
        (c) => c.code == parts[0],
        orElse: () => _availableCurrencies.first,
      );
      final toCurrency = _availableCurrencies.firstWhere(
        (c) => c.code == parts[1],
        orElse: () => _availableCurrencies.last,
      );

      _fromCurrency = fromCurrency;
      _toCurrency = toCurrency;
      _performConversion();
      _triggerHapticFeedback();
    }
  }

  void clearError() {
    _errorMessage = null;
    _setStatus(ApiStatus.loaded);
  }

  void _setDefaultCurrencies() {
    if (_availableCurrencies.isNotEmpty) {
      _fromCurrency ??= _availableCurrencies.firstWhere(
        (c) => c.code == AppConstants.defaultFromCurrency,
        orElse: () => _availableCurrencies.first,
      );

      _toCurrency ??= _availableCurrencies.firstWhere(
        (c) => c.code == AppConstants.defaultToCurrency,
        orElse: () => _availableCurrencies.last,
      );

      _performConversion();
    }
  }

  Future<void> _performConversion() async {
    if (_fromCurrency == null || _toCurrency == null || _fromAmount <= 0) {
      print('Cannot perform conversion: missing currency or amount');
      return;
    }

    print('Performing conversion: $_fromAmount ${_fromCurrency!.code} -> ${_toCurrency!.code}');

    final result = await _convertCurrencyUsecase(
      ConvertCurrencyParams(
        fromCurrency: _fromCurrency!,
        toCurrency: _toCurrency!,
        amount: _fromAmount,
      ),
    );

    result.fold(
      (failure) {
        print('Conversion failed: ${failure.message}');
        _errorMessage = failure.message;
      },
      (conversionResult) {
        print('Conversion successful: ${conversionResult.convertedAmount}');
        _toAmount = conversionResult.convertedAmount;
        _exchangeRate = conversionResult.exchangeRate;
        _errorMessage = null;
      },
    );

    notifyListeners();
  }

  Future<void> _performReverseConversion() async {
    if (_fromCurrency == null || _toCurrency == null || _toAmount <= 0) {
      return;
    }

    final result = await _convertCurrencyUsecase(
      ConvertCurrencyParams(
        fromCurrency: _toCurrency!,
        toCurrency: _fromCurrency!,
        amount: _toAmount,
      ),
    );

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (conversionResult) {
        _fromAmount = conversionResult.convertedAmount;
        _exchangeRate = 1.0 / conversionResult.exchangeRate;
        _errorMessage = null;
      },
    );

    notifyListeners();
  }

  void _addToRecentPairs() {
    if (_fromCurrency != null && _toCurrency != null) {
      final pair = '${_fromCurrency!.code}/${_toCurrency!.code}';
      _recentCurrencyPairs.remove(pair);
      _recentCurrencyPairs.insert(0, pair);

      if (_recentCurrencyPairs.length > 3) {
        _recentCurrencyPairs = _recentCurrencyPairs.take(3).toList();
      }
    }
  }

  void _setStatus(ApiStatus status) {
    _status = status;
    notifyListeners();
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }
}

class HistoryProvider extends ChangeNotifier {
  final GetConversionHistoryUsecase _getConversionHistoryUsecase;
  HistoryProvider({required GetConversionHistoryUsecase getConversionHistoryUsecase})
    : _getConversionHistoryUsecase = getConversionHistoryUsecase;

  ApiStatus _status = ApiStatus.initial;
  String? _errorMessage;
  List<Conversion> _conversions = [];
  List<Conversion> _filteredConversions = [];
  String? _currencyFilter;
  SortOption _sortOption = SortOption.dateDesc;

  ApiStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<Conversion> get conversions => _filteredConversions;
  String? get currencyFilter => _currencyFilter;
  SortOption get sortOption => _sortOption;
  bool get isLoading => _status == ApiStatus.loading;
  bool get hasError => _status == ApiStatus.error;
  bool get isEmpty => _filteredConversions.isEmpty;

  Future<void> loadHistory() async {
    _setStatus(ApiStatus.loading);

    final result = await _getConversionHistoryUsecase(GetConversionHistoryParams());

    result.fold(
      (failure) {
        _setStatus(ApiStatus.error);
        _errorMessage = failure.message;
      },
      (conversions) {
        _conversions = conversions;
        _applyFiltersAndSort();
        _setStatus(ApiStatus.loaded);
        _errorMessage = null;
      },
    );
  }

  void setCurrencyFilter(String? currency) {
    if (_currencyFilter != currency) {
      _currencyFilter = currency;
      _applyFiltersAndSort();
    }
  }

  void setSortOption(SortOption option) {
    if (_sortOption != option) {
      _sortOption = option;
      _applyFiltersAndSort();
    }
  }

  void clearFilter() {
    _currencyFilter = null;
    _applyFiltersAndSort();
  }

  void clearError() {
    _errorMessage = null;
    _setStatus(ApiStatus.loaded);
  }

  List<String> getAvailableCurrencies() {
    final currencies = <String>{};
    for (final conversion in _conversions) {
      currencies.add(conversion.fromCurrency.code);
      currencies.add(conversion.toCurrency.code);
    }
    return currencies.toList()..sort();
  }

  void _applyFiltersAndSort() {
    var filtered = List<Conversion>.from(_conversions);

    if (_currencyFilter != null) {
      filtered =
          filtered
              .where(
                (conversion) =>
                    conversion.fromCurrency.code == _currencyFilter ||
                    conversion.toCurrency.code == _currencyFilter,
              )
              .toList();
    }

    switch (_sortOption) {
      case SortOption.dateAsc:
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortOption.dateDesc:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortOption.nameAsc:
        filtered.sort((a, b) => a.fromCurrency.code.compareTo(b.fromCurrency.code));
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) => b.fromCurrency.code.compareTo(a.fromCurrency.code));
        break;
      case SortOption.priceAsc:
        filtered.sort((a, b) => a.fromAmount.compareTo(b.fromAmount));
        break;
      case SortOption.priceDesc:
        filtered.sort((a, b) => b.fromAmount.compareTo(a.fromAmount));
        break;
    }

    _filteredConversions = filtered;
    notifyListeners();
  }

  void _setStatus(ApiStatus status) {
    _status = status;
    notifyListeners();
  }
}

class PortfolioProvider extends ChangeNotifier {
  final ManagePortfolioUsecase _managePortfolioUsecase;

  PortfolioProvider({required ManagePortfolioUsecase managePortfolioUsecase})
    : _managePortfolioUsecase = managePortfolioUsecase;

  ApiStatus _status = ApiStatus.initial;
  String? _errorMessage;
  List<PortfolioItem> _portfolioItems = [];
  double _totalValue = 0.0;
  String _baseCurrency = AppConstants.usdCode;

  ApiStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<PortfolioItem> get portfolioItems => _portfolioItems;
  double get totalValue => _totalValue;
  String get baseCurrency => _baseCurrency;
  bool get isLoading => _status == ApiStatus.loading;
  bool get hasError => _status == ApiStatus.error;
  bool get isEmpty => _portfolioItems.isEmpty;

  Future<void> loadPortfolio() async {
    _setStatus(ApiStatus.loading);

    final result = await _managePortfolioUsecase.getPortfolio();

    result.fold(
      (failure) {
        _setStatus(ApiStatus.error);
        _errorMessage = failure.message;
      },
      (items) {
        _portfolioItems = items;
        _calculateTotalValue();
        _setStatus(ApiStatus.loaded);
        _errorMessage = null;
      },
    );
  }

  Future<void> addPortfolioItem({
    required Cryptocurrency cryptocurrency,
    required double amount,
    required DateTime dateAdded,
  }) async {
    final result = await _managePortfolioUsecase.addPortfolioItem(
      AddPortfolioItemParams(cryptocurrency: cryptocurrency, amount: amount, dateAdded: dateAdded),
    );

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {
        loadPortfolio();
      },
    );
  }

  Future<void> updatePortfolioItem({required String id, required double amount}) async {
    final result = await _managePortfolioUsecase.updatePortfolioItem(
      UpdatePortfolioItemParams(id: id, amount: amount),
    );

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {
        loadPortfolio();
      },
    );
  }

  Future<void> deletePortfolioItem(String id) async {
    final result = await _managePortfolioUsecase.deletePortfolioItem(id);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {
        loadPortfolio();
      },
    );
  }

  void setBaseCurrency(String currency) {
    if (_baseCurrency != currency) {
      _baseCurrency = currency;
      _calculateTotalValue();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _calculateTotalValue() async {
    final result = await _managePortfolioUsecase.getTotalPortfolioValue(_baseCurrency);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (value) {
        _totalValue = value;
      },
    );

    notifyListeners();
  }

  void _setStatus(ApiStatus status) {
    _status = status;
    notifyListeners();
  }
}

// ==================== ROUTING ====================

class AppRoutes {
  static const String converter = '/converter';
  static const String history = '/history';
  static const String portfolio = '/portfolio';
  static const String currencySelection = '/currency-selection';
  static const String addToken = '/add-token';
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.converter,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.converter,
                builder: (context, state) => const ConverterScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppRoutes.history, builder: (context, state) => const HistoryScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.portfolio,
                builder: (context, state) => const PortfolioScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.currencySelection,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _buildSlideTransitionPage(
            context,
            state,
            CurrencySelectionModal(
              currencyType: extra?['currencyType'] as CurrencyType? ?? CurrencyType.cryptocurrency,
              onCurrencySelected: extra?['onCurrencySelected'] as Function(Currency)?,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.addToken,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _buildSlideTransitionPage(
            context,
            state,
            AddTokenModal(onTokenAdded: extra?['onTokenAdded'] as VoidCallback?),
          );
        },
      ),
    ],
  );

  static Page<T> _buildSlideTransitionPage<T extends Object?>(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: animation.drive(
            Tween(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeInOut)),
          ),
          child: child,
        );
      },
    );
  }
}

// ==================== DEPENDENCY INJECTION ====================

class ProviderSetup {
  static Widget wrapWithProviders(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConverterProvider>(
          create: (_) => getIt<ConverterProvider>()..initialize(),
        ),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => getIt<HistoryProvider>()..loadHistory(),
        ),
        ChangeNotifierProvider<PortfolioProvider>(
          create: (_) => getIt<PortfolioProvider>()..loadPortfolio(),
        ),
      ],
      child: child,
    );
  }
}

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt.registerLazySingleton<http.Client>(() => http.Client());

  getIt.registerLazySingleton<Box<CryptocurrencyModel>>(
    () => Hive.box<CryptocurrencyModel>('cryptocurrencies'),
  );
  getIt.registerLazySingleton<Box<FiatCurrencyModel>>(
    () => Hive.box<FiatCurrencyModel>('fiat_currencies'),
  );
  getIt.registerLazySingleton<Box<ConversionModel>>(() => Hive.box<ConversionModel>('conversions'));
  getIt.registerLazySingleton<Box<PortfolioItemModel>>(
    () => Hive.box<PortfolioItemModel>('portfolio'),
  );
  getIt.registerLazySingleton<Box<DateTime>>(() => Hive.box<DateTime>('cache_timestamps'));

  getIt.registerLazySingleton<CoinMarketCapApi>(() => CoinMarketCapApiImpl(client: getIt()));
  getIt.registerLazySingleton<CurrencyLocalDataSource>(
    () => CurrencyLocalDataSourceImpl(cryptoBox: getIt(), fiatBox: getIt(), cacheBox: getIt()),
  );
  getIt.registerLazySingleton<ConversionLocalDataSource>(
    () => ConversionLocalDataSourceImpl(conversionsBox: getIt()),
  );
  getIt.registerLazySingleton<PortfolioLocalDataSource>(
    () => PortfolioLocalDataSourceImpl(portfolioBox: getIt()),
  );

  getIt.registerLazySingleton<CurrencyRepository>(
    () => CurrencyRepositoryImpl(remoteDataSource: getIt(), localDataSource: getIt()),
  );
  getIt.registerLazySingleton<ConversionRepository>(
    () => ConversionRepositoryImpl(localDataSource: getIt(), currencyLocalDataSource: getIt()),
  );
  getIt.registerLazySingleton<PortfolioRepository>(
    () => PortfolioRepositoryImpl(localDataSource: getIt()),
  );

  getIt.registerLazySingleton(() => GetCurrencyRatesUsecase(getIt()));
  getIt.registerLazySingleton(() => ConvertCurrencyUsecase(getIt()));
  getIt.registerLazySingleton(() => GetConversionHistoryUsecase(getIt()));
  getIt.registerLazySingleton(() => ManagePortfolioUsecase(getIt()));

  getIt.registerFactory(
    () => ConverterProvider(convertCurrencyUsecase: getIt(), getCurrencyRatesUsecase: getIt()),
  );
  getIt.registerFactory(() => HistoryProvider(getConversionHistoryUsecase: getIt()));
  getIt.registerFactory(() => PortfolioProvider(managePortfolioUsecase: getIt()));
}

// ==================== UI COMPONENTS ====================

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Color? color;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: color ?? UIConstants.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius ?? UIConstants.cardRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius ?? UIConstants.cardRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(UIConstants.cardPadding),
          child: child,
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? radius;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.radius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius ?? UIConstants.buttonRadius),
          ),
          side: BorderSide(color: backgroundColor ?? theme.primaryColor),
        ),
        child:
            isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(
                  text,
                  style: UIConstants.bodyStyle.copyWith(color: textColor ?? theme.primaryColor),
                ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? theme.primaryColor,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius ?? UIConstants.buttonRadius),
        ),
      ),
      child:
          isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : Text(text, style: UIConstants.bodyStyle.copyWith(color: textColor ?? Colors.white)),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? value;
  final TextEditingController? controller; // Добавляем controller
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool isNumeric;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final int? maxLines;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.value,
    this.controller, // Добавляем в конструктор
    this.onChanged,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.isNumeric = false,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller, // Используем controller если есть
          initialValue:
              controller == null ? value : null, // initialValue только если нет controller
          onChanged: isNumeric ? _handleNumericInput : onChanged,
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          inputFormatters:
              isNumeric
                  ? [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: InputValidators.formatAmountInput(newValue.text),
                        selection: newValue.selection,
                      );
                    }),
                  ]
                  : null,
          style: isNumeric ? UIConstants.numberStyle : UIConstants.bodyStyle,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
              borderSide: const BorderSide(color: Colors.grey, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
              borderSide: const BorderSide(color: Colors.grey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
              borderSide: const BorderSide(color: UIConstants.errorColor, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  void _handleNumericInput(String value) {
    if (InputValidators.isValidAmount(value) || value.isEmpty) {
      onChanged?.call(value);
    }
  }
}

class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool showCard;

  const LoadingWidget({super.key, this.message, this.showCard = true});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!, style: UIConstants.bodyStyle, textAlign: TextAlign.center),
        ],
      ],
    );

    if (showCard) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(UIConstants.cardPadding * 2),
            child: content,
          ),
        ),
      );
    }

    return Center(child: content);
  }
}

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool showCard;

  const CustomErrorWidget({super.key, required this.message, this.onRetry, this.showCard = true});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: UIConstants.errorColor),
        const SizedBox(height: 16),
        Text(message, style: UIConstants.bodyStyle, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          CustomButton(text: 'Retry', onPressed: onRetry, isOutlined: true),
        ],
      ],
    );

    if (showCard) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(UIConstants.cardPadding * 2),
            child: content,
          ),
        ),
      );
    }

    return Center(child: content);
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.mainPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: UIConstants.headingStyle.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: UIConstants.bodyStyle.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

// ==================== CONVERTER WIDGETS ====================

class CurrencySelector extends StatelessWidget {
  final Currency? currency;
  final VoidCallback onTap;
  final bool isLoading;

  const CurrencySelector({
    super.key,
    required this.currency,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: isLoading ? null : onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currency != null) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      currency!.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency!.code,
                      style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      currency!.name,
                      style: UIConstants.bodyStyle.copyWith(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Text('Select Currency', style: UIConstants.bodyStyle.copyWith(color: Colors.grey[600])),
          ],
          Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
        ],
      ),
    );
  }
}

class AmountInput extends StatefulWidget {
  final double amount;
  final ValueChanged<double> onAmountChanged;
  final bool readOnly;
  final String? hint;
  final List<TextInputFormatter>? inputFormatters;

  const AmountInput({
    super.key,
    required this.amount,
    required this.onAmountChanged,
    this.readOnly = false,
    this.hint,
    this.inputFormatters,
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late TextEditingController _controller;
  bool _isUpdatingFromParent = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.amount == 0.0 ? '' : widget.amount.toString());
  }

  @override
  void didUpdateWidget(AmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Обновляем текст только если значение изменилось извне (не от пользователя)
    if (widget.amount != oldWidget.amount && !_isUpdatingFromParent) {
      final newText = widget.amount == 0.0 ? '' : widget.amount.toString();
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        controller: _controller,
        // focusNode: focusNode,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: widget.inputFormatters,
        textAlign: TextAlign.right,
        style: AppTheme.dataTextStyle(
          isLight: true,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '0.0000',
          hintStyle: AppTheme.dataTextStyle(
            isLight: true,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ).copyWith(
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 2,
          ),
        ),
        onChanged: (value) {
          _isUpdatingFromParent = true;
          final parsedAmount = double.tryParse(value) ?? 0.0;
          widget.onAmountChanged(parsedAmount);
          _isUpdatingFromParent = false;
        },
      );
  }
}

class SwapButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const SwapButton({super.key, required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: UIConstants.primaryColor,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: IconButton(
        onPressed: isLoading ? null : onPressed,
        icon: AnimatedRotation(
          turns: isLoading ? 1 : 0,
          duration: UIConstants.animationDuration,
          child: const Icon(Icons.swap_vert, size: 24),
        ),
      ),
    );
  }
}

class RecentPairs extends StatelessWidget {
  final List<String> recentPairs;
  final Function(String) onPairSelected;

  const RecentPairs({super.key, required this.recentPairs, required this.onPairSelected});

  @override
  Widget build(BuildContext context) {
    if (recentPairs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Pairs',
          style: UIConstants.bodyStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recentPairs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final pair = recentPairs[index];
              return CustomCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onTap: () => onPairSelected(pair),
                child: Text(
                  pair,
                  style: UIConstants.bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==================== SCREENS ====================

class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: UIConstants.primaryColor,
        selectedItemColor: UIConstants.secondaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Converter'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
        ],
      ),
    );
  }
}

class ConverterScreen extends StatelessWidget {
  const ConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(AppConstants.appName, style: UIConstants.headingStyle),
        backgroundColor: UIConstants.primaryColor,
        elevation: 0,
        actions: [
          Consumer<ConverterProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    provider.isLoading
                        ? null
                        : () => provider.loadCurrencyRates(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: Consumer<ConverterProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.availableCurrencies.isEmpty) {
            return const LoadingWidget(message: 'Loading currency rates...');
          }

          if (provider.hasError && provider.availableCurrencies.isEmpty) {
            return CustomErrorWidget(
              message: provider.errorMessage ?? 'Failed to load currencies',
              onRetry: () => provider.loadCurrencyRates(forceRefresh: true),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(UIConstants.mainPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.fromCurrency != null && provider.toCurrency != null)
                  _buildExchangeRateCard(provider),

                const SizedBox(height: UIConstants.mainPadding),

                CurrencySection(
                  title: 'From',
                  currency: provider.fromCurrency,
                  amount: provider.fromAmount,
                  onCurrencyTap:
                      () => _showCurrencySelection(
                        context,
                        CurrencyType.cryptocurrency,
                        provider.setFromCurrency,
                      ),
                  onAmountChanged: provider.setFromAmount,
                  isLoading: provider.isLoading,
                ),

                const SizedBox(height: UIConstants.mainPadding),

                Center(
                  child: SwapButton(
                    onPressed: provider.swapCurrencies,
                    isLoading: provider.isLoading,
                  ),
                ),

                const SizedBox(height: UIConstants.mainPadding),

                CurrencySection(
                  title: 'To',
                  currency: provider.toCurrency,
                  amount: provider.toAmount,
                  onCurrencyTap:
                      () => _showCurrencySelection(
                        context,
                        CurrencyType.fiat,
                        provider.setToCurrency,
                      ),
                  onAmountChanged: provider.setToAmount,
                  isLoading: provider.isLoading,
                  readOnly: false,
                ),

                if (provider.recentCurrencyPairs.isNotEmpty)
                  const SizedBox(height: UIConstants.mainPadding),

                RecentPairs(
                  recentPairs: provider.recentCurrencyPairs,
                  onPairSelected: provider.selectRecentPair,
                ),

                

                if (provider.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: UIConstants.mainPadding),
                    padding: const EdgeInsets.all(UIConstants.cardPadding),
                    decoration: BoxDecoration(
                      color: UIConstants.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                      border: Border.all(color: UIConstants.errorColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: UIConstants.errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: UIConstants.bodyStyle.copyWith(color: UIConstants.errorColor),
                          ),
                        ),
                        TextButton(onPressed: provider.clearError, child: const Text('Dismiss')),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExchangeRateCard(ConverterProvider provider) {
    return Card(
      color: UIConstants.primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.cardPadding),
        child: Wrap(
          children: [
            Text(
              'Exchange Rate ',
              style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w400),
            ),
            Text(
              '1 ${provider.fromCurrency!.code} = ${provider.exchangeRate.toStringAsFixed(2)} ${provider.toCurrency!.code}',
              style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencySelection(
    BuildContext context,
    CurrencyType currencyType,
    Function(Currency) onCurrencySelected,
  ) {
    context.push(
      AppRoutes.currencySelection,
      extra: {'currencyType': currencyType, 'onCurrencySelected': onCurrencySelected},
    );
  }
}

class CurrencySection extends StatelessWidget {
  const CurrencySection({
    super.key,
    required this.title,
    required this.currency,
    required this.amount,
    required this.onCurrencyTap,
    required this.onAmountChanged,
    required this.isLoading,
    bool readOnly = false,
  });

  final String title;
  final Currency? currency;
  final double amount;
  final VoidCallback onCurrencyTap;
  final ValueChanged<double> onAmountChanged;
  final bool isLoading;
  final bool readOnly = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Currency selection button
          GestureDetector(
            onTap: onCurrencyTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currency?.symbol ?? '',
                    style: TextStyle(
                      color: AppTheme.accent,
                    ),
                  ),
                  SizedBox(width: 2),
                  Text(
                    currency?.name ?? '',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondary,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, 
                    color: AppTheme.textSecondary,
                    size: 4,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 2),

          // Amount input field
          isLoading
              ? Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 6,
                      height: 6,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                )
              : AmountInput(
                  amount: amount, 
                  onAmountChanged: onAmountChanged, 
                  readOnly: readOnly,
                  inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                ),
             
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Conversion History', style: UIConstants.headingStyle),
        backgroundColor: UIConstants.primaryColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            onSelected: (value) {
              if (value == 'export') {
                _exportToCsv(context);
              }
            },
            itemBuilder:
                (context) => [const PopupMenuItem(value: 'export', child: Text('Export to CSV'))],
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              context.read<HistoryProvider>().setSortOption(option);
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: SortOption.dateDesc,
                    child: Text('Date (Newest First)'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.dateAsc,
                    child: Text('Date (Oldest First)'),
                  ),
                  const PopupMenuItem(value: SortOption.nameAsc, child: Text('Currency (A-Z)')),
                  const PopupMenuItem(value: SortOption.nameDesc, child: Text('Currency (Z-A)')),
                ],
          ),
        ],
      ),
      body: Consumer<HistoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading history...');
          }

          if (provider.hasError) {
            return CustomErrorWidget(
              message: provider.errorMessage ?? 'Failed to load history',
              onRetry: provider.loadHistory,
            );
          }

          if (provider.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Conversions Yet',
              subtitle: 'Start converting currencies to see your history here',
              icon: Icons.history,
            );
          }

          return Column(
            children: [
              _buildFilterSection(context, provider),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(UIConstants.mainPadding),
                  itemCount: provider.conversions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conversion = provider.conversions[index];
                    return Dismissible(
                      key: Key(conversion.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: UIConstants.errorColor,
                          borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) => _showDeleteConfirmation(context),
                      onDismissed: (direction) {
                        _handleDismiss(context, conversion, index);
                      },
                      child: Card(
                        color: UIConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                        ),
                        child: ListTile(
                          onTap: () => _repeatConversion(context, conversion),
                          title: Text(
                            conversion.conversionPair,
                            style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${conversion.formattedFromAmount} → ${conversion.formattedToAmount}',
                                style: UIConstants.bodyStyle,
                              ),
                              Text(
                                conversion.formattedTimestamp,
                                style: UIConstants.bodyStyle.copyWith(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.replay),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, HistoryProvider provider) {
    final availableCurrencies = provider.getAvailableCurrencies();

    if (availableCurrencies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(UIConstants.mainPadding),
      color: UIConstants.primaryColor,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: provider.currencyFilter,
              decoration: const InputDecoration(
                labelText: 'Filter by Currency',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Currencies')),
                ...availableCurrencies.map(
                  (currency) => DropdownMenuItem(value: currency, child: Text(currency)),
                ),
              ],
              onChanged: provider.setCurrencyFilter,
            ),
          ),
          if (provider.currencyFilter != null) ...[
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.clear), onPressed: provider.clearFilter),
          ],
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Conversion'),
            content: const Text('Are you sure you want to delete this conversion?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _handleDismiss(BuildContext context, conversion, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Conversion deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            context.read<HistoryProvider>().loadHistory();
          },
        ),
      ),
    );
  }

  void _repeatConversion(BuildContext context, conversion) {
    final converterProvider = context.read<ConverterProvider>();
    converterProvider.setFromCurrency(conversion.fromCurrency);
    converterProvider.setToCurrency(conversion.toCurrency);
    converterProvider.setFromAmount(conversion.fromAmount);

    GoRouter.of(context).go('/converter');
  }

  void _exportToCsv(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('History exported to CSV successfully')));
  }
}

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('My Portfolio', style: UIConstants.headingStyle),
        backgroundColor: UIConstants.primaryColor,
        elevation: 0,
        actions: [
          Consumer<PortfolioProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddTokenModal(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading portfolio...');
          }

          if (provider.hasError) {
            return CustomErrorWidget(
              message: provider.errorMessage ?? 'Failed to load portfolio',
              onRetry: provider.loadPortfolio,
            );
          }

          return Column(
            children: [
              _buildTotalValueCard(provider),

              Expanded(
                child:
                    provider.isEmpty
                        ? EmptyStateWidget(
                          title: 'No Tokens in Portfolio',
                          subtitle: 'Add tokens to track their value and performance',
                          icon: Icons.account_balance_wallet,
                          action: CustomButton(
                            text: 'Add Token',
                            onPressed: () => _showAddTokenModal(context),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(UIConstants.mainPadding),
                          itemCount: provider.portfolioItems.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = provider.portfolioItems[index];
                            return Dismissible(
                              key: Key(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: UIConstants.errorColor,
                                  borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss:
                                  (direction) =>
                                      _showDeleteConfirmation(context, item.cryptocurrency.name),
                              onDismissed: (direction) {
                                _handleDismiss(context, provider, item);
                              },
                              child: Card(
                                color: UIConstants.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(UIConstants.cardRadius),
                                ),
                                child: ListTile(
                                  onTap: () => _showEditDialog(context, provider, item),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.cryptocurrency.symbol,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.cryptocurrency.name,
                                    style: UIConstants.bodyStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.amount} ${item.cryptocurrency.code}',
                                        style: UIConstants.bodyStyle,
                                      ),
                                      Text(
                                        'Added: ${_formatDate(item.dateAdded)}',
                                        style: UIConstants.bodyStyle.copyWith(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.cryptocurrency.formatAmount(item.currentValue),
                                        style: UIConstants.bodyStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              item.priceChangePercentage >= 0
                                                  ? UIConstants.successColor.withOpacity(0.2)
                                                  : UIConstants.errorColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${item.priceChangePercentage >= 0 ? '+' : ''}${item.priceChangePercentage.toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                item.priceChangePercentage >= 0
                                                    ? UIConstants.successColor
                                                    : UIConstants.errorColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalValueCard(PortfolioProvider provider) {
    return Container(
      margin: const EdgeInsets.all(UIConstants.mainPadding),
      child: Card(
        color: UIConstants.secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.cardRadius)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(UIConstants.cardPadding * 1.5),
              child: Column(
                children: [
                  Text(
                    'Total Portfolio Value',
                    style: UIConstants.bodyStyle.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${provider.totalValue.toStringAsFixed(2)}',
                    style: UIConstants.headingStyle.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'in ${provider.baseCurrency}',
                    style: UIConstants.bodyStyle.copyWith(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String tokenName) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Token'),
            content: Text('Are you sure you want to remove $tokenName from your portfolio?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  void _handleDismiss(BuildContext context, PortfolioProvider provider, item) {
    provider.deletePortfolioItem(item.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.cryptocurrency.name} removed from portfolio'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.addPortfolioItem(
              cryptocurrency: item.cryptocurrency,
              amount: item.amount,
              dateAdded: item.dateAdded,
            );
          },
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PortfolioProvider provider, item) {
    final amountController = TextEditingController(text: item.amount.toString());

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit ${item.cryptocurrency.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixText: item.cryptocurrency.code,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  final newAmount = double.tryParse(amountController.text);
                  if (newAmount != null && newAmount > 0) {
                    provider.updatePortfolioItem(id: item.id, amount: newAmount);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showAddTokenModal(BuildContext context) {
    context.push(
      AppRoutes.addToken,
      extra: {
        'onTokenAdded': () {
          context.read<PortfolioProvider>().loadPortfolio();
        },
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}

// ==================== MODALS ====================

class CurrencySelectionModal extends StatelessWidget {
  final CurrencyType currencyType;
  final Function(Currency)? onCurrencySelected;

  const CurrencySelectionModal({super.key, required this.currencyType, this.onCurrencySelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: UIConstants.primaryColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(UIConstants.modalRadius)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(UIConstants.cardPadding),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Currency', style: UIConstants.headingStyle),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
                  ],
                ),
              ),

              Expanded(
                child: Consumer<ConverterProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.availableCurrencies.isEmpty) {
                      return const LoadingWidget(message: 'Loading currencies...');
                    }

                    if (provider.hasError && provider.availableCurrencies.isEmpty) {
                      return CustomErrorWidget(
                        message: provider.errorMessage ?? 'Failed to load currencies',
                        onRetry: () => provider.loadCurrencyRates(forceRefresh: true),
                      );
                    }

                    final filteredCurrencies = _filterCurrencies(provider.availableCurrencies);

                    return Column(
                      children: [
                        if (currencyType == CurrencyType.cryptocurrency ||
                            currencyType == CurrencyType.cryptocurrency)
                          _buildCurrencySection(
                            'Cryptocurrencies',
                            filteredCurrencies.where((c) => c is Cryptocurrency).toList(),
                          ),

                        if (currencyType == CurrencyType.fiat ||
                            currencyType == CurrencyType.cryptocurrency)
                          _buildCurrencySection(
                            'Fiat Currencies',
                            filteredCurrencies.where((c) => c is FiatCurrency).toList(),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Currency> _filterCurrencies(List<Currency> currencies) {
    switch (currencyType) {
      case CurrencyType.cryptocurrency:
        return currencies.where((c) => c is Cryptocurrency).toList();
      case CurrencyType.fiat:
        return currencies.where((c) => c is FiatCurrency).toList();
    }
  }

  Widget _buildCurrencySection(String title, List<Currency> currencies) {
    if (currencies.isEmpty) return const SizedBox.shrink();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(UIConstants.cardPadding),
            child: Text(
              title,
              style: UIConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final currency = currencies[index];
                return ListTile(
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        currency.symbol,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  title: Text(
                    currency.name,
                    style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    currency.code,
                    style: UIConstants.bodyStyle.copyWith(color: Colors.grey[600]),
                  ),
                  trailing:
                      currency is Cryptocurrency
                          ? Text(
                            '\$${currency.currentPrice.toStringAsFixed(currency.currentPrice < 1 ? 4 : 2)}',
                            style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w500),
                          )
                          : null,
                  onTap: () {
                    onCurrencySelected?.call(currency);
                    context.pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AddTokenModal extends StatefulWidget {
  final VoidCallback? onTokenAdded;

  const AddTokenModal({super.key, this.onTokenAdded});

  @override
  State<AddTokenModal> createState() => _AddTokenModalState();
}

class _AddTokenModalState extends State<AddTokenModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  Cryptocurrency? _selectedCryptocurrency;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: UIConstants.primaryColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(UIConstants.modalRadius)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(UIConstants.cardPadding),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add Token', style: UIConstants.headingStyle),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
                  ],
                ),
              ),
        
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(UIConstants.mainPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCryptocurrencySelector(),
        
                        const SizedBox(height: UIConstants.mainPadding),
        
                        CustomTextField(
                          label: 'Amount',
                          hint: '0.0000',
                          value: _amountController.text,
                          onChanged: (value) => _amountController.text = value,
                          validator: InputValidators.validateAmount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          isNumeric: true,
                        ),
        
                        const SizedBox(height: UIConstants.mainPadding),
        
                        _buildDateSelector(),
        
                        const Spacer(),
        
                        CustomButton(
                          text: 'Add Token',
                          onPressed: _selectedCryptocurrency != null ? _addToken : null,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCryptocurrencySelector() {
    return Consumer<ConverterProvider>(
      builder: (context, provider, child) {
        final cryptocurrencies = provider.availableCurrencies.whereType<Cryptocurrency>().toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cryptocurrency',
              style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
              ),
              child: DropdownButtonFormField<Cryptocurrency>(
                value: _selectedCryptocurrency,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  border: InputBorder.none,
                ),
                hint: const Text('Select cryptocurrency'),
                items:
                    cryptocurrencies
                        .map(
                          (crypto) => DropdownMenuItem(
                            value: crypto,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Center(
                                    child: Text(
                                      crypto.symbol,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${crypto.name} (${crypto.code})'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (crypto) {
                  setState(() {
                    _selectedCryptocurrency = crypto;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a cryptocurrency';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Added', style: UIConstants.bodyStyle.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        CustomTextField(
          value: '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
          readOnly: true,
          onTap: _selectDate,
          suffix: const Icon(Icons.calendar_today),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _addToken() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      await context.read<PortfolioProvider>().addPortfolioItem(
        cryptocurrency: _selectedCryptocurrency!,
        amount: amount,
        dateAdded: _selectedDate,
      );

      widget.onTokenAdded?.call();

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedCryptocurrency!.name} added to portfolio')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add token: ${e.toString()}'),
            backgroundColor: UIConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}


class CryptoCalcApp extends StatelessWidget {
  const CryptoCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderSetup.wrapWithProviders(
      MaterialApp.router(
        title: 'CryptoCalc',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: UIConstants.secondaryColor,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: UIConstants.backgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: UIConstants.primaryColor,
            foregroundColor: UIConstants.secondaryColor,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
          cardTheme: CardThemeData(
            color: UIConstants.primaryColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UIConstants.cardRadius),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.secondaryColor,
              foregroundColor: UIConstants.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.buttonRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
