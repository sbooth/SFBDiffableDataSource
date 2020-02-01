/*
 * Copyright (c) 2020 Stephen F. Booth <me@sbooth.org>
 * See https://github.com/sbooth/SFBDiffableDataSource/blob/master/LICENSE.txt for license information
 */

import Foundation

/// A snapshot of a data source supporting multiple sections, typically used for `NSCollectionView`
public struct DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {

	/// A section within the collection
	struct Section {
		let identifier: SectionIdentifierType
		let position: Array<SectionIdentifierType>.Index
		let containedItems: Range<Array<ItemIdentifierType>.Index>
	}

	private(set) var orderedSectionIdentifiers = [SectionIdentifierType]()
	private(set) var sections = [SectionIdentifierType: Section]()
	private(set) var items = [ItemIdentifierType]()

	/// Creates an empty snapshot
	public init() {
	}

	/// The number of items in the snapshot
	public var numberOfItems: Int {
		return items.count
	}

	/// The number of sections in the snapshot
	public var numberOfSections: Int {
		return orderedSectionIdentifiers.count
	}

	/// The section identifiers in the snapshot
	public var sectionIdentifiers: [SectionIdentifierType] {
		return orderedSectionIdentifiers
	}

	/// The item identifiers in the snapshot
	public var itemIdentifiers: [ItemIdentifierType] {
		return items
	}

	/// Returns the number of items in the specified section
	public func numberOfItems(inSection identifier: SectionIdentifierType) -> Int {
		guard let section = sections[identifier] else {
			preconditionFailure("Unknown section \(identifier)")
		}
		return section.containedItems.count
	}

	/// Returns the identifiers for the items in the specified section
	public func itemIdentifiers(inSection identifier: SectionIdentifierType) -> ArraySlice<ItemIdentifierType> {
		guard let section = sections[identifier] else {
			preconditionFailure("Unknown section \(identifier)")
		}
		return items[section.containedItems]
	}

	/// Returns the identifier for the section containing the specified item or `nil` if none
	/// - complexity: O(*n*), where *n* is the number of items
	public func sectionIdentifier(containingItem identifier: ItemIdentifierType) -> SectionIdentifierType? {
		guard let index = items.firstIndex(of: identifier) else {
			preconditionFailure("Unknown item \(identifier)")
		}
		return sections.first(where: { $1.containsItem(atAbsoluteIndex: index) })?.key
	}

	/// Returns the index of the specified item or `nil` if none
	/// - complexity: O(*n*), where *n* is the number of items
	public func indexOfItem(_ identifier: ItemIdentifierType) -> Int? {
		return items.firstIndex(of: identifier)
	}

	/// Returns the index of the specified section or `nil` if none
	public func indexOfSection(_ identifier: SectionIdentifierType) -> Int? {
		return sections[identifier]?.position
	}

