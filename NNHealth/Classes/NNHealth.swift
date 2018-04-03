//  NNHealth.swift
//  Pods
//
//  Created by  XMFraker on 2018/4/2
//  Copyright © XMFraker All rights reserved. (https://github.com/ws00801526)
//  @class      NNHealth
//  @version    <#class version#>
//  @abstract   <#class description#>

import UIKit
import HealthKit

public struct HealthDataOption: OptionSet, Hashable {

    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public var hashValue: Int { return self.rawValue }
    
    public static let none = HealthDataOption(rawValue: 0)
    /// 获取健康数据-步数-单位:步
    public static let stepCount = HealthDataOption(rawValue: 1)
    /// 获取健康数据-步行,跑步距离-单位:m
    public static let distanceWalkingRunning = HealthDataOption(rawValue: 2)
    /// 获取健康数据-楼层-单位:楼
    public static let flightsClimed = HealthDataOption(rawValue: 4)
    
    /// 获取健康数据-骑行距离-单位:m
    public static let distanceCycling = HealthDataOption(rawValue: 8)
    /// 获取健康数据-静息能力消耗-单位:J
    public static let basalEnergyBurned = HealthDataOption(rawValue: 16)
    /// 获取健康数据-活动能量消耗-单位:J
    public static let activeEnergyBurned = HealthDataOption(rawValue: 32)

    /// 获取健康数据-游泳距离-单位:m
    @available(iOS 10.0, *)
    public static let distanceSwimming = HealthDataOption(rawValue: 128)
}

public struct HealthData {
    public var startDate: Date?
    public var endDate: Date?
    public var value: Double = 0.0
    public var type: HealthDataOption = .none
    public var sample: HKSample?
}

public struct HealthError: LocalizedError {

    public enum NNHealthErrorCode {
        case unknown,unauth, unavailable, unsupportedData
    }
    public var code: NNHealthErrorCode = .unknown
    
    init(_ code: NNHealthErrorCode) {
        self.code = code
    }
    
    public var errorDescription: String? {
        switch self.code {
            case .unauth: return NSLocalizedString("", comment: "当前设备未授权使用健康数据")
            case .unavailable: return NSLocalizedString("", comment: "当前设备不支持健康数据")
            case .unsupportedData: return NSLocalizedString("", comment: "当前不支持该类型健康数据")
            default: return NSLocalizedString("", comment: "未知的健康数据错误")
        }
    }
}


public typealias HealthHandler = ([HealthData]?, HealthError?) -> (Void)
public class HealthManager: NSObject {

    public static let prevDayTimeInterval = Double(60 * 60 * 24 * -1)
    public static let instance = HealthManager()
    public static let store = HKHealthStore()

    /// iOS8+系统 根据指定的健康数据类型,日期 获取对应的健康数据记录
    ///
    /// - Parameters:
    ///   - options: 健康数据类型 详细查看HealthDataOption
    ///   - startDate: 数据开始日期, 默认前一天
    ///   - endDate:   数据结束日期, 默认当前日期
    ///   - handler:   数据读取完成后回调, 在主线程内回调
    public func readHealthDatas(_ options: HealthDataOption,
                                startDate: Date = Date(timeIntervalSinceNow: HealthManager.prevDayTimeInterval),
                                endDate: Date = Date(),
                                handler: @escaping HealthHandler) {
        // 判断健康数据是否可用
        if (HealthManager.isHealthStoreAvailable() == false) {
            HealthManager.callBackOnMainThread(datas: nil, error: HealthError(.unavailable), handler: handler)
            return
        }
        
        // 获取需要读取的健康数据类型
        let samples = HealthManager.sampleTypesOfOptions(options)
        if samples.count == 0 {
            HealthManager.callBackOnMainThread(datas: nil, error: HealthError(.unsupportedData), handler: handler)
            return
        }
       
        // 请求授权
        HealthManager.store.requestAuthorization(toShare: nil, read: Set(samples)) { (success, error) in
            
            // 利用DispatchGroup, 全部读取完成后进行回调
            var datas = [HealthData]()
            let group = DispatchGroup()
            if success, error == nil {
                samples.forEach{
                    group.enter()
                    HealthManager.queryHealthDatas($0,
                                          startDate: startDate,
                                          endDate: endDate,
                                          handler: { (healthDatas, error) in
                        if error == nil, let healthDatas = healthDatas { datas.append(contentsOf: healthDatas) }
                        group.leave()
                    })
                }
            } else {
                HealthManager.callBackOnMainThread(datas: nil, error: HealthError(.unauth), handler: handler)
            }
            
            group.notify(queue: DispatchQueue.main) {
                HealthManager.callBackOnMainThread(datas: datas, error: nil, handler: handler)
            }
        }
    }
}

