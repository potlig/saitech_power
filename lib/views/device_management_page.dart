import 'dart:convert';
import 'dart:async';
import 'package:energy_and_power_monitor/widgets/Appbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Device {
  String name;
  String code;
  bool isStarred;

  Device({required this.name, required this.code, this.isStarred = false});

  Map<String, dynamic> toJson() => {
        "name": name,
        "code": code,
        "isStarred": isStarred,
      };

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      name: json["name"],
      code: json["code"],
      isStarred: json["isStarred"] ?? false,
    );
  }
}

class DeviceManagementPage extends StatelessWidget {
  final ValueChanged<String>? onChangeTitle; // callback for AppBar title

  const DeviceManagementPage({super.key, this.onChangeTitle});

  @override
  Widget build(BuildContext context) {
    // Call the callback to set the default title when page loads
    onChangeTitle?.call("Device Management");

    return Scaffold(
      body: DeviceManagementScreen(onChangeTitle: onChangeTitle),
    );
  }
}

class DeviceManagementScreen extends StatefulWidget {
  final ValueChanged<String>? onChangeTitle;

  const DeviceManagementScreen({super.key, this.onChangeTitle});

  @override
  State<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Device> _devices = [];
  Map<String, String> _deviceStatuses = {}; // deviceCode -> online/offline
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices().then((_) {
      _fetchDeviceStatuses();
      // Auto-refresh statuses every 1 minute
      _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _fetchDeviceStatuses();
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDeviceStatuses() async {
    if (_devices.isEmpty) return;

    final codes = _devices.map((d) => d.code).join(",");
    final url = Uri.parse(
        "http://m77.29f.mytemp.website/device_status.php?codes=$codes");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          setState(() {
            _deviceStatuses = {
              for (var d in data["devices"]) d["arduino_code"]: d["status"]
            };
          });
        }
      }
    } catch (e) {
      print("Error fetching device status: $e");
    }
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceData = prefs.getStringList("devices") ?? [];
    setState(() {
      _devices =
          deviceData.map((d) => Device.fromJson(jsonDecode(d))).toList();
    });
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceData = _devices.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList("devices", deviceData);
  }

  Future<void> _saveSelectedDeviceCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selectedDeviceCode", code);
  }

  void _addOrEditDevice({Device? existingDevice, int? index}) {
    final nameController =
        TextEditingController(text: existingDevice?.name ?? "");
    final codeController =
        TextEditingController(text: existingDevice?.code ?? "");
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(existingDevice == null ? "Add Device" : "Edit Device"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Device Name"),
                  ),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: "Device Code"),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final code = codeController.text.trim();
                    if (name.isEmpty || code.isEmpty) return;

                    // Prevent duplicate name or code
                    final duplicate = _devices.any((d) =>
                        (d.name.toLowerCase() == name.toLowerCase() ||
                            d.code.toLowerCase() == code.toLowerCase()) &&
                        d != existingDevice);

                    if (duplicate) {
                      setDialogState(() {
                        errorMessage = "Device Name or Code already exists!";
                      });
                      return;
                    }

                    setState(() {
                      if (existingDevice == null) {
                        _devices.add(Device(name: name, code: code));
                      } else {
                        _devices[index!] = Device(
                          name: name,
                          code: code,
                          isStarred: existingDevice.isStarred,
                        );
                      }
                    });
                    _saveDevices();
                    Navigator.pop(context);
                    _fetchDeviceStatuses(); // refresh statuses
                  },
                  child: Text(existingDevice == null ? "Add" : "Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteDevice(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content:
            Text("Are you sure you want to delete '${_devices[index].name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();

    if (_devices[index].isStarred) {
      await prefs.remove("selectedDeviceCode");
    }

    setState(() {
      _devices.removeAt(index);
    });
    _saveDevices();
    _fetchDeviceStatuses();
  }

  void _toggleStar(int index) {
    setState(() {
      for (var i = 0; i < _devices.length; i++) {
        _devices[i].isStarred = i == index;
      }
    });
    _saveDevices();
    _saveSelectedDeviceCode(_devices[index].code);

    // Update AppBar title when a device is starred
    widget.onChangeTitle?.call("Selected: ${_devices[index].name}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _devices.isEmpty
          ? const Center(child: Text("No devices added yet."))
          : ListView.separated(
              itemCount: _devices.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, thickness: 0.5, color: Colors.grey),
              itemBuilder: (context, index) {
                final device = _devices[index];
                final status = _deviceStatuses[device.code] ?? "loading";
                final isOnline = status.toLowerCase() == "online";

                return ListTile(
                  leading: IconButton(
                    icon: Icon(
                      device.isStarred
                          ? Icons.star
                          : Icons.star_border_outlined,
                      color: device.isStarred ? Colors.orange : Colors.grey,
                    ),
                    onPressed: () => _toggleStar(index),
                  ),
                  title: Text(device.name),
                  subtitle: Text("Code: ${device.code}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _addOrEditDevice(
                            existingDevice: device, index: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDevice(index),
                      ),
                      const SizedBox(width: 8),
                      if (status != "loading")
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                          ],
                        ),
                      );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditDevice(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Helper function for other pages
Future<String?> getSelectedDeviceCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString("selectedDeviceCode");
}
