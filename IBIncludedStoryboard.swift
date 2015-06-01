//
//  IBIncludedStoryboard.swift
//
//  Copyright 2015 Emily Ivie

//  Licensed under The MIT License
//  For full copyright and license information, please see http://opensource.org/licenses/MIT
//  Redistributions of files must retain the above copyright notice.

import UIKit

/**
    For including storyboard pages in other storyboards, visible in Interface Builder.
    
    Note: Interface Builder does not recognize view controllers. So this has to be a UIView if we want it visible there. :(
*/
@IBDesignable
public class IBIncludedStoryboard: UIView {

    @IBInspectable var storyboard:String!
    @IBInspectable var id:String?
    
    private var initFromCoder:Bool = false
    private var finished = false
    private var attachedToParentViewController = false
    private var strongViewController: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initFromCoder = true
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        attachStoryboard()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        if initFromCoder {
            attachStoryboard()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        if initFromCoder && !attachedToParentViewController, let viewController = strongViewController, let parentViewController = findParentViewController(topViewController()) {
            // we *really* want view controller hierarchy, this is a last ditch attempt if awakeFromNib was too early
            attachViewControllerToParent(viewController, parent: parentViewController)
            strongViewController = nil
        }
    }
    
    
    /**
        Instantiates target storyboard's view controller using IBDesignable properties.
    
        Note : Keep this function visible externally for use by custom segues.
        
        :param: bundle      The current code bundle (which allows this to be more accurate when used in custom segues)
        :returns: an optional storyboard view controller
    */
    public func getViewController(bundle: NSBundle = NSBundle.mainBundle()) -> UIViewController? {
        var storyboardObj = UIStoryboard(name: storyboard, bundle: bundle)
        //first retrieve the controller
        if let viewController = (id != nil ? storyboardObj.instantiateViewControllerWithIdentifier(id!) : storyboardObj.instantiateInitialViewController()) as? UIViewController {
            return viewController
        }
        return nil
    }
    
