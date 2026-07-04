import EventKit
import Foundation

// Request Calendar access (one-time prompt on first run).
let store = EKEventStore()
let sem = DispatchSemaphore(value: 0)
var granted = false

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { ok, _ in granted = ok; sem.signal() }
} else {
    store.requestAccess(to: .event) { ok, _ in granted = ok; sem.signal() }
}
sem.wait()

guard granted else {
    FileHandle.standardError.write(Data("calendar access not granted\n".utf8))
    exit(1)
}

let now = Date()
// Look back 1h so an in-progress meeting still surfaces; look ahead 12h.
let lookback = now.addingTimeInterval(-3600)
let lookahead = now.addingTimeInterval(12 * 3600)
let predicate = store.predicateForEvents(withStart: lookback, end: lookahead, calendars: nil)

// Selection logic: among events still relevant (endDate > now, not all-day),
// if any are already in progress (startDate <= now) prefer the one that
// started most recently — that's the meeting you most likely just joined when
// concurrent meetings overlap. Otherwise pick the earliest upcoming event.
let candidates = store.events(matching: predicate)
    .filter { !$0.isAllDay && $0.endDate > now }
let ongoing = candidates.filter { $0.startDate <= now }

let next: EKEvent?
if !ongoing.isEmpty {
    next = ongoing.max(by: { $0.startDate < $1.startDate })
} else {
    next = candidates.min(by: { $0.startDate < $1.startDate })
}

if let event = next {
    let startEpoch = Int(event.startDate.timeIntervalSince1970)
    let endEpoch = Int(event.endDate.timeIntervalSince1970)
    let title = (event.title ?? "")
        .replacingOccurrences(of: "\t", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
    print("\(startEpoch)\t\(endEpoch)\t\(title)")
}