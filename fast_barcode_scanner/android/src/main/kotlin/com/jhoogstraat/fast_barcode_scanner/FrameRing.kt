package com.jhoogstraat.fast_barcode_scanner

/**
 * Last [capacity] frames that yielded codes, keyed by frame id.
 *
 * A frame whose code set equals the newest slot's replaces that slot and keeps its id,
 * so one label held in view does not fill the ring. Only within [OVERWRITE_WINDOW_MS] of
 * the slot's creation, so the slot keeps showing the moment the codes appeared, not
 * whatever the camera points at later while the same code stays decodable at the edge.
 */
class FrameRing<T>(
    private val capacity: Int,
    private val nowMs: () -> Long = { System.nanoTime() / 1_000_000 },
) {
    private class Slot<T>(
        val id: Long,
        val codeValues: Set<String>,
        val createdAtMs: Long,
        var frame: T,
    )

    private val slots = ArrayDeque<Slot<T>>()

    // Never reset, so an id handed out before clear() cannot match a later frame.
    private var nextId = 1L

    /** Changes on every [clear]; a copy taken before a clear passes the old value to [put]. */
    @get:Synchronized
    var generation = 0L
        private set

    @Synchronized
    fun put(codeValues: Set<String>, frame: T): Long {
        val now = nowMs()
        val newest = slots.lastOrNull()
        if (newest != null && newest.codeValues == codeValues &&
            now - newest.createdAtMs <= OVERWRITE_WINDOW_MS
        ) {
            newest.frame = frame
            return newest.id
        }
        if (slots.size == capacity) slots.removeFirst()
        val slot = Slot(nextId++, codeValues, now, frame)
        slots.addLast(slot)
        return slot.id
    }

    /** Stores [frame] only when no [clear] happened since [generation] was read. */
    @Synchronized
    fun put(codeValues: Set<String>, frame: T, generation: Long): Long? =
        if (generation == this.generation) put(codeValues, frame) else null

    @Synchronized
    fun get(id: Long): T? = slots.firstOrNull { it.id == id }?.frame

    @Synchronized
    fun clear() {
        slots.clear()
        generation++
    }

    companion object {
        const val OVERWRITE_WINDOW_MS = 500L
    }
}
