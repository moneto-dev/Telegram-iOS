import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatMediaInputGifPane: ChatMediaInputPane, UIScrollViewDelegate {
    private let account: Account
    private let controllerInteraction: ChatControllerInteraction
    
    private var multiplexedNode: MultiplexedVideoNode?
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    init(account: Account, controllerInteraction: ChatControllerInteraction) {
        self.account = account
        self.controllerInteraction = controllerInteraction
        
        super.init()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        self.multiplexedNode?.bottomInset = bottomInset
        self.multiplexedNode?.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: size.width, height: size.height - topInset))
    }
    
    func fileAt(point: CGPoint) -> TelegramMediaFile? {
        return self.multiplexedNode?.fileAt(point: point)
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        if self.multiplexedNode == nil {
            let multiplexedNode = MultiplexedVideoNode(account: account)
            self.multiplexedNode = multiplexedNode
            if let validLayout = self.validLayout {
                multiplexedNode.frame = CGRect(origin: CGPoint(), size: validLayout)
            }
            
            self.view.addSubview(multiplexedNode)
            let initialOrder = Atomic<[MediaId]?>(value: nil)
            let gifs = self.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)])
                |> map { view -> [TelegramMediaFile] in
                    var recentGifs: OrderedItemListView?
                    if let orderedView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] {
                        recentGifs = orderedView as? OrderedItemListView
                    }
                    if let recentGifs = recentGifs {
                        return recentGifs.items.map { ($0.contents as! RecentMediaItem).media as! TelegramMediaFile }
                    } else {
                        return []
                    }
            }
            self.disposable.set((gifs |> deliverOnMainQueue).start(next: { [weak self] gifs in
                if let strongSelf = self {
                    strongSelf.multiplexedNode?.files = gifs
                }
            }))
            
            multiplexedNode.fileSelected = { [weak self] file in
                self?.controllerInteraction.sendGif(file)
            }
        }
    }
}
