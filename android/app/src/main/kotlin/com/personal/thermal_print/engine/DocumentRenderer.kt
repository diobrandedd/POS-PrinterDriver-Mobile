package com.personal.thermal_print.engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileOutputStream

object DocumentRenderer {
    fun decodeImage(bytes: ByteArray): Bitmap? {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    fun decodeImage(context: Context, uri: Uri): Bitmap? {
        return context.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    }

    fun renderPdfPages(context: Context, uri: Uri, targetWidth: Int): List<Bitmap> {
        val descriptor = openDescriptor(context, uri) ?: return emptyList()
        return descriptor.use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                val pages = mutableListOf<Bitmap>()
                for (i in 0 until renderer.pageCount) {
                    renderer.openPage(i).use { page ->
                        val scale = targetWidth.toFloat() / page.width.toFloat()
                        val height = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(targetWidth, height, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(bitmap)
                        canvas.drawColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                        pages.add(bitmap)
                    }
                }
                pages
            }
        }
    }

    fun renderPdfPages(context: Context, bytes: ByteArray, targetWidth: Int): List<Bitmap> {
        val temp = File.createTempFile("thermal_pdf_", ".pdf", context.cacheDir)
        try {
            FileOutputStream(temp).use { it.write(bytes) }
            val pfd = ParcelFileDescriptor.open(temp, ParcelFileDescriptor.MODE_READ_ONLY)
            return pfd.use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    val pages = mutableListOf<Bitmap>()
                    for (i in 0 until renderer.pageCount) {
                        renderer.openPage(i).use { page ->
                            val scale = targetWidth.toFloat() / page.width.toFloat()
                            val height = (page.height * scale).toInt().coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(targetWidth, height, Bitmap.Config.ARGB_8888)
                            val canvas = Canvas(bitmap)
                            canvas.drawColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                            pages.add(bitmap)
                        }
                    }
                    pages
                }
            }
        } finally {
            temp.delete()
        }
    }

    private fun openDescriptor(context: Context, uri: Uri): ParcelFileDescriptor? {
        return try {
            context.contentResolver.openFileDescriptor(uri, "r")
        } catch (_: Exception) {
            null
        }
    }
}