extension HealthData {
    
    init(sample: HKSample) {
        self.sample = sample
        self.endDate = sample.endDate
        self.startDate = sample.startDate
    }
    
    init(quantitySample: HKQuantitySample) {
        self.init(sample: quantitySample)
        let identifier: HKQuantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: quantitySample.quantityType.identifier)
        let quantity: HKQuantity = quantitySample.quantity
        switch identifier {
            case .stepCount:
                self.type = .stepCount
                self.value = quantity.doubleValue(for: HKUnit.count())
            case .flightsClimbed:
                self.type = .flightsClimed
                self.value = quantity.doubleValue(for: HKUnit.count())
            case .distanceWalkingRunning:
                self.type = .distanceWalkingRunning
                self.value = quantity.doubleValue(for: HKUnit.meter())
            case .distanceCycling:
                self.type = .distanceCycling
                self.value = quantity.doubleValue(for: HKUnit.meter())
            case .basalEnergyBurned:
                self.type = .basalEnergyBurned
                self.value = quantity.doubleValue(for: HKUnit.joule())
            case .activeEnergyBurned:
                self.type = .activeEnergyBurned
                self.value = quantity.doubleValue(for: HKUnit.joule())
            default: break
        }
        
        if #available(iOS 10.0, *) {
            if identifier == .distanceSwimming {
                self.type = .distanceSwimming
                self.value = quantity.doubleValue(for: HKUnit.meter())
            }
        }
    }
}

extension HealthManager {
    
    class func callBackOnMainThread(datas: [HealthData]?, error: HealthError?, handler: @escaping HealthHandler) {
        if Thread.isMainThread {
            handler(datas, error)
        } else {
            DispatchQueue.main.async { handler(datas, error) }
        }
    }
}

extension Array {
    
    func groupBy<K: Hashable>(_ f: (Element) -> K) -> [K: [Element]] {

        return self.reduce([:], { (result, element) -> [K: [Element]] in

            let key = f(element)
            var ret = result
            if var values = result[key] {
                values.append(element)
                ret.updateValue(values, forKey: key)
            } else {
                ret.updateValue([element], forKey: key)
            }
            return ret
        })
    }
}

extension HealthManager {
    
    class func queryHealthDatas(_ sampleType: HKSampleType?,  startDate: Date? , endDate: Date?, handler: @escaping HealthHandler) {
        
        guard let sample = sampleType else { handler(nil, nil); return; }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions(rawValue: 0))
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sample, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { (query, samples, error) in
            if error == nil, let samples = samples {
                let datas = HealthManager.transformQuantitySamples(samples)
                handler(datas, nil)
            } else {
                handler(nil, HealthError(.unknown));
            }
        }
        HealthManager.store.execute(query)
    }
    
    class func transformQuantitySamples(_ samples: [HKSample]?) -> [HealthData]? {
        guard let samples = samples else { return nil }
        let datas = samples.flatMap{ HealthData(quantitySample: $0 as! HKQuantitySample ) }
        return datas
    }
    
    class func sampleTypesOfOptions(_ options: HealthDataOption) -> [HKSampleType] {

        var samples = [HKSampleType]()
        if options.contains(.stepCount), let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            samples.append(quantityType)
        }
        
        if options.contains(.flightsClimed), let quantityType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            samples.append(quantityType)
        }
        
        if options.contains(.distanceWalkingRunning), let quantityType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            samples.append(quantityType)
        }
        
        if #available(iOS 10.0, *),
            options.contains(.distanceSwimming),
            let quantityType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            samples.append(quantityType)
        }
        
        if options.contains(.distanceCycling), let quantityType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            samples.append(quantityType)
        }
        
        if options.contains(.basalEnergyBurned), let quantityType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            samples.append(quantityType)
        }
        
        if options.contains(.activeEnergyBurned), let quantityType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            samples.append(quantityType)
        }
        return samples
    }
    
    class func isHealthStoreAvailable() -> Bool {
        if #available(iOS 8.0, *) { return HKHealthStore.isHealthDataAvailable() }
        return false
    }
}

