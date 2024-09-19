import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:volume_control/volume_control.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Configure the background service
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // This will run the task in the background even after app is closed
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      // iOS configuration (you can customize this)
      onForeground: onStart,
      autoStart: true,
    ),
  );

  // Start the service
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      // If the service is stopped by the user, stop the task
      if (await service.isForegroundService() == false) {
        timer.cancel();
        return;
      }
    }

    // Perform the Wi-Fi monitoring and volume adjustment
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedWifi = prefs.getString('selected_wifi');

    ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.wifi) {
      String? currentSsid = await WiFiForIoTPlugin.getSSID();
      if (currentSsid == savedWifi) {
        // Lower volume when connected to the saved Wi-Fi
        VolumeControl.setVolume(0.2);
      } else {
        // Restore volume when not connected to the saved Wi-Fi
        VolumeControl.setVolume(1.0);
      }
    } else {
      // Restore full volume when disconnected from Wi-Fi
      VolumeControl.setVolume(1.0);
    }
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WifiSelector(),
    );
  }
}

class WifiSelector extends StatefulWidget {
  @override
  _WifiSelectorState createState() => _WifiSelectorState();
}

class _WifiSelectorState extends State<WifiSelector> {
  List<WifiNetwork> _wifiList = [];
  String? _selectedWifi;

  @override
  void initState() {
    super.initState();
    _loadSavedWifi();
    _scanWifiNetworks();
  }

  Future<void> _loadSavedWifi() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedWifi = prefs.getString('selected_wifi');
    });
  }

  Future<void> _scanWifiNetworks() async {
    List<WifiNetwork>? networks = await WiFiForIoTPlugin.loadWifiList();
    setState(() {
      _wifiList = networks ?? [];
    });
  }

  Future<void> _saveSelectedWifi(String ssid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_wifi', ssid);
    setState(() {
      _selectedWifi = ssid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Wi-Fi')),
      body: _wifiList.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _wifiList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_wifiList[index].ssid ?? 'Unknown SSID'),
                  trailing: _selectedWifi == _wifiList[index].ssid
                      ? Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    _saveSelectedWifi(_wifiList[index].ssid!);
                  },
                );
              },
            ),
    );
  }
}
