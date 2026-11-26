package com.jhoogstraat.fast_barcode_scanner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class FrameRingTest {

    @Test
    fun `new code set takes a new id`() {
        val ring = FrameRing<String>(16)

        val first = ring.put(setOf("a"), "f1")
        val second = ring.put(setOf("b"), "f2")

        assertNotEquals(first, second)
        assertEquals("f1", ring.get(first))
        assertEquals("f2", ring.get(second))
    }

    @Test
    fun `equal code set overwrites newest slot and keeps its id`() {
        val ring = FrameRing<String>(16)

        val first = ring.put(setOf("a"), "f1")
        val second = ring.put(setOf("a"), "f2")

        assertEquals(first, second)
        assertEquals("f2", ring.get(first))
    }

    @Test
    fun `seventeenth distinct set evicts the oldest`() {
        val ring = FrameRing<String>(16)

        val ids = (0 until 17).map { ring.put(setOf("code$it"), "f$it") }

        assertNull(ring.get(ids.first()))
        ids.drop(1).forEach { assertNotNull(ring.get(it)) }
    }

    @Test
    fun `clear empties the ring`() {
        val ring = FrameRing<String>(16)
        val id = ring.put(setOf("a"), "f1")

        ring.clear()

        assertNull(ring.get(id))
    }

    @Test
    fun `put from before clear is dropped`() {
        val ring = FrameRing<String>(16)
        val generation = ring.generation

        ring.clear()
        val id = ring.put(setOf("a"), "f1", generation)

        assertNull(id)
        assertNull(ring.get(1L))
    }

    @Test
    fun `put from current generation is kept`() {
        val ring = FrameRing<String>(16)
        ring.clear()

        val id = ring.put(setOf("a"), "f1", ring.generation)

        assertEquals("f1", ring.get(id!!))
    }
}
