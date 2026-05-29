import SwiftUI

struct CustomerDetailView: View {
    let customer: Customer
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var docVM = DocumentViewModel()
    @State private var showingDocumentImport = false
    @State private var selectedDocType: DocumentTypeInfo?
    @State private var showingPDFPreview = false
    @State private var showingImagePicker = false
    @State private var showingFilePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var currentCustomer: Customer {
        dataStore.customers.first(where: { $0.id == customer.id }) ?? customer
    }
    
    var body: some View {
        List {
            Section(header: Text("客户信息")) {
                InfoRow(label: "姓名", value: currentCustomer.name)
                InfoRow(label: "性别", value: currentCustomer.gender)
                InfoRow(label: "电话", value: currentCustomer.phone)
                InfoRow(label: "住址", value: currentCustomer.address)
                InfoRow(label: "身份证号", value: currentCustomer.idNumber)
                InfoRow(label: "证件有效期", value: currentCustomer.idExpiry)
            }
            
            if !currentCustomer.spouseName.isEmpty {
                Section(header: Text("配偶信息")) {
                    InfoRow(label: "姓名", value: currentCustomer.spouseName)
                    InfoRow(label: "性别", value: currentCustomer.spouseGender)
                    InfoRow(label: "电话", value: currentCustomer.spousePhone)
                    InfoRow(label: "身份证号", value: currentCustomer.spouseIdNumber)
                    InfoRow(label: "证件有效期", value: currentCustomer.spouseIdExpiry)
                }
            }
            
            if !currentCustomer.businessLicenseType.isEmpty || !currentCustomer.businessName.isEmpty {
                Section(header: Text("营业执照信息")) {
                    InfoRow(label: "类型", value: currentCustomer.businessLicenseType)
                    InfoRow(label: "名称", value: currentCustomer.businessName)
                    InfoRow(label: "法定代表人", value: currentCustomer.businessLegalRepresentative)
                    InfoRow(label: "住所", value: currentCustomer.businessAddress)
                }
            }
            
            Section(header: Text("资料清单")) {
                let categories = DocumentCategory.allCases
                ForEach(categories, id: \.self) { category in
                    let docTypes = DocumentTypeRegistry.getTypes(forCategory: category)
                    if !docTypes.isEmpty {
                        DisclosureGroup(category.rawValue) {
                            ForEach(docTypes) { docType in
                                DocumentRow(
                                    docType: docType,
                                    customer: currentCustomer,
                                    onImport: {
                                        selectedDocType = docType
                                        showingDocumentImport = true
                                    },
                                    onDelete: { doc in
                                        docVM.deleteDocument(customerId: currentCustomer.id, documentId: doc.id)
                                    },
                                    onRotate: { doc in
                                        docVM.rotateImage(document: doc, customerId: currentCustomer.id)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("操作")) {
                Button(action: { showingPDFPreview = true }) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("生成PDF资料包")
                    }
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle(currentCustomer.name.isEmpty ? "客户详情" : currentCustomer.name)
        .sheet(isPresented: $showingDocumentImport) {
            if let docType = selectedDocType {
                DocumentImportView(
                    customer: currentCustomer,
                    documentType: docType,
                    docVM: docVM
                )
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            PDFPreviewView(customer: currentCustomer)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "未填写" : value)
                .foregroundColor(value.isEmpty ? .red : .primary)
        }
    }
}

struct DocumentRow: View {
    let docType: DocumentTypeInfo
    let customer: Customer
    let onImport: () -> Void
    let onDelete: (DocumentItem) -> Void
    let onRotate: (DocumentItem) -> Void
    
    var matchingDocuments: [DocumentItem] {
        customer.documents.filter { $0.documentType == docType.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(docType.index). \(docType.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(docType.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if matchingDocuments.isEmpty {
                    Button(action: onImport) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            if !matchingDocuments.isEmpty {
                ForEach(matchingDocuments) { doc in
                    HStack {
                        if let thumbnailData = doc.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: fileIcon(for: doc))
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(doc.fileName)
                                .font(.caption)
                                .lineLimit(1)
                            Text(Validator.formatShortDate(doc.createdAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if doc.thumbnailData != nil {
                            Button(action: { onRotate(doc) }) {
                                Image(systemName: "rotate.right")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Button(action: { onDelete(doc) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: onImport) {
                        Text("添加更多")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    func fileIcon(for doc: DocumentItem) -> String {
        if doc.fileName.hasSuffix(".pdf") {
            return "doc.fill"
        } else if doc.fileName.hasSuffix(".xlsx") || doc.fileName.hasSuffix(".xls") {
            return "tablecells"
        } else if doc.fileName.hasSuffix(".docx") || doc.fileName.hasSuffix(".doc") {
            return "doc.text"
        }
        return "photo"
    }
}
