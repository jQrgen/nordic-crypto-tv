package no.cryptonordic.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

/** Radio Norge behind the Android TV screen. On by default; the choice is remembered. */
class Radio(private val context: Context) {
    private val prefs = context.getSharedPreferences("radio", Context.MODE_PRIVATE)
    var isOn by mutableStateOf(prefs.getBoolean("on", true))
        private set
    var isPlaying by mutableStateOf(false)
        private set
    private var player: ExoPlayer? = null

    fun start() { if (isOn) play() }

    fun toggle() {
        isOn = !isOn
        prefs.edit().putBoolean("on", isOn).apply()
        if (isOn) play() else stop()
    }

    private fun play() {
        stop()
        player = ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(Api.RADIO))
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) { this@Radio.isPlaying = playing }
                // Live streams drop: rejoin the live edge after an error.
                override fun onPlayerError(error: PlaybackException) { if (this@Radio.isOn) this@Radio.play() }
            })
            prepare()
            play()
        }
    }

    fun stop() {
        player?.release()
        player = null
        isPlaying = false
    }
}
