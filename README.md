# ABC商户贷助手

ABC商户贷助手是一款专为银行客户经理设计的iOS应用，用于协助完成商户贷款的资料收集、录入、整理工作。

## 功能特性

- **客户管理**：创建、编辑、删除客户信息
- **证件OCR识别**：自动识别身份证、营业执照信息
- **资料导入**：支持拍照、相册、文件多种导入方式
- **资料整理**：30+类贷款资料的分类管理
- **PDF生成**：一键生成完整的贷款资料PDF包
- **离线使用**：所有功能无需网络连接

## 安装方法

1. 从 GitHub Releases 下载最新的 `ABC商户贷助手.ipa` 文件
2. 使用 [Sideloadly](https://sideloadly.io/) 或 [AltStore](https://altstore.io/) 安装到 iPhone

## 资料清单

应用支持以下资料的管理：
1. 贷款资料封面
2. 资料清单目录
3. 个人客户身份识别和尽职调查信息表
4. 营业执照
5. 身份证-客户/配偶
6. 结婚证/离婚证
7. 户口本
8. 房产证明
9. 租赁合同
10. 各类授权文件
11. 征信报告
12. 经营收入材料
13. 以及更多...

## 技术栈

- Swift 5.9
- SwiftUI
- Vision (OCR)
- PDFKit
- iOS 16.0+

## 开发

使用 XcodeGen 生成项目文件：
```bash
brew install xcodegen
xcodegen generate
open ABCMerchantLoan.xcodeproj
```

## 构建

项目通过 GitHub Actions 自动构建。推送代码到 `main` 分支将自动触发构建并生成 IPA 文件。
