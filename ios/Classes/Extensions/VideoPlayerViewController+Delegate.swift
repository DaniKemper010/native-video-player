import AVKit

extension VideoPlayerView: AVPlayerViewControllerDelegate {
    public func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        sendEvent("pipStart")
    }

    public func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        sendEvent("pipStop")
    }
    
    // Handle when the user dismisses fullscreen by swiping down or tapping Done
    @available(iOS 13.0, *)
    public func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        // Store the playback state before dismissing
        let wasPlaying = self.player?.rate != 0
        
        // Send fullscreen exit event when user dismisses fullscreen
        coordinator.animate(alongsideTransition: nil) { _ in
            // Check if this is the fullscreen view controller we're tracking
            if playerViewController == self.fullscreenPlayerViewController {
                self.fullscreenPlayerViewController = nil
                
                // Resume playback if it was playing before
                if wasPlaying {
                    self.player?.play()
                }
                
                self.sendEvent("fullscreenChange", data: ["isFullscreen": false])
            }
        }
    }
}