//
//  HealthManager.swift
//  HKTest
//
//  Created by 王儒林 on 2016/12/5.
//  Copyright © 2016年 xingshulin. All rights reserved.
//

import Foundation
import HealthKit

typealias UIResponseCallback = (String) -> Void

private func ui(_ callback: @escaping UIResponseCallback, _ string: String) {
    DispatchQueue.main.async() {
        callback(string)
    }
}

class HealthManager {
    static let shared: HealthManager? = HKHealthStore.isHealthDataAvailable() ? HealthManager() : nil
    private init() {
    }

    private var healthStore = HKHealthStore()

    func askForPermit(_ callback: @escaping UIResponseCallback = { _ in }) {
        var shareSet = Set<HKSampleType>()
        shareSet.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        shareSet.insert(HKObjectType.quantityType(forIdentifier: .stepCount)!)
        shareSet.insert(HKObjectType.workoutType())
        var readSet: Set<HKObjectType> = shareSet
        readSet.insert(HKObjectType.activitySummaryType())
        readSet.insert(HKObjectType.characteristicType(forIdentifier: .biologicalSex)!)
        readSet.insert(HKObjectType.categoryType(forIdentifier: .appleStandHour)!)
        let allPermited = readSet.map { healthStore.authorizationStatus(for: $0) == .sharingAuthorized }.reduce(true) { lastResult, newValue in
            return lastResult && newValue
        }
        if !allPermited {
            healthStore.requestAuthorization(toShare: shareSet, read: readSet, completion: { (succeed, error) in
                print("____\(succeed)\n\(error)")
            })
        }
    }

    //MARK: test actions
    func makeCorrelation(_ callback: @escaping UIResponseCallback = { _ in }) {
        //失败了
        let dates = makeDateFrom(ago: 40, lasts: 20)
        var samples = Set<HKSample>()
        let riceSample = HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates)!, quantity: HKQuantity(unit: HKUnit.gram(), doubleValue: 200), start: dates.startDate, end: dates.endDate, metadata: [HKMetadataKeyFoodType: "rice"])
        samples.insert(riceSample)

        let correlation = HKCorrelation(type: HKObjectType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.food)!, start: dates.startDate, end: dates.endDate, objects: samples)
        healthStore.save(correlation) { complete, error in
            let succeed = complete ? "成功" : "失败"
            ui(callback, "\(#function)\n\(succeed)\n\(error)")
        }
    }
    func makeCategory(_ callback: @escaping UIResponseCallback = { _ in }) {
        let dates = makeDateFrom(ago: 160, lasts: 10)
        let sample = HKCategorySample(type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, value:  HKCategoryValueSleepAnalysis.asleep.rawValue, start: dates.startDate, end: dates.endDate)
        healthStore.save(sample) { complete, error in
            let succeed = complete ? "成功" : "失败"
            ui(callback, "\(#function)\n\(succeed)\n\(error)")
        }
    }
    func makeSwimmingWorkoutTest(_ callback: @escaping UIResponseCallback = { _ in }) {
        let intervalDates = makeDateFrom(ago: 66, lasts: 15)
        let dates = makeDateFrom(ago: 66, lasts: 32)

        let event0 = HKWorkoutEvent(type: .resume, date: intervalDates.startDate)
        let event1 = HKWorkoutEvent(type: .pause, date: intervalDates.endDate)
        let event2 = HKWorkoutEvent(type: .resume, date: Date(timeInterval: 60 * 2, since: intervalDates.endDate))
        let event3 = HKWorkoutEvent(type: .pause, date: dates.endDate)
        let workout = HKWorkout(activityType: .swimming, start: dates.startDate, end: dates.endDate, workoutEvents: [event0, event1, event2, event3], totalEnergyBurned: nil, totalDistance: HKQuantity(unit: HKUnit.meter(), doubleValue: 750), totalSwimmingStrokeCount: HKQuantity(unit: HKUnit.count(), doubleValue: 240), device: nil, metadata: nil)

        healthStore.save(workout) { complete, error in
            let succeed = complete ? "成功" : "失败"
            ui(callback, "_____\(succeed)\n\(error)")
        }
    }

    func makeWalk(steps: Int, _ callback: @escaping UIResponseCallback = { _ in }) {
        let intervalDates = makeDateFrom(ago: 30, lasts: 10)

        let sample = HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: .stepCount)!, quantity: HKQuantity(unit: HKUnit.count(), doubleValue: Double(steps)), start: intervalDates.startDate, end: intervalDates.endDate, metadata: nil)
        healthStore.save(sample) { succeed, error in
            ui(callback, "____\(succeed)\n\(error)")
        }
    }

    //MARK: query
    func queryTest(_ callback: @escaping UIResponseCallback = { _ in }) {
        let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: nil, limit: 100, resultsHandler: { (query, samples, deleteds, anchor, error) in
            let sams = samples ?? []
            ui(callback, "\(sams)")
        })
        healthStore.execute(query)
    }

    func queryActivitySymmary(_ callback: @escaping UIResponseCallback = { _ in }) {

        let query = HKActivitySummaryQuery(predicate: nil) { query, summary, error in
            ui(callback, "______summary\(summary)")
        }
        healthStore.execute(query)
    }

    func querySource(_ callback: @escaping UIResponseCallback = { _ in }) {
        let query = HKSourceQuery(sampleType: HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.appleStandHour)!, samplePredicate: nil) { query, sources, error in
            guard let sources = sources else {
                return
            }
            let s = sources.map { source in
                return source.name
                }.reduce("") { sum, nextValue in
                return sum == "" ? nextValue : "\(sum)\n\(nextValue)"
            }
            ui(callback, "sources\n\(s)")
        }
        healthStore.execute(query)
    }

    func queryTodayStepCountBySourceQuery(_ callback: @escaping UIResponseCallback = { _ in }) {
        let now = Date()
        let startDate = now.startOfThisDay()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [HKQueryOptions.strictStartDate])
        let query = HKSourceQuery(sampleType: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!, samplePredicate: predicate) { query, sources, error in
            guard let sources = sources else {
                return
            }
            let s = sources.map { source in
                return source.name
                }.reduce("") { sum, nextValue in
                    return sum == "" ? nextValue : "\(sum)\n\(nextValue)"
            }
            ui(callback, "sources\n\(s)")
        }

        healthStore.execute(query)
    }
    ///StatisticsQuery
    func queryTodayStepCountByStatisticsQuery(_ callback: @escaping UIResponseCallback = { _ in }) {
        let now = Date()
        let today = now.startOfThisDay()

        let predicate = HKQuery.predicateForSamples(withStart: today, end: now, options: [HKQueryOptions.strictStartDate])
        let query = HKStatisticsQuery(quantityType: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!, quantitySamplePredicate: predicate, options: [.cumulativeSum, .separateBySource]) { [unowned self] query, statistics, error in
            guard let statistics = statistics else {
                return
            }
            ui(callback, self.readStatistics(statistics))
        }
        healthStore.execute(query)
    }
    func queryTodayStepCountByStatisticsCollectionQuery(_ callback: @escaping UIResponseCallback = { _ in }) {
        let now = Date()
        let startDate = now.aMonthAgo()!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [HKQueryOptions.strictStartDate])
        var dateComponents = DateComponents()
        dateComponents.day = 2

        let query = HKStatisticsCollectionQuery(quantityType: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!, quantitySamplePredicate: predicate, options: [.cumulativeSum, .separateBySource], anchorDate: startDate, intervalComponents: dateComponents)
        query.initialResultsHandler = { query, collection, error in
            guard let collection = collection else {
                return
            }
            collection.enumerateStatistics(from: startDate, to: now, with: { [unowned self] statistics, stop in
                let statisticsString = self.readStatistics(statistics)
                ui(callback, statisticsString)
            })
        }
        healthStore.execute(query)
    }

    func queryObserverQuery(_ callback: @escaping UIResponseCallback = { _ in }) {
        let now = Date()
        let startDate = now.aWeekAgo()!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [HKQueryOptions.strictStartDate])
        let query = HKObserverQuery(sampleType: HKObjectType.quantityType(forIdentifier: .stepCount)!, predicate: predicate) { query, handler, error in
        }
        healthStore.execute(query)
    }

    func querySex(_ callback: @escaping UIResponseCallback = { _ in }) {
        let sex = try? healthStore.biologicalSex()
        if let sex = sex {
            ui(callback, sex.biologicalSex.stringValue())
        }
    }
}