    /**
        Loads up the storyboard for inclusion and adds its view to hierarchy. Adds its view controller to hierarchy also.
        Shares layout constraints between IBIncludedStoryboard view and included view.
    */
    private func attachStoryboard() {
        if storyboard == nil || finished {
            return
        }
        finished = true
        
        let bundle = NSBundle(forClass: self.dynamicType)
        if let viewController = getViewController(bundle: bundle) {
            strongViewController = viewController
            //hook up view controller to hierarchy so viewWillAppear() works right...
            if let parentViewController = findParentViewController(topViewController()){
                attachViewControllerToParent(viewController, parent: parentViewController)
            }
            var view = viewController.view
            self.addSubview(view)
            //tell storyboard page to resize to fit inside this page:
            view.setTranslatesAutoresizingMaskIntoConstraints(false)
            var bindings: [NSObject: AnyObject] = ["view": view]
            self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[view]|", options:NSLayoutFormatOptions(0), metrics:nil, views: bindings))
            self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options:NSLayoutFormatOptions(0), metrics:nil, views: bindings))
            self.opaque = false
            self.backgroundColor = UIColor.clearColor()
        }
        
    }
    
    /**
        Inserts the view controller into the current hierarchy so viewWillAppear() gets called, etc.
        
        :param: viewController      the view controller to insert
        :param: parent              the view controller to insert it under
    */
    private func attachViewControllerToParent(viewController: UIViewController, parent: UIViewController) {
        viewController.willMoveToParentViewController(parent)
        parent.addChildViewController(viewController)
        viewController.didMoveToParentViewController(parent)
        attachedToParentViewController = true
        transferControllerProperties(viewController, parent: parent)
        attachSegueForwarders(viewController, parent: parent)
    }
    
    /**
        Attaches the included view controller to any segue forwarding view controllers found in hierarchy
        
        :param: viewController      the view controller to insert
        :param: parent              the lowest view controller to try attaching to
    */
    private func attachSegueForwarders(viewController: UIViewController, parent: UIViewController) {
        var topController = parent as UIViewController?
        while topController != nil {
            if let placeholder = topController as? IBIncludedWrapperViewController {
                placeholder.addIncludedViewController(viewController)
                // this will run any waiting prepareForSegue functions now, and check our included controller for any prepareForSegue functions in the future.
                break
            }
            topController = topController?.parentViewController
        }
    }
    
    /**
        Locates the top-most view controller that is under the tab/nav controllers
    
        :param: topController   (optional) view controller to start looking under, defaults to window's rootViewController
        :returns: an (optional) view controller
    */
    private func topViewController(_ topController: UIViewController? = nil) -> UIViewController? {
        let controller: UIViewController? = {
            if let controller = topController ?? UIApplication.sharedApplication().keyWindow?.rootViewController {
                return controller
            } else if let window = UIApplication.sharedApplication().delegate?.window {
                //this is only called if window.makeKeyAndVisible() didn't happen...?
                return window?.rootViewController
            }
            return nil
        }()
        if let tabController = controller as? UITabBarController, let nextController = tabController.selectedViewController {
            return topViewController(nextController)
        } else if let navController = controller as? UINavigationController, let nextController = navController.visibleViewController {
            return topViewController(nextController)
        } else if let nextController = controller?.presentedViewController {
            return topViewController(nextController)
        }
        return controller
    }
    
    /**
        Recursively deep-dives into view controller hierarchy looking for the closest view controller containing this IBIncludedNib.
        
        :param: topController   Whatever view controller we are currently diving into.
        :returns: an (optional) view controller containing this IBIncludedNib
    */
    private func findParentViewController(topController: UIViewController!) -> UIViewController? {
        if topController == nil {
            return nil
        }
        for viewController in topController.childViewControllers {
            // first try, deep dive into child controllers
            if let parentViewController = findParentViewController(viewController as? UIViewController) {
                return parentViewController
            }
        }
        // second try, top view controller (most generic)
        if let topView = topController?.view where findSelfInViews(topView) {
            return topController
        }
        return nil
    }
    
    
    /**
        Recursively searches through a view and all its child views for this IBIncludedNib
        
        :param: topView   Whatever view we are currently searching into
        :returns: true if view contains this IBIncludedNib, false otherwise
    */
    private func findSelfInViews(topView: UIView) -> Bool {
        if topView == self || topView == self.superview {
            return true
        } else {
            for view in topView.subviews {
                if findSelfInViews(view as! UIView) {
                    return true
                }
            }
        }
        return false
    }
    
    /**
        Below function derived from https://github.com/rob-brown/RBStoryboardLink/ Copyright (c) 2012-2015 Robert Brown
        Shared under MIT License http://opensource.org/licenses/MIT
    */
    public func transferControllerProperties(viewController: UIViewController, parent: UIViewController) {
        parent.navigationItem.title = viewController.navigationItem.title
        parent.navigationItem.titleView = viewController.navigationItem.titleView
        parent.navigationItem.prompt = viewController.navigationItem.prompt
        parent.navigationItem.hidesBackButton = viewController.navigationItem.hidesBackButton
        parent.navigationItem.backBarButtonItem = viewController.navigationItem.backBarButtonItem
        parent.navigationItem.rightBarButtonItem = viewController.navigationItem.rightBarButtonItem
        parent.navigationItem.leftBarButtonItem = viewController.navigationItem.leftBarButtonItem
        parent.navigationItem.rightBarButtonItems = viewController.navigationItem.rightBarButtonItems
        parent.navigationItem.leftBarButtonItems = viewController.navigationItem.leftBarButtonItems
        parent.navigationItem.leftItemsSupplementBackButton = viewController.navigationItem.leftItemsSupplementBackButton
        
        if parent.tabBarController != nil {
            viewController.tabBarItem = parent.tabBarItem
        }
        
        let editButton = parent.editButtonItem()
        let otherEditButton = viewController.editButtonItem()
        editButton.enabled = otherEditButton.enabled
        editButton.image = otherEditButton.image
        editButton.landscapeImagePhone = otherEditButton.landscapeImagePhone
        editButton.imageInsets = otherEditButton.imageInsets
        editButton.landscapeImagePhoneInsets = otherEditButton.landscapeImagePhoneInsets
        editButton.title = otherEditButton.title
        editButton.tag = otherEditButton.tag
        editButton.target = otherEditButton.target
        editButton.action = otherEditButton.action
        editButton.style = otherEditButton.style
        editButton.possibleTitles = otherEditButton.possibleTitles
        editButton.width = otherEditButton.width
        editButton.customView = otherEditButton.customView
        editButton.tintColor = otherEditButton.tintColor
        
        parent.modalTransitionStyle = viewController.modalTransitionStyle
        parent.modalPresentationStyle = viewController.modalPresentationStyle
        parent.definesPresentationContext = viewController.definesPresentationContext
        parent.providesPresentationContextTransitionStyle = viewController.providesPresentationContextTransitionStyle

        parent.preferredContentSize = viewController.preferredContentSize
        parent.modalInPopover = viewController.modalInPopover

        parent.title = viewController.title
        parent.hidesBottomBarWhenPushed = viewController.hidesBottomBarWhenPushed
        parent.editing = viewController.editing

        parent.automaticallyAdjustsScrollViewInsets = viewController.automaticallyAdjustsScrollViewInsets
        parent.edgesForExtendedLayout = viewController.edgesForExtendedLayout
        parent.extendedLayoutIncludesOpaqueBars = viewController.extendedLayoutIncludesOpaqueBars
        parent.modalPresentationCapturesStatusBarAppearance = viewController.modalPresentationCapturesStatusBarAppearance
        parent.transitioningDelegate = viewController.transitioningDelegate
    }
    
    /**
        Logs messages (even in Interface Builder) to a file which can be read to debug IB.
        > open /tmp/XcodeLiveRendering.log
        
        :param: message     The text to write out
        :param: forClass    (Optional) A class name to tag messages with
    */
    private func ibLog(message: String, forClass xClass: AnyClass? = nil) {
        // command line following to view output from Interface Builder > open /tmp/XcodeLiveRendering.log
        #if TARGET_INTERFACE_BUILDER
            let logPath = "/tmp/XcodeLiveRendering.log"
            if !NSFileManager.defaultManager().fileExistsAtPath(logPath) {
                NSFileManager.defaultManager().createFileAtPath(logPath, contents: NSData(), attributes: nil)
            }
            var fileHandle = NSFileHandle(forWritingAtPath: logPath)
            fileHandle?.seekToEndOfFile()
            let date = NSDate()
            let bundle = xClass != nil ? NSBundle(forClass: xClass!) : NSBundle.mainBundle()
            let application: AnyObject? = bundle.objectForInfoDictionaryKey("CFBundleName")
            let data = "\(date) \(application) \(message)\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
            fileHandle?.writeData(data!)
        #endif
    }
}
    