//
//  ObjCPropertyList.swift
//
//
//  Created by p-x9 on 2024/05/25
//
//

import Foundation
@_spi(Support) import MachOKit

public struct ObjCPropertyList: EntrySizeListProtocol {
    public typealias Entry = ObjCProperty

    /// Position of this list.
    ///
    /// The origin depends on where the Mach-O comes from.
    /// - Mach-O file: file offset from the start of the Mach-O header.
    /// - Mach-O in a dyld cache file: offset in the address space from the start (header) of the main cache.
    /// - Loaded Mach-O (`MachOImage`): offset from the start of the Mach-O header.
    public let offset: Int
    public let header: Header
    public let is64Bit: Bool
}

extension ObjCPropertyList {
    init(
        ptr: UnsafeRawPointer,
        offset: Int,
        is64Bit: Bool
    ) {
        self.offset = offset
        self.header = ptr.assumingMemoryBound(to: Header.self).pointee
        self.is64Bit = is64Bit
    }
}

extension ObjCPropertyList {
    public var isListOfLists: Bool {
        offset & 1 == 1
    }
}

extension ObjCPropertyList {
    public static var flagMask: UInt32 { 0 }
}

extension ObjCPropertyList {
    func isValidEntrySize(is64Bit: Bool) -> Bool {
        if is64Bit {
            MemoryLayout<ObjCProperty.Property64>.size == entrySize
        } else {
            MemoryLayout<ObjCProperty.Property32>.size == entrySize
        }
    }
}

extension ObjCPropertyList {
    public func properties(
        in machO: MachOImage
    ) -> [ObjCProperty] {
        guard !isListOfLists else {
            assertionFailure()
            return []
        }

        let ptr = machO.ptr.advanced(by: offset)
        let start = ptr.advanced(by: MemoryLayout<Header>.size)
        let sequence = MemorySequence(
            basePointer: start.assumingMemoryBound(
                to: ObjCProperty.Property.self
            ),
            numberOfElements: count
        )
        let size = MemoryLayout<ObjCProperty.Property>.size
        return sequence
            .enumerated()
            .map {
                ObjCProperty(
                    $1,
                    offset: entryOffset(at: $0, entrySize: size)
                )
            }
    }

    public func properties(
        in machO: MachOFile
    ) -> [ObjCProperty] {
        guard !isListOfLists else {
            assertionFailure()
            return []
        }

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forOffset: numericCast(offset)) else {
            return []
        }

        if machO.is64Bit {
            let sequence: DataSequence<ObjCProperty.Property64> = fileHandle
                .readDataSequence(
                    offset: fileOffset + numericCast(MemoryLayout<Header>.size),
                    numberOfElements: count
                )
            return sequence.enumerated()
                .map { i, property in
                    let fieldOffset = entryOffset(
                        at: i,
                        entrySize: MemoryLayout<ObjCProperty.Property64>.size
                    )
                    return ObjCProperty.UnresolvedProperty(
                        name: .init(
                            fieldOffset: fieldOffset,
                            value: property.name
                        ),
                        attributes: .init(
                            fieldOffset: fieldOffset + 8,
                            value: property.attributes
                        ),
                        offset: fieldOffset
                    )
                }
                .map {
                    machO.resolveRebase($0)
                }
                .compactMap {
                    var name = ""
                    if let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: $0.name) {
                        name = fileHandle.readString(
                            offset: fileOffset
                        ) ?? ""
                    }

                    var attributes = ""
                    if let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: $0.attributes) {
                        attributes = fileHandle.readString(
                            offset: fileOffset
                        ) ?? ""
                    }

                    return ObjCProperty(
                        name: name,
                        attributes: attributes,
                        offset: $0.offset
                    )
                }
        } else {
            let sequence: DataSequence<ObjCProperty.Property32> = fileHandle
                .readDataSequence(
                    offset: fileOffset + numericCast(MemoryLayout<Header>.size),
                    numberOfElements: count
                )
            return sequence.enumerated()
                .map { i, property in
                    let fieldOffset = entryOffset(
                        at: i,
                        entrySize: MemoryLayout<ObjCProperty.Property32>.size
                    )
                    return ObjCProperty.UnresolvedProperty(
                        name: .init(
                            fieldOffset: fieldOffset,
                            value: numericCast(property.name)
                        ),
                        attributes: .init(
                            fieldOffset: fieldOffset + 4,
                            value: numericCast(property.attributes)
                        ),
                        offset: fieldOffset
                    )
                }
                .map {
                    machO.resolveRebase($0)
                }
                .map {
                    var name = ""
                    if let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: $0.name) {
                        name = fileHandle.readString(
                            offset: fileOffset
                        ) ?? ""
                    }

                    var attributes = ""
                    if let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: $0.attributes) {
                        attributes = fileHandle.readString(
                            offset: fileOffset
                        ) ?? ""
                    }

                    return ObjCProperty(
                        name: name,
                        attributes: attributes,
                        offset: $0.offset
                    )
                }
        }
    }
}

extension ObjCPropertyList {
    private func entryOffset(at index: Int, entrySize: Int) -> Int {
        offset + MemoryLayout<Header>.size + entrySize * index
    }
}

extension MachOFile {
    func resolveRebase(
        _ unresolvedValue: ObjCProperty.UnresolvedProperty
    ) -> ObjCProperty.ResolvedProperty {
        ObjCProperty.ResolvedProperty(
            name: resolveRebase(unresolvedValue.name),
            attributes: resolveRebase(unresolvedValue.attributes),
            offset: unresolvedValue.offset
        )
    }
}
