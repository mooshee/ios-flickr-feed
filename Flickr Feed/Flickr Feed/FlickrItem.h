//
//  FlickrItem.h
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/11/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlickrItem : NSObject

@property (strong, nonatomic) NSString *title;
//@property (strong, nonatomic) NSURL *linkURL;
@property (strong, nonatomic) NSURL *thumbnailURL;
@property (strong, nonatomic) NSURL *largeURL;
//@property (strong, nonatomic) NSDate *dateTaken;
//@property (strong, nonatomic) NSDate *datePublished;
@property (strong, nonatomic) NSString *description;
@property (strong, nonatomic) NSString *author;
@property (strong, nonatomic) NSString *authorID;
//@property (strong, nonatomic) NSString *tags;

@end
