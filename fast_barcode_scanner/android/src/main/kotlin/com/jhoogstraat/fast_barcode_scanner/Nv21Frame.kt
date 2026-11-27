package com.jhoogstraat.fast_barcode_scanner

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.camera.core.ImageProxy
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID

/** A camera frame copied out of its [ImageProxy], so the proxy can be closed at once. */
class Nv21Frame(
    val data: ByteArray,
    val width: Int,
    val height: Int,
    val rotationDegrees: Int
) {
    fun writeJpeg(directory: File, quality: Int): File {
        val jpeg = ByteArrayOutputStream().also {
            YuvImage(data, ImageFormat.NV21, width, height, null)
                .compressToJpeg(Rect(0, 0, width, height), quality, it)
        }.toByteArray()
        val bytes = if (rotationDegrees == 0) jpeg else rotateJpeg(jpeg, quality)
        directory.mkdirs()
        return File(directory, "${UUID.randomUUID()}.jpeg").apply { writeBytes(bytes) }
    }

    private fun rotateJpeg(jpeg: ByteArray, quality: Int): ByteArray {
        val source = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
        val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
        val rotated = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        val out = ByteArrayOutputStream()
        rotated.compress(Bitmap.CompressFormat.JPEG, quality, out)
        source.recycle()
        rotated.recycle()
        return out.toByteArray()
    }

    companion object {
        const val MAX_LONG_EDGE = 1280

        fun copyOf(image: ImageProxy): Nv21Frame? {
            if (image.format != ImageFormat.YUV_420_888) return null
            val (y, u, v) = image.planes.map { YuvPlane(it.buffer, it.rowStride, it.pixelStride) }
            return yuv420ToNv21(
                image.width, image.height, image.imageInfo.rotationDegrees, y, u, v, MAX_LONG_EDGE
            )
        }
    }
}

class YuvPlane(buffer: ByteBuffer, val rowStride: Int, val pixelStride: Int) {
    // Own position, so bulk reads leave the image's buffer as other readers expect it.
    private val buffer = buffer.duplicate()
    private var rowBytes = ByteArray(0)

    /**
     * Writes [count] samples of source [row], one every [step] columns, into [dst] from
     * [dstOffset], [dstStride] apart. Reads the row in one bulk get: a per-sample
     * `ByteBuffer.get` is far slower and holds the camera's image longer.
     */
    fun readRow(row: Int, step: Int, count: Int, dst: ByteArray, dstOffset: Int, dstStride: Int) {
        if (count <= 0) return
        val sampleStride = step * pixelStride
        buffer.position(row * rowStride)
        if (sampleStride == 1 && dstStride == 1) {
            buffer.get(dst, dstOffset, count)
            return
        }
        // Ends at the last sample read: a plane's last row is often shorter than rowStride.
        val span = (count - 1) * sampleStride + 1
        if (rowBytes.size < span) rowBytes = ByteArray(span)
        buffer.get(rowBytes, 0, span)
        var out = dstOffset
        for (i in 0 until count) {
            dst[out] = rowBytes[i * sampleStride]
            out += dstStride
        }
    }
}

/** Subsamples by a whole step so the long edge fits [maxLongEdge]; keeps even sizes for NV21. */
fun yuv420ToNv21(
    width: Int,
    height: Int,
    rotationDegrees: Int,
    y: YuvPlane,
    u: YuvPlane,
    v: YuvPlane,
    maxLongEdge: Int
): Nv21Frame {
    val step = (maxOf(width, height) + maxLongEdge - 1) / maxLongEdge
    val outWidth = (width / step) and 1.inv()
    val outHeight = (height / step) and 1.inv()
    val lumaSize = outWidth * outHeight
    val data = ByteArray(lumaSize + lumaSize / 2)

    for (row in 0 until outHeight) {
        y.readRow(row * step, step, outWidth, data, row * outWidth, 1)
    }
    val chromaWidth = outWidth / 2
    for (row in 0 until outHeight / 2) {
        val rowStart = lumaSize + row * outWidth
        v.readRow(row * step, step, chromaWidth, data, rowStart, 2)
        u.readRow(row * step, step, chromaWidth, data, rowStart + 1, 2)
    }
    return Nv21Frame(data, outWidth, outHeight, rotationDegrees)
}
