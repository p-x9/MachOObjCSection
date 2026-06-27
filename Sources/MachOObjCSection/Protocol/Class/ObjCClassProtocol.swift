//
//  ObjCClassProtocol.swift
//
//
//  Created by p-x9 on 2024/08/06
//  
//

import Foundation
@_spi(Support) import MachOKit
import MachOObjCSectionC

public protocol ObjCClassProtocol: _FixupResolvable
where LayoutField == ObjCClassLayoutField,
      Layout: _ObjCClassLayoutProtocol
{
    associatedtype ClassROData: LayoutWrapper, ObjCClassRODataProtocol where ClassROData.Layout.Pointer == Layout.Pointer
    associatedtype ClassRWData: LayoutWrapper, ObjCClassRWDataProtocol where ClassRWData.Layout.Pointer == Layout.Pointer, ClassRWData.ObjCClassROData == ClassROData

    // var layout: Layout { get }
    var offset: Int { get }

    @_spi(Core)
    init(layout: Layout, offset: Int)

    func metaClass(in machO: MachOFile) -> (MachOFile, Self)?
    func superClass(in machO: MachOFile) -> (MachOFile, Self)?
    func superClassName(in machO: MachOFile) -> String?
    func classROData(in machO: MachOFile) -> ClassROData?

    func hasRWPointer(in machO: MachOImage) -> Bool

    func metaClass(in machO: MachOImage) -> (MachOImage, Self)?
    func superClass(in machO: MachOImage) -> (MachOImage, Self)?
    func superClassName(in machO: MachOImage) -> String?
    func classROData(in machO: MachOImage) -> ClassROData?
    func classRWData(in machO: MachOImage) -> ClassRWData?

    func version(in machO: MachOFile) -> Int32
    func version(in machO: MachOImage) -> Int32
}

extension ObjCClassProtocol {
    public func version(for data: ClassROData) -> Int32 {
        data.isMetaClass ? 7 : 0
    }
}

extension ObjCClassProtocol {
    // https://github.com/apple-oss-distributions/objc4/blob/89543e2c0f67d38ca5211cea33f42c51500287d5/runtime/objc-runtime-new.h#L2998C10-L2998C21
    // https://github.com/swiftlang/swift/blob/main/docs/ObjCInterop.md
    // https://github.com/swiftlang/swift/blob/643cbd15e637ece615b911cce1e1bf96a28297e3/lib/IRGen/GenClass.cpp#L2613
    public var isStubClass: Bool {
        let isa = layout.isa
        return 1 <= isa && isa < 16
    }
}

extension ObjCClassProtocol {
    /// class is a Swift class from the pre-stable Swift ABI
    public var isSwiftLegacy: Bool {
        layout.dataVMAddrAndFastFlags & numericCast(FAST_IS_SWIFT_LEGACY) != 0
    }

    /// class is a Swift class from the stable Swift ABI
    public var isSwiftStable: Bool {
        layout.dataVMAddrAndFastFlags & numericCast(FAST_IS_SWIFT_STABLE) != 0
    }

    public var isSwift: Bool {
        isSwiftStable || isSwiftLegacy
    }
}

extension ObjCClassProtocol {
    public func metaClass(in machO: MachOFile) -> (MachOFile, Self)? {
        _readClass(
            field: .isa,
            in: machO
        )
    }

    public func superClass(in machO: MachOFile) -> (MachOFile, Self)? {
        _readClass(
            field: .superclass,
            in: machO
        )
    }

    public func superClassName(in machO: MachOFile) -> String? {
        _readClassName(
            field: .superclass,
            in: machO
        )
    }
}

extension ObjCClassProtocol {
    public func metaClass(in machO: MachOImage) -> (MachOImage, Self)? {
        guard layout.isa > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.isa)) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(ptr: ptr) {
            guard let cache = DyldCacheLoaded.current,
                  let _targetMachO = cache.machO(containing: ptr) else {
                return nil
            }
            targetMachO = _targetMachO
        }

        let offset: Int = numericCast(layout.isa) - Int(bitPattern: targetMachO.ptr)

        let layout = ptr.assumingMemoryBound(to: Layout.self).pointee
        let cls: Self = .init(layout: layout, offset: offset)

        return (targetMachO, cls)
    }

    public func superClass(in machO: MachOImage) -> (MachOImage, Self)? {
        guard layout.superclass > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.superclass)) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(ptr: ptr) {
            guard let cache = DyldCacheLoaded.current,
                  let _targetMachO = cache.machO(containing: ptr) else {
                return nil
            }
            targetMachO = _targetMachO
        }

        let offset: Int = numericCast(layout.superclass) - Int(bitPattern: targetMachO.ptr)

        let layout = ptr.assumingMemoryBound(to: Layout.self).pointee
        let cls: Self = .init(layout: layout, offset: offset)

        return (targetMachO, cls)
    }

    public func superClassName(in machO: MachOImage) -> String? {
        guard layout.superclass > 0,
              let ptr = UnsafeRawPointer(bitPattern: UInt(layout.superclass)) else {
            return nil
        }
        return Self._readClassName(ptr: ptr, in: machO)
    }
}

