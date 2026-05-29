import SwiftUI

struct ContentView: View {
    @StateObject private var dataStore = DataStore.shared
    
    var body: some View {
        TabView {
            CustomerListView()
                .tabItem {
                    Label("客户管理", systemImage: "person.3.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
        .environmentObject(dataStore)
    }
}

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("应用信息")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("客户数量")
                        Spacer()
                        Text("\(dataStore.customers.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("数据管理")) {
                    Button("导出所有数据") {
                        exportData()
                    }
                    
                    Button("清除所有数据", role: .destructive) {
                    }
                }
                
                Section(header: Text("关于")) {
                    Text("ABC商户贷助手")
                        .font(.headline)
                    Text("协助客户经理完成商户贷款的资料收集、录入、整理等工作")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
    
    func exportData() {
    }
}
