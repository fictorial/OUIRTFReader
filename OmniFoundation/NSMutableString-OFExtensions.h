// Copyright 1997-2008, 2010-2012 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSString.h>
#import <OmniBase/OBUtilities.h> // for OB_DEPRECATED_ATTRIBUTE

#import <OmniFoundation/NSString-OFReplacement.h> // Some simpler replacement methods are in a NSMutableString(OFReplacement) category here

@interface NSMutableString (OFExtensions)
- (void)collapseAllOccurrencesOfCharactersInSet:(NSCharacterSet *)set toString:(NSString *)replaceString;

- (BOOL)replaceAllOccurrencesOfString:(NSString *)matchString withString:(NSString *)newString;
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (BOOL)replaceAllOccurrencesOfRegularExpressionString:(NSString *)matchString withString:(NSString *)newString;
#endif
- (void)replaceAllLineEndingsWithString:(NSString *)newString;

- (void)appendLongCharacter:(UnicodeScalarValue)aCharacter; // This handles >16 bits characters, encoding with with surrogate pairs
- (void)appendStrings: (NSString *)first, ... NS_REQUIRES_NIL_TERMINATION;

@end
