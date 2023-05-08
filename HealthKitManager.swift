//
//  HealthKitManager.swift
//  HealthKitDemo
//
//  Created by Harshit on 23/11/19.
//  Copyright © 2019 Harshit. All rights reserved.
//

import Foundation
import HealthKit

enum HealthkitSetupError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
    case authorizationFailed
}

typealias CompletionHandler = (([[String: Any]]?, Error?) -> Void)

@objc protocol HealthStoreProtocol {
    func requestAuthorization(completion: @escaping (Bool,Error?) -> Void)
    func getSteps(From startDate: Date, To endDate: Date,interval:DateComponents ,isDayInterval:Bool, completion: @escaping CompletionHandler)
    func getDistance(From startDate: Date, To endDate: Date,interval:DateComponents ,isDayInterval:Bool, completion: @escaping CompletionHandler)
    @objc optional func getEnergy(From startDate: Date, To endDate: Date,interval:DateComponents ,isDayInterval:Bool, completion: @escaping CompletionHandler)
}


final class HealthKitManager {
    
    // MARK: - Fileprivate variables
    
    fileprivate let healthStore: HKHealthStore
    
    // MARK: - Init method
    
    init(healthStore: HKHealthStore = HKHealthStore()){
        self.healthStore = healthStore
    }
    
    
    // MARK: - Fileprivate methods
    
    fileprivate func record(data: inout [[String: Any]], strDate: Date, endDate : Date, quantity: HKQuantity, isDayInterval : Bool) {
        // THE DATA IS BEING STORED IN A DICTIONARY
        // WHERE KEY -> DATE & VALUE -> STEPS/DISTANCE IN (COUNT/KM)
        
        var recordDict: [String: Any] = [:]
        
        if quantity.is(compatibleWith: HKUnit.meter()) {
            let distance = quantity.doubleValue(for: HKUnit.meter()) / 1000.0
            recordDict["Steps"] = 0
            recordDict["Distance"] = distance
            if endDate > Date(){
                recordDict["Date"] = endDate.stringValue
            }else{
                
            }
            if isDayInterval{
                recordDict["Date"] = endDate.previousDay.stringValue
            }else{
                recordDict["Date"] = endDate.stringValue
            }
            recordDict["StepsSource"] = 0
            if recordDict["Distance"] as! Double != 0{
                data.append(recordDict)
            }
        }else if quantity.is(compatibleWith: HKUnit.count()) {
            let count = quantity.doubleValue(for: HKUnit.count())
            recordDict["Steps"] = Int(round(count))
            debugPrint("We found count =  \(count)")
            var distance: Double = 0
            let height = 1.7 //average human height in meters
            let stride = height * 0.43 //average stride to height ratio
            distance = (Double(count) * stride)
            recordDict["Distance"] = distance
            if isDayInterval{
                if endDate >= Date(){
                    recordDict["Date"] = Date().stringValue
                }else{
                    recordDict["Date"] = endDate.previousDay.stringValue
                }
            }else{
                if endDate > Date(){
                    recordDict["Date"] = Date().stringValue
                }else{
                    recordDict["Date"] = endDate.stringValue
                }
            }
            recordDict["StepsSource"] = 0
            if recordDict["Steps"] as! Int != 0{
                data.append(recordDict)
            }
        }else if quantity.is(compatibleWith: HKUnit.kilocalorie()) {
            let distance = quantity.doubleValue(for: HKUnit.kilocalorie())
            recordDict["Energy"] = distance
            if endDate > Date(){
                recordDict["Date"] = endDate.stringValue
            }else{
                
            }
            if isDayInterval{
                recordDict["Date"] = endDate.previousDay.stringValue
            }else{
                recordDict["Date"] = endDate.stringValue
            }
            recordDict["StepsSource"] = 0
            if recordDict["Energy"] as! Double != 0{
                data.append(recordDict)
            }
        }
        
    }
    