extension ObjCClassProtocol {
    @available(*, deprecated, renamed: "metaClass(in:)", message: "Use `metaClass(in:)` that returns machO that contains class")
    public func metaClass(in machO: MachOFile) -> Self? {
        guard let (_, cls) = self.metaClass(in: machO) else {
            return nil
        }
        return cls
    }

    @available(*, deprecated, renamed: "superClass(in:)", message: "Use `superClass(in:)` that returns machO that contains class")
    public func superClass(in machO: MachOFile) -> Self? {
        guard let (_, cls) = self.superClass(in: machO) else {
            return nil
        }
        return cls
    }

    @available(*, deprecated, renamed: "metaClass(in:)", message: "Use `metaClass(in:)` that returns machO that contains class")
    func metaClass(in machO: MachOImage) -> Self? {
        guard let (targetMachO, cls) = self.metaClass(in: machO) else { return nil }
        let diff = Int(bitPattern: targetMachO.ptr) - Int(bitPattern: machO.ptr)
        return .init(
            layout: cls.layout,
            offset: cls.offset + diff
        )
    }

    @available(*, deprecated, renamed: "superClass(in:)", message: "Use `superClass(in:)` that returns machO that contains class")
    func superClass(in machO: MachOImage) -> Self? {
        guard let (targetMachO, cls) = self.superClass(in: machO) else { return nil }
        let diff = Int(bitPattern: targetMachO.ptr) - Int(bitPattern: machO.ptr)
        return .init(
            layout: cls.layout,
            offset: cls.offset + diff
        )
    }
}

extension ObjCClassProtocol {
    static func _readClassName(
        ptr: UnsafeRawPointer,
        in machO: MachOImage,
        allowsStubClass: Bool = true
    ) -> String? {
        let layout = ptr.assumingMemoryBound(to: Layout.self).pointee
        let cls: Self = .init(
            layout: layout,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )
        if !allowsStubClass, cls.isStubClass {
            return nil
        }

        // NOTE: In practice, you need to resolve the machO file to which the class belongs.
        // However, since the correct cache file handle is used internally, this is not a problem.

        var data: ClassROData?
        if let _data = cls.classROData(in: machO) {
            data = _data
        }
        if let rw = cls.classRWData(in: machO) {
            if let _data = rw.classROData(in: machO) {
                data = _data
            }
            if let ext = rw.ext(in: machO),
               let _data = ext.classROData(in: machO) {
                data = _data
            }
        }
        return data?.name(in: machO)
    }

    static func _readClassName(
        resolved: ResolvedValue,
        in machO: MachOFile,
        allowsStubClass: Bool = true
    ) -> String? {
        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let layout: Layout = fileHandle.read(offset: fileOffset)
        let cls: Self = .init(
            layout: layout,
            offset: numericCast(resolved.offset)
        )
        if !allowsStubClass, cls.isStubClass {
            return nil
        }
        // NOTE: In practice, you need to resolve the machO file to which the class belongs.
        // However, since the correct cache file handle is used internally, this is not a problem.
        guard let data = cls.classROData(in: machO) else {
            return nil
        }
        return data.name(in: machO)
    }

    private func _readClass(
        field: LayoutField,
        in machO: MachOFile
    ) -> (MachOFile, Self)? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        if isBind(field, in: machO) { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(unslidAddress: resolved.address),
           let cache = machO.cache(for: resolved.address),
           let machO = cache.machO(containing: resolved.address) {
            targetMachO = machO
        }

        let layout: Layout = fileHandle.read(offset: fileOffset)
        let cls: Self = .init(
            layout: layout,
            offset: numericCast(resolved.offset)
        )
        return (targetMachO, cls)
    }

    private func _readClassName(
        field: LayoutField,
        in machO: MachOFile
    ) -> String? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        if !isBind(field, in: machO) {
            let resolved = machO.resolveRebase(unresolved)
            if let name = Self._readClassName(
                resolved: resolved,
                in: machO
            ) {
                return name
            }
        }

        if let bindSymbolName = resolveBind(field, in: machO) {
            return bindSymbolName
                .replacingOccurrences(of: "_OBJC_CLASS_$_", with: "")
        }

        return nil
    }
}
