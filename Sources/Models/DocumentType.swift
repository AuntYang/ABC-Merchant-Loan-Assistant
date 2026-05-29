import Foundation

enum DocumentCategory: String, Codable, CaseIterable {
    case template = "模板表单"
    case customerDoc = "客户资料"
    case spouseDoc = "配偶资料"
    case propertyDoc = "资产资料"
    case authorization = "授权文件"
    case creditReport = "征信报告"
    case businessDoc = "工商资料"
    case incomeDoc = "收入资料"
    case other = "其他"
}

struct DocumentTypeInfo: Identifiable {
    let id: String
    let index: Int
    let name: String
    let category: DocumentCategory
    let requiresOCR: Bool
    let fileType: FileType
    let description: String
    
    enum FileType: String {
        case image = "照片"
        case pdf = "PDF"
        case excel = "Excel"
        case word = "Word"
        case any = "任意"
    }
}

struct DocumentTypeRegistry {
    static let allTypes: [DocumentTypeInfo] = [
        DocumentTypeInfo(id: "cover", index: 1, name: "贷款资料封面", category: .template, requiresOCR: false, fileType: .any, description: "需录入客户姓名、当前日期"),
        DocumentTypeInfo(id: "toc", index: 2, name: "资料清单目录", category: .template, requiresOCR: false, fileType: .any, description: "根据实际录入的资料自动生成"),
        DocumentTypeInfo(id: "identity_table", index: 3, name: "个人客户身份识别和尽职调查信息表", category: .template, requiresOCR: false, fileType: .any, description: "需录入客户及配偶信息"),
        DocumentTypeInfo(id: "business_license", index: 4, name: "营业执照", category: .businessDoc, requiresOCR: true, fileType: .image, description: "提取名称、类型、法定代表人、住所"),
        DocumentTypeInfo(id: "id_card_front", index: 5, name: "身份证-客户(正面)", category: .customerDoc, requiresOCR: true, fileType: .image, description: "客户身份证人像面"),
        DocumentTypeInfo(id: "id_card_back", index: 6, name: "身份证-客户(背面)", category: .customerDoc, requiresOCR: true, fileType: .image, description: "客户身份证国徽面"),
        DocumentTypeInfo(id: "spouse_id_front", index: 7, name: "身份证-配偶(正面)", category: .spouseDoc, requiresOCR: true, fileType: .image, description: "配偶身份证人像面"),
        DocumentTypeInfo(id: "spouse_id_back", index: 8, name: "身份证-配偶(背面)", category: .spouseDoc, requiresOCR: true, fileType: .image, description: "配偶身份证国徽面"),
        DocumentTypeInfo(id: "marriage_cert", index: 9, name: "结婚证/离婚证", category: .customerDoc, requiresOCR: false, fileType: .image, description: "结婚证或离婚证照片"),
        DocumentTypeInfo(id: "household_reg", index: 10, name: "户口本", category: .customerDoc, requiresOCR: false, fileType: .image, description: "户口本照片"),
        DocumentTypeInfo(id: "property_cert", index: 11, name: "房产证明", category: .propertyDoc, requiresOCR: false, fileType: .image, description: "房产证或购房合同"),
        DocumentTypeInfo(id: "lease_contract", index: 12, name: "租赁合同", category: .propertyDoc, requiresOCR: false, fileType: .any, description: "商铺租赁合同"),
        DocumentTypeInfo(id: "asset_cert", index: 13, name: "资产证明", category: .propertyDoc, requiresOCR: false, fileType: .any, description: "其他资产证明文件"),
        DocumentTypeInfo(id: "inventory_cert", index: 14, name: "存货证明", category: .propertyDoc, requiresOCR: false, fileType: .image, description: "存货照片或证明"),
        DocumentTypeInfo(id: "sunshine_letter_customer", index: 15, name: "个人贷款"阳光办贷"告知函-客户", category: .authorization, requiresOCR: false, fileType: .pdf, description: "客户签署"),
        DocumentTypeInfo(id: "integrity_letter_customer", index: 16, name: ""清廉办贷"告知函-客户", category: .authorization, requiresOCR: false, fileType: .pdf, description: "客户签署"),
        DocumentTypeInfo(id: "credit_auth_customer", index: 17, name: "个人征信业务授权书-客户", category: .authorization, requiresOCR: false, fileType: .pdf, description: "客户签署"),
        DocumentTypeInfo(id: "info_auth_customer", index: 18, name: "信息查询授权书-客户", category: .authorization, requiresOCR: false, fileType: .pdf, description: "客户签署"),
        DocumentTypeInfo(id: "risk_notice_customer", index: 19, name: "风险提示-客户", category: .authorization, requiresOCR: false, fileType: .pdf, description: "客户签署"),
        DocumentTypeInfo(id: "sunshine_letter_spouse", index: 20, name: "个人贷款"阳光办贷"告知函-配偶", category: .authorization, requiresOCR: false, fileType: .pdf, description: "配偶签署"),
        DocumentTypeInfo(id: "integrity_letter_spouse", index: 21, name: ""清廉办贷"告知函-配偶", category: .authorization, requiresOCR: false, fileType: .pdf, description: "配偶签署"),
        DocumentTypeInfo(id: "credit_auth_spouse", index: 22, name: "个人征信业务授权书-配偶", category: .authorization, requiresOCR: false, fileType: .pdf, description: "配偶签署"),
        DocumentTypeInfo(id: "info_auth_spouse", index: 23, name: "信息查询授权书-配偶", category: .authorization, requiresOCR: false, fileType: .pdf, description: "配偶签署"),
        DocumentTypeInfo(id: "risk_notice_spouse", index: 24, name: "风险提示-配偶", category: .authorization, requiresOCR: false, fileType: .pdf, description: "配偶签署"),
        DocumentTypeInfo(id: "credit_report_customer", index: 25, name: "征信报告-客户", category: .creditReport, requiresOCR: false, fileType: .pdf, description: "客户征信报告PDF"),
        DocumentTypeInfo(id: "credit_report_spouse", index: 26, name: "征信报告-配偶", category: .creditReport, requiresOCR: false, fileType: .pdf, description: "配偶征信报告PDF"),
        DocumentTypeInfo(id: "survey_photo", index: 27, name: "上门调查照片", category: .businessDoc, requiresOCR: false, fileType: .image, description: "上门调查拍摄的照片"),
        DocumentTypeInfo(id: "business_query", index: 28, name: "外部工商信息查询图片", category: .businessDoc, requiresOCR: false, fileType: .image, description: "工商信息查询截图"),
        DocumentTypeInfo(id: "dishonesty_query", index: 29, name: "失信被执行人查询图片", category: .businessDoc, requiresOCR: false, fileType: .image, description: "失信被执行人查询截图"),
        DocumentTypeInfo(id: "income_table", index: 30, name: "经营收入认定表", category: .incomeDoc, requiresOCR: false, fileType: .any, description: "经营收入认定表"),
        DocumentTypeInfo(id: "income_overview", index: 31, name: "收入流水总览截图", category: .incomeDoc, requiresOCR: false, fileType: .image, description: "收入流水总览截图"),
        DocumentTypeInfo(id: "income_pdf", index: 32, name: "流水PDF文件", category: .incomeDoc, requiresOCR: false, fileType: .pdf, description: "银行流水PDF文件")
    ]
    
    static func getType(byId id: String) -> DocumentTypeInfo? {
        allTypes.first { $0.id == id }
    }
    
    static func getTypes(forCategory category: DocumentCategory) -> [DocumentTypeInfo] {
        allTypes.filter { $0.category == category }
    }
}
