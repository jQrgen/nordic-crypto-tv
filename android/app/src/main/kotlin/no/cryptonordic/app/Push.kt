package no.cryptonordic.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.coroutines.resume

/**
 * Remote notifications through the Nordic Crypto push server (push/ in this
 * repository, docs/push.md) and Firebase Cloud Messaging. The server keeps only
 * the FCM token, the chosen countries and the language. While push works the
 * on-device check ([Alerts]) stays quiet; when it does not (no Firebase
 * settings in this build, no Google Play services, no network), the on-device
 * check is the fallback.
 *
 * Firebase is set up in code from BuildConfig, so no google-services.json is
 * needed in the repository. A build without FIREBASE_* values has no push.
 */
object Push {
    private const val PREFS = "push"
    const val CHANNEL = "new-stories"
    private val lock = Mutex()
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** This build carries Firebase settings. */
    val configured: Boolean get() = BuildConfig.FIREBASE_APP_ID.isNotEmpty() && BuildConfig.PUSH_SERVER_URL.isNotEmpty()

    /** The server accepted this device and can deliver to it. */
    fun active(c: Context) = prefs(c).getBoolean("active", false)

    private fun firebase(c: Context): FirebaseApp? {
        if (!configured) return null
        FirebaseApp.getApps(c).firstOrNull()?.let { return it }
        val options = FirebaseOptions.Builder()
            .setApplicationId(BuildConfig.FIREBASE_APP_ID)
            .setApiKey(BuildConfig.FIREBASE_API_KEY)
            .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
            .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
            .build()
        return runCatching { FirebaseApp.initializeApp(c.applicationContext, options) }.getOrNull()
    }

    private suspend fun <T> Task<T>.await(): T? = suspendCancellableCoroutine { cont ->
        addOnCompleteListener { t -> cont.resume(if (t.isSuccessful) t.result else null) }
    }

    fun ensureChannel(c: Context) {
        c.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(CHANNEL, Lang.tr("Notifications"), NotificationManager.IMPORTANCE_DEFAULT))
    }

    /** Registers, updates or forgets this device to match the notification settings. */
    fun syncLater(c: Context, force: Boolean = false) {
        val app = c.applicationContext
        scope.launch { sync(app, force) }
    }

    suspend fun sync(c: Context, force: Boolean = false, newToken: String? = null) = lock.withLock {
        if (!Alerts.enabled(c)) { forget(c); return@withLock }
        firebase(c) ?: run { setActive(c, false); return@withLock }
        ensureChannel(c)
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = true
        // getToken()/deleteToken() are deprecated since firebase-messaging 25.1 in favour of
        // register()/onRegistered(); they still work. Moving over is listed in docs/push.md.
        @Suppress("DEPRECATION")
        val token = newToken ?: messaging.token.await() ?: run { setActive(c, false); return@withLock }
        val countries = Alerts.countries(c).sorted()
        val day = System.currentTimeMillis() / 86_400_000
        val signature = (listOf(token, Lang.current) + countries).joinToString("|") + "|$day"
        val p = prefs(c)
        if (!force && active(c) && p.getString("sent", null) == signature) return@withLock
        val body = buildJsonObject {
            put("token", token)
            put("platform", "android")
            put("countries", JsonArray(countries.map { JsonPrimitive(it) }))
            put("language", Lang.current)
        }.toString()
        val reply = request("POST", "v1/devices", body)
        val delivers = reply?.let {
            runCatching {
                val o = Api.json.parseToJsonElement(it).jsonObject
                o["delivery"]?.jsonPrimitive?.booleanOrNull == true && o["stored"]?.jsonPrimitive?.booleanOrNull == true
            }.getOrNull()
        } == true
        p.edit().putString("token", token).putString("sent", if (delivers) signature else null).apply()
        setActive(c, delivers)
    }

    /** Notifications off: the server and Firebase forget this device. */
    private suspend fun forget(c: Context) {
        setActive(c, false)
        val p = prefs(c)
        val token = p.getString("token", null) ?: return
        val path = "v1/devices/" + URLEncoder.encode(token, "UTF-8")
        if (request("DELETE", path, null) != null) {
            p.edit().remove("token").remove("sent").apply()
            if (firebase(c) != null) {
                FirebaseMessaging.getInstance().isAutoInitEnabled = false
                @Suppress("DEPRECATION")
                FirebaseMessaging.getInstance().deleteToken().await()
            }
        }
    }

    private fun setActive(c: Context, on: Boolean) = prefs(c).edit().putBoolean("active", on).apply()

    /** The response body on HTTP 200, else null. */
    private suspend fun request(method: String, path: String, body: String?): String? = withContext(Dispatchers.IO) {
        runCatching {
            val conn = URL(BuildConfig.PUSH_SERVER_URL.trimEnd('/') + "/" + path).openConnection() as HttpURLConnection
            conn.requestMethod = method
            conn.connectTimeout = 10_000; conn.readTimeout = 15_000
            conn.setRequestProperty("User-Agent", "NordicCrypto-Android/1.1")
            if (body != null) {
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write(body.toByteArray()) }
            }
            if (conn.responseCode != 200) null else conn.inputStream.bufferedReader().use { it.readText() }
        }.getOrNull()
    }
}

/**
 * FCM shows the notification itself while the app is in the background, and a
 * tap opens MainActivity with "story" in the extras. In the foreground nothing is
 * announced, the same as the on-device check.
 */
class PushService : FirebaseMessagingService() {
    /** A new or rotated token: tell the push server. */
    override fun onRegistered(token: String) {
        Lang.load(applicationContext)
        val app = applicationContext
        Push.scope.launch { Push.sync(app, force = true, newToken = token) }
    }

    @Deprecated("Replaced by onRegistered in firebase-messaging 25.1; still called by getToken().")
    override fun onNewToken(token: String) = onRegistered(token)

    override fun onMessageReceived(message: RemoteMessage) = Unit
}