	/// Appends items to the specified section
	public mutating func appendItems(_ identifiers: [ItemIdentifierType], toSection identifier: SectionIdentifierType) {
		guard let section = sections[identifier] else {
			preconditionFailure("Unknown section \(identifier)")
		}

		items.insert(contentsOf: identifiers, at: section.containedItems.upperBound)
		sections[identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.withUpperBoundIncreased(by: identifiers.count))

		for identifier in orderedSectionIdentifiers.suffix(from: section.position.advanced(by: 1)) {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.translated(by: identifiers.count))
		}
	}

	/// Inserts item in the specified section before the specified item
	public mutating func insertItems(_ identifiers: [ItemIdentifierType], beforeItem beforeIdentifier: ItemIdentifierType) {
		guard let index = items.firstIndex(of: beforeIdentifier) else {
			preconditionFailure("Unknown item \(beforeIdentifier)")
		}

		guard let section = sections.first(where: { $1.containsItem(atAbsoluteIndex: index) }) else {
			preconditionFailure("Internal error: Missing section for item at absolute index \(index)")
		}

		items.insert(contentsOf: identifiers, at: section.value.containedItems.distance(from: section.value.containedItems.lowerBound, to: index))
		sections[section.key] = Section(identifier: section.value.identifier, position: section.value.position, containedItems: section.value.containedItems.withUpperBoundIncreased(by: identifiers.count))

		for identifier in orderedSectionIdentifiers.suffix(from: section.value.position.advanced(by: 1)) {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.translated(by: identifiers.count))
		}
	}

	/// Inserts item in the specified section after the specified item
	public mutating func insertItems(_ identifiers: [ItemIdentifierType], afterItem afterIdentifier: ItemIdentifierType) {
		guard let index = items.firstIndex(of: afterIdentifier) else {
			preconditionFailure("Unknown item \(afterIdentifier)")
		}

		guard let section = sections.first(where: { $1.containsItem(atAbsoluteIndex: index) }) else {
			preconditionFailure("Internal error: Missing section for item at absolute index \(index)")
		}

		items.insert(contentsOf: identifiers, at: section.value.containedItems.distance(from: section.value.containedItems.lowerBound, to: index.advanced(by: 1)))
		sections[section.key] = Section(identifier: section.value.identifier, position: section.value.position, containedItems: section.value.containedItems.withUpperBoundIncreased(by: identifiers.count))

		for identifier in orderedSectionIdentifiers.suffix(from: section.value.position.advanced(by: 1)) {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.translated(by: identifiers.count))
		}
	}

	/// Deletes the items corresponding to `identifiers`
	/// - complexity: O(*n*) where *n* is the number of items
	public mutating func deleteItems(_ identifiers: [ItemIdentifierType]) {
		for identifier in identifiers {
			guard let index = items.firstIndex(of: identifier) else {
				preconditionFailure("Unknown item \(identifier)")
			}
			deleteItem(atAbsoluteIndex: index)
		}
	}

	/// Deletes all the items from the snapshot, leaving empty sections
	public mutating func deleteAllItems() {
		items.removeAll()
		let containedItems = 0 ..< 0
		for section in sections {
			sections[section.key] = Section(identifier: section.value.identifier, position: section.value.position, containedItems: containedItems)
		}
	}

	/// Moves the specified item before `toIdentifier`
	public mutating func moveItem(_ identifier: ItemIdentifierType, beforeItem toIdentifier: ItemIdentifierType) {
		guard let index = items.firstIndex(of: toIdentifier) else {
			preconditionFailure("Unknown item \(toIdentifier)")
		}

		guard let section = sections.first(where: { $1.containsItem(atAbsoluteIndex: index) }) else {
			preconditionFailure("Internal error: Missing section for item at absolute index \(index)")
		}

		moveItem(identifier, toSection: section.key, atAbsoluteIndex: index)
	}

	/// Moves the specified item after `toIdentifier`
	public mutating func moveItem(_ identifier: ItemIdentifierType, afterItem toIdentifier: ItemIdentifierType) {
		guard let index = items.firstIndex(of: toIdentifier) else {
			preconditionFailure("Unknown item \(toIdentifier)")
		}

		guard let section = sections.first(where: { $1.containsItem(atAbsoluteIndex: index) }) else {
			preconditionFailure("Internal error: Missing section for item at absolute index \(index)")
		}

		moveItem(identifier, toSection: section.key, atAbsoluteIndex: index.advanced(by: 1))
	}

	/// Currently unimplemented
	mutating func reloadItems(_ identifiers: [ItemIdentifierType]) {
		preconditionFailure()
	}

	/// Appends empty sections to the snapshot
	public mutating func appendSections(_ identifiers: [SectionIdentifierType]) {
		for (i, identifier) in identifiers.enumerated() {
			sections[identifier] = Section(identifier: identifier, position: orderedSectionIdentifiers.count + i, containedItems: items.count ..< items.count)
		}
		orderedSectionIdentifiers.append(contentsOf: identifiers)
	}

	/// Inserts the specified sections before `identifier`
	public mutating func insertSections(_ identifiers: [SectionIdentifierType], beforeSection identifier: SectionIdentifierType) {
		guard let section = sections[identifier] else {
			preconditionFailure("Unknown section \(identifier)")
		}

		for (i, identifier) in identifiers.enumerated() {
			insertSection(identifier, at: section.position + i)
		}
	}

	/// Inserts the specified sections after `identifier`
	public mutating func insertSections(_ identifiers: [SectionIdentifierType], afterSection identifier: SectionIdentifierType) {
		guard let section = sections[identifier] else {
			preconditionFailure("Unknown section \(identifier)")
		}

		for (i, identifier) in identifiers.enumerated() {
			insertSection(identifier, at: section.position + i + 1)
		}
	}

	/// Deletes the sections with the specified identifiers and all their contained items from the snapshot
	public mutating func deleteSections(_ identifiers: [SectionIdentifierType]) {
		for identifier in identifiers {
			guard let section = sections[identifier] else {
				preconditionFailure("Unknown section \(identifier)")
			}
			deleteSection(section)
		}
	}

	/// Moves section `identifier` and all contained items before section `toIdentifier`
	public mutating func moveSection(_ identifier: SectionIdentifierType, beforeSection toIdentifier: SectionIdentifierType) {
		guard let section = sections[toIdentifier] else {
			preconditionFailure("Unknown section \(toIdentifier)")
		}

		moveSection(identifier, to: section.position)
	}

	/// Moves section `identifier` and all contained items after section `toIdentifier`
	public mutating func moveSection(_ identifier: SectionIdentifierType, afterSection toIdentifier: SectionIdentifierType) {
		guard let section = sections[toIdentifier] else {
			preconditionFailure("Unknown section \(toIdentifier)")
		}

		moveSection(identifier, to: section.position + 1)
	}

	/// Currently unimplemented
	mutating func reloadSections(_ identifiers: [SectionIdentifierType]) {
		preconditionFailure()
	}	
}

