//
//  FlickrAPIClient.h
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/12/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import "AFHTTPClient.h"

typedef void (^FlickrResultsBlock)(NSDictionary *response, NSError *error);

@interface FlickrAPIClient : AFHTTPClient

+ (FlickrAPIClient *)sharedClient;

- (void)publicFeedWithTags:(NSArray *)tags completionBlock:(FlickrResultsBlock)block;

@end
