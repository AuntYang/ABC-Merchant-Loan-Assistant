import Foundation
import Combine

class CustomerViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var searchText: String = ""
    
    private let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        dataStore.$customers
            .assign(to: &$customers)
    }
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customers.sorted { $0.createdAt > $1.createdAt }
        }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.contains(searchText)
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func addCustomer(_ customer: Customer) {
        dataStore.addCustomer(customer)
    }
    
    func updateCustomer(_ customer: Customer) {
        dataStore.updateCustomer(customer)
    }
    
    func deleteCustomer(at offsets: IndexSet) {
        let sortedCustomers = filteredCustomers
        for index in offsets {
            let customer = sortedCustomers[index]
            if let realIndex = dataStore.customers.firstIndex(where: { $0.id == customer.id }) {
                dataStore.customers.remove(at: realIndex)
            }
        }
        dataStore.save()
    }
    
    func getCustomer(byId id: UUID) -> Customer? {
        dataStore.customers.first { $0.id == id }
    }
}
