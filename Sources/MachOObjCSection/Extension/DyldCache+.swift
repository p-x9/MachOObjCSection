//
//  DyldCache+.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/11/02
//
//

import Foundation
@_spi(Support) import MachOKit
#if compiler(>=6.0) || (compiler(>=5.10) && hasFeature(AccessLevelOnImport))
internal import FileIO
#else
@_implementationOnly import FileIO
#endif

extension FileHandleHolder<any FileHandleIdentity & AnyObject, DyldCache.File> {
    static let shared: FileHandleHolder<Owner, File> = .init()
}

extension DyldCache {
    internal typealias File = MemoryMappedFile

    var fileHandle: File {
        FileHandleHolder.shared.fileHandle(
            for: fileHandleIdentity,
            initialize: {
                try! .open(url: url, isWritable: false)
            }
        )
    }
}

extension DyldCache {
    var fileStartOffset: UInt64 {
        numericCast(
            header.sharedRegionStart - mainCacheHeader.sharedRegionStart
        )
    }
}

// MARK: - Objective-C
extension DyldCache {
    var _objcOptimization: LocatedValue<ObjCOptimization>? {
        try? locateValue(\.objcOptimization)
    }

    var _oldObjcOptimization: LocatedValue<OldObjCOptimization>? {
        try? locateValue(\.oldObjcOptimization)
    }
}

extension DyldCache {
    var headerOptimizationRO64: ObjCHeaderOptimizationRO64? {
        guard cpu.is64Bit else { return nil }
        if let _objcOptimization {
            return _objcOptimization.value.headerOptimizationRO64(in: self)
        }
        if let _oldObjcOptimization {
            return _oldObjcOptimization.value.headerOptimizationRO64(in: self)
        }
        return nil
    }

    var headerOptimizationRO32: ObjCHeaderOptimizationRO32? {
        guard !cpu.is64Bit else { return nil }
        if let _objcOptimization {
            return _objcOptimization.value.headerOptimizationRO32(in: self)
        }
        if let _oldObjcOptimization {
            return _oldObjcOptimization.value.headerOptimizationRO32(in: self)
        }
        return nil
    }
}

extension DyldCache {
    var _headerOptimizationRO64: LocatedValue<ObjCHeaderOptimizationRO64>? {
        try? locateValue(\.headerOptimizationRO64)
    }

    var _headerOptimizationRO32: LocatedValue<ObjCHeaderOptimizationRO32>? {
        try? locateValue(\.headerOptimizationRO32)
    }
}

extension DyldCache {
    func _machO(at index: Int) -> LocatedValue<MachOFile>? {
        if let located = _headerOptimizationRO64,
           located.value.contains(index: index) {
            let headers = located.value.headerInfos(in: located.cache)
            guard let header = headers?.first(
                where: {
                    $0.index == index
                }
            ) else {
                return nil
            }
            return try? locateValue { header.machO(in: $0) }
        }
        if let located = _headerOptimizationRO32,
           located.value.contains(index: index) {
            let headers = located.value.headerInfos(in: located.cache)
            guard let header = headers?.first(
                where: {
                    $0.index == index
                }
            ) else {
                return nil
            }
            return try? locateValue { header.machO(in: $0) }
        }
        return nil
    }
}

// MARK: - mach-o
extension DyldCache {
    func machO(containing unslidAddress: UInt64) -> MachOFile? {
        for machO in self.machOFiles() {
            if machO.contains(unslidAddress: unslidAddress) {
                return machO
            }
        }
        return nil
    }
}

@inline(__always)
private func isEqual(_ lhs: uuid_t, _ rhs: uuid_t) -> Bool {
    lhs.0 == rhs.0 &&
    lhs.1 == rhs.1 &&
    lhs.2 == rhs.2 &&
    lhs.3 == rhs.3 &&
    lhs.4 == rhs.4 &&
    lhs.5 == rhs.5 &&
    lhs.6 == rhs.6 &&
    lhs.7 == rhs.7 &&
    lhs.8 == rhs.8 &&
    lhs.9 == rhs.9 &&
    lhs.10 == rhs.10 &&
    lhs.11 == rhs.11 &&
    lhs.12 == rhs.12 &&
    lhs.13 == rhs.13 &&
    lhs.14 == rhs.14 &&
    lhs.15 == rhs.15
}
