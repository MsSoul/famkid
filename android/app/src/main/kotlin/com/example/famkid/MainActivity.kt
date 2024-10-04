package com.example.famkid

import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
    private val PIN_LOCK_CHANNEL = "com.example.app/block"            // Channel for applying PIN lock on system apps

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
            return
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
                        unlockDevice(result)
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

            // Check if entered PIN is valid
            if (enteredPin.isNullOrEmpty()) {
                result.error("INVALID_PIN", "Entered PIN is null or empty", null)
                return@setMethodCallHandler
            }

            // Fetch the correct PIN from the backend using OkHttp
            val correctPin = getPinFromBackend(childId)

            // Unlock the device if the PIN is correct
            if (enteredPin == correctPin) {
                unlockDevice(result)
            } else {
                result.error("INVALID_PIN", "Incorrect PIN entered", null)
            }
        }

        // MethodChannel for applying PIN lock to system apps
        MethodChannel(messenger, PIN_LOCK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pinLockApp") {
                val packageName = call.argument<String>("package_name")
                if (packageName != null) {
                    applyPinLockForSystemApp(packageName)
                    result.success("PIN lock applied for app: $packageName")
                } else {
                    result.error("INVALID_PACKAGE", "Package name is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // MethodChannel for fetching installed apps
        MethodChannel(messenger, APP_LIST_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                val packageManager = packageManager
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
            // Unlock logic: Here you can simulate or clear the keyguard lock.
            result.success("Device unlocked successfully")
        } else {
            result.error("ADMIN_DISABLED", "Device Admin is not enabled", null)
        }
    }

    // Function to apply PIN lock for system apps
    private fun applyPinLockForSystemApp(packageName: String) {
        Log.i("MainActivity", "Applying PIN lock for system app: $packageName")
        // Implement the logic to PIN protect the system app here
        // For example, lock the app with a custom PIN or restrict access
    }

    // Function to get the MAC address of the device
    private fun getMacAddress(): String? {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        return wifiManager.connectionInfo.macAddress
    }

    // Function to fetch the correct PIN from the backend
    private fun getPinFromBackend(childId: String): String {
        val client = OkHttpClient()
        val request = Request.Builder()
            .url("http://192.168.100.235:5504/api/child/$childId/pin") // Replace with actual backend URL
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string()
            return if (response.isSuccessful && body != null) {
                val json = JSONObject(body)
                json.getString("pin")
            } else {
                "1234" // Default fallback PIN in case of error
            }
        }
    }
}
