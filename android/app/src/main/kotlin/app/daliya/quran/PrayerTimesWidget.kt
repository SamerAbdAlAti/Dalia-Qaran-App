package app.daliya.quran

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerTimesWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val data = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_times)

            val nextName = data.getString("next_prayer_name", "—") ?: "—"
            val nextTime = data.getString("next_prayer_time", "--:--") ?: "--:--"
            val fajr    = data.getString("fajr", "--:--") ?: "--:--"
            val dhuhr   = data.getString("dhuhr", "--:--") ?: "--:--"
            val asr     = data.getString("asr", "--:--") ?: "--:--"
            val maghrib = data.getString("maghrib", "--:--") ?: "--:--"
            val isha    = data.getString("isha", "--:--") ?: "--:--"

            views.setTextViewText(R.id.next_prayer_name, nextName)
            views.setTextViewText(R.id.next_prayer_time, nextTime)
            views.setTextViewText(R.id.fajr_time, fajr)
            views.setTextViewText(R.id.dhuhr_time, dhuhr)
            views.setTextViewText(R.id.asr_time, asr)
            views.setTextViewText(R.id.maghrib_time, maghrib)
            views.setTextViewText(R.id.isha_time, isha)

            // Tap to open app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_app_name, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
