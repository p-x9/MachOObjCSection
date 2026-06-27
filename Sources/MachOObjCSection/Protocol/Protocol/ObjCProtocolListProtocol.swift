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

    var offset: Int { get }
    var header: Header { get }

    @_spi(Core)
    init(offset: Int, header: Header)

    @_spi(Core)
    init(ptr: UnsafeRawPointer, offset: Int)

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
        guard !isListOfLists else { return nil }

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
