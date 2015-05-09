# IBIncludedStoryboard

**This iOS Swift class allows you to easily embed storyboard scenes into other storyboards with minimal extra code.**

Storyboards can easily get too large and they are slow and difficut to collaborate on without conflicts. IBIncludedStoryboard allows developers to break up their application into sensible chunks and link the storyboards visually.

To use, simply add the IBIncludedStoryboard.swift file to your project. 

Then, create a second storyboard file. If you set the Storyboard ID properties for your second storyboard scenes, you will have the option in the main storyboard to jump to any scene you want, otherwise it will default to the root/initial scene. 

![New Storyboard](/IBIncludedStoryboard/IBIncludedStoryboardDemo/Images.xcassets/1-SecondStoryboard.imageset/1-SecondStoryboard.png?raw=true)

In your main storyboard, create a placeholder view controller where you want to include this new storyboard.

![Linking To New Storyboard](/IBIncludedStoryboard/IBIncludedStoryboardDemo/Images.xcassets/2-MainStoryboardToSecond.imageset/2-MainStoryboardToSecond.png?raw=true)

1. Select the placeholder's root view.
2. Change the root view's class name to IBIncludedStoryboard.
3. Identify the storyboard in the IBIncludedStoryboard user-defined runtime attributes **Storyboard** and (optionally) *Id* (they will appear under the Attributes Inspector tab, one to the right of the Identity Inspector shown in the screenshot).
4. The chosen scene from your new storyboard should appear in the Interface Builder window.

That's it! You now have linked storyboards.

## Using With IBIncludedNib

I have another Swift class called [IBIncludedNib](https://github.com/mleiv/IBIncludedNib), which does the same thing as IBIncludedStoryboard, but with nibs. This allows for further encapsulation of layouts. In my applications, I use nibs for all the scenes, gather them in small groups of storyboards with IBIncludedNib, and link the storyboards with IBIncludedStoryboard.

**Quick Rundown**

![Including Nib](/IBIncludedStoryboard/IBIncludedStoryboardDemo/Images.xcassets/3-IncludingNib.imageset/3-IncludingNib.png?raw=true)

1. Create the nib file and (optionally) its controller.
2. In the storyboard, create a placeholder view controller and set one of its views to be IBIncludedNib (note: it does not have to be the root view: I sometimes like to use the placeholder to wrap the nib in a UIScrollView rather than mess with that at nib-level design).
3. Identify the nib and (optionally) its controller in the Attributes Inspector tab.
4. Your nib should appear in the Interface Builder Window.

## The Catch - Segues

Because IBIncludedStoryboard and IBIncludedNib are *child* view controllers of the main storyboard, calling segues from a child to a parent can get tricky. For IBIncludedNib in particular, I have just got into the habit of invoking all segues from IBAction functions.

![Seguing In Code Step 1](/IBIncludedStoryboard/IBIncludedStoryboardDemo/Images.xcassets/5-NibSegueDetail.imageset/5-NibSegueDetail.png?raw=true)

1. Create the segue from the storyboard scene's parent controller to the new scene and give it a unique identifier.

![Seguing In Code Step 2](/IBIncludedStoryboard/IBIncludedStoryboardDemo/Images.xcassets/6-NibSegueCode.imageset/6-NibSegueCode.png?raw=true)

2. Wire up an element in the child controller to code that directly invokes the segue. Example: 

```swift
@IBAction func clickedButton(sender: UIButton) {
    parentViewController?.performSegueWithIdentifier("SEGUE NAME", sender: sender)
}
```
