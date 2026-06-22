//
//  ObjCProtocolProtocol.swift
//
//
//  Created by p-x9 on 2024/05/27
//
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCProtocolProtocol: _FixupResolvable
where LayoutField == ObjCProtocolLayoutField,
    Layout: _ObjCProtocolLayoutProtocol
{
    associatedtype ObjCProtocolList: ObjCProtocolListProtocol where ObjCProtocolList.ObjCProtocol == Self

    // var layout: Layout { get }
    var offset: Int { get }

    @_spi(Core)
    init(layout: Layout, offset: Int)

    var size: UInt32 { get }
    var flags: UInt32 { get }

    func mangledName(in machO: MachOImage) -> String
    func protocolList(in machO: MachOImage) -> ObjCProtocolList?
    func instanceMethodList(in machO: MachOImage) -> ObjCMethodList?
    func classMethodList(in machO: MachOImage) -> ObjCMethodList?
    func optionalInstanceMethodList(in machO: MachOImage) -> ObjCMethodList?
    func optionalClassMethodList(in machO: MachOImage) -> ObjCMethodList?
    func instancePropertyList(in machO: MachOImage) -> ObjCPropertyList?
    func extendedMethodTypes(in machO: MachOImage) -> String?
    func demangledName(in machO: MachOImage) -> String?
    func classPropertyList(in machO: MachOImage) -> ObjCPropertyList?

    func mangledName(in machO: MachOFile) -> String
    func protocolList(in machO: MachOFile) -> ObjCProtocolList?
    func instanceMethodList(in machO: MachOFile) -> ObjCMethodList?
    func classMethodList(in machO: MachOFile) -> ObjCMethodList?
    func optionalInstanceMethodList(in machO: MachOFile) -> ObjCMethodList?
    func optionalClassMethodList(in machO: MachOFile) -> ObjCMethodList?
    func instancePropertyList(in machO: MachOFile) -> ObjCPropertyList?
    func extendedMethodTypes(in machO: MachOFile) -> String?
    func demangledName(in machO: MachOFile) -> String?
    func classPropertyList(in machO: MachOFile) -> ObjCPropertyList?
}

extension ObjCProtocolProtocol {
    public var size: UInt32 { layout.size }
    public var flags: UInt32 { layout.flags }
}

extension ObjCProtocolProtocol {
    public func mangledName(in machO: MachOImage) -> String {
        let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.mangledName)
        )
        return .init(cString: ptr!.assumingMemoryBound(to: CChar.self))
    }

    public func protocolList(in machO: MachOImage) -> ObjCProtocolList? {
        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.protocols)
        ) else {
            return nil
        }
        return .init(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )
    }

    public func instanceMethodList(in machO: MachOImage) -> ObjCMethodList? {
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

    public func classMethodList(in machO: MachOImage) -> ObjCMethodList? {
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

    public func optionalInstanceMethodList(in machO: MachOImage) -> ObjCMethodList? {
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

    public func optionalClassMethodList(in machO: MachOImage) -> ObjCMethodList? {
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

    public func instancePropertyList(in machO: MachOImage) -> ObjCPropertyList? {
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

    public func classPropertyList(in machO: MachOImage) -> ObjCPropertyList? {
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
        let unresolved = unresolvedValue(of: .mangledName)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return ""
        }
        return fileHandle.readString(
            offset: fileOffset
        ) ?? ""
    }

    public func protocolList(in machO: MachOFile) -> ObjCProtocolList? {
        guard layout.protocols > 0 else { return nil }

        let unresolved = unresolvedValue(of: .protocols)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let data = try! fileHandle.readData(
            offset: numericCast(fileOffset),
            length: MemoryLayout<ObjCProtocolList64.Header>.size
        )
        return data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            return .init(
                ptr: baseAddress,
                offset: numericCast(resolved.offset)
            )
        }
    }

    public func instanceMethodList(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(field: .instanceMethods, in: machO)
    }

    public func classMethodList(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(field: .classMethods, in: machO)
    }

    public func optionalInstanceMethodList(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(
            field: .optionalInstanceMethods,
            in: machO
        )
    }

    public func optionalClassMethodList(in machO: MachOFile) -> ObjCMethodList? {
        _readObjCMethodList(
            field: .optionalClassMethods,
            in: machO
        )
    }

    public func instancePropertyList(in machO: MachOFile) -> ObjCPropertyList? {
        _readObjCPropertyList(
            field: .instanceProperties,
            in: machO
        )
    }

    public func extendedMethodTypes(in machO: MachOFile) -> String? {
        let offset = layoutOffset(of: ._extendedMethodTypes)
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard layout._extendedMethodTypes > 0 else { return nil }

        let unresolved = unresolvedValue(of: ._extendedMethodTypes)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        if machO.is64Bit {
            let address: UInt64 = try! fileHandle.read(
                offset: numericCast(fileOffset)
            )
            guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forAddress: address) else {
                return nil
            }

            return fileHandle.readString(
                offset: fileOffset
            )
        } else {
            let _address: UInt32 = try! fileHandle.read(
                offset: numericCast(fileOffset)
            )
            let address: UInt64 = numericCast(_address)
            guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forAddress: address) else {
                return nil
            }

            return fileHandle.readString(
                offset: fileOffset
            )
        }
    }

    public func demangledName(in machO: MachOFile) -> String? {
        let offset = layoutOffset(of: ._demangledName)
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard layout._demangledName > 0 else { return nil }

        let unresolved = unresolvedValue(of: ._demangledName)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        return fileHandle.readString(
            offset: fileOffset
        )
    }

    public func classPropertyList(in machO: MachOFile) -> ObjCPropertyList? {
        let offset = layoutOffset(of: ._classProperties)
        guard size >= offset + MemoryLayout<Layout.Pointer>.size else {
            return nil
        }
        guard layout._classProperties > 0 else { return nil }
        return _readObjCPropertyList(
            field: ._classProperties,
            in: machO
        )
    }
}

extension ObjCProtocolProtocol {
    fileprivate func _readObjCMethodList(
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCMethodList? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let data = try! fileHandle.readData(
            offset: numericCast(fileOffset),
            length: MemoryLayout<ObjCMethodList.Header>.size
        )
        return data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            return .init(
                ptr: baseAddress,
                offset: numericCast(resolved.offset),
                is64Bit: machO.is64Bit
            )
        }
    }

    fileprivate func _readObjCPropertyList(
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCPropertyList? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let data = try! fileHandle.readData(
            offset: numericCast(fileOffset),
            length: MemoryLayout<ObjCPropertyList.Header>.size
        )
        return data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            return .init(
                ptr: baseAddress,
                offset: numericCast(resolved.offset),
                is64Bit: machO.is64Bit
            )
        }
    }
}
