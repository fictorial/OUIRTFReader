// Copyright 1997-2008, 2010 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <CoreFoundation/CFData.h>
#import <CoreFoundation/CFError.h>
#include <stdio.h>

extern FILE *OFDataCreateReadOnlyStandardIOFile(CFDataRef data, CFErrorRef *outError);
extern FILE *OFDataCreateReadWriteStandardIOFile(CFMutableDataRef data, CFErrorRef *outError);
