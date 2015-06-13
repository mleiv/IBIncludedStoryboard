//
//  IBIncludedThing.swift
//
//  Copyright 2015 Emily Ivie

//  Licensed under The MIT License
//  For full copyright and license information, please see http://opensource.org/licenses/MIT
//  Redistributions of files must retain the above copyright notice.


import UIKit

//MARK: IBIncludedSegueableWrapper protocol
/**
    Used by IBIncludedWrapperViewController, but since we don't know if that class was included, here's a short protocol to define it for use in IBIncludedThing.
*/
protocol IBIncludedSegueableWrapper {
    func addIncludedViewController(viewController: UIViewController)
}


//MARK: IBIncludedAbstractThing abstract parent class

/**
    For including stuff in other nibs/storyboards so they are visible/actionable in Interface Builder and also when app is run.
    
    Original nib version inspired by NibDesignable.swift by Morten Bøgh https://github.com/mbogh/NibDesignable
*/
@IBDesignable
public class IBIncludedAbstractThing: UIView {

    @IBInspectable var constrainHeight: Bool = true
    @IBInspectable var constrainWidth: Bool = true
    
    private var isInterfaceBuilder: Bool = {
        #if TARGET_INTERFACE_BUILDER
            return true
        #else
            return false
        #endif
    }()
    