extension DiffableDataSourceSnapshot {
	/// Returns the section identifier corresponding to `index` or `nil` if none
	func sectionIdentifier(for index: Int) -> SectionIdentifierType? {
		guard index < sections.count else {
			return nil
		}

		let sectionIdentifier = orderedSectionIdentifiers[index]
		guard let section = sections[sectionIdentifier] else {
			preconditionFailure("Internal error: Unknown section \(sectionIdentifier)")
		}

		return section.identifier
	}

	/// Returns the item identifier corresponding to `indexPath` or `nil` if none
	func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? {
		let identifiers = self.identifiers(for: indexPath)
		return identifiers?.1
	}

	/// Returns the section and item identifiers corresponding to `indexPath` or `nil` if none
	func identifiers(for indexPath: IndexPath) -> (SectionIdentifierType, ItemIdentifierType)? {
		guard indexPath.section < sections.count else {
			return nil
		}

		let sectionIdentifier = orderedSectionIdentifiers[indexPath.section]
		guard let section = sections[sectionIdentifier] else {
			preconditionFailure("Internal error: Unknown section \(sectionIdentifier)")
		}

		guard indexPath.item < section.containedItems.count else {
			return nil
		}

		return (sectionIdentifier, items[section.containedItems.lowerBound + indexPath.item])
	}

	/// Returns the index path corresponding to `itemIdentifier` or `nil` if none
	/// - complexity: O(*n*), where *n* is the number of items
	func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? {
		guard let absoluteItemIndex = items.firstIndex(of: itemIdentifier) else {
			return nil
		}
		
		for section in sections {
			if section.value.containsItem(atAbsoluteIndex: absoluteItemIndex) {
				return IndexPath(item: section.value.offsetOfItem(atAbsoluteIndex: absoluteItemIndex), section: section.value.position)
			}
		}
		
		return nil
	}

	/// Returns the index path corresponding to `absoluteItemIndex` or `nil` if none
	/// - complexity: O(*n*), where *n* is the number of sections
	func indexPath(forAbsoluteItemIndex absoluteItemIndex: Int) -> IndexPath? {
		for section in sections {
			if section.value.containsItem(atAbsoluteIndex: absoluteItemIndex) {
				return IndexPath(item: section.value.offsetOfItem(atAbsoluteIndex: absoluteItemIndex), section: section.value.position)
			}
		}

		return nil
	}

	/// inserts the section at `index`
	mutating func insertSection(_ section: SectionIdentifierType, at index: Int) {
		precondition(sections[section] == nil, "Internal error: Attempt to insert duplicate section \(section)")

		guard index <= sections.count else {
			preconditionFailure("Unable to insert section at index \(index)")
		}

		let followingIdentifiers = orderedSectionIdentifiers.suffix(from: index)

		for identifier in followingIdentifiers {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position + 1, containedItems: section.containedItems)
		}

		orderedSectionIdentifiers.insert(section, at: index)

		var containedItems = 0 ..< 0
		if orderedSectionIdentifiers.indices.contains(index.advanced(by: -1)) {
			let identifier = orderedSectionIdentifiers[index.advanced(by: -1)]
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			containedItems = section.containedItems.upperBound ..< section.containedItems.upperBound
		}
		else if orderedSectionIdentifiers.indices.contains(index.advanced(by: 1)) {
			let identifier = orderedSectionIdentifiers[index.advanced(by: 1)]
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			containedItems = section.containedItems.lowerBound ..< section.containedItems.lowerBound
		}

