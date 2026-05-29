import Foundation
import Combine

class DataStore: ObservableObject {
    @Published var customers: [Customer] = []
    
    static let shared = DataStore()
    
    private let fileName = "customers.json"
    
    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }
    
    private init() {
        load()
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            customers = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            customers = try JSONDecoder().decode([Customer].self, from: data)
        } catch {
            print("加载数据失败: \(error)")
            customers = []
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(customers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("保存数据失败: \(error)")
        }
    }
    
    func addCustomer(_ customer: Customer) {
        customers.append(customer)
        save()
    }
    
    func updateCustomer(_ customer: Customer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index] = customer
            save()
        }
    }
    
    func deleteCustomer(at offsets: IndexSet) {
        customers.remove(atOffsets: offsets)
        save()
    }
    
    func addDocument(to customerId: UUID, document: DocumentItem) {
        if let index = customers.firstIndex(where: { $0.id == customerId }) {
            customers[index].documents.append(document)
            save()
        }
    }
    
    func updateDocument(customerId: UUID, document: DocumentItem) {
        if let cIndex = customers.firstIndex(where: { $0.id == customerId }),
           let dIndex = customers[cIndex].documents.firstIndex(where: { $0.id == document.id }) {
            customers[cIndex].documents[dIndex] = document
            save()
        }
    }
    
    func deleteDocument(customerId: UUID, documentId: UUID) {
        if let cIndex = customers.firstIndex(where: { $0.id == customerId }) {
            customers[cIndex].documents.removeAll { $0.id == documentId }
            save()
        }
    }
    
    func getDocumentDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docDir = documents.appendingPathComponent("CustomerDocuments", isDirectory: true)
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)
        return docDir
    }
    
    func saveFile(data: Data, customerId: UUID, documentType: String, fileName: String) -> String {
        let customerDir = getDocumentDirectory().appendingPathComponent(customerId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: customerDir, withIntermediateDirectories: true)
        let fileURL = customerDir.appendingPathComponent("\(documentType)_\(fileName)")
        try? data.write(to: fileURL)
        return fileURL.path
    }
}
