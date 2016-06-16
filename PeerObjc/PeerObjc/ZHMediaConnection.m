//
//  ZHMediaConnection.m
//  PeerObjc
//
//  Created by zhubch on 15-3-9.
//  Copyright (c) 2015年 zhubch. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "ZHMediaConnection.h"
#import "ZHNegotiator.h"
#import "ZHConstraintsFactory.h"
#import "WebRTC.h"
#import "ZHPrivate.h"

@interface ZHMediaConnection ()<RTCEAGLVideoViewDelegate>

@end

@implementation ZHMediaConnection
{
    ZHNegotiator *negotiator;
    RTCPeerConnection *pc;
    
    RTCVideoTrack *remoteVideoTrack;
    RTCVideoTrack *localVideoTrack;
    
    RTCMediaStream *localStream;
    
    RTCEAGLVideoView *remoteVideoView;
    RTCEAGLVideoView *localVideoView;
    
    RTCPeerConnectionFactory *factory;
}

@synthesize open = _open;

- (instancetype)initWithPeer:(ZHPeer *)peer destPeerId:(NSString *)destId options:(NSDictionary *)options
{
    if (self = [super initWithPeer:peer destPeerId:destId options:options]) {
        self.type = @"media";
        NSDictionary *config = options[@"_payload"] ? options[@"_payload"] : @{@"originator": @"true"} ;

    
        [self renderVideoWithCamera:2];
        
        negotiator = [[ZHNegotiator alloc]initWithConnection:self];
        negotiator.stream = localStream;
        
        pc = [negotiator startPeerConnectionWithOptions:config];
        
        [pc addStream:localStream];
    }
    
    return self;
}

- (void)renderVideoWithCamera:(AVCaptureDevicePosition)cameraPosition
{
    
    factory = [[RTCPeerConnectionFactory alloc]init];
    
    localStream = [factory mediaStreamWithLabel:@"ARDAMS"];
    
    NSString *cameraID = nil;
    
    for (AVCaptureDevice *captureDevice in
         [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        
        if (captureDevice.position == cameraPosition) {
            cameraID = [captureDevice localizedName];
        }
    }
    
    NSAssert(cameraID, @"Unable to get the camera id");
    
    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:cameraID];
    RTCMediaConstraints *mediaConstraints = [ZHConstraintsFactory constraintsForMediaStream];
    RTCVideoSource *videoSource = [factory videoSourceWithCapturer:capturer constraints:mediaConstraints];
    localVideoTrack = [factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
    
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
    }
    
    [localStream addAudioTrack:[factory audioTrackWithID:@"ARDAMSa0"]];
}


- (void)handelMessage:(NSDictionary *)msg
{
    NSDictionary *payload = msg[@"payload"];
    
    if ([msg[@"type"] isEqualToString:@"ANSWER"]) {
        [negotiator handelSdp:payload[@"sdp"] withType:@"answer"];
        self.open = true;
    } else if ([msg[@"type"] isEqualToString:@"CANDIDATE"]) {
        
        NSDictionary *candidateObj = [payload objectForKey:@"candidate"];
        NSString *candidateMessage = [candidateObj objectForKey:@"candidate"];
        NSInteger sdpMLineIndex = [[candidateObj objectForKey:@"sdpMLineIndex"] integerValue];
        NSString *sdpMid = [candidateObj objectForKey:@"sdpMid"];
        RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:sdpMid index:sdpMLineIndex sdp:candidateMessage];
        [negotiator handleCandidate:candidate];
    }
}

- (RTCEAGLVideoView*)createRenderViewWithFrame:(CGRect)frame
{
    RTCEAGLVideoView *videoView = [[RTCEAGLVideoView alloc]initWithFrame:frame];
    videoView.delegate = self;
    frame = AVMakeRectWithAspectRatioInsideRect(frame.size, frame);
    videoView.frame = frame;
    return videoView;
}

- (UIView *)renderViewForType:(RenderType)type bounding:(CGRect)bounds
{
    if (type == RenderFromLocalCamera) {
        localVideoView = [self createRenderViewWithFrame:bounds];
        [localVideoTrack addRenderer:localVideoView];
        return localVideoView;
    }else{
        remoteVideoView = [self createRenderViewWithFrame:bounds];
        [remoteVideoTrack addRenderer:remoteVideoView];
        return remoteVideoView;
    }
}

- (void)recievedRemoteVideoTrack:(RTCVideoTrack *)track
{
    remoteVideoTrack = track;
    if ([self.delegate respondsToSelector:@selector(mediaConnectionRecievedStream)]) {
        [self.delegate mediaConnectionRecievedStream];
    }else{
        NSLog(@"WARMING:Selector not found:mediaConnectionRecievedStream");
    }
}

- (void)setOpen:(BOOL)open
{
    _open = open;
    
    if (_open && [self.delegate respondsToSelector:@selector(mediaConnectionDidOpen)]) {
        [self.delegate mediaConnectionDidOpen];
    }
    
    if (!_open && [self.delegate respondsToSelector:@selector(mediaConnectionDidClosed)]) {
        [self.delegate mediaConnectionDidClosed];
    }
}

- (void)setDelegate:(id<ZHMediaConnectionDelegate>)delegate
{
    _delegate = delegate;
}

- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size
{
    CGRect frame = AVMakeRectWithAspectRatioInsideRect(size, videoView.bounds);
    videoView.frame = frame;
}

- (void)close
{
    [super close];

    [pc close];
    
    self.open = NO;
}

@end
