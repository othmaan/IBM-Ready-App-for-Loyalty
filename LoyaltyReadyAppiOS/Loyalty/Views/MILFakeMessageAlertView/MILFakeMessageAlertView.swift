/*
Licensed Materials - Property of IBM
© Copyright IBM Corporation 2015. All Rights Reserved.
*/

import UIKit

/**
*  The view presented when an alert is triggered
*/
public class MILFakeMessageAlertView : UIView {
    
    //// Label of the alert
    @IBOutlet weak var alertLabel : UILabel!
    /// Reload button that may or may not be shown
    @IBOutlet weak var reloadButton: UIButton!
    
    var callback : (()->())!
    
    var isLoading = false

    /**
    Initializer for MILFakeMessageAlertView
    
    - returns: And instance of MILFakeMessageAlertView
    */
    class func instanceFromNib() -> MILFakeMessageAlertView {
        return UINib(nibName: "MILFakeMessageAlertView", bundle: nil).instantiateWithOwner(nil, options: nil)[0] as! MILFakeMessageAlertView
    }
    
    /**
    Sets the text on the MILFakeMessageAlertView's label
    
    - parameter text: The text to be displayed
    */
    func setLabel(text: String!) {
        if text != nil {
            self.alertLabel.text = text
        }
    }
    
    /**
    Sets the callback for the reload button
    
    - parameter callback: The callback function that is to be executed when the reload button is tapped
    */
    func setCallbackFunc(callback:(()->())!){
        if callback != nil {
            self.reloadButton.hidden = false
            self.callback = callback
            reloadButton.addTarget(self, action: "reloadButtonTapped", forControlEvents: UIControlEvents.TouchUpInside)
        }else{
            self.reloadButton.hidden = true
        }
    }
    
    /**
    The action for the reload button tap
    
    */
    @IBAction func reloadButtonTapped(){
        callback()
        MILFakeMessageAlertViewManager.sharedInstance.hide()
    }
}
