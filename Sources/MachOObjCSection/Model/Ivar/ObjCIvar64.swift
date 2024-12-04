//
//  ObjCIvar.swift
//
//
//  Created by p-x9 on 2024/08/21
//  
//

import Foundation
@_spi(Support) import MachOKit

// https://github.com/apple-oss-distributions/dyld/blob/25174f1accc4d352d9e7e6294835f9e6e9b3c7bf/common/ObjCVisitor.h#L328
public struct ObjCIvar64: LayoutWrapper, ObjCIvarProtocol {
    public struct Layout: _ObjCIvarLayoutProtocol {
        public typealias Pointer = UInt64

        public let offset: Pointer  // uint32_t*
        public let name: Pointer    // const char *
        public let type: Pointer    // const char *
        public let alignment: UInt32
        public let size: UInt32
    }

    public var layout: Layout
    public var offset: Int

    @_spi(Core)
    public init(layout: Layout, offset: Int) {
        self.layout = layout
        self.offset = offset
    }

    public func layoutOffset(of field: LayoutField) -> Int {
        let keyPath: PartialKeyPath<Layout>

        switch field {
        case .offset: keyPath = \.offset
        case .name: keyPath = \.name
        case .type: keyPath = \.type
        case .alignment: keyPath = \.alignment
        case .size: keyPath = \.size
        }

        return layoutOffset(of: keyPath)
    }
}

extension ObjCIvar64 {
    public func offset(in machO: MachOFile) -> UInt32? {
        let headerStartOffset = machO.headerStartOffset
        var offset: UInt64 = numericCast(layout.offset & 0x7ffffffff) + numericCast(headerStartOffset)

        if let resolved = resolveRebase(.offset, in: machO) {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
//        if isBind(\.offset, in: machO) { return nil }

        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }

        return machO.fileHandle
            .readData(
                offset: offset,
                size: MemoryLayout<UInt32>.size
            ).withUnsafeBytes {
                $0.load(as: UInt32.self)
            }
    }

    public func name(in machO: MachOFile) -> String? {
        let headerStartOffset = machO.headerStartOffset
        var offset: UInt64 = numericCast(layout.name & 0x7ffffffff) + numericCast(headerStartOffset)

        if let resolved = resolveRebase(.name, in: machO) {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
//        if isBind(\.name, in: machO) { return nil }

        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }

        return machO.fileHandle.readString(
            offset: offset
        )
    }

    public func type(in machO: MachOFile) -> String? {
        let headerStartOffset = machO.headerStartOffset
        var offset: UInt64 = numericCast(layout.type & 0x7ffffffff) + numericCast(headerStartOffset)

        if let resolved = resolveRebase(.type, in: machO) {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
//        if isBind(\.type, in: machO) { return nil }

        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }

        return machO.fileHandle.readString(
            offset: offset
        )
    }
}
