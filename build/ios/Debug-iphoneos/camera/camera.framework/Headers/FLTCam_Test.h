// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTCam.h"
#import "FLTSavePhotoDelegate.h"

// APIs exposed for unit testing.
@interface FLTCam ()

/// The output for video capturing.
@property(readonly, nonatomic) AVCaptureVideoDataOutput *captureVideoOutput;

/// The output for photo capturing. Exposed setter for unit tests.
@property(strong, nonatomic) AVCapturePhotoOutput *capturePhotoOutput API_AVAILABLE(ios(10));

/// A dictionary to retain all in-progress FLTSavePhotoDelegates. The key of the dictionary is the
/// AVCapturePhotoSettings's uniqueID for each photo capture operation, and the value is the
/// FLTSavePhotoDelegate that handles the result of each photo capture operation. Note that photo
/// capture operations may overlap, so we have to keep track of multiple delegates in progress,
/// instead of just a single delegate reference.
@property(readonly, nonatomic)
    NSMutableDictionary<NSNumber *, FLTSavePhotoDelegate *> *inProgressSavePhotoDelegates;

@end
