//
//  ObjCCategoryProtocol.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/12/06
//  
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCCategoryProtocol: _FixupResolvable where LayoutField == ObjCCategoryLayoutField {
    associatedtype Layout: _ObjCCategoryLayoutProtocol
    associatedtype ObjCClass: ObjCClassProtocol
    typealias ObjCProtocolList = ObjCClass.ClassROData.ObjCProtocolList

    var layout: Layout { get }
    var offset: Int { get }

    var isCatlist2: Bool { get }

    @_spi(Core)
    init(layout: Layout, offset: Int, isCatlist2: Bool)

    func name(in machO: MachOFile) -> String?
    func `class`(in machO: MachOFile) -> ObjCClass?
    func className(in machO: MachOFile) -> String?
    func instanceMethods(in machO: MachOFile) -> ObjCMethodList?
    func classMethods(in machO: MachOFile) -> ObjCMethodList?
    func instanceProperties(in machO: MachOFile) -> ObjCPropertyList?
    func classProperties(in machO: MachOFile) -> ObjCPropertyList?
    func protocols(in machO: MachOFile) -> ObjCProtocolList?

    func name(in machO: MachOImage) -> String?
    func `class`(in machO: MachOImage) -> ObjCClass?
    func className(in machO: MachOImage) -> String?
    func instanceMethods(in machO: MachOImage) -> ObjCMethodList?
    func classMethods(in machO: MachOImage) -> ObjCMethodList?
    func instanceProperties(in machO: MachOImage) -> ObjCPropertyList?
    func classProperties(in machO: MachOImage) -> ObjCPropertyList?
    func protocols(in machO: MachOImage) -> ObjCProtocolList?
}

extension ObjCCategoryProtocol {
    public func name(in machO: MachOFile) -> String? {
        var offset: UInt64 = numericCast(layout.name) & 0x7ffffffff + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        return machO.fileHandle.readString(offset: numericCast(offset))
    }

    public func `class`(in machO: MachOFile) -> ObjCClass? {
        _readClass(
            at: numericCast(layout.cls),
            field: .cls,
            in: machO
        )
    }

    public func className(in machO: MachOFile) -> String? {
        _readClassName(
            at: numericCast(layout.cls),
            field: .cls,
            in: machO
        )
    }

    public func instanceMethods(in machO: MachOFile) -> ObjCMethodList? {
        _readMethodList(
            at: numericCast(layout.instanceMethods),
            field: .instanceMethods,
            in: machO
        )
    }

    public func classMethods(in machO: MachOFile) -> ObjCMethodList? {
        _readMethodList(
            at: numericCast(layout.classMethods),
            field: .classMethods,
            in: machO
        )
    }

    public func instanceProperties(in machO: MachOFile) -> ObjCPropertyList? {
        _readPropertyList(
            at: numericCast(layout.instanceProperties),
            field: .instanceProperties,
            in: machO
        )
    }

    public func classProperties(in machO: MachOFile) -> ObjCPropertyList? {
        _readPropertyList(
            at: numericCast(layout._classProperties),
            field: ._classProperties,
            in: machO
        )
    }

    public func protocols(in machO: MachOFile) -> ObjCProtocolList? {
        _readProtocolList(
            at: numericCast(layout.protocols),
            field: .protocols,
            in: machO
        )
    }
}

extension ObjCCategoryProtocol {
    public func name(in machO: MachOImage) -> String? {
        guard layout.name > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.name)) else {
            return nil
        }
        return .init(
            cString: ptr.assumingMemoryBound(to: CChar.self),
            encoding: .utf8
        )
    }

    public func `class`(in machO: MachOImage) -> ObjCClass? {
        guard layout.cls > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.cls)) else {
            return nil
        }
        let offset: Int = numericCast(layout.cls) - Int(bitPattern: machO.ptr)
        let layout = ptr.assumingMemoryBound(to: ObjCClass.Layout.self).pointee
        return .init(layout: layout, offset: offset)
    }

    public func className(in machO: MachOImage) -> String? {
        guard let cls = `class`(in: machO),
              let data = cls.classROData(in: machO) else {
            return nil
        }
        return data.name(in: machO)
    }

    public func instanceMethods(in machO: MachOImage) -> ObjCMethodList? {
        _readMethodList(
            at: numericCast(layout.instanceMethods),
            in: machO
        )
    }

    public func classMethods(in machO: MachOImage) -> ObjCMethodList? {
        _readMethodList(
            at: numericCast(layout.classMethods),
            in: machO
        )
    }

    public func instanceProperties(in machO: MachOImage) -> ObjCPropertyList? {
        _readPropertyList(
            at: numericCast(layout.instanceProperties),
            in: machO
        )
    }

    public func classProperties(in machO: MachOImage) -> ObjCPropertyList? {
        _readPropertyList(
            at: numericCast(layout._classProperties),
            in: machO
        )
    }

    public func protocols(in machO: MachOImage) -> ObjCProtocolList? {
        _readProtocolList(
            at: numericCast(layout.protocols),
            in: machO
        )
    }
}

