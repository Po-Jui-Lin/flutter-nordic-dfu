import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_nordic_dfu/flutter_nordic_dfu.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  bool dfuRunning = false;
  int dfuRunningInx;

  @override
  void initState() {
    super.initState();
  }

  Future<void> doDfu(String deviceId) async {
    stopScan();
    dfuRunning = true;
    try {
      final s = await FlutterNordicDfu.startDfu(
        deviceId,
        'assets/ultron_door_pkg.zip',
        fileInAsset: true,
        progressListener:
            DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
          deviceAddress,
          percent,
          speed,
          avgSpeed,
          currentPart,
          partsTotal,
        ) {
          debugPrint('deviceAddress: $deviceAddress, percent: $percent');
        }),
      );
      debugPrint(s);
      dfuRunning = false;
    } catch (e) {
      dfuRunning = false;
      debugPrint(e.toString());
    }
  }

  void startScan() {
    scanSubscription?.cancel();
    setState(() {
      scanResults.clear();
      scanSubscription = flutterBlue.scan().listen(
        (scanResult) {
          if (scanResults.firstWhere(
                  (ele) => ele.device.id == scanResult.device.id,
                  orElse: () => null) !=
              null) {
            return;
          }

          debugPrint(scanResult.toString());

          setState(() {
            /// add result to results if not added
            scanResults.add(scanResult);
          });
        },
      );
    });
  }

  void stopScan() {
    scanSubscription?.cancel();
    scanSubscription = null;
    setState(() => scanSubscription = null);
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = scanSubscription != null;
    final hasDevice = scanResults.isNotEmpty;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: <Widget>[
            isScanning
                ? IconButton(
                    icon: const Icon(Icons.pause_circle_filled),
                    onPressed: dfuRunning ? null : stopScan,
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: dfuRunning ? null : startScan,
                  )
          ],
        ),
        // todo: remove this reversed logic?
        body: !hasDevice
            ? const Center(
                child: Text('No device'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemBuilder: _deviceItemBuilder,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemCount: scanResults.length,
              ),
      ),
    );
  }

  Widget _deviceItemBuilder(BuildContext context, int index) {
    final result = scanResults[index];
    return DeviceItem(
      isRunningItem: dfuRunningInx == null ? false : dfuRunningInx == index,
      scanResult: result,
      onPress: dfuRunning
          ? () async {
              await FlutterNordicDfu.abortDfu();
              setState(() {
                dfuRunningInx = null;
              });
            }
          : () async {
              setState(() {
                dfuRunningInx = index;
              });
              await this.doDfu(result.device.id.id);
              setState(() {
                dfuRunningInx = null;
              });
            },
    );
  }
}

class ProgressListenerListener extends DfuProgressListenerAdapter {
  @override
  void onProgressChanged(String deviceAddress, int percent, double speed,
      double avgSpeed, int currentPart, int partsTotal) {
    super.onProgressChanged(
        deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal);
    debugPrint('deviceAddress: $deviceAddress, percent: $percent');
  }
}

class DeviceItem extends StatelessWidget {
  final ScanResult scanResult;

  final VoidCallback onPress;

  final bool isRunningItem;

  const DeviceItem({this.scanResult, this.onPress, this.isRunningItem});

  @override
  Widget build(BuildContext context) {
    var name = "Unknow";
    if (scanResult.device.name != null && scanResult.device.name.isNotEmpty) {
      name = scanResult.device.name;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: <Widget>[
            const Icon(Icons.bluetooth),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name),
                  Text(scanResult.device.id.id),
                  Text("RSSI: ${scanResult.rssi}"),
                ],
              ),
            ),
            TextButton(
                onPressed: onPress,
                child: isRunningItem
                    ? const Text("Abort Dfu")
                    : const Text("Start Dfu"))
          ],
        ),
      ),
    );
  }
}
