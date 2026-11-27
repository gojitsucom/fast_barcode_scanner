package com.jhoogstraat.fast_barcode_scanner

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.ByteBuffer

class Nv21FrameTest {

    private fun plane(vararg bytes: Int, rowStride: Int, pixelStride: Int) =
        YuvPlane(ByteBuffer.wrap(ByteArray(bytes.size) { bytes[it].toByte() }), rowStride, pixelStride)

    @Test
    fun `frame within bound copies every pixel as NV21`() {
        val y = plane(1, 2, 3, 4, rowStride = 2, pixelStride = 1)
        // Interleaved chroma: U and V share one buffer at offsets 0 and 1.
        val u = plane(20, 10, rowStride = 2, pixelStride = 2)
        val v = plane(10, rowStride = 2, pixelStride = 2)

        val frame = yuv420ToNv21(2, 2, 90, y, u, v, maxLongEdge = 1280)

        assertEquals(2, frame.width)
        assertEquals(2, frame.height)
        assertEquals(90, frame.rotationDegrees)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4, 10, 20), frame.data)
    }

    @Test
    fun `long edge over bound is subsampled to fit`() {
        val y = plane(*IntArray(16) { it }, rowStride = 4, pixelStride = 1)
        val u = plane(50, 51, 52, 53, rowStride = 2, pixelStride = 1)
        val v = plane(60, 61, 62, 63, rowStride = 2, pixelStride = 1)

        val frame = yuv420ToNv21(4, 4, 0, y, u, v, maxLongEdge = 2)

        assertEquals(2, frame.width)
        assertEquals(2, frame.height)
        assertArrayEquals(byteArrayOf(0, 2, 8, 10, 60, 50), frame.data)
    }

    @Test
    fun `odd size with row padding and step over 1 matches per-sample copy`() {
        val width = 13
        val height = 9
        val chromaWidth = (width + 1) / 2
        val chromaHeight = (height + 1) / 2
        val lumaRowStride = 16
        val chromaRowStride = 16
        // Real planes end at their last sample, so the last row is shorter than rowStride.
        val luma = ByteArray((height - 1) * lumaRowStride + width) { (it * 7).toByte() }
        val chroma = ByteArray((chromaHeight - 1) * chromaRowStride + chromaWidth * 2) {
            (it * 3 + 1).toByte()
        }
        val y = YuvPlane(ByteBuffer.wrap(luma), lumaRowStride, 1)
        val u = YuvPlane(interleavedPlane(chroma, 0), chromaRowStride, 2)
        val v = YuvPlane(interleavedPlane(chroma, 1), chromaRowStride, 2)

        val frame = yuv420ToNv21(width, height, 0, y, u, v, maxLongEdge = 5)

        assertEquals(4, frame.width)
        assertEquals(2, frame.height)
        val expected = perSampleNv21(
            frame.width, frame.height, step = 3,
            luma, lumaRowStride, chroma, chromaRowStride,
        )
        assertArrayEquals(expected, frame.data)
    }

    @Test
    fun `copy leaves the plane buffer position untouched`() {
        val buffer = ByteBuffer.wrap(ByteArray(16) { it.toByte() })
        val y = YuvPlane(buffer, 4, 1)
        val chroma = YuvPlane(ByteBuffer.wrap(ByteArray(4)), 2, 1)

        yuv420ToNv21(4, 4, 0, y, chroma, chroma, maxLongEdge = 1280)

        assertEquals(0, buffer.position())
    }

    private fun interleavedPlane(chroma: ByteArray, offset: Int): ByteBuffer {
        val length = chroma.size - 1
        return ByteBuffer.wrap(chroma, offset, length).slice()
    }

    private fun perSampleNv21(
        outWidth: Int,
        outHeight: Int,
        step: Int,
        luma: ByteArray,
        lumaRowStride: Int,
        chroma: ByteArray,
        chromaRowStride: Int,
    ): ByteArray {
        val out = ByteArray(outWidth * outHeight * 3 / 2)
        var index = 0
        for (row in 0 until outHeight) {
            for (column in 0 until outWidth) {
                out[index++] = luma[row * step * lumaRowStride + column * step]
            }
        }
        for (row in 0 until outHeight / 2) {
            for (column in 0 until outWidth / 2) {
                val uAt = row * step * chromaRowStride + column * step * 2
                out[index++] = chroma[uAt + 1]
                out[index++] = chroma[uAt]
            }
        }
        return out
    }
}
