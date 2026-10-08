package no.cryptonordic.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Local notifications for new stories, per country. Everything stays on the
 * device: the app reads the public feed and compares it with what it has seen.
 */
object Alerts {
    private const val PREFS = "alerts"
    private const val CHANNEL = "new-stories"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enabled(c: Context) = prefs(c).getBoolean("enabled", false)
    fun countries(c: Context): Set<String> = prefs(c).getStringSet("countries", null) ?: Country.entries.map { it.code }.toSet()

    fun setEnabled(c: Context, on: Boolean) {
        prefs(c).edit().putBoolean("enabled", on).apply()
        if (on) schedule(c) else WorkManager.getInstance(c).cancelUniqueWork("news-check")
    }

    fun toggle(c: Context, country: Country) {
        val now = countries(c).toMutableSet()
        if (!now.add(country.code)) now.remove(country.code)
        prefs(c).edit().putStringSet("countries", now).apply()
    }

    /** Checks every 15 minutes, the shortest period Android allows. */
    fun schedule(c: Context) {
        val work = PeriodicWorkRequestBuilder<CheckWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(c).enqueueUniquePeriodicWork("news-check", ExistingPeriodicWorkPolicy.KEEP, work)
    }

    /** Announces unseen stories from the chosen countries; the first run only remembers. */
    fun process(c: Context, news: List<NewsItem>, foreground: Boolean = MainActivity.inForeground) {
        val p = prefs(c)
        val seenBefore = p.getStringSet("seen", null)
        val seen = seenBefore.orEmpty().toMutableSet()
        val fresh = news.filter { it.id !in seen }
        p.edit().putStringSet("seen", (seen + news.map { it.id }).let { if (it.size > 500) news.map { n -> n.id }.toSet() else it }).apply()
        if (seenBefore == null || !enabled(c) || foreground) return
        val wanted = fresh.filter { it.country in countries(c) }
        if (wanted.isEmpty() || !canNotify(c)) return

        val nm = c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, Lang.tr("Notifications"), NotificationManager.IMPORTANCE_DEFAULT))
        val lang = Lang.current
        val shown = if (wanted.size <= 3) wanted else listOf(wanted.first())
        for (item in shown) {
            val open = PendingIntent.getActivity(c, item.id.hashCode(),
                Intent(c, MainActivity::class.java).putExtra("story", item.id).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val title = if (wanted.size <= 3) listOfNotNull(item.sourceName, Country.of(item.country)?.localName).joinToString(" · ")
                else "Nordic Crypto"
            val body = if (wanted.size <= 3) item.headline(lang)
                else Lang.tr("%lld new stories", wanted.size) + ": " + wanted.take(2).joinToString(" · ") { it.headline(lang) }
            val n = android.app.Notification.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(android.app.Notification.BigTextStyle().bigText(body))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            nm.notify(item.id.hashCode(), n)
        }
    }

    fun canNotify(c: Context) = Build.VERSION.SDK_INT < 33 ||
        c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    class CheckWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
        override suspend fun doWork(): Result {
            Lang.load(applicationContext)
            val text = Api.fetch(applicationContext, "news.json") ?: return Result.retry()
            val news = runCatching { Api.json.decodeFromString<NewsFeed>(text).items }.getOrNull() ?: return Result.retry()
            process(applicationContext, news, foreground = false)
            return Result.success()
        }
    }
}
