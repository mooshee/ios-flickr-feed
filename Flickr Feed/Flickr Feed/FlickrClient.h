//
//  FlickrClient.h
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/11/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^FlickrClientResultsBlock)(NSDictionary *response, NSError *error);

@interface FlickrClient : NSObject

- (void)publicFeedWithTags:(NSArray *)tags completionBlock:(FlickrClientResultsBlock)completionBlock;

@end