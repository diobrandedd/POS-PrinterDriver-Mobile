package com.personal.thermal_print.transport

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class UsbTransport(
    private val context: Context,
    private val deviceName: String,
) : PrintTransport {
    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var connection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var outEndpoint: UsbEndpoint? = null

    override val isConnected: Boolean
        get() = connection != null && outEndpoint != null

    override fun connect() {
        disconnect()
        val device = findDevice()
            ?: throw IllegalStateException("USB printer not found: $deviceName")
        if (!usbManager.hasPermission(device)) {
            requestPermission(device)
            if (!usbManager.hasPermission(device)) {
                throw IllegalStateException("USB permission denied for ${device.deviceName}")
            }
        }

        val intf = pickInterface(device)
            ?: throw IllegalStateException("No usable USB interface on printer")
        val endpoint = pickOutEndpoint(intf)
            ?: throw IllegalStateException("No USB OUT endpoint on printer")

        val conn = usbManager.openDevice(device)
            ?: throw IllegalStateException("Unable to open USB device")
        if (!conn.claimInterface(intf, true)) {
            conn.close()
            throw IllegalStateException("Unable to claim USB interface")
        }
        connection = conn
        usbInterface = intf
        outEndpoint = endpoint
    }

    override fun write(data: ByteArray) {
        val conn = connection ?: throw IllegalStateException("USB printer is not connected")
        val endpoint = outEndpoint ?: throw IllegalStateException("USB printer is not connected")
        var offset = 0
        while (offset < data.size) {
            val chunk = minOf(endpoint.maxPacketSize.coerceAtLeast(64), data.size - offset)
            val written = conn.bulkTransfer(endpoint, data, offset, chunk, 5000)
            if (written <= 0) {
                throw IllegalStateException("USB write failed at offset $offset")
            }
            offset += written
        }
    }

    override fun disconnect() {
        try {
            val conn = connection
            val intf = usbInterface
            if (conn != null && intf != null) {
                conn.releaseInterface(intf)
            }
            conn?.close()
        } catch (_: Exception) {
        }
        connection = null
        usbInterface = null
        outEndpoint = null
    }

    private fun findDevice(): UsbDevice? {
        val devices = usbManager.deviceList.values
        if (deviceName.isBlank()) {
            return devices.firstOrNull { looksLikePrinter(it) } ?: devices.firstOrNull()
        }
        return devices.firstOrNull {
            it.deviceName == deviceName ||
                "${it.vendorId}:${it.productId}" == deviceName ||
                it.productName?.equals(deviceName, ignoreCase = true) == true
        }
    }

    private fun looksLikePrinter(device: UsbDevice): Boolean {
        if (device.deviceClass == UsbConstants.USB_CLASS_PRINTER) return true
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == UsbConstants.USB_CLASS_PRINTER) return true
        }
        return false
    }

    private fun pickInterface(device: UsbDevice): UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (pickOutEndpoint(intf) != null) return intf
        }
        return if (device.interfaceCount > 0) device.getInterface(0) else null
    }

    private fun pickOutEndpoint(intf: UsbInterface): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.direction == UsbConstants.USB_DIR_OUT &&
                ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK
            ) {
                return ep
            }
        }
        return null
    }

    private fun requestPermission(device: UsbDevice) {
        val latch = CountDownLatch(1)
        val action = context.packageName + ".USB_PERMISSION"
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == action) {
                    latch.countDown()
                }
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val permissionIntent = PendingIntent.getBroadcast(context, 0, Intent(action), flags)
        usbManager.requestPermission(device, permissionIntent)
        latch.await(15, TimeUnit.SECONDS)
        try {
            context.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
    }

    companion object {
        fun listDevices(context: Context): List<Map<String, Any?>> {
            val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
            return manager.deviceList.values.map { device ->
                mapOf(
                    "deviceName" to device.deviceName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "productName" to (device.productName ?: "USB printer"),
                    "hasPermission" to manager.hasPermission(device),
                )
            }
        }
    }
}
