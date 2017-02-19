/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import RxSwift
import PureLayout

class OpenQuicklyWindow: NSObject,
                         UiComponent,
                         NSWindowDelegate,
                         NSTableViewDelegate, NSTableViewDataSource {

  typealias StateType = MainWindow.State

  required init(source: Observable<StateType>, emitter: ActionEmitter, state: StateType) {
    self.emitter = emitter
    self.windowController = NSWindowController(windowNibName: "OpenQuicklyWindow")

    super.init()

    self.window.delegate = self

    source
      .subscribe(onNext: { state in
      })
      .addDisposableTo(self.disposeBag)
  }

  fileprivate let emitter: ActionEmitter
  fileprivate let disposeBag = DisposeBag()

  fileprivate(set) var flatFileItems = [FileItem]()
  fileprivate(set) var fileViewItems = [ScoredFileItem]()
  fileprivate var cwdPathCompsCount = 0

  fileprivate let windowController: NSWindowController

  fileprivate let searchField = NSTextField(forAutoLayout: ())
  fileprivate let progressIndicator = NSProgressIndicator(forAutoLayout: ())
  fileprivate let cwdControl = NSPathControl(forAutoLayout: ())
  fileprivate let countField = NSTextField(forAutoLayout: ())
  fileprivate let fileView = NSTableView.standardTableView()

  fileprivate var window: NSWindow {
    return self.windowController.window!
  }

  fileprivate func addViews() {
    let searchField = self.searchField
    searchField.rx.delegate.setForwardToDelegate(self, retainDelegate: false)

    let progressIndicator = self.progressIndicator
    progressIndicator.isIndeterminate = true
    progressIndicator.isDisplayedWhenStopped = false
    progressIndicator.style = .spinningStyle
    progressIndicator.controlSize = .small

    let fileView = self.fileView
    fileView.intercellSpacing = CGSize(width: 4, height: 4)
    fileView.dataSource = self
    fileView.delegate = self

    let fileScrollView = NSScrollView.standardScrollView()
    fileScrollView.autoresizesSubviews = true
    fileScrollView.documentView = fileView

    let cwdControl = self.cwdControl
    cwdControl.pathStyle = .standard
    cwdControl.backgroundColor = NSColor.clear
    cwdControl.refusesFirstResponder = true
    cwdControl.cell?.controlSize = .small
    cwdControl.cell?.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize())
    cwdControl.setContentCompressionResistancePriority(NSLayoutPriorityDefaultLow, for: .horizontal)

    let countField = self.countField
    countField.isEditable = false
    countField.isBordered = false
    countField.alignment = .right
    countField.backgroundColor = NSColor.clear
    countField.stringValue = "0 items"

    let contentView = self.window.contentView!
    contentView.addSubview(searchField)
    contentView.addSubview(progressIndicator)
    contentView.addSubview(fileScrollView)
    contentView.addSubview(cwdControl)
    contentView.addSubview(countField)

    searchField.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
    searchField.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
    searchField.autoPinEdge(toSuperviewEdge: .left, withInset: 8)

    progressIndicator.autoAlignAxis(.horizontal, toSameAxisOf: searchField)
    progressIndicator.autoPinEdge(.right, to: .right, of: searchField, withOffset: -4)

    fileScrollView.autoPinEdge(.top, to: .bottom, of: searchField, withOffset: 8)
    fileScrollView.autoPinEdge(toSuperviewEdge: .left, withInset: -1)
    fileScrollView.autoPinEdge(toSuperviewEdge: .right, withInset: -1)
    fileScrollView.autoSetDimension(.height, toSize: 200, relation: .greaterThanOrEqual)

    cwdControl.autoPinEdge(.top, to: .bottom, of: fileScrollView, withOffset: 4)
    cwdControl.autoPinEdge(toSuperviewEdge: .left, withInset: 2)
    cwdControl.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4)

    countField.autoPinEdge(.top, to: .bottom, of: fileScrollView, withOffset: 4)
    countField.autoPinEdge(toSuperviewEdge: .right, withInset: 2)
    countField.autoPinEdge(.left, to: .right, of: cwdControl, withOffset: 4)
  }
}

// MARK: - NSTableViewDataSource
extension OpenQuicklyWindow {

  @objc(numberOfRowsInTableView:)
  func numberOfRows(in _: NSTableView) -> Int {
    return self.fileViewItems.count
  }
}

// MARK: - NSTableViewDelegate
extension OpenQuicklyWindow {

  func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    return OpenQuicklyFileViewRow()
  }

  @objc(tableView:viewForTableColumn:row:)
  func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
    let cachedCell = (tableView.make(withIdentifier: "file-view-row", owner: self) as? ImageAndTextTableCell)?.reset()
    let cell = cachedCell ?? ImageAndTextTableCell(withIdentifier: "file-view-row")

    let url = self.fileViewItems[row].url
    cell.attributedText = self.rowText(for: url as URL)
    cell.image = FileUtils.icon(forUrl: url)

    return cell
  }

  func tableViewSelectionDidChange(_: Notification) {
//    NSLog("\(#function): selection changed")
  }

  fileprivate func rowText(for url: URL) -> NSAttributedString {
    let pathComps = url.pathComponents
    let truncatedPathComps = pathComps[self.cwdPathCompsCount..<pathComps.count]
    let name = truncatedPathComps.last!

    if truncatedPathComps.dropLast().isEmpty {
      return NSMutableAttributedString(string: name)
    }

    let rowText: NSMutableAttributedString
    let pathInfo = truncatedPathComps.dropLast().reversed().joined(separator: " / ")
    rowText = NSMutableAttributedString(string: "\(name) — \(pathInfo)")
    rowText.addAttribute(NSForegroundColorAttributeName,
                         value: NSColor.lightGray,
                         range: NSRange(location:name.characters.count, length: pathInfo.characters.count + 3))

    return rowText
  }
}
