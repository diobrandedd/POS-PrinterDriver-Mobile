package com.personal.thermal_print.transport

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Build
import java.io.IOException
import java.util.UUID

class BluetoothSppTransport(
    private val context: Context,
    private val address: String,
) : PrintTransport {
    private var socket: BluetoothSocket? = null

    override val isConnected: Boolean
        get() = socket?.isConnected == true

    @SuppressLint("MissingPermission")
    override fun connect() {
        if (address.isBlank()) {
            throw IllegalStateException("No Bluetooth printer address configured")
        }
        disconnect()
        val adapter = bluetoothAdapter()
            ?: throw IllegalStateException("Bluetooth is not available on this device")
        if (!adapter.isEnabled) {
            throw IllegalStateException("Bluetooth is turned off")
        }
        val device = try {
            adapter.getRemoteDevice(address)
        } catch (e: IllegalArgumentException) {
            throw IllegalStateException("Invalid Bluetooth address: $address", e)
        }

        val spp = UUID.fromString(SPP_UUID)
        var connected: BluetoothSocket? = null
        try {
            connected = device.createRfcommSocketToServiceRecord(spp)
            adapter.cancelDiscovery()
            connected.connect()
        } catch (first: IOException) {
            try {
                connected?.close()
            } catch (_: Exception) {
            }
            // Fallback used by many cheap ESC/POS modules.
            connected = fallbackSocket(device)
            adapter.cancelDiscovery()
            connected.connect()
        }
        socket = connected
    }

    override fun write(data: ByteArray) {
        val out = socket?.outputStream
            ?: throw IllegalStateException("Bluetooth printer is not connected")
        out.write(data)
        out.flush()
    }

    override fun disconnect() {
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
    }

    @SuppressLint("MissingPermission")
    private fun fallbackSocket(device: BluetoothDevice): BluetoothSocket {
        val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
        return method.invoke(device, 1) as BluetoothSocket
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val manager = context.getSystemService(BluetoothManager::class.java)
            manager?.adapter
        } else {
            @Suppress("DEPRECATION")
            BluetoothAdapter.getDefaultAdapter()
        }
    }

    companion object {
        private const val SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"
    }
}
