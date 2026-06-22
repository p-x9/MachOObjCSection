//
//  ObjCIvarProtocol.swift
//
//
//  Created by p-x9 on 2024/08/22
//  
//

import Foundation
import MachOObjCSectionC
@_spi(Support) import MachOKit

public protocol ObjCIvarProtocol: _FixupResolvable
where LayoutField == ObjCIvarLayoutField,
      Layout: _ObjCIvarLayoutProtocol
{
    // var layout: Layout { get }
    var offset: Int { get }

    @_spi(Core)
    init(layout: Layout, offset: Int)

    func offset(in machO: MachOFile) -> UInt32?
    func name(in machO: MachOFile) -> String?
    func type(in machO: MachOFile) -> String?

    func offset(in machO: MachOImage) -> UInt32?
    func name(in machO: MachOImage) -> String
    func type(in machO: MachOImage) -> String?
}

extension ObjCIvarProtocol {
    // https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.h#L1312
    public var alignment: UInt32 {
        if layout.alignment == ~UInt32.zero {
            return 1 << WORD_SHIFT
        }
        return 1 << layout.alignment
    }
}

extension ObjCIvarProtocol {
    public func offset(in machO: MachOFile) -> UInt32? {
        guard layout.offset > 0 else { return nil }

        let unresolved = unresolvedValue(of: .offset)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        return try! fileHandle.readData(
            offset: numericCast(fileOffset),
            length: MemoryLayout<UInt32>.size
        ).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
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

    public func type(in machO: MachOFile) -> String? {
        guard layout.type > 0 else { return nil }

        let unresolved = unresolvedValue(of: .type)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        return fileHandle.readString(
            offset: fileOffset
        )
    }
}

extension ObjCIvarProtocol {
    public func offset(in machO: MachOImage) -> UInt32? {
        guard layout.offset > 0 else { return nil }
        let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.offset)
        )
        return ptr!.assumingMemoryBound(to: UInt32.self).pointee
    }

    public func name(in machO: MachOImage) -> String {
        let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.name)
        )
        return .init(cString: ptr!.assumingMemoryBound(to: CChar.self))
    }

    public func type(in machO: MachOImage) -> String? {
        guard layout.type > 0 else { return nil }
        let ptr = UnsafeRawPointer(
            bitPattern: UInt(layout.type)
        )
        return .init(cString: ptr!.assumingMemoryBound(to: CChar.self))
    }
}
