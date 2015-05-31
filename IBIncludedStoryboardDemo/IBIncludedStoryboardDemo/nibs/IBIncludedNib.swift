//
//  IBIncludedNib.swift
//
//  Copyright 2015 Emily Ivie

//  Licensed under The MIT License
//  For full copyright and license information, please see the LICENSE.txt
//  Redistributions of files must retain the above copyright notice.

import UIKit

/**
    For including nibs in other nibs/storyboards. 
    This works for running in application too - don't have to load nibs in code anymore, 
        unless you are bringing one up dynamically on an action or something.
*/
@IBDesignable
public class IBIncludedNib: UIView{

    @IBInspectable var nib:String!
    @IBInspectable var controller:String?
    
    private var initFromCoder:Bool = false
    private var finished = false
    private var attachedToParentViewController = false
    private var strongViewController: UIViewController?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initFromCoder = true
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        attachNib()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        if initFromCoder {
            attachNib()
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
        Loads up the nib file for inclusion and adds its view to hierarchy. Ties it to a view controller if one is specified and adds that to hierarchy also.
        Shares layout constraints between IBIncludedNib view and nib's view.
    
        Derived from NibDesignable.swift by Morten Bøgh https://github.com/mbogh/NibDesignable
    */
    private func attachNib() {
        if nib == nil || finished {
            return
        }
        finished = true
        //ibLog("IBIncludedNib: Nib name = \"\(nib)\"")
        
        let bundle = NSBundle(forClass: self.dynamicType)
        var view:UIView!
        
        //first retrieve the view from its controller or its nib
        if controller != nil {
            if let ControllerType = classFromString(controller!, bundle: bundle) as? UIViewController.Type {
                //This is the better way to instantiate:
                //> let viewController = ControllerType(nibName: nib, bundle: bundle) as UIViewController
                //But I do it this way instead so I can force the segue code to run before viewDidLoad
                // (which we now call explicitly in attachViewControllerToParent() :/ )
                let viewController = ControllerType() as UIViewController
                UINib(nibName: nib, bundle: bundle).instantiateWithOwner(viewController, options: nil)
                view = viewController.view
                viewController.awakeFromNib()
                //hook up view controller to hierarchy so viewWillAppear() works right...
                if let parentViewController = findParentViewController(topViewController()){
                    attachViewControllerToParent(viewController, parent: parentViewController)
                    viewController.view = view
                } else {
                    strongViewController = viewController //hold strong ref ourselves
                }
            }
        } else {
            if let nibThing = bundle.loadNibNamed(nib, owner: self, options: nil) {
                if let nibView = nibThing.first as? UIView {
                    view = nibView
                }
            }
        }
        
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
        attachSegueForwarders(viewController, parent: parent)
        viewController.viewDidLoad()
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
        //println("top ? \(controller?.dynamicType) \(controller?.title)")
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
            //println("parent \(topController?.title) \(topController?.dynamicType)")
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
        if topView == self {
            return true
        } else {
            for childView in topView.subviews {
                if let view = childView as? UIView where findSelfInViews(view) {
                    return true
                }
            }
        }
        return false
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