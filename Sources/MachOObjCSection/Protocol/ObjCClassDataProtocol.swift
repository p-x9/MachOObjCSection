//
//  ObjCClassDataProtocol.swift
//
//
//  Created by p-x9 on 2024/08/06
//  
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCClassDataProtocol {
    associatedtype Layout: _ObjCClassDataLayoutProtocol
    associatedtype ObjCProtocolList: ObjCProtocolListProtocol
    associatedtype ObjCIvarList: ObjCIvarListProtocol

    var layout: Layout { get }
    var offset: Int { get }

    var isRootClass: Bool { get }

    func ivarLayout(in machO: MachOFile) -> [UInt8]?
    func weakIvarLayout(in machO: MachOFile) -> [UInt8]?
    func name(in machO: MachOFile) -> String?
    func methods(in machO: MachOFile) -> ObjCMethodList?
    func properties(in machO: MachOFile) -> ObjCPropertyList?
    func protocols(in machO: MachOFile) -> ObjCProtocolList?
    func ivars(in machO: MachOFile) -> ObjCIvarList?

    func ivarLayout(in machO: MachOImage) -> [UInt8]?
    func weakIvarLayout(in machO: MachOImage) -> [UInt8]?
    func name(in machO: MachOImage) -> String?
    func methods(in machO: MachOImage) -> ObjCMethodList?
    func properties(in machO: MachOImage) -> ObjCPropertyList?
    func protocols(in machO: MachOImage) -> ObjCProtocolList?
    func ivars(in machO: MachOImage) -> ObjCIvarList?
}

extension ObjCClassDataProtocol {
    public var flags: ObjCClassDataFlags {
        .init(rawValue: layout.flags)
    }
}

extension ObjCClassDataProtocol {
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

    public var hasRWPointer: Bool {
        isRealized
    }
}

extension ObjCClassDataProtocol {
    /// https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.mm#L6746
    public func version(in machO: MachOFile) -> Int32 {
        // FIXME: Support rw
        isMetaClass ? 7 : 0
    }

    public func version(in machO: MachOImage) -> Int32 {
        // FIXME: Support rw
        isMetaClass ? 7 : 0
    }
}

extension ObjCClassDataProtocol {
    public func ivarLayout(in machO: MachOFile) -> [UInt8]? {
        _ivarLayout(in: machO, at: numericCast(layout.ivarLayout))
    }

    public func weakIvarLayout(in machO: MachOFile) -> [UInt8]? {
        _ivarLayout(in: machO, at: numericCast(layout.weakIvarLayout))
    }

    public func name(in machO: MachOFile) -> String? {
        var offset: UInt64 = numericCast(layout.name) & 0x7ffffffff + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        return machO.fileHandle.readString(offset: numericCast(offset))
    }

