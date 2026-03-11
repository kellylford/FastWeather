//
//  AccessibleTableBridge.swift
//  Fast Weather
//
//  UIKit bridge that gives VoiceOver proper data-table navigation.
//
//  Based on the production implementation documented in:
//  /Users/kellyford/Documents/GitHub/Scores/TheBench/ACCESSIBLE_TABLES_IOS.md
//
//  Additions beyond the TheBench original:
//    • DataTableCellElement.onActivate / accessibilityActivate() — lets row-header
//      cells respond to VoiceOver double-tap (e.g. navigate to city detail).
//    • AccessibleDataTableView.rowActivationHandlers — array of per-row closures
//      wired to the row-header element of each data row.
//    • AccessibleDataTable.rowActivationHandlers — exposed through the SwiftUI bridge.
//    • updateUIView guard removed — ensures rebuild() runs on every SwiftUI update,
//      which is required for scroll-offset tracking to keep focus frames accurate.
//
//  Key protocol hooks (all from UIAccessibilityContainerDataTable, iOS 11+):
//    • accessibilityHeaderElements(forColumn:) — column header for each col
//    • accessibilityHeaderElements(forRow:)    — row header (col-0) for each data row;
//                                               the hook that makes VoiceOver read the
//                                               row label as persistent context
//    • accessibilityDataTableCellElement(forRow:column:) — individual cell elements
//
//  Usage (overlay the visual SwiftUI table, which is .accessibilityHidden(true)):
//
//      visualTableVStack
//          .accessibilityHidden(true)
//          .overlay(
//              AccessibleDataTable(headers: headers, rows: rows)
//                  .allowsHitTesting(false)
//          )
//

import SwiftUI
import UIKit

// MARK: - Cell element

/// A single logical cell in the accessibility table.
/// Implements UIAccessibilityContainerDataTableCell so VoiceOver can
/// announce the cell's position ("row 2, column 3 of 6").
final class DataTableCellElement: UIAccessibilityElement,
                                  UIAccessibilityContainerDataTableCell {
    private let _row: Int
    private let _col: Int

    /// Set on row-header cells (col 0 of each data row) to respond to
    /// VoiceOver double-tap (activation). Return true if handled.
    var onActivate: (() -> Bool)?

    init(container: AccessibleDataTableView,
         label: String,
         traits: UIAccessibilityTraits = .none,
         row: Int,
         col: Int) {
        self._row = row
        self._col = col
        super.init(accessibilityContainer: container)
        accessibilityLabel = label
        accessibilityTraits = traits
    }

    @objc func accessibilityRowRange() -> NSRange {
        NSRange(location: _row, length: 1)
    }

    @objc func accessibilityColumnRange() -> NSRange {
        NSRange(location: _col, length: 1)
    }

    override func accessibilityActivate() -> Bool {
        onActivate?() ?? super.accessibilityActivate()
    }
}

// MARK: - Container view

