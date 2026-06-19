package app.daliya.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class QuranMediaReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PLAY  = "app.daliya.quran.MEDIA_PLAY"
        const val ACTION_PAUSE = "app.daliya.quran.MEDIA_PAUSE"
        const val ACTION_NEXT  = "app.daliya.quran.MEDIA_NEXT"
        const val ACTION_PREV  = "app.daliya.quran.MEDIA_PREV"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val dartAction = when (intent.action) {
            ACTION_PLAY  -> "play"
            ACTION_PAUSE -> "pause"
            ACTION_NEXT  -> "next"
            ACTION_PREV  -> "prev"
            else -> return
        }
        MainActivity.mediaChannel?.invokeMethod("onMediaAction", dartAction)
    }
}
