import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let customer: Customer
    @Environment(\.dismiss) var dismiss
    @State private var pdfData: Data?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("正在生成PDF...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let data = pdfData {
                    PDFKitView(data: data)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("生成客户资料PDF")
                            .font(.title2)
                        
                        Text("将根据已录入的资料生成完整的贷款资料PDF文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: generatePDF) {
                            Text("生成PDF")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
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
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
        }
    }
    
    func generatePDF() {
        isGenerating = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = PDFGenerator.generateFullPDF(customer: customer)
            
            DispatchQueue.main.async {
                isGenerating = false
                if let data = data {
                    pdfData = data
                } else {
                    errorMessage = "PDF生成失败"
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
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
