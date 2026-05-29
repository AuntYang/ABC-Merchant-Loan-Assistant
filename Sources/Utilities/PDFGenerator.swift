import UIKit
import PDFKit

struct PDFGenerator {
    static func generateCoverPage(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            let titleFont = UIFont.boldSystemFont(ofSize: 28)
            let subtitleFont = UIFont.systemFont(ofSize: 18)
            let infoFont = UIFont.systemFont(ofSize: 16)
            
            let title = "商户贷款资料" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 200), withAttributes: [.font: titleFont])
            
            let subtitle = "封面" as NSString
            let subtitleSize = subtitle.size(withAttributes: [.font: subtitleFont])
            subtitle.draw(at: CGPoint(x: (pageRect.width - subtitleSize.width) / 2, y: 250), withAttributes: [.font: subtitleFont])
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月dd日"
            dateFormatter.locale = Locale(identifier: "zh_CN")
            
            let infoLines = [
                "客户姓名：\(customer.name)",
                "建档日期：\(dateFormatter.string(from: customer.createdAt))"
            ]
            
            var y: CGFloat = 350
            for line in infoLines {
                let nsLine = line as NSString
                nsLine.draw(at: CGPoint(x: 100, y: y), withAttributes: [.font: infoFont])
                y += 40
            }
        }
    }
    
    static func generateTOC(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let itemFont = UIFont.systemFont(ofSize: 13)
            let checkFont = UIFont.systemFont(ofSize: 12)
            
            let title = "资料清单目录" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 50), withAttributes: [.font: titleFont])
            
            let customerInfo = "客户：\(customer.name)" as NSString
            customerInfo.draw(at: CGPoint(x: 50, y: 90), withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
            
            var y: CGFloat = 130
            for docType in DocumentTypeRegistry.allTypes {
                let hasDoc = customer.documents.contains { $0.documentType == docType.id }
                let checkmark = hasDoc ? "☑" : "☐"
                let line = "\(checkmark) \(docType.index). \(docType.name)"
                let nsLine = line as NSString
                nsLine.draw(at: CGPoint(x: 50, y: y), withAttributes: [
                    .font: checkFont,
                    .foregroundColor: hasDoc ? UIColor.black : UIColor.gray
                ])
                y += 22
                
                if y > 780 {
                    context.beginPage()
                    y = 50
                }
            }
        }
    }
    
    static func generateIdentityTable(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let headerFont = UIFont.boldSystemFont(ofSize: 12)
            let cellFont = UIFont.systemFont(ofSize: 11)
            
            let title = "个人客户身份识别和尽职调查信息表" as NSString
            let titleSize = title.size(withAttributes: [.font: titleFont])
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: 40), withAttributes: [.font: titleFont])
            
            let tableData: [(String, String, String, String)] = [
                ("客户姓名", customer.name, "配偶姓名", customer.spouseName),
                ("客户性别", customer.gender, "配偶性别", customer.spouseGender),
                ("身份证号", customer.idNumber, "配偶身份证号", customer.spouseIdNumber),
                ("证件有效期", customer.idExpiry, "配偶证件有效期", customer.spouseIdExpiry),
                ("联系电话", customer.phone, "配偶电话", customer.spousePhone),
                ("现住址", customer.address, "", ""),
                ("营业执照类型", customer.businessLicenseType, "", "")
            ]
            
            var y: CGFloat = 90
            let col1X: CGFloat = 40
            let col2X: CGFloat = 160
            let col3X: CGFloat = 320
            let col4X: CGFloat = 440
            let rowHeight: CGFloat = 35
            let col1Width: CGFloat = 120
            let col2Width: CGFloat = 160
            
            for (header1, value1, header2, value2) in tableData {
                let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.darkGray]
                let valueAttrs: [NSAttributedString.Key: Any] = [.font: cellFont]
                
                (header1 as NSString).draw(at: CGPoint(x: col1X, y: y + 10), withAttributes: headerAttrs)
                (value1 as NSString).draw(at: CGPoint(x: col2X, y: y + 10), withAttributes: valueAttrs)
                
                if !header2.isEmpty {
                    (header2 as NSString).draw(at: CGPoint(x: col3X, y: y + 10), withAttributes: headerAttrs)
                    (value2 as NSString).draw(at: CGPoint(x: col4X, y: y + 10), withAttributes: valueAttrs)
                }
                
                let path = UIBezierPath()
                path.move(to: CGPoint(x: col1X, y: y + rowHeight))
                path.addLine(to: CGPoint(x: 555, y: y + rowHeight))
                UIColor.lightGray.setStroke()
                path.stroke()
                
                y += rowHeight
            }
        }
    }
    
    static func generateFullPDF(customer: Customer) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            if let coverData = generateCoverPage(customer: customer),
               let coverPage = PDFDocument(data: coverData) {
                for i in 0..<(coverPage.pageCount) {
                    if let page = coverPage.page(at: i) {
                        context.beginPage()
                        page.draw(with: .mediaBox, to: context.cgContext)
                    }
                }
            }
            
            if let tocData = generateTOC(customer: customer),
               let tocPage = PDFDocument(data: tocData) {
                for i in 0..<(tocPage.pageCount) {
                    if let page = tocPage.page(at: i) {
                        context.beginPage()
                        page.draw(with: .mediaBox, to: context.cgContext)
                    }
                }
            }
            
            if let tableData = generateIdentityTable(customer: customer),
               let tablePage = PDFDocument(data: tableData) {
                for i in 0..<(tablePage.pageCount) {
                    if let page = tablePage.page(at: i) {
                        context.beginPage()
                        page.draw(with: .mediaBox, to: context.cgContext)
                    }
                }
            }
        }
    }
}
