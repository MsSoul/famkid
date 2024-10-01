package com.example.famkid

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

// This class will handle Device Admin events (enabled, disabled)
class DeviceAdminReceiver : DeviceAdminReceiver() {

    // Called when Device Admin is enabled
    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Device Admin enabled", Toast.LENGTH_SHORT).show()
    }

    // Called when Device Admin is disabled
    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Device Admin disabled", Toast.LENGTH_SHORT).show()
    }
}
