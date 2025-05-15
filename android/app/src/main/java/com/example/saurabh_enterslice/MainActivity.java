package com.example.saurabh_enterslice;

import android.media.MediaScannerConnection;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "gallery_saver_channel";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("scanFile")) {
                        String path = call.argument("path");
                        MediaScannerConnection.scanFile(
                                getApplicationContext(),
                                new String[]{path},
                                null,
                                (scannedPath, uri) -> Log.d("MediaScanner", "Scanned: " + scannedPath)
                        );
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }
}
