package com.personal.thermal_print

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import com.personal.thermal_print.engine.PrintEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity() {
    private var printChannel: PrintMethodChannel? = null
    private var pendingIncoming: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val engine = PrintEngine.get(this)
        printChannel = PrintMethodChannel(flutterEngine.dartExecutor.binaryMessenger, engine)
        pendingIncoming?.let {
            printChannel?.emitIncoming(it)
            pendingIncoming = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        val payload = parseIntent(intent) ?: return
        val channel = printChannel
        if (channel != null) {
            channel.emitIncoming(payload)
        } else {
            pendingIncoming = payload
        }
    }

    private fun parseIntent(intent: Intent): Map<String, Any?>? {
        val action = intent.action ?: return null
        val data = intent.data

        if (data != null && (data.scheme == "thermalprint" || data.scheme == "rawprint")) {
            return parseCustomScheme(data)
        }

        when (action) {
            Intent.ACTION_SEND -> {
                val type = intent.type ?: "*/*"
                if (type.startsWith("text/")) {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                    return mapOf(
                        "kind" to "text",
                        "text" to text,
                        "mimeType" to type,
                        "autoPrint" to false,
                    )
                }
                val uri = getStreamUri(intent) ?: return null
                return mapOf(
                    "kind" to kindForMime(type, uri),
                    "uri" to uri.toString(),
                    "mimeType" to type,
                    "autoPrint" to false,
                )
            }
            Intent.ACTION_VIEW, Intent.ACTION_SEND_MULTIPLE -> {
                val uri = intent.data ?: getStreamUri(intent) ?: return null
                val type = intent.type ?: contentResolver.getType(uri) ?: "*/*"
                return mapOf(
                    "kind" to kindForMime(type, uri),
                    "uri" to uri.toString(),
                    "mimeType" to type,
                    "autoPrint" to false,
                )
            }
        }
        return null
    }

    private fun parseCustomScheme(uri: Uri): Map<String, Any?> {
        val ssp = uri.schemeSpecificPart ?: ""
        // thermalprint:base64,<data>
        // thermalprint:text,<urlencoded>
        // thermalprint:data:text/plain;base64,<data>
        when {
            ssp.startsWith("base64,", ignoreCase = true) -> {
                val b64 = ssp.substringAfter(",")
                return mapOf(
                    "kind" to "raw",
                    "base64" to b64,
                    "autoPrint" to true,
                )
            }
            ssp.startsWith("text,", ignoreCase = true) -> {
                val encoded = ssp.substringAfter(",")
                val text = URLDecoder.decode(encoded, StandardCharsets.UTF_8.name())
                return mapOf(
                    "kind" to "text",
                    "text" to text,
                    "autoPrint" to true,
                )
            }
            ssp.startsWith("data:", ignoreCase = true) -> {
                val comma = ssp.indexOf(',')
                if (comma > 0) {
                    val meta = ssp.substring(5, comma)
                    val payload = ssp.substring(comma + 1)
                    val isBase64 = meta.contains(";base64", ignoreCase = true)
                    val mime = meta.substringBefore(';')
                    return when {
                        mime.startsWith("text/") && isBase64 -> mapOf(
                            "kind" to "text",
                            "text" to String(Base64.decode(payload, Base64.DEFAULT), StandardCharsets.UTF_8),
                            "mimeType" to mime,
                            "autoPrint" to true,
                        )
                        mime.startsWith("text/") -> mapOf(
                            "kind" to "text",
                            "text" to URLDecoder.decode(payload, StandardCharsets.UTF_8.name()),
                            "mimeType" to mime,
                            "autoPrint" to true,
                        )
                        mime.startsWith("image/") && isBase64 -> mapOf(
                            "kind" to "imageBytes",
                            "bytesBase64" to payload,
                            "mimeType" to mime,
                            "autoPrint" to true,
                        )
                        mime == "application/pdf" && isBase64 -> mapOf(
                            "kind" to "pdfBytes",
                            "bytesBase64" to payload,
                            "mimeType" to mime,
                            "autoPrint" to true,
                        )
                        else -> mapOf(
                            "kind" to "raw",
                            "base64" to payload,
                            "autoPrint" to true,
                        )
                    }
                }
            }
        }
        val text = URLDecoder.decode(ssp, StandardCharsets.UTF_8.name())
        return mapOf(
            "kind" to "text",
            "text" to text,
            "autoPrint" to true,
        )
    }

    private fun getStreamUri(intent: Intent): Uri? {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun kindForMime(mime: String, uri: Uri): String {
        val path = uri.toString().lowercase()
        return when {
            mime.startsWith("image/") || path.matches(Regex(".*\\.(png|jpe?g|bmp|webp)$")) -> "image"
            mime == "application/pdf" || path.endsWith(".pdf") -> "pdf"
            mime.startsWith("text/") || path.endsWith(".txt") || path.endsWith(".prn") -> "textUri"
            else -> "uri"
        }
    }
}
