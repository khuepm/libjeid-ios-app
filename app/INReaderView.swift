//
//  INReaderView.swift
//  libjeid-ios-app
//
//  Copyright © 2019 Open Source Solution Technology Corporation
//  All rights reserved.
//

import UIKit

class INReaderView: UIView {
    let pinField: UITextField
    let startButton: UIButton

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        let explanation = CustomViewUtil.createTextView(UIScreen.main.bounds.size)
        explanation.text = "The information on the My Number card will be displayed.\n"
                    + "After pressing the Start Reading button, hold the device up to the card."

        let pinLabel = CustomViewUtil.createTextView(UIScreen.main.bounds.size)
        pinLabel.text = "PIN (4 digits, required)"

        pinField = CustomViewUtil.createTextField(UIScreen.main.bounds.size)
        pinField.isSecureTextEntry = true
        pinField.keyboardType = UIKeyboardType.numberPad

        let pinStackView = CustomViewUtil.createNarrowVerticalStackView(UIScreen.main.bounds.size)
        pinStackView.addArrangedSubview(pinLabel)
        pinStackView.addArrangedSubview(pinField)

        startButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        startButton.setTitle("Start Reading", for: .normal)

        let stackView = CustomViewUtil.createVerticalStackView(UIScreen.main.bounds.size)
        stackView.addArrangedSubview(explanation)
        stackView.addArrangedSubview(pinStackView)
        stackView.addArrangedSubview(startButton)

        super.init(frame: .zero)
        self.addSubview(stackView)

        stackView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (previousTraitCollection!.hasDifferentColorAppearance(comparedTo: traitCollection)) {
            pinField.layer.borderColor = CustomColor.textFieldBorder.cgColor
        }
    }
}
