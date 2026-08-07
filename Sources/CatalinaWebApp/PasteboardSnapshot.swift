import AppKit
import Foundation

struct PasteboardSnapshot {
    private struct Item {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }

    private let items: [Item]

    static func capture(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let capturedItems = (pasteboard.pasteboardItems ?? []).map { pasteboardItem -> Item in
            let values = pasteboardItem.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = pasteboardItem.data(forType: type) else {
                    return nil
                }
                return (type, data)
            }
            return Item(values: values)
        }
        return PasteboardSnapshot(items: capturedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard !items.isEmpty else {
            return
        }

        let restoredItems: [NSPasteboardItem] = items.map { item in
            let pasteboardItem = NSPasteboardItem()
            for (type, data) in item.values {
                pasteboardItem.setData(data, forType: type)
            }
            return pasteboardItem
        }
        _ = pasteboard.writeObjects(restoredItems)
    }
}
