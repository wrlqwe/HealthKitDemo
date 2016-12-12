//
//  ViewController.swift
//  HKTest
//
//  Created by 王儒林 on 2016/12/3.
//  Copyright © 2016年 xingshulin. All rights reserved.
//

import UIKit
import HealthKit
class ViewController: UIViewController {

    var stepCountIdentifier = HKQuantityTypeIdentifier.stepCount
    @IBAction func buttonTapped(_ sender: Any) {
//        HealthManager.shared?.makeSwimmingWorkoutTest({ (completion, error) in
//            print("_____________\(completion) \n \(error)")
//        })
        HealthManager.shared?.makeSwimmingWorkoutTest(showTip)
//        HealthManager.shared?.makeCorrelation(showTip)
//        HealthManager.shared?.makeCategory(showTip)
    }
    @IBAction func querySummary(_ sender: Any) {
        HealthManager.shared?.queryTodayStepCountByStatisticsCollectionQuery(showTip)
//        HealthManager.shared?.querySource()
//        HealthManager.shared?.queryTodayStepCountByStatisticsQuery(showTip)
//        HealthManager.shared?.queryTodayStepCountByStatisticsCollectionQuery(showTip)
//        HealthManager.shared?.querySource(showTip)
//        HealthManager.shared?.queryTodayStepCountBySourceQuery(showTip)
//        HealthManager.shared?.querySex(showTip)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        HealthManager.shared?.askForPermit()
    }


    //MARK: queue the tips
    let semaphore = DispatchSemaphore(value: 0)
    let backQueue = DispatchQueue(label: "tipsQueue")
    func showTip(tip: String) {
        let semaphoreLocal = semaphore
        let backQueueLocal = backQueue
        backQueueLocal.async {
            DispatchQueue.main.async { [weak self] in
                let vc = UIAlertController(title: nil, message: tip, preferredStyle: .alert)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = NSTextAlignment.left
                let text = NSAttributedString(string: tip, attributes: [
                    NSParagraphStyleAttributeName: paragraphStyle,
                    NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body),
                    NSForegroundColorAttributeName: UIColor.black
                    ])
                vc.setValue(text, forKey: "attributedMessage")
                vc.addAction(UIAlertAction(title: "ok", style: .default) { _ in
                    semaphoreLocal.signal()
                })
                self?.present(vc, animated: true, completion: nil)
            }
            semaphoreLocal.wait()
        }
    }
}
