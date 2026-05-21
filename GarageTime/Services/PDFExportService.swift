import Foundation
#if canImport(UIKit)
import UIKit
import PDFKit
#endif

/// Output type discriminator for `PDFExportService.export(...)`.
/// Marked `@unchecked Sendable` because the SwiftData `@Model` payload is read on
/// `@MainActor` only; the enum is never transferred across actor boundaries.
enum PDFExportKind: @unchecked Sendable {
    case vehicleHistory(Vehicle, dateRange: ClosedRange<Date>?, includeReceipts: Bool)
    case quote(Quote)
    case customerFile(Customer)
}

protocol PDFExporting: Sendable {
    /// Generates PDF data. Heavy work; call from a background task.
    @MainActor func export(_ kind: PDFExportKind, shop: ShopSettings) -> Data
}

struct RealPDFExportService: PDFExporting {

    // US Letter @ 72 DPI
    private let pageSize = CGSize(width: 612, height: 792)
    private let margin: CGFloat = 36

    @MainActor func export(_ kind: PDFExportKind, shop: ShopSettings) -> Data {
        #if canImport(UIKit)
        let format = UIGraphicsPDFRendererFormat()
        let info: [String: Any] = [
            kCGPDFContextCreator as String: "Garage Time",
            kCGPDFContextAuthor as String: shop.businessName.isEmpty ? "Garage Time" : shop.businessName,
            kCGPDFContextTitle as String: title(for: kind),
        ]
        format.documentInfo = info
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var cursor = drawHeader(in: ctx.cgContext, shop: shop, title: title(for: kind))
            cursor += 8

            switch kind {
            case .vehicleHistory(let vehicle, let range, let includeReceipts):
                cursor = drawVehicleHistory(vehicle, dateRange: range, includeReceipts: includeReceipts, cursor: cursor, ctx: ctx)
            case .quote(let quote):
                cursor = drawQuote(quote, shop: shop, cursor: cursor, ctx: ctx)
            case .customerFile(let customer):
                cursor = drawCustomerFile(customer, cursor: cursor, ctx: ctx)
            }

            drawFooter(in: ctx.cgContext, shop: shop, kind: kind)
        }
        #else
        return Data()
        #endif
    }

    private func title(for kind: PDFExportKind) -> String {
        switch kind {
        case .vehicleHistory(let v, _, _): return "Service History — \(v.displayTitle)"
        case .quote(let q):                return "Quote \(q.quoteNumber)"
        case .customerFile(let c):         return "Customer File — \(c.displayName)"
        }
    }

    // MARK: - Header / footer

    #if canImport(UIKit)
    private func drawHeader(in ctx: CGContext, shop: ShopSettings, title: String) -> CGFloat {
        // Logo (if any)
        var cursorX: CGFloat = margin
        if let data = shop.logoData, let image = UIImage(data: data) {
            let logoSize: CGFloat = 56
            image.draw(in: CGRect(x: cursorX, y: margin, width: logoSize, height: logoSize))
            cursorX += logoSize + 12
        }

        // Shop block (right of logo)
        let shopHeader = NSMutableAttributedString()
        if !shop.businessName.isEmpty {
            shopHeader.append(NSAttributedString(
                string: shop.businessName + "\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: UIColor.black,
                ]
            ))
        }
        let smallDetails = [
            [shop.addressLine1, shop.addressLine2].filter { !$0.isEmpty }.joined(separator: " "),
            shop.cityStateZip,
            shop.phone,
            shop.email,
        ].filter { !$0.isEmpty }.joined(separator: " · ")
        shopHeader.append(NSAttributedString(
            string: smallDetails,
            attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]
        ))

        let headerWidth = pageSize.width - margin - cursorX - margin
        shopHeader.draw(in: CGRect(x: cursorX, y: margin, width: headerWidth, height: 60))

        // Title bar
        let titleY: CGFloat = margin + 64
        let titleString = NSAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black,
        ])
        titleString.draw(at: CGPoint(x: margin, y: titleY))

        // Rule below header
        ctx.setStrokeColor(UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: margin, y: titleY + 30))
        ctx.addLine(to: CGPoint(x: pageSize.width - margin, y: titleY + 30))
        ctx.strokePath()

        return titleY + 36
    }

    private func drawFooter(in ctx: CGContext, shop: ShopSettings, kind: PDFExportKind) {
        let y = pageSize.height - 28
        ctx.setStrokeColor(UIColor.lightGray.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        ctx.strokePath()

        let df = DateFormatter()
        df.dateStyle = .medium
        let footer = NSAttributedString(
            string: "Generated by Garage Time · \(df.string(from: Date()))",
            attributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]
        )
        footer.draw(at: CGPoint(x: margin, y: y + 6))
    }

    // MARK: - Vehicle history

    private func drawVehicleHistory(_ vehicle: Vehicle,
                                    dateRange: ClosedRange<Date>?,
                                    includeReceipts: Bool,
                                    cursor: CGFloat,
                                    ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = cursor

        // Vehicle block
        let info = [
            ("Vehicle", "\(vehicle.year > 0 ? "\(vehicle.year) " : "")\(vehicle.make) \(vehicle.model) \(vehicle.trim)".trimmingCharacters(in: .whitespaces)),
            ("VIN", vehicle.vin),
            ("Plate", vehicle.licensePlate),
            ("Mileage", "\(vehicle.currentMileage) \(vehicle.mileageUnit.rawValue)"),
        ].filter { !$0.1.isEmpty }
        y = drawKeyValueGrid(info, y: y, columns: 2)
        y += 12

        // Service records
        let records = (vehicle.serviceRecords ?? []).sorted { $0.date > $1.date }.filter {
            if let range = dateRange {
                return range.contains($0.date)
            }
            return true
        }

        if records.isEmpty {
            drawText("No service records in range.", at: CGPoint(x: margin, y: y),
                     font: .systemFont(ofSize: 12), color: .darkGray)
            return y + 18
        }

        // Table header
        let df = DateFormatter(); df.dateStyle = .medium
        y = drawTableHeader(["Date", "Mileage", "Service", "Cost"], widths: [80, 70, 270, 80], y: y)
        y += 4

        for record in records {
            if y > pageSize.height - 80 {
                ctx.beginPage()
                y = margin
            }
            y = drawTableRow(
                [
                    df.string(from: record.date),
                    "\(record.mileageAtService)",
                    "\(record.category.displayName) — \(record.title.isEmpty ? "" : record.title)",
                    Money.format(record.totalCost),
                ],
                widths: [80, 70, 270, 80],
                y: y
            )
        }
        return y
    }

    // MARK: - Quote PDF

    private func drawQuote(_ quote: Quote,
                           shop: ShopSettings,
                           cursor: CGFloat,
                           ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = cursor

        // Customer / vehicle / quote meta
        let df = DateFormatter(); df.dateStyle = .medium
        let leftBlock = [
            ("Bill to", quote.customer?.displayName ?? "—"),
            ("Vehicle", quote.vehicle?.displayTitle ?? "—"),
            ("VIN", quote.vehicle?.vin ?? ""),
        ]
        let rightBlock = [
            ("Quote #", quote.quoteNumber),
            ("Issued", df.string(from: quote.issueDate)),
            ("Valid through", df.string(from: quote.expiryDate)),
            ("Status", quote.status.displayName),
        ]
        let halfWidth = (pageSize.width - 2 * margin) / 2
        drawKeyValueGrid(leftBlock, y: y, columns: 1, x: margin, width: halfWidth)
        drawKeyValueGrid(rightBlock, y: y, columns: 1, x: margin + halfWidth, width: halfWidth)
        y += CGFloat(max(leftBlock.count, rightBlock.count)) * 18 + 12

        // Line items
        y = drawTableHeader(["Type", "Description", "Qty", "Unit", "Total"], widths: [56, 280, 50, 70, 80], y: y)
        for item in quote.sortedLineItems {
            if y > pageSize.height - 200 {
                ctx.beginPage()
                y = margin
            }
            let qty = String(format: "%g", item.type == .labor ? (item.hours ?? item.quantity) : item.quantity)
            let unit = Money.format(item.type == .labor ? (item.laborRate ?? item.unitPrice) : item.unitPrice)
            y = drawTableRow(
                [item.type.displayName, item.itemDescription, qty, unit, Money.format(item.lineTotal)],
                widths: [56, 280, 50, 70, 80],
                y: y
            )
        }
        y += 12

        // Totals
        let totalsX = pageSize.width - margin - 220
        y = drawTotalRow("Subtotal labor", value: Money.format(quote.subtotalLabor), x: totalsX, y: y)
        y = drawTotalRow("Subtotal parts", value: Money.format(quote.subtotalParts), x: totalsX, y: y)
        if quote.subtotalFees > 0 {
            y = drawTotalRow("Fees", value: Money.format(quote.subtotalFees), x: totalsX, y: y)
        }
        if quote.discountAmount > 0 {
            y = drawTotalRow("Discount", value: "-" + Money.format(quote.discountAmount), x: totalsX, y: y)
        }
        if quote.taxAmount > 0 {
            y = drawTotalRow("Tax", value: Money.format(quote.taxAmount), x: totalsX, y: y)
        }
        y = drawTotalRow("TOTAL", value: Money.format(quote.total), x: totalsX, y: y, bold: true)
        y += 20

        // Notes
        if !quote.customerNotes.isEmpty {
            y = drawSectionTitle("Notes", y: y)
            y = drawBody(quote.customerNotes, y: y)
            y += 8
        }

        if !shop.quoteTerms.isEmpty {
            y = drawSectionTitle("Terms", y: y)
            y = drawBody(shop.quoteTerms, y: y, font: .systemFont(ofSize: 9), color: .darkGray)
            y += 8
        }

        if !shop.paymentInstructions.isEmpty {
            y = drawSectionTitle("Payment", y: y)
            y = drawBody(shop.paymentInstructions, y: y, font: .systemFont(ofSize: 9), color: .darkGray)
        }

        // Signature block (always shown; image only if present)
        drawSignatureBlock(quote: quote)

        return y
    }

    private func drawSignatureBlock(quote: Quote) {
        let sigY = pageSize.height - 160
        let sigWidth: CGFloat = 260
        let sigHeight: CGFloat = 70

        // "Customer signature" label
        ("CUSTOMER SIGNATURE" as NSString).draw(at: CGPoint(x: margin, y: sigY - 14),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: UIColor.darkGray,
            ])

        // Signature image (if signed)
        if let signature = quote.signaturePngData, let image = UIImage(data: signature) {
            // Draw centered in the box, preserving aspect ratio.
            let aspect = image.size.width / max(image.size.height, 1)
            var drawW = sigWidth
            var drawH = drawW / aspect
            if drawH > sigHeight {
                drawH = sigHeight
                drawW = drawH * aspect
            }
            let drawX = margin + (sigWidth - drawW) / 2
            let drawY = sigY + (sigHeight - drawH) / 2
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
        }

        // Signature line under the image
        if let ctx = UIGraphicsGetCurrentContext() {
            ctx.setStrokeColor(UIColor.darkGray.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: margin, y: sigY + sigHeight))
            ctx.addLine(to: CGPoint(x: margin + sigWidth, y: sigY + sigHeight))
            ctx.strokePath()
        }

        // Name + date below the line
        let name = quote.signedByName.isEmpty ? "____________________" : quote.signedByName
        drawText("Signed by: \(name)",
                 at: CGPoint(x: margin, y: sigY + sigHeight + 4),
                 font: .systemFont(ofSize: 9, weight: .medium), color: .black)
        if let when = quote.signedAt {
            let dateString = DateFormatter.localizedString(from: when, dateStyle: .medium, timeStyle: .short)
            drawText("Date: \(dateString)",
                     at: CGPoint(x: margin, y: sigY + sigHeight + 16),
                     font: .systemFont(ofSize: 9), color: .darkGray)
        } else {
            drawText("Date: ____________________",
                     at: CGPoint(x: margin, y: sigY + sigHeight + 16),
                     font: .systemFont(ofSize: 9), color: .darkGray)
        }
    }

    // MARK: - Customer file

    private func drawCustomerFile(_ customer: Customer,
                                  cursor: CGFloat,
                                  ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = cursor

        let pairs = [
            ("Customer", customer.displayName),
            ("Email", customer.email),
            ("Phone", customer.phone),
            ("Address", customer.formattedAddress.replacingOccurrences(of: "\n", with: ", ")),
        ].filter { !$0.1.isEmpty }
        y = drawKeyValueGrid(pairs, y: y, columns: 2)
        y += 14

        for vehicle in (customer.vehicles ?? []) {
            if y > pageSize.height - 200 {
                ctx.beginPage()
                y = margin
            }
            y = drawSectionTitle(vehicle.displayTitle, y: y)
            y = drawVehicleHistory(vehicle, dateRange: nil, includeReceipts: false, cursor: y, ctx: ctx)
            y += 18
        }
        return y
    }

    // MARK: - Drawing primitives

    @discardableResult
    private func drawText(_ string: String, at point: CGPoint,
                          font: UIFont = .systemFont(ofSize: 11),
                          color: UIColor = .black,
                          width: CGFloat? = nil) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let width {
            let attr = NSAttributedString(string: string, attributes: attrs)
            let rect = CGRect(x: point.x, y: point.y, width: width, height: .greatestFiniteMagnitude)
            let bounding = attr.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], context: nil)
            attr.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
            return point.y + bounding.height
        } else {
            (string as NSString).draw(at: point, withAttributes: attrs)
            return point.y + font.lineHeight
        }
    }

    @discardableResult
    private func drawKeyValueGrid(_ pairs: [(String, String)],
                                  y: CGFloat,
                                  columns: Int,
                                  x: CGFloat? = nil,
                                  width: CGFloat? = nil) -> CGFloat {
        let originX = x ?? margin
        let totalWidth = width ?? (pageSize.width - 2 * margin)
        let colWidth = totalWidth / CGFloat(columns)
        let rowHeight: CGFloat = 18

        var maxY = y
        for (index, pair) in pairs.enumerated() {
            let col = index % columns
            let row = index / columns
            let cellX = originX + CGFloat(col) * colWidth
            let cellY = y + CGFloat(row) * rowHeight

            let key = NSAttributedString(string: pair.0.uppercased(), attributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: UIColor.gray,
            ])
            let value = NSAttributedString(string: pair.1, attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black,
            ])
            key.draw(at: CGPoint(x: cellX, y: cellY))
            value.draw(at: CGPoint(x: cellX, y: cellY + 9))
            maxY = max(maxY, cellY + rowHeight)
        }
        return maxY
    }

    @discardableResult
    private func drawTableHeader(_ titles: [String], widths: [CGFloat], y: CGFloat) -> CGFloat {
        var x = margin
        for (title, width) in zip(titles, widths) {
            (title.uppercased() as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: UIColor.gray,
            ])
            x += width
        }
        // Underline
        UIColor.lightGray.setStroke()
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setLineWidth(0.5)
        ctx?.move(to: CGPoint(x: margin, y: y + 12))
        ctx?.addLine(to: CGPoint(x: margin + widths.reduce(0, +), y: y + 12))
        ctx?.strokePath()
        return y + 16
    }

    @discardableResult
    private func drawTableRow(_ values: [String], widths: [CGFloat], y: CGFloat) -> CGFloat {
        var x = margin
        let baseFont = UIFont.systemFont(ofSize: 10)
        var rowHeight: CGFloat = 14
        for (value, width) in zip(values, widths) {
            let attr = NSAttributedString(string: value, attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.black,
            ])
            let rect = CGRect(x: x, y: y, width: width - 6, height: .greatestFiniteMagnitude)
            let bounding = attr.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], context: nil)
            attr.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
            rowHeight = max(rowHeight, bounding.height + 4)
            x += width
        }
        // Row separator
        UIColor.lightGray.withAlphaComponent(0.3).setStroke()
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setLineWidth(0.25)
        ctx?.move(to: CGPoint(x: margin, y: y + rowHeight))
        ctx?.addLine(to: CGPoint(x: margin + widths.reduce(0, +), y: y + rowHeight))
        ctx?.strokePath()
        return y + rowHeight + 2
    }

    @discardableResult
    private func drawTotalRow(_ label: String, value: String, x: CGFloat, y: CGFloat, bold: Bool = false) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: bold ? 12 : 10, weight: bold ? .bold : .regular)
        let valueFont = UIFont.systemFont(ofSize: bold ? 13 : 11, weight: bold ? .bold : .regular)
        (label as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
            .font: labelFont,
            .foregroundColor: UIColor.black,
        ])
        let valueAttr = NSAttributedString(string: value, attributes: [
            .font: valueFont,
            .foregroundColor: UIColor.black,
        ])
        let valueWidth = valueAttr.size().width
        valueAttr.draw(at: CGPoint(x: pageSize.width - margin - valueWidth, y: y))
        return y + (bold ? 22 : 18)
    }

    @discardableResult
    private func drawSectionTitle(_ title: String, y: CGFloat) -> CGFloat {
        (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black,
        ])
        return y + 18
    }

    @discardableResult
    private func drawBody(_ text: String, y: CGFloat,
                          font: UIFont = .systemFont(ofSize: 10),
                          color: UIColor = .black) -> CGFloat {
        drawText(text, at: CGPoint(x: margin, y: y),
                 font: font, color: color,
                 width: pageSize.width - 2 * margin)
    }
    #endif
}

final class InMemoryPDFExportService: PDFExporting, @unchecked Sendable {
    var fixedOutput: Data = Data()
    @MainActor func export(_ kind: PDFExportKind, shop: ShopSettings) -> Data { fixedOutput }
}
