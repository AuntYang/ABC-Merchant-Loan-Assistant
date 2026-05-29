import UIKit
import Vision
import Combine

class OCRViewModel: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var recognizedText: String = ""
    @Published var idCardInfo: IDCardInfo?
    @Published var businessLicenseInfo: BusinessLicenseInfo?
    @Published var errorMessage: String?
    
    func recognizeText(from image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        OCRHelper.recognizeText(from: image) { [weak self] text in
            DispatchQueue.main.async {
                self?.isProcessing = false
                if let text = text {
                    self?.recognizedText = text
                } else {
                    self?.errorMessage = "文字识别失败，请重试"
                }
            }
        }
    }
    
    func extractIDCardInfo(from image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        OCRHelper.recognizeText(from: image) { [weak self] text in
            DispatchQueue.main.async {
                self?.isProcessing = false
                guard let text = text else {
                    self?.errorMessage = "身份证识别失败，请重试"
                    return
                }
                self?.recognizedText = text
                self?.idCardInfo = OCRHelper.extractIDCardInfo(from: text)
            }
        }
    }
    
    func extractBusinessLicenseInfo(from image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        OCRHelper.recognizeText(from: image) { [weak self] text in
            DispatchQueue.main.async {
                self?.isProcessing = false
                guard let text = text else {
                    self?.errorMessage = "营业执照识别失败，请重试"
                    return
                }
                self?.recognizedText = text
                self?.businessLicenseInfo = OCRHelper.extractBusinessLicenseInfo(from: text)
            }
        }
    }
    
    func validateAndApplyIDInfo(to customer: inout Customer, isSpouse: Bool = false) {
        guard let info = idCardInfo else { return }
        
        if !info.name.isEmpty {
            if isSpouse {
                customer.spouseName = info.name
            } else {
                customer.name = info.name
            }
        }
        
        if !info.gender.isEmpty {
            if isSpouse {
                customer.spouseGender = info.gender
            } else {
                customer.gender = info.gender
            }
        }
        
        if !info.idNumber.isEmpty {
            let validation = Validator.validateIDNumber(info.idNumber)
            if validation.isValid {
                if isSpouse {
                    customer.spouseIdNumber = info.idNumber
                } else {
                    customer.idNumber = info.idNumber
                }
            }
        }
        
        if !info.expiry.isEmpty {
            if isSpouse {
                customer.spouseIdExpiry = info.expiry
            } else {
                customer.idExpiry = info.expiry
            }
        }
    }
    
    func validateAndApplyBusinessInfo(to customer: inout Customer) {
        guard let info = businessLicenseInfo else { return }
        
        if !info.name.isEmpty {
            customer.businessName = info.name
        }
        if !info.type.isEmpty {
            customer.businessLicenseType = info.type
        }
        if !info.legalRepresentative.isEmpty {
            customer.businessLegalRepresentative = info.legalRepresentative
        }
        if !info.address.isEmpty {
            customer.businessAddress = info.address
        }
    }
}
