package com.example.famkid

import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val APP_LIST_CHANNEL = "com.example.app/app_list"
    private val DEVICE_INFO_CHANNEL = "com.example.device_info"
    private val DEVICE_CONTROL_CHANNEL = "com.example.device/control" // Channel for device lock/unlock control
    private val DEVICE_UNLOCK_PIN = "com.example.device/unlock_pin"   // Channel for device unlock via PIN

    private lateinit var appInstallReceiver: BroadcastReceiver
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var componentName: ComponentName

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize DevicePolicyManager for locking/unlocking device
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        componentName = ComponentName(this, DeviceAdminReceiver::class.java)

        // Safely handle flutterEngine
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger ?: run {
            Log.e("MainActivity", "flutterEngine or BinaryMessenger is null.")
            return // Exit if there's no valid messenger
        }

        // MethodChannel for locking and unlocking the device
        MethodChannel(messenger, DEVICE_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAdminActive" -> {
                    val isActive = devicePolicyManager.isAdminActive(componentName)
                    result.success(isActive)
                }
                "lockDevice" -> {
                    if (devicePolicyManager.isAdminActive(componentName)) {
                        devicePolicyManager.lockNow()
                        result.success("Device locked")
                    } else {
                        result.error("ADMIN_DISABLED", "Device Admin is not enabled", null)
                    }
                }
                "unlockDevice" -> {
                    if (devicePolicyManager.isAdminActive(componentName)) {
                        unlockDevice(result)  // Pass result to unlockDevice
                    } else {
                        result.error("ADMIN_DISABLED", "Device Admin is not enabled", null)
                    }
                }
                "enableAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                    intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "You need to enable Device Admin to lock and unlock the device.")
                    startActivityForResult(intent, 1)
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel for unlocking the device via PIN
        MethodChannel(messenger, DEVICE_UNLOCK_PIN).setMethodCallHandler { call, result ->
            val enteredPin = call.argument<String>("enteredPin")
            val childId = call.argument<String>("childId") ?: ""

            // Fetch the correct PIN from the backend (use OkHttp)
            val correctPin = getPinFromBackend(childId)

            // Unlock the device if the PIN is correct
            if (enteredPin == correctPin) {
                unlockDevice(result)
            } else {
                result.error("INVALID_PIN", "Incorrect PIN entered", null)
            }
        }

        // MethodChannel for fetching installed apps (if needed)
        MethodChannel(messenger, APP_LIST_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                val packageManager = packageManager

                // Intent to filter apps that have a launcher and can be launched from the home screen
                val intent = Intent(Intent.ACTION_MAIN, null)
                intent.addCategory(Intent.CATEGORY_LAUNCHER)

                val resolveInfoList = packageManager.queryIntentActivities(intent, 0)
                val appList = resolveInfoList.map { resolveInfo ->
                    val appName = resolveInfo.loadLabel(packageManager).toString()
                    val packageName = resolveInfo.activityInfo.packageName
                    val isSystemApp = (resolveInfo.activityInfo.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

                    mapOf(
                        "appName" to appName,
                        "packageName" to packageName,
                        "isSystemApp" to isSystemApp  // Identify if it's a system app
                    )
                }

                result.success(appList)
            } else {
                result.notImplemented()
            }
        }

        // Register the BroadcastReceiver for app installs and uninstalls
        appInstallReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action
                val packageName = intent?.data?.encodedSchemeSpecificPart

                if (action == Intent.ACTION_PACKAGE_ADDED || action == Intent.ACTION_PACKAGE_REMOVED) {
                    Log.i("AppInstallReceiver", "App $packageName has been ${if (action == Intent.ACTION_PACKAGE_ADDED) "installed" else "removed"}")

                    // Notify Flutter that the app list has changed
                    MethodChannel(messenger, APP_LIST_CHANNEL).invokeMethod("onAppListChanged", null)
                }
            }
        }

        // Register the receiver to listen for package changes
        val filter = IntentFilter()
        filter.addAction(Intent.ACTION_PACKAGE_ADDED)
        filter.addAction(Intent.ACTION_PACKAGE_REMOVED)
        filter.addDataScheme("package")
        registerReceiver(appInstallReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister the receiver to avoid memory leaks
        unregisterReceiver(appInstallReceiver)
    }

    // Function to lock the device
    private fun lockDevice(result: MethodChannel.Result) {
        if (devicePolicyManager.isAdminActive(componentName)) {
            devicePolicyManager.lockNow()  // Lock the device immediately
            result.success("Device locked")
        } else {
            result.error("ADMIN_DISABLED", "Device Admin is not enabled", null)
        }
    }

    // Logic for unlocking the device based on admin privileges
    private fun unlockDevice(result: MethodChannel.Result) {
        if (devicePolicyManager.isAdminActive(componentName)) {
            // Unlock logic. You could clear the keyguard or perform some action to simulate unlock.
            result.success("Device unlocked successfully")
        } else {
            result.error("ADMIN_DISABLED", "Device Admin is not enabled", null)
        }
    }

    // Function to get the MAC address of the device
    private fun getMacAddress(): String? {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        return wifiManager.connectionInfo.macAddress
    }

    // Function to fetch the correct PIN from the backend
    private fun getPinFromBackend(childId: String): String {
        // Use OkHttp to fetch the correct PIN from your backend API
        val client = OkHttpClient()
        val request = Request.Builder()
            .url("https://192.168.1.7/api/child/$childId/pin")
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string()
            if (response.isSuccessful && body != null) {
                val json = JSONObject(body)
                return json.getString("pin")
            } else {
                return "1234" // Default fallback pin in case of error
            }
        }
    }
}
