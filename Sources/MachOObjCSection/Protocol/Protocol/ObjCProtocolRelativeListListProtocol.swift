//
//  ObjCProtocolRelativeListListProtocol.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/12/01
//  
//

import Foundation

public protocol ObjCProtocolRelativeListListProtocol: RelativeListListProtocol where List: ObjCProtocolListProtocol {

    @_spi(Core)
    init(offset: Int, header: Header)

    @_spi(Core)
    init(ptr: UnsafeRawPointer, offset: Int)
}
