import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_package;
import 'dart:convert';
import 'dart:html' as html; // For web download
import 'financial_data_model.dart';

class StoredDataViewPage extends StatefulWidget {
  const StoredDataViewPage({super.key});

  @override
  State<StoredDataViewPage> createState() => _StoredDataViewPageState();
}

class _StoredDataViewPageState extends State<StoredDataViewPage> {
  String? _filterCompany;
  String? _filterYear;
  int _currentPage = 0;
  final int _rowsPerPage = 50;
  bool _sortByYear = true; // Sort by year by default

  @override
  Widget build(BuildContext context) {
    return Consumer<FinancialDataProvider>(
      builder: (context, provider, child) {
        List<FinancialDataEntry> displayData = provider.storedData.toList();
        // List<FinancialDataEntry> displayData = provider.storedData;

        // Apply filters
        if (_filterCompany != null) {
          displayData = displayData
              .where((e) => e.company == _filterCompany)
              .toList();
        }
        if (_filterYear != null) {
          displayData = displayData
              .where((e) => e.year == _filterYear)
              .toList();
        }

        // Sort data
        if (_sortByYear) {
          // Sort by year, then by company
          displayData.sort((a, b) {
            int yearCompare = a.year.compareTo(b.year);
            if (yearCompare != 0) return yearCompare;
            return a.company.compareTo(b.company);
          });
        } else {
          // Sort by company, then by year
          displayData.sort((a, b) {
            int companyCompare = a.company.compareTo(b.company);
            if (companyCompare != 0) return companyCompare;
            return a.year.compareTo(b.year);
          });
        }

        // Pagination
        int totalRows = displayData.length;
        int totalPages = (totalRows / _rowsPerPage).ceil();
        int startIndex = _currentPage * _rowsPerPage;
        int endIndex = startIndex + _rowsPerPage;
        if (endIndex > totalRows) endIndex = totalRows;

        List<FinancialDataEntry> pageData = totalRows > 0
            ? displayData.sublist(startIndex, endIndex)
            : [];

        return Scaffold(
          appBar: AppBar(
            title: Text('Stored Financial Data (${provider.totalEntries})'),
            actions: [
              IconButton(
                onPressed: provider.totalEntries > 0
                    ? () => _exportData(displayData)
                    : null,
                icon: const Icon(Icons.download),
                tooltip: 'Export to CSV/Excel',
              ),
              IconButton(
                onPressed: provider.totalEntries > 0
                    ? () => _showClearConfirmation(context)
                    : null,
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All Data',
              ),
            ],
          ),
          body: provider.totalEntries == 0
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildFilterBar(provider),
                    const Divider(),
                    _buildDataSummary(
                      totalRows,
                      startIndex,
                      endIndex,
                      totalPages,
                    ),
                    Expanded(child: _buildDataTable(pageData)),
                    if (totalPages > 1) _buildPagination(totalPages),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storage, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No stored data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Extract and store data from the data processor',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(FinancialDataProvider provider) {
    List<String> companies = provider.getAllCompanies();
    List<String> years = provider.getAllYears();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Filter: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  value: _filterCompany,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Companies'),
                    ),
                    ...companies.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterCompany = value;
                      _currentPage = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  value: _filterYear,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Years'),
                    ),
                    ...years.map(
                      (y) => DropdownMenuItem(value: y, child: Text(y)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterYear = value;
                      _currentPage = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filterCompany = null;
                    _filterYear = null;
                    _currentPage = 0;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Sort by: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('Year'),
                selected: _sortByYear,
                onSelected: (selected) {
                  setState(() {
                    _sortByYear = true;
                  });
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Company'),
                selected: !_sortByYear,
                onSelected: (selected) {
                  setState(() {
                    _sortByYear = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataSummary(
    int totalRows,
    int startIndex,
    int endIndex,
    int totalPages,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        'Showing ${startIndex + 1}-$endIndex of $totalRows records (Page ${_currentPage + 1} of $totalPages)',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDataTable(List<FinancialDataEntry> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data matches the selected filters'));
    }

    // Build headers
    List<String> headers = ['Company', 'Year'];
    headers.addAll(FinancialDataProvider.requiredColumns);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
          columns: headers
              .map(
                (h) => DataColumn(
                  label: SizedBox(
                    width: h == 'Company' ? 200 : 120,
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
              .toList(),
          rows: data
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          entry.company,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(entry.year)),
                    ...FinancialDataProvider.requiredColumns.map(
                      (col) => DataCell(Text(entry.data[col] ?? '')),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          ...List.generate(totalPages > 7 ? 7 : totalPages, (index) {
            int pageNumber;
            if (totalPages <= 7) {
              pageNumber = index;
            } else if (_currentPage < 3) {
              pageNumber = index;
            } else if (_currentPage > totalPages - 4) {
              pageNumber = totalPages - 7 + index;
            } else {
              pageNumber = _currentPage - 3 + index;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () => setState(() => _currentPage = pageNumber),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPage == pageNumber
                      ? Colors.blue
                      : Colors.grey.shade300,
                  foregroundColor: _currentPage == pageNumber
                      ? Colors.white
                      : Colors.black,
                ),
                child: Text('${pageNumber + 1}'),
              ),
            );
          }),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _exportData(List<FinancialDataEntry> displayData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: Text(
                'Exporting ${displayData.length} records',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.green),
              title: const Text('Export as CSV'),
              subtitle: const Text('Comma-separated values'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCSV(displayData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.blue),
              title: const Text('Export as Excel'),
              subtitle: const Text('Microsoft Excel format'),
              onTap: () {
                Navigator.pop(context);
                _exportAsExcel(displayData);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportAsCSV(List<FinancialDataEntry> data) {
    try {
      // Build headers
      List<String> headers = ['Company', 'Year'];
      headers.addAll(FinancialDataProvider.requiredColumns);

      // Build rows
      List<List<dynamic>> rows = [headers];

      for (var entry in data) {
        List<dynamic> row = [entry.company, entry.year];
        for (String col in FinancialDataProvider.requiredColumns) {
          row.add(entry.data[col] ?? '');
        }
        rows.add(row);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Download file
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download =
            'financial_data_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${data.length} records to CSV'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _exportAsExcel(List<FinancialDataEntry> data) {
    try {
      // Create Excel file
      var excel = excel_package.Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // Create new sheet
      var sheet = excel['Financial Data'];

      // Build headers
      List<String> headers = ['Company', 'Year'];
      headers.addAll(FinancialDataProvider.requiredColumns);

      // Add header row with styling
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          excel_package.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = excel_package.TextCellValue(headers[i]);
        cell.cellStyle = excel_package.CellStyle(
          bold: true,
          backgroundColorHex: excel_package.ExcelColor.blue,
          fontColorHex: excel_package.ExcelColor.white,
        );
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        var entry = data[rowIndex];

        // Company
        sheet
            .cell(
              excel_package.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: rowIndex + 1,
              ),
            )
            .value = excel_package.TextCellValue(
          entry.company,
        );

        // Year
        sheet
            .cell(
              excel_package.CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: rowIndex + 1,
              ),
            )
            .value = excel_package.TextCellValue(
          entry.year,
        );

        // Data columns
        for (
          int colIndex = 0;
          colIndex < FinancialDataProvider.requiredColumns.length;
          colIndex++
        ) {
          String columnName = FinancialDataProvider.requiredColumns[colIndex];
          String value = entry.data[columnName] ?? '';

          var cell = sheet.cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: colIndex + 2,
              rowIndex: rowIndex + 1,
            ),
          );

          // Try to parse as number, otherwise as text
          double? numValue = double.tryParse(value);
          if (numValue != null) {
            cell.value = excel_package.DoubleCellValue(numValue);
          } else {
            cell.value = excel_package.TextCellValue(value);
          }
        }
      }

      // Auto-fit columns (approximate)
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }
      sheet.setColumnWidth(0, 30); // Company column wider

      // Save and download
      var fileBytes = excel.save();
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download =
              'financial_data_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${data.length} records to Excel'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting Excel: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to clear all stored financial data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FinancialDataProvider>().clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}






// // ==================== STORED DATA VIEW PAGE ====================
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'financial_data_model.dart';

// class StoredDataViewPage extends StatefulWidget {
//   const StoredDataViewPage({super.key});

//   @override
//   State<StoredDataViewPage> createState() => _StoredDataViewPageState();
// }

// class _StoredDataViewPageState extends State<StoredDataViewPage> {
//   String? _filterCompany;
//   String? _filterYear;
//   int _currentPage = 0;
//   final int _rowsPerPage = 50;

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<FinancialDataProvider>(
//       builder: (context, provider, child) {
//         List<FinancialDataEntry> displayData = provider.storedData;

//         // Apply filters
//         if (_filterCompany != null) {
//           displayData = displayData
//               .where((e) => e.company == _filterCompany)
//               .toList();
//         }
//         if (_filterYear != null) {
//           displayData = displayData
//               .where((e) => e.year == _filterYear)
//               .toList();
//         }

//         // Pagination
//         int totalRows = displayData.length;
//         int totalPages = (totalRows / _rowsPerPage).ceil();
//         int startIndex = _currentPage * _rowsPerPage;
//         int endIndex = startIndex + _rowsPerPage;
//         if (endIndex > totalRows) endIndex = totalRows;

//         List<FinancialDataEntry> pageData = displayData.sublist(
//           startIndex,
//           endIndex,
//         );

//         return Scaffold(
//           appBar: AppBar(
//             title: Text('Stored Financial Data (${provider.totalEntries})'),
//             actions: [
//               IconButton(
//                 onPressed: provider.totalEntries > 0 ? _exportData : null,
//                 icon: const Icon(Icons.download),
//                 tooltip: 'Export to CSV/Excel',
//               ),
//               IconButton(
//                 onPressed: provider.totalEntries > 0
//                     ? () => _showClearConfirmation(context)
//                     : null,
//                 icon: const Icon(Icons.delete_sweep),
//                 tooltip: 'Clear All Data',
//               ),
//             ],
//           ),
//           body: provider.totalEntries == 0
//               ? _buildEmptyState()
//               : Column(
//                   children: [
//                     _buildFilterBar(provider),
//                     const Divider(),
//                     _buildDataSummary(totalRows, startIndex, endIndex, totalPages),
//                     Expanded(
//                       child: _buildDataTable(pageData),
//                     ),
//                     if (totalPages > 1)
//                       _buildPagination(totalPages),
//                   ],
//                 ),
//         );
//       },
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.storage, size: 64, color: Colors.grey.shade400),
//           const SizedBox(height: 16),
//           Text(
//             'No stored data',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey.shade600,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Extract and store data from the data processor',
//             style: TextStyle(color: Colors.grey.shade600),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFilterBar(FinancialDataProvider provider) {
//     List<String> companies = provider.getAllCompanies();
//     List<String> years = provider.getAllYears();

//     return Container(
//       padding: const EdgeInsets.all(16),
//       color: Colors.blue.shade50,
//       child: Row(
//         children: [
//           const Text(
//             'Filter: ',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: DropdownButtonFormField<String>(
//               decoration: const InputDecoration(
//                 labelText: 'Company',
//                 border: OutlineInputBorder(),
//                 isDense: true,
//               ),
//               value: _filterCompany,
//               items: [
//                 const DropdownMenuItem(
//                   value: null,
//                   child: Text('All Companies'),
//                 ),
//                 ...companies.map(
//                   (c) => DropdownMenuItem(value: c, child: Text(c)),
//                 ),
//               ],
//               onChanged: (value) {
//                 setState(() {
//                   _filterCompany = value;
//                   _currentPage = 0;
//                 });
//               },
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: DropdownButtonFormField<String>(
//               decoration: const InputDecoration(
//                 labelText: 'Year',
//                 border: OutlineInputBorder(),
//                 isDense: true,
//               ),
//               value: _filterYear,
//               items: [
//                 const DropdownMenuItem(
//                   value: null,
//                   child: Text('All Years'),
//                 ),
//                 ...years.map(
//                   (y) => DropdownMenuItem(value: y, child: Text(y)),
//                 ),
//               ],
//               onChanged: (value) {
//                 setState(() {
//                   _filterYear = value;
//                   _currentPage = 0;
//                 });
//               },
//             ),
//           ),
//           const SizedBox(width: 16),
//           ElevatedButton.icon(
//             onPressed: () {
//               setState(() {
//                 _filterCompany = null;
//                 _filterYear = null;
//                 _currentPage = 0;
//               });
//             },
//             icon: const Icon(Icons.clear),
//             label: const Text('Clear Filters'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDataSummary(
//     int totalRows,
//     int startIndex,
//     int endIndex,
//     int totalPages,
//   ) {
//     return Padding(
//       padding: const EdgeInsets.all(8),
//       child: Text(
//         'Showing ${startIndex + 1}-$endIndex of $totalRows records (Page ${_currentPage + 1} of $totalPages)',
//         style: const TextStyle(fontWeight: FontWeight.bold),
//       ),
//     );
//   }

//   Widget _buildDataTable(List<FinancialDataEntry> data) {
//     if (data.isEmpty) {
//       return const Center(
//         child: Text('No data matches the selected filters'),
//       );
//     }

//     // Build headers
//     List<String> headers = ['Company', 'Year'];
//     headers.addAll(FinancialDataProvider.requiredColumns);

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: SingleChildScrollView(
//         child: DataTable(
//           headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
//           columns: headers
//               .map(
//                 (h) => DataColumn(
//                   label: SizedBox(
//                     width: h == 'Company' ? 200 : 120,
//                     child: Text(
//                       h,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 12,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ),
//               )
//               .toList(),
//           rows: data
//               .map(
//                 (entry) => DataRow(
//                   cells: [
//                     DataCell(
//                       SizedBox(
//                         width: 200,
//                         child: Text(
//                           entry.company,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ),
//                     DataCell(Text(entry.year)),
//                     ...FinancialDataProvider.requiredColumns.map(
//                       (col) => DataCell(
//                         Text(entry.data[col] ?? ''),
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//               .toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildPagination(int totalPages) {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           IconButton(
//             onPressed: _currentPage > 0
//                 ? () => setState(() => _currentPage--)
//                 : null,
//             icon: const Icon(Icons.chevron_left),
//           ),
//           const SizedBox(width: 8),
//           ...List.generate(totalPages > 7 ? 7 : totalPages, (index) {
//             int pageNumber;
//             if (totalPages <= 7) {
//               pageNumber = index;
//             } else if (_currentPage < 3) {
//               pageNumber = index;
//             } else if (_currentPage > totalPages - 4) {
//               pageNumber = totalPages - 7 + index;
//             } else {
//               pageNumber = _currentPage - 3 + index;
//             }

//             return Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 4),
//               child: ElevatedButton(
//                 onPressed: () => setState(() => _currentPage = pageNumber),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _currentPage == pageNumber
//                       ? Colors.blue
//                       : Colors.grey.shade300,
//                   foregroundColor: _currentPage == pageNumber
//                       ? Colors.white
//                       : Colors.black,
//                 ),
//                 child: Text('${pageNumber + 1}'),
//               ),
//             );
//           }),
//           const SizedBox(width: 8),
//           IconButton(
//             onPressed: _currentPage < totalPages - 1
//                 ? () => setState(() => _currentPage++)
//                 : null,
//             icon: const Icon(Icons.chevron_right),
//           ),
//         ],
//       ),
//     );
//   }

//   void _exportData() {
//     // Show dialog for export options
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Export Data'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               leading: Icon(Icons.description),
//               title: Text('Export as CSV'),
//               subtitle: Text('Coming soon...'),
//             ),
//             ListTile(
//               leading: Icon(Icons.table_chart),
//               title: Text('Export as Excel'),
//               subtitle: Text('Coming soon...'),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showClearConfirmation(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Clear All Data'),
//         content: const Text(
//           'Are you sure you want to clear all stored financial data? This action cannot be undone.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               context.read<FinancialDataProvider>().clearAll();
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('All data cleared'),
//                   duration: Duration(seconds: 2),
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Clear All'),
//           ),
//         ],
//       ),
//     );
//   }
// }