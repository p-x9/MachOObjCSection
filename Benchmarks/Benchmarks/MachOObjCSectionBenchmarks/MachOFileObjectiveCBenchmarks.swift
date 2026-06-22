import Benchmark
import Foundation
import MachOKit
import MachOObjCSection

func registerMachOFileObjectiveCBenchmarks() {
    Benchmark("MachOFile.objc.classes.enumerate") { benchmark in
        let machO = BenchmarkFixtures.machOFile()

        benchmark.startMeasurement()

        blackHole(objcClasses(in: machO))
    }

    Benchmark("MachOFile.objc.classInfo.first100") { benchmark in
        let machO = BenchmarkFixtures.machOFile()
        let classes = objcClasses(in: machO)
        let limit = BenchmarkFixtures.classInfoLimit()

        benchmark.startMeasurement()

        var count = 0
        for cls in classes.prefix(limit) {
            blackHoleClassInfo(for: cls, in: machO)
            count += 1
        }
        blackHole(count)
    }

    Benchmark("MachOFile.objc.protocols.enumerate") { benchmark in
        let machO = BenchmarkFixtures.machOFile()

        benchmark.startMeasurement()

        blackHole(objcProtocols(in: machO))
    }

    Benchmark("MachOFile.objc.protocolInfo.first100") { benchmark in
        let machO = BenchmarkFixtures.machOFile()
        let protocols = objcProtocols(in: machO)
        let limit = BenchmarkFixtures.classInfoLimit()

        benchmark.startMeasurement()

        var count = 0
        for proto in protocols.prefix(limit) {
            blackHoleProtocolInfo(for: proto, in: machO)
            count += 1
        }
        blackHole(count)
    }

    Benchmark("MachOFile.objc.categories.enumerate") { benchmark in
        let machO = BenchmarkFixtures.machOFile()

        benchmark.startMeasurement()

        blackHole(objcCategories(in: machO))
    }

    Benchmark("MachOFile.objc.categoryInfo.first100") { benchmark in
        let machO = BenchmarkFixtures.machOFile()
        let categories = objcCategories(in: machO)
        let limit = BenchmarkFixtures.classInfoLimit()

        benchmark.startMeasurement()

        var count = 0
        for category in categories.prefix(limit) {
            blackHoleCategoryInfo(for: category, in: machO)
            count += 1
        }
        blackHole(count)
    }

    Benchmark("MachOFile.objc.methods.lists") { benchmark in
        let machO = BenchmarkFixtures.machOFile()

        benchmark.startMeasurement()

        var count = 0
        if let lists = machO.objc.methods {
            for list in lists {
                blackHole(list)
                count += 1
            }
        }
        blackHole(count)
    }

    Benchmark("MachOFile.objc.methods.entries") { benchmark in
        let machO = BenchmarkFixtures.machOFile()
        let lists: [ObjCMethodList] = machO.objc.methods.map { Array($0) } ?? []

        benchmark.startMeasurement()

        var count = 0
        for list in lists {
            let methods = list.methods(in: machO) ?? []
            blackHole(methods)
            count += methods.count
        }
        blackHole(count)
    }

    guard BenchmarkFixtures.hasDyldCache else { return }

    Benchmark("DyldCache.MachOFile.objc.classes.enumerate") { benchmark in
        guard let machO = BenchmarkFixtures.cacheMachOFile(benchmark: benchmark) else { return }

        benchmark.startMeasurement()

        blackHole(objcClasses(in: machO))
    }

    Benchmark("DyldCache.MachOFile.objc.classInfo.first100") { benchmark in
        guard let machO = BenchmarkFixtures.cacheMachOFile(benchmark: benchmark) else { return }
        let classes = objcClasses(in: machO)
        let limit = BenchmarkFixtures.classInfoLimit()

        benchmark.startMeasurement()

        var count = 0
        for cls in classes.prefix(limit) {
            blackHoleClassInfo(for: cls, in: machO)
            count += 1
        }
        blackHole(count)
    }

    Benchmark("DyldCache.MachOFile.objc.protocols.enumerate") { benchmark in
        guard let machO = BenchmarkFixtures.cacheMachOFile(benchmark: benchmark) else { return }

        benchmark.startMeasurement()

        blackHole(objcProtocols(in: machO))
    }

    Benchmark("DyldCache.MachOFile.objc.protocolInfo.first100") { benchmark in
        guard let machO = BenchmarkFixtures.cacheMachOFile(benchmark: benchmark) else { return }
        let protocols = objcProtocols(in: machO)
        let limit = BenchmarkFixtures.classInfoLimit()

        benchmark.startMeasurement()

        var count = 0
        for proto in protocols.prefix(limit) {
            blackHoleProtocolInfo(for: proto, in: machO)
            count += 1
        }
        blackHole(count)
    }

    Benchmark("DyldCache.MachOFile.objc.categories.enumerate") { benchmark in
        guard let machO = BenchmarkFixtures.cacheMachOFile(benchmark: benchmark) else { return }

        benchmark.startMeasurement()

        blackHole(objcCategories(in: machO))
    }

    Benchmark("DyldCache.MachOFile.objc.categoryInfo.first100") { benchmark in
        guard let machO = BenchmarkFixtures.cacheMachOFile(benchmark: benchmark) else { return }
        let categories = objcCategories(in: machO)
        let limit = BenchmarkFixtures.classInfoLimit()

        benchmark.startMeasurement()

        var count = 0
        for category in categories.prefix(limit) {
            blackHoleCategoryInfo(for: category, in: machO)
            count += 1
        }
        blackHole(count)
    }
}

private enum ObjCClass {
    case class64(ObjCClass64)
    case class32(ObjCClass32)
}

private enum ObjCProtocol {
    case protocol64(ObjCProtocol64)
    case protocol32(ObjCProtocol32)
}

private enum ObjCCategory {
    case category64(ObjCCategory64)
    case category32(ObjCCategory32)
}

private func objcClasses(in machO: MachOFile) -> [ObjCClass] {
    if machO.is64Bit {
        return (machO.objc.classes64 ?? []).map(ObjCClass.class64)
    }
    return (machO.objc.classes32 ?? []).map(ObjCClass.class32)
}

private func objcProtocols(in machO: MachOFile) -> [ObjCProtocol] {
    if machO.is64Bit {
        return (machO.objc.protocols64 ?? []).map(ObjCProtocol.protocol64)
    }
    return (machO.objc.protocols32 ?? []).map(ObjCProtocol.protocol32)
}

private func objcCategories(in machO: MachOFile) -> [ObjCCategory] {
    if machO.is64Bit {
        return (machO.objc.categories64 ?? []).map(ObjCCategory.category64)
    }
    return (machO.objc.categories32 ?? []).map(ObjCCategory.category32)
}

private func blackHoleClassInfo(for cls: ObjCClass, in machO: MachOFile) {
    switch cls {
    case let .class64(cls):
        blackHole(cls.info(in: machO))
    case let .class32(cls):
        blackHole(cls.info(in: machO))
    }
}

private func blackHoleProtocolInfo(for proto: ObjCProtocol, in machO: MachOFile) {
    switch proto {
    case let .protocol64(proto):
        blackHole(proto.info(in: machO))
    case let .protocol32(proto):
        blackHole(proto.info(in: machO))
    }
}

private func blackHoleCategoryInfo(for category: ObjCCategory, in machO: MachOFile) {
    switch category {
    case let .category64(category):
        blackHole(category.info(in: machO))
    case let .category32(category):
        blackHole(category.info(in: machO))
    }
}
