package com.personal.thermal_print.transport

import java.net.InetSocketAddress
import java.net.Socket

class TcpTransport(
    private val host: String,
    private val port: Int = 9100,
) : PrintTransport {
    private var socket: Socket? = null

    override val isConnected: Boolean
        get() = socket?.isConnected == true && socket?.isClosed == false

    override fun connect() {
        if (host.isBlank()) {
            throw IllegalStateException("No network printer host configured")
        }
        disconnect()
        val s = Socket()
        s.tcpNoDelay = true
        s.connect(InetSocketAddress(host.trim(), port), 8_000)
        s.soTimeout = 15_000
        socket = s
    }

    override fun write(data: ByteArray) {
        val out = socket?.getOutputStream()
            ?: throw IllegalStateException("Network printer is not connected")
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
}