    fileprivate func performCollectionQuery(sampleType: HKQuantityType, startDate: Date, endDate: Date,interval:DateComponents,isDayInterval : Bool, completion: @escaping CompletionHandler) {
//        var predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        /// if we want remove mannual entry uncomment theese lines
                var predicate = HKQuery.predicateForSamples(withStart:startDate , end: endDate, options: [.strictStartDate, .strictEndDate])
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate , NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)])
        var interval = interval
        
        
        let query = HKStatisticsCollectionQuery(quantityType: sampleType,
                                                quantitySamplePredicate: predicate,
                                                options: [.cumulativeSum],
                                                anchorDate: startDate,
                                                intervalComponents: interval)
        
        query.initialResultsHandler = { query, results, error in
            if error != nil {
                completion(nil, error)
                return
            }
            
            if let myResults = results {
                
                var data: [[String : Any]] = []
                
                myResults.enumerateStatistics(from: startDate, to: endDate) { [weak self] statistics, stop in
                    
                    if let quantity = statistics.sumQuantity() {
                        self?.record(data: &data, strDate: statistics.startDate,endDate :statistics.endDate, quantity: quantity, isDayInterval: isDayInterval)
                        debugPrint(" \(statistics.endDate)  and \(quantity)")
                    }
                    else {
                        if statistics.quantityType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue {
                            let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: 0.0)
                            if quantity.is(compatibleWith: HKUnit.count()) {
                                let count = quantity.doubleValue(for: HKUnit.count())
                                if count != 0 {
                                    self?.record(data: &data, strDate: statistics.startDate,endDate :statistics.endDate, quantity: quantity, isDayInterval: isDayInterval)
                                }
                            }
                        }
                        else if statistics.quantityType.identifier == HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue {
                            let quantity = HKQuantity(unit: HKUnit.meter(), doubleValue: 0.0)
                            self?.record(data: &data, strDate: statistics.startDate,endDate :statistics.endDate, quantity: quantity, isDayInterval: isDayInterval)
                        }else if statistics.quantityType.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue{
                            let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 0.0)
                            if quantity.is(compatibleWith: HKUnit.count()) {
                                let count = quantity.doubleValue(for: HKUnit.kilocalorie())
                                if count != 0 {
                                    self?.record(data: &data, strDate: statistics.startDate,endDate :statistics.endDate, quantity: quantity, isDayInterval: isDayInterval)
                                }
                            }
                        }
                    }
                }
                completion(data, nil)
                return
            }
            
            completion(nil, HealthkitSetupError.notAvailableOnDevice)
        }
        
        self.healthStore.execute(query)
    }
    
    fileprivate func fetchData(For sampleType: HKQuantityType, from startDate: Date, to endDate: Date,interval:DateComponents,isDayInterval: Bool, completion: @escaping CompletionHandler) {
        performCollectionQuery(sampleType: sampleType,
                               startDate: startDate,
                               endDate: endDate, interval: interval, isDayInterval: isDayInterval,
                               completion: completion)
    }
    
}

// MARK: - HealthStoreProtocol methods implementation
// MARK: -

extension HealthKitManager: HealthStoreProtocol {
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthkitSetupError.notAvailableOnDevice)
            return
        }
        
        guard let distanceWalkingRunningType = HKQuantityType.quantityType(forIdentifier:.distanceWalkingRunning),
              let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return completion(false, HealthkitSetupError.dataTypeNotAvailable)
        }
        
        let dataTypesToRead: Set<HKObjectType> = [distanceWalkingRunningType, stepsType]
        
        healthStore.requestAuthorization(toShare: nil, read: dataTypesToRead, completion: completion)
        
    }
    
    func getSteps(From startDate: Date, To endDate: Date,interval:DateComponents ,isDayInterval: Bool,completion: @escaping CompletionHandler) {
        guard let sampleTypeSteps = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount) else {
            completion(nil, HealthkitSetupError.dataTypeNotAvailable)
            return
        }
        fetchData(For: sampleTypeSteps, from: startDate, to: endDate, interval: interval, isDayInterval: isDayInterval, completion: completion)
    }
    func getDistance(From startDate: Date, To endDate: Date,interval:DateComponents,isDayInterval: Bool, completion: @escaping CompletionHandler) {
        guard let sampleTypeDistance = HKQuantityType.quantityType(forIdentifier:
                                                                    HKQuantityTypeIdentifier.distanceWalkingRunning) else {
            completion(nil, HealthkitSetupError.dataTypeNotAvailable)
            return
        }
        fetchData(For: sampleTypeDistance, from: startDate, to: endDate, interval: interval, isDayInterval: isDayInterval, completion: completion)
    }
    
    func getEnergy(From startDate: Date, To endDate: Date,interval:DateComponents ,isDayInterval: Bool,completion: @escaping CompletionHandler) {
        guard let sampleTypeSteps = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned) else {
            completion(nil, HealthkitSetupError.dataTypeNotAvailable)
            return
        }
        fetchData(For: sampleTypeSteps, from: startDate, to: endDate, interval: interval, isDayInterval: isDayInterval, completion: completion)
    }
    
}
extension Date {
    var stringValue: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.string(from: self)
    }
    
    /*
     THIS METHOD WILL SUBTRACT THE days FROM THE CURRENT DATE AND RETURNS THE DATE AS AS START DATE
     EX - SUPPOSE TODAYS DATE IS 27/11/19 AND days = 2
     SO IT WILL RETURN 25/11/19 AS START DATE.
     */
    
    func getDateFromNow(whenDifferenceInDays days: Int) -> Date? {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -(days - 1), to: self) else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }
}
