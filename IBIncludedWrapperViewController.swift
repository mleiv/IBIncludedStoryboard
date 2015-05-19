//
//  IBIncludedWrapperViewController.swift
//
//  Copyright 2015 Emily Ivie

//  Licensed under The MIT License
//  For full copyright and license information, please see the LICENSE.txt
//  Redistributions of files must retain the above copyright notice.
//

import UIKit

public typealias PrepareAfterIBIncludedSegueType = (UIViewController) -> Void

/**
    Protocol to identify nested IBIncluded{Thing} view controllers that need to share data during prepareForSegue.
*/
@objc public protocol IBIncludedSegueableController {
    /**
        Run code before segueing away or prepare for segue to a non-IBIncluded{Thing} page.
        Do not use to share data (see prepareAfterIBIncludedSegue for that).
    */
    optional func prepareBeforeIBIncludedSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    
    /**
        Check the destination view controller type and share data if it is what you want.
    */
    optional var prepareAfterIBIncludedSegue: PrepareAfterIBIncludedSegueType { get }
}


/**
    Forwards any prepareForSegue behavior between nested IBIncluded{Thing} view controllers.
    Assign all IBIncluded{Thing} placeholder/wrapper view controllers to this class.
*/
public class IBIncludedWrapperViewController: UIViewController {

    internal var includedViewControllers = [IBIncludedSegueableController]()
    
    public typealias prepareAfterSegueType = (UIViewController) -> Void
    internal var prepareAfterSegueClosures:[PrepareAfterIBIncludedSegueType] = []

    /**
        Forward any segues to the saved included view controllers.
        (Also, save any of their prepareAfterIBIncludedSegue closures for the destination to process -after- IBIncluded{Thing} is included.)
        
        Can handle scenarios where one half of the segue in an IBIncluded{Thing} but the other half isn't.
    */
    override public func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // forward for pre-segue preparations:
        for includedController in includedViewControllers {
            includedController.prepareBeforeIBIncludedSegue?(segue, sender: sender)
        }
        // share post-segue closures for later execution:
        if let includedDestination = segue.destinationViewController as? IBIncludedWrapperViewController {
            // check self for any seguable closures (if we aren't IBIncluded{Thing} but are segueing to one):
            if let selfSegue = self as? IBIncludedSegueableController {
                if let closure = selfSegue.prepareAfterIBIncludedSegue {
                    includedDestination.prepareAfterSegueClosures.append(closure)
                }
            }
            // check all seguable closures now:
            for includedController in includedViewControllers {
                if let closure = includedController.prepareAfterIBIncludedSegue {
                    includedDestination.prepareAfterSegueClosures.append(closure)
                }
            }
        // execute now on top-level destination (if we are segueing from IBIncluded{Thing} to something that is not):
        } else if let destination = segue.destinationViewController as? UIViewController {
            // check self for any seguable closures (if we aren't IBIncluded{Thing} but are segueing to one):
            if let selfSegue = self as? IBIncludedSegueableController {
                if let closure = selfSegue.prepareAfterIBIncludedSegue {
                    closure(destination)
                }
            }
            // check all seguable closures now:
            for includedController in includedViewControllers {
                if let closure = includedController.prepareAfterIBIncludedSegue {
                    closure(destination)
                }
            }
        }
    }
    
    /**
        Save any included view controllers that may need segue handling later.
    */
    public func addIncludedViewController(viewController: UIViewController) {
        // only save segue-handling controllers
        if let includedController = viewController as? IBIncludedSegueableController {
            includedViewControllers.append(includedController)
        }
        // but we don't care what we run our saved prepareAfterIBIncludedSegue closures on:
        for closure in prepareAfterSegueClosures {
            closure(viewController)
        }
    }
}
