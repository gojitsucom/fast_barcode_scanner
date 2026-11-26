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
}
