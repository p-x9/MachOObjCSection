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

    public func list(
        in machO: MachOImage,
        forImageIndex imageIndex: Int?
    ) -> (MachOImage, List)? {
        guard let imageIndex,
              let entry = entries(in: machO).first(
                where: { $0.imageIndex == imageIndex }
              )
        else { return nil }
        return list(in: machO, for: entry)
    }
}

extension RelativeListListProtocol {
    public func entries(in machO: MachOFile) -> [Entry] {
        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forOffset: numericCast(offset)) else {
            return []
        }

        let sequence: DataSequence<Entry.Layout> = fileHandle.readDataSequence(
            offset: fileOffset + numericCast(MemoryLayout<Header>.size),
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

    public func lists(in machO: MachOFile) -> [(MachOFile, List)] {
        entries(in: machO)
            .compactMap {
                list(in: machO, for: $0)
            }
    }

    public func list(
        in machO: MachOFile,
        forImageIndex imageIndex: Int?
    ) -> (MachOFile, List)? {
        guard let imageIndex,
              let entry = entries(in: machO).first(
                where: { $0.imageIndex == imageIndex }
              )
        else { return nil }
        return list(in: machO, for: entry)
    }
}
