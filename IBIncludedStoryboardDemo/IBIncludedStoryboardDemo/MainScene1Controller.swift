//
//  MainScene1Controller.swift
//  IBIncludedStoryboardDemo
//
//  Created by Emily Ivie on 5/19/15.
//  Copyright (c) 2015 Emily Ivie. All rights reserved.
//

import UIKit

class MainScene1Controller: IBIncludedWrapperViewController, IBIncludedSegueableController {

    @IBOutlet weak var textField: UITextField!
    
    lazy var prepareAfterIBIncludedSegue: PrepareAfterIBIncludedSegueType = { (destination) in
        if let includedDestination = destination as? SecondScene1Controller {
            includedDestination.sentValue = self.textField?.text ?? ""
            return true
        }
        return false
    }
}