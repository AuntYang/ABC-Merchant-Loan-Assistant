import SwiftUI

struct CustomerDetailView: View {
    let customer: Customer
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var docVM = DocumentViewModel()
    @State private var showingDocumentImport = false
    @State private var selectedDocType: DocumentTypeInfo?
    @State private var showingPDFPreview = false
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    
    // Editable fields
    @State private var editName = ""
    @State private var editPhone = ""
    @State private var editAddress = ""
    @State private var editSpouseName = ""
    @State private var editSpousePhone = ""
    @State private var editGender = ""
    @State private var editSpouseGender = ""
    @State private var editIdNumber = ""
    @State private var editSpouseIdNumber = ""
    @State private var editIdExpiry = ""
    @State private var editSpouseIdExpiry = ""
    @State private var editBusinessLicenseType = ""
    @State private var editBusinessName = ""
    @State private var editBusinessLegalRepresentative = ""
    @State private var editBusinessAddress = ""
    @State private var editErrors: [String] = []
    @State private var showEditAlert = false
    
    var currentCustomer: Customer {
        dataStore.customers.first(where: { $0.id == customer.id }) ?? customer
    }
    
    var body: some View {
        List {
            // MARK: - Completion Overview Dashboard (Fix 5)
            Section {
                CompletionDashboardView(customer: currentCustomer)
            }
            
            // MARK: - Customer Info (editable - Fix 2)
            Section(header: Text("\u{5BA2}\u{6237}\u{4FE1}\u{606F}")) {
                if isEditing {
                    EditableField(label: "\u{59D3}\u{540D}", text: $editName)
                    Picker("\u{6027}\u{522B}", selection: $editGender) {
                        Text("\u{7537}").tag("\u{7537}")
                        Text("\u{5973}").tag("\u{5973}")
                    }.pickerStyle(SegmentedPickerStyle())
                    EditableField(label: "\u{7535}\u{8BDD}", text: $editPhone, keyboard: .phonePad)
                    EditableField(label: "\u{4F4F}\u{5740}", text: $editAddress)
                    EditableField(label: "\u{8EAB}\u{4EFD}\u{8BC1}\u{53F7}", text: $editIdNumber, keyboard: .asciiCapable)
                    EditableField(label: "\u{8BC1}\u{4EF6}\u{6709}\u{6548}\u{671F}", text: $editIdExpiry)
                } else {
                    InfoRow(label: "\u{59D3}\u{540D}", value: currentCustomer.name)
                    InfoRow(label: "\u{6027}\u{522B}", value: currentCustomer.gender)
                    InfoRow(label: "\u{7535}\u{8BDD}", value: currentCustomer.phone)
                    InfoRow(label: "\u{4F4F}\u{5740}", value: currentCustomer.address)
                    InfoRow(label: "\u{8EAB}\u{4EFD}\u{8BC1}\u{53F7}", value: currentCustomer.idNumber)
                    InfoRow(label: "\u{8BC1}\u{4EF6}\u{6709}\u{6548}\u{671F}", value: currentCustomer.idExpiry)
                }
            }
            
            // MARK: - Spouse Info
            Section(header: Text("\u{914D}\u{5076}\u{4FE1}\u{606F}")) {
                if isEditing {
                    EditableField(label: "\u{59D3}\u{540D}", text: $editSpouseName)
                    Picker("\u{6027}\u{522B}", selection: $editSpouseGender) {
                        Text("\u{7537}").tag("\u{7537}")
                        Text("\u{5973}").tag("\u{5973}")
                    }.pickerStyle(SegmentedPickerStyle())
                    EditableField(label: "\u{7535}\u{8BDD}", text: $editSpousePhone, keyboard: .phonePad)
                    EditableField(label: "\u{8EAB}\u{4EFD}\u{8BC1}\u{53F7}", text: $editSpouseIdNumber, keyboard: .asciiCapable)
                    EditableField(label: "\u{8BC1}\u{4EF6}\u{6709}\u{6548}\u{671F}", text: $editSpouseIdExpiry)
                } else {
                    InfoRow(label: "\u{59D3}\u{540D}", value: currentCustomer.spouseName)
                    InfoRow(label: "\u{6027}\u{522B}", value: currentCustomer.spouseGender)
                    InfoRow(label: "\u{7535}\u{8BDD}", value: currentCustomer.spousePhone)
                    InfoRow(label: "\u{8EAB}\u{4EFD}\u{8BC1}\u{53F7}", value: currentCustomer.spouseIdNumber)
                    InfoRow(label: "\u{8BC1}\u{4EF6}\u{6709}\u{6548}\u{671F}", value: currentCustomer.spouseIdExpiry)
                }
            }
            
            // MARK: - Business Info
            Section(header: Text("\u{8425}\u{4E1A}\u{6267}\u{7167}\u{4FE1}\u{606F}")) {
                if isEditing {
                    EditableField(label: "\u{540D}\u{79F0}", text: $editBusinessName)
                    EditableField(label: "\u{7C7B}\u{578B}", text: $editBusinessLicenseType)
                    EditableField(label: "\u{6CD5}\u{5B9A}\u{4EE3}\u{8868}\u{4EBA}", text: $editBusinessLegalRepresentative)
                    EditableField(label: "\u{4F4F}\u{6240}", text: $editBusinessAddress)
                } else {
                    InfoRow(label: "\u{540D}\u{79F0}", value: currentCustomer.businessName)
                    InfoRow(label: "\u{7C7B}\u{578B}", value: currentCustomer.businessLicenseType)
                    InfoRow(label: "\u{6CD5}\u{5B9A}\u{4EE3}\u{8868}\u{4EBA}", value: currentCustomer.businessLegalRepresentative)
                    InfoRow(label: "\u{4F4F}\u{6240}", value: currentCustomer.businessAddress)
                }
            }
            
            // MARK: - Document Checklist
            Section(header: Text("\u{8D44}\u{6599}\u{6E05}\u{5355}")) {
                ForEach(DocumentCategory.allCases, id: \.self) { category in
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
            
            // MARK: - Actions
            Section {
                Button(action: { showingPDFPreview = true }) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("\u{751F}\u{6210}PDF\u{8D44}\u{6599}\u{5305}")
                    }
                }
            }
        }
        .navigationTitle(currentCustomer.name.isEmpty ? "\u{5BA2}\u{6237}\u{8BE6}\u{60C5}" : currentCustomer.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "\u{5B8C}\u{6210}" : "\u{7F16}\u{8F91}") {
                    if isEditing {
                        saveEdits()
                    } else {
                        startEditing()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentImport) {
            if let docType = selectedDocType {
                DocumentImportView(customer: currentCustomer, documentType: docType, docVM: docVM)
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            PDFPreviewView(customer: currentCustomer)
        }
        .alert("\u{9A8C}\u{8BC1}\u{9519}\u{8BEF}", isPresented: $showEditAlert) {
            Button("\u{786E}\u{5B9A}", role: .cancel) {}
        } message: {
            Text(editErrors.joined(separator: "\n"))
        }
    }
    
    func startEditing() {
        editName = currentCustomer.name
        editPhone = currentCustomer.phone
        editAddress = currentCustomer.address
        editGender = currentCustomer.gender
        editSpouseName = currentCustomer.spouseName
        editSpousePhone = currentCustomer.spousePhone
        editSpouseGender = currentCustomer.spouseGender
        editIdNumber = currentCustomer.idNumber
        editSpouseIdNumber = currentCustomer.spouseIdNumber
        editIdExpiry = currentCustomer.idExpiry
        editSpouseIdExpiry = currentCustomer.spouseIdExpiry
        editBusinessLicenseType = currentCustomer.businessLicenseType
        editBusinessName = currentCustomer.businessName
        editBusinessLegalRepresentative = currentCustomer.businessLegalRepresentative
        editBusinessAddress = currentCustomer.businessAddress
        isEditing = true
    }
    
    func saveEdits() {
        editErrors = []
        
        let nameV = Validator.validateName(editName)
        if !nameV.isValid { editErrors.append(nameV.message) }
        let phoneV = Validator.validatePhoneNumber(editPhone)
        if !phoneV.isValid { editErrors.append(phoneV.message) }
        if !editIdNumber.isEmpty {
            let idV = Validator.validateIDNumber(editIdNumber)
            if !idV.isValid { editErrors.append("\u{5BA2}\u{6237}\u{8EAB}\u{4EFD}\u{8BC1}: \(idV.message)") }
        }
        if !editSpouseIdNumber.isEmpty {
            let sidV = Validator.validateIDNumber(editSpouseIdNumber)
            if !sidV.isValid { editErrors.append("\u{914D}\u{5076}\u{8EAB}\u{4EFD}\u{8BC1}: \(sidV.message)") }
        }
        if !editSpousePhone.isEmpty {
            let spV = Validator.validatePhoneNumber(editSpousePhone)
            if !spV.isValid { editErrors.append("\u{914D}\u{5076}\u{7535}\u{8BDD}: \(spV.message)") }
        }
        
        if !editErrors.isEmpty {
            showEditAlert = true
            return
        }
        
        var updated = currentCustomer
        updated.name = editName
        updated.phone = editPhone
        updated.address = editAddress
        updated.gender = editGender
        updated.spouseName = editSpouseName
        updated.spousePhone = editSpousePhone
        updated.spouseGender = editSpouseGender
        updated.idNumber = editIdNumber
        updated.spouseIdNumber = editSpouseIdNumber
        updated.idExpiry = editIdExpiry
        updated.spouseIdExpiry = editSpouseIdExpiry
        updated.businessLicenseType = editBusinessLicenseType
        updated.businessName = editBusinessName
        updated.businessLegalRepresentative = editBusinessLegalRepresentative
        updated.businessAddress = editBusinessAddress
        
        dataStore.updateCustomer(updated)
        isEditing = false
    }
}

// MARK: - Editable Field
struct EditableField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .foregroundColor(.secondary)
            TextField(label, text: $text)
                .keyboardType(keyboard)
        }
    }
}

