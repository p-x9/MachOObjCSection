//
//  ObjCMethodRelativeListList.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/11/02
//
//

import Foundation
@_spi(Support) import MachOKit

public struct ObjCMethodRelativeListList: RelativeListListProtocol {
    public typealias List = ObjCMethodList

    public let offset: Int
    public let header: Header
}

extension ObjCMethodRelativeListList {
    init(
        ptr: UnsafeRawPointer,
        offset: Int
    ) {
        self.offset = offset
        self.header = ptr.assumingMemoryBound(to: Header.self).pointee
    }

    public func list(in machO: MachOImage, for entry: Entry) -> (MachOImage, List)? {
        let offset = entry.offset + entry.listOffset
        let ptr = machO.ptr.advanced(by: offset)

#if canImport(MachO)
        guard let cache: DyldCacheLoaded = .current else { return nil }
        guard let machO = cache.machO(at: entry.imageIndex) else { return nil }

        let list = List(
            ptr: ptr,
            offset: .init(bitPattern: ptr) - .init(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )

        return (machO, list)
#else
        return nil
#endif
    }
}

extension ObjCMethodRelativeListList {
    public func list(in machO: MachOFile, for entry: Entry) -> (MachOFile, List)? {
        let offset: UInt64 = numericCast(entry.offset + entry.listOffset)

        guard let (cache, resolvedOffset) = machO.cacheAndFileOffset(fromStart: offset) else {
            return nil
        }

        guard let machO = cache._machO(at: entry.imageIndex)?.value else { return nil }

        let header: List.Header = cache.fileHandle.read(offset: resolvedOffset)
        let list = List(
            offset: numericCast(offset),
            header: header,
            is64Bit: machO.is64Bit
        )

        return (machO, list)
    }
}
