package no.cryptonordic.app.ui

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL

/** Nordlys tokens, the same values as the Apple apps. */
object NL {
    val ground = Color(0xFF06090F)
    val bg = Color(0xFF070B14)
    val panel = Color(0xFF0F1522)
    val aside = Color(0xFF0D1320)
    val raised = Color(0xFF1A2232)
    val rule = Color(0xFF1E2738)
    val textPrimary = Color(0xFFF2F5FA)
    val textSecondary = Color(0xFFA3ADC2)
    val textTertiary = Color(0xFF7A859C)
    val body = Color(0xFFC9D1DF)
    val accent = Color(0xFF3DDC97)
    val accent2 = Color(0xFF8B7CF6)
    val warning = Color(0xFFFFB547)
    val danger = Color(0xFFFF5D6C)
    val telegram = Color(0xFF229ED9)
    val serif = FontFamily.Serif

    fun country(code: String?) = when (code) {
        "NO" -> Color(0xFFF2545B)
        "SE" -> Color(0xFFF2C14E)
        "DK" -> Color(0xFFFF7AA2)
        "FI" -> Color(0xFF4D9DFF)
        "IS" -> Color(0xFF3FD3C6)
        else -> textTertiary
    }

    fun topic(t: String?) = when (t?.lowercase()) {
        "regulation", "mica", "policy", "licence", "tax" -> Color(0xFF8B7CF6)
        "crime", "aml", "fraud", "sanctions" -> Color(0xFFFF7A45)
        "business", "funds", "markets", "adoption", "mining", "bitcoin" -> Color(0xFF3DDC97)
        "stablecoins", "payments", "cbdc", "banking", "tokenisation", "defi" -> Color(0xFF2EC4E6)
        else -> Color(0xFF5B6CFF)
    }
}

/** Generated aurora art: two soft glows in a story's country and topic colours. */
@Composable
fun AuroraArt(seed: String, primary: Color, secondary: Color, modifier: Modifier = Modifier) {
    val h = seed.fold(1469598103934665603L) { acc, ch -> (acc xor ch.code.toLong()) * 1099511628211L }
    val ax = ((h ushr 8) and 0xFF) / 255f
    val ay = ((h ushr 16) and 0xFF) / 255f
    Box(modifier.background(NL.bg)) {
        Canvas(Modifier.matchParentSize().blur(60.dp)) {
            drawCircle(primary.copy(alpha = 0.75f), radius = size.minDimension * 0.75f,
                center = androidx.compose.ui.geometry.Offset(size.width * (0.2f + ax * 0.3f), size.height * (0.2f + ay * 0.2f)))
            drawCircle(secondary.copy(alpha = 0.55f), radius = size.minDimension * 0.6f,
                center = androidx.compose.ui.geometry.Offset(size.width * (0.75f - ay * 0.2f), size.height * 0.45f))
        }
        Box(Modifier.matchParentSize().background(Brush.verticalGradient(0.35f to Color.Transparent, 1f to NL.bg.copy(alpha = 0.88f))))
    }
}

@Composable
fun CountryChip(code: String?, size: Int = 13) {
    val c = NL.country(code)
    Text(code ?: "—", color = c, fontSize = size.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.background(c.copy(alpha = 0.18f), RoundedCornerShape(50)).padding(horizontal = 8.dp, vertical = 2.dp))
}

/** An outlet's logo when the API has one, else a monogram in a colour of its own. */
@Composable
fun SourceLogo(name: String?, url: String?, size: Dp = 20.dp, shape: Shape = RoundedCornerShape(size * 0.24f)) {
    val bmp = rememberRemoteImage(url?.takeUnless { it.lowercase().endsWith(".svg") })
    Box(Modifier.size(size).clip(shape), contentAlignment = Alignment.Center) {
        if (bmp != null) {
            Image(bmp, null, Modifier.matchParentSize().background(Color.White).padding(size * 0.08f), contentScale = ContentScale.Fit)
        } else {
            val label = initials(name)
            Box(Modifier.matchParentSize().background(monogramColor(name)), contentAlignment = Alignment.Center) {
                Text(label, color = Color.White, fontWeight = FontWeight.Bold,
                    fontSize = (size.value * if (label.length > 2) 0.34f else 0.44f).sp)
            }
        }
    }
}

fun initials(name: String?): String {
    val words = (name ?: "?").split(' ', '-').filter { it.isNotBlank() && !it.startsWith("(") }
    val first = words.firstOrNull() ?: return "?"
    if (first.length <= 3 && first == first.uppercase()) return first
    return words.take(2).mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("")
}

private fun monogramColor(name: String?): Color {
    val palette = listOf(0xFF5B6CFF, 0xFF0E8F63, 0xFFC8323F, 0xFF9C6F00, 0xFF1F63D1, 0xFF0B827A, 0xFF8B4FD6, 0xFFC23A6A, 0xFF2E7D99)
    val h = (name ?: "").fold(1469598103934665603L) { acc, ch -> (acc xor ch.code.toLong()) * 1099511628211L }
    return Color(palette[((h ushr 1) % palette.size).toInt()])
}

/** Small image loader with an in-memory cache; enough for logos and portraits. */
private val imageCache = java.util.concurrent.ConcurrentHashMap<String, ImageBitmap>()

@Composable
fun rememberRemoteImage(url: String?): ImageBitmap? {
    var image by remember(url) { mutableStateOf(url?.let { imageCache[it] }) }
    LaunchedEffect(url) {
        if (url == null || image != null) return@LaunchedEffect
        image = withContext(Dispatchers.IO) {
            runCatching {
                val reachable = url.replace("https://jqrgen.github.io/nordic-crypto/", "https://nordiccrypto.no/")
                URL(reachable).openStream().use { BitmapFactory.decodeStream(it) }?.asImageBitmap()
            }.getOrNull()
        }?.also { imageCache[url] = it }
    }
    return image
}

@Composable
fun QrCode(text: String, size: Dp) {
    val bmp = remember(text) {
        val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 256, 256)
        val b = Bitmap.createBitmap(m.width, m.height, Bitmap.Config.ARGB_8888)
        for (x in 0 until m.width) for (y in 0 until m.height) b.setPixel(x, y, if (m[x, y]) android.graphics.Color.BLACK else android.graphics.Color.WHITE)
        b.asImageBitmap()
    }
    Image(bmp, null, Modifier.size(size).background(Color.White, RoundedCornerShape(12.dp)).padding(6.dp))
}

@Composable
fun Glyph(size: Dp) {
    Box(Modifier.size(size).clip(RoundedCornerShape(size * 0.22f)), contentAlignment = Alignment.Center) {
        AuroraArt("nordic-crypto", Color(0xFF3DDC97), Color(0xFF8B7CF6), Modifier.matchParentSize())
        Text("✦", color = Color.White, fontSize = (size.value * 0.5f).sp)
    }
}

fun circle(): Shape = CircleShape
