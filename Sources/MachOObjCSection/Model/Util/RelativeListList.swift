//
//  RelativeListList.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/11/02
//  
//

import Foundation
@_spi(Support) import MachOKit

// https://github.com/apple-oss-distributions/objc4/blob/89543e2c0f67d38ca5211cea33f42c51500287d5/runtime/objc-runtime-new.h#L1482

public struct RelativeListListEntry: LayoutWrapper {
    public typealias Layout = relative_list_list_entry_t

    public let offset: Int
    public var layout: Layout

    public var imageIndex: Int { numericCast(layout.imageIndex) }
    public var listOffset: Int { numericCast(layout.listOffset) }
}

public protocol RelativeListListProtocol: EntrySizeListProtocol where Entry == RelativeListListEntry {
    associatedtype List

    var offset: Int { get }
    var header: EntrySizeListHeader { get }

    func lists(in machO: MachOImage) -> [(MachOImage, List)]
    func list(in machO: MachOImage, for entry: Entry) -> (MachOImage, List)?

    func lists(in machO: MachOFile) -> [(MachOFile, List)]
    func list(in machO: MachOFile, for entry: Entry) -> (MachOFile, List)?
}

extension RelativeListListProtocol {
    public static var flagMask: UInt32 { 0 }
}

extension RelativeListListProtocol {
    public func entries(in machO: MachOImage) -> [Entry] {
        let ptr = machO.ptr.advanced(by: offset)
        let sequence = MemorySequence(
            basePointer: ptr
                .advanced(by: MemoryLayout<Header>.size)
                .assumingMemoryBound(to: Entry.Layout.self),
            numberOfElements: numericCast(header.count)
        )

        let baseOffset = offset + MemoryLayout<Header>.size
        let entrySize = MemoryLayout<Entry.Layout>.size
        return sequence.enumerated()
            .map { i, layout in
                Entry(
                    offset: baseOffset + entrySize * i,
                    layout: layout
                )
            }
    }

    public func lists(in machO: MachOImage) -> [(MachOImage, List)] {
        entries(in: machO)
            .compactMap {
                list(in: machO, for: $0)
            }
    }
}

extension RelativeListListProtocol {
    public func entries(in machO: MachOFile) -> [Entry] {
        let offset = offset + machO.headerStartOffset

        var resolvedOffset: UInt64 = numericCast(offset)

        var fileHandle = machO.fileHandle

        if let (_cache, _offset) = machO.cacheAndFileOffset(
            fromStart: UInt64(offset)
        ) {
            resolvedOffset = _offset
            fileHandle = _cache.fileHandle
        }

        let sequence: DataSequence<Entry.Layout> = fileHandle.readDataSequence(
            offset: resolvedOffset + numericCast(MemoryLayout<Header>.size),
            numberOfElements: numericCast(header.count)
        )

        let baseOffset = offset + MemoryLayout<Header>.size - machO.headerStartOffset
        let entrySize = MemoryLayout<Entry.Layout>.size
        return sequence.enumerated()
            .map { i, layout in
                Entry(
                    offset: baseOffset + entrySize * i,
                    layout: layout
                )
            }
    }

    public func lists(in machO: MachOFile) -> [(MachOFile, List)] {
        entries(in: machO)
            .compactMap {
                list(in: machO, for: $0)
            }
    }
}

extension RelativeListListEntry {
    public func machO(in cache: DyldCacheLoaded) -> MachOImage? {
        cache.machO(at: imageIndex)
    }

    public func machO(in cache: DyldCache) -> MachOFile? {
        cache.machO(at: imageIndex)
    }
}