		sections[section] = Section(identifier: section, position: index, containedItems: containedItems)
	}

	mutating func moveSection(_ identifier: SectionIdentifierType, to index: Int) {
		guard let section = sections[identifier] else {
			preconditionFailure("Unknown section \(identifier)")
		}

		guard index < sections.count else {
			preconditionFailure("Unable to move section to index \(index)")
		}

		let items = self.items[section.containedItems]

		deleteSection(section)
		insertSection(identifier, at: index)
		appendItems(Array(items), toSection: identifier)
	}

	/// Deletes the section at `index`
	mutating func deleteSection(at index: Int) {
		guard let section = sections[orderedSectionIdentifiers[index]] else {
			preconditionFailure("Missing section for index \(index)")
		}
		deleteSection(section)
	}

	/// Performs the actual work of deleting a section
	mutating func deleteSection(_ sectionToDelete: Section) {
		precondition(sections[sectionToDelete.identifier] != nil, "Internal error: Unable to delete unknown section \(sectionToDelete.identifier)")

		for identifier in orderedSectionIdentifiers.suffix(from: sectionToDelete.position.advanced(by: 1)) {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position - 1, containedItems: section.containedItems.translated(by: -sectionToDelete.containedItems.count))
		}

		orderedSectionIdentifiers.remove(at: sectionToDelete.position)
		items.removeSubrange(sectionToDelete.containedItems)
		sections[sectionToDelete.identifier] = nil
	}

	/// Deletes the item at `absoluteItemIndex`
	mutating func deleteItem(atAbsoluteIndex absoluteItemIndex: Int) {
		guard let section = sections.first(where: { $1.containsItem(atAbsoluteIndex: absoluteItemIndex) }) else {
			preconditionFailure("Missing section for item at absolute index \(absoluteItemIndex)")
		}

		items.remove(at: absoluteItemIndex)

		sections[section.key] = Section(identifier: section.value.identifier, position: section.value.position, containedItems: section.value.containedItems.dropLast())


		for identifier in orderedSectionIdentifiers.suffix(from: section.value.position.advanced(by: 1)) {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.translated(by: -1))
		}
	}

	/// Inserts  the item at `absoluteItemIndex`
	mutating func insertItem(_ identifier: ItemIdentifierType, inSection sectionIdentifier: SectionIdentifierType, atAbsoluteIndex absoluteItemIndex: Int) {
		guard let section = sections[sectionIdentifier] else {
			preconditionFailure("Internal error: Missing section \(sectionIdentifier)")
		}

		items.insert(identifier, at: absoluteItemIndex)

		sections[section.identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.withUpperBoundIncreased(by: 1))

		for identifier in orderedSectionIdentifiers.suffix(from: section.position.advanced(by: 1)) {
			guard let section = sections[identifier] else {
				preconditionFailure("Internal error: Missing section \(identifier)")
			}
			sections[identifier] = Section(identifier: section.identifier, position: section.position, containedItems: section.containedItems.translated(by: 1))
		}
	}

	mutating func moveItem(_ identifier: ItemIdentifierType, toSection sectionIdentifier: SectionIdentifierType, atAbsoluteIndex absoluteItemIndex: Int) {
		guard let oldIndex = items.firstIndex(of: identifier) else {
			preconditionFailure("Unknown item \(identifier)")
		}

		guard absoluteItemIndex < items.count else {
			preconditionFailure("Unable to move item to index \(absoluteItemIndex)")
		}

		deleteItem(atAbsoluteIndex: oldIndex)
		insertItem(identifier, inSection: sectionIdentifier, atAbsoluteIndex: absoluteItemIndex)
	}
}

extension DiffableDataSourceSnapshot {
	/// Returns the difference of `self` from `snapshot`
	func difference(from snapshot: DiffableDataSourceSnapshot) -> DiffableDataSourceSnapshotDifference<SectionIdentifierType, ItemIdentifierType> {
		return DiffableDataSourceSnapshotDifference(sourceState: snapshot, targetState: self)
	}
}

extension DiffableDataSourceSnapshot: CustomDebugStringConvertible {
	public var debugDescription: String {
		var result = "DiffableDataSourceSnapshot("

		if !items.isEmpty {
			result += "\(items.count) items, \(orderedSectionIdentifiers.count) sections, "
			result += sections.sorted(by: { $0.1.position < $1.1.position }).map({ "\($1)" }).joined(separator: ", ")
		}
		result += ")"
		return result
	}
}

extension DiffableDataSourceSnapshot.Section: Equatable {
	static func ==(lhs: DiffableDataSourceSnapshot.Section, rhs: DiffableDataSourceSnapshot.Section) -> Bool {
		return lhs.identifier == rhs.identifier
	}
}

extension DiffableDataSourceSnapshot.Section: Hashable {
	func hash(into hasher: inout Hasher) {
		hasher.combine(identifier)
	}
}

extension DiffableDataSourceSnapshot.Section {
	func containsItem(atAbsoluteIndex index: Array<ItemIdentifierType>.Index) -> Bool {
		return containedItems.contains(index)
	}

	func offsetOfItem(atAbsoluteIndex index: Array<ItemIdentifierType>.Index) -> Int {
		return containedItems.distance(from: containedItems.lowerBound, to: index)
	}
}

extension DiffableDataSourceSnapshot.Section: CustomDebugStringConvertible {
	var debugDescription: String {
		"Section('\(identifier)', position \(position), \(containedItems.count) items from \(containedItems))"
	}
}

private extension Range where Bound: AdditiveArithmetic {
	/// Adds `amount` to the range's upper bound
	func withUpperBoundIncreased(by amount: Bound) -> Range {
		return lowerBound ..< upperBound + amount
	}

	/// Adds `amount` to the range's lower and upper bounds
	func translated(by amount: Bound) -> Range {
		return Range(uncheckedBounds: (lowerBound + amount, upperBound + amount))
	}
}
