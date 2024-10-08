//
//  RCReaderView.swift
//  libjeid-ios-app
//
//  Copyright © 2020 Open Source Solution Technology Corporation
//  All rights reserved.
//

import UIKit

class RCReaderView: UIView {
    let numberField: UITextField
    let startButton: UIButton

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        let explanation = CustomViewUtil.createTextView(UIScreen.main.bounds.size)
        explanation.text = "After pressing the Start Reading button, hold the device up to the card.\n"
                    + "It supports residence cards and special permanent resident certificates."

        let numberLabel = CustomViewUtil.createTextView(UIScreen.main.bounds.size)
        numberLabel.text = "Residence card or equivalent number"

        numberField = CustomViewUtil.createTextField(UIScreen.main.bounds.size)
        numberField.keyboardType = UIKeyboardType.asciiCapable
        numberField.autocapitalizationType = .allCharacters

        let pin1StackView = CustomViewUtil.createNarrowVerticalStackView(UIScreen.main.bounds.size)
        pin1StackView.addArrangedSubview(numberLabel)
        pin1StackView.addArrangedSubview(numberField)

        startButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        startButton.setTitle("Start Reading", for: .normal)

        let stackView = CustomViewUtil.createVerticalStackView(UIScreen.main.bounds.size)
        stackView.addArrangedSubview(explanation)
        stackView.addArrangedSubview(pin1StackView)
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
            numberField.layer.borderColor = CustomColor.textFieldBorder.cgColor
        }
    }
}
