//
//  MainView.swift
//  libjeid-ios-app
//
//  Copyright © 2019 Open Source Solution Technology Corporation
//  All rights reserved.
//

import UIKit

class MainView: UIView {
    let inButton: UIButton
    let dlButton: UIButton
    let epButton: UIButton
    let rcButton: UIButton
    let pinButton: UIButton

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        inButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        inButton.setTitle("My Number Card", for: .normal)

        dlButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        dlButton.setTitle("Driver's License", for: .normal)

        epButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        epButton.setTitle("Passport", for: .normal)
        epButton.isHidden = true

        rcButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        rcButton.setTitle("Residence Card", for: .normal)

        pinButton = CustomViewUtil.createButton(UIScreen.main.bounds.size)
        pinButton.setTitle("PIN Code Status", for: .normal)

        let stackView = CustomViewUtil.createVerticalStackView(UIScreen.main.bounds.size)
        stackView.addArrangedSubview(inButton)
        stackView.addArrangedSubview(dlButton)
        stackView.addArrangedSubview(epButton)
        stackView.addArrangedSubview(rcButton)
        stackView.addArrangedSubview(pinButton)

        super.init(frame: .zero)
        self.addSubview(stackView)
        stackView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
    }
}
