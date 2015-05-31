//
//  NibController.swift
//
//  Created by Emily Ivie on 4/11/15.
//

import UIKit

class Nib2Controller: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    
    var sentValue: String = "?"
    
    override func awakeFromNib() {
        let x = 6
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Sent Value: \(sentValue)"
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //yes, this works also!
    }

}