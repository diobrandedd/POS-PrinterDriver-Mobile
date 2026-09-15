package com.personal.thermal_print

import android.os.Handler
import android.os.Looper
import com.personal.thermal_print.engine.PrintEngine
import com.personal.thermal_print.engine.PrinterProfile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class PrintMethodChannel(
    messenger: BinaryMessenger,
    private val engine: PrintEngine,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val events = EventChannel(messenger, EVENT_CHANNEL)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    init {
        channel.setMethodCallHandler(this)
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    fun emitIncoming(payload: Map<String, Any?>) {
        main.post { eventSink?.success(payload) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getProfile" -> result.success(engine.loadProfile().toMap())
            "saveProfile" -> {
                val map = call.arguments as? Map<*, *>
                engine.saveProfile(PrinterProfile.fromMap(map))
                result.success(engine.loadProfile().toMap())
            }
            "getStatus" -> result.success(engine.connectionStatus())
            "listBluetoothDevices" -> runAsync(result) { engine.listBluetoothDevices() }
            "listUsbDevices" -> runAsync(result) { engine.listUsbDevices() }
            "connect" -> runAsync(result) {
                val map = call.arguments as? Map<*, *>
                if (map != null) {
                    engine.connect(PrinterProfile.fromMap(map))
                } else {
                    engine.connect()
                }
            }
            "disconnect" -> runAsync(result) { engine.disconnect() }
            "openCashDrawer" -> runAsync(result) {
                val pin = call.argument<Int>("pin") ?: 0
                engine.openCashDrawer(pin = pin)
            }
            "printTest" -> runAsync(result) { engine.printTest() }
            "printText" -> runAsync(result) {
                val text = call.argument<String>("text")
                    ?: throw IllegalArgumentException("text required")
                engine.printText(text)
            }
            "printImage" -> runAsync(result) {
                val bytes = call.argument<ByteArray>("bytes")
                    ?: throw IllegalArgumentException("bytes required")
                engine.printImageBytes(bytes)
            }
            "printPdf" -> runAsync(result) {
                val bytes = call.argument<ByteArray>("bytes")
                    ?: throw IllegalArgumentException("bytes required")
                engine.printPdfBytes(bytes)
            }
            "printUri" -> runAsync(result) {
                val uri = call.argument<String>("uri")
                    ?: throw IllegalArgumentException("uri required")
                val mime = call.argument<String>("mimeType")
                engine.printUri(uri, mime)
            }
            "printBase64" -> runAsync(result) {
                val data = call.argument<String>("data")
                    ?: throw IllegalArgumentException("data required")
                engine.printBase64EscPos(data)
            }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post {
                    result.error("print_error", e.message ?: e.toString(), null)
                }
            }
        }
    }

    companion object {
        const val CHANNEL = "com.personal.thermal_print/printer"
        const val EVENT_CHANNEL = "com.personal.thermal_print/incoming"
    }
}
