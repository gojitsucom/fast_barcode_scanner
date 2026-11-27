import Foundation

/// Last `capacity` frames that yielded codes, keyed by frame id.
///
/// A frame whose code set equals the newest slot's replaces that slot and keeps its id,
/// so one label held in view does not fill the ring. Only within `overwriteWindowMs` of
/// the slot's creation, so the slot keeps showing the moment the codes appeared, not
/// whatever the camera points at later while the same code stays decodable at the edge.
final class FrameRing<T> {
    private struct Slot {
        let id: Int64
        let codeValues: Set<String>
        let createdAtMs: Int64
        var frame: T
    }

    static var overwriteWindowMs: Int64 { 500 }

    private let capacity: Int
    private let nowMs: () -> Int64
    private var slots: [Slot] = []
    private let lock = NSLock()

    // Never reset, so an id handed out before clear() cannot match a later frame.
    private var nextId: Int64 = 1

    private var _generation: Int64 = 0

    init(
        capacity: Int,
        nowMs: @escaping () -> Int64 = { Int64(ProcessInfo.processInfo.systemUptime * 1000) }
    ) {
        self.capacity = capacity
        self.nowMs = nowMs
    }

    /// Changes on every `clear()`; a copy taken before a clear passes the old value to `put`.
    var generation: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return _generation
    }

    func put(codeValues: Set<String>, frame: T) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return putLocked(codeValues: codeValues, frame: frame)
    }

    /// Stores `frame` only when no `clear()` happened since `generation` was read.
    func put(codeValues: Set<String>, frame: T, generation: Int64) -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        guard generation == _generation else { return nil }
        return putLocked(codeValues: codeValues, frame: frame)
    }

    func get(_ id: Int64) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return slots.first { $0.id == id }?.frame
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        slots.removeAll()
        _generation += 1
    }

    private func putLocked(codeValues: Set<String>, frame: T) -> Int64 {
        let now = nowMs()
        if let newestIndex = slots.indices.last,
           slots[newestIndex].codeValues == codeValues,
           now - slots[newestIndex].createdAtMs <= Self.overwriteWindowMs {
            slots[newestIndex].frame = frame
            return slots[newestIndex].id
        }
        if slots.count == capacity {
            slots.removeFirst()
        }
        let slot = Slot(id: nextId, codeValues: codeValues, createdAtMs: now, frame: frame)
        nextId += 1
        slots.append(slot)
        return slot.id
    }
}