extension ObjCCategoryProtocol {
    private func _readClass(
        at offset: UInt64,
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCClass? {
        guard offset > 0 else { return nil }
        var offset: UInt64 = numericCast(offset) & 0x7ffffffff + numericCast(machO.headerStartOffset)

        if let resolved = resolveRebase(field, in: machO) {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
        if isBind(field, in: machO) { return nil }

        var resolvedOffset = offset
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            resolvedOffset = _offset
        }

        let layout: ObjCClass.Layout = machO.fileHandle.read(offset: resolvedOffset)
        return .init(layout: layout, offset: numericCast(offset))
    }

    private func _readClassName(
        at offset: UInt64,
        field: LayoutField,
        in machO: MachOFile
    ) -> String? {
        guard offset > 0 else { return nil }

        if let cls = _readClass(
            at: offset,
            field: field,
            in: machO
        ), let data = cls.classROData(in: machO) {
            return data.name(in: machO)
        }

        if let bindSymbolName = resolveBind(field, in: machO) {
            return bindSymbolName
                .replacingOccurrences(of: "_OBJC_CLASS_$_", with: "")
        }

        return nil
    }

    private func _readMethodList(
        at offset: UInt64,
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCMethodList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        var offset: UInt64 = numericCast(offset) & 0x7ffffffff + numericCast(machO.headerStartOffset)

        if let resolved = resolveRebase(field, in: machO),
            resolved != offset {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
//        if isBind(\.baseMethods, in: machO) { return nil }

        var resolvedOffset = offset
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            resolvedOffset = _offset
        }

        let data = machO.fileHandle.readData(
            offset: resolvedOffset,
            size: MemoryLayout<ObjCMethodList.Header>.size
        )
        let list: ObjCMethodList? = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else { return nil }
            return .init(
                ptr: ptr,
                offset: numericCast(offset) - machO.headerStartOffset,
                is64Bit: machO.is64Bit
            )
        }
        if list?.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    private func _readPropertyList(
        at offset: UInt64,
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCPropertyList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        var offset: UInt64 = numericCast(offset) & 0x7ffffffff + numericCast(machO.headerStartOffset)

        if let resolved = resolveRebase(field, in: machO),
           resolved != offset {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
//        if isBind(\.baseProperties, in: machO) { return nil }

        var resolvedOffset = offset
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            resolvedOffset = _offset
        }

        let data = machO.fileHandle.readData(
            offset: resolvedOffset,
            size: MemoryLayout<ObjCPropertyList.Header>.size
        )
        let list: ObjCPropertyList? = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else {
                return nil
            }
            return .init(
                ptr: ptr,
                offset: numericCast(offset) - machO.headerStartOffset,
                is64Bit: machO.is64Bit
            )
        }
        if list?.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    private func _readProtocolList(
        at offset: UInt64,
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCProtocolList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        var offset: UInt64 = numericCast(offset) & 0x7ffffffff + numericCast(machO.headerStartOffset)

        if let resolved = resolveRebase(field, in: machO),
           resolved != offset {
            offset = resolved & 0x7ffffffff + numericCast(machO.headerStartOffset)
        }
//        if isBind(\.baseProtocols, in: machO) { return nil }

        var resolvedOffset = offset

        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.mainCacheHeader.sharedRegionStart) else {
                return nil
            }
            resolvedOffset = _offset
        }

        let data = machO.fileHandle.readData(
            offset: resolvedOffset,
            size: MemoryLayout<ObjCProtocolList.Header>.size
        )

        let list: ObjCProtocolList? = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else {
                return nil
            }
            return .init(
                ptr: ptr,
                offset: numericCast(offset) - machO.headerStartOffset
            )
        }
        return list
    }
}

extension ObjCCategoryProtocol {
    private func _readMethodList(
        at offset: UInt64,
        in machO: MachOImage
    ) -> ObjCMethodList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(offset)
        ) else {
            return nil
        }

        let list = ObjCMethodList(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )

        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }

        return list
    }

    private func _readPropertyList(
        at offset: UInt64,
        in machO: MachOImage
    ) -> ObjCPropertyList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(offset)
        ) else {
            return nil
        }
        let list = ObjCPropertyList(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )

        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }

        return list
    }

    private func _readProtocolList(
        at offset: UInt64,
        in machO: MachOImage
    ) -> ObjCProtocolList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(offset)
        ) else {
            return nil
        }
        let list = ObjCProtocolList(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )

        return list
    }
}