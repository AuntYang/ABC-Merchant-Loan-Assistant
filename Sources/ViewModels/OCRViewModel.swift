import UIKit
import Combine

class OCRViewModel: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var recognizedText: String = ""
    @Published var idCardInfo: IDCardInfo?
    @Published var businessLicenseInfo: BusinessLicenseInfo?
    @Published var errorMessage: String?
    
    func extractIDCardFront(from image: UIImage) {
        isProcessing = true; errorMessage = nil
        OCRHelper.recognizeTextRobust(from: image) { [weak self] text in
            DispatchQueue.main.async {
                self?.isProcessing = false
                guard let text = text else { self?.errorMessage = "身份证识别失败"; return }
                self?.recognizedText = text
                self?.idCardInfo = OCRHelper.extractIDCardFront(from: text)
            }
        }
    }
    
    func extractIDCardBack(from image: UIImage) {
        isProcessing = true; errorMessage = nil
        OCRHelper.recognizeTextRobust(from: image) { [weak self] text in
            DispatchQueue.main.async {
                self?.isProcessing = false
                guard let text = text else { self?.errorMessage = "身份证识别失败"; return }
                self?.recognizedText = text
                self?.idCardInfo = OCRHelper.extractIDCardBack(from: text)
            }
        }
    }
    
    func extractBusinessLicenseInfo(from image: UIImage) {
        isProcessing = true; errorMessage = nil
        OCRHelper.recognizeTextRobust(from: image) { [weak self] text in
            DispatchQueue.main.async {
                self?.isProcessing = false
                guard let text = text else { self?.errorMessage = "营业执照识别失败"; return }
                self?.recognizedText = text
                self?.businessLicenseInfo = OCRHelper.extractBusinessLicenseInfo(from: text)
            }
        }
    }
}