    public func properties(in machO: MachOFile) -> ObjCPropertyList? {
        guard layout.baseProperties > 0 else { return nil }
        var offset: UInt64 = numericCast(layout.baseProperties) & 0x7ffffffff + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        let data = machO.fileHandle.readData(
            offset: offset,
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
        return list
    }
}

extension ObjCClassDataProtocol {
    public func ivarLayout(in machO: MachOImage) -> [UInt8]? {
        _ivarLayout(in: machO, at: numericCast(layout.ivarLayout))
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

    public func methods(in machO: MachOImage) -> ObjCMethodList? {
        guard layout.baseMethods > 0 else { return nil }
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

    public func properties(in machO: MachOImage) -> ObjCPropertyList? {
        guard layout.baseProperties > 0 else { return nil }
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
}

extension ObjCClassDataProtocol where ObjCProtocolList == ObjCProtocolList64 {
    public func protocols(in machO: MachOFile) -> ObjCProtocolList? {
        guard layout.baseProtocols > 0 else { return nil }
        var offset: UInt64 = numericCast(layout.baseProtocols) & 0x7ffffffff + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        let data = machO.fileHandle.readData(
            offset: offset,
            size: MemoryLayout<ObjCProtocolList64.Header>.size
        )
        let list: ObjCProtocolList64? = data.withUnsafeBytes {
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

    public func protocols(in machO: MachOImage) -> ObjCProtocolList? {
        guard layout.baseProtocols > 0 else { return nil }
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

extension ObjCClassDataProtocol where ObjCProtocolList == ObjCProtocolList32 {
    public func protocols(in machO: MachOFile) -> ObjCProtocolList? {
        guard layout.baseProtocols > 0 else { return nil }
        var offset: UInt64 = numericCast(layout.baseProtocols) + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        let data = machO.fileHandle.readData(
            offset: offset,
            size: MemoryLayout<ObjCProtocolList32.Header>.size
        )
        let list: ObjCProtocolList32? = data.withUnsafeBytes {
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

    public func protocols(in machO: MachOImage) -> ObjCProtocolList? {
        guard layout.baseProtocols > 0 else { return nil }
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

extension ObjCClassDataProtocol where ObjCIvarList == ObjCIvarList64 {
    public func ivars(in machO: MachOFile) -> ObjCIvarList? {
        guard layout.ivars > 0 else { return nil }
        var offset: UInt64 = numericCast(layout.ivars) & 0x7ffffffff + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        let data = machO.fileHandle.readData(
            offset: offset,
            size: MemoryLayout<ObjCIvarList64.Header>.size
        )
        let list: ObjCIvarList64? = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else {
                return nil
            }
            return .init(
                header: ptr
                    .assumingMemoryBound(to: ObjCIvarListHeader.self)
                    .pointee,
                offset: numericCast(offset) - machO.headerStartOffset
            )
        }
        return list
    }

    public func ivars(in machO: MachOImage) -> ObjCIvarList? {
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
}

extension ObjCClassDataProtocol where ObjCIvarList == ObjCIvarList32 {
    public func ivars(in machO: MachOFile) -> ObjCIvarList? {
        guard layout.ivars > 0 else { return nil }
        var offset: UInt64 = numericCast(layout.ivars) + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        let data = machO.fileHandle.readData(
            offset: offset,
            size: MemoryLayout<ObjCIvarList32.Header>.size
        )
        let list: ObjCIvarList32? = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else {
                return nil
            }
            return .init(
                header: ptr.assumingMemoryBound(to: ObjCIvarListHeader.self).pointee,
                offset: numericCast(offset) - machO.headerStartOffset
            )
        }
        return list
    }

    public func ivars(in machO: MachOImage) -> ObjCIvarList? {
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
}

extension ObjCClassDataProtocol {
    private func _ivarLayout(
        in machO: MachOFile,
        at offset: Int
    ) -> [UInt8]? {
        var offset: UInt64 = numericCast(offset) & 0x7ffffffff + numericCast(machO.headerStartOffset)
        if let cache = machO.cache {
            guard let _offset = cache.fileOffset(of: offset + cache.header.sharedRegionStart) else {
                return nil
            }
            offset = _offset
        }
        guard let string = machO.fileHandle.readString(offset: offset),
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

extension ObjCClassDataProtocol where Self: LayoutWrapper {
    func resolveRebase(
        _ keyPath: PartialKeyPath<Layout>,
        in machO: MachOFile
    ) -> UInt64? {
        let offset = self.offset + layoutOffset(of: keyPath)
        if let resolved = machO.resolveOptionalRebase(at: UInt64(offset)) {
            if let cache = machO.cache {
                return resolved - cache.header.sharedRegionStart
            }
            return resolved
        }
        return nil
    }

    func isBind(
        _ keyPath: PartialKeyPath<Layout>,
        in machO: MachOFile
    ) -> Bool {
        let offset = self.offset + layoutOffset(of: keyPath)
        return machO.isBind(offset)
    }
}
