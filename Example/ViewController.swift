/*
 * Copyright (c) 2020 Stephen F. Booth <me@sbooth.org>
 * See https://github.com/sbooth/SFBDiffableDataSource/blob/master/LICENSE.txt for license information
 */

import Cocoa
import SFBDiffableDataSource

class SearchResult: Hashable {
	let identifier = UUID()
	func hash(into hasher: inout Hasher) {
		hasher.combine(identifier)
	}
	static func ==(lhs: SearchResult, rhs: SearchResult) -> Bool {
		return lhs.identifier == rhs.identifier
	}
}

class Track: SearchResult {
	let title: String
	init(_ title: String) {
		self.title = title
	}
}

extension Track: CustomDebugStringConvertible {
	var debugDescription: String {
		return "'\(title)'"
	}
}

class Album: SearchResult {
	let title: String
	init(_ title: String) {
		self.title = title
	}
}

extension Album: CustomDebugStringConvertible {
	var debugDescription: String {
		return "'\(title)'"
	}
}

class ViewController: NSViewController {
	@IBOutlet weak var collectionView: NSCollectionView!
	private var dataSource: CollectionViewDiffableDataSource<SectionKind, SearchResult>!

	private enum SectionKind: Int {
		case track, album
	}

	private var tracks: [Track] = [
		Track("Santeria"), Track("The Great Gig in the Sky"), Track("Variations on the Kanon by Pachelbel"), Track("Why Can't This Be Love"), Track("Jeremy")
	]
	private var albums: [Album] = [
		Album("Sublime"), Album("The Dark Side of the Moon"), Album("December"), Album("5150"), Album("Ten")
	]

	private var everyOther = true

	override func viewDidLoad() {
		super.viewDidLoad()

		configureHierarchy()
		configureDataSource()

		clearSearchResults(animate: false)
	}

	@IBAction func performSearch(_ sender: AnyObject?) {
		guard let searchString = sender?.stringValue else {
			return
		}

		if searchString.isEmpty {
			clearSearchResults(animate: true)
			return
		}

		let lc = searchString.lowercased()
		let tracks = self.tracks.filter { $0.title.lowercased().contains(lc) }
		let albums = self.albums.filter { $0.title.lowercased().contains(lc) }

		print("Search for '\(lc)' matched \(tracks.count) tracks and \(albums.count) albums")

		var snapshot = DiffableDataSourceSnapshot<SectionKind, SearchResult>()

		// Reorder the sections for testing/debugging/demonstration purposes
		if everyOther {
			if !tracks.isEmpty {
				snapshot.appendSections([.track])
				snapshot.appendItems(tracks, toSection: .track)
			}
			if !albums.isEmpty {
				snapshot.appendSections([.album])
				snapshot.appendItems(albums, toSection: .album)
			}
		}
		else {
			if !albums.isEmpty {
				snapshot.appendSections([.album])
				snapshot.appendItems(albums, toSection: .album)
			}
			if !tracks.isEmpty {
				snapshot.appendSections([.track])
				snapshot.appendItems(tracks, toSection: .track)
			}
		}

		everyOther.toggle()

		dataSource.apply(snapshot, animatingDifferences: true)
	}

	func clearSearchResults(animate: Bool) {
		let snapshot = DiffableDataSourceSnapshot<SectionKind, SearchResult>()
		dataSource.apply(snapshot, animatingDifferences: animate)
	}

    private func createLayout() -> NSCollectionViewLayout {
		let sectionProvider = { (sectionIndex: Int,
			layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection in

			let sectionKind = self.dataSource.sectionIdentifier(for: sectionIndex)!
			switch sectionKind {
			case .track:
				let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
				let item = NSCollectionLayoutItem(layoutSize: itemSize)

				let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
				let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

				let section = NSCollectionLayoutSection(group: group)

				return section
			case .album:
				let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
				let item = NSCollectionLayoutItem(layoutSize: itemSize)

				let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(59))
				let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

				let section = NSCollectionLayoutSection(group: group)

				return section
			}
		}

		return NSCollectionViewCompositionalLayout(sectionProvider: sectionProvider)
	}

	private func configureHierarchy() {
		collectionView.register(NSNib(nibNamed: "TrackItem", bundle: nil), forItemWithIdentifier: TrackItem.reuseIdentifier)
		collectionView.register(NSNib(nibNamed: "AlbumItem", bundle: nil), forItemWithIdentifier: AlbumItem.reuseIdentifier)

		collectionView.collectionViewLayout = createLayout()
	}

	private func configureDataSource() {
		dataSource = CollectionViewDiffableDataSource<SectionKind, SearchResult>(collectionView: collectionView) { (collectionView, indexPath, sectionIdentifier, itemIdentifier) -> NSCollectionViewItem? in

			switch sectionIdentifier {
			case .track:
				let item = collectionView.makeItem(withIdentifier: TrackItem.reuseIdentifier, for: indexPath) as! TrackItem
				let track = itemIdentifier as! Track
				item.textField?.stringValue = track.title
				return item
			case .album:
				let item = collectionView.makeItem(withIdentifier: AlbumItem.reuseIdentifier, for: indexPath) as! AlbumItem
				let album = itemIdentifier as! Album
				item.textField?.stringValue = album.title
				return item
			}
		}
	}
}
