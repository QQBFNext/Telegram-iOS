import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


func _internal_markAllChatsAsRead(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return network.request(Api.functions.messages.getDialogUnreadMarks(flags: 0, parentPeer: nil))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.DialogPeer]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result = result else {
            return .complete()
        }
        
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            var signals: [Signal<Void, NoError>] = []
            for peer in result {
                switch peer {
                    case let .dialogPeer(dialogPeerData):
                        let peer = dialogPeerData.peer
                        let peerId = peer.peerId
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            if let _ = transaction.getPeer(peerId).flatMap(apiInputChannel) {
                                signals.append(.complete())
                            }
                        } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                            if let _ = transaction.getPeer(peerId).flatMap(apiInputPeer) {
                                signals.append(.complete())
                            }
                        } else {
                            assertionFailure()
                        }
                    case .dialogPeerCommunity:
                        break
                    case .dialogPeerFolder:
                        assertionFailure()
                }
            }
            
            let applyLocally = postbox.transaction { transaction -> Void in
                
            }
            
            return combineLatest(signals)
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
            |> then(applyLocally)
        } |> switchToLatest
    }
}
