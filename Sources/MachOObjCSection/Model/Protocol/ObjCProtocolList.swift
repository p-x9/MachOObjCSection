//
//  ObjCProtocolList.swift
//
//
//  Created by p-x9 on 2024/05/25
//
//

import Foundation
@testable @_spi(Support) import MachOKit

public struct ObjCProtocolList64: ObjCProtocolListProtocol {
    public typealias Header = ObjCProtocolListHeader64
    public typealias ObjcProtocol = ObjCProtocol64

    public let offset: Int
    public let header: Header

    init(ptr: UnsafeRawPointer, offset: Int) {
        self.offset = offset
        self.header = ptr.assumingMemoryBound(to: Header.self).pointee
    }
}

extension ObjCProtocolList64 {
    public func protocols(
        in machO: MachOImage
    ) -> [ObjcProtocol]? {
        let ptr = machO.ptr.advanced(by: offset)
        let sequnece = MemorySequence(
            basePointer: ptr
                .advanced(by: MemoryLayout<Header>.size)
                .assumingMemoryBound(to: UInt64.self),
            numberOfElements: numericCast(header.count)
        )

        return sequnece
            .map {
                UnsafeRawPointer(bitPattern: UInt($0))!
                    .assumingMemoryBound(to: ObjCProtocol64.self)
                    .pointee
            }
    }

    public func protocols(
        in machO: MachOFile
    ) -> [ObjcProtocol]? {
        let headerStartOffset = machO.headerStartOffset/* + machO.headerStartOffsetInCache*/
        let start = headerStartOffset + offset
        let data = machO.fileHandle.readData(
            offset: numericCast(start + MemoryLayout<Header>.size),
            size: MemoryLayout<UInt64>.size * numericCast(header.count)
        )
        let sequnece: DataSequence<UInt64> = .init(
            data: data,
            numberOfElements: numericCast(header.count)
        )

        return sequnece
            .map {
                var offset = $0 & 0x7ffffffff
                if let cache = machO.cache {
                    offset = numericCast(cache.fileOffset(of: numericCast(offset) + cache.header.sharedRegionStart) ?? 0)
                }
                return machO.fileHandle.read<ObjCProtocol64>(
                    offset: numericCast(headerStartOffset) + numericCast(offset),
                    swapHandler: { _ in }
                )
            }
    }
}

public struct ObjCProtocolList32: ObjCProtocolListProtocol {
    public typealias Header = ObjCProtocolListHeader32
    public typealias ObjcProtocol = ObjCProtocol32

    public let offset: Int
    public let header: Header

    init(ptr: UnsafeRawPointer, offset: Int) {
        self.offset = offset
        self.header = ptr.assumingMemoryBound(to: Header.self).pointee
    }
}

extension ObjCProtocolList32 {
    public func protocols(
        in machO: MachOImage
    ) -> [ObjcProtocol]? {
        let ptr = machO.ptr.advanced(by: offset)
        let sequnece = MemorySequence(
            basePointer: ptr
                .advanced(by: MemoryLayout<Header>.size)
                .assumingMemoryBound(to: UInt32.self),
            numberOfElements: numericCast(header.count)
        )

        return sequnece
            .map {
                UnsafeRawPointer(bitPattern: UInt($0))!
                    .assumingMemoryBound(to: ObjCProtocol32.self)
                    .pointee
            }
    }

    public func protocols(
        in machO: MachOFile
    ) -> [ObjcProtocol]? {
        let headerStartOffset = machO.headerStartOffset/* + machO.headerStartOffsetInCache*/
        let start = headerStartOffset + offset
        let data = machO.fileHandle.readData(
            offset: numericCast(start + MemoryLayout<Header>.size),
            size: MemoryLayout<UInt32>.size * numericCast(header.count)
        )
        let sequnece: DataSequence<UInt32> = .init(
            data: data,
            numberOfElements: numericCast(header.count)
        )

        return sequnece
            .map {
                let offset = $0
                return machO.fileHandle.read<ObjCProtocol32>(
                    offset: numericCast(headerStartOffset) + numericCast(offset),
                    swapHandler: { _ in }
                )
            }
    }
}
