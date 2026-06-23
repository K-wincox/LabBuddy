package com.kongweikang.labbuddy_android

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class TimerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val timerId = intent.getStringExtra(extraTimerId) ?: return
        val runTitle = intent.getStringExtra(extraRunTitle) ?: "LabBuddy Timer"
        val stepTitle = intent.getStringExtra(extraStepTitle) ?: "实验步骤"

        ensureChannel(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            context,
            timerId.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("计时完成：$stepTitle")
            .setContentText(runTitle)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$runTitle\n$stepTitle 已到时间。"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        NotificationManagerCompat.from(context).notify(timerId.hashCode(), notification)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(channelId) != null) return
        val channel = NotificationChannel(
            channelId,
            "LabBuddy Timers",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Bench timer completion alerts"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val channelId = "labbuddy_timers"
        const val extraTimerId = "timer_id"
        const val extraRunTitle = "run_title"
        const val extraStepTitle = "step_title"
    }
}
