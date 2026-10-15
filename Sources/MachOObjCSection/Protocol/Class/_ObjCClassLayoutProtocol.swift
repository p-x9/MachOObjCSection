//
//  _ObjCClassLayoutProtocol.swift
//
//
//  Created by p-x9 on 2024/08/06
//  
//

import Foundation

// ref: https://github.com/apple-oss-distributions/objc4/blob/89543e2c0f67d38ca5211cea33f42c51500287d5/runtime/objc-runtime-new.h#L2714
public protocol _ObjCClassLayoutProtocol {
    associatedtype Pointer: FixedWidthInteger

    var isa: Pointer { get }
    var superclass: Pointer { get }
    var methodCacheBuckets: Pointer { get }
    var methodCacheProperties: Pointer { get }
    var dataVMAddrAndFastFlags: Pointer { get }
}

public enum ObjCClassLayoutField {
    case isa
    case superclass
    case methodCacheBuckets
    case methodCacheProperties
    case dataVMAddrAndFastFlags
}
