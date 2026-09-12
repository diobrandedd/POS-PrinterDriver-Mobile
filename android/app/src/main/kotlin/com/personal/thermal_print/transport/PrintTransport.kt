package com.personal.thermal_print.transport

interface PrintTransport {
    val isConnected: Boolean
    fun connect()
    fun write(data: ByteArray)
    fun disconnect()
}
