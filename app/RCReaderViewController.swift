//
//  RCReaderViewController.swift
//  libjeid-ios-app
//
//  Copyright © 2020 Open Source Solution Technology Corporation
//  All rights reserved.
//

import CoreNFC
import UIKit
import libjeid

class RCReaderViewController: WrapperViewController, NFCTagReaderSessionDelegate {
    let MAX_NUMBER_LENGTH: Int = 12
    var rcReaderView: RCReaderView!
    var numberField: UITextField!
    var session: NFCTagReaderSession?
    private var number: String?

    override func loadView() {
        self.title = "Residence Card Reader"
        rcReaderView = RCReaderView()
        numberField = rcReaderView.numberField
        numberField.delegate = self
        rcReaderView.startButton.addTarget(self, action: #selector(pushStartButton), for: .touchUpInside)

        let wrapperView = WrapperView(rcReaderView)
        wrapperView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view = wrapperView
    }

    @objc func pushStartButton(sender: UIButton){
        self.number = self.numberField!.text
        if let activeField = self.activeField {
            activeField.resignFirstResponder()
        }
        if (!NFCReaderSession.readingAvailable) {
            self.openAlertView("Error", "Your device does not support NFC.")
            return
        }
        self.clearPublishedLog()
        if let _ = self.session {
            publishLog("Please wait a moment and try again")
        } else {
            self.session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: DispatchQueue.global())
            self.session?.alertMessage = "Please hold your device near the card"
            self.session?.begin()
            self.rcReaderView.startButton.alpha = Self.INACTIVE_ALPHA
        }
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let currentStr: NSString = textField.text! as NSString
        let newStr: NSString = currentStr.replacingCharacters(in: range, with: string) as NSString
        return newStr.length <= MAX_NUMBER_LENGTH
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("tagReaderSessionDidBecomeActive: \(Thread.current)")
    }

