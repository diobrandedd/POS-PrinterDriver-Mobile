package com.personal.thermal_print.engine

import android.graphics.Bitmap
import android.graphics.Color
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object EscPosEncoder {
    private val INIT = byteArrayOf(0x1B, 0x40)
    private val ALIGN_CENTER = byteArrayOf(0x1B, 0x61, 0x01)
    private val ALIGN_LEFT = byteArrayOf(0x1B, 0x61, 0x00)
    private val BOLD_ON = byteArrayOf(0x1B, 0x45, 0x01)
    private val BOLD_OFF = byteArrayOf(0x1B, 0x45, 0x00)
    private val FEED_LINES = byteArrayOf(0x1B, 0x64, 0x03)
    private val PARTIAL_CUT = byteArrayOf(0x1D, 0x56, 0x01)

    /**
     * ESC p m t1 t2 — pulse cash drawer kick connector.
     * Default: pin 2 (m=0), ~50ms on / ~500ms off (t units = 2ms).
     */
    fun encodeOpenCashDrawer(
        pin: Int = 0,
        onTime: Int = 0x19,
        offTime: Int = 0xFA,
    ): ByteArray {
        val m = if (pin == 1) 1 else 0
        return byteArrayOf(
            0x1B,
            0x70,
            m.toByte(),
            (onTime and 0xFF).toByte(),
            (offTime and 0xFF).toByte(),
        )
    }

    fun charsetFor(codePage: String): Charset {
        val name = when (codePage.uppercase(Locale.US)) {
            "CP437", "IBM437" -> "IBM437"
            "CP850" -> "IBM850"
            "CP852" -> "IBM852"
            "CP858" -> "IBM858"
            "CP860" -> "IBM860"
            "CP863" -> "IBM863"
            "CP865" -> "IBM865"
            "CP866" -> "IBM866"
            "WINDOWS-1252", "CP1252" -> "windows-1252"
            "UTF-8", "UTF8" -> "UTF-8"
            else -> "IBM437"
        }
        return try {
            Charset.forName(name)
        } catch (_: Exception) {
            Charsets.ISO_8859_1
        }
    }

    fun encodeText(
        text: String,
        profile: PrinterProfile,
        appendCut: Boolean = profile.autoCut,
    ): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(INIT)
        out.write(ALIGN_LEFT)
        val charset = charsetFor(profile.codePage)
        val normalized = text.replace("\r\n", "\n").replace('\r', '\n')
        for (line in normalized.split('\n')) {
            out.write(line.toByteArray(charset))
            out.write('\n'.code)
        }
        out.write(FEED_LINES)
        if (appendCut) out.write(PARTIAL_CUT)
        return out.toByteArray()
    }

    fun encodeBitmap(
        source: Bitmap,
        profile: PrinterProfile,
        appendCut: Boolean = profile.autoCut,
    ): ByteArray {
        val widthDots = profile.dotsPerLine
        val scaled = scaleToWidth(source, widthDots)
        val mono = toMono(scaled)
        if (scaled !== source) scaled.recycle()

        val out = ByteArrayOutputStream()
        out.write(INIT)
        when (profile.graphicsCommand) {
            GraphicsCommand.GS_V_0 -> writeGsV0(out, mono)
            GraphicsCommand.ESC_STAR -> writeEscStar(out, mono)
        }
        out.write(FEED_LINES)
        if (appendCut) out.write(PARTIAL_CUT)
        mono.recycle()
        return out.toByteArray()
    }

    fun encodeBitmaps(
        bitmaps: List<Bitmap>,
        profile: PrinterProfile,
    ): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(INIT)
        bitmaps.forEachIndexed { index, bmp ->
            val widthDots = profile.dotsPerLine
            val scaled = scaleToWidth(bmp, widthDots)
            val mono = toMono(scaled)
            if (scaled !== bmp) scaled.recycle()
            when (profile.graphicsCommand) {
                GraphicsCommand.GS_V_0 -> writeGsV0(out, mono)
                GraphicsCommand.ESC_STAR -> writeEscStar(out, mono)
            }
            mono.recycle()
            if (index < bitmaps.lastIndex) {
                out.write(byteArrayOf(0x1B, 0x64, 0x02))
            }
        }
        out.write(FEED_LINES)
        if (profile.autoCut) out.write(PARTIAL_CUT)
        return out.toByteArray()
    }

    fun buildTestReceipt(profile: PrinterProfile): ByteArray {
        val out = ByteArrayOutputStream()
        val charset = charsetFor(profile.codePage)
        val now = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val widthLabel = "${profile.paperWidthMm}mm / ${profile.dotsPerLine} dots"
        out.write(INIT)
        out.write(ALIGN_CENTER)
        out.write(BOLD_ON)
        out.write("Thermal Print\n".toByteArray(charset))
        out.write(BOLD_OFF)
        out.write("Personal driver (no watermark)\n".toByteArray(charset))
        out.write("--------------------------------\n".toByteArray(charset))
        out.write(ALIGN_LEFT)
        out.write("Printer: ${profile.displayName.ifBlank { profile.address.ifBlank { "not set" } }}\n".toByteArray(charset))
        out.write("Paper: $widthLabel\n".toByteArray(charset))
        out.write("Transport: ${profile.transport.name.lowercase()}\n".toByteArray(charset))
        out.write("Time: $now\n".toByteArray(charset))
        out.write("--------------------------------\n".toByteArray(charset))
        out.write("KJ-5802H and other ESC/POS\n".toByteArray(charset))
        out.write("Bluetooth / USB / Wi-Fi 9100\n".toByteArray(charset))
        out.write(FEED_LINES)
        if (profile.autoCut) out.write(PARTIAL_CUT)
        return out.toByteArray()
    }

    private fun scaleToWidth(source: Bitmap, targetWidth: Int): Bitmap {
        if (source.width == targetWidth) return source
        val ratio = targetWidth.toFloat() / source.width.toFloat()
        val targetHeight = (source.height * ratio).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true)
    }

    private fun toMono(source: Bitmap): Bitmap {
        val w = source.width
        val h = source.height
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(w * h)
        source.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) {
            val c = pixels[i]
            val a = Color.alpha(c)
            if (a < 16) {
                pixels[i] = Color.WHITE
                continue
            }
            val gray = (0.299 * Color.red(c) + 0.587 * Color.green(c) + 0.114 * Color.blue(c)).toInt()
            pixels[i] = if (gray < 160) Color.BLACK else Color.WHITE
        }
        out.setPixels(pixels, 0, w, 0, 0, w, h)
        return out
    }

    private fun writeGsV0(out: ByteArrayOutputStream, mono: Bitmap) {
        val width = mono.width
        val height = mono.height
        val widthBytes = (width + 7) / 8
        val pixels = IntArray(width * height)
        mono.getPixels(pixels, 0, width, 0, 0, width, height)

        // Chunk tall images to avoid buffer overflows on cheap printers.
        val maxRows = 255
        var y = 0
        while (y < height) {
            val sliceHeight = minOf(maxRows, height - y)
            out.write(0x1D)
            out.write('v'.code)
            out.write(0x00)
            out.write(0x00) // normal mode
            out.write(widthBytes and 0xFF)
            out.write((widthBytes shr 8) and 0xFF)
            out.write(sliceHeight and 0xFF)
            out.write((sliceHeight shr 8) and 0xFF)

            for (row in 0 until sliceHeight) {
                for (byteIndex in 0 until widthBytes) {
                    var b = 0
                    for (bit in 0 until 8) {
                        val x = byteIndex * 8 + bit
                        if (x < width) {
                            val color = pixels[(y + row) * width + x]
                            if (Color.red(color) < 128) {
                                b = b or (0x80 shr bit)
                            }
                        }
                    }
                    out.write(b)
                }
            }
            y += sliceHeight
        }
    }

    private fun writeEscStar(out: ByteArrayOutputStream, mono: Bitmap) {
        val width = mono.width
        val height = mono.height
        val pixels = IntArray(width * height)
        mono.getPixels(pixels, 0, width, 0, 0, width, height)

        var y = 0
        while (y < height) {
            val bandHeight = minOf(24, height - y)
            out.write(0x1B)
            out.write('*'.code)
            out.write(33) // 24-dot double density
            out.write(width and 0xFF)
            out.write((width shr 8) and 0xFF)

            for (x in 0 until width) {
                val column = ByteArray(3)
                for (k in 0 until bandHeight) {
                    val color = pixels[(y + k) * width + x]
                    if (Color.red(color) < 128) {
                        column[k / 8] = (column[k / 8].toInt() or (0x80 shr (k % 8))).toByte()
                    }
                }
                out.write(column)
            }
            out.write(0x0A)
            y += 24
        }
    }
}
