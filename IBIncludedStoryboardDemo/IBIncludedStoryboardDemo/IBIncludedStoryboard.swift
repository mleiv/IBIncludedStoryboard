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

    @IBInspectable var storyboard: String!
    @IBInspectable var id: String?
    @IBInspectable var treatAsNib: Bool = false
    
    private var finished = false
    private var isInterfaceBuilder = false
    private var attachedToParentViewController = false
    private var strongViewController: UIViewController?

//    override init(frame: CGRect) {
//        super.init(frame: frame)
//    }
//
//    required public init(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        isInterfaceBuilder = true
        attachStoryboard()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        attachStoryboard()
    }
    
    override public func layoutSubviews() {
        if !attachedToParentViewController, let viewController = strongViewController {
            if let parentViewController = findParentViewController(activeViewController(topViewController())) {
                // we *really* want view controller hierarchy, this is a last ditch attempt if awakeFromNib was too early
                attachSegueForwarders(viewController, parent: parentViewController)
                attachView(viewController: viewController)
                attachViewControllerToParent(viewController, parent: parentViewController)
                strongViewController = nil
            } else if isInterfaceBuilder {
                attachView(viewController: viewController)
                strongViewController = nil
            }
        }
        super.layoutSubviews()
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
            //hook up view controller to hierarchy so viewWillAppear() works right...
            if let parentViewController = findParentViewController(activeViewController(topViewController())) {
                attachSegueForwarders(viewController, parent: parentViewController)
                attachView(viewController: viewController)
                attachViewControllerToParent(viewController, parent: parentViewController)
            } else {
                strongViewController = viewController
            }
        }
    }
    
    /**
        Initializes nib and adds its view to hierarchy. Ties it to a view controller if one was specified.
        Shares layout constraints between IBIncludedNib view and nib's view.
    
        Derived from NibDesignable.swift by Morten Bøgh https://github.com/mbogh/NibDesignable
    */
    private func attachView(#viewController: UIViewController?) {
        
        var view = viewController?.view as UIView!
        
        //then, add the view to the view hierarchy
        if view != nil {
            self.addSubview(view)
            //tell nib to resize to fit inside this view:
            view.setTranslatesAutoresizingMaskIntoConstraints(false)
            let bindings = ["view": view]
            self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[view]|", options:NSLayoutFormatOptions(0), metrics:nil, views: bindings))
            self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options:NSLayoutFormatOptions(0), metrics:nil, views: bindings))
            //clear out top-level view visibility, so only subview shows
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
            }
            topController = topController?.parentViewController
        }
    }
    
    /**
        Locates the top-most view controller
    
        :returns: an (optional) view controller
    */
    private func topViewController() -> UIViewController? {
        if let controller = UIApplication.sharedApplication().keyWindow?.rootViewController {
            return controller
        } else if let window = UIApplication.sharedApplication().delegate?.window {
            //this is only called if window.makeKeyAndVisible() didn't happen...?
            return window?.rootViewController
        }
        return nil
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
        if treatAsNib {
            return
        }
        // skip the navigation controller/etc. :
        let includedController = activeViewController(viewController) ?? viewController
        
        parent.navigationItem.title = includedController.navigationItem.title
        parent.navigationItem.titleView = includedController.navigationItem.titleView
        parent.navigationItem.prompt = includedController.navigationItem.prompt
        parent.navigationItem.hidesBackButton = includedController.navigationItem.hidesBackButton
        parent.navigationItem.backBarButtonItem = includedController.navigationItem.backBarButtonItem
        parent.navigationItem.rightBarButtonItem = includedController.navigationItem.rightBarButtonItem
        parent.navigationItem.leftBarButtonItem = includedController.navigationItem.leftBarButtonItem
        parent.navigationItem.rightBarButtonItems = includedController.navigationItem.rightBarButtonItems
        parent.navigationItem.leftBarButtonItems = includedController.navigationItem.leftBarButtonItems
        parent.navigationItem.leftItemsSupplementBackButton = includedController.navigationItem.leftItemsSupplementBackButton
        
        if parent.tabBarController != nil {
            includedController.tabBarItem = parent.tabBarItem
        }
        
        let editButton = parent.editButtonItem()
        let otherEditButton = includedController.editButtonItem()
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

        parent.modalTransitionStyle = includedController.modalTransitionStyle
        parent.modalPresentationStyle = includedController.modalPresentationStyle
        parent.definesPresentationContext = includedController.definesPresentationContext
        parent.providesPresentationContextTransitionStyle = includedController.providesPresentationContextTransitionStyle

        parent.preferredContentSize = includedController.preferredContentSize
        parent.modalInPopover = includedController.modalInPopover

        if includedController.title != nil { // this messes with tab bar names
            parent.title = includedController.title
        }
        parent.hidesBottomBarWhenPushed = includedController.hidesBottomBarWhenPushed
        parent.editing = includedController.editing

        parent.automaticallyAdjustsScrollViewInsets = includedController.automaticallyAdjustsScrollViewInsets
        parent.edgesForExtendedLayout = includedController.edgesForExtendedLayout
        parent.extendedLayoutIncludesOpaqueBars = includedController.extendedLayoutIncludesOpaqueBars
        parent.modalPresentationCapturesStatusBarAppearance = includedController.modalPresentationCapturesStatusBarAppearance
        parent.transitioningDelegate = includedController.transitioningDelegate
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
    