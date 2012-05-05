// Copyright 2003-2005, 2010-2011 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/CFArray-OFExtensions.h>

#import <OmniFoundation/OFCFCallbacks.h>
#import <OmniBase/rcsid.h>
#import <Foundation/NSZone.h> // NSMakeCollectable

RCS_ID("$Id$");

CFMutableArrayRef OFCreateNonOwnedPointerArray(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, &OFNonOwnedPointerArrayCallbacks);
}

CFMutableArrayRef OFCreateIntegerArray(void)
{
    return CFArrayCreateMutable(kCFAllocatorDefault, 0, &OFIntegerArrayCallbacks);
}

Boolean OFCFArrayIsSortedAscendingUsingFunction(CFArrayRef self, CFComparatorFunction comparator, void *context)
{
    CFIndex valueIndex, valueCount = CFArrayGetCount(self);
    if (valueCount < 2)
        return true;
    
    const void *value1, *value2 = CFArrayGetValueAtIndex(self, 0);
    for (valueIndex = 1; valueIndex < valueCount; valueIndex++) {
        value1 = value2;
        value2 = CFArrayGetValueAtIndex(self, valueIndex);
        if (comparator(value1, value2, context) > 0)
            return false;
    }
    
    return true;
}
