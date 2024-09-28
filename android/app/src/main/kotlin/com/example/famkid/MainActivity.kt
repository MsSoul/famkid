package com.example.famkid

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.content.Intent
import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log

class MainActivity : FlutterActivity() {
    private val APP_LIST_CHANNEL = "com.example.app/app_list"
    private val DEVICE_INFO_CHANNEL = "com.example.device_info"
    private val APP_BLOCK_CHANNEL = "com.example.app/block"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check if flutterEngine is non-null before using it
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger != null) {
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

                        Log.i("AppInfo", "User-visible App: $appName, Package: $packageName")

                        mapOf(
                            "appName" to appName,
                            "packageName" to packageName
                        )
                    }

                    Log.i("AppInfo", "Total user-visible apps found: ${appList.size}")
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

                // Log the received values to confirm
                Log.i("AppBlockChannel", "Received package_name: $packageName, is_allowed: $isAllowed")

                if (packageName != null && isAllowed != null) {
                    if (!isAllowed) {
                        blockApp(packageName)
                        result.success("App blocked successfully")
                    } else {
                        unblockApp(packageName)
                        result.success("App unblocked successfully")
                    }
                } else {
                    Log.e("AppBlockChannel", "Failed: Package name or isAllowed is null")
                    result.error("INVALID_PACKAGE", "Package name or isAllowed status is null", null)
                }
            }
        } else {
            Log.e("MainActivity", "flutterEngine or BinaryMessenger is null.")
        }
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
