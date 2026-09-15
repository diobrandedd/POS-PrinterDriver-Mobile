package com.personal.thermal_print.engine

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.util.Base64
import com.personal.thermal_print.transport.BluetoothSppTransport
import com.personal.thermal_print.transport.PrintTransport
import com.personal.thermal_print.transport.TcpTransport
import com.personal.thermal_print.transport.UsbTransport
import java.util.concurrent.Executors

class PrintEngine(private val context: Context) {
    private val settings = PrinterSettings(context)
    private val executor = Executors.newSingleThreadExecutor()
    private var activeTransport: PrintTransport? = null

    fun loadProfile(): PrinterProfile = settings.load()

    fun saveProfile(profile: PrinterProfile) {
        settings.save(profile)
    }

    fun connectionStatus(): Map<String, Any?> {
        val profile = settings.load()
        return mapOf(
            "connected" to (activeTransport?.isConnected == true),
            "profile" to profile.toMap(),
        )
    }

    @SuppressLint("MissingPermission")
    fun listBluetoothDevices(): List<Map<String, Any?>> {
        val adapter = bluetoothAdapter() ?: return emptyList()
        return adapter.bondedDevices?.map { device ->
            mapOf(
                "name" to (device.name ?: "Unknown"),
                "address" to device.address,
                "bonded" to true,
            )
        }?.sortedBy { it["name"] as String } ?: emptyList()
    }

    fun listUsbDevices(): List<Map<String, Any?>> = UsbTransport.listDevices(context)

    fun connect(profile: PrinterProfile? = null): Map<String, Any?> {
        val target = profile ?: settings.load()
        if (profile != null) settings.save(profile)
        disconnectInternal()
        val transport = createTransport(target)
        transport.connect()
        activeTransport = transport
        return connectionStatus()
    }

    fun disconnect(): Map<String, Any?> {
        disconnectInternal()
        return connectionStatus()
    }

    fun ensureConnected(profile: PrinterProfile = settings.load()): PrintTransport {
        val current = activeTransport
        if (current != null && current.isConnected) return current
        disconnectInternal()
        val transport = createTransport(profile)
        transport.connect()
        activeTransport = transport
        return transport
    }

    fun printRaw(bytes: ByteArray, keepOpen: Boolean = true) {
        val profile = settings.load()
        val transport = ensureConnected(profile)
        try {
            transport.write(bytes)
        } finally {
            if (!keepOpen) disconnectInternal()
        }
    }

    fun openCashDrawer(pin: Int = 0): Map<String, Any?> {
        val data = EscPosEncoder.encodeOpenCashDrawer(pin = pin)
        printRaw(data)
        return mapOf("ok" to true, "bytes" to data.size)
    }

    fun printTest(): Map<String, Any?> {
        val profile = settings.load()
        val data = EscPosEncoder.buildTestReceipt(profile)
        printRaw(data)
        return mapOf("ok" to true, "bytes" to data.size)
    }

    fun printText(text: String): Map<String, Any?> {
        val profile = settings.load()
        val data = EscPosEncoder.encodeText(text, profile)
        printRaw(data)
        return mapOf("ok" to true, "bytes" to data.size)
    }

    fun printImageBytes(bytes: ByteArray): Map<String, Any?> {
        val profile = settings.load()
        val bitmap = DocumentRenderer.decodeImage(bytes)
            ?: throw IllegalStateException("Unable to decode image")
        try {
            val data = EscPosEncoder.encodeBitmap(bitmap, profile)
            printRaw(data)
            return mapOf("ok" to true, "bytes" to data.size)
        } finally {
            bitmap.recycle()
        }
    }

    fun printPdfBytes(bytes: ByteArray): Map<String, Any?> {
        val profile = settings.load()
        val pages = DocumentRenderer.renderPdfPages(context, bytes, profile.dotsPerLine)
        if (pages.isEmpty()) throw IllegalStateException("PDF has no pages")
        try {
            val data = EscPosEncoder.encodeBitmaps(pages, profile)
            printRaw(data)
            return mapOf("ok" to true, "pages" to pages.size, "bytes" to data.size)
        } finally {
            pages.forEach { it.recycle() }
        }
    }

    fun printUri(uriString: String, mimeType: String?): Map<String, Any?> {
        val uri = Uri.parse(uriString)
        val profile = settings.load()
        val mime = mimeType ?: context.contentResolver.getType(uri) ?: ""
        return when {
            mime.startsWith("image/") || uriString.lowercase().matches(Regex(".*\\.(png|jpe?g|bmp|webp)$")) -> {
                val bitmap = DocumentRenderer.decodeImage(context, uri)
                    ?: throw IllegalStateException("Unable to open image")
                try {
                    val data = EscPosEncoder.encodeBitmap(bitmap, profile)
                    printRaw(data)
                    mapOf("ok" to true, "bytes" to data.size)
                } finally {
                    bitmap.recycle()
                }
            }
            mime == "application/pdf" || uriString.lowercase().endsWith(".pdf") -> {
                val pages = DocumentRenderer.renderPdfPages(context, uri, profile.dotsPerLine)
                if (pages.isEmpty()) throw IllegalStateException("Unable to render PDF")
                try {
                    val data = EscPosEncoder.encodeBitmaps(pages, profile)
                    printRaw(data)
                    mapOf("ok" to true, "pages" to pages.size, "bytes" to data.size)
                } finally {
                    pages.forEach { it.recycle() }
                }
            }
            mime.startsWith("text/") || uriString.lowercase().endsWith(".txt") -> {
                val text = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                    ?: throw IllegalStateException("Unable to read text")
                printText(text)
            }
            else -> throw IllegalStateException("Unsupported content type: $mime")
        }
    }

    fun printBase64EscPos(base64: String): Map<String, Any?> {
        val bytes = Base64.decode(base64, Base64.DEFAULT)
        printRaw(bytes)
        return mapOf("ok" to true, "bytes" to bytes.size)
    }

    fun printBitmaps(bitmaps: List<Bitmap>) {
        if (bitmaps.isEmpty()) throw IllegalStateException("Nothing to print")
        val profile = settings.load()
        val data = EscPosEncoder.encodeBitmaps(bitmaps, profile)
        printRaw(data, keepOpen = false)
    }

    fun runBlocking(block: PrintEngine.() -> Any?): Any? {
        val future = executor.submit<Any?> { block(this) }
        return future.get()
    }

    private fun createTransport(profile: PrinterProfile): PrintTransport {
        return when (profile.transport) {
            TransportType.BLUETOOTH -> BluetoothSppTransport(context, profile.address)
            TransportType.USB -> UsbTransport(context, profile.address)
            TransportType.TCP -> TcpTransport(profile.address, profile.tcpPort)
        }
    }

    private fun disconnectInternal() {
        try {
            activeTransport?.disconnect()
        } catch (_: Exception) {
        }
        activeTransport = null
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.getSystemService(BluetoothManager::class.java)?.adapter
        } else {
            @Suppress("DEPRECATION")
            BluetoothAdapter.getDefaultAdapter()
        }
    }

    companion object {
        @Volatile
        private var instance: PrintEngine? = null

        fun get(context: Context): PrintEngine {
            return instance ?: synchronized(this) {
                instance ?: PrintEngine(context.applicationContext).also { instance = it }
            }
        }
    }
}
