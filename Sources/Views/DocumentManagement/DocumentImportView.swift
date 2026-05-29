import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DocumentImportView: View {
    let customer: Customer
    let documentType: DocumentTypeInfo
    @ObservedObject var docVM: DocumentViewModel
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var ocrVM = OCRViewModel()
    
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingFilePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedImages: [UIImage] = []
    @State private var isProcessing = false
    @State private var showOCROption = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(documentType.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(documentType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Text("选择导入方式")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    ImportButton(
                        icon: "camera.fill",
                        title: "拍照导入",
                        subtitle: "使用相机拍摄\(documentType.name)",
                        color: .blue
                    ) {
                        showingCamera = true
                    }
                    
                    ImportButton(
                        icon: "photo.on.rectangle",
                        title: "从相册选择",
                        subtitle: "从手机相册选择照片",
                        color: .green
                    ) {
                        showingImagePicker = true
                    }
                    
                    ImportButton(
                        icon: "doc.fill",
                        title: "从文件导入",
                        subtitle: "选择PDF、Word、Excel或图片文件",
                        color: .orange
                    ) {
                        showingFilePicker = true
                    }
                }
                .padding(.horizontal)
                
                if isProcessing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("正在处理...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                if let error = ocrVM.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("导入资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingImagePicker) {
                MultiImagePicker(selectedImages: $selectedImages)
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [
                    .image, .pdf,
                    UTType(filenameExtension: "xlsx") ?? .data,
                    UTType(filenameExtension: "xls") ?? .data,
                    UTType(filenameExtension: "docx") ?? .data,
                    UTType(filenameExtension: "doc") ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: selectedImage) { newImage in
                guard let image = newImage else { return }
                handleImageImport(image)
            }
            .onChange(of: selectedImages) { newImages in
                for image in newImages {
                    handleImageImport(image)
                }
            }
            .alert("导入成功", isPresented: $showSuccess) {
                Button("确定") { dismiss() }
                Button("继续导入") {}
            } message: {
                Text("资料已成功导入")
            }
        }
    }
    
    func handleImageImport(_ image: UIImage) {
        isProcessing = true
        
        if let doc = docVM.saveImage(image, for: customer.id, documentType: documentType.id) {
            docVM.addDocument(to: customer.id, document: doc)
            
            if documentType.requiresOCR {
                showOCROption = true
            }
            
            showSuccess = true
        }
        
        isProcessing = false
        selectedImage = nil
    }
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                
                if let doc = docVM.saveFile(data, for: customer.id, documentType: documentType.id, fileName: fileName) {
                    docVM.addDocument(to: customer.id, document: doc)
                    showSuccess = true
                }
            } catch {
                docVM.errorMessage = "文件读取失败: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            docVM.errorMessage = "文件选择失败: \(error.localizedDescription)"
        }
    }
}

struct ImportButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker
        
        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.selectedImages.append(image)
                            }
                        }
                    }
                }
            }
        }
    }
}
