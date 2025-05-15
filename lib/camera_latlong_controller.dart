import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';



class CameraControllerGetX extends GetxController {
  late CameraController cameraController;
  late CameraDescription cameraDescription;

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    cameraDescription = cameras.first;
    cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
    );
    await cameraController.initialize();
  }



  @override
  void onInit() {
    initializeCamera();
    super.onInit();
  }

  @override
  void onClose() {
    cameraController.dispose();
    super.onClose();
  }

}



class CameraManagerController extends GetxController {
  CameraController? cameraController;
  RxBool isCameraInitialized = false.obs;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;
      cameraController = CameraController(
        firstCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await cameraController!.initialize();
      isCameraInitialized.value = true;
    } catch (e) {
      print("check 2  $e");
    }
  }



  Future<File> _addLatLongToImage(File originalImage, double lat, double lng) async {
    print("check 3 ");
    final imageBytes = await originalImage.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) throw Exception("failed");

    final text = 'Lat: $lat, Lng: $lng';

    final font = img.arial24;
    img.drawString(
      image,
      text,
      font: font,
      x: 10,
      y: image.height - 30,
      color: img.ColorInt16.rgb(255, 255, 0),

    );
    print("check 4 ");
    final tempDir = await getTemporaryDirectory();
    final newPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_latlong.jpg';
    final updatedImage = File(newPath);
    await updatedImage.writeAsBytes(img.encodeJpg(image, quality: 90));

    return updatedImage;
  }



  Future<XFile?> takePicture(double lat, double lng) async {
    print("check 5 ");
    await requestStoragePermission();
    if (cameraController == null || !cameraController!.value.isInitialized) return null;

    try {
      print("check 6 ");
      XFile image = await cameraController!.takePicture();

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,

        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile == null) {
        return image;
      }

      File croppedImageFile = File(croppedFile.path);
      final updatedImageFile = await _addLatLongToImage(croppedImageFile, lat, lng);


      final savedFile = await saveImageToGallery(XFile(updatedImageFile.path));

      return savedFile ?? image;

    } catch (e) {
      print('check 7 error: $e');
      return null;
    }
  }


  Future<XFile?> saveImageToGallery(XFile image) async {
    print("check 8 ");
    try {
      final imageFile = File(image.path);
      Directory? directory;

      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Pictures/saurabh');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }


      final String newPath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await imageFile.copy(newPath);

      await _scanFile(savedImage.path);

      return XFile(savedImage.path);
    } catch (e) {
      print("check 9 error: $e");
      return null;
    }
  }

  Future<void> _scanFile(String path) async {
    try {
      const platform = MethodChannel('gallery_saver_channel');
      await platform.invokeMethod('scanFile', {'path': path});
    } catch (e) {
        print("check 10 error _scanfile: $e");
    }
  }

  @override
  void onInit() {
    initializeCamera();
    super.onInit();
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }
}



Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    if (await Permission.storage.request().isGranted) {
      return true;
    }

    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return true;
    } else {
      await openAppSettings();
      return false;
    }
  }
  return true;
}



