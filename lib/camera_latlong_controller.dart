import 'dart:io';
import 'dart:ui' as ui;

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




  Future<File> _addLatLongToImage(File originalImageFile, double lat, double lng, String address) async {
    final originalImageBytes = await originalImageFile.readAsBytes();
    final originalImage = await decodeImageFromList(originalImageBytes);

    final ByteData data = await rootBundle.load('assets/images/images.jpg');
    final Uint8List bytes = data.buffer.asUint8List();
    final mapImage = await decodeImageFromList(bytes);


    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    canvas.drawImage(originalImage, Offset.zero, paint);


    final textStyle = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: 24,
    );
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: TextDirection.ltr,
    );

    const double padding = 10;
    const double lineSpacing = 5;
    const double previewImageHeight = 100;
    const double previewImageWidth = 100;


    final addressBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(address);
    final addressParagraph = addressBuilder.build();
    addressParagraph.layout(ui.ParagraphConstraints(width: originalImage.width - previewImageWidth - (padding * 3)));

    final latLngBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText('Lat ${lat.toStringAsFixed(6)}° Long ${lng.toStringAsFixed(6)}°');
    final latLngParagraph = latLngBuilder.build();
    latLngParagraph.layout(ui.ParagraphConstraints(width: originalImage.width - previewImageWidth - (padding * 3)));


    final now = DateTime.now();
    final formattedDateTime = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:' // fixed
        '${now.minute.toString().padLeft(2, '0')} '
        '${now.hour >= 12 ? 'PM' : 'AM'} GMT +05:30';

    final dateTimeBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(formattedDateTime);
    final dateTimeParagraph = dateTimeBuilder.build();
    dateTimeParagraph.layout(ui.ParagraphConstraints(width: originalImage.width - previewImageWidth - (padding * 3)));


    final double totalTextHeight = addressParagraph.height + latLngParagraph.height + dateTimeParagraph.height + (lineSpacing * 2);
    final double totalContentHeight = previewImageHeight > totalTextHeight ? previewImageHeight : totalTextHeight;


    final double contentY = originalImage.height - totalContentHeight - padding;


    final double imageX = padding;
    final double imageY = contentY;
    final Rect src = Rect.fromLTWH(0, 0, mapImage.width.toDouble(), mapImage.height.toDouble());
    final Rect dst = Rect.fromLTWH(imageX, imageY, previewImageWidth, previewImageHeight);
    canvas.drawImageRect(mapImage, src, dst, paint);


    final double textStartX = imageX + previewImageWidth + padding;
    final double textStartY = contentY;

    canvas.drawParagraph(addressParagraph, Offset(textStartX, textStartY));
    canvas.drawParagraph(latLngParagraph, Offset(textStartX, textStartY + addressParagraph.height + lineSpacing));
    canvas.drawParagraph(dateTimeParagraph, Offset(
      textStartX,
      textStartY + addressParagraph.height + latLngParagraph.height + (lineSpacing * 2),
    ));


    final picture = recorder.endRecording();
    final img = await picture.toImage(originalImage.width, originalImage.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();


    final tempDir = await getTemporaryDirectory();
    final newPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_final.png';
    final resultFile = File(newPath);
    await resultFile.writeAsBytes(pngBytes);

    return resultFile;
  }


  Future<XFile?> takePicture(double lat, double lng,String address) async {
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
      final updatedImageFile = await _addLatLongToImage(croppedImageFile, lat, lng,address);


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



