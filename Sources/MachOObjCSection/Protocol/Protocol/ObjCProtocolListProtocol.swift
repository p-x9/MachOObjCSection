//
//  ObjCProtocolListProtocol.swift
//
//
//  Created by p-x9 on 2024/07/19
//
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCProtocolListHeaderProtocol {
    var count: Int { get }
}

public protocol ObjCProtocolListProtocol {
    associatedtype Header: ObjCProtocolListHeaderProtocol
    associatedtype ObjCProtocol: ObjCProtocolProtocol

    /// Position of this list.
    ///
    /// The origin depends on where the Mach-O comes from.
    /// - Mach-O file: file offset from the start of the Mach-O header.
    /// - Mach-O in a dyld cache file: offset in the address space from the start (header) of the main cache.
    /// - Loaded Mach-O (`MachOImage`): offset from the start of the Mach-O header.
    var offset: Int { get }
    var header: Header { get }

    @_spi(Core)
    init(offset: Int, header: Header)

    @_spi(Core)
    init(ptr: UnsafeRawPointer, offset: Int)

    /// Position of the pointer slot of the protocol at `index` in this list.
    ///
    /// It has the same origin as ``offset``.
    func entryOffset(at index: Int) -> Int

    func protocols(in machO: MachOImage) -> [(MachOImage, ObjCProtocol)]?
    func protocols(in machO: MachOFile) -> [(MachOFile, ObjCProtocol)]?
}

extension ObjCProtocolListProtocol {
    public var isListOfLists: Bool {
        offset & 1 == 1
    }
}

extension ObjCProtocolListProtocol {
    func _readProtocols<Pointer: FixedWidthInteger>(
        in machO: MachOImage,
        pointerType: Pointer.Type
    ) -> [(MachOImage, ObjCProtocol)]? {
        guard !isListOfLists else {
            assertionFailure()
            return nil
        }

        let ptr = machO.ptr.advanced(by: offset)
        let sequnece = MemorySequence(
            basePointer: ptr
                .advanced(by: MemoryLayout<Header>.size)
                .assumingMemoryBound(to: Pointer.self),
            numberOfElements: numericCast(header.count)
        )

        return sequnece
            .compactMap {
                guard let ptr = UnsafeRawPointer(bitPattern: UInt($0)) else {
                    return nil
                }
                let layout = ptr
                    .assumingMemoryBound(to: ObjCProtocol.Layout.self)
                    .pointee

                var targetMachO = machO
                if !targetMachO.contains(ptr: ptr) {
                    guard let cache = DyldCacheLoaded.current,
                          let _targetMachO = cache.machO(containing: ptr) else {
                        return nil
                    }
                    targetMachO = _targetMachO
                }

                let `protocol`: ObjCProtocol = .init(
                    layout: layout,
                    offset: Int(bitPattern: ptr) - Int(bitPattern: targetMachO.ptr)
                )
                return (targetMachO, `protocol`)
            }
    }
}
