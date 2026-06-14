package app.daliya.quran

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class AyahWidget : AppWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.widget_ayah)

            val text = data.getString("ayah_text", "﴿ وَقُل رَّبِّ زِدْنِي عِلْمًا ﴾") ?: "﴿ وَقُل رَّبِّ زِدْنِي عِلْمًا ﴾"
            val ref  = data.getString("ayah_ref", "") ?: ""

            views.setTextViewText(R.id.ayah_text, text)
            views.setTextViewText(R.id.ayah_ref, ref)

            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 1, intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.ayah_text, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
