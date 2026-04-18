import 'package:flutter/material.dart';

import 'financial_data_model.dart';

class FinancialDataExtractor {
  // Mapping of required columns to their item name patterns in the data
  static const Map<String, List<String>> columnMappings = {
    'Non Current Assets (A)': [
      'A. Non-Current Assets',
      'Non-Current Assets (A',
      'Non Current Assets (A)',
    ],
    'Current Assets (B)': ['B. Current Assets', 'Current Assets (B'],
    'Total Assets (A+B)': ['Total Assets (A+B)', 'Total Assets'],
    'D. Non-Current Liabilities (D1+D2+D3+D4+D5)': [
      'D. Non-Current Liabilities',
      'Non-Current Liabilities (D',
    ],
    'E. Current Liabilities (E1+E2+E3+E4)': [
      'E. Current Liabilities',
      'Current Liabilities (E',
    ],
    'Total Liabilities (D+E)': ['Total Liabilities', 'Total Liabilities (D+E)'],
    'Gross Profit (F3)': [
      '3. Gross profit / (loss)',
      '3. Gross profit',
      'Gross profit / (loss)',
      'Gross profit',
      'F3. Gross profit',
      'F3',
    ],
    'Administrative Expenses (F4)': [
      '4. General, administrative and other expenses',
      '4. Administrative expenses',
      'General, administrative and other expenses',
      'Administrative expenses',
      'F4. Administrative expenses',
      'F4',
    ],
    'Other Income (F5)': [
      '5. Other income / (loss)',
      '5. Other income',
      'Other income / (loss)',
      'Other income',
      'F5. Other income',
      'F5',
    ],
    'EBIT (F6)': [
      '6. EBIT',
      'EBIT',
      'F6. EBIT',
      '6. Earnings before interest and tax',
    ],
    'Financial Expenses (F7)': [
      '6. Financial expenses',
      'Financial expenses',
      'F6. Financial expenses',
      'F7. Financial expenses',
      '7. Financial expenses',
      '7. Financial expense',
      'Financial expense',
    ],
    'Interest Expense (F7(i))': [
      '(i) Interest expenses',
      'Interest expenses',
      'of which: (i) Interest expenses',
      '(i) Interest expense',
      'Interest expense',
    ],
      'Profit / (loss) before taxation (F7)': [
      '8. Profit / (loss) before taxation',
      '7. Profit / (loss) before taxation',
      'Profit / (loss) before taxation',
      'F7. Profit / (loss) before taxation',
      'Profit before taxation',
      'F7. Profit',
      'F7',
    ],
    'Tax Expense (F8)': [
      '9. Tax expenses',
      '9. Tax expense',
      '8. Tax expenses',
      '8. Tax expense',
      'F9. Tax expenses',
      'F9. Tax expense',
      'F8. Tax',
      'F8. Tax expenses',
    ],
    'Tax Expense - Current (F8(i))': [
      '(i) Current',
      '8(i) Current',
      'i) Current',
      'Current tax',
      'F8(i)',
    ],
    'Profit After Tax (F10)': [
      '10. Profit / (loss) after tax',
      '10. Profit after tax',
      'Profit / (loss) after tax',
      'Profit after tax',
      'F10. Profit after tax',
      'F10',
    ],
    'Sales (F1)': ['1. Sales', 'Sales', 'F1. Sales'],
    'Cash & Bank Balance (B1)': [
      '1. Cash & bank balance',
      'Cash & bank balance',
      'B1. Cash',
    ],
    'Short-Term Investments (B5)': [
      '4. Short term investments',
      'Short term investments',
      'B5. Short term investments',
    ],
    'Long-Term Investments (A5)': [
      '5. Long term investments',
      'Long term investments',
      'A5. Long term investments',
    ],
  };

