//
//  ObjCClassDataProtocol.swift
//
//
//  Created by p-x9 on 2024/08/06
//
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCClassRODataProtocol: _FixupResolvable
where LayoutField == ObjCClassRODataLayoutField,
      Layout: _ObjCClassRODataLayoutProtocol
{
    associatedtype ObjCProtocolList: ObjCProtocolListProtocol
    associatedtype ObjCIvarList: ObjCIvarListProtocol
    associatedtype ObjCProtocolRelativeListList: ObjCProtocolRelativeListListProtocol where ObjCProtocolRelativeListList.List == ObjCProtocolList

    // var layout: Layout { get }
    var offset: Int { get }

    var isRootClass: Bool { get }

    @_spi(Core)
    init(layout: Layout, offset: Int)

    func ivarLayout(in machO: MachOFile) -> [UInt8]?
    func weakIvarLayout(in machO: MachOFile) -> [UInt8]?
    func name(in machO: MachOFile) -> String?
    func methodList(in machO: MachOFile) -> ObjCMethodList?
    func propertyList(in machO: MachOFile) -> ObjCPropertyList?
    func protocolList(in machO: MachOFile) -> ObjCProtocolList?
    func ivarList(in machO: MachOFile) -> ObjCIvarList?

    func ivarLayout(in machO: MachOImage) -> [UInt8]?
    func weakIvarLayout(in machO: MachOImage) -> [UInt8]?
    func name(in machO: MachOImage) -> String?
    func methodList(in machO: MachOImage) -> ObjCMethodList?
    func propertyList(in machO: MachOImage) -> ObjCPropertyList?
    func protocolList(in machO: MachOImage) -> ObjCProtocolList?
    func ivarList(in machO: MachOImage) -> ObjCIvarList?

    func methodRelativeListList(in machO: MachOFile) -> ObjCMethodRelativeListList?
    func propertyRelativeListList(in machO: MachOFile) -> ObjCPropertyRelativeListList?
    func protocolRelativeListList(in machO: MachOFile) -> ObjCProtocolRelativeListList?

    func methodRelativeListList(in machO: MachOImage) -> ObjCMethodRelativeListList?
    func propertyRelativeListList(in machO: MachOImage) -> ObjCPropertyRelativeListList?
    func protocolRelativeListList(in machO: MachOImage) -> ObjCProtocolRelativeListList?
}

extension ObjCClassRODataProtocol {
    public var flags: ObjCClassRODataFlags {
        .init(rawValue: layout.flags)
    }
}

extension ObjCClassRODataProtocol {
    // https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.h#L36

    public var isMetaClass: Bool {
        flags.contains(.meta)
    }

    public var isRootClass: Bool {
        flags.contains(.root)
    }

    // Values for class_rw_t->flags
    // These are not emitted by the compiler and are never used in class_ro_t.
    // Their presence should be considered in future ABI versions.
    // class_t->data is class_rw_t, not class_ro_t
    public var isRealized: Bool {
        flags.contains(.realized)
    }
}

extension ObjCClassRODataProtocol {
    public func ivarLayout(in machO: MachOFile) -> [UInt8]? {
        if flags.contains(.meta) { return nil }
        return _ivarLayout(field: .ivarLayout, in: machO)
    }

    public func weakIvarLayout(in machO: MachOFile) -> [UInt8]? {
        _ivarLayout(field: .weakIvarLayout, in: machO)
    }

    public func name(in machO: MachOFile) -> String? {
        let unresolved = unresolvedValue(of: .name)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        return fileHandle.readString(
            offset: fileOffset
        )
    }

    public func methodList(in machO: MachOFile) -> ObjCMethodList? {
        guard layout.baseMethods > 0 else { return nil }
        guard layout.baseMethods & 1 == 0 else { return nil }

        let unresolved = unresolvedValue(of: .baseMethods)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCMethodList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCMethodList(
            offset: numericCast(resolved.offset),
            header: header,
            is64Bit: machO.is64Bit
        )
        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    public func propertyList(in machO: MachOFile) -> ObjCPropertyList? {
        guard layout.baseProperties > 0 else { return nil }
        guard layout.baseProperties & 1 == 0 else { return nil }

        let unresolved = unresolvedValue(of: .baseProperties)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCPropertyList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCPropertyList(
            offset: numericCast(resolved.offset),
            header: header,
            is64Bit: machO.is64Bit
        )
        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    public func ivarList(in machO: MachOFile) -> ObjCIvarList? {
        guard layout.ivars > 0 else { return nil }

        let unresolved = unresolvedValue(of: .ivars)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCIvarList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCIvarList(
            header: header,
            offset: numericCast(resolved.offset)
        )

        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    public func protocolList(in machO: MachOFile) -> ObjCProtocolList? {
        guard layout.baseProtocols > 0 else { return nil }
        guard layout.baseProtocols & 1 == 0 else { return nil }

        let unresolved = unresolvedValue(of: .baseProtocols)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCProtocolList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCProtocolList(
            offset: numericCast(resolved.offset),
            header: header
        )
        return list
    }
}

extension ObjCClassRODataProtocol {
    public func ivarLayout(in machO: MachOImage) -> [UInt8]? {
        if flags.contains(.meta) { return nil }
        return _ivarLayout(in: machO, at: numericCast(layout.ivarLayout))
    }

    public func weakIvarLayout(in machO: MachOImage) -> [UInt8]? {
        _ivarLayout(in: machO, at: numericCast(layout.weakIvarLayout))
    }

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

    public func methodList(in machO: MachOImage) -> ObjCMethodList? {
        guard layout.baseMethods > 0 else { return nil }
        guard layout.baseMethods & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.baseMethods)
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

    public func propertyList(in machO: MachOImage) -> ObjCPropertyList? {
        guard layout.baseProperties > 0 else { return nil }
        guard layout.baseProperties & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.baseProperties)
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

    public func ivarList(in machO: MachOImage) -> ObjCIvarList? {
        guard layout.ivars > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.ivars)) else {
            return nil
        }
        let list = ObjCIvarList(
            header: ptr
                .assumingMemoryBound(to: ObjCIvarList.Header.self)
                .pointee,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )
        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }

        return list
    }

