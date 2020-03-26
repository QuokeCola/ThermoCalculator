//
//  DataSourceStructure.swift
//  ThermoCalc
//
//  Created by 钱晨 on 2020/3/23.
//  Copyright © 2020年 钱晨. All rights reserved.
//

import Foundation

struct calculatedRes {
    let p: String
    let v: String
    let T: String
    let h: String
    let u: String
    let x: String
    let State: String
    let Substance: String
    func get_result()->String{
        return "State:\(State), P:\(p), V:\(v), T:\(T), h:\(h), u:\(u)"
    }
}

struct Result{
    let property1: String
    let property2: String
    let calculated_result: calculatedRes
}

enum substance_t {
    case Water
    case Refrigerant_22
    case Refrigerant_134a
    case Ammonia
    case Propane
}

var Results = [Result]()

private enum searchCondition_t{
    case p
    case v
    case t
    case h
    case u
}

func search(searchCommand: String) {
    var commandStrings = searchCommand.split(separator: ",")
    var SearchResult: Result
    //return SearchResult
}
