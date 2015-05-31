//
//  SecondScene1Controller.swift
//  IBIncludedStoryboardDemo
//
//  Created by Emily Ivie on 5/19/15.
//  Copyright (c) 2015 Emily Ivie. All rights reserved.
//

import UIKit

class SecondScene1Controller: UIViewController, IBIncludedSegueableController {
    @IBOutlet weak var label: UILabel!
    
    var sentValue: String = "None"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        label?.text = "Sent Value: \(sentValue)"
    }
}