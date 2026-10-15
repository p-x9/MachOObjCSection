//
//  ObjCIvarList64.swift
//
//
//  Created by p-x9 on 2024/08/21
//
//

import Foundation
@_spi(Support) import MachOKit

public struct ObjCIvarList64: ObjCIvarListProtocol {
    public typealias ObjCIvar = ObjCIvar64
    public typealias Entry = ObjCIvar

    /// Position of this list.
    ///
    /// The origin depends on where the Mach-O comes from.
    /// - Mach-O file: file offset from the start of the Mach-O header.
    /// - Mach-O in a dyld cache file: offset in the address space from the start (header) of the main cache.
    /// - Loaded Mach-O (`MachOImage`): offset from the start of the Mach-O header.
    public let offset: Int
    public let header: Header

    @_spi(Core)
    public init(
        header: Header,
        offset: Int
    ) {
        self.header = header
        self.offset = offset
    }
}

extension ObjCIvarList64 {
    public func ivars(in machO: MachOFile) -> [ObjCIvar]? {
        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forOffset: numericCast(offset)) else {
            return []
        }

        let size = MemoryLayout<ObjCIvar.Layout>.size
        let sequence: DataSequence<ObjCIvar.Layout> = fileHandle
            .readDataSequence(
                offset: fileOffset + numericCast(MemoryLayout<Header>.size),
                numberOfElements: count
            )
        return sequence.enumerated()
            .map {
                .init(
                    layout: $1,
                    offset: offset + MemoryLayout<Header>.size + size * $0
                )
            }
    }
}
