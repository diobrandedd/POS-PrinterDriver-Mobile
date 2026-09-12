package com.personal.thermal_print.service

import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintJob
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.personal.thermal_print.engine.PrintEngine
import com.personal.thermal_print.engine.PrinterSettings
import java.util.ArrayList

class ThermalPrintService : PrintService() {
    override fun onCreatePrinterDiscoverySession(): PrinterDiscoverySession {
        return object : PrinterDiscoverySession() {
            override fun onStartPrinterDiscovery(priorityList: MutableList<PrinterId>) {
                addPrinters(listOf(buildPrinterInfo(generatePrinterId(PRINTER_LOCAL_ID))))
            }

            override fun onStopPrinterDiscovery() {}

            override fun onValidatePrinters(printerIds: MutableList<PrinterId>) {
                val infos = ArrayList<PrinterInfo>()
                for (id in printerIds) {
                    infos.add(buildPrinterInfo(id))
                }
                addPrinters(infos)
            }

            override fun onStartPrinterStateTracking(printerId: PrinterId) {
                addPrinters(listOf(buildPrinterInfo(printerId)))
            }

            override fun onStopPrinterStateTracking(printerId: PrinterId) {}

            override fun onDestroy() {}
        }
    }

    override fun onRequestCancelPrintJob(printJob: PrintJob) {
        printJob.cancel()
    }

    override fun onPrintJobQueued(printJob: PrintJob) {
        Thread {
            try {
                printJob.start()
                val document = printJob.document
                    ?: throw IllegalStateException("Print document missing")
                val pfd = document.data
                    ?: throw IllegalStateException("Print document data missing")
                val bitmaps = renderPdf(pfd)
                if (bitmaps.isEmpty()) {
                    throw IllegalStateException("No pages to print")
                }
                try {
                    PrintEngine.get(applicationContext).printBitmaps(bitmaps)
                } finally {
                    bitmaps.forEach { it.recycle() }
                }
                printJob.complete()
            } catch (e: Exception) {
                printJob.fail(e.message)
            }
        }.start()
    }

    private fun buildPrinterInfo(printerId: PrinterId): PrinterInfo {
        val profile = PrinterSettings(applicationContext).load()
        val label = profile.displayName.ifBlank {
            when {
                profile.address.isNotBlank() -> "Thermal (${profile.address})"
                else -> "Thermal Printer"
            }
        }
        val media = if (profile.paperWidthMm >= 80) {
            PrintAttributes.MediaSize("THERMAL_80", "Thermal 80mm", 3149, 11693)
        } else {
            PrintAttributes.MediaSize("THERMAL_58", "Thermal 58mm", 2267, 11693)
        }
        val caps = PrinterCapabilitiesInfo.Builder(printerId)
            .addMediaSize(media, true)
            .addResolution(
                PrintAttributes.Resolution("203dpi", "203dpi", 203, 203),
                true,
            )
            .setColorModes(
                PrintAttributes.COLOR_MODE_MONOCHROME,
                PrintAttributes.COLOR_MODE_MONOCHROME,
            )
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .build()

        return PrinterInfo.Builder(printerId, label, PrinterInfo.STATUS_IDLE)
            .setCapabilities(caps)
            .setDescription("ESC/POS thermal via Thermal Print (no watermark)")
            .build()
    }

    private fun renderPdf(pfd: ParcelFileDescriptor): List<Bitmap> {
        val profile = PrinterSettings(applicationContext).load()
        val targetWidth = profile.dotsPerLine
        return PdfRenderer(pfd).use { renderer ->
            val pages = mutableListOf<Bitmap>()
            for (i in 0 until renderer.pageCount) {
                renderer.openPage(i).use { page ->
                    val scale = targetWidth.toFloat() / page.width.toFloat()
                    val height = (page.height * scale).toInt().coerceAtLeast(1)
                    val bitmap = Bitmap.createBitmap(targetWidth, height, Bitmap.Config.ARGB_8888)
                    Canvas(bitmap).drawColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                    pages.add(bitmap)
                }
            }
            pages
        }
    }

    companion object {
        private const val PRINTER_LOCAL_ID = "thermal_default"
    }
}
