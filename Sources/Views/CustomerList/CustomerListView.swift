import SwiftUI

struct CustomerListView: View {
    @StateObject private var viewModel = CustomerViewModel()
    @State private var showingCreateView = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.filteredCustomers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无客户")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("点击右上角 + 创建新客户")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(viewModel.filteredCustomers) { customer in
                            NavigationLink(destination: CustomerDetailView(customer: customer)) {
                                CustomerRowView(customer: customer)
                            }
                        }
                        .onDelete { offsets in
                            let sortedCustomers = viewModel.filteredCustomers
                            for index in offsets {
                                let customer = sortedCustomers[index]
                                if let realIndex = viewModel.customers.firstIndex(where: { $0.id == customer.id }) {
                                    viewModel.customers.remove(at: realIndex)
                                }
                            }
                            DataStore.shared.save()
                        }
                    }
                    .searchable(text: $searchText, prompt: "搜索客户姓名或电话")
                }
            }
            .navigationTitle("客户管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateView = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateView) {
                CustomerCreateView()
            }
            .onChange(of: searchText) { newValue in
                viewModel.searchText = newValue
            }
        }
    }
}

struct CustomerRowView: View {
    let customer: Customer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(customer.name.isEmpty ? "未命名客户" : customer.name)
                    .font(.headline)
                Spacer()
                Text("\(customer.documents.count)份资料")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !customer.phone.isEmpty {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(customer.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(Validator.formatShortDate(customer.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let completionPercentage = calculateCompletion(customer: customer)
                Text("完成 \(Int(completionPercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(completionPercentage > 0.5 ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    func calculateCompletion(customer: Customer) -> Double {
        let total = DocumentTypeRegistry.allTypes.count
        let completed = customer.documents.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }
}
