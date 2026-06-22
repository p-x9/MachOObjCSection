//
//  ObjCProtocolList32.swift
//
//
//  Created by p-x9 on 2024/11/01
//
//

import Foundation
@_spi(Support) import MachOKit

public struct ObjCProtocolList32: ObjCProtocolListProtocol {
    public typealias Header = ObjCProtocolListHeader32
    public typealias ObjCProtocol = ObjCProtocol32

    public let offset: Int
    public let header: Header

    @_spi(Core)
    public init(ptr: UnsafeRawPointer, offset: Int) {
        self.offset = offset
        self.header = ptr.assumingMemoryBound(to: Header.self).pointee
    }
}

extension ObjCProtocolList32 {
    public func protocols(
        in machO: MachOImage
    ) -> [(MachOImage, ObjCProtocol)]? {
        _readProtocols(in: machO, pointerType: UInt32.self)
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

        let sequnece: DataSequence<UInt32> = fileHandle
            .readDataSequence(
                offset: fileOffset + numericCast(MemoryLayout<Header>.size),
                numberOfElements: numericCast(header.count)
            )

        return sequnece.enumerated()
            .map { i, value in
                UnresolvedValue(
                    fieldOffset: offset
                    + MemoryLayout<Header>.size
                    + MemoryLayout<UInt32>.stride * i,
                    value: numericCast(value)
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

                let layout: ObjCProtocol32.Layout = fileHandle.read(
                    offset: numericCast(fileOffset),
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
