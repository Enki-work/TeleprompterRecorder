//
//  GAMRequest.h
//  Google Mobile Ads SDK
//
//  Copyright 2014 Google LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GADRequest.h>

/// Add this constant to the testDevices property's array to receive test ads on the simulator.
GAD_EXTERN NSString *_Nonnull const kGAMSimulatorID GAD_DEPRECATED_MSG_ATTRIBUTE(
    "Use GADRequestConfiguration/GADSimulatorID instead.");

/// Specifies optional parameters for ad requests.
@interface GAMRequest : GADRequest

/// Publisher provided user ID.
@property(nonatomic, copy, nullable) NSString *publisherProvidedID;

/// Array of strings used to exclude specified categories in ad results.
@property(nonatomic, copy, nullable) NSArray<NSString *> *categoryExclusions;

/// Key-value pairs used for custom targeting.
@property(nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *customTargeting;

@end
