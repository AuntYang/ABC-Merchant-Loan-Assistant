import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct PDFPreviewView: View {
    let customer: Customer
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var pdfData: Data?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var showTemplateEditor = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("正在生成PDF...")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let data = pdfData {
                    PDFKitView(data: data)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 60)).foregroundColor(.gray)
                        Text("生成客户资料PDF")
                            .font(.title2)
                        Text("将根据已录入的资料生成完整的贷款资料PDF文件")
                            .font(.caption).foregroundColor(.secondary)
                        
                        let docs = currentCustomer().documents
                        let tplDocs = docs.filter { d in DocumentTypeRegistry.templateTypes.contains(where: { $0.id == d.documentType }) }
                        if !docs.isEmpty {
                            Text("已导入 \(docs.count) 个文档（模板 \(tplDocs.count) 个）")
                                .font(.caption).foregroundColor(.green)
                        } else {
                            Text("暂无导入文档").font(.caption).foregroundColor(.orange)
                        }
                        
                        Button(action: { showTemplateEditor = true }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("配置模板占位符")
                            }
                            .font(.headline).foregroundColor(.white)
                            .frame(width: 260, height: 48)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: generatePDF) {
                            Text("生成PDF")
                                .font(.headline).foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding()
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).padding()
                }
            }
            .navigationTitle("PDF预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if pdfData != nil {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData { ShareSheet(items: [data]) }
            }
            .sheet(isPresented: $showTemplateEditor) {
                TemplateEditorView(customer: customer, dataStore: dataStore)
            }
        }
    }
    
    func generatePDF() {
        isGenerating = true
        errorMessage = nil
        let c = currentCustomer()
        Task.detached(priority: .userInitiated) {
            let data = PDFGenerator.generateFullPDF(customer: c)
            await MainActor.run {
                self.isGenerating = false
                if let data = data { self.pdfData = data }
                else { self.errorMessage = "PDF生成失败" }
            }
        }
    }
    
    func currentCustomer() -> Customer {
        dataStore.customers.first(where: { $0.id == customer.id }) ?? customer
    }
}

struct TemplateEditorView: View {
    let customer: Customer
    let dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var templateKeys: [String] = []
    @State private var templateValues: [String: String] = [:]
    @State private var showDocImporter = false
    @State private var importedTemplateData: Data?
    @State private var importedTemplateFileName: String = ""
    @State private var selectedTemplateType: DocumentTypeInfo?
    @State private var importFeedback = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("模板占位符配置")) {
                    Text("在模板文档中使用 {{Key}} 格式的占位符，系统将自动用客户信息填充")
                        .font(.caption).foregroundColor(.secondary)
                    
                    Text("常用占位符").font(.headline)
                    
                    ForEach(["CustomerName", "CustomerPhone", "CustomerIdNumber", "CustomerAddress",
                             "CustomerGender", "SpouseName", "SpousePhone", "SpouseIdNumber",
                             "BusinessName", "BusinessLegalRepresentative", "BusinessAddress",
                             "CurrentDate", "Loan_id"], id: \.self) { key in
                        HStack {
                            Text("{{\(key)}}")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                            Spacer()
                            Text(autoValue(for: key))
                                .font(.caption).foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Section(header: Text("自定义占位符")) {
                    Text("添加模板中使用的其他占位符及其对应的值")
                        .font(.caption).foregroundColor(.secondary)
                    
                    ForEach(templateKeys, id: \.self) { key in
                        HStack {
                            Text("{{\(key)}}").font(.system(.caption, design: .monospaced))
                            Spacer()
                            TextField("值", text: Binding(
                                get: { templateValues[key] ?? "" },
                                set: { templateValues[key] = $0 }
                            ))
                        }
                    }
                    
                    Button(action: {
                        let newKey = "Custom_\(templateKeys.count + 1)"
                        templateKeys.append(newKey)
                        templateValues[newKey] = ""
                    }) {
                        Label("添加自定义占位符", systemImage: "plus")
                    }
                }
                
                Section(header: Text("导入模板文档")) {
                    ForEach(DocumentTypeRegistry.templateTypes) { docType in
                        Button(action: {
                            selectedTemplateType = docType
                            showDocImporter = true
                        }) {
                            HStack {
                                Text(docType.name)
                                Spacer()
                                if customer.documents.contains(where: { $0.documentType == docType.id }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                if !importFeedback.isEmpty {
                    Text(importFeedback).font(.caption).foregroundColor(.orange)
                }
            }
            .navigationTitle("模板编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveTemplateValues()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDocImporter) {
                DocumentPickerView(fileData: $importedTemplateData, fileName: $importedTemplateFileName, isPresented: $showDocImporter)
            }
            .onChange(of: importedTemplateData) { data in
                guard let data = data, let type = selectedTemplateType else { return }
                let docVM = DocumentViewModel()
                if let doc = docVM.saveFile(data, for: customer.id, documentType: type.id, fileName: importedTemplateFileName) {
                    docVM.addDocument(to: customer.id, document: doc)
                    importFeedback = "✅ 已导入: \(importedTemplateFileName)"
                } else {
                    importFeedback = "❌ 导入失败"
                }
                importedTemplateData = nil
            }
            .onAppear {
                templateValues = customer.autoTemplateValues()
                templateKeys = customer.templateValues.keys.sorted()
            }
        }
    }
    
    func autoValue(for key: String) -> String {
        let values = customer.autoTemplateValues()
        return values[key] ?? "(未设置)"
    }
    
    func saveTemplateValues() {
        var updated = customer
        updated.templateValues = templateValues
        dataStore.updateCustomer(updated)
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        if let doc = PDFDocument(data: data) { v.document = doc }
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}