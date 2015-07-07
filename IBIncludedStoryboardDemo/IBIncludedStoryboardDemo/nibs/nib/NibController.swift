//
//  NibController.swift
//
//  Created by Emily Ivie on 4/11/15.
//

import UIKit

class NibController: UIViewController, IBIncludedSegueableController {

    @IBOutlet weak var clickButton: UIButton!
    @IBOutlet weak var clickButton2: UIButton!
    
    var storedValue = "Unset"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        //no longer called, sorry!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //yes, this works also!
    }
    
    @IBAction func clickedButton(sender: UIButton) {
        storedValue = sender == clickButton ? "1" : "2"
        
        // you can also set prepareAfterIBIncludedSegue here:
        //let someValue = storedValue
        //prepareAfterIBIncludedSegue = { (destination) in
        //    if let includedDestination = destination as? Nib2Controller {
        //        includedDestination.sentValue = storedValue
        //    }
        //}

        parentViewController?.performSegueWithIdentifier("Page 2 Segue", sender: sender)
    }
    
    lazy var prepareAfterIBIncludedSegue: PrepareAfterIBIncludedSegueType = { (destination) in
        if let includedDestination = destination as? Nib2Controller {
            includedDestination.sentValue = self.storedValue
        }
    }

}