    func tagReaderSession(_ session: NFCTagReaderSession,
                          didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError {
            if nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                print("tagReaderSession error: " + nfcError.localizedDescription)
                self.publishLog("Error: " + nfcError.localizedDescription)
                if nfcError.code == .readerSessionInvalidationErrorSessionTerminatedUnexpectedly {
                    self.publishLog("Please wait a moment and try again")
                }
            }
        } else {
            print("tagReaderSession error: " + error.localizedDescription)
        }
        self.session = nil
        DispatchQueue.main.async {
            self.rcReaderView.startButton.alpha = Self.ACTIVE_ALPHA
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession,
                          didDetect tags: [NFCTag]) {
        let msgReadingHeader = "Reading\n"
        let msgErrorHeader = "Error\n"
        print("reader session thread: \(Thread.current)")
        let tag = tags.first!
        session.connect(to: tag) { (error: Error?) in
            print("connect thread: \(Thread.current)")
            if error != nil {
                print(error!)
                session.invalidate(errorMessage: "connect error")
                return
            }
            do {
                let reader = try JeidReader(tag)
                self.clearPublishedLog()
                session.alertMessage = "Starting to read..."
                let type = try reader.detectCardType()
                if (type != CardType.RC) {
                    self.publishLog("This is not a Residence Card or Special Permanent Resident Certificate.")
                    session.invalidate(errorMessage: "\(msgErrorHeader)This is not a Residence Card or Special Permanent Resident Certificate.")
                    return
                }
                self.publishLog("# Starting to read Residence Card")
                print("thread: \(Thread.current)")
                let ap = try reader.selectRC()
                session.alertMessage = "\(msgReadingHeader)Common data elements, card type..."
                // startAC(_:)実行前は認証の必要がない共通データ要素とカード種別のみが読み出されます
                let freeFiles = try ap.readFiles()
                session.alertMessage += "Success"
                let commonData = try freeFiles.getCommonData()
                self.publishLog("## Common Data Elements")
                self.publishLog(commonData.description)
                let cardType = try freeFiles.getCardType()
                self.publishLog("## Card Type")
                self.publishLog(cardType.description)
                
                if (self.number == nil || self.number!.isEmpty) {
                    self.publishLog("Please enter your residence card number or special permanent resident certificate number")
                    session.invalidate(errorMessage: "\(msgErrorHeader) The residence card number or equivalent number has not been entered")
                    return
                }
                do {
                    let rcKey = try RCKey(self.number!)
                    session.alertMessage = "\(msgReadingHeader)Starting SM & authentication..."
                    self.publishLog("## Starting Secure Messaging & Authentication")
                    try ap.startAC(rcKey)
                    self.publishLog("Success\n")
                    session.alertMessage += "Success"
                } catch let jeidError as JeidError {
                    switch jeidError {
                    case .invalidKey:
                        session.invalidate(errorMessage: "\(msgErrorHeader)Authentication failed")
                        self.publishLog("Failed\n")
                        self.handleInvalidKeyError(jeidError)
                        return
                    default:
                        throw jeidError
                    }
                }

                session.alertMessage = "\(msgReadingHeader)Reading files..."
                let files = try ap.readFiles()
                session.alertMessage += "Success"

                var dataDict = Dictionary<String, Any>()
                if let type = cardType.type {
                    dataDict["rc-card-type"] = type
                }
                let cardEntries = try files.getCardEntries()
                let entriesImage = try cardEntries.pngData()
                let src = "data:image/png;base64,\(entriesImage.base64EncodedString())"
                dataDict["rc-front-image"] = src
                let photo = try files.getPhoto()
                if let photoImage = photo.photoData {
                    let src = "data:image/jp2;base64,\(photoImage.base64EncodedString())"
                    dataDict["rc-photo"] = src
                }

                let address = try files.getAddress()
                self.publishLog("## Address (Back side entry)")
                self.publishLog(address.description)

                // カード種別が在留カードの場合
                if cardType.type == "1" {
                    let comprehensivePermission = try files.getComprehensivePermission()
                    self.publishLog("## Back side comprehensive permission for activities other than those permitted")
                    self.publishLog(comprehensivePermission.description)
                    let individualPermission = try files.getIndividualPermission()
                    self.publishLog("## Back side individual permission for activities other than those permitted")
                    self.publishLog(individualPermission.description)
                    let updateStatus = try files.getUpdateStatus()
                    self.publishLog("## Back side application for extension of period of stay")
                    self.publishLog(updateStatus.description)
                }
                let signature = try files.getSignature()
                self.publishLog("## Electronic Signature")
                self.publishLog(signature.description)

                // 真正性検証
                do {
                    let result = try files.validate()
                    dataDict["rc-valid"] = result.isValid
                    self.publishLog("Authenticity verification result: \(result)\n")
                } catch JeidError.unsupportedOperation {
                    // 無償版の場合、RCFiles#validate()でJeidError.unsupportedOperationが返ります
                    self.publishLog("The free version of the library does not support authenticity verification\n")
                } catch {
                    self.publishLog("\(error)")
                }

                session.alertMessage = "Reading completed"
                session.invalidate()
                self.openWebView(dataDict)
            } catch {
                session.invalidate(errorMessage: session.alertMessage + "Failed")
                self.publishLog("\(error)")
            }
        }
    }

    func openWebView(_ dict: Dictionary<String, Any>) {
        DispatchQueue.main.async {
            do {
                let jsonData: Data = try JSONSerialization.data(withJSONObject: dict, options: [])
                var jsonStr: String? = String(bytes: jsonData, encoding: .utf8)
                jsonStr = jsonStr?.replacingOccurrences(of: "\\\"", with: "\\\\\"")

                let path = Bundle.main.path(forResource: "rc", ofType: "html", inDirectory: "WebAssets/rc")!
                let localHtmlUrl = URL(fileURLWithPath: path, isDirectory: false)
                let webViewController = WebViewController(localHtmlUrl, "render(\'\(jsonStr!)\');")
                webViewController.title = "Residence Card Viewer"
                self.navigationController?.pushViewController(webViewController, animated: true)
            } catch (let error) {
                self.publishLog("\(error)")
                self.openAlertView("Error", "Failed to display reading results")
            }
        }
    }

    func handleInvalidKeyError(_ jeidError: JeidError) {
        let title = "Incorrect number"
        let message = "Please enter the correct residence card number or special permanent resident certificate number"
        openAlertView(title, message)
    }
}
