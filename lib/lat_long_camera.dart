import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'camera_latlong_controller.dart';

import 'location_controller.dart';

class CameraScreen extends StatefulWidget {
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final cameraManager = Get.find<CameraManagerController>();

  final locationController = Get.find<LocationController>();

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();

    _locationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      locationController.getUserLocation();
    });

  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera')),
      body: Obx(() {
        if (!cameraManager.isCameraInitialized.value ||
            cameraManager.cameraController == null) {
          return Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            CameraPreview(cameraManager.cameraController!),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  locationController.latitude.value == 0.0
                      ? Text('fetching lat.', style: TextStyle(color: Colors.white, fontSize: 16))
                      : Text('Lat: ${locationController.latitude.value}', style: TextStyle(color: Colors.white, fontSize: 16)),

                  locationController.longitude.value == 0.0
                      ? Text('fetching lng.', style: TextStyle(color: Colors.white, fontSize: 16))
                      : Text('Lng: ${locationController.longitude.value}', style: TextStyle(color: Colors.white, fontSize: 16)),

                  locationController.address.value.isEmpty
                      ? Text('fetching address.', style: TextStyle(color: Colors.white, fontSize: 14))
                      : Text('Address: ${locationController.address.value}', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool storageGranted = await requestStoragePermission();
          if (!storageGranted) {
            print('check1');
          }
          final file = await cameraManager.takePicture(locationController.latitude.value,locationController.longitude.value,locationController.address.value);
          if (file != null) {
            Get.snackbar("Captured", file.path);
          }
        },
        child: Icon(Icons.camera),
      ),
    );
  }
}
