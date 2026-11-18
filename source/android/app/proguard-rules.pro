# Keep Android entry points referenced by the manifest and MethodChannels.
-keep class com.example.internet_manager_app.MainActivity { *; }
-keep class com.example.internet_manager_app.InternetSpeedService { *; }
-keep class com.example.internet_manager_app.InternetLimitMonitorService { *; }
-keep class com.example.internet_manager_app.InternetManagerVpnService { *; }
-keep class com.example.internet_manager_app.InternetManagerBootReceiver { *; }
-keep class com.example.internet_manager_app.NetworkStatsReader { *; }
