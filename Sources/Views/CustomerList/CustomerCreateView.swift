import SwiftUI
import PhotosUI

struct CustomerCreateView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var ocrVM = OCRViewModel()
    @StateObject private var docVM = DocumentViewModel()

    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var spouseName = ""
    @State private var spousePhone = ""
    @State private var gender = "男"
    @State private var spouseGender = "女"
    @State private var idNumber = ""
    @State private var spouseIdNumber = ""
    @State private var idExpiry = ""
    @State private var spouseIdExpiry = ""
    @State private var businessLicenseType = ""
    @State private var businessName = ""
    @State private var businessLegalRepresentative = ""
    @State private var businessAddress = ""

    // Separate state for each import source to avoid race conditions
    @State private var cameraImage: UIImage?
    @State private var photoLibImage: UIImage?
    @State private var scanTarget = 0
    @State private var showImportChoice = false
    @State private var showCamera = false
    @State private var showPhotoLib = false
    
    @State private var collectedDocs: [String: (data: Data, fileName: String)] = [:]
    @State private var validationErrors: [String] = []
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var ocrFeedback = ""
    @State private var showRawOCR = false
    @State private var rawOCRText = ""

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Customer Info
                Section(header: Text("客户身份证")) {
                    field("姓名", text: $name, placeholder: "客户姓名")
                    genderPicker("性别", selection: $gender, isCustomer: true)
                    field("电话", text: $phone, placeholder: "11位手机号", keyboard: .phonePad)
                    field("住址", text: $address, placeholder: "现住址")
                    field("身份证号", text: $idNumber, placeholder: "18位", keyboard: .asciiCapable)
                    field("有效期", text: $idExpiry, placeholder: "如2020.01.01-2030.01.01")
                    scanBtn("客户身份证——正面(人像面)", target: 1, key: "id_card_front")
                    scanBtn("客户身份证——背面(国徽面)", target: 2, key: "id_card_back")
                }
                // MARK: - Spouse Info
                Section(header: Text("配偶身份证")) {
                    field("姓名", text: $spouseName, placeholder: "配偶姓名")
                    genderPicker("性别", selection: $spouseGender, isCustomer: false)
                    field("电话", text: $spousePhone, placeholder: "11位手机号", keyboard: .phonePad)
                    field("身份证号", text: $spouseIdNumber, placeholder: "18位", keyboard: .asciiCapable)
                    field("有效期", text: $spouseIdExpiry, placeholder: "如2020.01.01-2030.01.01")
                    scanBtn("配偶身份证——正面", target: 3, key: "spouse_id_front")
                    scanBtn("配偶身份证——背面", target: 4, key: "spouse_id_back")
                }
                // MARK: - Business License
                Section(header: Text("营业执照信息")) {
                    field("名称", text: $businessName, placeholder: "工商户名称")
                    field("类型", text: $businessLicenseType, placeholder: "如个体工商户")
                    field("法定代表人", text: $businessLegalRepresentative, placeholder: "法定代表人姓名")
                    field("住所", text: $businessAddress, placeholder: "营业住所")
                    scanBtn("扫描营业执照", target: 5, key: "business_license")
                }
                // MARK: - Feedback
                if ocrVM.isProcessing {
                    HStack { ProgressView(); Text("正在识别中，请稍候...") }
                }
                if !ocrFeedback.isEmpty {
                    Text(ocrFeedback).font(.caption).foregroundColor(.orange)
                }
                if !rawOCRText.isEmpty {
                    Button(action: { showRawOCR.toggle() }) {
                        Text(showRawOCR ? "隐藏识别文字" : "查看原始识别文字")
                            .font(.caption2).foregroundColor(.blue)
                    }
                    if showRawOCR {
                        Text(rawOCRText).font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray).padding(4)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                if let e = ocrVM.errorMessage {
                    Text(e).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle("创建客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { saveCustomer() }.fontWeight(.bold) }
            }
            .confirmationDialog("选择导入方式", isPresented: $showImportChoice, titleVisibility: .visible) {
                Button("拍照") { showCamera = true }
                Button("从相册选择") { showPhotoLib = true }
                Button("取消", role: .cancel) {}
            }
            // Camera sheet - uses separate cameraImage state
            .sheet(isPresented: $showCamera, onDismiss: {
                if let img = cameraImage {
                    processImage(img, fromCamera: true)
                    cameraImage = nil
                }
            }) {
                ImagePicker(image: $cameraImage, sourceType: .camera)
            }
            // Photo library sheet - uses separate photoLibImage state
            .sheet(isPresented: $showPhotoLib, onDismiss: {
                if let img = photoLibImage {
                    processImage(img, fromCamera: false)
                    photoLibImage = nil
                }
            }) {
                SinglePhotoPicker(selectedImage: $photoLibImage)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: { Text(validationErrors.joined(separator: "\n")) }
        }
        .onChange(of: gender) { newGender in
            // Auto-set spouse gender opposite to customer (fix #4)
            if newGender == "男" { spouseGender = "女" }
            else { spouseGender = "男" }
        }
    }

    // MARK: - Subviews
    private func field(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack { Text(label).frame(width: 70, alignment: .leading); TextField(placeholder, text: text).keyboardType(keyboard) }
    }

    private func genderPicker(_ label: String, selection: Binding<String>, isCustomer: Bool) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .leading)
            Picker(label, selection: selection) { Text("男").tag("男"); Text("女").tag("女") }.pickerStyle(.segmented)
        }
    }

    private func scanBtn(_ label: String, target: Int, key: String) -> some View {
        Button(action: {
            scanTarget = target
            ocrFeedback = ""
            showImportChoice = true
        }) {
            HStack {
                Image(systemName: "camera.viewfinder"); Text(label); Spacer()
                if collectedDocs[key] != nil { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
            }
        }
    }

    // MARK: - OCR Processing (fix #2, #3)
        func processImage(_ image: UIImage, fromCamera: Bool) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let map: [Int: (key: String, fileName: String)] = [
            1: ("id_card_front", "客户身份证正面.jpg"),
            2: ("id_card_back", "客户身份证背面.jpg"),
            3: ("spouse_id_front", "配偶身份证正面.jpg"),
            4: ("spouse_id_back", "配偶身份证背面.jpg"),
            5: ("business_license", "营业执照.jpg")
        ]
        guard let m = map[scanTarget] else { return }
        collectedDocs[m.key] = (data: data, fileName: m.fileName)
        ocrFeedback = "正在识别中..."

        switch scanTarget {
        case 1: // Customer ID Front
            OCRHelper.recognizeTextRobust(from: image) { text in
                DispatchQueue.main.async {
                    guard let text = text else { ocrFeedback = "⚠️ 识别失败，请重新拍摄清晰照片或手动输入"; return }
                    let info = OCRHelper.extractIDCardFront(from: text)
                    var filled: [String] = []
                    if !info.name.isEmpty { name = info.name; filled.append("姓名") }
                    if !info.gender.isEmpty { gender = info.gender; filled.append("性别") }
                    if !info.idNumber.isEmpty { idNumber = info.idNumber; filled.append("身份证号") }
                    if !info.address.isEmpty && address.isEmpty { address = info.address; filled.append("地址") }
                    rawOCRText = text
                    if filled.isEmpty { ocrFeedback = "⚠️ 未能提取信息，请确保照片清晰、方向正确" }
                    else {
                        let allFields = ["姓名","性别","身份证号","地址","民族","出生日期","有效期"]
                        let missed = allFields.filter { !filled.contains($0) }
                        if missed.isEmpty { ocrFeedback = "✅ 已提取: \(filled.joined(separator: "、"))" }
                        else { ocrFeedback = "✅ 已提取: \(filled.joined(separator: "、"))\n⚠️ 未提取: \(missed.joined(separator: "、"))\n点击下方可查看原始识别文字" }
                    }
                }
            }
        case 2: // Customer ID Back
            OCRHelper.recognizeBlocksRobust(from: image) { blocks in
                DispatchQueue.main.async {
                    let text = blocks.map { $0.text }.joined(separator: "\n")
                    guard !blocks.isEmpty else { ocrFeedback = "⚠️ 识别失败，请重新拍摄"; return }
                    let info = OCRHelper.extractIDCardBack(from: text)
                    if !info.expiry.isEmpty { idExpiry = info.expiry; ocrFeedback = "✅ 已提取有效期: \(info.expiry)" }
                    else { ocrFeedback = "⚠️ 未能提取有效期，请手动输入\n识别文字: \(text.prefix(80))..." }
                }
            }
        case 3: // Spouse ID Front
            OCRHelper.recognizeBlocksRobust(from: image) { blocks in
                DispatchQueue.main.async {
                    let text = blocks.map { $0.text }.joined(separator: "\n")
                    guard !blocks.isEmpty else { ocrFeedback = "⚠️ 识别失败，请重新拍摄"; return }
                    let info = OCRHelper.extractIDCardFront(from: blocks)
                    var filled: [String] = []
                    if !info.name.isEmpty { spouseName = info.name; filled.append("配偶姓名") }
                    if !info.gender.isEmpty { spouseGender = info.gender; filled.append("配偶性别") }
                    if !info.idNumber.isEmpty { spouseIdNumber = info.idNumber; filled.append("配偶身份证号") }
                    if filled.isEmpty { ocrFeedback = "⚠️ 未能提取信息，请手动输入" }
                    else { ocrFeedback = "✅ 已提取: \(filled.joined(separator: "、"))" }
                }
            }
        case 4: // Spouse ID Back
            OCRHelper.recognizeBlocksRobust(from: image) { blocks in
                DispatchQueue.main.async {
                    let text = blocks.map { $0.text }.joined(separator: "\n")
                    guard !blocks.isEmpty else { ocrFeedback = "⚠️ 识别失败，请重新拍摄"; return }
                    let info = OCRHelper.extractIDCardBack(from: text)
                    if !info.expiry.isEmpty { spouseIdExpiry = info.expiry; ocrFeedback = "✅ 已提取配偶有效期: \(info.expiry)" }
                    else { ocrFeedback = "⚠️ 未能提取有效期，请手动输入" }
                }
            }
        case 5: // Business License
            OCRHelper.recognizeBlocksRobust(from: image) { blocks in
                DispatchQueue.main.async {
                    let text = blocks.map { $0.text }.joined(separator: "\n")
                    guard !blocks.isEmpty else { ocrFeedback = "⚠️ 识别失败，请重新拍摄"; return }
                    let info = OCRHelper.extractBusinessLicenseInfo(from: blocks)
                    rawOCRText = text
                    var filled: [String] = []
                    if !info.name.isEmpty { businessName = info.name; filled.append("名称") }
                    if !info.type.isEmpty { businessLicenseType = info.type; filled.append("类型") }
                    if !info.legalRepresentative.isEmpty { businessLegalRepresentative = info.legalRepresentative; filled.append("法定代表人") }
                    if !info.address.isEmpty { businessAddress = info.address; filled.append("住所") }
                    if filled.isEmpty { ocrFeedback = "⚠️ 未能提取信息，请确保照片清晰" }
                    else {
                        let allFields = ["名称","类型","法定代表人","住所","注册资本","成立日期","经营范围"]
                        let missed = allFields.filter { !filled.contains($0) }
                        if missed.isEmpty { ocrFeedback = "✅ 已提取: \(filled.joined(separator: "、"))" }
                        else { ocrFeedback = "✅ 已提取: \(filled.joined(separator: "、"))\n⚠️ 未提取: \(missed.joined(separator: "、"))" }
                    }
                }
            }
        default: break
        }
    }

    // MARK: - Save (fix #4: auto-set business rep)
    func saveCustomer() {
        // Auto-set business legal representative = customer name if empty
        if businessLegalRepresentative.isEmpty && !name.isEmpty {
            businessLegalRepresentative = name
        }
        
        validationErrors = []
        let nv = Validator.validateName(name); if !nv.isValid { validationErrors.append(nv.message) }
        let pv = Validator.validatePhoneNumber(phone); if !pv.isValid { validationErrors.append(pv.message) }
        if !idNumber.isEmpty { let iv = Validator.validateIDNumber(idNumber); if !iv.isValid { validationErrors.append("客户身份证: \(iv.message)") } }
        if !spouseIdNumber.isEmpty { let sv = Validator.validateIDNumber(spouseIdNumber); if !sv.isValid { validationErrors.append("配偶身份证: \(sv.message)") } }
        if !spousePhone.isEmpty { let sp = Validator.validatePhoneNumber(spousePhone); if !sp.isValid { validationErrors.append("配偶电话: \(sp.message)") } }
        if !validationErrors.isEmpty { alertTitle = "验证错误"; showAlert = true; return }

        var c = Customer(name: name, phone: phone, address: address, spouseName: spouseName, spousePhone: spousePhone, gender: gender, spouseGender: spouseGender, idNumber: idNumber, spouseIdNumber: spouseIdNumber, idExpiry: idExpiry, spouseIdExpiry: spouseIdExpiry, businessLicenseType: businessLicenseType, businessName: businessName, businessLegalRepresentative: businessLegalRepresentative, businessAddress: businessAddress)
        for (dk, di) in collectedDocs {
            let fp = dataStore.saveFile(data: di.data, customerId: c.id, documentType: dk, fileName: di.fileName)
            let t = docVM.createThumbnail(from: di.data)
            c.documents.append(DocumentItem(documentType: dk, fileName: di.fileName, filePath: fp, fileData: di.data, thumbnailData: t))
        }
        dataStore.addCustomer(c)
        dismiss()
    }
}