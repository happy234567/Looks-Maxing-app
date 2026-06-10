package com.levelmaxing.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

class AppWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_layout)

        // Lock In Pending Intent
        views.setOnClickPendingIntent(R.id.btn_lock_in, getPendingIntent(context, "lock_in", 1))

        // Food Scan Pending Intent
        views.setOnClickPendingIntent(R.id.btn_food_scan, getPendingIntent(context, "food_scan", 2))

        // Face Scan Pending Intent
        views.setOnClickPendingIntent(R.id.btn_face_scan, getPendingIntent(context, "face_scan", 3))

        // Fetch Today's Tasks
        val tasks = getTodayTasks(context)
        views.setTextViewText(R.id.widget_tasks_list, tasks)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun getPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("widget_action", action)
        }
        val flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    private fun getTodayTasks(context: Context): String {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.lock_in_data_v2", null) ?: return "• Tap to set up today's tasks"
            
            val json = JSONObject(raw)
            val config = json.optJSONObject("config") ?: return "• Complete your targets today"
            val weekdayTasks = config.optJSONArray("weekdayTasks") ?: return "• Complete your targets today"
            
            // Calculate current day index (0=Monday, 6=Sunday)
            val calendar = Calendar.getInstance()
            val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
            val idx = (dayOfWeek + 5) % 7 // Maps Sun(1) -> 6, Mon(2) -> 0, Tue(3) -> 1, ..., Sat(7) -> 5
            
            val todayTasksArray = weekdayTasks.optJSONArray(idx)
            if (todayTasksArray == null || todayTasksArray.length() == 0) {
                // If there are no custom tasks, show the mandatory ones
                val mandatory = config.optJSONObject("mandatory")
                val steps = mandatory?.optInt("stepsTarget", 10000) ?: 10000
                val protein = mandatory?.optInt("proteinTarget", 100) ?: 100
                val sleep = mandatory?.optDouble("sleepTarget", 8.0) ?: 8.0
                return "• $steps steps\n• $protein g Protein\n• $sleep hr Sleep"
            }
            
            val sb = StringBuilder()
            val limit = Math.min(todayTasksArray.length(), 4) // Show up to 4 tasks
            for (i in 0 until limit) {
                sb.append("• ").append(todayTasksArray.getString(i))
                if (i < limit - 1) {
                    sb.append("\n")
                }
            }
            if (todayTasksArray.length() > limit) {
                sb.append("\n• +").append(todayTasksArray.length() - limit).append(" more...")
            }
            return sb.toString()
        } catch (e: Exception) {
            return "• Tap to view Lock In progress"
        }
    }
}
