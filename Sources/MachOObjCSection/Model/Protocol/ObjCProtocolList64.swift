//
//  ObjCProtocolList.swift
//
//
//  Created by p-x9 on 2024/05/25
//
//

import Foundation
@_spi(Support) import MachOKit

public struct ObjCProtocolList64: ObjCProtocolListProtocol {
    public typealias Header = ObjCProtocolListHeader64
    public typealias ObjCProtocol = ObjCProtocol64

    public let offset: Int
    public let header: Header

    @_spi(Core)
    public init(offset: Int, header: Header) {
        self.offset = offset
        self.header = header
    }
}

extension ObjCProtocolList64 {
    @_spi(Core)
    public init(ptr: UnsafeRawPointer, offset: Int) {
        self.offset = offset
        self.header = ptr.assumingMemoryBound(to: Header.self).pointee
    }
}

extension ObjCProtocolList64 {
    public func protocols(
        in machO: MachOImage
    ) -> [(MachOImage, ObjCProtocol)]? {
        _readProtocols(in: machO, pointerType: UInt64.self)
    }

    public func protocols(
        in machO: MachOFile
    ) -> [(MachOFile, ObjCProtocol)]? {
        guard !isListOfLists else {
            assertionFailure()
            return nil
        }

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forOffset: numericCast(offset)) else {
            return nil
        }

        let sequnece: DataSequence<UInt64> = fileHandle
            .readDataSequence(
                offset: fileOffset + numericCast(MemoryLayout<Header>.size),
                numberOfElements: numericCast(header.count)
            )

        return sequnece.enumerated()
            .map { i, value in
                UnresolvedValue(
                    fieldOffset: offset
                    + MemoryLayout<Header>.size
                    + MemoryLayout<UInt64>.stride * i,
                    value: value
                )
            }
            .compactMap { unresolved in
                let resolved = machO.resolveRebase(unresolved)

                guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
                    return nil
                }

                var targetMachO = machO
                if !targetMachO.contains(unslidAddress: resolved.address),
                   let cache = machO.cache(for: resolved.address),
                   let machO = cache.machO(containing: resolved.address) {
                    targetMachO = machO
                }

                let layout: ObjCProtocol64.Layout = fileHandle.read(
                    offset:  numericCast(fileOffset),
                    swapHandler: { _ in }
                )
                let `protocol`: ObjCProtocol = .init(
                    layout: layout,
                    offset: numericCast(resolved.offset)
                )
                return (targetMachO, `protocol`)
            }
    }
}
