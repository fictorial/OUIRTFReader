// Copyright 2005, 2010 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSComparisonPredicate.h>

@interface NSComparisonPredicate (OFExtensions)
+ (NSPredicate *)isKindOfClassPredicate:(Class)cls;
+ (NSPredicate *)conformsToProtocolPredicate:(Protocol *)protocol;
@end
