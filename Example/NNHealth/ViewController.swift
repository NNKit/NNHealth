//
//  ViewController.swift
//  NNHealth
//
//  Created by ws00801526 on 04/02/2018.
//  Copyright (c) 2018 ws00801526. All rights reserved.
//

import UIKit
import NNHealth

class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var stepCountSwitch: UISwitch!
    @IBOutlet weak var distanceWalking: UISwitch!
    @IBOutlet weak var flightsClimbed: UISwitch!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func queryHealthDatas(_ sender: UIButton) {

        var option: HealthDataOption = .none
        if self.stepCountSwitch.isOn { option = option.union(.stepCount) }
        if self.flightsClimbed.isOn { option = option.union(.flightsClimed) }
        if self.distanceWalking.isOn { option = option.union(.distanceWalkingRunning) }
        
        HealthManager.instance.readHealthDatas(option) { (datas, error) -> (Void) in
            if error == nil, let datas = datas {
                self.textView.text = "query data is \(datas)"
            } else {
                self.textView.text = "some error hanppened \(error?.errorDescription ?? "unknown error")"
            }
        }
    }
}

