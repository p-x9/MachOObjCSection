//
//  ObjCProtocolProtocol.swift
//
//
//  Created by p-x9 on 2024/05/27
//
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCProtocolProtocol {
    associatedtype Layout: _ObjCProtocolLayoutProtocol
    associatedtype ObjCProtocolList: ObjCProtocolListProtocol where ObjCProtocolList.ObjCProtocol == Self

    var layout: Layout { get }
}

extension ObjCProtocolProtocol {
    public func mangledName(in machO: MachOImage) -> String {
        let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.mangledName)
        )
        return .init(cString: ptr!.assumingMemoryBound(to: CChar.self))
    }

    public func instanceMethods(in machO: MachOImage) -> ObjCMethodList? {
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.instanceMethods)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )
    }

    public func classMethods(in machO: MachOImage) -> ObjCMethodList? {
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.classMethods)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )
    }

    public func optionalInstanceMethods(in machO: MachOImage) -> ObjCMethodList? {
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.optionalInstanceMethods)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )
    }

    public func optionalClassMethods(in machO: MachOImage) -> ObjCMethodList? {
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.optionalClassMethods)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )
    }

    public func instanceProperties(in machO: MachOImage) -> ObjCPropertyList? {
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.instanceProperties)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )
    }

    public var size: UInt32 { layout.size }
    public var flags: UInt32 { layout.flags }

    public func extendedMethodTypes(in machO: MachOImage) -> String? {
        let offset = machO.is64Bit ? 72 : 40
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard let _extendedMethodTypes = UnsafeRawPointer(
            bitPattern: UInt(layout._extendedMethodTypes)
        ) else {
            return nil
        }
        return .init(
            cString: _extendedMethodTypes
                .assumingMemoryBound(to: UnsafePointer<CChar>.self)
                .pointee
        )
    }

    public func demangledName(in machO: MachOImage) -> String? {
        let offset = machO.is64Bit ? 80 : 44
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard let _demangledName = UnsafeRawPointer(
            bitPattern: UInt(layout._demangledName)
        ) else {
            return nil
        }
        return .init(
            cString: _demangledName
                .assumingMemoryBound(to: CChar.self)
        )
    }

    public func classProperties(in machO: MachOImage) -> ObjCPropertyList? {
        let offset = machO.is64Bit ? 88 : 48
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout._classProperties)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )
    }
}

extension ObjCProtocolProtocol {
    public func mangledName(in machO: MachOFile) -> String {
        let headerStartOffset = machO.headerStartOffset/* + machO.headerStartOffsetInCache*/
        return machO.fileHandle.readString(
            offset: numericCast(layout.mangledName & 0x7ffffffff) + numericCast(headerStartOffset)
        ) ?? ""
    }

    public func instanceMethods(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(in: machO, offset: numericCast(layout.instanceMethods))
    }

    public func classMethods(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(in: machO, offset: numericCast(layout.classMethods))
    }

    public func optionalInstanceMethods(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(
            in: machO,
            offset: numericCast(layout.optionalInstanceMethods)
        )
    }

    public func optionalClassMethods(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(
            in: machO,
            offset: numericCast(layout.optionalClassMethods)
        )
    }

    public func instanceProperties(in machO: MachOFile) -> ObjCPropertyList? {
        _readObjCPropertyList(
            in: machO,
            offset: numericCast(layout.instanceProperties)
        )
    }

    public func extendedMethodTypes(in machO: MachOFile) -> String? {
        let offset = machO.is64Bit ? 72 : 40
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard layout._extendedMethodTypes > 0 else { return nil }
        let headerStartOffset = machO.headerStartOffset/* + machO.headerStartOffsetInCache*/

        let _extendedMethodTypes = layout._extendedMethodTypes & 0x7ffffffff
        if machO.is64Bit {
            var offset: UInt64 = UInt64(_extendedMethodTypes)
            if let cache = machO.cache {
                offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart)!
            }
            offset = machO.fileHandle.read(
                offset: numericCast(headerStartOffset) + numericCast(offset)
            ) & 0x7ffffffff
            return machO.fileHandle.readString(
                offset: numericCast(headerStartOffset) + numericCast(offset)
            )
        } else {
            let offset: UInt32 = machO.fileHandle.read(
                offset: numericCast(headerStartOffset) + numericCast(_extendedMethodTypes)
            )
            return machO.fileHandle.readString(
                offset: numericCast(headerStartOffset) + numericCast(offset)
            )
        }
    }

    public func demangledName(in machO: MachOFile) -> String? {
        let offset = machO.is64Bit ? 80 : 44
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard layout._demangledName > 0 else { return nil }
        let headerStartOffset = machO.headerStartOffset/* + machO.headerStartOffsetInCache*/

        let _demangledName = layout._demangledName & 0x7ffffffff
        return machO.fileHandle.readString(
            offset: numericCast(headerStartOffset) + numericCast(_demangledName)
        )
    }

    public func classProperties(in machO: MachOFile) -> ObjCPropertyList? {
        _readObjCPropertyList(
            in: machO,
            offset: numericCast(layout._classProperties)
        )
    }
}

extension ObjCProtocolProtocol {
    fileprivate func _readObjCMethodList(
        in machO: MachOFile,
        offset: UInt64
    ) -> ObjCMethodList? {
        guard offset > 0 else { return nil }
        let headerStartOffset = machO.headerStartOffset /*+ machO.headerStartOffsetInCache*/
        var offset = offset & 0x7ffffffff
        if let cache = machO.cache {
            offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) ?? 0
        }
        let data = machO.fileHandle.readData(
            offset: numericCast(headerStartOffset) + numericCast(offset),
            size: MemoryLayout<ObjCMethodList.Header>.size
        )
        return data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            return .init(
                ptr: baseAddress,
                offset: numericCast(offset),
                is64Bit: machO.is64Bit
            )
        }
    }

    fileprivate func _readObjCPropertyList(
        in machO: MachOFile,
        offset: UInt64
    ) -> ObjCPropertyList? {
        guard offset > 0 else { return nil }
        let headerStartOffset = machO.headerStartOffset/* + machO.headerStartOffsetInCache*/
        var offset = offset & 0x7ffffffff
        if let cache = machO.cache {
            offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) ?? 0
        }
        let data = machO.fileHandle.readData(
            offset: numericCast(headerStartOffset) + numericCast(offset),
            size: MemoryLayout<ObjCPropertyList.Header>.size
        )
        return data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            return .init(
                ptr: baseAddress,
                offset: numericCast(offset),
                is64Bit: machO.is64Bit
            )
        }
    }
}