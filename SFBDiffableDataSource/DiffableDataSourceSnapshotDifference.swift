/*
 * Copyright (c) 2020 Stephen F. Booth <me@sbooth.org>
 * See https://github.com/sbooth/SFBDiffableDataSource/blob/master/LICENSE.txt for license information
 */

import Foundation

/// A helper for `NSCollectionView` change animations
///
/// All locations for deletions are relative to `sourceState`.
/// All  locations for insertions  are relative to `targetState`.
/// For moves, all `from` locations  are relative to `stateAfterDeletions` and all `to` locations are are relative to `targetState`.
struct DiffableDataSourceSnapshotDifference<SectionIdentifierType, ItemIdentifierType> where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {
	struct ElementMove<LocationType>: Hashable where LocationType: Hashable {
		let from: LocationType
		let to: LocationType
	}

	typealias SnapshotType = DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>

	typealias SectionMove = ElementMove<Int>
	typealias ItemMove = ElementMove<IndexPath>

	let sourceState: SnapshotType
	let targetState: SnapshotType

	/// Snapshot of `sourceState` after applying section and item deletions
	let stateAfterDeletions: SnapshotType

	/// Indexes in `sourceState` of sections that were deleted
	let deletedSections: IndexSet
	/// Index paths in `sourceState` of individual deleted items not part of any deleted sections
	let deletedItems: Set<IndexPath>

	/// Indexes in `targetState` of sections that were inserted
	let insertedSections: IndexSet
	/// Index paths in `targetState` of items that were inserted
	let insertedItems: Set<IndexPath>

	/// Indexes  in `stateAfterDeletions` and `targetState` of sections that were moved
	let movedSections: Set<SectionMove>
	/// Indexe paths  in `stateAfterDeletions` and `targetState` of individual items  that were moved
	let movedItems: Set<ItemMove>

	init(sourceState: SnapshotType, targetState: SnapshotType) {
		self.sourceState = sourceState
		self.targetState = targetState

		// Progressively track the effects of the operations on the snapshot, for NSCollectionView's benefit
		var workingState = sourceState

		// 1. Process section deletions
		var sectionDiff = targetState.sectionIdentifiers.difference(from: sourceState.sectionIdentifiers).inferringMoves()
		var deletedSections = IndexSet()
		for removal in sectionDiff.removals.reversed() {
			if case let .remove(offset, _, associatedWith) = removal, associatedWith == nil {
				workingState.deleteSection(at: offset)
				deletedSections.insert(offset)
			}
		}
		self.deletedSections = deletedSections

		// 2. Process item deletions
		var itemDiff = targetState.itemIdentifiers.difference(from: sourceState.itemIdentifiers).inferringMoves()
		var deletedItems: Set<IndexPath> = []
		for removal in itemDiff.removals.reversed() {
			if case let .remove(offset, _, associatedWith) = removal, associatedWith == nil {
				guard let indexPath = sourceState.indexPath(forAbsoluteItemIndex: offset) else {
					preconditionFailure("Unknown index path for absolute item index \(offset)")
				}
				if !deletedSections.contains(indexPath.section) {
					workingState.deleteItem(atAbsoluteIndex: offset)
					deletedItems.insert(indexPath)
				}
			}
		}
		self.deletedItems = deletedItems

		// 3. Save the working state after deletions
		stateAfterDeletions = workingState

		// 4. Process section insertions
		var insertedSections = IndexSet()
		for insertion in sectionDiff.insertions {
			if case let .insert(offset, element, associatedWith) = insertion, associatedWith == nil {
				workingState.insertSection(element, at: offset)
				insertedSections.insert(offset)
			}
		}
		self.insertedSections = insertedSections

		// 5. Process item insertions
		var insertedItems: Set<IndexPath> = []
		for insertion in itemDiff.insertions {
			if case let .insert(offset, element, associatedWith) = insertion, associatedWith == nil {
				guard let indexPath = targetState.indexPath(forAbsoluteItemIndex: offset) else {
					preconditionFailure("Unknown index path for absolute item index \(offset)")
				}
				let section = targetState.orderedSectionIdentifiers[indexPath.section]
				workingState.insertItem(element, inSection: section, atAbsoluteIndex: offset)
				insertedItems.insert(indexPath)
			}
		}
		self.insertedItems = insertedItems

		workingState = stateAfterDeletions

		// 6. Process section moves
		sectionDiff = targetState.sectionIdentifiers.difference(from: workingState.sectionIdentifiers).inferringMoves()
		var movedSections: Set<SectionMove> = []
		for insertion in sectionDiff.insertions {
			if case let .insert(offset, element, associatedWith) = insertion, associatedWith != nil {
				workingState.moveSection(element, to: offset)
				movedSections.insert(SectionMove(from: associatedWith!, to: offset))
			}
		}
		self.movedSections = movedSections

		// 7. Process item moves
		itemDiff = targetState.itemIdentifiers.difference(from: workingState.itemIdentifiers).inferringMoves()
		var movedItems: Set<ItemMove> = []
		for insertion in itemDiff.insertions {
			if case let .insert(offset, element, associatedWith) = insertion, associatedWith != nil {
				guard let fromIndexPath = workingState.indexPath(forAbsoluteItemIndex: associatedWith!) else {
					preconditionFailure("Unknown index path for absolute item index \(associatedWith!)")
				}
				guard let toIndexPath = targetState.indexPath(forAbsoluteItemIndex: offset) else {
					preconditionFailure("Unknown index path for absolute item index \(offset)")
				}
				let section = targetState.orderedSectionIdentifiers[toIndexPath.section]
				workingState.moveItem(element, toSection: section, atAbsoluteIndex: offset)
				movedItems.insert(ItemMove(from: fromIndexPath, to: toIndexPath))
			}
		}
		self.movedItems = movedItems
	}
}

extension DiffableDataSourceSnapshotDifference: CustomDebugStringConvertible {
	public var debugDescription: String {
		"DiffableDataSourceSnapshotDifference(sourceState: \(sourceState), targetState: \(targetState), deletedSections: \(deletedSections), insertedSections: \(insertedSections.sorted()), movedSections: \(movedSections.sorted(by: { $0.from < $1.from })), deletedItems: \(deletedItems), insertedItems: \(insertedItems), movedItems: \(movedItems.sorted(by: { $0.from < $1.from })))"
	}
}

extension DiffableDataSourceSnapshotDifference.ElementMove: CustomDebugStringConvertible {
	var debugDescription: String {
		return "\(from) -> \(to)"
	}
}
