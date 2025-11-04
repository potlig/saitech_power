import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:energy_and_power_monitor/widgets/Appbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class AllVariablesPage extends StatefulWidget {
  const AllVariablesPage({super.key});

  @override
  State<AllVariablesPage> createState() => _AllVariablesPageState();
}

class _AllVariablesPageState extends State<AllVariablesPage> {
  Map<String, Map<String, List<Map<String, String>>>> variables = {};
  Set<String> favorites = {};
  bool isLoading = true;
  String? errorMessage;
  Timer? _timer;

  final Map<String, IconData> unitIcons = {
    "current": Icons.power,
    "voltage": Icons.bolt,
    "power": Icons.electric_bolt,
    "power_factor": Icons.show_chart,
    "frequency": Icons.wifi,
    "thd": Icons.bar_chart,
    "harmonics": Icons.graphic_eq,
    "max": Icons.arrow_upward,
    "min": Icons.arrow_downward,
    "energy": Icons.battery_full,
    "demand": Icons.trending_up,
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    fetchVariables();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchVariables(showLoader: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList("favoriteCategories") ?? [];
    if (!mounted) return;
    setState(() {
      favorites = favList.toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("favoriteCategories", favorites.toList());
  }

  Future<String?> getSelectedDeviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("selectedDeviceCode");
  }

  Future<bool> _checkDeviceStatus(String arduinoCode) async {
    try {
      final url =
          "http://m77.29f.mytemp.website/device_status.php?codes=$arduinoCode";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success" && data["devices"] is List) {
          final device = (data["devices"] as List).firstWhere(
            (d) => d["arduino_code"] == arduinoCode,
            orElse: () => null,
          );
          if (device != null && device["status"] == "offline") {
            return false;
          }
        }
      }
    } catch (e) {
      developer.log("Device status check failed: $e");
    }
    return true; // default assume online
  }

  Future<void> fetchVariables({bool showLoader = true}) async {
    var arduinoCode = await getSelectedDeviceCode();

    if (arduinoCode == null) {
      if (!mounted) return;
      setState(() {
        variables.clear();
        errorMessage = "Please select a device first in Device Management.";
        isLoading = false;
      });
      return;
    }

    // ✅ Check device status before fetching
    bool isOnline = await _checkDeviceStatus(arduinoCode);
    if (!isOnline) {
      if (!mounted) return;
      setState(() {
        variables.clear();
        errorMessage = "Device is currently offline.";
        isLoading = false;
      });
      return;
    }

    developer.log("Fetching with device code: $arduinoCode");
    var url =
        "http://m77.29f.mytemp.website/fetch_all_parameters.php?arduino_code=$arduinoCode";

    if (showLoader) {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final grouped = <String, Map<String, List<Map<String, String>>>>{};

        data.forEach((categoryName, section) {
          final subcategories = <String, List<Map<String, String>>>{};

          void parseMap(String prefix, Map<dynamic, dynamic> map) {
            map.forEach((key, value) {
              final currentPath =
                  prefix.isEmpty ? key : "$prefix/$key";

              if (value is Map &&
                  value.containsKey("value") &&
                  value.containsKey("unit")) {
                final subcat = prefix.isEmpty ? "" : prefix;
                subcategories.putIfAbsent(subcat, () => []).add({
                  "unit": key,
                  "value": "${value['value']} ${value['unit']}",
                });
              } else if (value is Map) {
                parseMap(currentPath, value);
              } else {
                final subcat = prefix.isEmpty ? "" : prefix;
                subcategories.putIfAbsent(subcat, () => []).add({
                  "unit": key,
                  "value": "$value",
                });
              }
            });
          }

          if (section is Map) parseMap("", section);

          if (subcategories.containsKey("") && subcategories.length > 1) {
            subcategories["General"] = subcategories.remove("")!;
          }

          if (subcategories.keys.length == 1 &&
              subcategories.containsKey("")) {
            subcategories[""] = subcategories.remove("")!;
          }

          if (subcategories.isNotEmpty) grouped[categoryName] = subcategories;
        });

        if (!mounted) return;
        setState(() {
          variables = grouped;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = "Error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } on SocketException {
      if (!mounted) return;
      setState(() {
        errorMessage = "No internet connection";
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Unexpected error occurred";
        isLoading = false;
      });
    }
  }

  IconData _getIconForUnit(String unit) {
    for (var prefix in unitIcons.keys) {
      if (unit.toLowerCase().contains(prefix)) {
        return unitIcons[prefix]!;
      }
    }
    return Icons.device_unknown;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        errorMessage == "Device is currently offline."
                            ? Icons.cloud_off
                            : errorMessage ==
                                    "Please select a device first in Device Management."
                                ? Icons.devices
                                : errorMessage == "No internet connection"
                                    ? Icons.wifi_off
                                    : Icons.error_outline,
                        size: 60,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => fetchVariables(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : variables.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.redAccent,
                          ),
                          Text(
                            "No items to display.\nTry refreshing or select another device.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => fetchVariables(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: variables.entries.length,
                        separatorBuilder: (_, __) => const Divider(
                          thickness: 0.3,
                          height: 1,
                          color: Colors.grey,
                        ),
                        itemBuilder: (context, index) {
                          final entry = variables.entries.elementAt(index);
                          final categoryName = entry.key;
                          final isFavorite =
                              favorites.contains(categoryName);

                          return Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.grey),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(categoryName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                          )),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isFavorite
                                            ? Icons.star
                                            : Icons.star_border,
                                        color:
                                            isFavorite ? Colors.amber : null,
                                      ),
                                      onPressed: () async {
                                        if (!mounted) return;
                                        setState(() {
                                          if (isFavorite) {
                                            favorites.remove(categoryName);
                                          } else {
                                            favorites.add(categoryName);
                                          }
                                        });
                                        await _saveFavorites();
                                      },
                                    ),
                                  ],
                                ),
                                children: entry.value.entries.map((subEntry) {
                                  final subcategory = subEntry.key;
                                  final items = subEntry.value;

                                  Widget listWithSeparators = ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(
                                      thickness: 1,
                                      height: 1,
                                      color: Colors.black12,
                                    ),
                                    itemBuilder: (context, i) {
                                      final unit = items[i]["unit"] ?? "";
                                      final value = items[i]["value"] ?? "";
                                      return ListTile(
                                        leading: Icon(_getIconForUnit(unit)),
                                        title: Text(unit,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        subtitle: Text(value,
                                            style: const TextStyle(
                                                color: Colors.black54)),
                                      );
                                    },
                                  );

                                  if (subcategory.isEmpty) {
                                    return listWithSeparators;
                                  }

                                  return ExpansionTile(
                                    title: Text(subcategory,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    children: [listWithSeparators],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
