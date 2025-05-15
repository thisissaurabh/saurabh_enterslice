

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationController extends GetxController implements GetxService {
  RxDouble latitude = 0.0.obs;
  RxDouble longitude = 0.0.obs;
  RxString address = ''.obs;

  @override
  void onInit() {
    super.onInit();

  }

  Future<bool> requestLocationPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      var status = await Permission.location.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.location.request();
        if (status.isGranted) return true;
      }

      if (status.isPermanentlyDenied) {
        bool opened = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Permission Required'),
            content: Text(
                'Please enable location from device to continue.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop(true);
                },
                child: Text('Settings'),
              ),
            ],
          ),
        );
        return opened ?? false;
      }

      return false;
    }
    return true;
  }

  Future<void> getUserLocation() async {
    bool permissionGranted = await requestLocationPermission(Get.context!);

    if (!permissionGranted) {
      print('check');
      return;
    }

    print('check 1');

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('check 2  $serviceEnabled');

      if (!serviceEnabled) {
        print('check 3  $serviceEnabled');
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print("check 4 $permission");

      if (permission == LocationPermission.denied) {
        print("🔄 check 5");
        permission = await Geolocator.requestPermission();
        print("check 6 $permission");

        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          print("check 7");
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        print("check 8");
        return;
      }

      print("check 9");
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 10));

      latitude.value = currentPosition.latitude;
      longitude.value = currentPosition.longitude;

      await getAddressFromLatLng(latitude.value, longitude.value);

      print('lat: ${latitude.value}, lng: ${longitude.value}');
      print('address: ${address.value}');

      print('working fine');
      print('lat: ${latitude.value}, lng: ${longitude.value}');
    } catch (e) {
      print('check 10 error $e');
    }

    update();
  }


  Future<void> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address.value =
        '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
        update();
      }
    } catch (e) {
      print('Error check 11: $e');
    }
  }

}
