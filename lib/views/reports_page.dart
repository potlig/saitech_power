import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:energy_and_power_monitor/widgets/Appbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ReportScreen(),
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<String> _allCategories = [];
  final List<String> _selectedCategories = [];
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = true;
  bool _downloading = false; // ✅ Added for download loading
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      var arduinoCode = await getSelectedDeviceCode();

      if (arduinoCode == null) {
        if (!mounted) return;
        setState(() {
          _error = "Please select a device first in Device Management.";
          _loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
            "http://m77.29f.mytemp.website/fetch_all_parameters.php?arduino_code=$arduinoCode"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic> && data.containsKey("error")) {
          if (!mounted) return;
          setState(() {
            _error = data["error"].toString();
            _loading = false;
          });
          return;
        }

        if (data is Map<String, dynamic>) {
          List<String> categories = [];

          for (var k in data.keys) {
            if (k == "arduino_code" || k == "timestamp") continue;

            if (k == "harmonics" && data["harmonics"] is Map<String, dynamic>) {
              categories.addAll(
                (data["harmonics"] as Map<String, dynamic>)
                    .keys
                    .map((sub) => "HARMONICS ${sub.toUpperCase()}"),
              );
            } else if (k == "thd_current" || k == "thd_voltage") {
              if (!categories.contains("THD")) categories.add("THD");
            } else if (k == "active_power" || k == "reactive_power") {
              continue;
            } else if (k == "apparent_power") {
              categories.add("POWER");
            } else {
              categories.add(k.toString().replaceAll("_", " ").toUpperCase());
            }
          }

          if (categories.isEmpty) {
            if (!mounted) return;
            setState(() {
              _error = "No categories available for this device.";
              _loading = false;
            });
          } else {
            if (!mounted) return;
            setState(() {
              _allCategories = ["ALL", ...categories];
              _loading = false;
            });
          }
        } else {
          if (!mounted) return;
          setState(() {
            _error = "Unexpected response format.";
            _loading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = "Failed to load categories (${response.statusCode})";
          _loading = false;
        });
      }
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _error = "No internet connection";
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Unexpected error: $e";
        _loading = false;
      });
    }
  }

  Future<String?> getSelectedDeviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("selectedDeviceCode");
  }

  Future<File> _downloadFile(String url, String filename) async {
    try {
      developer.log(url);
      var response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Failed to download file");
      }

      Directory dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      File file = File("${dir.path}/$filename");
      await file.writeAsBytes(response.bodyBytes);

      developer.log('Downloaded file path = ${file.path}');
      return file;
    } catch (error) {
      developer.log('File downloading error = $error');
      return File('');
    }
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          if (_toDate != null && picked.isAfter(_toDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("From Date cannot be after To Date."),
              ),
            );
            return;
          }
          _fromDate = picked;
        } else {
          if (_fromDate != null && picked.isBefore(_fromDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("To Date cannot be before From Date."),
              ),
            );
            return;
          }
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _error == "Please select a device first in Device Management."
                  ? Icons.devices
                  : _error == "No internet connection"
                      ? Icons.wifi_off
                      : Icons.error_outline,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _fetchCategories(),
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_allCategories.isEmpty) {
      return const Center(
        child: Text(
          "No categories available.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Categories",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _selectedCategories
                        .map((cat) => Chip(
                              label: Text(cat),
                              onDeleted: () {
                                if (!mounted) return;
                                setState(() {
                                  _selectedCategories.remove(cat);
                                });
                              },
                            ))
                        .toList(),
                  ),
                  DropdownButton<String>(
                    hint: const Text("Add Category"),
                    isExpanded: true,
                    items: _allCategories
                        .where((c) => !_selectedCategories.contains(c))
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: _allCategories.isEmpty
                        ? null
                        : (value) {
                            if (!mounted) return;
                            if (value != null) {
                              setState(() {
                                if (value == "ALL") {
                                  _selectedCategories.clear();
                                  _selectedCategories.addAll(
                                      _allCategories.where((c) => c != "ALL"));
                                } else {
                                  _selectedCategories.add(value);
                                }
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: "From",
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _fromDate != null
                                  ? "${_fromDate!.month}/${_fromDate!.day}/${_fromDate!.year}"
                                  : "mm/dd/yyyy",
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: "To",
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _toDate != null
                                  ? "${_toDate!.month}/${_toDate!.day}/${_toDate!.year}"
                                  : "mm/dd/yyyy",
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (_selectedCategories.isEmpty ||
                            _fromDate == null ||
                            _toDate == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Please select categories and dates.")),
                          );
                          return;
                        }

                        if (_toDate!.isBefore(_fromDate!)) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("To Date cannot be before From Date.")),
                          );
                          return;
                        }

                        String from =
                            "${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}";
                        String to =
                            "${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}";

                        String categories = _selectedCategories.contains("ALL")
                            ? "all"
                            : _selectedCategories
                                .map((c) {
                                  String param =
                                      c.replaceAll(" ", "_").toLowerCase();
                                  if (param == "max") return "max_values";
                                  if (param == "min") return "min_values";
                                  if (param == "power") return "power";
                                  return param;
                                })
                                .join(",");

                        var arduinoCode = await getSelectedDeviceCode();
                        String url =
                            "http://m77.29f.mytemp.website/report_all_parameters.php?arduino_code=$arduinoCode&from=$from&to=$to&categories=$categories";
                        developer.log("Url: $url");

                        DateTime now = DateTime.now();
                        String timestamp =
                            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
                        String filename = "Report-$timestamp.csv";

                        setState(() => _downloading = true); // ✅ Start loading
                        File file = await _downloadFile(url, filename);
                        setState(() => _downloading = false); // ✅ Stop loading

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Report saved at ${file.path}")),
                          );
                        }
                      },
                      child: const Text(
                        "Generate Report",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ✅ Download Loading Overlay
        if (_downloading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    "Downloading report...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
