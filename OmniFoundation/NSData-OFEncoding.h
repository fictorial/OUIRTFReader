// Copyright 1997-2008, 2010 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSData.h>

typedef struct OFQuotedPrintableMapping {
    char map[256];   // 256 entries, one for each octet value
    unsigned short translations[8];  // 8 is an arbitrary size; must be at least 2
} OFQuotedPrintableMapping;


@interface NSData (OFEncoding) 

+ (id)dataWithHexString:(NSString *)hexString error:(NSError **)outError;
- initWithHexString:(NSString *)hexString error:(NSError **)outError;

- (NSString *)lowercaseHexString; /* has a leading 0x (sigh) */
- (NSString *)unadornedLowercaseHexString;  /* no 0x */

- initWithASCII85String:(NSString *)ascii85String;
- (NSString *)ascii85String;

+ (id)dataWithBase64String:(NSString *)base64String;
- initWithBase64String:(NSString *)base64String;
- (NSString *)base64String;

// This is our own coding method, not a standard.  This is good
// for NSData strings that users have to type in.
- initWithASCII26String:(NSString *)ascii26String;
- (NSString *)ascii26String;

// This is a generic implementation of quoted-printable-style encodings, used by methods elsewhere in OmniFoundation
- (NSString *)quotedPrintableStringWithMapping:(const OFQuotedPrintableMapping *)qpMap lengthHint:(NSUInteger)zeroIfNoHint;
- (NSUInteger)lengthOfQuotedPrintableStringWithMapping:(const OFQuotedPrintableMapping *)qpMap;

@end