/// An invisible UIKit view whose sole purpose is to expose a proper
/// UIAccessibilityContainerDataTable tree to VoiceOver.
/// Set allowsHitTesting(false) in SwiftUI so touches pass through.
final class AccessibleDataTableView: UIView,
                                     UIAccessibilityContainerDataTable {

    // MARK: Public inputs
    var columnHeaders: [String] = [] { didSet { rebuild() } }
    var dataRows: [[String]] = []    { didSet { rebuild() } }

    /// Per-row activation handlers for row-header cells (col 0 of each data row).
    /// Index 0 = first data row. VoiceOver calls the handler when the user
    /// double-taps a city name cell, e.g. to navigate to city detail.
    var rowActivationHandlers: [() -> Bool] = [] { didSet { rebuild() } }

    // MARK: Private state
    private var headerElements: [DataTableCellElement] = []
    private var rowElements:    [[DataTableCellElement]] = []

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityContainerType = .dataTable   // REQUIRED — without this, nothing works
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuild()
    }

    // MARK: Build elements

    private func rebuild() {
        guard !columnHeaders.isEmpty else {
            headerElements = []
            rowElements    = []
            return
        }

        let ncols = columnHeaders.count
        let nrows = dataRows.count

        // Divide the view bounds into a logical grid for focus-rectangle placement.
        // Column 0 (row-header column) gets 40% of width; remaining columns split equally.
        let totalW    = max(1, bounds.width)
        let totalH    = max(1, bounds.height)
        let col0W     = totalW * 0.40
        let otherColW = ncols > 1 ? (totalW - col0W) / CGFloat(ncols - 1) : 0
        let rowH      = totalH / CGFloat(nrows + 1)  // +1 for the column-header row

        func xOffset(col: Int) -> CGFloat {
            col == 0 ? 0 : col0W + CGFloat(col - 1) * otherColW
        }
        func colWidth(col: Int) -> CGFloat {
            col == 0 ? col0W : otherColW
        }
        func screenFrame(row: Int, col: Int) -> CGRect {
            let local = CGRect(x: xOffset(col: col),
                               y: CGFloat(row) * rowH,
                               width: colWidth(col: col),
                               height: rowH)
            return UIAccessibility.convertToScreenCoordinates(local, in: self)
        }

        // Column header row (accessibility row 0).
        // .header trait = VoiceOver announces "header" and reads this cell
        // as context when the user navigates down a column.
        headerElements = columnHeaders.enumerated().map { col, title in
            let el = DataTableCellElement(container: self, label: title,
                                          traits: .header, row: 0, col: col)
            el.accessibilityFrame = screenFrame(row: 0, col: col)
            return el
        }

        // Data rows (accessibility rows 1…n).
        // Column-0 cells are the row headers. They use .staticText traits —
        // NOT .header, which would make VoiceOver say "heading" and break
        // table navigation. Their role as row headers is communicated entirely
        // through accessibilityHeaderElements(forRow:) below.
        rowElements = dataRows.enumerated().map { row, cols in
            cols.enumerated().map { col, label in
                let el = DataTableCellElement(container: self, label: label,
                                              traits: .staticText,
                                              row: row + 1, col: col)
                el.accessibilityFrame = screenFrame(row: row + 1, col: col)
                // Wire row-header cells to their navigation/activation handler.
                if col == 0 && row < rowActivationHandlers.count {
                    el.onActivate = rowActivationHandlers[row]
                }
                return el
            }
        }
    }

    // MARK: UIAccessibilityContainerDataTable

    @objc func accessibilityRowCount() -> Int {
        dataRows.count + 1  // data rows + column-header row
    }

    @objc func accessibilityColumnCount() -> Int {
        columnHeaders.count
    }

    /// Column header for each column.
    /// VoiceOver calls this when the user navigates down a column so it can
    /// announce "Temperature" (or "Wind Speed") as persistent context.
    @objc func accessibilityHeaderElements(forColumn column: Int) -> [Any]? {
        guard column < headerElements.count else { return nil }
        return [headerElements[column]]
    }

    /// Row header for each data row — the column-0 cell (city name).
    /// THIS IS THE METHOD ALMOST EVERYONE OMITS.
    /// It is the direct equivalent of <th scope="row"> in HTML.
    /// VoiceOver calls this when the user navigates across a row so it can
    /// announce "San Diego" as persistent context for every data cell in that
    /// row — without the app having to stuff the city name into every cell label.
    @objc func accessibilityHeaderElements(forRow row: Int) -> [Any]? {
        guard row > 0 else { return nil }  // row 0 is the column-header row; no row-header for it
        let dataRow = row - 1
        guard dataRow < rowElements.count,
              !rowElements[dataRow].isEmpty else { return nil }
        return [rowElements[dataRow][0]]   // column-0 cell IS the row header
    }

    /// Cell element at an explicit (row, column) position.
    /// Used by VoiceOver's table-navigation rotor commands (next/previous in column, etc.).
    @objc func accessibilityDataTableCellElement(
        forRow row: Int, column: Int
    ) -> (any UIAccessibilityContainerDataTableCell)? {
        if row == 0 {
            return column < headerElements.count ? headerElements[column] : nil
        }
        let dataRow = row - 1
        guard dataRow < rowElements.count,
              column < rowElements[dataRow].count else { return nil }
        return rowElements[dataRow][column]
    }

    /// Linear element order for standard VoiceOver swipe navigation.
    override var accessibilityElements: [Any]? {
        get {
            var all: [Any] = headerElements
            rowElements.forEach { all.append(contentsOf: $0) }
            return all
        }
        set {}
    }
}

// MARK: - SwiftUI representable

/// SwiftUI wrapper — drop this onto any visual table using .overlay().
///
///     visualTableVStack
///         .accessibilityHidden(true)
///         .overlay(
///             AccessibleDataTable(headers: headers, rows: rows)
///                 .allowsHitTesting(false)
///         )
///
/// headers               — column labels; headers[0] is the row-header column label ("City")
/// rows                  — one array per data row; rows[n][0] is the row-header value (full city name)
/// rowActivationHandlers — optional per-row closures called when VoiceOver activates a row header
struct AccessibleDataTable: UIViewRepresentable {
    let headers: [String]
    let rows: [[String]]
    var rowActivationHandlers: [() -> Bool] = []

    func makeUIView(context: Context) -> AccessibleDataTableView {
        AccessibleDataTableView()
    }

    func updateUIView(_ uiView: AccessibleDataTableView, context: Context) {
        // No guard — always update so that scroll-offset changes trigger a
        // rebuild() and keep VoiceOver focus-rectangle positions accurate.
        uiView.rowActivationHandlers = rowActivationHandlers
        uiView.columnHeaders = headers
        uiView.dataRows      = rows
    }
}
