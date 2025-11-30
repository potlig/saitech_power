import 'dart:async';
import 'dart:convert';
import 'package:energy_and_power_monitor/widgets/Appbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, Map<String, List<Map<String, dynamic>>>> categorizedData = {};
  Set<String> favoriteCategories = {};
  bool isLoading = true;
  String? errorMessage;
  Timer? _timer;

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
      favoriteCategories = favList.toSet();
    });
  }

  Future<String?> getSelectedDeviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("selectedDeviceCode");
  }

  // ✅ Added: Check device online/offline status before fetching data
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
    } catch (_) {
      // fail silently, assume online
    }
    return true;
  }

  Future<void> fetchVariables({bool showLoader = true}) async {
    var arduinoCode = await getSelectedDeviceCode();

    // ✅ Handle no selected device
    if (arduinoCode == null) {
      if (!mounted) return;
      setState(() {
        categorizedData.clear();
        errorMessage = "Please select a device first in Device Management.";
        isLoading = false;
      });
      return;
    }

    // ✅ Check device online/offline
    bool isOnline = await _checkDeviceStatus(arduinoCode);
    if (!isOnline) {
      if (!mounted) return;
      setState(() {
        categorizedData.clear();
        errorMessage = "Device is currently offline.";
        isLoading = false;
      });
      return;
    }

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

        final Map<String, Map<String, List<Map<String, dynamic>>>> parsed = {};

        data.forEach((category, value) {
          final subcats = <String, List<Map<String, dynamic>>>{};

          if (value is Map) {
            value.forEach((key, val) {
              if (val is Map &&
                  val.containsKey("value") &&
                  val.containsKey("unit")) {
                subcats.putIfAbsent("", () => []).add({
                  "key": key,
                  "value": val["value"],
                  "unit": val["unit"],
                });
              } else if (val is num || val is String) {
                subcats.putIfAbsent("", () => []).add({
                  "key": key,
                  "value": val,
                  "unit": "",
                });
              } else if (val is Map) {
                subcats[key] = [];
                val.forEach((subKey, subVal) {
                  subcats[key]!.add({
                    "key": subKey,
                    "value": subVal is Map && subVal.containsKey("value")
                        ? subVal["value"]
                        : subVal,
                    "unit": subVal is Map && subVal.containsKey("unit")
                        ? subVal["unit"]
                        : "",
                  });
                });
              }
            });
          }

          if (subcats.containsKey("") && subcats.length > 1) {
            subcats["General"] = subcats.remove("")!;
          }

          if (subcats.isNotEmpty) parsed[category] = subcats;
        });

        if (!mounted) return;
        setState(() {
          categorizedData = parsed;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = "No Internet Connection";
        isLoading = false;
      });
    }
  }

  Map<String, Map<String, List<Map<String, dynamic>>>>
      _getCategorizedFavorites() {
    final filtered = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (var fav in favoriteCategories) {
      if (categorizedData.containsKey(fav)) {
        filtered[fav] = categorizedData[fav]!;
      }
    }
    return filtered;
  }

  IconData _getIconForMetric(String key) {
    if (key.contains("current")) return Icons.power;
    if (key.contains("voltage")) return Icons.bolt;
    if (key == "power") return Icons.electric_bolt;
    if (key.contains("power_factor")) return Icons.show_chart;
    if (key.contains("frequency")) return Icons.wifi;
    if (key == "thd") return Icons.device_thermostat;
    if (key.contains("harmonic")) return Icons.auto_awesome;
    if (key.contains("max")) return Icons.arrow_upward;
    if (key.contains("min")) return Icons.arrow_downward;
    return Icons.device_unknown;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = _getCategorizedFavorites();

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
                                : errorMessage == "No Internet Connection"
                                    ? Icons.wifi_off
                                    : Icons.error_outline,
                        size: 60,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(errorMessage!,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => fetchVariables(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : favorites.isEmpty
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
                            "No categories chosen.\nGo to All Variables and star a category.",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: favorites.entries.length,
                      separatorBuilder: (_, __) => const Divider(
                        thickness: 0.5,
                        height: 1,
                        color: Colors.grey,
                      ),
                      itemBuilder: (context, index) {
                        final entry = favorites.entries.elementAt(index);
                        final category = entry.key;
                        final subcats = entry.value;

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
                              tilePadding: EdgeInsets.zero,
                              title: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              children: subcats.entries.map((sub) {
                                final subcat = sub.key;
                                final metrics = sub.value;

                                if (subcat.isEmpty) {
                                  return _buildMetricsList(metrics, theme);
                                }

                                return ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  title: Text(subcat,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  children: [_buildMetricsList(metrics, theme)],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildMetricsList(
      List<Map<String, dynamic>> metrics, ThemeData theme) {
    final clr = theme.colorScheme.primary;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: metrics.length,
      separatorBuilder: (_, __) => const Divider(
        thickness: 0.5,
        height: 1,
        color: Colors.black26,
      ),
      itemBuilder: (context, i) {
        final key = metrics[i]["key"] ?? "";
        final val = metrics[i]["value"];
        final unit = metrics[i]["unit"] ?? "";
        final valueStr = (val is num) ? val.toStringAsFixed(3) : val.toString();

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(_getIconForMetric(key), color: clr),
          title: Text(
            key,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            unit.isNotEmpty ? "$valueStr $unit" : valueStr,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
          ),
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        );
      },
    );
  }
}
