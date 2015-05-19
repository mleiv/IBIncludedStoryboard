//
//  NibController.swift
//
//  Created by Emily Ivie on 4/11/15.
//

import UIKit

class Nib2Controller: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    
    var sentValue: String = "?" {
        didSet{
            setup()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //yes, this works also!
    }
    
    func setup() {
        titleLabel.text = "Sent Value: \(sentValue)"
    }

}