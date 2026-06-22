//
//  ObjCClass32.swift
//
//
//  Created by p-x9 on 2024/08/19
//  
//

import Foundation
@_spi(Support) import MachOKit
import MachOObjCSectionC

public struct ObjCClass32: LayoutWrapper, ObjCClassProtocol {
    public typealias Pointer = UInt32
    public typealias ClassROData = ObjCClassROData32
    public typealias ClassRWData = ObjCClassRWData32
    public typealias LayoutField = ObjCClassLayoutField

    public struct Layout: _ObjCClassLayoutProtocol {
        public let isa: Pointer // UnsafeRawPointer?
        public let superclass: Pointer // UnsafeRawPointer?
        public let methodCacheBuckets: Pointer
        public let methodCacheProperties: Pointer // aka vtable
        public let dataVMAddrAndFastFlags: Pointer

        // This field is only present if this is a Swift object, ie, has the Swift
        // fast bits set
        public let swiftClassFlags: UInt32
    }

    public var layout: Layout
    public var offset: Int

    @_spi(Core)
    public init(layout: Layout, offset: Int) {
        self.layout = layout
        self.offset = offset
    }

    public func keyPath(of field: LayoutField) -> KeyPath<Layout, Pointer> {
        switch field {
        case .isa: \.isa
        case .superclass: \.superclass
        case .methodCacheBuckets: \.methodCacheBuckets
        case .methodCacheProperties: \.methodCacheProperties
        case .dataVMAddrAndFastFlags: \.dataVMAddrAndFastFlags
        }
    }
}

extension ObjCClass32 {
    public func classROData(in machO: MachOFile) -> ClassROData? {
        _classROData(in: machO)
    }
}

extension ObjCClass32 {
    // https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.h#L2534
    public func hasRWPointer(in machO: MachOImage) -> Bool {
        if FAST_IS_RW_POINTER_32 != 0 {
            return numericCast(layout.dataVMAddrAndFastFlags) & FAST_IS_RW_POINTER_32 != 0
        } else {
            guard let data = _classROData(in: machO) else {
                return false
            }
            return data.isRealized
        }
    }

    public func classROData(in machO: MachOImage) -> ClassROData? {
        if hasRWPointer(in: machO) { return nil }
        return _classROData(in: machO)
    }

    public func classRWData(in machO: MachOImage) -> ClassRWData? {
        if !hasRWPointer(in: machO) { return nil }

        let FAST_DATA_MASK: UInt = FAST_DATA_MASK_32

        let address: UInt = numericCast(layout.dataVMAddrAndFastFlags) & FAST_DATA_MASK

        guard let ptr = UnsafeRawPointer(bitPattern: address) else {
            return nil
        }

        let layout = ptr
            .assumingMemoryBound(to: ClassRWData.Layout.self)
            .pointee
        let classData = ClassRWData(
            layout: layout,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )

        return classData
    }
}

extension ObjCClass32 {
    /// https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.mm#L6746
    public func version(in machO: MachOFile) -> Int32 {
        guard let _data = _classROData(in: machO) else {
            return 0
        }
        return version(for: _data)
    }

    public func version(in machO: MachOImage) -> Int32 {
        if let rw = classRWData(in: machO),
           let ext = rw.ext(in: machO) {
            return numericCast(ext.version)
        }
        guard let _data = _classROData(in: machO) else {
            return 0
        }
        return version(for: _data)
    }
}

extension ObjCClass32 {
    private func _classROData(in machO: MachOImage) -> ClassROData? {
        let address: UInt = numericCast(layout.dataVMAddrAndFastFlags) & numericCast(FAST_DATA_MASK_32)
        guard let ptr = UnsafeRawPointer(bitPattern: address) else {
            return nil
        }
        let layout = ptr
            .assumingMemoryBound(to: ClassROData.Layout.self)
            .pointee
        let classData = ClassROData(
            layout: layout,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )

        return classData
    }

    private func _classROData(in machO: MachOFile) -> ClassROData? {
        let FAST_DATA_MASK: UInt64 = numericCast(FAST_DATA_MASK_32)

        var unresolved = unresolvedValue(of: .dataVMAddrAndFastFlags)
        unresolved.value &= FAST_DATA_MASK
        var resolved = machO.resolveRebase(unresolved)
        resolved.address &= FAST_DATA_MASK

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forAddress: resolved.address) else {
            return nil
        }

        let offset: Int = if let cache = machO.cache {
            numericCast(resolved.address - cache.mainCacheHeader.sharedRegionStart)
        } else {
            numericCast(machO.fileOffset(of: resolved.address)!)
        }

        let layout: ClassROData.Layout = fileHandle.read(offset: fileOffset)
        let classData = ClassROData(
            layout: layout,
            offset: offset
        )

        return classData
    }
}