//MARK: private methods
private extension HealthManager {
    func readStatistics(_ statistics: HKStatistics) -> String {
        var startDate = statistics.startDate.description(with: Locale.current)
        startDate = startDate.substring(to: startDate.index(startDate.startIndex, offsetBy: 11))
        var endDate = statistics.endDate.description(with: Locale.current)
        endDate = endDate.substring(to: endDate.index(endDate.startIndex, offsetBy: 11))
        let statisticStrs: [String] = statistics.sources?.map { source in
            let name = source.name
            let identifier = source.bundleIdentifier
            let quantity = statistics.sumQuantity(for: source).map { "\($0)" } ?? "(null)"
            return "\(name):\(quantity) \(identifier)"
            } ?? []

        let statisticStr = statisticStrs.joined(separator: "\n\n")
        let resp = ["步数\nfrom:\n\(startDate)\nto:\n\(endDate)\nBy:\n\n\(statisticStr)\n\n________",
            "Merge后步数\(statistics.sumQuantity().map { "\($0)" } ?? "")"].joined(separator: "\n")
        return resp
    }
    func makeDateFrom(ago minutesAgo: Int, lasts minutes: Int) -> (startDate: Date, endDate: Date) {
        let startDate = Date(timeIntervalSinceNow: TimeInterval(0 - 60 * minutesAgo))
        let endDate = Date(timeInterval: TimeInterval(60 * minutes), since: startDate)
        return (startDate: startDate, endDate: endDate)
    }
}

private extension Date {
    static func startOfToday() -> Date? {
        return Date().startOfThisDay()
    }

    func dateComponents() -> DateComponents {
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
    }

    func startOfThisDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }

    func endOfThisDay() -> Date? {
        return Calendar.current.date(byAdding: Calendar.Component.day, value: 1, to: startOfThisDay())
    }

    func aWeekAgo() -> Date? {
        return Calendar.current.date(byAdding: .weekOfYear, value: -1, to: self)
    }

    func thirtyDaysAgo() -> Date? {
        return Calendar.current.date(byAdding: .day, value: -30, to: self)
    }

    func aMonthAgo() -> Date? {
        return Calendar.current.date(byAdding: .month, value: -1, to: self)
    }
}

extension HKBiologicalSex {
    func stringValue() -> String {
        switch self {
        case .notSet:
            return "unknown"
        case .male:
            return "male"
        case .female:
            return "female"
        case .other:
            return "other"
        }
    }
}