    public func protocolList(in machO: MachOImage) -> ObjCProtocolList? {
        guard layout.baseProtocols > 0 else { return nil }
        guard layout.baseProtocols & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.baseProtocols)
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

extension ObjCClassRODataProtocol {
    public func methodRelativeListList(in machO: MachOFile) -> ObjCMethodRelativeListList? {
        guard layout.baseMethods > 0 else { return nil }
        guard layout.baseMethods & 1 == 1 else { return nil }

        var unresolved = unresolvedValue(of: .baseMethods)
        unresolved.value &= ~1
        var resolved = machO.resolveRebase(unresolved)
        resolved.address &= ~1
        resolved.offset &= ~1

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCMethodRelativeListList.Header = fileHandle.read(offset: fileOffset)
        let lists = ObjCMethodRelativeListList(
            offset: numericCast(resolved.offset),
            header: header
        )
        return lists
    }

    public func propertyRelativeListList(in machO: MachOFile) -> ObjCPropertyRelativeListList? {
        guard layout.baseProperties > 0 else { return nil }
        guard layout.baseProperties & 1 == 1 else { return nil }

        var unresolved = unresolvedValue(of: .baseProperties)
        unresolved.value &= ~1
        var resolved = machO.resolveRebase(unresolved)
        resolved.address &= ~1
        resolved.offset &= ~1

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCPropertyRelativeListList.Header = fileHandle.read(offset: fileOffset)
        let lists = ObjCPropertyRelativeListList(
            offset: numericCast(resolved.offset),
            header: header
        )
        return lists
    }

    public func protocolRelativeListList(in machO: MachOFile) -> ObjCProtocolRelativeListList? {
        guard layout.baseProtocols > 0 else { return nil }
        guard layout.baseProtocols & 1 == 1 else { return nil }

        var unresolved = unresolvedValue(of: .baseProtocols)
        unresolved.value &= ~1
        var resolved = machO.resolveRebase(unresolved)
        resolved.address &= ~1
        resolved.offset &= ~1

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCProtocolRelativeListList.Header = fileHandle.read(offset: fileOffset)
        let lists = ObjCProtocolRelativeListList(
            offset: numericCast(resolved.offset),
            header: header
        )
        return lists
    }
}

extension ObjCClassRODataProtocol {
    public func methodRelativeListList(
        in machO: MachOImage
    ) -> ObjCMethodRelativeListList? {
        guard layout.baseMethods > 0 else { return nil }
        guard layout.baseMethods & 1 == 1 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.baseMethods & ~1)
        ) else {
            return nil
        }

        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )
    }

    public func propertyRelativeListList(
        in machO: MachOImage
    ) -> ObjCPropertyRelativeListList? {
        guard layout.baseProperties > 0 else { return nil }
        guard layout.baseProperties & 1 == 1 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.baseProperties & ~1)
        ) else {
            return nil
        }

        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )
    }

    public func protocolRelativeListList(
        in machO: MachOImage
    ) -> ObjCProtocolRelativeListList? {
        guard layout.baseProtocols > 0 else { return nil }
        guard layout.baseProtocols & 1 == 1 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.baseProtocols & ~1)
        ) else {
            return nil
        }

        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )
    }
}

extension ObjCClassRODataProtocol {
    private func _ivarLayout(
        field: LayoutField,
        in machO: MachOFile
    ) -> [UInt8]? {
        let unresolved = unresolvedValue(of: field)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        guard let string = fileHandle.readString(offset: fileOffset),
              let data = string.data(using: .utf8) else {
            return nil
        }
        return Array(data)
    }

    private func _ivarLayout(
        in machO: MachOImage,
        at offset: Int
    ) -> [UInt8]? {
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(offset)) else {
            return nil
        }
        guard let string = String(cString: ptr.assumingMemoryBound(to: CChar.self), encoding: .utf8),
              let data = string.data(using: .utf8) else {
            return nil
        }
        return Array(data)
    }
}
