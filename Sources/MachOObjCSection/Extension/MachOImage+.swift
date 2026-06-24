//
//  MachOImage+.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/12/10
//  
//

import Foundation
import MachOKit

extension MachOImage {
    func findObjCSection64(for section: ObjCMachOSection) -> Section64? {
        findObjCSection64(for: section.rawValue)
    }

    func findObjCSection32(for section: ObjCMachOSection) -> Section? {
        findObjCSection32(for: section.rawValue)
    }

    // [dyld implementation](https://github.com/apple-oss-distributions/dyld/blob/66c652a1f1f6b7b5266b8bbfd51cb0965d67cc44/common/MachOFile.cpp#L3880)
    func findObjCSection64(for name: String) -> Section64? {
        let segmentNames = [
            "__DATA", "__DATA_CONST", "__DATA_DIRTY"
        ]
        let segments = segments64
        for segment in segments {
            guard segmentNames.contains(segment.segmentName) else {
                continue
            }
            if let section = segment._section(for: name, in: self) {
                return section
            }
        }
        return nil
    }

    func findObjCSection32(for name: String) -> Section? {
        let segmentNames = [
            "__DATA", "__DATA_CONST", "__DATA_DIRTY"
        ]
        let segments = segments32
        for segment in segments {
            guard segmentNames.contains(segment.segmentName) else {
                continue
            }
            if let section = segment._section(for: name, in: self) {
                return section
            }
        }
        return nil
    }
}

extension MachOImage {
    var objcImageIndex: Int? {
#if canImport(MachO)
        guard header.isInDyldCache else { return nil }
        guard let cache = DyldCacheLoaded.current else { return nil }
        if let headerOptimizationRO = cache.headerOptimizationRO64,
           let info = headerOptimizationRO.headerInfo(in: cache, for: self) {
            return info.index
        }
        if let headerOptimizationRO = cache.headerOptimizationRO32,
           let info = headerOptimizationRO.headerInfo(in: cache, for: self) {
            return info.index
        }
#endif
        return nil

    }
}
