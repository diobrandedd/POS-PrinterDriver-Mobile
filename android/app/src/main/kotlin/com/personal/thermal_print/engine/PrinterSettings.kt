package com.personal.thermal_print.engine

import android.content.Context
import android.content.SharedPreferences

enum class TransportType {
    BLUETOOTH,
    USB,
    TCP,
}

enum class GraphicsCommand {
    GS_V_0,
    ESC_STAR,
}

data class PrinterProfile(
    val transport: TransportType = TransportType.BLUETOOTH,
    val address: String = "",
    val displayName: String = "",
    val paperWidthMm: Int = 58,
    val graphicsCommand: GraphicsCommand = GraphicsCommand.GS_V_0,
    val autoCut: Boolean = true,
    val codePage: String = "CP437",
    val tcpPort: Int = 9100,
) {
    val dotsPerLine: Int
        get() = if (paperWidthMm >= 80) 576 else 384

    fun toMap(): Map<String, Any?> = mapOf(
        "transport" to transport.name.lowercase(),
        "address" to address,
        "displayName" to displayName,
        "paperWidthMm" to paperWidthMm,
        "graphicsCommand" to when (graphicsCommand) {
            GraphicsCommand.GS_V_0 -> "gs_v_0"
            GraphicsCommand.ESC_STAR -> "esc_star"
        },
        "autoCut" to autoCut,
        "codePage" to codePage,
        "tcpPort" to tcpPort,
        "dotsPerLine" to dotsPerLine,
    )

    companion object {
        fun fromMap(map: Map<*, *>?): PrinterProfile {
            if (map == null) return PrinterProfile()
            val transport = when ((map["transport"] as? String)?.lowercase()) {
                "usb" -> TransportType.USB
                "tcp", "network", "wifi" -> TransportType.TCP
                else -> TransportType.BLUETOOTH
            }
            val graphics = when ((map["graphicsCommand"] as? String)?.lowercase()) {
                "esc_star", "esc*" -> GraphicsCommand.ESC_STAR
                else -> GraphicsCommand.GS_V_0
            }
            return PrinterProfile(
                transport = transport,
                address = map["address"] as? String ?: "",
                displayName = map["displayName"] as? String ?: "",
                paperWidthMm = (map["paperWidthMm"] as? Number)?.toInt() ?: 58,
                graphicsCommand = graphics,
                autoCut = map["autoCut"] as? Boolean ?: true,
                codePage = map["codePage"] as? String ?: "CP437",
                tcpPort = (map["tcpPort"] as? Number)?.toInt() ?: 9100,
            )
        }
    }
}

class PrinterSettings(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(): PrinterProfile = PrinterProfile(
        transport = when (prefs.getString(KEY_TRANSPORT, "bluetooth")) {
            "usb" -> TransportType.USB
            "tcp" -> TransportType.TCP
            else -> TransportType.BLUETOOTH
        },
        address = prefs.getString(KEY_ADDRESS, "") ?: "",
        displayName = prefs.getString(KEY_DISPLAY_NAME, "") ?: "",
        paperWidthMm = prefs.getInt(KEY_PAPER_WIDTH, 58),
        graphicsCommand = when (prefs.getString(KEY_GRAPHICS, "gs_v_0")) {
            "esc_star" -> GraphicsCommand.ESC_STAR
            else -> GraphicsCommand.GS_V_0
        },
        autoCut = prefs.getBoolean(KEY_AUTO_CUT, true),
        codePage = prefs.getString(KEY_CODE_PAGE, "CP437") ?: "CP437",
        tcpPort = prefs.getInt(KEY_TCP_PORT, 9100),
    )

    fun save(profile: PrinterProfile) {
        prefs.edit()
            .putString(
                KEY_TRANSPORT,
                when (profile.transport) {
                    TransportType.USB -> "usb"
                    TransportType.TCP -> "tcp"
                    TransportType.BLUETOOTH -> "bluetooth"
                },
            )
            .putString(KEY_ADDRESS, profile.address)
            .putString(KEY_DISPLAY_NAME, profile.displayName)
            .putInt(KEY_PAPER_WIDTH, profile.paperWidthMm)
            .putString(
                KEY_GRAPHICS,
                when (profile.graphicsCommand) {
                    GraphicsCommand.ESC_STAR -> "esc_star"
                    GraphicsCommand.GS_V_0 -> "gs_v_0"
                },
            )
            .putBoolean(KEY_AUTO_CUT, profile.autoCut)
            .putString(KEY_CODE_PAGE, profile.codePage)
            .putInt(KEY_TCP_PORT, profile.tcpPort)
            .apply()
    }

    companion object {
        private const val PREFS = "thermal_print_settings"
        private const val KEY_TRANSPORT = "transport"
        private const val KEY_ADDRESS = "address"
        private const val KEY_DISPLAY_NAME = "displayName"
        private const val KEY_PAPER_WIDTH = "paperWidthMm"
        private const val KEY_GRAPHICS = "graphicsCommand"
        private const val KEY_AUTO_CUT = "autoCut"
        private const val KEY_CODE_PAGE = "codePage"
        private const val KEY_TCP_PORT = "tcpPort"
    }
}
