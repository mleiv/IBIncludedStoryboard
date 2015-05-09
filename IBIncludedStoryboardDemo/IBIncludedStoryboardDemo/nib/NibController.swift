//
//  NibController.swift
//
//  Created by Emily Ivie on 4/11/15.
//

import UIKit

class NibController: UIViewController {

    @IBOutlet weak var clickLabel: UILabel!
    @IBOutlet weak var clickButton: UIButton!
    
    private var clicks = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //yes, this works also!
    }
    
    @IBAction func clickedButton(sender: UIButton) {
        parentViewController?.performSegueWithIdentifier("Page2 Segue", sender: sender)
    }

}