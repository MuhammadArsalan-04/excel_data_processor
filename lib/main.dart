import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:provider/provider.dart';

import 'package:csv/csv.dart';

import 'financial_data_model.dart';
import 'financial_data_extractor.dart';
import 'stored_data_view_page.dart';

void main() {
  // runApp(const MyApp());

  runApp(
    ChangeNotifierProvider(
      create: (_) => FinancialDataProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Excel & CSV Data Processor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Processor'),
        actions: [
          // Add this button to navigate to stored data
          Consumer<FinancialDataProvider>(
            builder: (context, provider, child) {
              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoredDataViewPage(),
                    ),
                  );
                },
                icon: Badge(
                  label: Text('${provider.totalEntries}'),
                  isLabelVisible: provider.totalEntries > 0,
                  child: const Icon(Icons.storage),
                ),
                tooltip: 'View Stored Data',
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upload_file, size: 100, color: Colors.blue),
            const SizedBox(height: 32),
            const Text(
              'Choose File Type to Process',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExcelProcessorPage(),
                  ),
                );
              },
              icon: const Icon(Icons.table_chart),
              label: const Text('Process Excel File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CsvProcessorPage(),
                  ),
                );
              },
              icon: const Icon(Icons.description),
              label: const Text('Process Multiple CSV Files'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 48),
            // Add this button to view stored data
            Consumer<FinancialDataProvider>(
              builder: (context, provider, child) {
                return ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StoredDataViewPage(),
                      ),
                    );
                  },
                  icon: Badge(
                    label: Text('${provider.totalEntries}'),
                    isLabelVisible: provider.totalEntries > 0,
                    child: const Icon(Icons.storage),
                  ),
                  label: const Text('View Stored Financial Data'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


// ==================== CSV PROCESSOR PAGE ====================
class CsvProcessorPage extends StatefulWidget {
  const CsvProcessorPage({super.key});

  @override
  State<CsvProcessorPage> createState() => _CsvProcessorPageState();
}

class _CsvProcessorPageState extends State<CsvProcessorPage> {
  bool _isLoading = false;
  String _loadingMessage = '';
  List<String> _fileNames = [];

  List<Map<String, dynamic>> _jsonData = [];
  List<Map<String, dynamic>> _filteredData = [];
  List<List<dynamic>> _displayCsvData = [];

  int _currentPage = 0;
  final int _rowsPerPage = 100;
  int _totalFilteredRows = 0;

  Set<String> _selectedSectors = {};
  Set<String> _selectedOrganizations = {};
  List<String> _availableSectors = [];
  List<String> _availableOrganizations = [];
  String _sectorColumnName = '';
  String _subsectorColumnName = '';
  String _organizationColumnName = '';

  // Dynamic column filter
  Map<String, Set<String>> _dynamicFilters = {};
  Map<String, List<String>> _availableDynamicFilters = {};
  List<String> _allColumnNames = [];

  // Selected columns to display
  Set<String> _selectedColumnsToDisplay = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _fileNames = result.files.map((f) => f.name).toList();
          _currentPage = 0;
          _isLoading = true;
          _loadingMessage = 'Reading CSV files...';
        });

        List<Map<String, dynamic>> allData = [];

        for (int i = 0; i < result.files.length; i++) {
          PlatformFile file = result.files[i];

          setState(() {
            _loadingMessage =
                'Processing ${file.name} (${i + 1}/${result.files.length})...';
          });

          Uint8List? fileBytes = file.bytes;

          if (fileBytes == null && !kIsWeb && file.path != null) {
            fileBytes = await File(file.path!).readAsBytes();
          }

          if (fileBytes == null) {
            _showError('Cannot read file: ${file.name}');
            continue;
          }

          List<Map<String, dynamic>> csvData = await _parseCsvBytes(fileBytes);
          allData.addAll(csvData);

          await Future.delayed(const Duration(milliseconds: 50));
        }

        if (allData.isEmpty) {
          setState(() => _isLoading = false);
          _showError('No data found in CSV files.');
          return;
        }

        setState(() {
          _jsonData = allData;
          _loadingMessage = 'Extracting filter options...';
        });

        await Future.delayed(const Duration(milliseconds: 50));
        _extractFilterColumns(allData);
        _extractAllColumns(allData);
        _applyFilters();

        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error picking files: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _parseCsvBytes(Uint8List bytes) async {
    String csvString = String.fromCharCodes(bytes);
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(
      csvString,
    );

    if (csvTable.isEmpty) return [];

    List<String> headers = [];
    for (var cell in csvTable[0]) {
      String header = cell?.toString().trim() ?? '';
      if (header.isEmpty) {
        header = 'Column${headers.length + 1}';
      }
      headers.add(header);
    }

    List<Map<String, dynamic>> jsonData = [];
    for (int i = 1; i < csvTable.length; i++) {
      Map<String, dynamic> row = {};
      for (int j = 0; j < headers.length && j < csvTable[i].length; j++) {
        row[headers[j]] = csvTable[i][j]?.toString().trim() ?? '';
      }
      jsonData.add(row);
    }

    return jsonData;
  }

  void _extractFilterColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;

    Map<String, dynamic> firstRow = data[0];
    for (String key in firstRow.keys) {
      String lowerKey = key.toLowerCase();
      if (lowerKey.contains('sector') &&
          !lowerKey.contains('sub') &&
          _sectorColumnName.isEmpty) {
        _sectorColumnName = key;
      }
      if (lowerKey.contains('subsector') && _subsectorColumnName.isEmpty) {
        _subsectorColumnName = key;
      }
      if ((lowerKey.contains('organization') || lowerKey.contains('company')) &&
          _organizationColumnName.isEmpty) {
        _organizationColumnName = key;
      }
    }

    Set<String> sectors = {};
    Set<String> organizations = {};

    for (var row in data) {
      if (_sectorColumnName.isNotEmpty) {
        String sector = row[_sectorColumnName]?.toString().trim() ?? '';
        if (sector.isNotEmpty) sectors.add(sector);
      }
      if (_organizationColumnName.isNotEmpty) {
        String org = row[_organizationColumnName]?.toString().trim() ?? '';
        if (org.isNotEmpty) organizations.add(org);
      }
    }

    setState(() {
      _availableSectors = sectors.toList()..sort();
      _availableOrganizations = organizations.toList()..sort();
    });
  }

  void _extractAllColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;

    setState(() {
      _allColumnNames = data[0].keys.toList()..sort();
    });
  }

  Future<void> _extractDynamicColumnValues(String columnName) async {
    if (_jsonData.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Extracting values for $columnName...';
    });

    try {
      Set<String> values = {};
      for (int i = 0; i < _jsonData.length; i++) {
        String value = _jsonData[i][columnName]?.toString().trim() ?? '';
        if (value.isNotEmpty) values.add(value);

        if (i % 1000 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      List<String> result = values.toList()..sort();

      setState(() {
        _availableDynamicFilters[columnName] = result;
        if (!_dynamicFilters.containsKey(columnName)) {
          _dynamicFilters[columnName] = <String>{};
        }
        _isLoading = false;
        _loadingMessage = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
      _showError('Error extracting column values: $e');
    }
  }

  void _applyFilters() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Applying filters...';
      _currentPage = 0;
    });

    try {
      List<Map<String, dynamic>> filtered = [];

      for (int i = 0; i < _jsonData.length; i++) {
        var row = _jsonData[i];

        bool sectorMatch =
            _selectedSectors.isEmpty ||
            _selectedSectors.contains(
              row[_sectorColumnName]?.toString().trim(),
            );
        bool orgMatch =
            _selectedOrganizations.isEmpty ||
            _selectedOrganizations.contains(
              row[_organizationColumnName]?.toString().trim(),
            );

        bool dynamicMatch = true;
        for (var entry in _dynamicFilters.entries) {
          if (entry.value.isNotEmpty) {
            String columnName = entry.key;
            Set<String> selectedValues = entry.value;
            String cellValue = row[columnName]?.toString().trim() ?? '';
            if (!selectedValues.contains(cellValue)) {
              dynamicMatch = false;
              break;
            }
          }
        }

        if (sectorMatch && orgMatch && dynamicMatch) {
          filtered.add(row);
        }

        if (i % 1000 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      setState(() {
        _filteredData = filtered;
        _totalFilteredRows = filtered.length;
      });

      _updateDisplayData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
      _showError('Error applying filters: $e');
    }
  }

  Future<void> _updateDisplayData() async {
    setState(() {
      _loadingMessage = 'Loading page data...';
    });

    await Future.delayed(const Duration(milliseconds: 50));

    if (_filteredData.isEmpty) {
      setState(() {
        _displayCsvData = [];
        _isLoading = false;
        _loadingMessage = '';
      });
      return;
    }

    List<String> allHeaders = _filteredData[0].keys.toList();

    List<String> headersToDisplay = [];
    if (_selectedColumnsToDisplay.isEmpty) {
      headersToDisplay = allHeaders;
    } else {
      for (var col in allHeaders) {
        if (_selectedColumnsToDisplay.contains(col)) {
          headersToDisplay.add(col);
        }
      }
    }

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    if (endIndex > _filteredData.length) endIndex = _filteredData.length;

    List<List<dynamic>> csvData = [headersToDisplay];
    for (int i = startIndex; i < endIndex; i++) {
      List<dynamic> row = headersToDisplay
          .map((h) => _filteredData[i][h])
          .toList();
      csvData.add(row);
    }

    setState(() {
      _displayCsvData = csvData;
      _isLoading = false;
      _loadingMessage = '';
    });
  }

  void _nextPage() {
    if ((_currentPage + 1) * _rowsPerPage < _totalFilteredRows) {
      setState(() {
        _currentPage++;
      });
      _updateDisplayData();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _updateDisplayData();
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _updateDisplayData();
  }

  void _clearData() {
    setState(() {
      _fileNames = [];
      _jsonData = [];
      _filteredData = [];
      _displayCsvData = [];
      _isLoading = false;
      _loadingMessage = '';
      _currentPage = 0;
      _totalFilteredRows = 0;
      _selectedSectors.clear();
      _selectedOrganizations.clear();
      _availableSectors = [];
      _availableOrganizations = [];
      _sectorColumnName = '';
      _subsectorColumnName = '';
      _organizationColumnName = '';
      _dynamicFilters.clear();
      _availableDynamicFilters.clear();
      _allColumnNames = [];
      _selectedColumnsToDisplay.clear();
    });
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        availableSectors: _availableSectors,
        availableOrganizations: _availableOrganizations,
        selectedSectors: _selectedSectors,
        selectedOrganizations: _selectedOrganizations,
        sectorColumnName: _sectorColumnName,
        subsectorColumnName: _subsectorColumnName,
        organizationColumnName: _organizationColumnName,
        allColumnNames: _allColumnNames,
        dynamicFilters: _dynamicFilters,
        availableDynamicFilters: _availableDynamicFilters,
        selectedColumnsToDisplay: _selectedColumnsToDisplay,
        onExtractColumn: _extractDynamicColumnValues,
        onApply: (sectors, organizations, dynamicFilters, selectedColumns) {
          setState(() {
            _selectedSectors = sectors;
            _selectedOrganizations = organizations;
            _dynamicFilters = dynamicFilters;
            _selectedColumnsToDisplay = selectedColumns;
          });
          _applyFilters();
        },
        onExtractAndNavigate: (selectedColumn) {
          _extractAndNavigateToFilteredView(selectedColumn);
        },
      ),
    );
  }

  void _extractAndNavigateToFilteredView(String selectedColumn) async {
    // Use filtered data if filters are applied, otherwise use all data
    List<Map<String, dynamic>> dataToUse = _filteredData.isNotEmpty
        ? _filteredData
        : _jsonData;

    if (dataToUse.isEmpty) {
      _showError('No data available');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredDataViewPage(
          filteredData: dataToUse,
          sectorColumnName: _sectorColumnName,
          subsectorColumnName: _subsectorColumnName.isNotEmpty
              ? _subsectorColumnName
              : null,
          organizationColumnName: _organizationColumnName,
          selectedColumnsToDisplay: _selectedColumnsToDisplay,
          allColumnNames: _allColumnNames,
        ),
      ),
    );
  }

  int _getTotalActiveFilters() {
    int count = _selectedSectors.length + _selectedOrganizations.length;
    for (var values in _dynamicFilters.values) {
      count += values.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    int displayedRows = _displayCsvData.length > 0
        ? _displayCsvData.length - 1
        : 0;
    int totalActiveFilters = _getTotalActiveFilters();
    int totalPages = (_totalFilteredRows / _rowsPerPage).ceil();
    int startRow = _currentPage * _rowsPerPage + 1;
    int endRow = (_currentPage + 1) * _rowsPerPage;
    if (endRow > _totalFilteredRows) endRow = _totalFilteredRows;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Data Processor'),
        actions: [
          if (_jsonData.isNotEmpty && !_isLoading)
            IconButton(
              onPressed: _showFilterDialog,
              icon: Badge(
                label: Text('$totalActiveFilters'),
                isLabelVisible: totalActiveFilters > 0,
                child: const Icon(Icons.filter_list),
              ),
              tooltip: 'Filter Data',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickFiles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Pick CSV Files (Multiple)'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _fileNames.isNotEmpty && !_isLoading
                          ? _clearData
                          : null,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                if (_fileNames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Files loaded: ${_fileNames.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _fileNames
                        .map(
                          (name) => Chip(
                            label: Text(name),
                            avatar: const Icon(Icons.description, size: 16),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),

          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isLoading && _displayCsvData.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          'Showing $startRow-$endRow of $_totalFilteredRows records (Page ${_currentPage + 1} of $totalPages)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (totalActiveFilters > 0 ||
                            _selectedColumnsToDisplay.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                ..._selectedSectors.map(
                                  (s) => Chip(
                                    label: Text('$_sectorColumnName: $s'),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedSectors.remove(s);
                                      });
                                      _applyFilters();
                                    },
                                  ),
                                ),
                                ..._selectedOrganizations.map(
                                  (o) => Chip(
                                    label: Text('$_organizationColumnName: $o'),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedOrganizations.remove(o);
                                      });
                                      _applyFilters();
                                    },
                                  ),
                                ),
                                ..._dynamicFilters.entries.expand((entry) {
                                  return entry.value.map(
                                    (value) => Chip(
                                      label: Text('${entry.key}: $value'),
                                      onDeleted: () {
                                        setState(() {
                                          _dynamicFilters[entry.key]!.remove(
                                            value,
                                          );
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                  );
                                }),
                                if (_selectedColumnsToDisplay.isNotEmpty)
                                  Chip(
                                    label: Text(
                                      'Columns: ${_selectedColumnsToDisplay.length} selected',
                                    ),
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: _displayCsvData[0]
                              .map(
                                (header) => DataColumn(
                                  label: Text(
                                    header.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          rows: _displayCsvData
                              .skip(1)
                              .map(
                                (row) => DataRow(
                                  cells: row
                                      .map(
                                        (cell) =>
                                            DataCell(Text(cell.toString())),
                                      )
                                      .toList(),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_totalFilteredRows > _rowsPerPage)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0 ? _previousPage : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 8),
                          ...List.generate(totalPages > 7 ? 7 : totalPages, (
                            index,
                          ) {
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ElevatedButton(
                                onPressed: () => _goToPage(pageNumber),
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
                            onPressed:
                                (_currentPage + 1) * _rowsPerPage <
                                    _totalFilteredRows
                                ? _nextPage
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          if (!_isLoading &&
              _displayCsvData.isEmpty &&
              _jsonData.isNotEmpty &&
              totalActiveFilters > 0)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_alt_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No data matches the selected filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isLoading && _displayCsvData.isEmpty && _fileNames.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No files selected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload CSV files to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== EXCEL PROCESSOR PAGE ====================
class ExcelProcessorPage extends StatefulWidget {
  const ExcelProcessorPage({super.key});

  @override
  State<ExcelProcessorPage> createState() => _ExcelProcessorPageState();
}

class _ExcelProcessorPageState extends State<ExcelProcessorPage> {
  bool _isLoading = false;
  String _loadingMessage = '';
  String? _fileName;

  List<Map<String, dynamic>> _jsonData = [];
  List<Map<String, dynamic>> _filteredData = [];
  List<List<dynamic>> _displayCsvData = [];

  int _currentPage = 0;
  final int _rowsPerPage = 100;
  int _totalFilteredRows = 0;

  List<String> _sheetNames = [];
  String? _selectedSheet;

  Set<String> _selectedSectors = {};
  Set<String> _selectedOrganizations = {};
  List<String> _availableSectors = [];
  List<String> _availableOrganizations = [];
  String _sectorColumnName = '';
  String _subsectorColumnName = '';
  String _organizationColumnName = '';

  Map<String, Set<String>> _dynamicFilters = {};
  Map<String, List<String>> _availableDynamicFilters = {};
  List<String> _allColumnNames = [];
  Set<String> _selectedColumnsToDisplay = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _fileName = result.files.single.name;
          _currentPage = 0;
          _isLoading = true;
          _loadingMessage = 'Reading file...';
        });

        Uint8List? fileBytes = result.files.single.bytes;

        if (fileBytes == null && !kIsWeb && result.files.single.path != null) {
          fileBytes = await File(result.files.single.path!).readAsBytes();
        }

        if (fileBytes == null) {
          _showError('Cannot read file bytes.');
          setState(() => _isLoading = false);
          return;
        }

        await _processFileBytes(fileBytes);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error picking file: $e');
    }
  }

  Future<void> _processFileBytes(Uint8List bytes) async {
    try {
      setState(() {
        _loadingMessage = 'Decoding Excel file...';
      });

      await Future.delayed(const Duration(milliseconds: 100));

      SpreadsheetDecoder decoder = SpreadsheetDecoder.decodeBytes(bytes);

      List<String> sheets = decoder.tables.keys.toList();
      setState(() {
        _sheetNames = sheets;
        _selectedSheet = sheets.isNotEmpty ? sheets[0] : null;
      });

      if (_selectedSheet != null) {
        await _convertToJsonAndExtractFilters(decoder, _selectedSheet!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error processing file: $e');
    }
  }

  Future<void> _convertToJsonAndExtractFilters(
    SpreadsheetDecoder decoder,
    String sheetName,
  ) async {
    setState(() {
      _loadingMessage = 'Converting Excel to JSON...';
    });

    await Future.delayed(const Duration(milliseconds: 50));
    List<Map<String, dynamic>> jsonResult = _excelToJson(decoder, sheetName);

    if (jsonResult.isEmpty) {
      setState(() => _isLoading = false);
      _showError('No data found in the selected sheet.');
      return;
    }

    setState(() {
      _jsonData = jsonResult;
      _loadingMessage = 'Extracting filter options...';
    });

    await Future.delayed(const Duration(milliseconds: 50));
    _extractFilterColumns(jsonResult);
    _extractAllColumns(jsonResult);
    _applyFilters();

    setState(() {
      _isLoading = false;
      _loadingMessage = '';
    });
  }

  List<Map<String, dynamic>> _excelToJson(
    SpreadsheetDecoder decoder,
    String sheetName,
  ) {
    var table = decoder.tables[sheetName];
    if (table == null || table.rows.isEmpty) return [];

    List<String> headers = [];
    for (var cell in table.rows[0]) {
      String header = cell?.toString().trim() ?? '';
      if (header.isEmpty) {
        header = 'Column${headers.length + 1}';
      }
      headers.add(header);
    }

    List<Map<String, dynamic>> jsonData = [];
    for (int i = 1; i < table.rows.length; i++) {
      Map<String, dynamic> row = {};
      for (int j = 0; j < headers.length && j < table.rows[i].length; j++) {
        row[headers[j]] = table.rows[i][j]?.toString().trim() ?? '';
      }
      jsonData.add(row);

      if (i % 500 == 0) {
        setState(() {
          _loadingMessage =
              'Converting Excel to JSON... ($i/${table.rows.length - 1})';
        });
      }
    }

    return jsonData;
  }

  void _extractFilterColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;

    Map<String, dynamic> firstRow = data[0];
    for (String key in firstRow.keys) {
      String lowerKey = key.toLowerCase();
      if (lowerKey.contains('sector') &&
          !lowerKey.contains('sub') &&
          _sectorColumnName.isEmpty) {
        _sectorColumnName = key;
      }
      if (lowerKey.contains('subsector') && _subsectorColumnName.isEmpty) {
        _subsectorColumnName = key;
      }
      if ((lowerKey.contains('organization') || lowerKey.contains('company')) &&
          _organizationColumnName.isEmpty) {
        _organizationColumnName = key;
      }
    }

    Set<String> sectors = {};
    Set<String> organizations = {};

    for (var row in data) {
      if (_sectorColumnName.isNotEmpty) {
        String sector = row[_sectorColumnName]?.toString().trim() ?? '';
        if (sector.isNotEmpty) sectors.add(sector);
      }
      if (_organizationColumnName.isNotEmpty) {
        String org = row[_organizationColumnName]?.toString().trim() ?? '';
        if (org.isNotEmpty) organizations.add(org);
      }
    }

    setState(() {
      _availableSectors = sectors.toList()..sort();
      _availableOrganizations = organizations.toList()..sort();
    });
  }

  void _extractAllColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;

    setState(() {
      _allColumnNames = data[0].keys.toList()..sort();
    });
  }

  Future<void> _extractDynamicColumnValues(String columnName) async {
    if (_jsonData.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Extracting values for $columnName...';
    });

    try {
      Set<String> values = {};
      for (int i = 0; i < _jsonData.length; i++) {
        String value = _jsonData[i][columnName]?.toString().trim() ?? '';
        if (value.isNotEmpty) values.add(value);

        if (i % 1000 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      List<String> result = values.toList()..sort();

      setState(() {
        _availableDynamicFilters[columnName] = result;
        if (!_dynamicFilters.containsKey(columnName)) {
          _dynamicFilters[columnName] = <String>{};
        }
        _isLoading = false;
        _loadingMessage = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
      _showError('Error extracting column values: $e');
    }
  }

  void _applyFilters() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Applying filters...';
      _currentPage = 0;
    });

    try {
      List<Map<String, dynamic>> filtered = [];

      for (int i = 0; i < _jsonData.length; i++) {
        var row = _jsonData[i];

        bool sectorMatch =
            _selectedSectors.isEmpty ||
            _selectedSectors.contains(
              row[_sectorColumnName]?.toString().trim(),
            );
        bool orgMatch =
            _selectedOrganizations.isEmpty ||
            _selectedOrganizations.contains(
              row[_organizationColumnName]?.toString().trim(),
            );

        bool dynamicMatch = true;
        for (var entry in _dynamicFilters.entries) {
          if (entry.value.isNotEmpty) {
            String columnName = entry.key;
            Set<String> selectedValues = entry.value;
            String cellValue = row[columnName]?.toString().trim() ?? '';
            if (!selectedValues.contains(cellValue)) {
              dynamicMatch = false;
              break;
            }
          }
        }

        if (sectorMatch && orgMatch && dynamicMatch) {
          filtered.add(row);
        }

        if (i % 1000 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      setState(() {
        _filteredData = filtered;
        _totalFilteredRows = filtered.length;
      });

      _updateDisplayData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
      _showError('Error applying filters: $e');
    }
  }

  Future<void> _updateDisplayData() async {
    setState(() {
      _loadingMessage = 'Loading page data...';
    });

    await Future.delayed(const Duration(milliseconds: 50));

    if (_filteredData.isEmpty) {
      setState(() {
        _displayCsvData = [];
        _isLoading = false;
        _loadingMessage = '';
      });
      return;
    }

    List<String> allHeaders = _filteredData[0].keys.toList();

    List<String> headersToDisplay = [];
    if (_selectedColumnsToDisplay.isEmpty) {
      headersToDisplay = allHeaders;
    } else {
      for (var col in allHeaders) {
        if (_selectedColumnsToDisplay.contains(col)) {
          headersToDisplay.add(col);
        }
      }
    }

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    if (endIndex > _filteredData.length) endIndex = _filteredData.length;

    List<List<dynamic>> csvData = [headersToDisplay];
    for (int i = startIndex; i < endIndex; i++) {
      List<dynamic> row = headersToDisplay
          .map((h) => _filteredData[i][h])
          .toList();
      csvData.add(row);
    }

    setState(() {
      _displayCsvData = csvData;
      _isLoading = false;
      _loadingMessage = '';
    });
  }

  void _nextPage() {
    if ((_currentPage + 1) * _rowsPerPage < _totalFilteredRows) {
      setState(() {
        _currentPage++;
      });
      _updateDisplayData();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _updateDisplayData();
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _updateDisplayData();
  }

  Future<void> _onSheetChanged(String? newSheet) async {
    if (newSheet != null && newSheet != _selectedSheet) {
      setState(() {
        _selectedSheet = newSheet;
        _currentPage = 0;
        _selectedSectors.clear();
        _selectedOrganizations.clear();
        _dynamicFilters.clear();
        _availableDynamicFilters.clear();
        _selectedColumnsToDisplay.clear();
      });
    }
  }

  void _clearData() {
    setState(() {
      _fileName = null;
      _jsonData = [];
      _filteredData = [];
      _displayCsvData = [];
      _sheetNames = [];
      _selectedSheet = null;
      _isLoading = false;
      _loadingMessage = '';
      _currentPage = 0;
      _totalFilteredRows = 0;
      _selectedSectors.clear();
      _selectedOrganizations.clear();
      _availableSectors = [];
      _availableOrganizations = [];
      _sectorColumnName = '';
      _subsectorColumnName = '';
      _organizationColumnName = '';
      _dynamicFilters.clear();
      _availableDynamicFilters.clear();
      _allColumnNames = [];
      _selectedColumnsToDisplay.clear();
    });
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        availableSectors: _availableSectors,
        availableOrganizations: _availableOrganizations,
        selectedSectors: _selectedSectors,
        selectedOrganizations: _selectedOrganizations,
        sectorColumnName: _sectorColumnName,
        subsectorColumnName: _subsectorColumnName,
        organizationColumnName: _organizationColumnName,
        allColumnNames: _allColumnNames,
        dynamicFilters: _dynamicFilters,
        availableDynamicFilters: _availableDynamicFilters,
        selectedColumnsToDisplay: _selectedColumnsToDisplay,
        onExtractColumn: _extractDynamicColumnValues,
        onApply: (sectors, organizations, dynamicFilters, selectedColumns) {
          setState(() {
            _selectedSectors = sectors;
            _selectedOrganizations = organizations;
            _dynamicFilters = dynamicFilters;
            _selectedColumnsToDisplay = selectedColumns;
          });
          _applyFilters();
        },
        onExtractAndNavigate: (selectedColumn) {
          _extractAndNavigateToFilteredView(selectedColumn);
        },
      ),
    );
  }

  void _extractAndNavigateToFilteredView(String selectedColumn) async {
    // Use filtered data if filters are applied, otherwise use all data
    List<Map<String, dynamic>> dataToUse = _filteredData.isNotEmpty
        ? _filteredData
        : _jsonData;

    if (dataToUse.isEmpty) {
      _showError('No data available');
      return;
    }

    // Find item name column (if exists)
    String? itemNameColumn;
    for (var col in _allColumnNames) {
      if (col.toLowerCase().contains('item') ||
          col.toLowerCase().contains('name')) {
        itemNameColumn = col;
        break;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredDataViewPage(
          filteredData: dataToUse,
          allColumnNames: _allColumnNames,
          selectedColumnsToDisplay: _selectedColumnsToDisplay,
          sectorColumnName: _sectorColumnName,
          subsectorColumnName: _subsectorColumnName.isNotEmpty
              ? _subsectorColumnName
              : null,
          organizationColumnName: _organizationColumnName,
          // itemNameColumnName: itemNameColumn,
          // selectedDataColumn: selectedColumn,
        ),
      ),
    );
  }

  int _getTotalActiveFilters() {
    int count = _selectedSectors.length + _selectedOrganizations.length;
    for (var values in _dynamicFilters.values) {
      count += values.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    int displayedRows = _displayCsvData.length > 0
        ? _displayCsvData.length - 1
        : 0;
    int totalActiveFilters = _getTotalActiveFilters();
    int totalPages = (_totalFilteredRows / _rowsPerPage).ceil();
    int startRow = _currentPage * _rowsPerPage + 1;
    int endRow = (_currentPage + 1) * _rowsPerPage;
    if (endRow > _totalFilteredRows) endRow = _totalFilteredRows;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Data Processor'),
        actions: [
          if (_jsonData.isNotEmpty && !_isLoading)
            IconButton(
              onPressed: _showFilterDialog,
              icon: Badge(
                label: Text('$totalActiveFilters'),
                isLabelVisible: totalActiveFilters > 0,
                child: const Icon(Icons.filter_list),
              ),
              tooltip: 'Filter Data',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Pick Excel File'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _fileName != null && !_isLoading
                          ? _clearData
                          : null,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'File: $_fileName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                if (_sheetNames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Select Sheet: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedSheet,
                        items: _sheetNames
                            .map(
                              (sheet) => DropdownMenuItem(
                                value: sheet,
                                child: Text(sheet),
                              ),
                            )
                            .toList(),
                        onChanged: _isLoading ? null : _onSheetChanged,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(),

          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isLoading && _displayCsvData.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          'Showing $startRow-$endRow of $_totalFilteredRows records (Page ${_currentPage + 1} of $totalPages)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (totalActiveFilters > 0 ||
                            _selectedColumnsToDisplay.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                ..._selectedSectors.map(
                                  (s) => Chip(
                                    label: Text('$_sectorColumnName: $s'),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedSectors.remove(s);
                                      });
                                      _applyFilters();
                                    },
                                  ),
                                ),
                                ..._selectedOrganizations.map(
                                  (o) => Chip(
                                    label: Text('$_organizationColumnName: $o'),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedOrganizations.remove(o);
                                      });
                                      _applyFilters();
                                    },
                                  ),
                                ),
                                ..._dynamicFilters.entries.expand((entry) {
                                  return entry.value.map(
                                    (value) => Chip(
                                      label: Text('${entry.key}: $value'),
                                      onDeleted: () {
                                        setState(() {
                                          _dynamicFilters[entry.key]!.remove(
                                            value,
                                          );
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                  );
                                }),
                                if (_selectedColumnsToDisplay.isNotEmpty)
                                  Chip(
                                    label: Text(
                                      'Columns: ${_selectedColumnsToDisplay.length} selected',
                                    ),
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: _displayCsvData[0]
                              .map(
                                (header) => DataColumn(
                                  label: Text(
                                    header.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          rows: _displayCsvData
                              .skip(1)
                              .map(
                                (row) => DataRow(
                                  cells: row
                                      .map(
                                        (cell) =>
                                            DataCell(Text(cell.toString())),
                                      )
                                      .toList(),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_totalFilteredRows > _rowsPerPage)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0 ? _previousPage : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 8),
                          ...List.generate(totalPages > 7 ? 7 : totalPages, (
                            index,
                          ) {
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ElevatedButton(
                                onPressed: () => _goToPage(pageNumber),
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
                            onPressed:
                                (_currentPage + 1) * _rowsPerPage <
                                    _totalFilteredRows
                                ? _nextPage
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          if (!_isLoading &&
              _displayCsvData.isEmpty &&
              _jsonData.isNotEmpty &&
              totalActiveFilters > 0)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_alt_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No data matches the selected filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isLoading && _displayCsvData.isEmpty && _fileName == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No file selected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload an Excel file to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== FILTER DIALOG - ENHANCED ====================
class FilterDialog extends StatefulWidget {
  final List<String> availableSectors;
  final List<String> availableOrganizations;
  final Set<String> selectedSectors;
  final Set<String> selectedOrganizations;
  final String sectorColumnName;
  final String subsectorColumnName;
  final String organizationColumnName;
  final List<String> allColumnNames;
  final Map<String, Set<String>> dynamicFilters;
  final Map<String, List<String>> availableDynamicFilters;
  final Set<String> selectedColumnsToDisplay;
  final Function(String) onExtractColumn;
  final Function(
    Set<String>,
    Set<String>,
    Map<String, Set<String>>,
    Set<String>,
  )
  onApply;
  final Function(String)? onExtractAndNavigate;

  const FilterDialog({
    super.key,
    required this.availableSectors,
    required this.availableOrganizations,
    required this.selectedSectors,
    required this.selectedOrganizations,
    required this.sectorColumnName,
    required this.subsectorColumnName,
    required this.organizationColumnName,
    required this.allColumnNames,
    required this.dynamicFilters,
    required this.availableDynamicFilters,
    required this.selectedColumnsToDisplay,
    required this.onExtractColumn,
    required this.onApply,
    this.onExtractAndNavigate,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Set<String> _tempSelectedSectors;
  late Set<String> _tempSelectedOrganizations;
  late Map<String, Set<String>> _tempDynamicFilters;
  late Set<String> _tempSelectedColumnsToDisplay;
  String _sectorSearch = '';
  String _orgSearch = '';
  Map<String, String> _dynamicSearches = {};

  @override
  void initState() {
    super.initState();
    _tempSelectedSectors = Set<String>.from(widget.selectedSectors);
    _tempSelectedOrganizations = Set<String>.from(widget.selectedOrganizations);
    _tempDynamicFilters = Map<String, Set<String>>.from(
      widget.dynamicFilters.map(
        (key, value) => MapEntry(key, Set<String>.from(value)),
      ),
    );
    _tempSelectedColumnsToDisplay = Set<String>.from(
      widget.selectedColumnsToDisplay,
    );
  }

  void _addDynamicFilter() {
    showDialog(
      context: context,
      builder: (context) => _ColumnSelectionDialog(
        availableColumns: widget.allColumnNames,
        alreadySelectedColumns: _tempDynamicFilters.keys.toList(),
        organizationColumnName: widget.organizationColumnName,
        onSelect: (columnName) {
          widget.onExtractColumn(columnName);
          setState(() {
            _tempDynamicFilters[columnName] = <String>{};
            _dynamicSearches[columnName] = '';
          });
        },
      ),
    );
  }

  void _removeDynamicFilter(String columnName) {
    setState(() {
      _tempDynamicFilters.remove(columnName);
      _dynamicSearches.remove(columnName);
    });
  }

  void _showColumnSelector() {
    showDialog(
      context: context,
      builder: (context) => _DisplayColumnSelectorDialog(
        allColumns: widget.allColumnNames,
        selectedColumns: _tempSelectedColumnsToDisplay,
        organizationColumnName: widget.organizationColumnName,
        onApply: (selectedColumns) {
          setState(() {
            _tempSelectedColumnsToDisplay = selectedColumns;
          });
        },
      ),
    );
  }

  void _viewFilteredData() {
    Navigator.pop(context); // Close filter dialog
    if (widget.onExtractAndNavigate != null) {
      widget.onExtractAndNavigate!(
        '',
      ); // Empty string means view all filtered data
    }
  }

  // void _showExtractDataDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => _ExtractDataDialog(
  //       allColumns: widget.allColumnNames,
  //       onExtract: (selectedColumn) {
  //         Navigator.pop(context); // Close filter dialog
  //         if (widget.onExtractAndNavigate != null) {
  //           widget.onExtractAndNavigate!(selectedColumn);
  //         }
  //       },
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    List<String> filteredSectors = widget.availableSectors
        .where((s) => s.toLowerCase().contains(_sectorSearch.toLowerCase()))
        .toList();

    List<String> filteredOrgs = widget.availableOrganizations
        .where((o) => o.toLowerCase().contains(_orgSearch.toLowerCase()))
        .toList();

    int tabCount = 2 + _tempDynamicFilters.length;

    return Dialog(
      child: Container(
        width: 700,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Data',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _viewFilteredData,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Filtered Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showColumnSelector,
                      icon: const Icon(Icons.view_column, size: 18),
                      label: Text(
                        'Columns (${_tempSelectedColumnsToDisplay.length})',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addDynamicFilter,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Filter'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: DefaultTabController(
                length: tabCount,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(
                          text: widget.sectorColumnName.isNotEmpty
                              ? widget.sectorColumnName
                              : 'Sector',
                        ),
                        Tab(
                          text: widget.organizationColumnName.isNotEmpty
                              ? widget.organizationColumnName
                              : 'Organization',
                        ),
                        ..._tempDynamicFilters.keys.map((columnName) {
                          return Tab(
                            child: Row(
                              children: [
                                Text(columnName),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _removeDynamicFilter(columnName),
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildFilterTab(
                            searchHint: 'Search sectors...',
                            searchValue: _sectorSearch,
                            onSearchChanged: (val) =>
                                setState(() => _sectorSearch = val),
                            items: filteredSectors,
                            selectedItems: _tempSelectedSectors,
                            onToggle: (item) {
                              setState(() {
                                if (_tempSelectedSectors.contains(item)) {
                                  _tempSelectedSectors.remove(item);
                                } else {
                                  _tempSelectedSectors.add(item);
                                }
                              });
                            },
                            onSelectAll: () {
                              setState(() {
                                _tempSelectedSectors.addAll(filteredSectors);
                              });
                            },
                            onClearAll: () {
                              setState(() {
                                _tempSelectedSectors.clear();
                              });
                            },
                          ),
                          _buildFilterTab(
                            searchHint: 'Search organizations...',
                            searchValue: _orgSearch,
                            onSearchChanged: (val) =>
                                setState(() => _orgSearch = val),
                            items: filteredOrgs,
                            selectedItems: _tempSelectedOrganizations,
                            onToggle: (item) {
                              setState(() {
                                if (_tempSelectedOrganizations.contains(item)) {
                                  _tempSelectedOrganizations.remove(item);
                                } else {
                                  _tempSelectedOrganizations.add(item);
                                }
                              });
                            },
                            onSelectAll: () {
                              setState(() {
                                _tempSelectedOrganizations.addAll(filteredOrgs);
                              });
                            },
                            onClearAll: () {
                              setState(() {
                                _tempSelectedOrganizations.clear();
                              });
                            },
                          ),
                          ..._tempDynamicFilters.keys.map((columnName) {
                            String searchValue =
                                _dynamicSearches[columnName] ?? '';
                            List<String> availableValues =
                                widget.availableDynamicFilters[columnName] ??
                                [];
                            List<String> filteredValues = availableValues
                                .where(
                                  (v) => v.toLowerCase().contains(
                                    searchValue.toLowerCase(),
                                  ),
                                )
                                .toList();

                            return _buildFilterTab(
                              searchHint: 'Search $columnName...',
                              searchValue: searchValue,
                              onSearchChanged: (val) {
                                setState(() {
                                  _dynamicSearches[columnName] = val;
                                });
                              },
                              items: filteredValues,
                              selectedItems: _tempDynamicFilters[columnName]!,
                              onToggle: (item) {
                                setState(() {
                                  if (_tempDynamicFilters[columnName]!.contains(
                                    item,
                                  )) {
                                    _tempDynamicFilters[columnName]!.remove(
                                      item,
                                    );
                                  } else {
                                    _tempDynamicFilters[columnName]!.add(item);
                                  }
                                });
                              },
                              onSelectAll: () {
                                setState(() {
                                  _tempDynamicFilters[columnName]!.addAll(
                                    filteredValues,
                                  );
                                });
                              },
                              onClearAll: () {
                                setState(() {
                                  _tempDynamicFilters[columnName]!.clear();
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tempSelectedSectors.clear();
                      _tempSelectedOrganizations.clear();
                      for (var key in _tempDynamicFilters.keys) {
                        _tempDynamicFilters[key]!.clear();
                      }
                      _tempSelectedColumnsToDisplay.clear();
                    });
                  },
                  child: const Text('Clear All'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _tempSelectedSectors,
                      _tempSelectedOrganizations,
                      _tempDynamicFilters,
                      _tempSelectedColumnsToDisplay,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String searchHint,
    required String searchValue,
    required Function(String) onSearchChanged,
    required List<String> items,
    required Set<String> selectedItems,
    required Function(String) onToggle,
    required VoidCallback onSelectAll,
    required VoidCallback onClearAll,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${selectedItems.length} selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: onSelectAll,
                    child: const Text('Select All'),
                  ),
                  TextButton(onPressed: onClearAll, child: const Text('Clear')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No items found'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    String item = items[index];
                    bool isSelected = selectedItems.contains(item);
                    return CheckboxListTile(
                      title: Text(item),
                      value: isSelected,
                      onChanged: (val) => onToggle(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ==================== COLUMN SELECTION DIALOG ====================
class _ColumnSelectionDialog extends StatefulWidget {
  final List<String> availableColumns;
  final List<String> alreadySelectedColumns;
  final String organizationColumnName;
  final Function(String) onSelect;

  const _ColumnSelectionDialog({
    required this.availableColumns,
    required this.alreadySelectedColumns,
    required this.organizationColumnName,
    required this.onSelect,
  });

  @override
  State<_ColumnSelectionDialog> createState() => _ColumnSelectionDialogState();
}

class _ColumnSelectionDialogState extends State<_ColumnSelectionDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    List<String> filteredColumns = widget.availableColumns
        .where(
          (col) =>
              !widget.alreadySelectedColumns.contains(col) &&
              col.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return AlertDialog(
      title: const Text('Select Column to Filter'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: const Text(
                'Select any column to add as a filter',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search columns...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredColumns.isEmpty
                  ? const Center(child: Text('No columns available'))
                  : ListView.builder(
                      itemCount: filteredColumns.length,
                      itemBuilder: (context, index) {
                        String columnName = filteredColumns[index];
                        return ListTile(
                          title: Text(columnName),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () {
                            widget.onSelect(columnName);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ==================== DISPLAY COLUMN SELECTOR DIALOG ====================
class _DisplayColumnSelectorDialog extends StatefulWidget {
  final List<String> allColumns;
  final Set<String> selectedColumns;
  final String organizationColumnName;
  final Function(Set<String>) onApply;

  const _DisplayColumnSelectorDialog({
    required this.allColumns,
    required this.selectedColumns,
    required this.organizationColumnName,
    required this.onApply,
  });

  @override
  State<_DisplayColumnSelectorDialog> createState() =>
      _DisplayColumnSelectorDialogState();
}

class _DisplayColumnSelectorDialogState
    extends State<_DisplayColumnSelectorDialog> {
  late Set<String> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = Set<String>.from(widget.selectedColumns);
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredColumns = widget.allColumns
        .where((col) => col.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Select Columns to Display'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select columns to display in the table',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'If no columns are selected, all columns will be shown',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search columns...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_tempSelected.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _tempSelected.addAll(filteredColumns);
                          });
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _tempSelected.clear();
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredColumns.isEmpty
                  ? const Center(child: Text('No columns available'))
                  : ListView.builder(
                      itemCount: filteredColumns.length,
                      itemBuilder: (context, index) {
                        String columnName = filteredColumns[index];
                        bool isSelected = _tempSelected.contains(columnName);
                        return CheckboxListTile(
                          title: Text(columnName),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (isSelected) {
                                _tempSelected.remove(columnName);
                              } else {
                                _tempSelected.add(columnName);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_tempSelected);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ==================== FILTERED DATA VIEW PAGE ====================

// ==================== FILTERED DATA VIEW PAGE - UPDATED ====================
class FilteredDataViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> filteredData;
  final String sectorColumnName;
  final String? subsectorColumnName;
  final String organizationColumnName;
  final Set<String> selectedColumnsToDisplay;
  final List<String> allColumnNames;

  const FilteredDataViewPage({
    super.key,
    required this.filteredData,
    required this.sectorColumnName,
    this.subsectorColumnName,
    required this.organizationColumnName,
    required this.selectedColumnsToDisplay,
    required this.allColumnNames,
  });

  @override
  State<FilteredDataViewPage> createState() => _FilteredDataViewPageState();
}

class _FilteredDataViewPageState extends State<FilteredDataViewPage> {
  List<List<dynamic>> _displayData = [];
  int _currentPage = 0;
  final int _rowsPerPage = 100;
  late Set<String> _selectedColumns;

  @override
  void initState() {
    super.initState();
    _selectedColumns = Set<String>.from(widget.selectedColumnsToDisplay);
    _prepareDisplayData();
  }

  void _prepareDisplayData() {
    // Determine which columns to display
    List<String> headers = [];

    if (_selectedColumns.isEmpty) {
      // Show all columns if none selected
      headers = widget.filteredData.isNotEmpty
          ? widget.filteredData[0].keys.toList()
          : [];
    } else {
      // Show only selected columns
      headers = widget.filteredData.isNotEmpty
          ? widget.filteredData[0].keys
                .where((key) => _selectedColumns.contains(key))
                .toList()
          : [];
    }

    List<List<dynamic>> data = [headers];

    for (var row in widget.filteredData) {
      List<dynamic> rowData = headers
          .map((header) => row[header]?.toString() ?? '')
          .toList();
      data.add(rowData);
    }

    setState(() {
      _displayData = data;
    });
  }

  void _showColumnSelector() {
    showDialog(
      context: context,
      builder: (context) => _ColumnSelectorDialog(
        allColumns: widget.allColumnNames,
        selectedColumns: _selectedColumns,
        onApply: (selectedColumns) {
          setState(() {
            _selectedColumns = selectedColumns;
            _currentPage = 0;
          });
          _prepareDisplayData();
        },
      ),
    );
  }

  void _nextPage() {
    if ((_currentPage + 1) * _rowsPerPage < _displayData.length - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _storeData() async {
    // Show year selection dialog
    await _showYearSelectionDialog();
  }

  Future<void> _showYearSelectionDialog() async {
    if (widget.filteredData.isEmpty) {
      _showError('No data to store');
      return;
    }

    // Detect year columns
    List<String> yearColumns = FinancialDataExtractor.detectYearColumns(
      widget.filteredData,
    );

    if (yearColumns.isEmpty) {
      _showError('No year columns found in the data');
      return;
    }

    // Detect item name column
    String? itemNameColumn = FinancialDataExtractor.detectItemNameColumn(
      widget.filteredData,
    );

    if (itemNameColumn == null) {
      _showError('Could not detect item name column');
      return;
    }

    // Show dialog to select years
    Set<String> selectedYears = {};

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Years to Store'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue.shade50,
                    child: const Text(
                      'Select which years you want to extract and store',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedYears.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedYears.addAll(yearColumns);
                              });
                            },
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedYears.clear();
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: yearColumns.length,
                      itemBuilder: (context, index) {
                        String year = yearColumns[index];
                        bool isSelected = selectedYears.contains(year);
                        return CheckboxListTile(
                          title: Text(year),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (isSelected) {
                                selectedYears.remove(year);
                              } else {
                                selectedYears.add(year);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedYears.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Store Data'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && selectedYears.isNotEmpty) {
      // Extract and store the data
      try {
        List<FinancialDataEntry> entries =
            FinancialDataExtractor.extractFinancialData(
              filteredData: widget.filteredData,
              organizationColumnName: widget.organizationColumnName,
              itemNameColumn: itemNameColumn,
              yearColumns: selectedYears.toList(),
              sectorColumnName: widget.sectorColumnName,
            );

        if (entries.isEmpty) {
          _showError(
            'No data could be extracted. Please check if the data format is correct.',
          );
          return;
        }

        // Store in provider
        context.read<FinancialDataProvider>().addMultipleEntries(entries);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully stored ${entries.length} entries'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoredDataViewPage(),
                  ),
                );
              },
            ),
          ),
        );
      } catch (e) {
        _showError('Error storing data: $e');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalRows = _displayData.length - 1;
    int totalPages = (totalRows / _rowsPerPage).ceil();
    int startRow = _currentPage * _rowsPerPage + 1;
    int endRow = (_currentPage + 1) * _rowsPerPage;
    if (endRow > totalRows) endRow = totalRows;

    int startIndex = _currentPage * _rowsPerPage + 1;
    int endIndex = startIndex + _rowsPerPage;
    if (endIndex > _displayData.length) endIndex = _displayData.length;

    List<List<dynamic>> pageData = _displayData.isEmpty
        ? []
        : _displayData.sublist(0, 1) +
              _displayData.sublist(startIndex, endIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtered Data View'),

        actions: [
          IconButton(
            onPressed: _showColumnSelector,
            icon: Badge(
              label: Text('${_selectedColumns.length}'),
              isLabelVisible: _selectedColumns.isNotEmpty,
              child: const Icon(Icons.view_column),
            ),
            tooltip: 'Select Columns',
          ),
          IconButton(
            onPressed: _storeData,
            icon: const Icon(Icons.save),
            tooltip: 'Store Data',
          ),
          // Add button to view stored data
          Consumer<FinancialDataProvider>(
            builder: (context, provider, child) {
              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoredDataViewPage(),
                    ),
                  );
                },
                icon: Badge(
                  label: Text('${provider.totalEntries}'),
                  isLabelVisible: provider.totalEntries > 0,
                  child: const Icon(Icons.storage),
                ),
                tooltip: 'View Stored Data (${provider.totalEntries})',
              );
            },
          ),
        ],

        // actions: [
        //   IconButton(
        //     onPressed: _showColumnSelector,
        //     icon: Badge(
        //       label: Text('${_selectedColumns.length}'),
        //       isLabelVisible: _selectedColumns.isNotEmpty,
        //       child: const Icon(Icons.view_column),
        //     ),
        //     tooltip: 'Select Columns',
        //   ),
        //   IconButton(
        //     onPressed: _storeData,
        //     icon: const Icon(Icons.save),
        //     tooltip: 'Store Data',
        //   ),
        // ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing filtered data',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Total Records: $totalRows',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    if (_selectedColumns.isNotEmpty)
                      Text(
                        'Displaying ${_selectedColumns.length} of ${widget.allColumnNames.length} columns',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Data'),
                ),
                Text(
                  'Showing $startRow-$endRow of $totalRows records (Page ${_currentPage + 1} of $totalPages)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _storeData,
                  icon: const Icon(Icons.save),
                  label: const Text('Store Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _displayData.isEmpty
                ? const Center(child: Text('No data to display'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: pageData[0]
                            .map(
                              (header) => DataColumn(
                                label: Text(
                                  header.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        rows: pageData
                            .skip(1)
                            .map(
                              (row) => DataRow(
                                cells: row
                                    .map(
                                      (cell) => DataCell(Text(cell.toString())),
                                    )
                                    .toList(),
                              ),
                            )
                            .toList(),
                        headingRowColor: WidgetStateProperty.all(
                          Colors.blue.shade100,
                        ),
                      ),
                    ),
                  ),
          ),
          if (totalRows > _rowsPerPage)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 0 ? _previousPage : null,
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
                        onPressed: () => _goToPage(pageNumber),
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
                    onPressed: (_currentPage + 1) * _rowsPerPage < totalRows
                        ? _nextPage
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== COLUMN SELECTOR DIALOG FOR FILTERED VIEW ====================
class _ColumnSelectorDialog extends StatefulWidget {
  final List<String> allColumns;
  final Set<String> selectedColumns;
  final Function(Set<String>) onApply;

  const _ColumnSelectorDialog({
    required this.allColumns,
    required this.selectedColumns,
    required this.onApply,
  });

  @override
  State<_ColumnSelectorDialog> createState() => _ColumnSelectorDialogState();
}

class _ColumnSelectorDialogState extends State<_ColumnSelectorDialog> {
  late Set<String> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = Set<String>.from(widget.selectedColumns);
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredColumns = widget.allColumns
        .where((col) => col.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Select Columns to Display'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select columns to display in the table',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'If no columns are selected, all columns will be shown',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search columns...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_tempSelected.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _tempSelected.addAll(filteredColumns);
                          });
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _tempSelected.clear();
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredColumns.isEmpty
                  ? const Center(child: Text('No columns available'))
                  : ListView.builder(
                      itemCount: filteredColumns.length,
                      itemBuilder: (context, index) {
                        String columnName = filteredColumns[index];
                        bool isSelected = _tempSelected.contains(columnName);
                        return CheckboxListTile(
                          title: Text(columnName),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (isSelected) {
                                _tempSelected.remove(columnName);
                              } else {
                                _tempSelected.add(columnName);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_tempSelected);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
