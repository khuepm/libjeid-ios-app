//
//  INReaderViewController.swift
//  libjeid-ios-app
//
//  Copyright © 2019 Open Source Solution Technology Corporation
//  All rights reserved.
//

import CoreNFC
import UIKit
import libjeid

class INReaderViewController: WrapperViewController, NFCTagReaderSessionDelegate {
    let MAX_PIN_LENGTH: Int = 4
    var inReaderView: INReaderView!
    var pinField: UITextField!
    var session: NFCTagReaderSession?
    private var pin: String?

    override func loadView() {
        self.title = "My Number Card Reader" // Translated from "マイナンバーカードリーダー"
        inReaderView = INReaderView()
        pinField = inReaderView.pinField
        pinField.delegate = self
        inReaderView.startButton.addTarget(self, action: #selector(pushStartButton), for: .touchUpInside)

        let wrapperView = WrapperView(inReaderView)
        wrapperView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view = wrapperView
    }

    @objc func pushStartButton(sender: UIButton){
        self.pin = self.pinField!.text
        if let activeField = self.activeField {
            activeField.resignFirstResponder()
        }
        if (!NFCReaderSession.readingAvailable) {
            self.openAlertView("Error", "Your device does not support NFC.") // Translated from "エラー", "お使いの端末はNFCに対応していません。"
            return
        }
        self.clearPublishedLog()
        if let _ = self.session {
            publishLog("Please wait a moment and try again") // Translated from "しばらく待ってから再度お試しください"
        } else {
            self.session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: DispatchQueue.global())
            self.session?.alertMessage = "Please hold your device near the card" // Translated from "カードに端末をかざしてください"
            self.session?.begin()
            self.inReaderView.startButton.alpha = Self.INACTIVE_ALPHA
        }
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let currentStr: NSString = textField.text! as NSString
        let newStr: NSString = currentStr.replacingCharacters(in: range, with: string) as NSString
        return newStr.length <= MAX_PIN_LENGTH
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
                    self.publishLog("Please wait a moment and try again") // Translated from "しばらく待ってから再度お試しください"
                }
            }
        } else {
            print("tagReaderSession error: " + error.localizedDescription)
        }
        self.session = nil
        DispatchQueue.main.async {
            self.inReaderView.startButton.alpha = Self.ACTIVE_ALPHA
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession,
                          didDetect tags: [NFCTag]) {
        let msgReadingHeader = "Reading\n" // Translated from "読み取り中\n"
        let msgErrorHeader = "Error\n" // Translated from "エラー\n"
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
                if (self.pin == nil || self.pin!.isEmpty || self.pin!.count != 4) {
                    self.publishLog("Please enter a 4-digit PIN") // Translated from "4桁の暗証番号を入力してください"
                    session.invalidate(errorMessage: "\(msgErrorHeader)PIN has not been entered") // Translated from "暗証番号が入力されていません"
                    return
                }
                let reader = try JeidReader(tag)
                self.clearPublishedLog()
                session.alertMessage = "Reading..."
                let cardType = try reader.detectCardType()
                if (cardType != CardType.IN) {
                    self.publishLog("This is not a My Number Card") // Translated from "マイナンバーカードではありません"
                    session.invalidate(errorMessage: "\(msgErrorHeader)This is not a My Number Card") // Translated from "マイナンバーカードではありません"
                    return
                }
                self.publishLog("# Starting My Number Card reading") // Translated from "# マイナンバーカードの読み取り開始"
                print("thread: \(Thread.current)")
                self.publishLog("## Retrieving information from the text input assistance AP") // Translated from "## 券面入力補助APから情報を取得します"
                let textAp = try reader.selectINText()
                do {
                    session.alertMessage = "\(msgReadingHeader)Authenticating with PIN..." // Translated from "暗証番号による認証..."
                    self.publishLog("### Authenticating with PIN") // Translated from "### 暗証番号による認証"
                    try textAp.verifyPin(self.pin!)
                    self.publishLog("Success\n")
                    session.alertMessage += "Success"
                } catch let jeidError as JeidError {
                    switch jeidError {
                    case .invalidPin:
                        session.invalidate(errorMessage: "\(msgErrorHeader)Authentication failed") // Translated from "認証失敗"
                        self.publishLog("Failed\n")
                        self.handleInvalidPinError(jeidError)
                        return
                    default:
                        throw jeidError
                    }
                }

                session.alertMessage = "\(msgReadingHeader)Retrieving information from the text input assistance AP..."
                let textFiles = try textAp.readFiles()
                session.alertMessage += "Success"

                var dataDict = Dictionary<String, Any>()
                self.publishLog("### Personal Number")
                do {
                    let textMyNumber = try textFiles.getMyNumber()
                    self.publishLog(textMyNumber.description)
                    if let myNumber = textMyNumber.myNumber {
                        dataDict["cardinfo-mynumber"] = myNumber
                    }
                } catch JeidError.unsupportedOperation {
                    // 無償版の場合、INTextFiles#getMyNumber()でJeidError.unsupportedOperationが返ります
                    self.publishLog("Free version library does not support retrieving personal number\n")
                }

                let textAttrs = try textFiles.getAttributes()
                self.publishLog("### 4 Information")
                self.publishLog(textAttrs.description)
                if let name = textAttrs.name {
                    dataDict["cardinfo-name"] = name
                }
                if let birthDate = textAttrs.birthDate {
                    dataDict["cardinfo-birth"] = birthDate
                }
                if let sexString = textAttrs.sexString {
                    dataDict["cardinfo-sex"] = sexString
                }
                if let address = textAttrs.address {
                    dataDict["cardinfo-addr"] = address
                }

                self.publishLog("### Validating the text input assistance AP")
                do {
                    let textApValidationResult = try textFiles.validate()
                    self.publishLog(textApValidationResult.description + "\n")
                    dataDict["textap-validation-result"] = textApValidationResult.isValid
                } catch JeidError.unsupportedOperation {
                    // 無償版の場合、INTextFiles#validate()でJeidError.unsupportedOperationが返ります
                    self.publishLog("Free version library does not support validation\n")
                }

                self.publishLog("## Retrieving information from the visual AP")
                let visualAp = try reader.selectINVisual()
                session.alertMessage = "\(msgReadingHeader)Authenticating with PIN..."
                self.publishLog("### Authenticating with PIN")
                try visualAp.verifyPin(self.pin!)
                self.publishLog("Success\n")
                session.alertMessage += "Success"
                session.alertMessage = "\(msgReadingHeader)Retrieving information from the visual AP..."
                let visualFiles = try visualAp.readFiles()
                session.alertMessage += "Success"
                let visualEntries = try visualFiles.getEntries()
                self.publishLog("### Card Entries")
                self.publishLog(visualEntries.description)
                if let expireDate = visualEntries.expireDate {
                    dataDict["cardinfo-expire"] = expireDate
                }
                if let birthDate = visualEntries.birthDate {
                    dataDict["cardinfo-birth2"] = birthDate
                }
                if let sexString = visualEntries.sexString {
                    dataDict["cardinfo-sex2"] = sexString
                }
                if let nameImage = visualEntries.name {
                    let src = "data:image/png;base64,\(nameImage.base64EncodedString())"
                    dataDict["cardinfo-name-image"] = src
                }
                if let addressImage = visualEntries.address {
                    let src = "data:image/png;base64,\(addressImage.base64EncodedString())"
                    dataDict["cardinfo-address-image"] = src
                }
                if let photoData = visualEntries.photoData {
                    let src = "data:image/jp2;base64,\(photoData.base64EncodedString())"
                    dataDict["cardinfo-photo"] = src
                }

                do {
                    let visualMyNumber = try visualFiles.getMyNumber()
                    if let myNumberImage = visualMyNumber.myNumber {
                        let src = "data:image/png;base64,\(myNumberImage.base64EncodedString())"
                        dataDict["cardinfo-mynumber-image"] = src
                    }
                } catch JeidError.unsupportedOperation {
                    // 無償版の場合、INVisualFiles#getMyNumber()でJeidError.unsupportedOperationが返ります
                }

                self.publishLog("### Validating the visual AP")
                do {
                    let visualApValidationResult = try visualFiles.validate()
                    self.publishLog(visualApValidationResult.description + "\n")
                    dataDict["visualap-validation-result"] = visualApValidationResult.isValid
                } catch JeidError.unsupportedOperation {
                    // 無償版の場合、INVisualFiles#validate()でJeidError.unsupportedOperationが返ります
                    self.publishLog("Free version library does not support validation\n")
                }

                session.alertMessage = "Reading completed"
                session.invalidate()
                self.openWebView(dataDict)
            } catch {
                session.invalidate(errorMessage: session.alertMessage + "Failed") // Translated from "失敗"
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

                let path = Bundle.main.path(forResource: "in", ofType: "html", inDirectory: "WebAssets/in")!
                let localHtmlUrl = URL(fileURLWithPath: path, isDirectory: false)
                let webViewController = WebViewController(localHtmlUrl, "render(\'\(jsonStr!)\');")
                webViewController.title = "My Number Card Viewer"
                self.navigationController?.pushViewController(webViewController, animated: true)
            } catch (let error) {
                self.publishLog("\(error)")
                self.openAlertView("Error", "Failed to display reading results")
            }
        }
    }

    func handleInvalidPinError(_ jeidError: JeidError) {
        let title: String
        let message: String
        guard case .invalidPin(let counter) = jeidError else {
            print("unexpected error: \(jeidError)")
            return
        }
        if (jeidError.isBlocked!) {
            title = "PIN is blocked" // Translated from "暗証番号がブロックされています"
            message = "Please apply for unblocking at your municipal office." // Translated from "市区町村窓口でブロック解除の申請を行ってください。"
        } else {
            title = "Incorrect PIN" // Translated from "暗証番号が間違っています"
            message = "Please enter the correct PIN.\n" // Translated from "暗証番号を正しく入力してください。\n"
                + "It will be blocked after \(counter) more incorrect attempts." // Translated from "残り\(counter)回間違えるとブロックされます。"
        }
        openAlertView(title, message)
    }
}
