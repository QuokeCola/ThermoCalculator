//
//  InterTextField.swift
//  ThermoCalc
//
//  Created by 钱晨 on 2020/6/19.
//  Copyright © 2020年 钱晨. All rights reserved.
//

import UIKit

class InterView: UIView {
    var textView: UITextView!
    var label: UILabel!
    func setupKeyboard(Keyboard: UIView) {
        textView.inputView = Keyboard
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.subviews.forEach({$0.removeFromSuperview()})
        var Frame = frame
        Frame.origin = CGPoint(x: 0.0, y: 0.0)
        label = UILabel(frame: Frame)
        label.text = ","
        label.sizeToFit()
        label.frame.size.height = frame.height
        self.addSubview(label)
        Frame.size.width = 10.0
        Frame.origin.x = label.frame.width
        textView = UITextView(frame: Frame)
        textView.backgroundColor = UIColor.clear
        self.addSubview(textView)
        self.frame.size.width = label.frame.width + textView.frame.width
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func becomeFirstResponder() -> Bool {
        NotificationCenter.default.post(name: NSNotification.Name(NotificationKeyboardSwitchStateKey), object: self)
        self.textView.becomeFirstResponder()
        return false
    }
    func textViewSelected() {
        NotificationCenter.default.post(name: NSNotification.Name(NotificationKeyboardSwitchStateKey), object: self)
    }
}