    private var finished = false
    private var viewAttached = false
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
        // BTW - nested IBIncluded{Thing} do not use prepareForInterfaceBuilder()
        includeThing()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        includeThing()
    }
    
    override public func layoutSubviews() {
        if !attachedToParentViewController, let viewController = strongViewController where attachThing(viewController) {
            strongViewController = nil
        }
        super.layoutSubviews()
    }
    
    /**
        Instantiates target view controller using IBDesignable properties.
        - ABSTRACT -
        
        :param: bundle      The current code bundle (which allows this to be more accurate when used in custom segues)
        :returns: an optional storyboard view controller
    */
    public func getViewController(bundle: NSBundle = NSBundle.mainBundle()) -> UIViewController? {
        return nil
    }
    
    /**
        Setup function for initializing the view controller and attaching it and its view to hierarchy.
        Should probably override in child classes.
    */
    private func includeThing() {
        if finished { return }
        finished = true
        
        let bundle = NSBundle(forClass: self.dynamicType)
        if let viewController = getViewController(bundle: bundle) {
            //hook up view controller to hierarchy so viewWillAppear() works right...
            if !attachThing(viewController) {
                if isInterfaceBuilder {
                    attachView(viewController.view)
                    //if we don't do this now, nested IBIncluded{Thing} may never be loaded :/
                }
                strongViewController = viewController
            }
        } else {
            noViewControllerFound()
        }
    }
    
    /**
        What to do when there is no included thing view controller.
        - ABSTRACT -
    */
    private func noViewControllerFound() {}
    
    
    /**
        Attaches a viewcontroller to its parent if found and also attached the view.
        
        :param: viewController      The newly initialized included thing's controller
    */
    private func attachThing(viewController: UIViewController) -> Bool {
        if let parentViewController = findParentViewController(activeViewController(topViewController())) {
            // we *really* want view controller hierarchy, this is a last ditch attempt if awakeFromNib was too early
            attachSegueForwarders(viewController, parent: parentViewController)
            attachView(viewController.view)
            attachViewControllerToParent(viewController, parent: parentViewController)
            return true
        }
        return false
    }
    
    /**
        Adds view to hierarchy.
        Shares layout constraints between view and wrapper view.
    
        Derived from NibDesignable.swift by Morten Bøgh https://github.com/mbogh/NibDesignable
        
        :param: view      The newly initialized included thing's view
    */
    private func attachView(view: UIView!) {
        if view != nil && !viewAttached {
            self.addSubview(view)
            
            //change wrapper (self) height and width if we are doing that
            if !constrainHeight {
                let heightConstraint = NSLayoutConstraint(item: view, attribute: NSLayoutAttribute.Height, relatedBy: .Equal, toItem: self as UIView, attribute: NSLayoutAttribute.Height, multiplier: CGFloat(1.0), constant: CGFloat(0))
                self.addConstraint(heightConstraint)
            }
            if !constrainWidth {
                let widthConstraint = NSLayoutConstraint(item: view, attribute: NSLayoutAttribute.Width, relatedBy: .Equal, toItem: self as UIView, attribute: NSLayoutAttribute.Width, multiplier: CGFloat(1.0), constant: CGFloat(0))
                self.addConstraint(widthConstraint)
            }
            
            //tell child to fit itself to the edges of wrapper (self)
            view.setTranslatesAutoresizingMaskIntoConstraints(false)
            let bindings = ["view": view]
            self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[view]|", options:NSLayoutFormatOptions(0), metrics:nil, views: bindings))
            self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options:NSLayoutFormatOptions(0), metrics:nil, views: bindings))
            
            //clear out top-level view visibility, so only subview shows
            self.opaque = false
            self.backgroundColor = UIColor.clearColor()
            
            viewAttached = true
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
    }
    
    /**
        Attaches the included view controller to any segue forwarding view controllers found in hierarchy
        
        :param: viewController      the view controller to insert
        :param: parent              the lowest view controller to try attaching to
    */
    private func attachSegueForwarders(viewController: UIViewController, parent: UIViewController) {
        var topController = parent as UIViewController?
        while topController != nil {
            if let placeholder = topController as? IBIncludedSegueableWrapper {
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
        if let controller = window?.rootViewController {
            return controller
        } else if let controller = UIApplication.sharedApplication().keyWindow?.rootViewController {
            return controller
        } else if let delegate = UIApplication.sharedApplication().delegate, let controller = delegate.window??.rootViewController {
            return controller
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
        Recursively deep-dives into view controller hierarchy looking for the closest view controller containing self
        
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
        Recursively searches through a view and all its child views for self
        
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
        create a static method to get a swift class for a string name
        From http://stackoverflow.com/questions/24030814/swift-language-nsclassfromstring
        
        :param: className       The name of the class to be instantiated
        :param: bundle          (optional) bundle to look for class in
        :returns: an instantiated object of stated class, or nil
    */
    private func classFromString(className: String, bundle: NSBundle? = nil) -> (AnyClass!) {
        let useBundle = bundle ?? NSBundle.mainBundle()
        if let appName = useBundle.objectForInfoDictionaryKey("CFBundleName") as? String {
            let classStringName = "\(appName).\(className)"
            //? "_TtC\(appName!.utf16count)\(appName)\(countElements(className))\(className)"
            return NSClassFromString(classStringName)
        }
        return nil
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

//MARK: IBIncludedStoryboard implemented class

/**
    For including storyboard pages in other nibs/storyboards, visible in Interface Builder.
*/
public class IBIncludedStoryboard: IBIncludedAbstractThing {

    @IBInspectable var storyboard: String!
    @IBInspectable var id: String?
    @IBInspectable var treatAsNib: Bool = false
    
    /**
        Instantiates target storyboard's view controller using IBDesignable properties.
    
        Note : Keep this function visible externally for use by custom segues.
        
        :param: bundle      The current code bundle (which allows this to be more accurate when used in custom segues)
        :returns: an optional storyboard view controller
    */
    public override func getViewController(bundle: NSBundle = NSBundle.mainBundle()) -> UIViewController? {
        if storyboard == nil { return nil }
        var storyboardObj = UIStoryboard(name: storyboard, bundle: bundle)
        //first retrieve the controller
        if let viewController = (id != nil ? storyboardObj.instantiateViewControllerWithIdentifier(id!) : storyboardObj.instantiateInitialViewController()) as? UIViewController {
            return viewController
        }
        return nil
    }
    
    /**
        Inserts the view controller into the current hierarchy so viewWillAppear() gets called, etc.
        
        :param: viewController      the view controller to insert
        :param: parent              the view controller to insert it under
    */
    private override func attachViewControllerToParent(viewController: UIViewController, parent: UIViewController) {
        super.attachViewControllerToParent(viewController, parent: parent)
        transferControllerProperties(viewController, parent: parent)
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
}


//MARK: IBIncludedNib implemented class

/**
    For including nibs in other nibs/storyboards, visible in Interface Builder.
*/
public class IBIncludedNib: IBIncludedAbstractThing {

    @IBInspectable var nib:String!
    @IBInspectable var controller:String?
    @IBInspectable var treatAsNib: Bool = false
    
    /**
        Instantiates target nib's view controller using IBDesignable properties.
        
        :param: bundle      The current code bundle (which allows this to be more accurate when used in custom segues)
        :returns: an optional storyboard view controller
    */
    public override func getViewController(bundle: NSBundle = NSBundle.mainBundle()) -> UIViewController? {
        if nib == nil { return nil }
        let bundle = NSBundle(forClass: self.dynamicType)
        if controller != nil, let ControllerType = classFromString(controller!, bundle: bundle) as? UIViewController.Type {
            return ControllerType(nibName: nib, bundle: bundle) as UIViewController
        }
        return nil
    }
    
    /**
        What to do when there is no included thing view controller.
    */
    private override func noViewControllerFound() {
        let bundle = NSBundle(forClass: self.dynamicType)
        if nib != nil, let view = bundle.loadNibNamed(nib, owner: self, options: nil)?.first as? UIView {
            attachView(view)
        }
    }
}
    