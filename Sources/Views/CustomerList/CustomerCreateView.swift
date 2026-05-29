import SwiftUI

struct CustomerCreateView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var ocrVM = OCRViewModel()
    
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
    
    @State private var showingIDCardScanner = false
    @State private var showingSpouseIDCardScanner = false
    @State private var scanTarget = 0
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    @State private var validationErrors: [String] = []
    @State private var showValidationAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("客户基本信息").font(.headline)) {
                    HStack {
                        Text("姓名")
                        TextField("请输入客户姓名", text: $name)
                            .textContentType(.name)
                    }
                    
                    Picker("性别", selection: $gender) {
                        Text("男").tag("男")
                        Text("女").tag("女")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Text("电话")
                        TextField("11位手机号", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    
                    HStack {
                        Text("住址")
                        TextField("请输入现住址", text: $address)
                    }
                    
                    HStack {
                        Text("身份证号")
                        TextField("18位身份证号码", text: $idNumber)
                            .keyboardType(.asciiCapable)
                    }
                    
                    HStack {
                        Text("证件有效期")
                        TextField("如: 2020.01.01-2030.01.01", text: $idExpiry)
                    }
                    
                    Button(action: {
                        scanTarget = 1
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("扫描客户身份证")
                        }
                    }
                }
                
                Section(header: Text("配偶基本信息").font(.headline)) {
                    HStack {
                        Text("姓名")
                        TextField("请输入配偶姓名", text: $spouseName)
                            .textContentType(.name)
                    }
                    
                    Picker("性别", selection: $spouseGender) {
                        Text("男").tag("男")
                        Text("女").tag("女")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Text("电话")
                        TextField("11位手机号", text: $spousePhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    
                    HStack {
                        Text("身份证号")
                        TextField("18位身份证号码", text: $spouseIdNumber)
                            .keyboardType(.asciiCapable)
                    }
                    
                    HStack {
                        Text("证件有效期")
                        TextField("如: 2020.01.01-2030.01.01", text: $spouseIdExpiry)
                    }
                    
                    Button(action: {
                        scanTarget = 2
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("扫描配偶身份证")
                        }
                    }
                }
                
                Section(header: Text("营业执照信息").font(.headline)) {
                    HStack {
                        Text("类型")
                        TextField("如: 个体工商户", text: $businessLicenseType)
                    }
                    
                    Button(action: {
                        scanTarget = 3
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("扫描营业执照")
                        }
                    }
                }
                
                if ocrVM.isProcessing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("正在识别...")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = ocrVM.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("创建客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCustomer()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .onChange(of: selectedImage) { newImage in
                guard let image = newImage else { return }
                processScannedImage(image)
            }
            .alert("验证错误", isPresented: $showValidationAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(validationErrors.joined(separator: "\n"))
            }
        }
    }
    
    func processScannedImage(_ image: UIImage) {
        switch scanTarget {
        case 1:
            ocrVM.extractIDCardInfo(from: image)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let info = ocrVM.idCardInfo {
                    if !info.name.isEmpty { name = info.name }
                    if !info.gender.isEmpty { gender = info.gender }
                    if !info.idNumber.isEmpty { idNumber = info.idNumber }
                    if !info.expiry.isEmpty { idExpiry = info.expiry }
                }
            }
        case 2:
            ocrVM.extractIDCardInfo(from: image)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let info = ocrVM.idCardInfo {
                    if !info.name.isEmpty { spouseName = info.name }
                    if !info.gender.isEmpty { spouseGender = info.gender }
                    if !info.idNumber.isEmpty { spouseIdNumber = info.idNumber }
                    if !info.expiry.isEmpty { spouseIdExpiry = info.expiry }
                }
            }
        case 3:
            ocrVM.extractBusinessLicenseInfo(from: image)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let info = ocrVM.businessLicenseInfo {
                    if !info.type.isEmpty { businessLicenseType = info.type }
                }
            }
        default:
            break
        }
        selectedImage = nil
    }
    
    func saveCustomer() {
        validationErrors = []
        
        let nameValidation = Validator.validateName(name)
        if !nameValidation.isValid {
            validationErrors.append(nameValidation.message)
        }
        
        let phoneValidation = Validator.validatePhoneNumber(phone)
        if !phoneValidation.isValid {
            validationErrors.append(phoneValidation.message)
        }
        
        if !idNumber.isEmpty {
            let idValidation = Validator.validateIDNumber(idNumber)
            if !idValidation.isValid {
                validationErrors.append("客户身份证: \(idValidation.message)")
            }
        }
        
        if !spouseIdNumber.isEmpty {
            let spouseIdValidation = Validator.validateIDNumber(spouseIdNumber)
            if !spouseIdValidation.isValid {
                validationErrors.append("配偶身份证: \(spouseIdValidation.message)")
            }
        }
        
        if !spousePhone.isEmpty {
            let spousePhoneValidation = Validator.validatePhoneNumber(spousePhone)
            if !spousePhoneValidation.isValid {
                validationErrors.append("配偶电话: \(spousePhoneValidation.message)")
            }
        }
        
        if !validationErrors.isEmpty {
            showValidationAlert = true
            return
        }
        
        let customer = Customer(
            name: name,
            phone: phone,
            address: address,
            spouseName: spouseName,
            spousePhone: spousePhone,
            gender: gender,
            spouseGender: spouseGender,
            idNumber: idNumber,
            spouseIdNumber: spouseIdNumber,
            idExpiry: idExpiry,
            spouseIdExpiry: spouseIdExpiry,
            businessLicenseType: businessLicenseType
        )
        
        dataStore.addCustomer(customer)
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
