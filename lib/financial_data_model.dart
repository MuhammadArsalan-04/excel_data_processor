import 'package:flutter/foundation.dart';

// ==================== DATA MODELS ====================
class FinancialDataEntry {
  final String company;
  final String year;
  final Map<String, String> data; // Key: column name, Value: data value

  FinancialDataEntry({
    required this.company,
    required this.year,
    required this.data,
  });

  // Convert to CSV row
  List<String> toCsvRow(List<String> columnOrder) {
    List<String> row = [company, year];
    for (String column in columnOrder) {
      row.add(data[column] ?? '');
    }
    return row;
  }

  // Convert to map for easy manipulation
  Map<String, dynamic> toMap() {
    return {'company': company, 'year': year, ...data};
  }
}

// ==================== PROVIDER ====================

class FinancialDataProvider extends ChangeNotifier {
  final List<FinancialDataEntry> _storedData = [];

  List<FinancialDataEntry> get storedData => List.unmodifiable(_storedData);

  // Column definitions for the financial data
  // These must match the keys in FinancialDataExtractor.columnMappings
  static const List<String> requiredColumns = [
    'Non Current Assets (A)',
    'Operating Fixed Assets After Depreciation (A3)',
    'Current Assets (B)',
    'Total Assets (A+B)',
    'D. Non-Current Liabilities (D1+D2+D3+D4+D5)',
    'E. Current Liabilities (E1+E2+E3+E4)',
    'Total Liabilities (D+E)',
    // 'Gross Profit (F3)',
    // 'Administrative Expenses (F4)',
    'Other Income (F5)',
    'EBIT (F6)',
    'Financial Expenses (F7)',
    'Interest Expense (F7(i))',
    'Profit / (loss) before taxation (F6-F7)',
    'Tax Expense (F8)',
    'Tax Expense - Current (F8(i))',
    // 'Tax Expense (F9)',
    'Profit After Tax (F10)',
    'Sales (F1)',
    'Cash & Bank Balance (B1)',
    'Short-Term Investments (B5)',
    'Long-Term Investments (A5)',
  ];

  // Add single entry
  void addEntry(FinancialDataEntry entry) {
    _storedData.add(entry);
    notifyListeners();
  }

  // Add multiple entries
  void addMultipleEntries(List<FinancialDataEntry> entries) {
    _storedData.addAll(entries);
    notifyListeners();
  }

  // Remove entry
  void removeEntry(int index) {
    if (index >= 0 && index < _storedData.length) {
      _storedData.removeAt(index);
      notifyListeners();
    }
  }

  // Clear all data
  void clearAll() {
    _storedData.clear();
    notifyListeners();
  }

  // Get all companies
  List<String> getAllCompanies() {
    return _storedData.map((e) => e.company).toSet().toList()..sort();
  }

  // Get all years
  List<String> getAllYears() {
    return _storedData.map((e) => e.year).toSet().toList()..sort();
  }

  // Get data for specific company
  List<FinancialDataEntry> getDataForCompany(String company) {
    return _storedData.where((e) => e.company == company).toList();
  }

  // Get data for specific year
  List<FinancialDataEntry> getDataForYear(String year) {
    return _storedData.where((e) => e.year == year).toList();
  }

  // Check if data exists for company-year combination
  bool hasData(String company, String year) {
    return _storedData.any((e) => e.company == company && e.year == year);
  }

  // Get total number of entries
  int get totalEntries => _storedData.length;
}

// import 'package:flutter/foundation.dart';

// // ==================== DATA MODELS ====================
// class FinancialDataEntry {
//   final String company;
//   final String year;
//   final Map<String, String> data; // Key: column name, Value: data value

//   FinancialDataEntry({
//     required this.company,
//     required this.year,
//     required this.data,
//   });

//   // Convert to CSV row
//   List<String> toCsvRow(List<String> columnOrder) {
//     List<String> row = [company, year];
//     for (String column in columnOrder) {
//       row.add(data[column] ?? '');
//     }
//     return row;
//   }

//   // Convert to map for easy manipulation
//   Map<String, dynamic> toMap() {
//     return {'company': company, 'year': year, ...data};
//   }
// }

// // ==================== PROVIDER ====================

// class FinancialDataProvider extends ChangeNotifier {
//   final List<FinancialDataEntry> _storedData = [];

//   List<FinancialDataEntry> get storedData => List.unmodifiable(_storedData);

//   // Column definitions for the financial data
//   static const List<String> requiredColumns = [
//     'Non Current Assets (A)',
//     'Current Assets (B)',
//     'Total Assets (A+B)',
//     'Profit After Tax (F10)',
//     'D. Non-Current Liabilities (D1+D2+D3+D4+D5)',
//     'E. Current Liabilities (E1+E2+E3+E4)',
//     'Total Liabilities (D+E)',
//     'Interest Expense (F7(i))',
//     'EBIT (F6)',
//     'Other Income (F5)',
//     'Sales (F1)',
//     'Cash & Bank Balance (B1)',
//     'Short-Term Investments (B5)',
//     'Long-Term Investments (A5)',
//     'Non-Current Assets (Total)',
//     'Current Assets (Total)',
//   ];

//   // Add single entry
//   void addEntry(FinancialDataEntry entry) {
//     _storedData.add(entry);
//     notifyListeners();
//   }

//   // Add multiple entries
//   void addMultipleEntries(List<FinancialDataEntry> entries) {
//     _storedData.addAll(entries);
//     notifyListeners();
//   }

//   // Remove entry
//   void removeEntry(int index) {
//     if (index >= 0 && index < _storedData.length) {
//       _storedData.removeAt(index);
//       notifyListeners();
//     }
//   }

//   // Clear all data
//   void clearAll() {
//     _storedData.clear();
//     notifyListeners();
//   }

//   // Get all companies
//   List<String> getAllCompanies() {
//     return _storedData.map((e) => e.company).toSet().toList()..sort();
//   }

//   // Get all years
//   List<String> getAllYears() {
//     return _storedData.map((e) => e.year).toSet().toList()..sort();
//   }

//   // Get data for specific company
//   List<FinancialDataEntry> getDataForCompany(String company) {
//     return _storedData.where((e) => e.company == company).toList();
//   }

//   // Get data for specific year
//   List<FinancialDataEntry> getDataForYear(String year) {
//     return _storedData.where((e) => e.year == year).toList();
//   }

//   // Check if data exists for company-year combination
//   bool hasData(String company, String year) {
//     return _storedData.any((e) => e.company == company && e.year == year);
//   }

//   // Get total number of entries
//   int get totalEntries => _storedData.length;
// }
