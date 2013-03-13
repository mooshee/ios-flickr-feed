//
//  FlickrAPIClient.m
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/12/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import "FlickrAPIClient.h"
#import "FlickrJSONRequestOperation.h"

static NSString * const kFlickrAPIBaseURLString = @"http://api.flickr.com/";

@implementation FlickrAPIClient

+ (FlickrAPIClient *)sharedClient {
    static FlickrAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[FlickrAPIClient alloc] initWithBaseURL:[NSURL URLWithString:kFlickrAPIBaseURLString]];
    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
    [self registerHTTPOperationClass:[FlickrJSONRequestOperation class]];
    
	[self setDefaultHeader:@"Accept" value:@"application/json"];
        
    return self;
}

#pragma mark - API

- (void)publicFeedWithTags:(NSArray *)tags completionBlock:(FlickrResultsBlock)block {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"json", @"format",
                            [tags componentsJoinedByString:@","], @"tags",
                            nil];
        
    [self getPath:@"services/feeds/photos_public.gne" parameters:params success:^(AFHTTPRequestOperation *operation, id JSON) {
        if (block) {
            block(JSON, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (block) {
            block(nil, error);
        }
    }];
}

@end
