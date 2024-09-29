package com.example.famkid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.util.Log
import android.net.wifi.WifiManager

class MainActivity : FlutterActivity() {
    private val APP_LIST_CHANNEL = "com.example.app/app_list"
    private val DEVICE_INFO_CHANNEL = "com.example.device_info"
    private val APP_BLOCK_CHANNEL = "com.example.app/block"

    private lateinit var appInstallReceiver: BroadcastReceiver

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Safely handle flutterEngine
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger ?: run {
            Log.e("MainActivity", "flutterEngine or BinaryMessenger is null.")
            return // Exit if there's no valid messenger
        }

        // MethodChannel for fetching installed apps
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

                    Log.i("AppInfo", "App: $appName, Package: $packageName, isSystemApp: $isSystemApp")

                    mapOf(
                        "appName" to appName,
                        "packageName" to packageName,
                        "isSystemApp" to isSystemApp  // Identify if it's a system app
                    )
                }

                Log.i("AppInfo", "Total apps found: ${appList.size}")
                result.success(appList)
            } else {
                result.notImplemented()
            }
        }

        // MethodChannel for fetching device info (MAC address)
        MethodChannel(messenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMacAddress") {
                val macAddress = getMacAddress()
                if (macAddress != null) {
                    result.success(macAddress)
                } else {
                    result.error("UNAVAILABLE", "MAC address not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // MethodChannel for blocking/unblocking apps based on `is_allowed` status
        MethodChannel(messenger, APP_BLOCK_CHANNEL).setMethodCallHandler { call, result ->
            val packageName = call.argument<String>("package_name")
            val isAllowed = call.argument<Boolean>("is_allowed")
            val isSystemApp = call.argument<Boolean>("is_system_app") ?: false

            // Log the received values to confirm
            Log.i("AppBlockChannel", "Received package_name: $packageName, is_allowed: $isAllowed, isSystemApp: $isSystemApp")

            if (packageName != null && isAllowed != null) {
                // Only allow blocking/unblocking of user apps
                if (!isSystemApp) {
                    if (!isAllowed) {
                        blockApp(packageName)
                        result.success("User app blocked successfully")
                    } else {
                        unblockApp(packageName)
                        result.success("User app unblocked successfully")
                    }
                } else {
                    Log.i("AppBlockChannel", "System apps cannot be blocked/unblocked")
                    result.error("BLOCK_ERROR", "System apps cannot be blocked or unblocked", null)
                }
            } else {
                Log.e("AppBlockChannel", "Failed: Package name or isAllowed is null")
                result.error("INVALID_PACKAGE", "Package name or isAllowed status is null", null)
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

    private fun blockApp(packageName: String) {
        try {
            val packageManager = packageManager
            // Ensure to disable the app completely
            packageManager.setApplicationEnabledSetting(
                packageName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER,
                0
            )
            Log.i("AppBlock", "App blocked: $packageName")
        } catch (e: Exception) {
            Log.e("AppBlock", "Error blocking app: ${e.message}")
        }
    }

    private fun unblockApp(packageName: String) {
        try {
            val packageManager = packageManager
            // Ensure to enable the app properly
            packageManager.setApplicationEnabledSetting(
                packageName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                0
            )
            Log.i("AppBlock", "App unblocked: $packageName")
        } catch (e: Exception) {
            Log.e("AppBlock", "Error unblocking app: ${e.message}")
        }
    }

    private fun getMacAddress(): String? {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        return wifiManager.connectionInfo.macAddress
    }
}
