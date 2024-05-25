//
//  ObjCMethod.swift
//  
//
//  Created by p-x9 on 2024/05/16
//  
//

import Foundation
@testable import MachOKit

// https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.h#L925

public struct ObjCMethod {
    public let name: String
    public let types: String
    public let imp: IMP?

    init(name: String, types: String, imp: IMP?) {
        self.name = name
        self.types = types
        self.imp = imp
    }
}

extension ObjCMethod {
    public enum Kind: UInt32 {
        case pointer
        case relativeDirect
        case relativeIndirect
    }
}

extension ObjCMethod {
    public struct Pointer {
        public let name: UnsafePointer<CChar>
        public let types: UnsafePointer<CChar>
        public let imp: IMP
    }

    init(_ pointer: Pointer) {
        self.init(
            name: .init(cString: pointer.name),
            types: .init(cString: pointer.types),
            imp: pointer.imp
        )
    }
}

extension ObjCMethod {
    public struct Pointer32 {
        public let name: UInt32 // UnsafePointer<CChar>
        public let types: UInt32 // UnsafePointer<CChar>
        public let imp: UInt32 // IMP
    }

    init(_ pointer: Pointer32) {
        let name = UnsafeRawPointer(bitPattern: UInt(pointer.name))?
            .assumingMemoryBound(to: CChar.self)
        let types = UnsafeRawPointer(bitPattern: UInt(pointer.types))?
            .assumingMemoryBound(to: CChar.self)
        let imp = OpaquePointer(bitPattern: UInt(pointer.imp))
        self.init(
            name: .init(cString: name!),
            types: .init(cString: types!),
            imp: imp
        )
    }
}

extension ObjCMethod {
    public struct Pointer64 {
        public let name: UInt64 // UnsafePointer<CChar>
        public let types: UInt64 // UnsafePointer<CChar>
        public let imp: UInt64 // IMP
    }

    init(_ pointer: Pointer64) {
        let name = UnsafeRawPointer(bitPattern: UInt(pointer.name))?
            .assumingMemoryBound(to: CChar.self)
        let types = UnsafeRawPointer(bitPattern: UInt(pointer.types))?
            .assumingMemoryBound(to: CChar.self)
        let imp = OpaquePointer(bitPattern: UInt(pointer.imp))
        self.init(
            name: .init(cString: name!),
            types: .init(cString: types!),
            imp: imp
        )
    }
}

extension ObjCMethod {
    public struct RelativeDirect {
        public let name: RelativeDirectPointer<CChar>
        public let types: RelativeDirectPointer<CChar>
        public let imp: RelativeDirectPointer<IMP>
    }

    init(_ relativeDirect: RelativeDirect, at pointer: UnsafeRawPointer) {
        let base = unsafeBitCast(
            NSSelectorFromString("🤯"),
            to: UnsafeRawPointer.self
        )
        self.init(
            name: .init(
                cString: relativeDirect.name
                    .address(from: base)
                    .assumingMemoryBound(to: CChar.self)
            ),
            types: .init(
                cString: relativeDirect.types
                    .address(from: pointer.advanced(by: 4))
                    .assumingMemoryBound(to: CChar.self)
            ),
            imp: nil
        )
    }
}

extension ObjCMethod {
    public struct RelativeInDirect {
        public let name: RelativeIndirectPointer<CChar>
        public let types: RelativeDirectPointer<CChar>
        public let imp: RelativeDirectPointer<IMP>
    }

    init(_ relativeIndirect: RelativeInDirect, at pointer: UnsafeRawPointer) {
        self.init(
            name: .init(
                cString: relativeIndirect.name
                    .address(from: pointer)
                    .assumingMemoryBound(to: UnsafePointer<CChar>.self)
                    .pointee
            ),
            types: .init(
                cString: relativeIndirect.types
                    .address(from: pointer.advanced(by: 4))
                    .assumingMemoryBound(to: CChar.self)
            ),
            imp: relativeIndirect.imp
                .pointee(from: pointer.advanced(by: 8))
        )
    }
}