// MARK: - Completion Dashboard (Fix 5)
struct CompletionDashboardView: View {
    let customer: Customer
    
    var totalDocs: Int { DocumentTypeRegistry.allTypes.count }
    var completedDocs: Int { customer.documents.count }
    var percentage: Double { totalDocs > 0 ? Double(completedDocs) / Double(totalDocs) : 0 }
    
    var categoryStats: [(String, Int, Int, Color)] {
        DocumentCategory.allCases.compactMap { cat in
            let types = DocumentTypeRegistry.getTypes(forCategory: cat)
            guard !types.isEmpty else { return nil }
            let completed = types.filter { t in customer.documents.contains { $0.documentType == t.id } }.count
            let color: Color = completed == types.count ? .green : (completed > 0 ? .orange : .red)
            return (cat.rawValue, completed, types.count, color)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Overall progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{8D44}\u{6599}\u{5B8C}\u{6210}\u{5EA6}")
                        .font(.headline)
                    Text("\(completedDocs)/\(totalDocs) \u{9879}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(percentage))
                        .stroke(percentage > 0.8 ? Color.green : (percentage > 0.5 ? Color.orange : Color.red), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(width: 60, height: 60)
            }
            
            // Per-category breakdown
            VStack(spacing: 6) {
                ForEach(categoryStats, id: \.0) { stat in
                    HStack {
                        Text(stat.0)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        
                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(stat.3)
                                    .frame(width: geo.size.width * (stat.2 > 0 ? CGFloat(stat.1) / CGFloat(stat.2) : 0), height: 12)
                            }
                        }
                        .frame(height: 12)
                        
                        Text("\(stat.1)/\(stat.2)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "\u{672A}\u{586B}\u{5199}" : value)
                .foregroundColor(value.isEmpty ? .red : .primary)
        }
    }
}

// MARK: - Document Row
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
                        if let td = doc.thumbnailData, let ui = UIImage(data: td) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: fileIcon(for: doc))
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(doc.fileName).font(.caption).lineLimit(1)
                            Text(Validator.formatShortDate(doc.createdAt))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if doc.thumbnailData != nil {
                            Button(action: { onRotate(doc) }) {
                                Image(systemName: "rotate.right").foregroundColor(.orange)
                            }
                        }
                        
                        Button(action: { onDelete(doc) }) {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                    
                    Button(action: onImport) {
                        Text("\u{6DFB}\u{52A0}\u{66F4}\u{591A}").font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    func fileIcon(for doc: DocumentItem) -> String {
        if doc.fileName.hasSuffix(".pdf") { return "doc.fill" }
        if doc.fileName.hasSuffix(".xlsx") || doc.fileName.hasSuffix(".xls") { return "tablecells" }
        if doc.fileName.hasSuffix(".docx") || doc.fileName.hasSuffix(".doc") { return "doc.text" }
        return "photo"
    }
}
