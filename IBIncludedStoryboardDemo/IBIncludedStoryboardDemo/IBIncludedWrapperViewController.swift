//
//  IBIncludedWrapperViewController.swift
//
//  Copyright 2015 Emily Ivie

//  Licensed under The MIT License
//  For full copyright and license information, please see http://opensource.org/licenses/MIT
//  Redistributions of files must retain the above copyright notice.
//

import UIKit


//MARK: IBIncludedSegueableController protocol

public typealias PrepareAfterIBIncludedSegueType = (UIViewController) -> Bool

/**
    Protocol to identify nested IBIncluded{Thing} view controllers that need to share data during prepareForSegue.
    Note: This is not a default protocol applied to all IBIncluded{Thing} - you have to apply it individually to nibs/storyboards that are sharing data.
*/
@objc public protocol IBIncludedSegueableController {
    
    /// Run code before segueing away or prepare for segue to a non-IBIncluded{Thing} page.
    /// Do not use to share data (see prepareAfterIBIncludedSegue for that).
    /// - parameter segue: The segue object containing information about the view controllers involved in the segue. See [prepareForSegue documentation](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIViewController_Class/#//apple_ref/occ/instm/UIViewController/prepareForSegue:sender:)
    /// - parameter sender: The object that initiated the segue. You might use this parameter to perform different actions based on which control (or other object) initiated the segue. See [prepareForSegue documentation](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIViewController_Class/#//apple_ref/occ/instm/UIViewController/prepareForSegue:sender:)
    /// - returns: `true` if function has finished its work and can be deleted, `false` if it did not find the controller it is looking for yet.

    optional func prepareBeforeIBIncludedSegue(segue: UIStoryboardSegue, sender: AnyObject?) -> Bool
    
    /// Check the destination view controller type and share data if it is what you want.
    optional var prepareAfterIBIncludedSegue: PrepareAfterIBIncludedSegueType { get set }
}


//MARK: IBIncludedWrapperViewController definition

/**
    Forwards any prepareForSegue behavior between nested IBIncluded{Thing} view controllers.
    Runs for all nested IBIncludedWrapperViewControllers, so you can have some pretty intricately-nested levels of stroyboards/nibs and they can still share data, so long as a segue is involved.

    Assign this class to all IBIncluded{Thing} placeholder/wrapper view controllers involved at any level in sharing data between controllers.
*/
public class IBIncludedWrapperViewController: UIViewController, IBIncludedSegueableWrapper {

    internal var includedViewControllers = [IBIncludedSegueableController]()
    
    internal var prepareAfterSegueClosures:[PrepareAfterIBIncludedSegueType] = []

    /**
        Forward any segues to the saved included view controllers.
        (Also, save any of their prepareAfterIBIncludedSegue closures for the destination to process -after- IBIncluded{Thing} is included.)
        
        Can handle scenarios where one half of the segue in an IBIncluded{Thing} but the other half isn't.
    */
    override public func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        //super.prepareForSegue(segue, sender: sender) //doesn't help propogate up the segue
        
        forwardToParentControllers(segue, sender: sender)
    
        // forward for pre-segue preparations:
        for includedController in includedViewControllers {
            includedController.prepareBeforeIBIncludedSegue?(segue, sender: sender)
        }
        
        // save/share post-segue closures for later execution:
        // skip any navigation/tab controllers
        if let destinationController = activeViewController(segue.destinationViewController) {
            tryToApplyClosures(destinationController)
        }
        
        prepareAfterSegueClosures = [] // we are done, clean up any lingering controllers in case we have ARC issues
        // NOTE: you may not want this if you are doing very delayed prepareAfterSegue stuff (like, delayed until after a segue to another page and coming back), but I have seen no ill effects myself.
    }
    
    public func tryToApplyClosures(destinationController: UIViewController?) {
        if let includedDestination = destinationController as? IBIncludedWrapperViewController {
            // check self for any seguable closures (if we aren't IBIncluded{Thing} but are segueing to one):
            if let selfSegue = self as? IBIncludedSegueableController, let closure = selfSegue.prepareAfterIBIncludedSegue {
                includedDestination.prepareAfterSegueClosures.append(closure)
            }
            // check all seguable closures now:
            for includedController in includedViewControllers {
                if let closure = includedController.prepareAfterIBIncludedSegue {
                    includedDestination.prepareAfterSegueClosures.append(closure)
                }
            }
            if includedDestination is IBIncludedSegueableController {
                // it's a seguable controller also, so run all seguable closures now:
                for includedController in includedViewControllers {
                    if let closure = includedController.prepareAfterIBIncludedSegue {
                        closure(destinationController!) //nil already tested above
                    }
                }
            }
        // execute now on top-level destination (if we are segueing from IBIncluded{Thing} to something that is not):
        } else if destinationController != nil {
            // check self for any seguable closures (if we aren't IBIncluded{Thing} but are segueing to one):
            if let selfSegue = self as? IBIncludedSegueableController {
                if let closure = selfSegue.prepareAfterIBIncludedSegue {
                    closure(destinationController!)
                }
            }
            // check all seguable closures now:
            for includedController in includedViewControllers {
                if let closure = includedController.prepareAfterIBIncludedSegue {
                    closure(destinationController!)
                }
            }
        }
    }
    
    /**
        Save any included view controllers that may need segue handling later.
    */
    public func addIncludedViewController(viewController: UIViewController) {
        // skip any navigation/tab controllers
        if let newController = activeViewController(viewController) where newController != viewController {
            return addIncludedViewController(newController)
        }
        // only save segue-handling controllers
        if let includedController = viewController as? IBIncludedSegueableController {
            includedViewControllers.append(includedController)
        }
        // try running saved segue closures, delete any that are marked finished
        prepareAfterSegueClosures = prepareAfterSegueClosures.filter { closure in
            let finished = closure(viewController)
            return !finished
        }
    }
    
    public func addClosure(newClosure: PrepareAfterIBIncludedSegueType) {
        prepareAfterSegueClosures.append(newClosure)
    }
    
    public func resetClosures() {
        prepareAfterSegueClosures = []
    }
    
    /**
        Propogates the segue up to parent IBIncludedWrapperViewControllers so they can also run the prepareAfterIBIncludedSegue() on their included things. 
        
        Since any IBIncluded{Thing} attaches to all IBIncludedWrapperViewControllers in the hierarchy, I am not sure why this is required, but I know the prior version didn't work in some heavily-nested scenarios without this addition.
    
        :param: controller   (optional) view controller to start looking under, defaults to window's rootViewController
        :returns: an (optional) view controller
    */
    private func forwardToParentControllers(segue: UIStoryboardSegue, sender: AnyObject?) {
        var currentController = self as UIViewController
        while let controller = currentController.parentViewController {
            if let wrapperController = controller as? IBIncludedWrapperViewController {
                wrapperController.prepareForSegue(segue, sender: sender)
                break //wrapperController will do further parents
            }
            currentController = controller
        }
    }
    
    /**
        Locates the top-most view controller that is under the tab/nav controllers
    
        :param: controller   (optional) view controller to start looking under, defaults to window's rootViewController
        :returns: an (optional) view controller
    */
    private func activeViewController(controller: UIViewController!) -> UIViewController? {
        if controller == nil {
            return nil
        }
        if let tabController = controller as? UITabBarController, let nextController = tabController.selectedViewController {
            return activeViewController(nextController)
        } else if let navController = controller as? UINavigationController, let nextController = navController.visibleViewController {
            return activeViewController(nextController)
        } else if let nextController = controller.presentedViewController {
            return activeViewController(nextController)
        }
        return controller
    }
}