  /// Extract financial data from filtered dataset
  ///
  /// Parameters:
  /// - filteredData: List of filtered row data
  /// - organizationColumnName: Name of the organization/company column
  /// - itemNameColumn: Name of the column containing item names (like "A. Non-Current Assets")
  /// - yearColumns: List of year column names to extract data from
  /// - sectorColumnName: Optional sector column name
  static List<FinancialDataEntry> extractFinancialData({
    required List<Map<String, dynamic>> filteredData,
    required String organizationColumnName,
    required String itemNameColumn,
    required List<String> yearColumns,
    String? sectorColumnName,
  }) {
    List<FinancialDataEntry> entries = [];

    // Group data by company
    Map<String, List<Map<String, dynamic>>> groupedByCompany = {};
    for (var row in filteredData) {
      String company = row[organizationColumnName]?.toString().trim() ?? '';
      if (company.isNotEmpty) {
        if (!groupedByCompany.containsKey(company)) {
          groupedByCompany[company] = [];
        }
        groupedByCompany[company]!.add(row);
      }
    }

    // Process each company
    for (var companyEntry in groupedByCompany.entries) {
      String company = companyEntry.key;
      List<Map<String, dynamic>> companyRows = companyEntry.value;

      // Process each year
      for (String yearColumn in yearColumns) {
        Map<String, String> yearData = {};

        // Extract data for each required column
        for (var columnEntry in columnMappings.entries) {
          String targetColumn = columnEntry.key;
          List<String> patterns = columnEntry.value;

          // Find matching row
          for (var row in companyRows) {
            String itemName = row[itemNameColumn]?.toString().trim() ?? '';

            // Check if this row matches any of the patterns (OR condition)
            bool matches = patterns.any(
              (pattern) =>
                  itemName.toLowerCase().contains(pattern.toLowerCase()),
            );

            if (matches) {
              String value = row[yearColumn]?.toString().trim() ?? '';
              if (value.isNotEmpty) {
                // Clean the value (remove commas, spaces, etc.)
                value = value.replaceAll(',', '').trim();
                yearData[targetColumn] = value;
              }
              break;
            }
          }
        }

        // === CALCULATIONS ===

        // 1. Calculate Total Assets if not found but components are available
        if (!yearData.containsKey('Total Assets (A+B)')) {
          String? nonCurrent = yearData['Non Current Assets (A)'];
          String? current = yearData['Current Assets (B)'];

          if (nonCurrent != null && current != null) {
            try {
              double total =
                  (double.tryParse(nonCurrent) ?? 0) +
                  (double.tryParse(current) ?? 0);
              yearData['Total Assets (A+B)'] = total.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 2. Calculate Total Liabilities (D+E)
        if (!yearData.containsKey('Total Liabilities (D+E)')) {
          String? nonCurrentLiabilities =
              yearData['D. Non-Current Liabilities (D1+D2+D3+D4+D5)'];
          String? currentLiabilities =
              yearData['E. Current Liabilities (E1+E2+E3+E4)'];

          if (nonCurrentLiabilities != null && currentLiabilities != null) {
            try {
              double total =
                  (double.tryParse(nonCurrentLiabilities) ?? 0) +
                  (double.tryParse(currentLiabilities) ?? 0);
              yearData['Total Liabilities (D+E)'] = total.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 3. Calculate EBIT (F3 - F4 + F5) - ONLY if not already present
        if (!yearData.containsKey('EBIT (F6)')) {
          String? grossProfit = yearData['Gross Profit (F3)'];
          String? adminExpenses = yearData['Administrative Expenses (F4)'];
          String? otherIncome = yearData['Other Income (F5)'];

          if (grossProfit != null &&
              adminExpenses != null &&
              otherIncome != null) {
            try {
              double ebit =
                  (double.tryParse(grossProfit) ?? 0) -
                  (double.tryParse(adminExpenses) ?? 0) +
                  (double.tryParse(otherIncome) ?? 0);
              yearData['EBIT (F6)'] = ebit.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 4. Calculate Profit / (loss) before taxation (F6-F7) - ONLY if not already present
        if (!yearData.containsKey('Profit / (loss) before taxation (F6-F7)')) {
          String? ebit = yearData['EBIT (F6)'];
          String? financialExpenses = yearData['Financial Expenses (F7)'];

          if (ebit != null && financialExpenses != null) {
            try {
              double pbtValue =
                  (double.tryParse(ebit) ?? 0) -
                  (double.tryParse(financialExpenses) ?? 0);
              yearData['Profit / (loss) before taxation (F6-F7)'] = pbtValue.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 5. Calculate Profit After Tax
        // Formula: Profit After Tax = Profit / (loss) before taxation (F7) - Tax Expense (F8)
        // Priority: F8 primary, F8(i) fallback
        if (!yearData.containsKey('Profit After Tax (F10)')) {
          String? profitBeforeTaxF7 = yearData['Profit / (loss) before taxation (F7)'];
          String? taxExpenseF8 = yearData['Tax Expense (F8)'];

          // If Tax Expense (F8) is not available, use Tax Expense - Current (F8(i)) as fallback
          if (taxExpenseF8 == null) {
            taxExpenseF8 = yearData['Tax Expense - Current (F8(i))'];
          }

          if (profitBeforeTaxF7 != null && taxExpenseF8 != null) {
            try {
              double f7Value = double.tryParse(profitBeforeTaxF7) ?? 0;
              double taxValue = double.tryParse(taxExpenseF8) ?? 0;

              debugPrint('Calculating Profit After Tax for $company in $yearColumn: F7 = $f7Value, Tax Expense = $taxValue');
              double profitAfterTax = f7Value - taxValue;
              yearData['Profit After Tax (F10)'] = profitAfterTax.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // Only add entry if we have at least some data
        if (yearData.isNotEmpty) {
          entries.add(
            FinancialDataEntry(
              company: company,
              year: yearColumn,
              data: yearData,
            ),
          );
        }
      }
    }

    return entries;
  }

  /// Automatically detect year columns from the data
  static List<String> detectYearColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];

    List<String> yearColumns = [];
    var firstRow = data[0];

    // Look for columns that look like years (4 digits)
    RegExp yearPattern = RegExp(r'^\d{4}$');

    for (String column in firstRow.keys) {
      if (yearPattern.hasMatch(column.trim())) {
        yearColumns.add(column);
      }
    }

    // Sort years
    yearColumns.sort();
    return yearColumns;
  }

  /// Detect the item name column
  static String? detectItemNameColumn(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return null;

    var firstRow = data[0];

    // Look for columns that might contain item names
    List<String> possibleNames = [
      'item',
      'item name',
      'description',
      'particulars',
      'line item',
    ];

    for (String column in firstRow.keys) {
      String lowerColumn = column.toLowerCase();
      if (possibleNames.any((name) => lowerColumn.contains(name))) {
        return column;
      }
    }

    return null;
  }
}








// // ==================== DATA EXTRACTION SERVICE ====================
// import 'financial_data_model.dart';

// class FinancialDataExtractor {
//   // Mapping of required columns to their item name patterns in the data
//   static const Map<String, List<String>> columnMappings = {
//     'Non Current Assets (A)': [
//       'A. Non-Current Assets',
//       'Non-Current Assets (A',
//       'Non Current Assets (A)',
//     ],
//     'Current Assets (B)': ['B. Current Assets', 'Current Assets (B'],
//     'Total Assets (A+B)': ['Total Assets (A+B)', 'Total Assets'],
//     'D. Non-Current Liabilities (D1+D2+D3+D4+D5)': [
//       'D. Non-Current Liabilities',
//       'Non-Current Liabilities (D',
//     ],
//     'E. Current Liabilities (E1+E2+E3+E4)': [
//       'E. Current Liabilities',
//       'Current Liabilities (E',
//     ],
//     'Total Liabilities (D+E)': ['Total Liabilities', 'Total Liabilities (D+E)'],
//     'Gross Profit (F3)': [
//       '3. Gross profit',
//       'Gross profit',
//       'F3. Gross profit',
//     ],
//     'Administrative Expenses (F4)': [
//       '4. Administrative expenses',
//       'Administrative expenses',
//       'F4. Administrative expenses',
//     ],
//     'Other Income (F5)': [
//       '5. Other income',
//       'Other income',
//       'F5. Other income',
//     ],
//     'EBIT (F6)': [
//       '6. EBIT',
//       'EBIT',
//       'F6. EBIT',
//       '6. Earnings before interest and tax',
//     ],
//     'Financial Expenses (F7)': [
//       '7. Financial expenses',
//       'Financial expenses',
//       'F7. Financial expenses',
//       '7. Financial expense',
//       'Financial expense',
//     ],
//     'Interest Expense (F7(i))': [
//       '(i) Interest expenses',
//       'Interest expenses',
//       'of which: (i) Interest expenses',
//       '(i) Interest expense',
//       'Interest expense',
//     ],
//     'Tax Expense (F9)': [
//       '9. Tax expenses',
//       'Tax expenses',
//       'F9. Tax expenses',
//       '9. Tax expense',
//       'Tax expense',
//       'F9. Tax expense',
//     ],
//     'Profit After Tax (F10)': [
//       '10. Profit after tax',
//       'Profit after tax',
//       'F10. Profit after tax',
//     ],
//     'Sales (F1)': ['1. Sales', 'Sales', 'F1. Sales'],
//     'Cash & Bank Balance (B1)': [
//       '1. Cash & bank balance',
//       'Cash & bank balance',
//       'B1. Cash',
//     ],
//     'Short-Term Investments (B5)': [
//       '4. Short term investments',
//       'Short term investments',
//       'B5. Short term investments',
//     ],
//     'Long-Term Investments (A5)': [
//       '5. Long term investments',
//       'Long term investments',
//       'A5. Long term investments',
//     ],
//   };

//   /// Extract financial data from filtered dataset
//   ///
//   /// Parameters:
//   /// - filteredData: List of filtered row data
//   /// - organizationColumnName: Name of the organization/company column
//   /// - itemNameColumn: Name of the column containing item names (like "A. Non-Current Assets")
//   /// - yearColumns: List of year column names to extract data from
//   /// - sectorColumnName: Optional sector column name
//   static List<FinancialDataEntry> extractFinancialData({
//     required List<Map<String, dynamic>> filteredData,
//     required String organizationColumnName,
//     required String itemNameColumn,
//     required List<String> yearColumns,
//     String? sectorColumnName,
//   }) {
//     List<FinancialDataEntry> entries = [];

//     // Group data by company
//     Map<String, List<Map<String, dynamic>>> groupedByCompany = {};
//     for (var row in filteredData) {
//       String company = row[organizationColumnName]?.toString().trim() ?? '';
//       if (company.isNotEmpty) {
//         if (!groupedByCompany.containsKey(company)) {
//           groupedByCompany[company] = [];
//         }
//         groupedByCompany[company]!.add(row);
//       }
//     }

//     // Process each company
//     for (var companyEntry in groupedByCompany.entries) {
//       String company = companyEntry.key;
//       List<Map<String, dynamic>> companyRows = companyEntry.value;

//       // Process each year
//       for (String yearColumn in yearColumns) {
//         Map<String, String> yearData = {};

//         // Extract data for each required column
//         for (var columnEntry in columnMappings.entries) {
//           String targetColumn = columnEntry.key;
//           List<String> patterns = columnEntry.value;

//           // Find matching row
//           for (var row in companyRows) {
//             String itemName = row[itemNameColumn]?.toString().trim() ?? '';

//             // Check if this row matches any of the patterns
//             bool matches = patterns.any(
//               (pattern) =>
//                   itemName.toLowerCase().contains(pattern.toLowerCase()),
//             );

//             if (matches) {
//               String value = row[yearColumn]?.toString().trim() ?? '';
//               if (value.isNotEmpty) {
//                 // Clean the value (remove commas, spaces, etc.)
//                 value = value.replaceAll(',', '').trim();
//                 yearData[targetColumn] = value;
//               }
//               break;
//             }
//           }
//         }

//         // === CALCULATIONS ===

//         // 1. Calculate Total Assets if not found but components are available
//         if (!yearData.containsKey('Total Assets (A+B)')) {
//           String? nonCurrent = yearData['Non Current Assets (A)'];
//           String? current = yearData['Current Assets (B)'];

//           if (nonCurrent != null && current != null) {
//             try {
//               double total =
//                   (double.tryParse(nonCurrent) ?? 0) +
//                   (double.tryParse(current) ?? 0);
//               yearData['Total Assets (A+B)'] = total.toStringAsFixed(0);
//             } catch (e) {
//               // If calculation fails, leave it empty
//             }
//           }
//         }

//         // 2. Calculate Total Liabilities (D+E)
//         if (!yearData.containsKey('Total Liabilities (D+E)')) {
//           String? nonCurrentLiabilities =
//               yearData['D. Non-Current Liabilities (D1+D2+D3+D4+D5)'];
//           String? currentLiabilities =
//               yearData['E. Current Liabilities (E1+E2+E3+E4)'];

//           if (nonCurrentLiabilities != null && currentLiabilities != null) {
//             try {
//               double total =
//                   (double.tryParse(nonCurrentLiabilities) ?? 0) +
//                   (double.tryParse(currentLiabilities) ?? 0);
//               yearData['Total Liabilities (D+E)'] = total.toStringAsFixed(0);
//             } catch (e) {
//               // If calculation fails, leave it empty
//             }
//           }
//         }

//         // 3. Calculate EBIT (F3 + F4 + F5) - ALWAYS override any existing value
//         // EBIT = Gross Profit (F3) + Administrative Expenses (F4) + Other Income (F5)
//         String? grossProfit = yearData['Gross Profit (F3)'];
//         String? adminExpenses = yearData['Administrative Expenses (F4)'];
//         String? otherIncome = yearData['Other Income (F5)'];

//         if (grossProfit != null &&
//             adminExpenses != null &&
//             otherIncome != null) {
//           try {
//             double ebit =
//                 (double.tryParse(grossProfit) ?? 0) +
//                 (double.tryParse(adminExpenses) ?? 0) +
//                 (double.tryParse(otherIncome) ?? 0);
//             yearData['EBIT (F6)'] = ebit.toStringAsFixed(0);
//           } catch (e) {
//             // If calculation fails, leave it empty
//           }
//         }

//         // 4. Calculate Profit After Tax = ((F3 + F4 + F5) - F7) - F9
//         // This is: (EBIT - Financial Expenses) - Tax Expense
//         String? financialExpenses = yearData['Financial Expenses (F7)'];
//         String? taxExpense = yearData['Tax Expense (F9)'];

//         if (grossProfit != null &&
//             adminExpenses != null &&
//             otherIncome != null &&
//             financialExpenses != null &&
//             taxExpense != null) {
//           try {
//             // Calculate EBIT first
//             double ebitValue =
//                 (double.tryParse(grossProfit) ?? 0) +
//                 (double.tryParse(adminExpenses) ?? 0) +
//                 (double.tryParse(otherIncome) ?? 0);

//             // Calculate Profit After Tax: (EBIT - F7) - F9
//             double profitAfterTax =
//                 (ebitValue - (double.tryParse(financialExpenses) ?? 0)) -
//                 (double.tryParse(taxExpense) ?? 0);

//             yearData['Profit After Tax (F10)'] = profitAfterTax.toStringAsFixed(
//               0,
//             );
//           } catch (e) {
//             // If calculation fails, leave it empty
//           }
//         }

//         // Only add entry if we have at least some data
//         if (yearData.isNotEmpty) {
//           entries.add(
//             FinancialDataEntry(
//               company: company,
//               year: yearColumn,
//               data: yearData,
//             ),
//           );
//         }
//       }
//     }

//     return entries;
//   }

//   /// Automatically detect year columns from the data
//   static List<String> detectYearColumns(List<Map<String, dynamic>> data) {
//     if (data.isEmpty) return [];

//     List<String> yearColumns = [];
//     var firstRow = data[0];

//     // Look for columns that look like years (4 digits)
//     RegExp yearPattern = RegExp(r'^\d{4}$');

//     for (String column in firstRow.keys) {
//       if (yearPattern.hasMatch(column.trim())) {
//         yearColumns.add(column);
//       }
//     }

//     // Sort years
//     yearColumns.sort();
//     return yearColumns;
//   }

//   /// Detect the item name column
//   static String? detectItemNameColumn(List<Map<String, dynamic>> data) {
//     if (data.isEmpty) return null;

//     var firstRow = data[0];

//     // Look for columns that might contain item names
//     List<String> possibleNames = [
//       'item',
//       'item name',
//       'description',
//       'particulars',
//       'line item',
//     ];

//     for (String column in firstRow.keys) {
//       String lowerColumn = column.toLowerCase();
//       if (possibleNames.any((name) => lowerColumn.contains(name))) {
//         return column;
//       }
//     }

//     return null;
//   }
// }












/*








import 'financial_data_model.dart';

class FinancialDataExtractor {
  // Mapping of required columns to their item name patterns in the data
  static const Map<String, List<String>> columnMappings = {
    'Non Current Assets (A)': [
      'A. Non-Current Assets',
      'Non-Current Assets (A',
      'Non Current Assets (A)',
    ],
    'Current Assets (B)': ['B. Current Assets', 'Current Assets (B'],
    'Total Assets (A+B)': ['Total Assets (A+B)', 'Total Assets'],
    'D. Non-Current Liabilities (D1+D2+D3+D4+D5)': [
      'D. Non-Current Liabilities',
      'Non-Current Liabilities (D',
    ],
    'E. Current Liabilities (E1+E2+E3+E4)': [
      'E. Current Liabilities',
      'Current Liabilities (E',
    ],
    'Total Liabilities (D+E)': ['Total Liabilities', 'Total Liabilities (D+E)'],
    'Gross Profit (F3)': [
      '3. Gross profit',
      'Gross profit',
      'F3. Gross profit',
    ],
    'Administrative Expenses (F4)': [
      '4. Administrative expenses',
      'Administrative expenses',
      'F4. Administrative expenses',
    ],
    'Other Income (F5)': [
      '5. Other income',
      'Other income',
      'F5. Other income',
    ],
    'EBIT (F6)': [
      '6. EBIT',
      'EBIT',
      'F6. EBIT',
      '6. Earnings before interest and tax',
    ],
    'Financial Expenses (F7)': [
      '7. Financial expenses',
      'Financial expenses',
      'F7. Financial expenses',
      '7. Financial expense',
      'Financial expense',
    ],
    'Interest Expense (F7(i))': [
      '(i) Interest expenses',
      'Interest expenses',
      'of which: (i) Interest expenses',
      '(i) Interest expense',
      'Interest expense',
    ],
    'Tax Expense (F9)': [
      '9. Tax expenses',
      'Tax expenses',
      'F9. Tax expenses',
      '9. Tax expense',
      'Tax expense',
      'F9. Tax expense',
    ],
    'Profit After Tax (F10)': [
      '10. Profit after tax',
      'Profit after tax',
      'F10. Profit after tax',
    ],
    'Sales (F1)': ['1. Sales', 'Sales', 'F1. Sales'],
    'Cash & Bank Balance (B1)': [
      '1. Cash & bank balance',
      'Cash & bank balance',
      'B1. Cash',
    ],
    'Short-Term Investments (B5)': [
      '4. Short term investments',
      'Short term investments',
      'B5. Short term investments',
    ],
    'Long-Term Investments (A5)': [
      '5. Long term investments',
      'Long term investments',
      'A5. Long term investments',
    ],
  };

  /// Extract financial data from filtered dataset
  ///
  /// Parameters:
  /// - filteredData: List of filtered row data
  /// - organizationColumnName: Name of the organization/company column
  /// - itemNameColumn: Name of the column containing item names (like "A. Non-Current Assets")
  /// - yearColumns: List of year column names to extract data from
  /// - sectorColumnName: Optional sector column name
  static List<FinancialDataEntry> extractFinancialData({
    required List<Map<String, dynamic>> filteredData,
    required String organizationColumnName,
    required String itemNameColumn,
    required List<String> yearColumns,
    String? sectorColumnName,
  }) {
    List<FinancialDataEntry> entries = [];

    // Group data by company
    Map<String, List<Map<String, dynamic>>> groupedByCompany = {};
    for (var row in filteredData) {
      String company = row[organizationColumnName]?.toString().trim() ?? '';
      if (company.isNotEmpty) {
        if (!groupedByCompany.containsKey(company)) {
          groupedByCompany[company] = [];
        }
        groupedByCompany[company]!.add(row);
      }
    }

    // Process each company
    for (var companyEntry in groupedByCompany.entries) {
      String company = companyEntry.key;
      List<Map<String, dynamic>> companyRows = companyEntry.value;

      // Process each year
      for (String yearColumn in yearColumns) {
        Map<String, String> yearData = {};

        // Extract data for each required column
        for (var columnEntry in columnMappings.entries) {
          String targetColumn = columnEntry.key;
          List<String> patterns = columnEntry.value;

          // Find matching row
          for (var row in companyRows) {
            String itemName = row[itemNameColumn]?.toString().trim() ?? '';

            // Check if this row matches any of the patterns
            bool matches = patterns.any(
              (pattern) =>
                  itemName.toLowerCase().contains(pattern.toLowerCase()),
            );

            if (matches) {
              String value = row[yearColumn]?.toString().trim() ?? '';
              if (value.isNotEmpty) {
                // Clean the value (remove commas, spaces, etc.)
                value = value.replaceAll(',', '').trim();
                yearData[targetColumn] = value;
              }
              break;
            }
          }
        }

        // === CALCULATIONS ===

        // 1. Calculate Total Assets if not found but components are available
        if (!yearData.containsKey('Total Assets (A+B)')) {
          String? nonCurrent = yearData['Non Current Assets (A)'];
          String? current = yearData['Current Assets (B)'];

          if (nonCurrent != null && current != null) {
            try {
              double total =
                  (double.tryParse(nonCurrent) ?? 0) +
                  (double.tryParse(current) ?? 0);
              yearData['Total Assets (A+B)'] = total.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 2. Calculate Total Liabilities (D+E)
        if (!yearData.containsKey('Total Liabilities (D+E)')) {
          String? nonCurrentLiabilities =
              yearData['D. Non-Current Liabilities (D1+D2+D3+D4+D5)'];
          String? currentLiabilities =
              yearData['E. Current Liabilities (E1+E2+E3+E4)'];

          if (nonCurrentLiabilities != null && currentLiabilities != null) {
            try {
              double total =
                  (double.tryParse(nonCurrentLiabilities) ?? 0) +
                  (double.tryParse(currentLiabilities) ?? 0);
              yearData['Total Liabilities (D+E)'] = total.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 3. Calculate EBIT (F3 - F4 + F5) - ONLY if not already present
        if (!yearData.containsKey('EBIT (F6)')) {
          String? grossProfit = yearData['Gross Profit (F3)'];
          String? adminExpenses = yearData['Administrative Expenses (F4)'];
          String? otherIncome = yearData['Other Income (F5)'];

          if (grossProfit != null &&
              adminExpenses != null &&
              otherIncome != null) {
            try {
              double ebit =
                  (double.tryParse(grossProfit) ?? 0) -
                  (double.tryParse(adminExpenses) ?? 0) +
                  (double.tryParse(otherIncome) ?? 0);
              yearData['EBIT (F6)'] = ebit.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 4. Calculate Profit / (loss) before taxation (F6-F7) - ONLY if not already present
        if (!yearData.containsKey('Profit / (loss) before taxation (F6-F7)')) {
          String? ebit = yearData['EBIT (F6)'];
          String? financialExpenses = yearData['Financial Expenses (F7)'];

          if (ebit != null && financialExpenses != null) {
            try {
              double pbtValue =
                  (double.tryParse(ebit) ?? 0) -
                  (double.tryParse(financialExpenses) ?? 0);
              yearData['Profit / (loss) before taxation (F6-F7)'] = pbtValue.toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, leave it empty
            }
          }
        }

        // 5. Calculate Profit After Tax = Profit / (loss) before taxation (F6-F7) - Tax Expense (F8)
        if (!yearData.containsKey('Profit After Tax (F10)')) {
          // Try CASE 1: Use calculated Profit Before Tax (F6-F7) and Tax Expense (F8)
          String? profitBeforeTax = yearData['Profit / (loss) before taxation (F6-F7)'];
          String? taxExpense = yearData['Tax Expense (F8)'];

          if (profitBeforeTax != null && taxExpense != null) {
            try {
              double pbtValue = double.tryParse(profitBeforeTax) ?? 0;
              double taxValue = double.tryParse(taxExpense) ?? 0;

              debugPrint('Calculating Profit After Tax for $company in $yearColumn (CASE 1): PBT = $pbtValue, Tax Expense = $taxValue');
              double profitAfterTax = pbtValue - taxValue;

              yearData['Profit After Tax (F10)'] = profitAfterTax
                  .toStringAsFixed(0);
            } catch (e) {
              // If calculation fails, try fallback
            }
          }

          // Try CASE 2: Use Tax Expense - Current (F8(i)) if F8 is not available
          if (!yearData.containsKey('Profit After Tax (F10)')) {
            String? profitBeforeTaxFallback = yearData['Profit / (loss) before taxation (F6-F7)'];
            String? currentTaxExpense = yearData['Tax Expense - Current (F8(i))'];

            if (profitBeforeTaxFallback != null && currentTaxExpense != null) {
              try {
                double pbtValue = double.tryParse(profitBeforeTaxFallback) ?? 0;
                double ctValue = double.tryParse(currentTaxExpense) ?? 0;

                debugPrint('Calculating Profit After Tax for $company in $yearColumn (CASE 2): PBT = $pbtValue, Current Tax = $ctValue');
                double profitAfterTax = pbtValue - ctValue;

                yearData['Profit After Tax (F10)'] = profitAfterTax
                    .toStringAsFixed(0);
              } catch (e) {
                // If calculation fails, try CASE 3
              }
            }
          }

          // Try CASE 3: Use original Profit / (loss) before taxation (F7) if available
          if (!yearData.containsKey('Profit After Tax (F10)')) {
            String? profitBeforeTaxF7 = yearData['Profit / (loss) before taxation (F7)'];
            String? taxExpenseF8 = yearData['Tax Expense (F8)'];

            if (profitBeforeTaxF7 != null && taxExpenseF8 != null) {
              try {
                double pbtValue = double.tryParse(profitBeforeTaxF7) ?? 0;
                double taxValue = double.tryParse(taxExpenseF8) ?? 0;

                debugPrint('Calculating Profit After Tax for $company in $yearColumn (CASE 3): PBT (F7) = $pbtValue, Tax Expense = $taxValue');
                double profitAfterTax = pbtValue - taxValue;

                yearData['Profit After Tax (F10)'] = profitAfterTax
                    .toStringAsFixed(0);
              } catch (e) {
                // If calculation fails, try CASE 4
              }
            }
          }


        }

        // Only add entry if we have at least some data
        if (yearData.isNotEmpty) {
          entries.add(
            FinancialDataEntry(
              company: company,
              year: yearColumn,
              data: yearData,
            ),
          );
        }
      }
    }

    return entries;
  }

  /// Automatically detect year columns from the data
  static List<String> detectYearColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];

    List<String> yearColumns = [];
    var firstRow = data[0];

    // Look for columns that look like years (4 digits)
    RegExp yearPattern = RegExp(r'^\d{4}$');

    for (String column in firstRow.keys) {
      if (yearPattern.hasMatch(column.trim())) {
        yearColumns.add(column);
      }
    }

    // Sort years
    yearColumns.sort();
    return yearColumns;
  }

  /// Detect the item name column
  static String? detectItemNameColumn(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return null;

    var firstRow = data[0];

    // Look for columns that might contain item names
    List<String> possibleNames = [
      'item',
      'item name',
      'description',
      'particulars',
      'line item',
    ];

    for (String column in firstRow.keys) {
      String lowerColumn = column.toLowerCase();
      if (possibleNames.any((name) => lowerColumn.contains(name))) {
        return column;
      }
    }

    return null;
  }
}








// // ==================== DATA EXTRACTION SERVICE ====================
// import 'financial_data_model.dart';

// class FinancialDataExtractor {
//   // Mapping of required columns to their item name patterns in the data
//   static const Map<String, List<String>> columnMappings = {
//     'Non Current Assets (A)': [
//       'A. Non-Current Assets',
//       'Non-Current Assets (A',
//       'Non Current Assets (A)',
//     ],
//     'Current Assets (B)': ['B. Current Assets', 'Current Assets (B'],
//     'Total Assets (A+B)': ['Total Assets (A+B)', 'Total Assets'],
//     'D. Non-Current Liabilities (D1+D2+D3+D4+D5)': [
//       'D. Non-Current Liabilities',
//       'Non-Current Liabilities (D',
//     ],
//     'E. Current Liabilities (E1+E2+E3+E4)': [
//       'E. Current Liabilities',
//       'Current Liabilities (E',
//     ],
//     'Total Liabilities (D+E)': ['Total Liabilities', 'Total Liabilities (D+E)'],
//     'Gross Profit (F3)': [
//       '3. Gross profit',
//       'Gross profit',
//       'F3. Gross profit',
//     ],
//     'Administrative Expenses (F4)': [
//       '4. Administrative expenses',
//       'Administrative expenses',
//       'F4. Administrative expenses',
//     ],
//     'Other Income (F5)': [
//       '5. Other income',
//       'Other income',
//       'F5. Other income',
//     ],
//     'EBIT (F6)': [
//       '6. EBIT',
//       'EBIT',
//       'F6. EBIT',
//       '6. Earnings before interest and tax',
//     ],
//     'Financial Expenses (F7)': [
//       '7. Financial expenses',
//       'Financial expenses',
//       'F7. Financial expenses',
//       '7. Financial expense',
//       'Financial expense',
//     ],
//     'Interest Expense (F7(i))': [
//       '(i) Interest expenses',
//       'Interest expenses',
//       'of which: (i) Interest expenses',
//       '(i) Interest expense',
//       'Interest expense',
//     ],
//     'Tax Expense (F9)': [
//       '9. Tax expenses',
//       'Tax expenses',
//       'F9. Tax expenses',
//       '9. Tax expense',
//       'Tax expense',
//       'F9. Tax expense',
//     ],
//     'Profit After Tax (F10)': [
//       '10. Profit after tax',
//       'Profit after tax',
//       'F10. Profit after tax',
//     ],
//     'Sales (F1)': ['1. Sales', 'Sales', 'F1. Sales'],
//     'Cash & Bank Balance (B1)': [
//       '1. Cash & bank balance',
//       'Cash & bank balance',
//       'B1. Cash',
//     ],
//     'Short-Term Investments (B5)': [
//       '4. Short term investments',
//       'Short term investments',
//       'B5. Short term investments',
//     ],
//     'Long-Term Investments (A5)': [
//       '5. Long term investments',
//       'Long term investments',
//       'A5. Long term investments',
//     ],
//   };

//   /// Extract financial data from filtered dataset
//   ///
//   /// Parameters:
//   /// - filteredData: List of filtered row data
//   /// - organizationColumnName: Name of the organization/company column
//   /// - itemNameColumn: Name of the column containing item names (like "A. Non-Current Assets")
//   /// - yearColumns: List of year column names to extract data from
//   /// - sectorColumnName: Optional sector column name
//   static List<FinancialDataEntry> extractFinancialData({
//     required List<Map<String, dynamic>> filteredData,
//     required String organizationColumnName,
//     required String itemNameColumn,
//     required List<String> yearColumns,
//     String? sectorColumnName,
//   }) {
//     List<FinancialDataEntry> entries = [];

//     // Group data by company
//     Map<String, List<Map<String, dynamic>>> groupedByCompany = {};
//     for (var row in filteredData) {
//       String company = row[organizationColumnName]?.toString().trim() ?? '';
//       if (company.isNotEmpty) {
//         if (!groupedByCompany.containsKey(company)) {
//           groupedByCompany[company] = [];
//         }
//         groupedByCompany[company]!.add(row);
//       }
//     }

//     // Process each company
//     for (var companyEntry in groupedByCompany.entries) {
//       String company = companyEntry.key;
//       List<Map<String, dynamic>> companyRows = companyEntry.value;

//       // Process each year
//       for (String yearColumn in yearColumns) {
//         Map<String, String> yearData = {};

//         // Extract data for each required column
//         for (var columnEntry in columnMappings.entries) {
//           String targetColumn = columnEntry.key;
//           List<String> patterns = columnEntry.value;

//           // Find matching row
//           for (var row in companyRows) {
//             String itemName = row[itemNameColumn]?.toString().trim() ?? '';

//             // Check if this row matches any of the patterns
//             bool matches = patterns.any(
//               (pattern) =>
//                   itemName.toLowerCase().contains(pattern.toLowerCase()),
//             );

//             if (matches) {
//               String value = row[yearColumn]?.toString().trim() ?? '';
//               if (value.isNotEmpty) {
//                 // Clean the value (remove commas, spaces, etc.)
//                 value = value.replaceAll(',', '').trim();
//                 yearData[targetColumn] = value;
//               }
//               break;
//             }
//           }
//         }

//         // === CALCULATIONS ===

//         // 1. Calculate Total Assets if not found but components are available
//         if (!yearData.containsKey('Total Assets (A+B)')) {
//           String? nonCurrent = yearData['Non Current Assets (A)'];
//           String? current = yearData['Current Assets (B)'];

//           if (nonCurrent != null && current != null) {
//             try {
//               double total =
//                   (double.tryParse(nonCurrent) ?? 0) +
//                   (double.tryParse(current) ?? 0);
//               yearData['Total Assets (A+B)'] = total.toStringAsFixed(0);
//             } catch (e) {
//               // If calculation fails, leave it empty
//             }
//           }
//         }

//         // 2. Calculate Total Liabilities (D+E)
//         if (!yearData.containsKey('Total Liabilities (D+E)')) {
//           String? nonCurrentLiabilities =
//               yearData['D. Non-Current Liabilities (D1+D2+D3+D4+D5)'];
//           String? currentLiabilities =
//               yearData['E. Current Liabilities (E1+E2+E3+E4)'];

//           if (nonCurrentLiabilities != null && currentLiabilities != null) {
//             try {
//               double total =
//                   (double.tryParse(nonCurrentLiabilities) ?? 0) +
//                   (double.tryParse(currentLiabilities) ?? 0);
//               yearData['Total Liabilities (D+E)'] = total.toStringAsFixed(0);
//             } catch (e) {
//               // If calculation fails, leave it empty
//             }
//           }
//         }

//         // 3. Calculate EBIT (F3 + F4 + F5) - ALWAYS override any existing value
//         // EBIT = Gross Profit (F3) + Administrative Expenses (F4) + Other Income (F5)
//         String? grossProfit = yearData['Gross Profit (F3)'];
//         String? adminExpenses = yearData['Administrative Expenses (F4)'];
//         String? otherIncome = yearData['Other Income (F5)'];

//         if (grossProfit != null &&
//             adminExpenses != null &&
//             otherIncome != null) {
//           try {
//             double ebit =
//                 (double.tryParse(grossProfit) ?? 0) +
//                 (double.tryParse(adminExpenses) ?? 0) +
//                 (double.tryParse(otherIncome) ?? 0);
//             yearData['EBIT (F6)'] = ebit.toStringAsFixed(0);
//           } catch (e) {
//             // If calculation fails, leave it empty
//           }
//         }

//         // 4. Calculate Profit After Tax = ((F3 + F4 + F5) - F7) - F9
//         // This is: (EBIT - Financial Expenses) - Tax Expense
//         String? financialExpenses = yearData['Financial Expenses (F7)'];
//         String? taxExpense = yearData['Tax Expense (F9)'];

//         if (grossProfit != null &&
//             adminExpenses != null &&
//             otherIncome != null &&
//             financialExpenses != null &&
//             taxExpense != null) {
//           try {
//             // Calculate EBIT first
//             double ebitValue =
//                 (double.tryParse(grossProfit) ?? 0) +
//                 (double.tryParse(adminExpenses) ?? 0) +
//                 (double.tryParse(otherIncome) ?? 0);

//             // Calculate Profit After Tax: (EBIT - F7) - F9
//             double profitAfterTax =
//                 (ebitValue - (double.tryParse(financialExpenses) ?? 0)) -
//                 (double.tryParse(taxExpense) ?? 0);

//             yearData['Profit After Tax (F10)'] = profitAfterTax.toStringAsFixed(
//               0,
//             );
//           } catch (e) {
//             // If calculation fails, leave it empty
//           }
//         }

//         // Only add entry if we have at least some data
//         if (yearData.isNotEmpty) {
//           entries.add(
//             FinancialDataEntry(
//               company: company,
//               year: yearColumn,
//               data: yearData,
//             ),
//           );
//         }
//       }
//     }

//     return entries;
//   }

//   /// Automatically detect year columns from the data
//   static List<String> detectYearColumns(List<Map<String, dynamic>> data) {
//     if (data.isEmpty) return [];

//     List<String> yearColumns = [];
//     var firstRow = data[0];

//     // Look for columns that look like years (4 digits)
//     RegExp yearPattern = RegExp(r'^\d{4}$');

//     for (String column in firstRow.keys) {
//       if (yearPattern.hasMatch(column.trim())) {
//         yearColumns.add(column);
//       }
//     }

//     // Sort years
//     yearColumns.sort();
//     return yearColumns;
//   }

//   /// Detect the item name column
//   static String? detectItemNameColumn(List<Map<String, dynamic>> data) {
//     if (data.isEmpty) return null;

//     var firstRow = data[0];

//     // Look for columns that might contain item names
//     List<String> possibleNames = [
//       'item',
//       'item name',
//       'description',
//       'particulars',
//       'line item',
//     ];

//     for (String column in firstRow.keys) {
//       String lowerColumn = column.toLowerCase();
//       if (possibleNames.any((name) => lowerColumn.contains(name))) {
//         return column;
//       }
//     }

//     return null;
//   }
// }










*/