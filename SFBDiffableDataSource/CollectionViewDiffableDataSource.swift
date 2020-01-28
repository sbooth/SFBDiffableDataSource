/*
 * Copyright (c) 2020 Stephen F. Booth <me@sbooth.org>
 * See https://github.com/sbooth/SFBDiffableDataSource/blob/master/LICENSE.txt for license information
 */

import Cocoa

public class CollectionViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType>: NSObject, NSCollectionViewDataSource where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {
	
	public typealias ItemProvider = (NSCollectionView, IndexPath, SectionIdentifierType, ItemIdentifierType) -> NSCollectionViewItem?
	public typealias SupplementaryViewProvider = (NSCollectionView, NSCollectionView.SupplementaryElementKind, IndexPath, SectionIdentifierType) -> (NSView & NSCollectionViewElement)?

	var supplementaryViewProvider: SupplementaryViewProvider?

	private weak var collectionView: NSCollectionView?
	private let itemProvider: ItemProvider
	private var _snapshot = DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()

	public init(collectionView: NSCollectionView, itemProvider: @escaping CollectionViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType>.ItemProvider) {
		self.collectionView = collectionView
		self.itemProvider = itemProvider
		
		super.init()
		
		collectionView.dataSource = self
	}

	public func apply(_ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true, completionHandler completion: (() -> Void)? = nil) {

		guard animatingDifferences else {
			_snapshot = snapshot
			collectionView?.reloadData()
			return
		}

		// Calculate the differences between the current and desired states
		let difference = snapshot.difference(from: _snapshot)

		// `NSCollectionView` seems to be finicky about the order of operations and has certain requirements for `performBatchUpdates` to work correctly:
		//   1) `delete` operations must use source index paths
		//   2) `insert` and `move` operations must use target index paths
		//
		// Ideally, the code below would look like:
		/*
			_snapshot = snapshot
			collectionView?.animator().performBatchUpdates({
				self.collectionView?.deleteSections(difference.deletedSections)
				self.collectionView?.deleteItems(at: difference.deletedItems)

				self.collectionView?.insertSections(difference.insertedSections)
				self.collectionView?.insertItems(at: difference.insertedItems)

				difference.movedSections.forEach { self.collectionView?.moveSection($0.from, toSection: $0.to) }
				difference.movedItems.forEach { self.collectionView?.moveItem(at: $0.from, to: $0.to) }
			}, completionHandler: { _ in
				completion?()
			})
		*/
		// But this crashes in `-[NSCollectionViewData indexPathForItemAtGlobalIndex:]`, related to `moveSections`.
		//
		// For example, applying the following changes to a snapshot with 5 items in section 0 and 4 in section 1 results in:
		/*
			deleted sections: []
			deleted items: [[0, 1], [0, 2], [0, 3], [1, 0], [1, 1], [1, 3]]
			inserted sections: []
			inserted items: []
			moved sections: [(0, 1)]
			moved items: []
			*** Assertion failure in -[NSCollectionViewData indexPathForItemAtGlobalIndex:], /BuildRoot/Library/Caches/com.apple.xbs/Sources/UIFoundation/UIFoundation-660/UIFoundation/CollectionView/UICollectionViewData.m:906
			[General] request for index path for global index 5 when there are only 3 items in the collection view
		*/
		// I could not get things working in one call to `performBatchUpdates`, hence the two nested calls below.

		_snapshot = difference.stateAfterDeletions

		collectionView?.animator().performBatchUpdates({
			self.collectionView?.deleteSections(difference.deletedSections)
			self.collectionView?.deleteItems(at: difference.deletedItems)
		}, completionHandler: { _ in
			self._snapshot = snapshot

			self.collectionView?.animator().performBatchUpdates({
				self.collectionView?.insertSections(difference.insertedSections)
				self.collectionView?.insertItems(at: difference.insertedItems)
				difference.movedSections.forEach { self.collectionView?.moveSection($0.from, toSection: $0.to) }
				difference.movedItems.forEach { self.collectionView?.moveItem(at: $0.from, to: $0.to) }
			}, completionHandler: { _ in
				completion?()
			})
		})
	}

	public func snapshot() -> DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> {
		return _snapshot
	}
	
	public func sectionIdentifier(for section: Int) -> SectionIdentifierType? {
		return _snapshot.sectionIdentifier(for: section)
	}

	public func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? {
		return _snapshot.itemIdentifier(for: indexPath)
	}

	public func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? {
		return _snapshot.indexPath(for: itemIdentifier)
	}

	public func numberOfSections(in collectionView: NSCollectionView) -> Int {
		return _snapshot.numberOfSections
	}
	
	public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
		return _snapshot.numberOfItems(inSection: _snapshot.sectionIdentifiers[section])
	}
	
	public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
		guard let (sectionIdentifier, itemIdentifier) = _snapshot.identifiers(for: indexPath) else {
			preconditionFailure("Missing identifiers for index path \(indexPath)")
		}
		
		guard let item = itemProvider(collectionView, indexPath, sectionIdentifier, itemIdentifier) else {
			preconditionFailure("CollectionViewDiffableDataSource.itemProvider returned nil item")
		}
		
		return item
	}
	
	public func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
		guard let sectionIdentifier = _snapshot.sectionIdentifier(for: indexPath.section) else {
			preconditionFailure("Missing section for index \(indexPath.section)")
		}

		guard let view = supplementaryViewProvider?(collectionView, kind, indexPath, sectionIdentifier) else {
			preconditionFailure("CollectionViewDiffableDataSource.supplementaryViewProvider returned nil view")
		}

		return view
	}
}
